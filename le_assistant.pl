:- module(le_assistant, [handle_assistant_command/2, handle_assistant_status/2, handle_assistant_interrupt/2, get_most_recent_opencode_session/2, normalize_path/2]).

:- use_module(library(readutil)).
:- use_module(library(process)).
:- use_module(library(http/http_client)).
:- use_module(library(http/http_json)).
:- use_module(library(http/json)).
:- use_module(library(pcre)).
:- use_module(llm/llm_client, [llm_model/3]).

:- dynamic assistant_file_counter/1.
assistant_file_counter(1).

:- dynamic assistant_job/2.        % JobID, PID
:- dynamic assistant_job_output/3. % JobID, Stream, Text
:- dynamic assistant_job_status/2. % JobID, Status
:- dynamic assistant_job_content/2. % JobID, NewContent (after completion)

normalize_path(P, N) :-
    ( atom(P) -> A = P ; atom_string(A, P) ),
    % Remove /private prefix if present (macOS symlink)
    ( sub_atom(A, 0, 8, _, "/private") ->
        sub_atom(A, 8, _, 0, N0)
    ; N0 = A
    ),
    % Replace multiple slashes with single slash and remove trailing slash
    split_string(N0, "/", "/", Parts),
    exclude(==(""), Parts, CleanParts),
    atomic_list_concat(CleanParts, "/", Path),
    ( sub_atom(N0, 0, 1, _, "/") -> atom_concat('/', Path, N) ; N = Path ),
    !.

opencode_server_url(URL) :-
    getenv('OPENCODE_SERVER_URL', URL0),
    atom_string(URL, URL0).

opencode_api_get('/sessions', Sessions) :-
    catch(
        setup_call_cleanup(
            process_create(path(opencode), ['session', 'list', '--format', 'json'], [stdout(pipe(Out))]),
            json_read_dict(Out, Sessions),
            close(Out)
        ),
        Error,
        (format(user_error, "DEBUG: CLI session list failed: ~w~n", [Error]), fail)
    ),
    !.

opencode_api_get(Path, Result) :-
    opencode_server_url(Base),
    atomic_list_concat([Base, Path], URL),
    http_get(URL, Result, [json_object(dict)]).

opencode_api_post(Path, Data, Result) :-
    ( Path == '/run' -> fail ; true ), % We use CLI for /run
    opencode_server_url(Base),
    atomic_list_concat([Base, Path], URL),
    http_post(URL, json(Data), Result, [json_object(dict)]).

opencode_api_delete(Path, Result) :-
    opencode_server_url(Base),
    atomic_list_concat([Base, Path], URL),
    http_delete(URL, Result, [json_object(dict)]).

paths_match(P1, P2) :-
    normalize_path(P1, N1),
    normalize_path(P2, N2),
    N1 == N2.

get_opencode_env(Env) :-
    findall(Name-SVal, (
        member(Var, ['PATH', 'HOME', 'USER', 'SHELL']),
        getenv(Var, SVal),
        Name = Var
    ), BaseEnv),
    absolute_file_name('llm/settings/opencode_config.json', MCPConfig, [access(read), expand(true)]),
    Pairs = ['TERM'-"dumb", 'PAGER'-"cat", 'NO_COLOR'-"1", 'OPENCODE_CONFIG'-MCPConfig | BaseEnv],
    dict_pairs(Env, env, Pairs).

get_directory_for_session(SessionID, Directory) :-
    catch(
        opencode_api_get('/sessions', Sessions),
        _,
        fail
    ),
    atom_string(ASID, SessionID),
    member(Session, Sessions),
    get_dict(id, Session, SID),
    atom_string(ASID_check, SID),
    ASID == ASID_check,
    get_dict(directory, Session, Directory),
    !.

