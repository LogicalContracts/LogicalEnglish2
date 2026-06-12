/** <module> Regression test for dangling "... that" meta connectives whose
    argument is written at an inconsistent (shallower) indentation.

    A rule like

        it is prohibited that a creature attends the tea party if
           the creature is a lofty creature
            and it is not the case that
        it is approved that the creature attends the tea party.

    has weird indentation we wish to tolerate: the "it is not the case that"
    line is indented more deeply than the conjunct before it, while its argument
    ("it is approved that ...") sits at column 0. The hierarchy builder must
    still attach the argument as the negation's child, yielding

        and(is_a_lofty_creature(A), not(it_is_approved_that(attends(A, B))))

    rather than the broken and(and(lofty, not(true)), it_is_approved_that(...)).

    Run with:  swipl -q -g run_tests -t halt testing/test_grammar_dangling_that.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_grammar_dangling_that, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

% Recursively drop every le_at(G, _, _) wrapper so the test can match on the
% bare logical structure. (Named deep_* to avoid clashing with the shallow
% strip_le_at/2 exported by le_proof_game.)
deep_strip_le_at(G, G) :- var(G), !.
deep_strip_le_at(le_at(G, _, _), Out) :- !, deep_strip_le_at(G, Out).
deep_strip_le_at(G, Out) :-
    compound(G), !,
    G =.. [F|Args],
    maplist(deep_strip_le_at, Args, Args1),
    Out =.. [F|Args1].
deep_strip_le_at(G, G).

% All it_is_prohibited_that/1 rule bodies in the example, with le_at stripped.
prohibited_bodies(KB, Bodies) :-
    le_kbs:load('examples/moreExamples/testing/tea_party2.le', KB),
    findall(Body,
            ( clause(KB:it_is_prohibited_that(H), B),
              deep_strip_le_at((it_is_prohibited_that(H) :- B), (_ :- Body))
            ),
            Bodies).

% True when some element of Bodies is structurally identical (variant) to
% Pattern. Uses =@= so the test never binds either side (unlike sub_term/2 with
% a non-ground pattern, which would over-match free variables).
has_variant(Bodies, Pattern) :-
    once(( member(B, Bodies), B =@= Pattern )).

% True when Term contains the literal subterm not(true) (the old bug), compared
% with ==, so free variables are never accidentally matched.
contains_not_true(T) :- T == not(true), !.
contains_not_true(T) :-
    compound(T),
    arg(_, T, A),
    contains_not_true(A).

:- begin_tests(grammar_dangling_that).

% The mis-indented "it is not the case that" rule must negate the following
% clause, not an empty (true) scope.
test(not_the_case_absorbs_shallower_argument) :-
    prohibited_bodies(_KB, Bodies),
    % The lofty creature is the same one whose attendance is not approved, so
    % the variable is shared between the two conjuncts.
    assertion(has_variant(Bodies,
                          and(is_a_lofty_creature(A),
                              not(it_is_approved_that(attends(A, _)))))),
    % And the broken not(true) form must be gone from every rule.
    assertion(\+ ( member(B, Bodies), contains_not_true(B) )).

% The well-indented sibling rule keeps working (negation of the approved fact).
test(well_indented_not_the_case_still_correct) :-
    prohibited_bodies(_KB, Bodies),
    assertion(has_variant(Bodies, not(it_is_approved_that(attends(_, _))))).

:- end_tests(grammar_dangling_that).
