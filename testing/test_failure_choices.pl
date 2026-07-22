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

% --- A prepositional-chain query solves its constraints before the main verb ---
% "we will make WHICH payment under this policy in respect of THIS claim" must not
% explore an UNRELATED claim in its failure explanation: the prepositional
% constraint (in respect of this claim) is solved before we_will_make/1, so the
% main verb cannot pick a different payment/claim witness. Regression for the
% query reorder in le_grammar.pl (query_chain_goal/3 + parse_node/6) and the
% source-order answer folding in le_kbs.pl (select_main_literal/4).
prep_program("the target language is: prolog.
the templates are:
    we will make *a payment*.
    *a payment* under *a policy*; prepositional.
    *a payment* in respect of *a claim*; prepositional.
    *a claim* is approved.
the knowledge base k includes:
    we will make a payment under this policy in respect of a claim
        if the claim is approved.
scenario s is:
    this payment under this policy.
    this payment in respect of this claim.
    other payment under this policy.
    other payment in respect of other claim.
query q is:
    we will make which payment under this policy in respect of this claim.").

test(prep_chain_query_does_not_leak_other_claim) :-
    prep_program(P),
    le_kbs:load_text(P, KB),
    le_kbs:createSession(KB, SM),
    setup_call_cleanup(true,
        ( le_kbs:setScenarion(SM, s),
          \+ le_kbs:query(SM, q, _, _, _),
          le_kbs:query_explain(SM, q, _, _, Why),
          term_to_atom(Why, WhyAtom),
          % The failure is about THIS claim not being approved; the decoy
          % "other claim" must never appear.
          assertion(\+ sub_atom(WhyAtom, _, _, _, 'other claim')),
          assertion(sub_atom(WhyAtom, _, _, _, 'this claim'))
        ),
        le_kbs:destroySession(SM)).

% --- An "unless" rule's negation carries a navigable source range ---
% The compiled `not/1` used to be bare (no le_at wrapper), so the negation node
% in a failure explanation had range `none` and navigated nowhere. It is now
% wrapped with the rule's span (le_grammar.pl, unless clause of second_pass_item).
unless_program("the target language is: prolog.
the templates are:
    *a person* is covered,
    *a person* is eligible,
    *a person* is excluded,
    *a person* notifies.
the knowledge base k includes:
    a person is covered if
        the person is eligible
        and the person is excluded.
    a person is excluded unless the person notifies.
scenario s is:
    alice is eligible.
    it is assumable whether alice notifies.
query q is:
    alice is covered.").

test(unless_negation_node_has_range) :-
    unless_program(P),
    le_kbs:load_text(P, KB),
    le_kbs:createSession(KB, SM),
    setup_call_cleanup(true,
        ( le_kbs:setScenarion(SM, s),
          \+ le_kbs:query(SM, q, _, _, _),
          le_kbs:query_explain(SM, q, _, _, Why),
          ( is_list(Why) -> member(Root, Why) ; Root = Why ),
          find_node(Root, failure(_, Range, LE, _)),
          le_contains(LE, notifies),
          le_contains(LE, 'not the case'),
          assertion(Range = range(_, _))
        ),
        le_kbs:destroySession(SM)).

% --- An outdented negation connective does not swallow a following conjunct ---
% "... if C and it is not the case that (A) and B" where "it is not the case
% that" sits at a SHALLOWER indent than the rule's conjunct chain and B is
% outdented back to the chain level: B must parse as a POSITIVE top-level
% conjunct (a sibling of the negation), not as the negation's second argument.
% Regression for the chain-anchor threshold in lines_to_hierarchy
% (le_grammar.pl); mirrors hiscoxhappypath.le's trailing "... fulfills all the
% general conditions of this policy" (rule at line 96/110), whose success
% subtree used to be missing because it was hidden inside not(A and B) and A
% (short-circuit) failed before B was ever evaluated.
neg_scope_program("the target language is: prolog.
the templates are:
    *a person* is covered,
    *a person* qualifies,
    *a person* is barred,
    *a person* is verified.
the knowledge base k includes:
    a person is covered
    if the person qualifies
and it is not the case that
        the person is barred
    and the person is verified.
scenario s is:
    alice qualifies.
    alice is verified.
query q is:
    which person is covered.").

test(outdented_negation_does_not_swallow_following_conjunct) :-
    neg_scope_program(P),
    le_kbs:load_text(P, KB),
    le_kbs:createSession(KB, SM),
    setup_call_cleanup(true,
        ( le_kbs:setScenarion(SM, s),
          le_kbs:query(SM, q, _, _, Why),
          ( is_list(Why) -> member(Root, Why) ; Root = Why ),
          Root = success(_, _, RootLE, Kids),
          le_contains(RootLE, 'is covered'),
          % B ("... is verified") is a DIRECT child of the rule head — a
          % top-level conjunct proven on its own, i.e. a sibling of the negation.
          assertion(( member(K, Kids), K = success(_, _, VLE, _),
                      le_contains(VLE, verified) )),
          % The negation node carries ONLY its own single argument; it must not
          % have absorbed B ("verified") as a second conjunct.
          assertion(( member(K2, Kids), K2 = success(_, _, NegLE, _),
                      le_contains(NegLE, 'not the case'),
                      \+ le_contains(NegLE, verified) ))
        ),
        le_kbs:destroySession(SM)).

:- end_tests(failure_choices).
