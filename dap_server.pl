/** <module> DAP Server for Logical English
    
    This module implements a minimal Debug Adapter Protocol (DAP) server
    for Logical English, running within the SWI-Prolog process.
*/

:- module(dap_server, [dap_websocket_handler/1, dap_tracer_hook/6]).

:- use_module(library(http/websocket)).
:- use_module(library(http/json)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_client)).
:- use_module(library(http/http_host)).
:- use_module(library(http/html_write)).
:- use_module(library(debug)).

:- dynamic dap_session/3. % SM, WebSocket, ThreadID
:- dynamic breakpoint/2. % Module, Line
:- dynamic stopped_state/5. % ID, Goal, SM, Anc, Depth

% Test seam: when dap_test_capture is set, the tracer records each stop as
% dap_test_stop(Port, Goal, Anc) and auto-continues (no websocket), so the trace
% behaviour can be checked from a plunit test. Never set in production.
:- dynamic dap_test_capture/0.
:- dynamic dap_test_stop/3.

% Enable DAP debugging
:- debug(dap).

% Tracer hook — runs in interpreter thread
dap_tracer_hook(Port, SM, Goal, ID, Anc, Depth) :-
    dap_test_capture, !,
    ( should_stop(Port, SM, Goal, ID, Anc, Depth)
    ->  assertz(dap_test_stop(Port, Goal, Anc))
    ;   true
    ).
dap_tracer_hook(Port, SM, Goal, ID, Anc, Depth) :-
    catch(
        (   should_stop(Port, SM, Goal, ID, Anc, Depth)
        ->  debug(dap, 'Tracer stop at ~w: ~w', [Port, Goal]),
            retractall(stopped_state(_, _, SM, _, _)),
            assertz(stopped_state(ID, Goal, SM, Anc, Depth)),
            build_stopped_event(Port, ID, Event),
            (   send_dap_event(SM, Event)
            ->  debug(dap, 'Waiting for command for session ~w...', [SM]),
                wait_for_command(SM, Command),
                debug(dap, 'Received command: ~w', [Command]),
                execute_command(Command, SM, Goal, ID, Anc, Depth)
            ;   debug(dap, 'Failed to send event, disabling debug for ~w', [SM]),
                retractall(SM:debug_mode)
            )
        ;   true
        ),
        E,
        (debug(dap, 'Error in tracer hook: ~w', [E]), true)
    ).

should_stop(call, _SM, _Goal, _ID, _Anc, _Depth) :- !.
should_stop(fail, _SM, _Goal, _ID, _Anc, _Depth) :- !.
should_stop(exit, _SM, _Goal, _ID, _Anc, _Depth) :- !.
should_stop(exception(_), _SM, _Goal, _ID, _Anc, _Depth) :- !.

build_stopped_event(Port, _ID, _{
    type: event,
    event: stopped,
    body: _{
        reason: Reason,
        threadId: 1,
        preserveFocusHint: false,
        allThreadsStopped: true
    }
}) :-
    port_to_reason(Port, Reason).

port_to_reason(call, step).
port_to_reason(exit, step).
port_to_reason(fail, step).
port_to_reason(exception(_), exception).

send_dap_event(SM, Event) :-
    dap_session(SM, WS, _),
    catch(ws_send(WS, json(Event)), E, (debug(dap, 'ws_send failed: ~w', [E]), fail)).

% Maximum seconds to wait for the next DAP command before treating the trace as
% abandoned. This bound is essential: the traced query runs on an HTTP worker
% thread and blocks here until a command arrives over the websocket, so without a
% timeout an abandoned trace (closed tab, dropped socket, paused-and-forgotten)
% would hold that worker forever and, after enough of them, exhaust the whole
% worker pool — making the server stop responding to all requests.
dap_command_timeout(300).

