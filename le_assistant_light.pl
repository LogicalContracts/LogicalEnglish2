/** <module> Logical English Light Assistant
    
    This module implements the "Light" mode of the Logical English Assistant.
    It runs a Prolog-native agentic loop in a background thread, calling the
    LLM directly and executing in-process tools (verify, query).
*/

:- module(le_assistant_light, [
    run_light_assistant/8,
    run_light_assistant_thread/6
]).

:- use_module(library(http/http_json)).
:- use_module(le_assistant).
:- use_module(le_tools).
:- use_module(llm/llm_client).
:- use_module(restricted_paths).

%!  run_light_assistant_thread(+JobID, +Command, +Program0, +Model, +Keys, +UserRoles) is det.
%
%   Runs the Light Assistant in a background thread.
run_light_assistant_thread(JobID, Command, Program0, Model, Keys, UserRoles) :-
    asserta(le_assistant:assistant_job_status(JobID, running)),
    catch(
        (   run_light_assistant(JobID, Command, Program0, Model, Keys, UserRoles, FinalExplanation, FinalProgram),
            asserta(le_assistant:assistant_job_content(JobID, FinalProgram)),
            % Format the final output as JSON so that handle_assistant_status can parse it
            JSONDict = _{explanation: FinalExplanation, new_content: FinalProgram},
            with_output_to(string(JSONStr), json_write_dict(current_output, JSONDict, [width(0)])),
            assertz(le_assistant:assistant_job_output(JobID, stdout, JSONStr)),
            retractall(le_assistant:assistant_job_status(JobID, _)),
            asserta(le_assistant:assistant_job_status(JobID, finished("exit(0)")))
        ),
        Error,
        (   % Handle error or interrupt
            (   Error == interrupt
            ->  StatusStr = "interrupted",
                assertz(le_assistant:assistant_job_output(JobID, stderr, "Job interrupted by user.\n"))
            ;   term_string(Error, ErrorStr),
                format(string(Msg), "Error during execution: ~w\n", [ErrorStr]),
                assertz(le_assistant:assistant_job_output(JobID, stderr, Msg)),
                StatusStr = "error"
            ),
            asserta(le_assistant:assistant_job_content(JobID, Program0)),
            retractall(le_assistant:assistant_job_status(JobID, _)),
            asserta(le_assistant:assistant_job_status(JobID, finished(StatusStr)))
        )
    ).

%!  run_light_assistant(+JobID, +Command, +Program0, +Model, +Keys, +UserRoles, -FinalExplanation, -FinalProgram) is det.
%
%   Runs the main Light Assistant agentic loop.
run_light_assistant(JobID, Command, Program0, Model, Keys, UserRoles, FinalExplanation, FinalProgram) :-
    assemble_system_prompt(Program0, UserRoles, SystemPrompt),
    Messages0 = [
        _{role: system, content: SystemPrompt},
        _{role: user, content: Command}
    ],
    agent_loop(JobID, Model, Keys, Messages0, Program0, 0, FinalExplanation, FinalProgram).

