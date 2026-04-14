:- use_module(le_kbs).

test :-
    runTestsFor('examples/moreExamples/citizenship.le.tests', Result),
    print_test_result(Result),
    halt.

:- test.
