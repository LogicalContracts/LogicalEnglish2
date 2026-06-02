/** <module> Logical English Assistant
    
    This module provides the backend for the Logical English Assistant.
    It manages background jobs that run 'opencode' to help users
    write and debug Logical English programs using LLMs.
*/

:- module(le_assistant, [handle_assistant_command/2, handle_assistant_status/2, handle_assistant_interrupt/2, get_most_recent_opencode_session/2, normalize_path/2, test_llm_providers/0, extract_json_from_string/3]).

:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_session)).
:- use_module(library(pcre)).
:- use_module(llm/llm_client, [llm_model/3]).
:- use_module(le_assistant_light).

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

paths_match(P1, P2) :-
    normalize_path(P1, N1),
    normalize_path(P2, N2),
    N1 == N2.

get_opencode_env(Env) :-
    get_opencode_env(_{}, Env).

get_opencode_env(APIKeys, Env) :-
    get_opencode_env(APIKeys, true, Env).

get_opencode_env(APIKeys, UseMCP, Env) :-
    findall(Name=SVal, (
        member(Var, ['PATH', 'HOME', 'USER', 'SHELL']),
        getenv(Var, SVal),
        Name = Var
    ), BaseEnv),
    get_api_env(APIKeys, APIEnv),
    ( UseMCP == true ->
        (   catch(get_dynamic_opencode_config(MCPConfig), _, fail)
        ->  ConfigEnv = ['OPENCODE_CONFIG'=MCPConfig]
        ;   absolute_file_name('llm/settings/opencode_config.json', MCPConfig, [access(read), expand(true)]),
            ConfigEnv = ['OPENCODE_CONFIG'=MCPConfig]
        )
    ; ConfigEnv = ['OPENCODE_CONFIG'='/dev/null']
    ),
    append(BaseEnv, APIEnv, Env0),
    append(ConfigEnv, Env0, Env1),
    Env = ['TERM'=dumb, 'PAGER'=cat, 'NO_COLOR'='1' | Env1].

get_dynamic_opencode_config(ConfigPath) :-
    absolute_file_name('llm/settings/opencode_config.json.template', TemplatePath, [access(read), expand(true)]),
    read_file_to_string(TemplatePath, Template, []),
    working_directory(CWD, CWD),
    % Remove trailing slash from CWD if present
    ( sub_atom(CWD, _, 1, 0, '/') -> sub_atom(CWD, 0, _, 1, CWD0) ; CWD0 = CWD ),
    re_replace("{{PROJECT_ROOT}}"/g, CWD0, Template, ConfigContent),
    assistant_work_dir(WorkDir),
    format(string(ConfigPath), "~w/opencode_config.json", [WorkDir]),
    setup_call_cleanup(
        open(ConfigPath, write, S),
        write(S, ConfigContent),
        close(S)
    ).

get_api_env(APIKeys, APIEnv) :-
    findall(Name=SVal, (
        member(Key-EnvVars, [
            openai-['OPENAI_API_KEY'], 
            anthropic-['ANTHROPIC_API_KEY'], 
            google-['GEMINI_API_KEY', 'GOOGLE_API_KEY', 'GOOGLE_GENERATIVE_AI_API_KEY'], 
            groq-['GROQ_API_KEY'], 
            together-['TOGETHER_API_KEY', 'TOGETHERAI_API_KEY']
        ]),
        (   (is_dict(APIKeys), get_dict(Key, APIKeys, Val), Val \== null, Val \== "")
        ->  to_atom_or_string(Val, SVal), member(Name, EnvVars)
        ;   member(EV, EnvVars), catch(getenv(EV, SVal), _, fail), Name = EV
        )
    ), APIEnv).