%!  agent_loop(+JobID, +Model, +Keys, +Messages, +Program, +Step, -FinalExplanation, -FinalProgram) is det.
%
%   The bounded model-tool loop.
agent_loop(JobID, Model, Keys, Messages, Program, Step, FinalExplanation, FinalProgram) :-
    MaxSteps = 10,
    (   Step >= MaxSteps
    ->  FinalExplanation = "Reached step limit before completion.",
        FinalProgram = Program
    ;   % Check if job is interrupted
        (   le_assistant:assistant_job_status(JobID, running)
        ->  true
        ;   throw(interrupt)
        ),
        % Get API key
        get_key_for_model(Model, Keys, Key),
        % Call LLM
        format(string(ProgressMsg), "Calling LLM (step ~w)...\n", [Step]),
        assertz(le_assistant:assistant_job_output(JobID, stdout, ProgressMsg)),
        catch(
            llm_client:llm_request(Model, Messages, Reply, [api_key(Key), max_tokens(4096)]),
            Error,
            (   % Log error and rethrow
                term_string(Error, ErrorStr),
                format(string(ErrMsg), "LLM request failed: ~w\n", [ErrorStr]),
                assertz(le_assistant:assistant_job_output(JobID, stderr, ErrMsg)),
                throw(Error)
            )
        ),
        % Parse action
        (   le_assistant:extract_json_from_string(Reply, ActionDict, _)
        ->  ( get_dict(action, ActionDict, Action) -> true ; Action = "unknown" ),
            format(string(ActionMsg), "Model action: ~w\n", [Action]),
            assertz(le_assistant:assistant_job_output(JobID, stdout, ActionMsg)),
            (   Action == "verify"
            ->  % Run verify tool
                assertz(le_assistant:assistant_job_output(JobID, stdout, "Running verification...\n")),
                le_tools:le_tool_verify(Program, VerifyResult),
                % Format result as string to append to messages
                with_output_to(string(ResultStr), json_write_dict(current_output, VerifyResult, [width(0)])),
                format_verify_result(VerifyResult, FormattedResult),
                format(string(VerifyOutputMsg), "Verification result: ~w\n", [FormattedResult]),
                assertz(le_assistant:assistant_job_output(JobID, stdout, VerifyOutputMsg)),
                % If there are no issues, nudge the model to finish
                (   FormattedResult == "no issues"
                ->  NudgeResultStr = "Verification result: no issues. All tests passed and there are no warnings or errors! You have successfully completed the task. Please respond with the 'finish' action to return the final program and explain your changes to the user."
                ;   NudgeResultStr = ResultStr
                ),
                % Append to messages and loop
                append(Messages, [
                    _{role: assistant, content: Reply},
                    _{role: user, content: NudgeResultStr}
                ], NewMessages),
                Step1 is Step + 1,
                agent_loop(JobID, Model, Keys, NewMessages, Program, Step1, FinalExplanation, FinalProgram)
            ;   Action == "query"
            ->  % Run query tool
                assertz(le_assistant:assistant_job_output(JobID, stdout, "Running query...\n")),
                % We need to pass program_text to le_tool_query
                QueryArgs = ActionDict.put(program_text, Program),
                le_tools:le_tool_query(QueryArgs, QueryResult),
                with_output_to(string(ResultStr), json_write_dict(current_output, QueryResult, [width(0)])),
                % Append to messages and loop
                append(Messages, [
                    _{role: assistant, content: Reply},
                    _{role: user, content: ResultStr}
                ], NewMessages),
                Step1 is Step + 1,
                agent_loop(JobID, Model, Keys, NewMessages, Program, Step1, FinalExplanation, FinalProgram)
            ;   Action == "edit"
            ->  % Update program
                ( get_dict(new_content, ActionDict, NewProgram) -> true ; NewProgram = Program ),
                assertz(le_assistant:assistant_job_output(JobID, stdout, "Program updated.\n")),
                % Append to messages and loop
                append(Messages, [
                    _{role: assistant, content: Reply},
                    _{role: user, content: "Program updated. Please verify your changes."}
                ], NewMessages),
                Step1 is Step + 1,
                agent_loop(JobID, Model, Keys, NewMessages, NewProgram, Step1, FinalExplanation, FinalProgram)
            ;   Action == "finish"
            ->  % Finish
                get_dict(explanation, ActionDict, FinalExplanation),
                ( get_dict(new_content, ActionDict, FinalProgram) -> true ; FinalProgram = Program ),
                assertz(le_assistant:assistant_job_output(JobID, stdout, "Task completed successfully.\n"))
            ;   % Unknown action
                format(string(NudgeMsg), "Unknown action '~w'. Please respond with a valid action.", [Action]),
                append(Messages, [
                    _{role: assistant, content: Reply},
                    _{role: user, content: NudgeMsg}
                ], NewMessages),
                Step1 is Step + 1,
                agent_loop(JobID, Model, Keys, NewMessages, Program, Step1, FinalExplanation, FinalProgram)
            )
        ;   % No parseable JSON action
            append(Messages, [
                _{role: assistant, content: Reply},
                _{role: user, content: "Please respond with a single JSON action object."}
            ], NewMessages),
            Step1 is Step + 1,
            agent_loop(JobID, Model, Keys, NewMessages, Program, Step1, FinalExplanation, FinalProgram)
        )
    ).

