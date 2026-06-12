/** <module> Unit tests for the start_api_server/1 port guard.

    Regression test for the silent double-start: on macOS/BSD http_server/2
    opens its socket with SO_REUSEADDR, so binding a port that another process
    already serves SUCCEEDS without error while that other process keeps the
    connections. start_api_server/1 now probes the port with a TCP connect first
    (port_in_use/1) and throws instead of starting an unreachable second server.

    Run with:  swipl -q -g run_tests -t halt testing/test_start_api_server.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_start_api_server, []).

:- use_module(library(plunit)).
:- use_module(library(socket)).
% classic_web_api.pl lives in the repo root, one level up from this file.
:- use_module('../classic_web_api').

% Open a listening socket on an OS-assigned (ephemeral) loopback port so the
% test never collides with a real service. Port is unified with the chosen port.
open_listener(Socket, Port) :-
    tcp_socket(Socket),
    tcp_setopt(Socket, reuseaddr),
    tcp_bind(Socket, '127.0.0.1':Port),
    tcp_listen(Socket, 5).

:- begin_tests(start_api_server).

% A port with a live listener is reported as in use.
test(detects_listener) :-
    open_listener(Socket, Port),
    setup_call_cleanup(
        true,
        assertion(classic_web_api:port_in_use(Port)),
        tcp_close_socket(Socket)
    ).

% Once the listener is gone the port is free again.
test(free_port_not_in_use) :-
    open_listener(Socket, Port),
    tcp_close_socket(Socket),
    assertion(\+ classic_web_api:port_in_use(Port)).

% start_api_server/1 refuses to start on an occupied port, raising a clear
% error BEFORE doing any setup or binding a second (dead) server.
test(start_api_server_rejects_busy_port) :-
    open_listener(Socket, Port),
    setup_call_cleanup(
        true,
        catch(classic_web_api:start_api_server(Port), Err, true),
        tcp_close_socket(Socket)
    ),
    assertion(nonvar(Err)),
    assertion(Err = error(le_server_error(port_in_use(Port)), _)).

:- end_tests(start_api_server).