get_directory_for_session(SessionID, Directory) :-
    get_opencode_env(Env),
    catch(
        setup_call_cleanup(
            process_create(path(opencode), ['session', 'list', '--format', 'json'], [stdout(pipe(Out)), stderr(null), env(Env), cwd('/')]),
            (   at_end_of_stream(Out) -> Sessions = []
            ;   json_read_dict(Out, Sessions)
            ),
            close(Out)
        ),
        _,
        Sessions = []
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
    get_opencode_env(Env),
    catch(
        setup_call_cleanup(
            process_create(path(opencode), ['session', 'list', '--format', 'json'], [stdout(pipe(Out)), stderr(null), env(Env), cwd(Dir)]),
            (   at_end_of_stream(Out) -> Sessions = []
            ;   json_read_dict(Out, Sessions)
            ),
            close(Out)
        ),
        Error,
        (format(user_error, "DEBUG: Error listing sessions: ~w~n", [Error]), Sessions = [])
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
    ; % Sort by updated_at descending
      findall(Time-ID, (
          member(S, AssistantSessions),
          get_dict(id, S, ID),
          get_dict(updated_at, S, Time)
      ), Pairs),
      keysort(Pairs, Sorted),
      reverse(Sorted, [_-SessionID|_]),
      format(user_error, "DEBUG: Found most recent session ~w for directory ~w~n", [SessionID, Dir])
    ).


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
    ( get_dict(mode, Dict, Mode) -> true ; Mode = "deep" ),
    (   Mode == "light"
    ->  ( get_dict(command, Dict, Command) -> true ; Command = "" ),
        ( get_dict(content, Dict, Content) -> true ; Content = "" ),
        ( get_dict(api_keys, Dict, APIKeys) -> true ; APIKeys = _{} ),
        ( get_dict(model, Dict, Model) -> true ; Model = "" ),
        get_next_id(ID),
        format(string(JobID), "job_~w", [ID]),
        (   http_in_session(_SessionId), http_session_data(user(_, Roles)) -> UserRoles = Roles ; UserRoles = [] ),
        thread_create(le_assistant_light:run_light_assistant_thread(JobID, Command, Content, Model, APIKeys, UserRoles), ThreadID, [detached(true)]),
        asserta(assistant_job(JobID, ThreadID)),
        Response = _{
            result: ok,
            job_id: JobID
        }
    ;   ( get_dict(command, Dict, Command) -> true ; Command = "" ),
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
          ; ActualSessionID = "ses_default",
            format(user_error, "DEBUG: Starting/Continuing conversation ~w in directory ~w~n", [SessionID, WorkDir])
          )
        ),

        % Create a temporary file for the editor content
        get_next_id(ID),
        format(string(JobID), "job_~w", [ID]),
        
        RelTempFile = "myProgram.le",
        format(string(TempFile), "~w/~w", [WorkDir, RelTempFile]),
        
        setup_call_cleanup(
            open(TempFile, write, Stream),
            write(Stream, Content),
            close(Stream)
        ),
        
        % Resolve model to provider/model format for opencode
        (   (Model \== "", Model \== null)
        ->  ( llm_model(Model, Provider, APIModel) -> 
                ( Provider == gemini -> ActualProvider = google 
                ; Provider == together -> ActualProvider = togetherai
                ; ActualProvider = Provider 
                ),
                format(atom(OpencodeModel), "~w/~w", [ActualProvider, APIModel])
            ;   OpencodeModel = Model % Fallback to original if not found
            )
        ;   OpencodeModel = ""
        ),

        % Prepare environment variables
        get_opencode_env(APIKeys, BaseEnv),
        
        % Special case: if model is groq/openai/gpt-oss-120b, ensure GROQ_API_KEY is set
        (   sub_atom(OpencodeModel, _, _, _, 'groq/')
        ->  ( (is_dict(APIKeys), get_dict(openai, APIKeys, GKey), GKey \== null, GKey \== "") -> 
                to_atom_or_string(GKey, SGKey),
                ExtraEnv = ['GROQ_API_KEY'=SGKey]
            ; ExtraEnv = [] )
        ;   ExtraEnv = []
        ),
        
        append(ExtraEnv, BaseEnv, Env),
        
        create_agent_files(WorkDir, RelTempFile),

        % Prepare opencode arguments
        maplist(to_atom_or_string, [ActualSessionID, RelTempFile, OpencodeModel, Command], [ASessionID, ARelTempFile, AModel, ACommand]),
        format(user_error, "DEBUG: Final ActualSessionID: ~w~n", [ASessionID]),

        % Check if session exists
        (   (ASessionID \== "ses_default", ASessionID \== "default", ASessionID \== "", session_exists(ASessionID))
        ->  SessionArgs = ['--session', ASessionID],
            format(user_error, "DEBUG: Session ~w exists, adding --session flag~n", [ASessionID])
        ;   SessionArgs = [],
            format(user_error, "DEBUG: Session ~w does not exist or is default, skipping --session flag~n", [ASessionID])
        ),

        % Use 'build' agent as suggested, it should pick up CLAUDE.md or AGENTS.md
        BaseArgs = ['run', '--dangerously-skip-permissions' | SessionArgs],
        append(BaseArgs, ['--file', ARelTempFile, '--agent', 'build', '--format', 'default'], Args0),
        ( (AModel \== "", AModel \== null) -> append(Args0, ['--model', AModel, ACommand], Args) ; append(Args0, [ACommand], Args) ),
        
        format(user_error, "DEBUG: Starting background process: opencode ~w in ~w~n", [Args, WorkDir]),
        
        process_create(path(opencode), Args, [stdin(null), stdout(pipe(Out)), stderr(pipe(Err)), env(Env), cwd(WorkDir), process(PID)]),
        asserta(assistant_job(JobID, PID)),
        asserta(assistant_job_status(JobID, running)),
        
        % Start threads to read output
        thread_create(read_to_db(JobID, stdout, Out), _, [detached(true)]),
        thread_create(read_to_db(JobID, stderr, Err), _, [detached(true)]),
        
        % Start a thread to wait for the process
        thread_create(wait_for_job(JobID, PID, TempFile, ASessionID, Content, WorkDir), _, [detached(true)]),
        
        Response = _{
            result: ok,
            job_id: JobID
        }
    ).

