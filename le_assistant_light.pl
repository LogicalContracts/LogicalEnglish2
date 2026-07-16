/** <module> Logical English Light Assistant
    
    This module implements the "Light" mode of the Logical English Assistant.
    It runs a Prolog-native agentic loop in a background thread, calling the
    LLM directly and executing in-process tools (verify, query).
*/

:- module(le_assistant_light, [
    run_light_assistant/9,
    run_light_assistant_thread/7
]).

:- use_module(library(http/http_json)).
:- use_module(le_assistant).
:- use_module(le_i18n).
:- use_module(le_tools).
:- use_module(llm/llm_client).
:- use_module(restricted_paths).

%!  run_light_assistant_thread(+JobID, +Command, +Program0, +Model, +Keys, +UserRoles, +MaxSteps) is det.
%
%   Runs the Light Assistant in a background thread.
run_light_assistant_thread(JobID, Command, Program0, Model, Keys, UserRoles, MaxSteps) :-
    asserta(le_assistant:assistant_job_status(JobID, running)),
    catch(
        (   run_light_assistant(JobID, Command, Program0, Model, Keys, UserRoles, MaxSteps, FinalExplanation, FinalProgram),
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

%!  run_light_assistant(+JobID, +Command, +Program0, +Model, +Keys, +UserRoles, +MaxSteps, -FinalExplanation, -FinalProgram) is det.
%
%   Runs the main Light Assistant agentic loop.
run_light_assistant(JobID, Command, Program0, Model, Keys, UserRoles, MaxSteps, FinalExplanation, FinalProgram) :-
    assemble_system_prompt(Program0, UserRoles, SystemPrompt),
    Messages0 = [
        _{role: system, content: SystemPrompt},
        _{role: user, content: Command}
    ],
    agent_loop(JobID, Model, Keys, Messages0, Program0, 0, dirty, MaxSteps, FinalExplanation, FinalProgram).

%!  agent_loop(+JobID, +Model, +Keys, +Messages, +Program, +Step, +LastVerifyStatus, +MaxSteps, -FinalExplanation, -FinalProgram) is det.
%
%   The bounded model-tool loop.
agent_loop(JobID, Model, Keys, Messages, Program, Step, LastVerifyStatus, MaxSteps, FinalExplanation, FinalProgram) :-
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
        % Call LLM (progress messages are user-visible: localized via the
        % messages.csv catalog, in the language inherited from the request)
        le_i18n:le_msg(assistant_calling_llm, [step-Step], CallingMsg),
        format(string(ProgressMsg), "~w\n", [CallingMsg]),
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
            ->  (   LastVerifyStatus == clean
                ->  % The program is already clean, and the model is just looping. Force terminate as success!
                    assertz(le_assistant:assistant_job_output(JobID, stdout, "Program is already verified with no issues. Terminating successfully.\n")),
                    FinalExplanation = "The program was verified successfully with no issues.",
                    FinalProgram = Program
                ;   % Run verify tool
                    le_i18n:le_msg(assistant_running_verification, [], VerifyingMsg),
                    format(string(VerifyingLine), "~w\n", [VerifyingMsg]),
                    assertz(le_assistant:assistant_job_output(JobID, stdout, VerifyingLine)),
                    le_tools:le_tool_verify(Program, VerifyResult),
                    % Format result as string to append to messages
                    with_output_to(string(ResultStr), json_write_dict(current_output, VerifyResult, [width(0)])),
                    format_verify_result(VerifyResult, FormattedResult),
                    format(string(VerifyOutputMsg), "Verification result: ~w\n", [FormattedResult]),
                    assertz(le_assistant:assistant_job_output(JobID, stdout, VerifyOutputMsg)),
                    % If there are no issues, nudge the model to finish
                    (   FormattedResult == "no issues"
                    ->  NudgeResultStr = "Verification result: no issues. All tests passed and there are no warnings or errors! You have successfully completed the task. You MUST now immediately respond with the 'finish' action to return the final program and explain your changes to the user. Do NOT call 'verify' or 'query' again.",
                        NextStatus = clean
                    ;   NudgeResultStr = ResultStr,
                        NextStatus = dirty
                    ),
                    % Append to messages and loop
                    append(Messages, [
                        _{role: assistant, content: Reply},
                        _{role: user, content: NudgeResultStr}
                    ], NewMessages),
                    Step1 is Step + 1,
                    agent_loop(JobID, Model, Keys, NewMessages, Program, Step1, NextStatus, MaxSteps, FinalExplanation, FinalProgram)
                )
            ;   Action == "query"
            ->  (   LastVerifyStatus == clean
                ->  % The program is already clean, and the model is just looping. Force terminate as success!
                    assertz(le_assistant:assistant_job_output(JobID, stdout, "Program is already verified with no issues. Terminating successfully.\n")),
                    FinalExplanation = "The program was verified successfully with no issues.",
                    FinalProgram = Program
                ;   % Run query tool
                    le_i18n:le_msg(assistant_running_query, [], QueryingMsg),
                    format(string(QueryingLine), "~w\n", [QueryingMsg]),
                    assertz(le_assistant:assistant_job_output(JobID, stdout, QueryingLine)),
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
                    agent_loop(JobID, Model, Keys, NewMessages, Program, Step1, dirty, MaxSteps, FinalExplanation, FinalProgram)
                )
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
                agent_loop(JobID, Model, Keys, NewMessages, NewProgram, Step1, dirty, MaxSteps, FinalExplanation, FinalProgram)
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
                agent_loop(JobID, Model, Keys, NewMessages, Program, Step1, LastVerifyStatus, MaxSteps, FinalExplanation, FinalProgram)
            )
        ;   % No parseable JSON action
            append(Messages, [
                _{role: assistant, content: Reply},
                _{role: user, content: "Please respond with a single JSON action object."}
            ], NewMessages),
            Step1 is Step + 1,
            agent_loop(JobID, Model, Keys, NewMessages, Program, Step1, LastVerifyStatus, MaxSteps, FinalExplanation, FinalProgram)
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
    % The prompt assets follow the PROGRAM's language (its opener statement);
    % an empty/undeclared program follows the request's UI language (O-6).
    ( le_kbs:text_language(Program, ProgLang), ProgLang \== en -> true
    ; le_i18n:le_active_language(ProgLang) ),
    le_i18n:set_le_language(ProgLang),
    load_agent_template(_ResourceMap, InstructionBody0),
    % Replace positional placeholders in InstructionBody0 if any
    catch(
        format(string(InstructionBody), InstructionBody0, [".", ".", "your program", "your program", "your program", "your program"]),
        _,
        InstructionBody = InstructionBody0
    ),
    
    % Load LE syntax summary (the active language's variant when present)
    le_i18n:localized_asset('docs/le_summary', md, SummaryPath),
    read_file_to_string(SummaryPath, SyntaxSummary, []),
    
    % Load curated examples
    load_curated_examples(UserRoles, ExamplesStr),
    
    % Get tool specification
    tool_specification(ToolSpec),
    
    % Output-language directive (a no-op line for English)
    language_directive(LangDirective),

    % Assemble everything
    format(string(SystemPrompt),
           "~w~w\n\n## Logical English Syntax Summary\n~w\n\n## Curated Examples\n~w\n\n~w\n\n## Your Program\n```\n~w\n```\n",
           [InstructionBody, LangDirective, SyntaxSummary, ExamplesStr, ToolSpec, Program]).

%!  language_directive(-Directive) is det.
%
%   An explicit output-language instruction for non-English programs: respond
%   and write LE in the program's language, with its keyword set.
language_directive(Directive) :-
    le_i18n:le_active_language(Lang),
    (   Lang == en
    ->  Directive = ""
    ;   ( le_i18n:language_param(Lang, english_name, Name) -> true ; Name = Lang ),
        ( le_i18n:language_autonym(Lang, Autonym) -> true ; Autonym = Name ),
        ( le_i18n:language_opener(Lang, OpenerWords), atomic_list_concat(OpenerWords, ' ', Opener) -> true ; Opener = '' ),
        format(string(Directive),
               "\n\n## Output language\nThe program is written in ~w (~w). Write ALL Logical English you produce in ~w, using the ~w keyword set shown in the syntax summary below; the program's first statement must be `~w: prolog.`. Respond to the user in ~w.\n",
               [Name, Autonym, Name, Name, Opener, Name])
    ).

%!  load_agent_template(-ResourceMap, -InstructionBody) is det.
%
%   Loads and parses the AGENTS_LE_template.md file.
load_agent_template(ResourceMap, InstructionBody) :-
    le_i18n:localized_asset('AGENTS_LE_template', md, TemplatePath),
    read_file_to_string(TemplatePath, Template, []),
    (   sub_string(Template, 0, 3, _, "---")
    ->  sub_string(Template, 3, _, _, Rest),
        sub_string(Rest, BeforeDash, 3, AfterDash, "---"),
        sub_string(Rest, 0, BeforeDash, _, FrontmatterStr),
        sub_string(Rest, _, AfterDash, 0, Body0),
        parse_yaml_frontmatter(FrontmatterStr, ResourceMap),
        % Strip out DEEP_MODE_ONLY block
        (   sub_string(Body0, StartDeep, _, EndDeep, "<!-- DEEP_MODE_ONLY_START -->")
        ->  sub_string(Body0, 0, StartDeep, _, Preamble),
            sub_string(Body0, _, EndDeep, 0, PostDeep),
            (   sub_string(PostDeep, _, _, EndEnd, "<!-- DEEP_MODE_ONLY_END -->")
            ->  sub_string(PostDeep, _, EndEnd, 0, Postamble),
                format(string(InstructionBody), "~w~w", [Preamble, Postamble])
            ;   InstructionBody = Body0
            )
        ;   InstructionBody = Body0
        )
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
        % skip_tests: the listing only needs each KB loaded for its summary;
        % running the KBs' embedded tests here would take tens of seconds.
        % kb_summary_safe holds a module reference while summarizing, so a
        % concurrent session teardown cannot reclaim the KB module mid-read.
        ( le_kbs:kb_summary_safe(FullPath, [skip_tests], Summary0) ->
            Summary = Summary0
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

load_curated_examples(_UserRoles, ExamplesStr) :-
    % Non-English languages use their own example tree (examples/<lang>/).
    le_i18n:le_active_language(Lang),
    Lang \== en,
    atomic_list_concat([examples, /, Lang], LangDir),
    exists_directory(LangDir),
    !,
    atomic_list_concat([LangDir, '/'], LangDirSlash),
    directory_files(LangDir, Files0),
    include([F]>>sub_atom(F, _, _, 0, '.le'), Files0, Files),
    msort(Files, Sorted),
    findall(Block,
            ( member(F, Sorted),
              atomic_list_concat([LangDirSlash, F], Path),
              catch(read_file_to_string(Path, Content, []), _, fail),
              format(string(Block), "### Example: ~w\n```le\n~w\n```\n", [F, Content]) ),
            Blocks),
    atomic_list_concat(Blocks, "\n", ExamplesStr).
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
    
    % Also inline the full content of a few key representative examples (and only these, token budget oblige)
    CuratedFiles = [
        "examples/moreExamples/citizenship.le",
        "examples/moreExamples/numbering_test.le",
        "examples/moreExamples/1_net_asset_value_test_3.le",
        "examples/moreExamples/payg.le",
        "examples/moreExamples/dates.le",
        "examples/moreExamples/insureLE2/big_conclusions.le"
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