%!  get_most_recent_opencode_session(+Dir, -SessionID) is semidet.
%
%   Finds the most recently updated opencode session ID for the given directory.
get_most_recent_opencode_session(Dir, SessionID) :-
    normalize_path(Dir, NormalizedDir),
    catch(
        opencode_api_get('/sessions', Sessions),
        Error,
        (format(user_error, "DEBUG: Error listing sessions: ~w~n", [Error]), fail)
    ),
    % Filter sessions that match our normalized directory
    findall(S, (
        member(S, Sessions),
        get_dict(directory, S, SDir),
        normalize_path(SDir, NormalizedSDir),
        ( NormalizedSDir == NormalizedDir ->
            true
        ; fail
        )
    ), AssistantSessions),
    ( AssistantSessions == [] ->
        format(user_error, "DEBUG: No sessions found matching directory ~w (normalized: ~w)~n", [Dir, NormalizedDir]),
        fail
    ; true
    ),
    % Map to pairs of (Updated, Session) for sorting
    maplist(session_to_pair, AssistantSessions, Pairs),
    % Sort by Updated timestamp (ascending)
    keysort(Pairs, SortedPairs),
    % Get the last one (most recent)
    last(SortedPairs, _-MostRecent),
    get_dict(id, MostRecent, SessionID).

session_to_pair(Session, Updated-Session) :-
    get_dict(updated, Session, Updated).

session_exists(ID) :-
    get_directory_for_session(ID, _).

assistant_work_dir(AbsDir) :-
    Base = "/tmp/le_assistant",
    ( exists_directory(Base) -> true ; make_directory(Base) ),
    absolute_file_name(Base, AbsDir0, [file_type(directory)]),
    normalize_path(AbsDir0, AbsDir).

get_next_id(ID) :-
    with_mutex(assistant_id_gen, (
        assistant_file_counter(ID),
        NextID is ID + 1,
        retractall(assistant_file_counter(_)),
        asserta(assistant_file_counter(NextID))
    )).