%!  get_key_for_model(+Model, +Keys, -Key) is det.
%
%   Resolves the API key for the selected model.
get_key_for_model(Model, Keys, Key) :-
    (   llm_client:llm_model(Model, Provider0, _)
    ->  ( Provider0 == gemini -> Provider = google ; Provider = Provider0 ),
        (   get_dict(Provider, Keys, Key), Key \== null, Key \== ""
        ->  true
        ;   % Fallback to environment variable
            catch(llm_client:api_key(Provider0, Key), _, Key = "")
        )
    ;   % Fallback to openai provider if model is unknown
        (   get_dict(openai, Keys, Key), Key \== null, Key \== ""
        ->  true
        ;   catch(llm_client:api_key(openai, Key), _, Key = "")
        )
    ).

%!  assemble_system_prompt(+Program, +UserRoles, -SystemPrompt) is det.
%
%   Assembles the system prompt by inlining instructions, syntax, and examples.
assemble_system_prompt(Program, UserRoles, SystemPrompt) :-
    load_agent_template(_ResourceMap, InstructionBody0),
    % Replace positional placeholders in InstructionBody0 if any
    catch(
        format(string(InstructionBody), InstructionBody0, [".", ".", "your program", "your program", "your program", "your program"]),
        _,
        InstructionBody = InstructionBody0
    ),
    
    % Load LE syntax summary
    ( exists_file('docs/le_summary.md') -> 
        read_file_to_string('docs/le_summary.md', SyntaxSummary, [])
    ; read_file_to_string('../docs/le_summary.md', SyntaxSummary, [])
    ),
    
    % Load curated examples
    load_curated_examples(UserRoles, ExamplesStr),
    
    % Get tool specification
    tool_specification(ToolSpec),
    
    % Assemble everything
    format(string(SystemPrompt),
           "~w\n\n## Logical English Syntax Summary\n~w\n\n## Curated Examples\n~w\n\n~w\n\n## Your Program\n```\n~w\n```\n",
           [InstructionBody, SyntaxSummary, ExamplesStr, ToolSpec, Program]).

%!  load_agent_template(-ResourceMap, -InstructionBody) is det.
%
%   Loads and parses the AGENTS_LE_template.md file.
load_agent_template(ResourceMap, InstructionBody) :-
    ( exists_file('AGENTS_LE_template.md') -> 
        read_file_to_string('AGENTS_LE_template.md', Template, [])
    ; read_file_to_string('../AGENTS_LE_template.md', Template, [])
    ),
    (   sub_string(Template, 0, 3, _, "---")
    ->  sub_string(Template, 3, _, _, Rest),
        sub_string(Rest, BeforeDash, 3, AfterDash, "---"),
        sub_string(Rest, 0, BeforeDash, _, FrontmatterStr),
        sub_string(Rest, _, AfterDash, 0, Body0),
        parse_yaml_frontmatter(FrontmatterStr, ResourceMap),
        InstructionBody = Body0
    ;   ResourceMap = _{},
        InstructionBody = Template
    ).

parse_yaml_frontmatter(Str, Dict) :-
    split_string(Str, "\n", "\r", Lines),
    findall(Key-Val, (
        member(Line, Lines),
        sub_string(Line, BeforeColon, 1, AfterColon, ":"),
        sub_string(Line, 0, BeforeColon, _, Key0),
        sub_string(Line, _, AfterColon, 0, Val0),
        normalize_space(atom(Key), Key0),
        normalize_space(string(Val), Val0)
    ), Pairs),
    dict_pairs(Dict, _, Pairs).

list_examples_with_summaries(Dir, Prefix, UserRoles, Examples) :-
    directory_files(Dir, Files),
    findall(_{name: ExPath, summary: Summary}, (
        member(F, Files),
        sub_atom(F, _, _, 0, '.le'),
        \+ sub_atom(F, _, _, 0, '.le.tests'),
        file_name_extension(Base, le, F),
        atomic_list_concat([Dir, F], FullPath),
        restricted_paths:is_path_allowed(FullPath, UserRoles),
        atom_concat(Prefix, Base, ExPath),
        ( catch(le_kbs:load(FullPath, KB), _, fail) ->
            le_kbs:kbSummary(KB, Summary)
        ; Summary = "No summary available"
        )
    ), DirectExamples),
    findall(SubExamples, (
        member(F, Files),
        \+ sub_atom(F, 0, 1, _, '.'),
        directory_file_path(Dir, F, SubDir),
        exists_directory(SubDir),
        restricted_paths:is_path_allowed(SubDir, UserRoles),
        atomic_list_concat([Prefix, F, '/'], SubPrefix),
        atomic_list_concat([SubDir, '/'], SubDirSlash),
        list_examples_with_summaries(SubDirSlash, SubPrefix, UserRoles, SubExamples)
    ), SubExamplesLists),
    append(SubExamplesLists, SubExamplesFlat),
    append(DirectExamples, SubExamplesFlat, Examples).

