/** <module> The example runner's load limit

    runTestsFor/2 gives a program's load a time limit (flag
    le_test_load_seconds, default 300 s). The 30 s limit of before cut off
    programs that include many others: examples/regulatory/medicare/all_cases.le
    includes the whole Medicare model (56 policies) and loads in ~65 s, more
    on a busy machine. The parser swallows the time-limit exception, so a cut
    off parse used to "load" with no scenarios and the file was reported
    [NONE] (0 tests); a load that uses up its budget is now a load error.

    Run with:  swipl -q -g run_tests -t halt testing/test_runner_limits.pl
*/

:- module(test_runner_limits, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

:- begin_tests(runner_limits).

test(default_load_limit) :-
    (   current_prolog_flag(le_test_load_seconds, _)
    ->  true
    ;   le_kbs:test_load_seconds(S), S =:= 300
    ).

test(load_limit_flag, [cleanup(set_prolog_flag(le_test_load_seconds, 300))]) :-
    set_prolog_flag(le_test_load_seconds, 45),
    le_kbs:test_load_seconds(S),
    S =:= 45.

% A load cut short by the limit is an error, never a file with no tests.
test(cut_off_load_is_error, [cleanup(set_prolog_flag(le_test_load_seconds, 300))]) :-
    set_prolog_flag(le_test_load_seconds, 1),
    le_kbs:runTestsFor('examples/regulatory/medicare/all_cases.le', test_file(_, Results)),
    Results = [error(load, _, _)].

:- end_tests(runner_limits).
