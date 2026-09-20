/** <module> library(time), for a system with no clock to interrupt it

    `library(time)` is missing from the WebAssembly image because everything
    in it is built on an alarm that fires on another thread, and there is only
    one thread. LE2 uses exactly one predicate of it — call_with_time_limit/2,
    eight times: the test runner, the s(CASP) runner, and the query the editor
    asks.

    The substitute bounds the goal by *inferences* instead of seconds, with
    call_with_inference_limit/3, and throws the very exception the real one
    throws. So the recovery code above it — `catch(..., time_limit_exceeded,
    Timeout = true)` in le_kbs.pl and le_scasp.pl — is entered exactly as it
    is on the server, and a runaway query in a browser tab still stops.

    What is lost, and it should be said plainly: inferences are not seconds.
    A goal that spends its time in one expensive built-in (a large sort, a
    regular expression) makes few inferences and can outlast its budget; a
    goal in a tight recursive loop is stopped early if the machine is faster
    than the flag below says. The flag is what makes that adjustable:

        ?- set_prolog_flag(le_wasm_inferences_per_second, 8 000 000).

    The default is deliberately generous (a browser tab that stops a legitimate
    30-second proof at 12 seconds is a worse bug than one that takes 45), and
    it is measured, not guessed: see wasm/README.md.
*/

:- module(time, [
    call_with_time_limit/2,     % +Seconds, :Goal
    alarm/3,                    % +Seconds, :Goal, -Id
    alarm/4,                    % +Seconds, :Goal, -Id, +Options
    remove_alarm/1              % +Id
    ]).

:- meta_predicate
    call_with_time_limit(+, 0),
    alarm(+, 0, -),
    alarm(+, 0, -, +).

%!  inferences_per_second(-N) is det.
inferences_per_second(N) :-
    (   current_prolog_flag(le_wasm_inferences_per_second, N0),
        integer(N0), N0 > 0
    ->  N = N0
    ;   N = 6_000_000
    ).

%!  call_with_time_limit(+Seconds, :Goal) is semidet.
%
%   As library(time)'s, within the limits above: once, and throwing
%   time_limit_exceeded when the budget runs out.
call_with_time_limit(Seconds, Goal) :-
    inferences_per_second(Rate),
    Limit is max(1000, truncate(Seconds * Rate)),
    %  once/1, because library(time)'s call_with_time_limit/2 is once/1 and
    %  call_with_inference_limit/3 is not: without it a caller could backtrack
    %  into a goal that the server would have committed to.
    call_with_inference_limit(once(Goal), Limit, Result),
    (   Result == inference_limit_exceeded
    ->  throw(time_limit_exceeded)
    ;   true
    ).

%!  alarm(+Seconds, :Goal, -Id) is det.
%
%   There is no timer to schedule this on. Nothing in LE2 calls it; it is here
%   so that a module importing library(time) whole still loads, and so that a
%   future caller gets a refusal it can see rather than silence.
alarm(Seconds, Goal, Id) :-
    alarm(Seconds, Goal, Id, []).
alarm(_Seconds, _Goal, _Id, _Options) :-
    throw(error(resource_error(no_timers),
                context(time:alarm/4, 'no timers in the WebAssembly build'))).

remove_alarm(_Id).
