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

    When meta templates NEST, the one whose words start first in the sentence
    is the outer one (le_grammar:outer_first/3): "the lender notifies the
    borrower on a date that the borrower fails to fulfil an obligation that a
    requirement" is a notice of a failure, not a failure of a notice.

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

% Nested meta templates: the template that starts first is the outer literal,
% in a fact, in a rule's condition, and in a query. Alphabetically
% fails_to_fulfil_that comes first, and it used to take "bank notifies bob on
% ... that bob" into its first, ordinary slot.
nested_meta_program(Text) :-
    Text = "the target language is: prolog.\n\nthe templates are:\n    *a lender* notifies *a borrower* on *a date* that *a message*.\n    *a borrower* fails to fulfil *an obligation* that *a requirement*.\n    *a person* pays *an amount* on *a date*.\n    *a borrower* is warned.\n\nthe knowledge base nesting includes:\n\na borrower is warned if\n    a lender notifies the borrower on a date that the borrower fails to fulfil an obligation that the borrower pays an amount on a second date.\n\nscenario one is:\n    bank notifies bob on 2016-06-02 that bob fails to fulfil loan one that bob pays 525 on 2016-06-01.\n\nquery q is:\n    which borrower is warned.\n".

test(nested_meta_templates_in_a_fact) :-
    nested_meta_program(Text),
    le_kbs:load_text(Text, KB),
    KB:scenario(one, Facts),
    member(F0, Facts), ( F0 = fact_with_source(F, _, _) -> true ; F = F0 ),
    assertion(F = notifies_on_that(bank, bob, _,
                  fails_to_fulfil_that(bob, 'loan one', pays_on(bob, 525, _)))).

test(nested_meta_templates_in_a_rule) :-
    nested_meta_program(Text),
    le_kbs:load_text(Text, KB),
    stripped_rules(KB, is_warned, 1, Rules),
    assertion(has_variant(Rules,
        (is_warned(B) :- notifies_on_that(_L, B, _D1,
                             fails_to_fulfil_that(B, _O, pays_on(B, _A, _D2)))))).

test(nested_meta_templates_answer) :-
    nested_meta_program(Text0),
    string_concat(Text0, "\nscenario two is:\n    bank notifies bob on 2016-06-02 that bob fails to fulfil loan one that bob pays 525 on 2016-06-01.\n    q expects answers [\"bob is warned\"].\n", Text),
    tmp_file_stream(text, File, S0), close(S0),
    atom_concat(File, '.le', LE),
    setup_call_cleanup(open(LE, write, S, [encoding(utf8)]), write(S, Text), close(S)),
    runTestsFor(LE, test_file(_, Results)),
    assertion(Results == [pass(q, two)]).

:- end_tests(meta_template_priority).
