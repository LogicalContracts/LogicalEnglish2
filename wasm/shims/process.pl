/** <module> library(process), for a machine with no processes

    A browser tab cannot start a program. Two modules import this library and
    both mean the same thing by it: the LE Assistant (le_assistant.pl) and the
    Contract Assistant (le_contract_assistant.pl) run `opencode` as a child
    process and read its output.

    Neither can work here, and neither should pretend to. The refusal is an
    existence error on the executable, which is what these modules already
    handle: a machine without `opencode` installed is a case the server build
    has always had to answer for.
*/

:- module(process, [
    process_create/3,           % +Exe, +Args, +Options
    process_wait/2,             % +PID, -Status
    process_wait/3,             % +PID, +Status, +Options
    process_kill/1,             % +PID
    process_kill/2,             % +PID, +Signal
    process_id/1                % -PID
    ]).

process_create(Exe, _Args, _Options) :-
    throw(error(existence_error(source_sink, Exe),
                context(process:process_create/3,
                        'a WebAssembly build cannot start a program'))).

process_wait(_PID, exit(1)).
process_wait(_PID, exit(1), _Options).
process_kill(_PID).
process_kill(_PID, _Signal).
process_id(0).