read_to_db(JobID, StreamName, Stream) :-
    format(user_error, "DEBUG: read_to_db started for ~w ~w~n", [JobID, StreamName]),
    repeat,
    (   at_end_of_stream(Stream)
    ->  format(user_error, "DEBUG: read_to_db finished for ~w ~w~n", [JobID, StreamName]),
        catch(close(Stream), _, true), !
    ;   catch(read_pending_codes(Stream, Codes, []), E, (format(user_error, "DEBUG: read_to_db error: ~w~n", [E]), Codes = [])),
        (   Codes == []
        ->  sleep(0.1), fail
        ;   string_codes(String, Codes),
            assertz(assistant_job_output(JobID, StreamName, String)),
            fail
        )
    ).


wait_for_job(JobID, PID, TempFile, ASessionID, OldContent, WorkDir) :-
    process_wait(PID, Status),
    
    % After opencode runs, it might have modified TempFile.
    ( exists_file(TempFile) -> 
        ( catch(read_file_to_string(TempFile, NewContent, []), _, NewContent = OldContent) )
    ; NewContent = OldContent ),
    
    % We keep the files in the session directory to facilitate discovery
    asserta(assistant_job_content(JobID, NewContent)),
    
    % Give opencode a moment to sync its session database
    sleep(0.2),

    % Always obtain the most recent session ID for this directory after opencode runs
    % We MUST obtain it from the session list to get the real ID
    ( get_most_recent_opencode_session(WorkDir, RecentSID) ->
        ActualSID = RecentSID,
        format(user_error, "DEBUG: Discovered session ID for directory ~w: ~w~n", [WorkDir, ActualSID])
    ; ActualSID = ASessionID,
      format(user_error, "DEBUG: Could not discover session ID for directory ~w, using ~w~n", [WorkDir, ActualSID])
    ),
    asserta(assistant_job_output(JobID, session_id, ActualSID)),
    
    % FINALLY mark the job as finished, to avoid race conditions with status polling
    term_string(Status, StatusStr),
    retractall(assistant_job_status(JobID, _)),
    asserta(assistant_job_status(JobID, finished(StatusStr))).

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
        
        (   Status = finished(ExitStatus)
        ->  ( assistant_job_content(JobID, NewContent) -> true ; NewContent = "" ),
            ( assistant_job_output(JobID, session_id, SID) -> ActualSID = SID ; ActualSID = "" ),
            format(user_error, "DEBUG: Returning session_id to client: ~w~n", [ActualSID]),
            
            (   extract_json_from_string(Stdout, JSONDict, StdoutWithoutJSON),
                get_dict(explanation, JSONDict, Explanation)
            ->  ( (var(StdoutWithoutJSON) ; string_length(StdoutWithoutJSON, 0) ; catch(normalize_space(atom(""), StdoutWithoutJSON), _, fail)) -> 
                    FinalStdout = Explanation 
                ; ( paths_match(StdoutWithoutJSON, Explanation) ->
                    FinalStdout = Explanation
                  ; format(string(FinalStdout), "~w\n\n~w", [StdoutWithoutJSON, Explanation])
                  )
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
    (   assistant_job(JobID, Target)
    ->  ( assistant_job_status(JobID, running) ->
            (   integer(Target) -> % It's a PID
                catch(process_kill(Target, term), _, true)
            ;   % It's a thread ID/alias
                catch(thread_signal(Target, throw(interrupt)), _, true)
            ),
            Response = _{result: ok, message: "Job interrupted"}
        ;   Response = _{result: ok, message: "Job already finished"}
        )
    ;   Response = _{result: error, error: "Job not found"}
    ).

extract_json_from_string(String, Dict, Remaining) :-
    String \== "",
    (   % Try with code block first. Greedy match for the JSON content.
        re_matchsub("(?s)```json\\s*(\\{.*\\})\\s*```", String, Sub)
    ->  get_dict(1, Sub, JSONStr),
        get_dict(0, Sub, FullMatch),
        catch(atom_json_dict(JSONStr, Dict, []), _, fail)
    ;   % If no code block, find the last valid JSON block by searching from the end
        find_last_json_block(String, Dict, FullMatch)
    ),
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

find_last_json_block(String, Dict, FullMatch) :-
    % Find all occurrences of '{' in the string
    findall(Index, sub_string(String, Index, 1, _, "{"), Indices),
    % Reverse the indices to search from the end
    reverse(Indices, RevIndices),
    % Find the first index from the end that forms a valid JSON block
    member(Index, RevIndices),
    sub_string(String, Index, _, 0, Sub),
    string_length(Sub, SubLen),
    % Find all occurrences of '}' in Sub
    findall(After, sub_string(Sub, _, 1, After, "}"), Afters),
    % We want the smallest After first (which corresponds to the longest prefix)
    sort(Afters, SortedAfters),
    member(After, SortedAfters),
    Len is SubLen - After,
    sub_string(Sub, 0, Len, _, JSONStr),
    catch(atom_json_dict(JSONStr, Dict, []), _, fail),
    FullMatch = JSONStr,
    !.

strip_ansi(In, Out) :-
    (   catch(re_replace("\\x1b\\[[0-9;]*[mK]"/g, "", In, Out0), _, fail)
    ->  Out = Out0
    ;   Out = In
    ).

to_atom_or_string(X, X) :- (atom(X) ; string(X)), !.
to_atom_or_string(X, S) :- term_string(X, S).

create_agent_files(WorkDir, RelTempFile) :-
    working_directory(CWD, CWD),
    % Remove trailing slash from CWD if present
    ( sub_atom(CWD, _, 1, 0, '/') -> sub_atom(CWD, 0, _, 1, CWD0) ; CWD0 = CWD ),
    format(string(TemplatePath), "~w/AGENTS_LE_template.md", [CWD0]),
    ( exists_file(TemplatePath) -> 
        read_file_to_string(TemplatePath, Template, [])
    ; read_file_to_string('AGENTS_LE_template.md', Template, [])
    ),
    format(string(AgentFile), "~w/AGENTS.md", [WorkDir]),
    forall(member(F, [AgentFile]), (
        setup_call_cleanup(
            open(F, write, Stream),
            format(Stream, Template, [CWD0, CWD0, RelTempFile, RelTempFile, RelTempFile, RelTempFile]),
            close(Stream)
        )
    )).

%!  test_llm_providers is det.
%
%   Tests all available LLM providers with a simple prompt.
test_llm_providers :-
    findall(Provider, (
        member(Provider-EnvVars, [
            openai-['OPENAI_API_KEY'], 
            anthropic-['ANTHROPIC_API_KEY'], 
            google-['GEMINI_API_KEY', 'GOOGLE_API_KEY'], 
            groq-['GROQ_API_KEY'], 
            together-['TOGETHER_API_KEY', 'TOGETHERAI_API_KEY']
        ]),
        member(EV, EnvVars),
        getenv(EV, _)
    ), AvailableProviders0),
    sort(AvailableProviders0, AvailableProviders),
    ( AvailableProviders == [] -> 
        writeln("No API keys found in environment variables.")
    ; forall(member(P, AvailableProviders), (
        format("Testing provider: ~w~n", [P]),
        % Pick a model for this provider
        (   P == openai -> Model = 'gpt-4o-mini'
        ;   P == anthropic -> Model = 'claude'
        ;   P == google -> Model = 'gemini'
        ;   P == groq -> Model = 'openai/gpt-oss-120b'
        ;   P == together -> Model = 'deepseek-ai/DeepSeek-V4-Pro'
        ;   fail
        ),
        ( test_opencode_prompt(Model, "who are you? please answer in one sentence.", Answer) ->
            format("Answer from ~w (~w): ~w~n~n", [P, Model, Answer])
        ; format("Failed to get answer from ~w (~w)~n~n", [P, Model])
        )
      ))
    ).

test_opencode_prompt(Model, Prompt, Answer) :-
    assistant_work_dir(WorkDir),
    ( exists_directory(WorkDir) -> true ; make_directory(WorkDir) ),
    % Create a minimal config with providers but no MCP to avoid noise and ensure resolution
    format(string(ConfigPath), "~w/test_config.json", [WorkDir]),
    ConfigDict = _{
        provider: _{
            openai:    _{},
            anthropic: _{},
            groq:      _{},
            google:    _{},
            togetherai: _{options: _{baseURL: "https://api.together.xyz/v1"}}
        }
    },
    setup_call_cleanup(
        open(ConfigPath, write, S),
        json_write_dict(S, ConfigDict),
        close(S)
    ),
    get_opencode_env(_{}, false, Env0),
    % Override OPENCODE_CONFIG to our temp one
    ( select('OPENCODE_CONFIG'=_, Env0, 'OPENCODE_CONFIG'=ConfigPath, Env) -> true ; Env = ['OPENCODE_CONFIG'=ConfigPath | Env0] ),
    ( llm_model(Model, Provider, APIModel) -> 
        ( Provider == gemini -> ActualProvider = google 
        ; Provider == together -> ActualProvider = togetherai
        ; ActualProvider = Provider 
        ),
        format(atom(OpencodeModel), "~w/~w", [ActualProvider, APIModel])
    ; OpencodeModel = Model
    ),
    Args = ['run', '--dangerously-skip-permissions', '--agent', 'general', '--model', OpencodeModel, Prompt],
    format(user_error, "DEBUG: Running opencode ~w in ~w~n", [Args, WorkDir]),
    setup_call_cleanup(
        process_create(path(opencode), Args, [stdout(pipe(Out)), stderr(pipe(Err)), env(Env), cwd(WorkDir), process(PID)]),
        (   read_string(Out, _, Answer),
            read_string(Err, _, ErrMsg),
            process_wait(PID, Status),
            ( (Status \== exit(0), Answer == "") -> 
                format(user_error, "DEBUG: opencode failed with status ~w~n", [Status]),
                format(user_error, "DEBUG: stderr: ~w~n", [ErrMsg]),
                fail
            ; true )
        ),
        ( close(Out), close(Err) )
    ).
