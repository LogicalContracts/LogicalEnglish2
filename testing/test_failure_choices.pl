/** <module> Failure explanations expose exhausted choice points

    When a conjunction fails, a condition that SUCCEEDED with a non-ground
    call is shown as a choice point. Since 2026-07-20 it also carries WHY it
    could produce no other solution: the failure subtrees of its exhausted
    alternative branches (the bindings those branches committed to are what
    made later goals fail). Previously the choice node was a bare leaf, so
    e.g. retracting one scenario fact collapsed a rich failure explanation
    into an unrelated-looking stub (hiscoxhappypath.le, scenario zero).

    Run with:  swipl -q -g run_tests -t halt testing/test_failure_choices.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_failure_choices, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

program("the target language is: prolog.

the templates are:
    *a person* is happy,
    *a person* is a winner,
    *a person* is calm,
    *a person* has a pet,
    *a person* trains.

the knowledge base w includes:

a person is happy
    if the person is a winner
    and the person is calm.

a person is a winner
    if the person has a pet
    and the person trains.

scenario s is:
    Alice has a pet.
    Alice trains.
    Bob has a pet.

query q is:
    which person is happy.
").

% Any node in the tree (success/failure/repeated_group, children last-arg list).
find_node(N, N).
find_node(T, N) :-
    compound(T),
    T =.. [_|Args],
    append(_, [Kids], Args),
    is_list(Kids),
    member(K, Kids),
    find_node(K, N).

le_contains(LE, Sub) :-
    ( atom(LE) -> A = LE ; term_to_atom(LE, A) ),
    sub_atom(A, _, _, _, Sub).

:- begin_tests(failure_choices).

% "Alice is a winner" succeeded, then "Alice is calm" failed; backtracking
% exhausted the winner choice (Bob has a pet but does not train). The choice
% node must now CONTAIN that exhausted alternative — a failure about
% "trains" — rather than being a bare leaf.
test(choice_point_carries_its_exhausted_alternatives) :-
    program(P),
    le_kbs:load_text(P, KB),
    le_kbs:createSession(KB, SM),
    setup_call_cleanup(true,
        ( le_kbs:setScenarion(SM, s),
          \+ le_kbs:query(SM, q, _, _, _),
          le_kbs:query_explain(SM, q, _, _, Why),
          ( is_list(Why) -> member(Root, Why) ; Root = Why ),
          find_node(Root, success(_, _, ChoiceLE, ChoiceKids)),
          le_contains(ChoiceLE, 'is a winner'),
          ChoiceKids \== [],
          member(Kid, ChoiceKids),
          find_node(Kid, failure(_, _, FailLE, _)),
          le_contains(FailLE, trains)
        ),
        le_kbs:destroySession(SM)).

% The failed sibling itself is still reported as before.
test(failed_condition_still_reported) :-
    program(P),
    le_kbs:load_text(P, KB),
    le_kbs:createSession(KB, SM),
    setup_call_cleanup(true,
        ( le_kbs:setScenarion(SM, s),
          le_kbs:query_explain(SM, q, _, _, Why),
          ( is_list(Why) -> member(Root, Why) ; Root = Why ),
          find_node(Root, failure(_, _, CalmLE, _)),
          le_contains(CalmLE, calm)
        ),
        le_kbs:destroySession(SM)).

:- end_tests(failure_choices).
