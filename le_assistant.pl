:- module(le_assistant, [handle_assistant_command/2]).

:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(http/http_json)).
:- use_module(library(pcre)).
:- use_module(llm/llm_client, [llm_model/3]).

:- dynamic assistant_file_counter/1.
assistant_file_counter(1).

get_next_id(ID) :-
    with_mutex(assistant_id_gen, (
        assistant_file_counter(ID),
        NextID is ID + 1,
        retractall(assistant_file_counter(_)),
        asserta(assistant_file_counter(NextID))
    )).

%!  handle_assistant_command(+Dict, -Response) is det.
%
%   Handles a command for the LE Assistant.
handle_assistant_command(Dict, Response) :-
    format(user_error, "DEBUG: Entering handle_assistant_command~n", []),
    ( get_dict(command, Dict, Command) -> true ; Command = "" ),
    ( get_dict(content, Dict, Content) -> string_length(Content, L), format(user_error, "DEBUG: Content length: ~w~n", [L]) ; Content = "", format(user_error, "DEBUG: Content missing~n", []) ),
    ( get_dict(session_id, Dict, SessionID0) -> 
        ( sub_atom(SessionID0, 0, 3, _, ses) -> SessionID = SessionID0 ; atom_concat(ses, SessionID0, SessionID) )
    ; SessionID = "ses_default" ),
    ( get_dict(api_keys, Dict, APIKeys) -> true ; APIKeys = _{} ),
    ( get_dict(model, Dict, Model) -> true ; Model = "" ),
    
    % Create a temporary file for the editor content
    get_next_id(ID),
    format(string(TempFile), "/tmp/le_assistant/myProgram~w.le", [ID]),
    setup_call_cleanup(
        open(TempFile, write, Stream),
        write(Stream, Content),
        close(Stream)
    ),
    format(user_error, "DEBUG: Temp file created: ~w~n", [TempFile]),
    
    % Prepare environment variables
    % Inherit important ones and add API keys
    findall(Name=SVal, (
        member(Var, ['PATH', 'HOME', 'USER', 'SHELL']),
        getenv(Var, SVal),
        Name = Var
    ), BaseEnv),
    
    working_directory(CWD, CWD),
    format(string(MCPConfig), "~allm/settings/opencode_config.json", [CWD]),
    
    findall(Name=SVal, (
        get_dict(Key, APIKeys, Val),
        Val \== null, Val \== "",
        to_atom_or_string(Val, SVal),
        (   Key == openai -> Name = 'OPENAI_API_KEY'
        ;   Key == anthropic -> Name = 'ANTHROPIC_API_KEY'
        ;   Key == google -> Name = 'GOOGLE_API_KEY'
        ;   Key == groq -> Name = 'GROQ_API_KEY'
        ;   Key == together -> Name = 'TOGETHER_API_KEY'
        ;   fail
        )
    ), APIEnv),
    
    % Resolve model to provider/model format for opencode
    (   (Model \== "", Model \== null)
    ->  ( llm_model(Model, Provider, APIModel) -> 
            ( Provider == gemini -> ActualProvider = google 
            ; Provider == openai -> ActualProvider = groq % Based on user's model list
            ; ActualProvider = Provider 
            ),
            format(atom(OpencodeModel), "~w/~w", [ActualProvider, APIModel])
        ;   OpencodeModel = Model % Fallback to original if not found
        )
    ;   OpencodeModel = ""
    ),

    % Special case: if model is groq/openai/gpt-oss-120b, ensure GROQ_API_KEY is set
    (   sub_atom(OpencodeModel, _, _, _, 'groq/')
    ->  ( get_dict(openai, APIKeys, GKey), GKey \== null, GKey \== "" -> 
            to_atom_or_string(GKey, SGKey),
            ExtraEnv = ['GROQ_API_KEY'=SGKey]
        ; ExtraEnv = [] )
    ;   ExtraEnv = []
    ),
    
    append(BaseEnv, APIEnv, Env1),
    append(ExtraEnv, Env1, Env2),
    Env = ['TERM'=dumb, 'PAGER'=cat, 'NO_COLOR'='1', 'OPENCODE_CONFIG'=MCPConfig | Env2],
    
    format(string(AgentFile), "AGENTS_LE_~w.md", [ID]),
    create_agent_file(AgentFile, TempFile),

    % Prepare opencode arguments
    maplist(to_atom_or_string, [SessionID, TempFile, OpencodeModel, Command], [ASessionID, ATempFile, AModel, ACommand]),

    % Check if session exists
    (   (ASessionID \== "ses_default", session_exists(ASessionID))
    ->  SessionArgs = ['--session', ASessionID]
    ;   SessionArgs = []
    ),

    % Use 'build' agent as suggested, it should pick up CLAUDE.md
    BaseArgs = ['run' | SessionArgs],
    append(BaseArgs, ['--file', ATempFile, '--agent', 'build', '--format', 'default'], Args0),
    ( (AModel \== "", AModel \== null) -> append(Args0, ['--model', AModel, ACommand], Args) ; append(Args0, [ACommand], Args) ),
    
    format(user_error, "DEBUG: Running process_create: opencode ~w~n", [Args]),
    
    (   catch(
            (
                format(user_error, "DEBUG: Calling process_create...~n", []),
                process_create(path(opencode), Args, [stdin(null), stdout(pipe(Out)), stderr(pipe(Err)), env(Env), process(PID)]),
                format(user_error, "DEBUG: process_create succeeded, PID: ~w~n", [PID]),
                
                % Read from both pipes in separate threads to avoid deadlock
                thread_create(safe_read(Out, stdout), T1, []),
                thread_create(safe_read(Err, stderr), T2, []),
                
                format(user_error, "DEBUG: Waiting for output threads...~n", []),
                thread_join(T1, Status1),
                thread_join(T2, Status2),
                
                ( Status1 = exited(Stdout0) -> strip_ansi(Stdout0, Stdout) ; Stdout = "" ),
                ( Status2 = exited(Stderr0) -> strip_ansi(Stderr0, Stderr) ; Stderr = "" ),
                
                % Close pipes
                close(Out),
                close(Err),
                
                format(user_error, "DEBUG: Waiting for process...~n", []),
                process_wait(PID, Status),
                format(user_error, "DEBUG: Process finished with status: ~w~n", [Status])
            ),
            E,
            (
                format(user_error, "DEBUG: Process execution failed (catch): ~w~n", [E]),
                Stdout = "",
                term_string(E, Stderr),
                Status = error
            )
        )
    ->  true
    ;   format(user_error, "DEBUG: Process block failed (backtracked)~n", []),
        Stdout = "", Stderr = "Internal failure in process block", Status = error
    ),
    
    % After opencode runs, it might have modified TempFile.
    ( exists_file(TempFile) -> 
        ( catch(read_file_to_string(TempFile, NewContent, []), _, NewContent = Content),
          catch(delete_file(TempFile), _, true) )
    ; NewContent = Content ),
    
    % Delete the agent file
    ( exists_file(AgentFile) -> catch(delete_file(AgentFile), _, true) ; true ),
    
    % Ensure Stdout and Stderr are bound
    ( var(Stdout) -> Stdout = "" ; true ),
    ( var(Stderr) -> Stderr = "" ; true ),

    % Try to extract session ID from output if we started a new one
    (   (var(SessionArgs) ; SessionArgs == [])
    ->  ( extract_session_id(Stdout, NewSID) -> ActualSID = NewSID ; extract_session_id(Stderr, NewSID) -> ActualSID = NewSID ; ActualSID = ASessionID )
    ;   ActualSID = ASessionID
    ),

    % Ensure Status is a string for JSON
    ( var(Status) -> StatusStr = "unknown" ; term_string(Status, StatusStr) ),

    % Try to extract JSON from Stdout for cleaner response
    (   extract_json_from_string(Stdout, JSONDict)
    ->  ( get_dict(explanation, JSONDict, FinalStdout) -> true ; FinalStdout = Stdout ),
        ( get_dict(new_content, JSONDict, ContentFromJson) -> FinalNewContent = ContentFromJson ; FinalNewContent = NewContent )
    ;   FinalStdout = Stdout, FinalNewContent = NewContent
    ),

    Response = _{
        result: ok,
        stdout: FinalStdout,
        stderr: Stderr,
        new_content: FinalNewContent,
        exit_status: StatusStr,
        session_id: ActualSID
    },
    format(user_error, "DEBUG: Leaving handle_assistant_command, session: ~w~n", [ActualSID]).