wait_for_command(SM, Command) :-
    format(atom(Queue), 'dap_commands_~w', [SM]),
    dap_command_timeout(Timeout),
    (   catch(thread_get_message(Queue, Msg, [timeout(Timeout)]), E,
              (debug(dap, 'thread_get_message failed: ~w', [E]), fail))
    ->  Command = Msg
    ;   % Timed out or the queue is gone: abandon the trace and free the worker.
        debug(dap, 'No DAP command for ~w within ~w s; abandoning trace', [SM, Timeout]),
        Command = disconnect
    ).

execute_command(continue, _, _, _, _, _) :- !.
execute_command(stepIn, _, _, _, _, _) :- !.
execute_command(next, _, _, _, _, _) :- !.
execute_command(disconnect, SM, _, _, _, _) :-
    retractall(SM:debug_mode),
    throw(dap_disconnect).

% WebSocket Handler
dap_websocket_handler(Request) :-
    (   http_parameters(Request, [sessionModule(SMStr, [])])
    ->  atom_string(SM, SMStr)
    ;   SM = unknown
    ),
    debug(dap, 'New WebSocket connection for session ~w', [SM]),
    http_upgrade_to_websocket(dap_loop(SM), [], Request).

dap_loop(SM, WebSocket) :-
    thread_self(Me),
    retractall(dap_session(SM, _, _)),
    assertz(dap_session(SM, WebSocket, Me)),
    format(atom(Queue), 'dap_commands_~w', [SM]),
    (   catch(message_queue_create(Queue), _, true)
    ->  true
    ;   message_queue_destroy(Queue),
        message_queue_create(Queue)
    ),
    catch(
        dap_receive_loop(SM, WebSocket),
        dap_disconnect,
        debug(dap, 'DAP session ~w disconnected', [SM])
    ),
    % Wake any traced query still blocked in wait_for_command/2 so its HTTP
    % worker thread is released immediately, rather than only after the timeout.
    catch(thread_send_message(Queue, disconnect), _, true),
    message_queue_destroy(Queue),
    retractall(dap_session(SM, WebSocket, Me)).

dap_receive_loop(SM, WebSocket) :-
    ws_receive(WebSocket, Message),
    (   Message == end_of_file
    ->  true
    ;   debug(dap, 'Received WebSocket message: ~w', [Message]),
        handle_dap_message(SM, Message, WebSocket),
        dap_receive_loop(SM, WebSocket)
    ).

handle_dap_message(SM, Message, WS) :-
    (   Message = json(Dict) -> handle_request(SM, Dict, WS)
    ;   Message = text(Data) -> 
        (   catch(atom_json_dict(Data, Dict, []), _, fail)
        ->  handle_request(SM, Dict, WS)
        ;   true
        )
    ;   is_dict(Message, websocket) -> 
        get_dict(data, Message, Data),
        (   get_dict(opcode, Message, text)
        ->  (   catch(atom_json_dict(Data, Dict, []), _, fail)
            ->  handle_request(SM, Dict, WS)
            ;   true
            )
        ;   true
        )
    ;   Message = close(_, _) -> throw(dap_disconnect)
    ;   true
    ).

handle_request(SM, Dict, WS) :-
    get_dict(command, Dict, Command0),
    (   atom(Command0) -> Command = Command0 ; atom_string(Command, Command0) ),
    get_dict(seq, Dict, Seq),
    debug(dap, 'Handling request ~w: ~w', [Seq, Command]),
    (   catch(handle_command(SM, Command, Dict, Body), E, (debug(dap, 'Error handling ~w: ~w', [Command, E]), fail))
    ->  Reply = _{
            type: response,
            request_seq: Seq,
            success: true,
            command: Command,
            body: Body
        }
    ;   Reply = _{
            type: response,
            request_seq: Seq,
            success: false,
            command: Command,
            message: "Command failed"
        }
    ),
    debug(dap, 'Sending response for ~w', [Command]),
    ws_send(WS, json(Reply)).

% --- DAP Command Handlers ---

handle_command(_SM, initialize, _Dict, _{
    supportsConfigurationDoneRequest: true,
    supportsStepBack: false
}).

handle_command(_SM, launch, _Dict, _{}).