%!  handle_assistant_command(+Dict, -Response) is det.
%
%   Starts a command for the LE Assistant and returns a JobID.
handle_assistant_command(Dict, Response) :-
    format(user_error, "DEBUG: Entering handle_assistant_command~n", []),
    ( get_dict(command, Dict, Command) -> true ; Command = "" ),
    ( get_dict(content, Dict, Content) -> true ; Content = "" ),
    ( get_dict(session_id, Dict, SessionID0) -> 
        atom_string(ASID0, SessionID0),
        ( sub_atom(ASID0, 0, 3, _, ses) -> SessionID = ASID0 ; atom_concat(ses, ASID0, SessionID) )
    ; SessionID = "ses_default" ),
    format(user_error, "DEBUG: Incoming session_id: ~w~n", [SessionID]),
    ( get_dict(api_keys, Dict, APIKeys) -> true ; APIKeys = _{} ),
    ( get_dict(model, Dict, Model) -> true ; Model = "" ),
    
    assistant_work_dir(BaseDir),
    
    % Determine WorkDir and ActualSessionID
    ( (string_length(SessionID, Len), Len > 20, get_directory_for_session(SessionID, RealDir)) ->
        ActualSessionID = SessionID,
        WorkDir = RealDir,
        format(user_error, "DEBUG: Continuing opencode session ~w in directory ~w~n", [ActualSessionID, WorkDir])
    ; % Bogus ID or first request or editor hasn't updated yet
      format(string(WorkDir0), "~w/~w", [BaseDir, SessionID]),
      normalize_path(WorkDir0, WorkDir),
      ( exists_directory(WorkDir) -> true ; make_directory(WorkDir) ),
      ( get_most_recent_opencode_session(WorkDir, RealSessionID) ->
          ActualSessionID = RealSessionID,
          format(user_error, "DEBUG: Discovered real session ~w for conversation ~w~n", [ActualSessionID, SessionID])
      ; (string_length(SessionID, Len2), Len2 > 20) ->
          ActualSessionID = SessionID,
          format(user_error, "DEBUG: Using provided long session_id ~w for conversation ~w~n", [ActualSessionID, SessionID])
      ; ActualSessionID = "ses_default",
        format(user_error, "DEBUG: Starting/Continuing conversation ~w in directory ~w~n", [SessionID, WorkDir])
      )
    ),

    % Create a temporary file for the editor content
    get_next_id(ID),
    format(string(JobID), "job_~w", [ID]),
    
    RelTempFile = "myProgram.le",
    format(string(TempFile), "~w/~w", [WorkDir, RelTempFile]),
    format(string(AgentFile), "~w/AGENTS.md", [WorkDir]),
    
    setup_call_cleanup(
        open(TempFile, write, Stream),
        write(Stream, Content),
        close(Stream)
    ),
    
    % Prepare environment variables
    get_opencode_env(BaseEnvDict),
    
    % Ensure OPENCODE_LOG_LEVEL is set to DEBUG for better error reporting
    put_dict(BaseEnvDict, _{'OPENCODE_LOG_LEVEL': "DEBUG"}, Env0),
    
    findall(Name-SVal, (
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
            ( (ActualProvider == groq, APIModel == 'llama-3.3-70b-versatile') ->
                OpencodeModel = 'groq/llama-3.3-70b-specdec' % Use specdec for better compatibility
            ; format(atom(OpencodeModel), "~w/~w", [ActualProvider, APIModel])
            )
        ;   OpencodeModel = Model % Fallback to original if not found
        )
    ;   OpencodeModel = ""
    ),
    
    % Special case: if model is groq/openai/gpt-oss-120b, ensure GROQ_API_KEY is set
    (   sub_atom(OpencodeModel, _, _, _, 'groq/')
    ->  ( get_dict(openai, APIKeys, GKey), GKey \== null, GKey \== "" -> 
            to_atom_or_string(GKey, SGKey),
            ExtraEnv = ['GROQ_API_KEY'-SGKey]
        ; ExtraEnv = [] )
    ;   ExtraEnv = []
    ),
    
    dict_pairs(APIEnvDict, env, APIEnv),
    dict_pairs(ExtraEnvDict, env, ExtraEnv),
    put_dict(Env0, APIEnvDict, Env1),
    put_dict(Env1, ExtraEnvDict, Env),
    
    create_agent_file(AgentFile, RelTempFile),

    % Prepare opencode arguments
    maplist(to_atom_or_string, [ActualSessionID, RelTempFile], [ASessionID, ARelTempFile]),
    format(user_error, "DEBUG: Final ActualSessionID: ~w~n", [ASessionID]),

    asserta(assistant_job(JobID, JobID)), % Use JobID as RemoteJobID for local tracking
    asserta(assistant_job_status(JobID, running)),
    
    % Start a thread to run the opencode CLI
    thread_create(run_job_cli(JobID, ASessionID, ARelTempFile, OpencodeModel, Command, Env, WorkDir, TempFile, Content), _, [detached(true)]),
    
    Response = _{
        result: ok,
        job_id: JobID
    }.

