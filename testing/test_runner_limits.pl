/** <module> The example runner's load limit

    runTestsFor/2 gives a program's load a time limit (flag
    le_test_load_seconds, default 120 s). A parse cut off by the limit loads
    nothing, and the file then counted as having no tests: the 30 s limit of
    before cut off programs that include many others (the InsurLE Medicare
    model's whole-model file includes 56 policies and loads in ~40 s).

    Run with:  swipl -q -g run_tests -t halt testing/test_runner_limits.pl
*/

:- module(test_runner_limits, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

:- begin_tests(runner_limits).

test(default_load_limit) :-
    (   current_prolog_flag(le_test_load_seconds, _)
    ->  true
    ;   le_kbs:test_load_seconds(S), S =:= 120
    ).

test(load_limit_flag, [cleanup(set_prolog_flag(le_test_load_seconds, 120))]) :-
    set_prolog_flag(le_test_load_seconds, 45),
    le_kbs:test_load_seconds(S),
    S =:= 45.

:- end_tests(runner_limits).