handle_command(_SM, setBreakpoints, Dict, _{breakpoints: BPs}) :-
    get_dict(arguments, Dict, Args),
    get_dict(source, Args, Source),
    get_dict(path, Source, Path),
    get_dict(breakpoints, Args, RequestedBPs),
    maplist(verify_breakpoint(Path), RequestedBPs, BPs).

handle_command(SM, stackTrace, _Dict, _{
    stackFrames: Frames,
    totalFrames: Count
}) :-
    (   stopped_state(ID, Goal, SM, Anc, _Depth)
    ->  build_frames(ID, Goal, SM, Anc, Frames),
        length(Frames, Count)
    ;   debug(dap, 'stackTrace requested but no stopped_state for ~w', [SM]),
        Frames = [], Count = 0
    ).

% Scopes for a frame: one "Local" scope whose variablesReference is the frame's
% own index (echoed from the request), so `variables` can report that frame's args.
handle_command(_SM, scopes, Dict, _{
    scopes: [
        _{ name: "Local", variablesReference: Ref, expensive: false }
    ]
}) :-
    (   get_dict(arguments, Dict, Args), get_dict(frameId, Args, FrameId), integer(FrameId)
    ->  Ref = FrameId
    ;   Ref = 1
    ).

handle_command(SM, variables, Dict, _{
    variables: Vars
}) :-
    (   get_dict(arguments, Dict, VArgs), get_dict(variablesReference, VArgs, Ref0),
        ( integer(Ref0) -> Ref = Ref0 ; atom_number(Ref0, Ref) )
    ->  true
    ;   Ref = 1
    ),
    (   stopped_state(_ID, Goal, SM, Anc, _Depth)
    ->  ( SM:le_kb_module_fact(KB) -> true ; KB = none ),
        FrameGoals = [Goal | Anc],
        ( nth1(Ref, FrameGoals, FG) -> true ; FG = Goal ),
        frame_variables(KB, FG, Vars)
    ;   Vars = []
    ).

handle_command(SM, continue, _Dict, _{}) :-
    format(atom(Queue), 'dap_commands_~w', [SM]),
    thread_send_message(Queue, continue).

handle_command(SM, stepIn, _Dict, _{}) :-
    format(atom(Queue), 'dap_commands_~w', [SM]),
    thread_send_message(Queue, stepIn).

handle_command(SM, next, _Dict, _{}) :-
    format(atom(Queue), 'dap_commands_~w', [SM]),
    thread_send_message(Queue, next).

handle_command(SM, disconnect, _Dict, _{}) :-
    format(atom(Queue), 'dap_commands_~w', [SM]),
    thread_send_message(Queue, disconnect).

% --- Helpers ---

verify_breakpoint(_Path, BP, _{verified: true, line: Line}) :-
    get_dict(line, BP, Line).

% The call-stack frames, ordered innermost-first (DAP convention): the current
% goal is frame 1, its caller frame 2, ... the root query last. The UI renders them
% top-down (root at the top). Each frame's variablesReference equals its 1-based
% index, so the variables request can resolve which frame's variables to report.
build_frames(_ID, Goal, SM, Anc, Frames) :-
    ( SM:le_kb_module_fact(KB) -> true ; KB = none ),
    FrameGoals = [Goal | Anc],
    findall(Frame,
            ( nth1(Idx, FrameGoals, FG), build_one_frame(Idx, FG, SM, KB, Frame) ),
            Frames).

build_one_frame(Idx, FG, SM, KB, Frame) :-
    (   catch(build_one_frame_unsafe(Idx, FG, SM, KB, Frame), E,
              (debug(dap, 'build_one_frame failed: ~w', [E]), fail))
    ->  true
    ;   term_string(FG, Name),
        Frame = _{ id: Idx, name: Name, offset: 0, endOffset: 0, column: 1,
                   variablesReference: Idx, source: _{ name: "prolog", path: "/main.le" } }
    ).

