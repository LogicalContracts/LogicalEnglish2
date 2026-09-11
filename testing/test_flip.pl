/** <module> Flip queries: minimal scenario changes that flip an outcome

    LE_extensions_proposal §3.7, docs/le_summary.md §17.7.

    Run with:  swipl -q -g run_tests -t halt testing/test_flip.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_flip, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

change_sets(KB, Scenario, Query, Sets) :-
    createSession(KB, SM),
    setScenarion(SM, Scenario),
    KB:query_info(Query, Goal, _),
    findall(Set,
            ( reasoner:i(Goal, SM, _, _),
              Goal = le_flip(_, Changes),
              maplist(le_kbs:change_string(KB), Changes, Set0), msort(Set0, Set) ),
            Sets0),
    destroySession(SM),
    msort(Sets0, Sets).

answers(KB, Scenario, Query, Answers) :-
    createSession(KB, SM),
    setScenarion(SM, Scenario),
    findall(A, ( query(SM, Query, I, _, _), canonical_string(I, A) ), Answers0),
    destroySession(SM),
    msort(Answers0, Answers).

:- begin_tests(flip).

test(housing_example) :-
    load('examples/RulesRus/flip_housing.le', KB),
    change_sets(KB, rich, flip_rich, R),
    R == [["add: rich is on a low income"]],
    change_sets(KB, bob, flip_bob, B),
    B == [["remove: bob is on a low income"], ["remove: bob is on other benefits"]].

test(answers_render_the_change) :-
    load('examples/RulesRus/flip_housing.le', KB),
    answers(KB, rich, flip_rich, As),
    As == ["add: rich is on a low income"].

% A judged template's open instance is a one-step change: a judgment.
test(judgment_as_a_change) :-
    load_text("the target language is: prolog.

the templates are:
    *a claim* is payable.
    *a claim* is for *a damage*; undefined.
    *a damage* is accidental; judged.
    *a damage* is reported within the time limit; undefined.

the knowledge base judged damage includes:
a claim is payable
    if the claim is for a damage
    and the damage is reported within the time limit
    and the damage is accidental.

scenario undecided is:
    claim one is for the burst pipe.
    the burst pipe is reported within the time limit.

scenario late is:
    claim one is for the burst pipe.

query flip is:
    which minimal change to the scenario makes it the case that
        claim one is payable.
", KB),
    change_sets(KB, undecided, flip, U),
    U == [["add: the burst pipe is accidental"]],
    % Two changes, found although the second condition is only reached once
    % the first holds.
    change_sets(KB, late, flip, L),
    L == [["add: the burst pipe is accidental", "add: the burst pipe is reported within the time limit"]].

test(already_holds_needs_no_change) :-
    load('examples/RulesRus/flip_housing.le', KB),
    createSession(KB, SM), setScenarion(SM, bob),
    once(parse_custom_query(KB, "bob gets help to pay rent", G)),
    findall(C, ( le_flip:minimal_changes(G, SM, KB, C, _) ), Cs),
    destroySession(SM),
    Cs == [[[]]].

% With no template marked, the templates no rule concludes are the scenario
% elements.
test(unmarked_program_uses_extensional_templates) :-
    load_text("the target language is: prolog.

the templates are:
    *a person* is happy.
    *a person* is rich.
    *a person* is healthy.

the knowledge base k includes:
a person is happy
    if the person is rich
    and the person is healthy.

scenario s is:
    ann is rich.

query flip is:
    which minimal change to the scenario makes it the case that
        ann is happy.
", KB),
    change_sets(KB, s, flip, S),
    S == [["add: ann is healthy"]].

test(bounded_search) :-
    load_text("the target language is: prolog.

the templates are:
    *a person* is happy.
    *a person* has *a thing*; undefined.

the knowledge base k includes:
a person is happy
    if the person has the car
    and the person has the house
    and the person has the boat
    and the person has the plane.

scenario s is:
    ann has the car.

query flip is:
    which minimal change to the scenario makes it the case that
        ann is happy.
", KB),
    % three additions are needed; the default bound is 3 changes
    change_sets(KB, s, flip, S),
    S == [["add: ann has the boat", "add: ann has the house", "add: ann has the plane"]],
    set_prolog_flag(le_flip_max_changes, 2),
    call_cleanup(change_sets(KB, s, flip, S2), set_prolog_flag(le_flip_max_changes, 3)),
    S2 == [].

:- end_tests(flip).
