% The test runner must survive the programs it is given.
%
% Programs that reach runTestsFor/2 are routinely machine-written and hit
% run-time errors no verifier can see: `R = min(A, L)` (Logical English has no
% min function — see the `the minimum of *X* and *Y* is *Z*` system template)
% leaves the unevaluated term in a variable, and summing it throws from deep
% inside the reasoner. That used to abort the whole suite, leaving every file
% after the offending one silently unrun.

:- use_module('../le_kbs').

:- begin_tests(test_runner_robustness).

% `min/2` is not an LE function; the term survives into a sum aggregate, which
% throws type_error(evaluable, ...) mid-proof.
throwing_program("the target language is: prolog.

the templates are:
    *a claim* has item *an item* worth *an amount*.
    *a claim* has a sublimit of *an amount*.
    *an item* of *a claim* pays *an amount*.
    *a claim* has subtotal of *an amount*.

the knowledge base tiny includes:

an item of a claim pays an amount R
    if the claim has item the item worth an amount A
    and the claim has a sublimit of an amount L
    and R = min(A, L).

a claim has subtotal of an amount T
    if the claim has a sublimit of an amount L
    and a T is the sum of each P such that
        an item of the claim pays a P.

scenario one is:
    claim one has item jewelry worth 9000.
    claim one has a sublimit of 2500.
    sub expects answers [\"claim one has subtotal of 2500\"].

query sub is:
    which claim has subtotal of which amount.
").

% ... and the same program written correctly, to prove the guard does not turn
% working tests into errors.
working_program("the target language is: prolog.

the templates are:
    *a claim* has item *an item* worth *an amount*.
    *a claim* has a sublimit of *an amount*.
    *an item* of *a claim* pays *an amount*.
    *a claim* has subtotal of *an amount*.

the knowledge base tiny includes:

an item of a claim pays an amount R
    if the claim has item the item worth an amount A
    and the claim has a sublimit of an amount L
    and the minimum of A and L is R.

a claim has subtotal of an amount T
    if the claim has a sublimit of an amount L
    and a T is the sum of each P such that
        an item of the claim pays a P.

scenario one is:
    claim one has item jewelry worth 9000.
    claim one has a sublimit of 2500.
    sub expects answers [\"claim one has subtotal of 2500\"].

query sub is:
    which claim has subtotal of which amount.
").

run(Program, Results) :-
    le_kbs:load_text(Program, KB),
    findall(test(Q, S, A, U), KB:le_expected(Q, S, A, U), Tests),
    Tests \== [],
    maplist(le_kbs:run_one_test(KB), Tests, Results).

% The raising test comes back as that test's error — the call itself succeeds.
test(a_test_that_raises_becomes_an_error_result) :-
    throwing_program(P),
    run(P, Results),
    assertion(Results = [_]),
    Results = [R],
    assertion(R = error(_, _, _)),
    R = error(Q, S, Msg),
    assertion(Q == sub), assertion(S == one),
    assertion(sub_string(Msg, _, _, _, "Run-time error")),
    assertion(sub_string(Msg, _, _, _, "type_error")),
    % error/3 is its own outcome: the suite counts errors separately from
    % failures and exits non-zero on either (see testing/run_tests.sh).
    assertion(\+ le_kbs:is_failure(R)).

% The suite goes on: a second file's tests still run after the first threw.
test(the_run_continues_after_a_raising_test) :-
    throwing_program(P1), working_program(P2),
    run(P1, R1), run(P2, R2),
    assertion(R1 = [error(_, _, _)]),
    assertion(R2 = [pass(_, _)]).

% The guard must not swallow a message truncated beyond recognition, nor a
% working test.
test(a_correct_program_still_passes) :-
    working_program(P),
    run(P, [R]),
    assertion(R = pass(sub, one)).

:- end_tests(test_runner_robustness).