load_curated_examples(UserRoles, ExamplesStr) :-
    le_kbs:le_examples_dir(ExDir),
    atomic_list_concat([ExDir, '/'], DirSlash),
    list_examples_with_summaries(DirSlash, '', UserRoles, Examples),
    % Format the list of all accessible examples
    findall(Line, (
        member(Ex, Examples),
        format(string(Line), "- **~w**: ~w\n", [Ex.name, Ex.summary])
    ), Lines),
    atomic_list_concat(Lines, "", ListStr),
    
    % Also inline the full content of a few key representative examples
    CuratedFiles = [
        "examples/moreExamples/citizenship.le",
        "examples/moreExamples/numbering_test.le"
    ],
    findall(ExContent, (
        member(File, CuratedFiles),
        (   exists_file(File),
            restricted_paths:is_path_allowed(File, UserRoles)
        ->  read_file_to_string(File, Content, []),
            format(string(ExContent), "### Full Content of Example: ~w\n```\n~w\n```\n", [File, Content])
        ;   ExContent = ""
        )
    ), Contents),
    atomic_list_concat(Contents, "\n", FullContentsStr),
    
    format(string(ExamplesStr), "Here is a list of all Logical English examples currently available in the system:\n~w\n\n~w", [ListStr, FullContentsStr]).

tool_specification(Spec) :-
    Spec = "
## Tool Calling Protocol
You do not have direct access to the file system or external tools. Instead, you must interact with the Logical English engine by outputting a single JSON object at the end of your response.
You MUST respond with EXACTLY one JSON object in one of the following formats:

1. To verify the current program (check for syntax errors, warnings, and run tests):
```json
{ \"action\": \"verify\" }
```

2. To run a query against the current program:
```json
{
  \"action\": \"query\",
  \"query\": \"the query to execute (MUST match a template exactly)\",
  \"scenario\": \"optional scenario name\",
  \"facts\": \"optional additional facts (MUST match templates exactly)\"
}
```

3. To edit the program text:
```json
{
  \"action\": \"edit\",
  \"new_content\": \"the full updated program text\"
}
```

4. To finish your task and return the final verified program:
```json
{
  \"action\": \"finish\",
  \"explanation\": \"Markdown summary of your changes; refer to the file as 'your program'\",
  \"new_content\": \"the full, verified program text\"
}
```

IMPORTANT RULES:
- You MUST use the `verify` action after any edit to ensure the program is correct and all tests pass.
- Do NOT finish until the program has no errors or warnings, and all tests pass.
- Your response must contain EXACTLY one JSON block.
".

format_verify_result(VerifyResult, FormattedStr) :-
    get_dict(issues, VerifyResult, Issues),
    get_dict(test_results, VerifyResult, Tests),
    (   Issues == [], Tests == []
    ->  FormattedStr = "no issues"
    ;   % Format issues and tests nicely
        findall(IssueLine, (
            member(I, Issues),
            get_dict(severity, I, Sev),
            get_dict(message, I, Msg),
            format(string(IssueLine), "- [~w] ~w", [Sev, Msg])
        ), IssueLines),
        findall(TestLine, (
            member(T, Tests),
            get_dict(status, T, Status),
            get_dict(query, T, Q),
            get_dict(scenario, T, S),
            (   Status == "pass"
            ->  format(string(TestLine), "- [PASS] Query '~w' in scenario '~w'", [Q, S])
            ;   get_dict(expected, T, Exp),
                get_dict(actual, T, Act),
                format(string(TestLine), "- [FAIL] Query '~w' in scenario '~w' (Expected: ~w, Actual: ~w)", [Q, S, Exp, Act])
            )
        ), TestLines),
        (   IssueLines == [] -> IssuesPart = "" ; atomic_list_concat(IssueLines, "\n", IssuesStr), format(string(IssuesPart), "Issues:\n~w\n", [IssuesStr]) ),
        (   TestLines == [] -> TestsPart = "" ; atomic_list_concat(TestLines, "\n", TestsStr), format(string(TestsPart), "Test Results:\n~w\n", [TestsStr]) ),
        format(string(FormattedStr), "~w~w", [IssuesPart, TestsPart])
    ).