extract_session_id(Text, ID) :-
    Text \== "",
    catch(re_matchsub("ses_[a-zA-Z0-9]+", Text, Sub, []), _, fail),
    get_dict(0, Sub, ID).

extract_json_from_string(String, Dict) :-
    String \== "",
    % Look for JSON in a code block first, then just any JSON-like structure
    (   re_matchsub("```json\n?(\\{.*\\})\n?```", String, Sub, [dotall])
    ->  get_dict(1, Sub, JSONStr)
    ;   re_matchsub("(\\{.*\\})", String, Sub, [dotall])
    ->  get_dict(1, Sub, JSONStr)
    ;   fail
    ),
    catch(json_read_dict(string(JSONStr), Dict), _, fail).

strip_ansi(In, Out) :-
    % Regex for ANSI escape sequences: ESC [ ... m or ESC [ ... K
    % \x1B is ESC. In Prolog strings, we use \u001b or similar if supported, 
    % but re_replace often accepts hex escapes in the pattern.
    % We'll use the hex escape \x1b for the ESC character.
    re_replace("\\x1b\\[[0-9;]*[mK]"/g, "", In, Out).

safe_read(Stream, Label) :-
    format(user_error, "DEBUG: Thread ~w started~n", [Label]),
    read_lines(Stream, Lines, Label),
    atomic_list_concat(Lines, "\n", String),
    format(user_error, "DEBUG: Thread ~w finished~n", [Label]),
    thread_exit(String).

read_lines(Stream, Lines, Label) :-
    read_line_to_string(Stream, Line),
    ( Line == end_of_file ->
        Lines = []
    ; 
        format(user_error, "DEBUG: [~w] ~w~n", [Label, Line]),
        Lines = [Line|Rest],
        read_lines(Stream, Rest, Label)
    ).

to_atom_or_string(X, X) :- (atom(X) ; string(X)), !.
to_atom_or_string(X, S) :- term_string(X, S).

session_exists(ID) :-
    format(user_error, "DEBUG: Checking if session exists: ~w~n", [ID]),
    setup_call_cleanup(
        process_create(path(opencode), ['session', 'list', '--format', 'json'], [stdout(pipe(Out)), stderr(null)]),
        (
            json_read_dict(Out, Sessions),
            member(Session, Sessions),
            get_dict(id, Session, ID)
        ),
        close(Out)
    ),
    format(user_error, "DEBUG: Session ~w found~n", [ID]),
    !.
session_exists(ID) :-
    format(user_error, "DEBUG: Session ~w not found~n", [ID]),
    fail.

create_agent_file(AgentFile, TempFile) :-
    read_file_to_string('AGENTS_LE_template.md', Template, []),
    setup_call_cleanup(
        open(AgentFile, write, Stream),
        format(Stream, Template, [TempFile, TempFile, TempFile, TempFile]),
        close(Stream)
    ).