run_job_cli(JobID, ASessionID, RelTempFile, Model, Command, EnvDict, WorkDir, TempFile, OldContent) :-
    % Convert EnvDict to env([Name=Value, ...])
    dict_pairs(EnvDict, _, Pairs),
    maplist([N-V, N=V]>>true, Pairs, EnvList),
    
    % Prepare arguments
    BaseArgs = ['run', '--format', 'json', '--agent', 'build', '--file', RelTempFile],
    ( (Model \== "", Model \== null) -> Args1 = ['--model', Model | BaseArgs] ; Args1 = BaseArgs ),
    ( (ASessionID \== "ses_default", ASessionID \== "") -> Args2 = ['--session', ASessionID | Args1] ; Args2 = Args1 ),
    append(Args2, ['--', Command], FinalArgs),
    
    format(user_error, "DEBUG: Running opencode CLI: opencode ~w~n", [FinalArgs]),
    
    setup_call_cleanup(
        process_create(path(opencode), FinalArgs, [
            stdout(pipe(Out)),
            stderr(pipe(Err)),
            cwd(WorkDir),
            env(EnvList),
            process(PID)
        ]),
        (
            retractall(assistant_job(JobID, _)),
            asserta(assistant_job(JobID, PID)),
            % Read stdout and stderr in separate threads or sequentially if we don't care about interleaving
            read_string(Err, _, Stderr),
            read_stdout_events(Out, JobID, ASessionID, FinalSessionID),
            process_wait(PID, ExitStatus)
        ),
        (
            close(Out),
            close(Err)
        )
    ),
    
    % Read the updated content from the temp file
    ( exists_file(TempFile) ->
        read_file_to_string(TempFile, NewContent, [])
    ; NewContent = OldContent
    ),
    
    asserta(assistant_job_output(JobID, stderr, Stderr)),
    asserta(assistant_job_output(JobID, session_id, FinalSessionID)),
    asserta(assistant_job_content(JobID, NewContent)),
    
    retractall(assistant_job_status(JobID, _)),
    ( ExitStatus = exit(0) -> Status = finished(0) ; Status = finished(1) ),
    asserta(assistant_job_status(JobID, Status)).

read_stdout_events(Stream, JobID, DefaultSID, FinalSID) :-
    read_line_to_string(Stream, Line),
    ( Line == end_of_file ->
        FinalSID = DefaultSID
    ; ( catch(atom_json_dict(Line, Dict, []), _, fail) ->
        ( get_dict(type, Dict, "text") ->
            get_dict(part, Dict, Part),
            get_dict(text, Part, Text),
            assertz(assistant_job_output(JobID, stdout, Text))
        ; true
        ),
        ( get_dict(sessionID, Dict, SID) -> NextSID = SID ; NextSID = DefaultSID )
      ; % Not JSON, just append to stdout
        assertz(assistant_job_output(JobID, stdout, Line)),
        assertz(assistant_job_output(JobID, stdout, "\n")),
        NextSID = DefaultSID
      ),
      read_stdout_events(Stream, JobID, NextSID, FinalSID)
    ).

poll_job(_JobID, _RemoteJobID, _ASessionID, _OldContent) :-
    % No longer used, but kept for compatibility if needed
    true.


%!  handle_assistant_status(+Dict, -Response) is det.
handle_assistant_status(Dict, Response) :-
    get_dict(job_id, Dict, JobID),
    (   assistant_job_status(JobID, Status)
    ->  findall(L, assistant_job_output(JobID, stdout, L), StdoutLines),
        findall(L, assistant_job_output(JobID, stderr, L), StderrLines),
        atomic_list_concat(StdoutLines, "", Stdout0),
        atomic_list_concat(StderrLines, "", Stderr0),
        strip_ansi(Stdout0, Stdout),
        strip_ansi(Stderr0, Stderr),
        string_length(Stdout, StdoutLen),
        string_length(Stderr, StderrLen),
        format(user_error, "DEBUG: Job ~w status: ~w. Stdout len: ~w, Stderr len: ~w~n", [JobID, Status, StdoutLen, StderrLen]),
        
        (   Status = finished(ExitStatus)
        ->  ( assistant_job_content(JobID, NewContent) -> true ; NewContent = "" ),
            ( assistant_job_output(JobID, session_id, SID) -> ActualSID = SID ; ActualSID = "" ),
            format(user_error, "DEBUG: Returning session_id to client: ~w~n", [ActualSID]),
            
            (   extract_json_from_string(Stdout, JSONDict, StdoutWithoutJSON)
            ->  ( get_dict(explanation, JSONDict, Explanation) -> 
                    ( (var(StdoutWithoutJSON) ; string_length(StdoutWithoutJSON, 0) ; catch(normalize_space(atom(""), StdoutWithoutJSON), _, fail)) -> 
                        FinalStdout = Explanation 
                    ; ( paths_match(StdoutWithoutJSON, Explanation) ->
                        FinalStdout = Explanation
                      ; format(string(FinalStdout), "~w\n\n~w", [StdoutWithoutJSON, Explanation])
                      )
                    )
                ; FinalStdout = StdoutWithoutJSON
                ),
                ( get_dict(new_content, JSONDict, ContentFromJson) -> FinalNewContent = ContentFromJson ; FinalNewContent = NewContent )
            ;   FinalStdout = Stdout, FinalNewContent = NewContent
            ),
            
            Response = _{
                result: ok,
                status: finished,
                exit_status: ExitStatus,
                stdout: FinalStdout,
                stderr: Stderr,
                new_content: FinalNewContent,
                session_id: ActualSID
            }
        ;   Response = _{
                result: ok,
                status: running,
                stdout: Stdout,
                stderr: Stderr
            }
        )
    ;   Response = _{result: error, error: "Job not found"}
    ).