build_one_frame_unsafe(Idx, FG, SM, KB, _{
    id: Idx,
    name: Name,
    offset: Offset,
    endOffset: EndOffset,
    column: 1,
    variablesReference: Idx,
    source: _{ name: SourceName, path: "/main.le" }
}) :-
    frame_name(KB, FG, Name),
    frame_source_name(KB, SourceName),
    frame_offsets(FG, SM, KB, Offset, EndOffset).

frame_name(KB, FG, Name) :-
    (   KB \== none, le_kbs:item_to_instance(KB, FG, Tokens)
    ->  le_kbs:canonical_string(Tokens, Name)
    ;   term_string(FG, Name)
    ).

frame_source_name(KB, SourceName) :-
    (   KB \== none, current_predicate(KB:le_kb/1), KB:le_kb(KBName)
    ->  ( atom(KBName) -> atom_concat(KBName, '.le', SourceName) ; SourceName = KBName )
    ;   SourceName = "document.le"
    ).

% A goal wrapped as le_at(_, Start, End) carries its CALL-SITE source range, which
% is what we want to highlight (where the goal is written in the rule/query). Bare
% goals fall back to the range of the clause that would prove them.
frame_offsets(le_at(_, Start, End), _SM, _KB, Start, End) :- !.
frame_offsets(Goal, SM, KB, Offset, EndOffset) :-
    (   ( clause(SM:Goal, _, Ref) ; (KB \== none, clause(KB:Goal, _, Ref)) ),
        ( SM:le_source_info(Ref, Offset, EndOffset, _)
        ; KB \== none, KB:le_source_info(Ref, Offset, EndOffset, _) )
    ->  true
    ;   Offset = 0, EndOffset = 0
    ).

% frame_variables(+KB, +FrameGoal, -Vars): the goal's arguments as name/value
% pairs, named by their template variable type ("a payment", "a claim") and valued
% by their CURRENT binding (rendered in LE). Because the frame goals hold the live
% reasoner variables, a variable shown here becomes bound as deeper steps unify it.
frame_variables(KB, FG0, Vars) :-
    ( FG0 = le_at(FG, _, _) -> true ; FG = FG0 ),
    ( goal_arg_bindings(KB, FG, Vars) -> true ; Vars = [] ).

goal_arg_bindings(KB, FG, Vars) :-
    callable(FG),
    FG =.. [F | Args], Args \== [],
    (   KB \== none,
        KB:le_dict(dict([F | Formal], NTs, _, _, _, _, _)),
        same_length(Formal, Args)
    ->  copy_term(Formal-NTs, FormalC-NTsC),
        maplist(arg_name_from_nt(NTsC), FormalC, Names),
        FormalC = Args,                       % bind formals to actuals (names kept)
        maplist(arg_dap_entry(KB), Names, Args, Vars)
    ;   findall(V,
                ( nth1(I, Args, A), format(atom(N), 'argument ~w', [I]), arg_dap_entry(KB, N, A, V) ),
                Vars)
    ).

arg_name_from_nt(NTsC, FVar, Name) :-
    (   member(V - Type, NTsC), V == FVar, atom(Type)
    ->  type_with_article(Type, Name)
    ;   Name = 'a value'
    ).

type_with_article(Type, Name) :-
    atom_codes(Type, [C | _]),
    ( memberchk(C, [0'a,0'e,0'i,0'o,0'u,0'A,0'E,0'I,0'O,0'U]) -> Art = an ; Art = a ),
    format(atom(Name), '~w ~w', [Art, Type]).

arg_dap_entry(KB, Name, Value, _{ name: Name, value: Str, variablesReference: 0 }) :-
    (   var(Value)
    ->  Str = "(unbound)"
    ;   atom(Value)
    ->  atom_string(Value, Str)          % render 'this payment' without quotes
    ;   string(Value)
    ->  Str = Value
    ;   KB \== none, compound(Value), \+ is_list(Value),
        catch(le_kbs:item_to_instance(KB, Value, Toks), _, fail)
    ->  le_kbs:canonical_string(Toks, Str)
    ;   term_string(Value, Str)
    ).
