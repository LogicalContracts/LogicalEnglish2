/** <module> Regression test: meta templates win the outer-literal choice.

    A meta template ("*a person* says that *a sentence*") has a 'that'-marked
    slot that, by the LE convention, swallows the rest of the sentence — so when
    its marker words occur in a condition, it must be parsed as the OUTER
    literal. Templates used to be tried purely in specificity order, so the
    wordier "*a person* is the father of *a person*" template matched first and
    absorbed the meta phrase into its own first slot:

        is_the_father_of(says_that(C, 'the person'), B)      % WRONG

    instead of

        says_that(C, is_the_father_of(A, B))                 % intended

    (see candidate_template/3 in le_grammar.pl and examples/moreExamples/
    citizenship.le lines 25-31).

    Run with:  swipl -q -g run_tests -t halt testing/test_meta_template_priority.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_meta_template_priority, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

% Recursively drop every le_at(G, _, _) wrapper so tests can match on the bare
% logical structure, preserving head/body variable sharing by stripping the
% whole (Head :- Body) term at once.
deep_strip_le_at(G, G) :- var(G), !.
deep_strip_le_at(le_at(G, _, _), Out) :- !, deep_strip_le_at(G, Out).
deep_strip_le_at(G, Out) :-
    compound(G), !,
    G =.. [F|Args],
    maplist(deep_strip_le_at, Args, Args1),
    Out =.. [F|Args1].
deep_strip_le_at(G, G).

stripped_rules(KB, F, A, Rules) :-
    functor(H, F, A),
    findall(R, ( clause(KB:H, B), deep_strip_le_at((H :- B), R) ), Rules).

has_variant(Rules, Pattern) :-
    once(( member(R, Rules), R =@= Pattern )).

:- begin_tests(meta_template_priority).

% The condition "a third person says that the person is the father of the other
% person" must parse with says_that as the outer literal, its sentence slot
% holding the embedded is_the_father_of literal that SHARES the head variables.
test(meta_template_is_outer_literal) :-
    Text = "the target language is: prolog.\nthe templates are:\n    *a person* is the father of *a person*.\n    *a person* says that *a sentence*.\n    *a person* is trusted.\n\nthe knowledge base fatherhood includes:\n\na person is the father of an other person\n    if a third person says that the person is the father of the other person\n    and the third person is trusted.\n",
    le_kbs:load_text(Text, KB),
    stripped_rules(KB, is_the_father_of, 2, Rules),
    assertion(has_variant(Rules,
        (is_the_father_of(A, B) :-
            and(says_that(C, is_the_father_of(A, B)), is_trusted(C))))).

% Pin the bundled citizenship.le: both fatherhood rules go through says_that.
test(citizenship_father_rules_parse_via_says_that) :-
    le_kbs:load('examples/moreExamples/citizenship.le', KB),
    stripped_rules(KB, is_the_father_of, 2, Rules),
    assertion(has_variant(Rules,
        (is_the_father_of(A, B) :-
            and(says_that(C, is_the_father_of(A, B)),
                is_qualified_to_determine_fatherhood(C))))),
    assertion(has_variant(Rules,
        (is_the_father_of(X, Y) :- says_that(X, is_the_father_of(X, Y))))).

% A sentence with no meta marker keeps its ordinary parse: the wordier template
% still wins when no meta template matches.
test(non_meta_sentences_are_unaffected) :-
    Text = "the target language is: prolog.\nthe templates are:\n    *a person* is the father of *a person*.\n    *a person* says that *a sentence*.\n\nthe knowledge base plain includes:\n\nharry is the father of john.\n",
    le_kbs:load_text(Text, KB),
    stripped_rules(KB, is_the_father_of, 2, Rules),
    assertion(has_variant(Rules, (is_the_father_of(harry, john) :- true))).

:- end_tests(meta_template_priority).
