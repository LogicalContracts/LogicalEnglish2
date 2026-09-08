/** <module> Unit tests for definite descriptions in rules.

    "the white rabbit" is a variable only when the SAME rule introduced it with
    an indefinite phrase ("a white rabbit"); where nothing introduces it, the
    phrase names a global constant — the same individual in rules, scenarios and
    queries. See examples/moreExamples/white_rabbit.le, the worked example.

    Pinned here:
      * an introduced definite phrase ("a rabbit ... if the rabbit ...") is
        still one shared variable;
      * a non-introduced one ("the white rabbit", "the tea party") becomes the
        constant named by the whole phrase, article included, which is exactly
        what a scenario fact writing the same phrase produces;
      * a definite phrase inside an arithmetic expression ("the total is the
        amount * 2") resolves to the introduced variable instead of swallowing
        the whole expression into one variable name.

    Run with:  swipl -q -g run_tests -t halt testing/test_definite_constants.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_definite_constants, []).

:- use_module(library(plunit)).
% le_kbs.pl lives in the repo root, one level up from this testing/ file.
:- use_module('../le_kbs').

% Recursively drop every le_at(G, _, _) source wrapper, leaving the bare logic.
deep_strip_le_at(G, G) :- var(G), !.
deep_strip_le_at(le_at(G, _, _), Out) :- !, deep_strip_le_at(G, Out).
deep_strip_le_at(G, Out) :-
    compound(G), !,
    G =.. [F|Args],
    maplist(deep_strip_le_at, Args, Args1),
    Out =.. [F|Args1].
deep_strip_le_at(G, G).

% The single clause of Functor/Arity in KB, as Head :- Body, le_at stripped.
rule(KB, Functor, Arity, Head, Body) :-
    functor(Head, Functor, Arity),
    clause(KB:Head, Body0),
    deep_strip_le_at(Body0, Body).

wonderland(KB) :- le_kbs:load('examples/moreExamples/white_rabbit.le', KB).

:- begin_tests(definite_constants).

% "a rabbit is in a hurry if the rabbit is late for an appointment": the body's
% "the rabbit" is the head variable, and "an appointment" a fresh one.
test(introduced_definite_is_the_head_variable) :-
    wonderland(KB),
    rule(KB, is_in_a_hurry, 1, Head, Body),
    Head = is_in_a_hurry(Rabbit),
    Body = is_late_for(BodyRabbit, Appointment),
    assertion(BodyRabbit == Rabbit),
    assertion(var(Appointment)).

% Nothing introduces "the white rabbit" or "the tea party": both are constants,
% named by the whole phrase.
test(unintroduced_definites_are_constants) :-
    wonderland(KB),
    rule(KB, falls_down_the_rabbit_hole, 1, Head, Body),
    Head = falls_down_the_rabbit_hole(Person),
    assertion(var(Person)),
    assertion(Body == and(follows(Person, 'the white rabbit'),
                          is_late_for('the white rabbit', 'the tea party'))).

% A scenario fact writing the same phrase yields the same constant, which is why
% the rule above can be about that one rabbit.
test(scenario_fact_uses_the_same_constant) :-
    wonderland(KB),
    KB:scenario(wonderland, Facts),
    assertion(memberchk(fact_with_source(is_late_for('the white rabbit', 'the tea party'), _, _), Facts)).

% A definite phrase used inside an expression refers to the variable that the
% rule introduced, rather than being read as the name of one whole variable
% ("amount * 2").
test(definite_inside_expression_refers_to_the_introduced_variable) :-
    le_kbs:load_text("the target language is: prolog.

the templates are:
*a person* has an amount of *an amount*.
*a person* has a doubled amount of *an amount*.

the knowledge base doubling includes:

a person has a doubled amount of a total
    if the person has an amount of an amount
    and the total is the amount * 2.
", KB),
    rule(KB, has_a_doubled_amount_of, 2, Head, Body),
    Head = has_a_doubled_amount_of(_, Total),
    Body = and(has_an_amount_of(_, Amount), le_is(BodyTotal, Expr)),
    assertion(BodyTotal == Total),
    assertion(Expr == Amount * 2).

:- end_tests(definite_constants).