%!  handle_assistant_interrupt(+Dict, -Response) is det.
handle_assistant_interrupt(Dict, Response) :-
    get_dict(job_id, Dict, JobID),
    (   assistant_job(JobID, PID)
    ->  ( assistant_job_status(JobID, running) ->
            ( integer(PID) ->
                process_kill(PID, sigterm),
                Response = _{result: ok, message: "Job interrupted"}
            ; % Fallback to API if it was a remote job (though we switched to local)
              format(string(Path), "/jobs/~w/interrupt", [PID]),
              ( catch(opencode_api_post(Path, _{}, _), _, fail) ->
                  Response = _{result: ok, message: "Job interrupted"}
              ;   Response = _{result: error, error: "Failed to interrupt job"}
              )
            )
        ;   Response = _{result: ok, message: "Job already finished"}
        )
    ;   Response = _{result: error, error: "Job not found"}
    ).

extract_json_from_string(String, Dict, Remaining) :-
    String \== "",
    (   % Try with code block first. Greedy match for the JSON content.
        re_matchsub("(?s)```json\\s*(\\{.*\\})\\s*```", String, Sub)
    ->  get_dict(1, Sub, JSONStr),
        get_dict(0, Sub, FullMatch)
    ;   % Try without code block. Greedy match from first { to last }.
        re_matchsub("(?s)(\\{.*\\})", String, Sub)
    ->  get_dict(1, Sub, JSONStr),
        get_dict(0, Sub, FullMatch)
    ;   fail
    ),
    catch(atom_json_dict(JSONStr, Dict, []), _, fail),
    % Remove the full match from the string using sub_string to be safe
    (   sub_string(String, Before, _Len, After, FullMatch)
    ->  sub_string(String, 0, Before, _, Preamble),
        sub_string(String, _, After, 0, Postamble),
        format(string(Remaining0), "~w~w", [Preamble, Postamble]),
        (   (var(Remaining0) ; string_length(Remaining0, 0))
        ->  Remaining = ""
        ;   catch(normalize_space(atom(Remaining), Remaining0), _, Remaining = Remaining0)
        )
    ;   Remaining = String
    ).

strip_ansi(In, Out) :-
    (   catch(re_replace("\\x1b\\[[0-9;]*[mK]"/g, "", In, Out0), _, fail)
    ->  Out = Out0
    ;   Out = In
    ).

to_atom_or_string(X, X) :- (atom(X) ; string(X)), !.
to_atom_or_string(X, S) :- term_string(X, S).

create_agent_file(AgentFile, RelTempFile) :-
    working_directory(CWD, CWD),
    format(string(TemplatePath), "~w/AGENTS_LE_template.md", [CWD]),
    ( exists_file(TemplatePath) -> 
        read_file_to_string(TemplatePath, Template, [])
    ; read_file_to_string('AGENTS_LE_template.md', Template, [])
    ),
    setup_call_cleanup(
        open(AgentFile, write, Stream),
        format(Stream, Template, [RelTempFile, RelTempFile, RelTempFile, RelTempFile]),
        close(Stream)
    ).
