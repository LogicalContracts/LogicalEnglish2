/** <module> Unit tests for `the functions are:` (and for what it replaced)

    A function is a template of the form "... is *a value*" declared in its own
    section (docs/user/reference/language.md §2.3). Declaring it lets the
    sentence be written WITHOUT its last place wherever a value is expected:
    "the price of a cup with capacity 200" is then the price itself.

    Pinned here:
      * the compact form binds the value through a goal placed BEFORE the
        condition that uses it — which is what makes a comparison work;
      * the same application written twice in one sentence is ONE goal, so a
        function with several answers does not multiply them;
      * the full sentence is unaffected, and a fact whose value is a function
        becomes a rule;
      * a declared function that is not of the "... is *a value*" form is
        reported (function_not_is_form), and the rest of the program still
        parses;
      * `; defines global`, which §2.2 and §2.3 replaced between them, is
        reported (defines_global_removed);
      * `the constants are:`, which uses the same machinery underneath, still
        raises nothing.

    The worked example is
    examples/moreExamples/language/templates/functions.le.

    Run with:  swipl -q -g run_tests -t halt testing/test_functions.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_functions, []).

:- use_module(library(plunit)).
%  le_kbs.pl lives in the repo root, one level up from this testing/ file.
:- use_module('../le_kbs').

%  Recursively drop every le_at(G, _, _) source wrapper, leaving the bare logic.
deep_strip_le_at(G, G) :- var(G), !.
deep_strip_le_at(le_at(G, _, _), Out) :- !, deep_strip_le_at(G, Out).
deep_strip_le_at(G, Out) :-
    compound(G), !,
    G =.. [F|Args],
    maplist(deep_strip_le_at, Args, Args1),
    Out =.. [F|Args1].
deep_strip_le_at(G, G).

%  The single clause of Functor/Arity in KB, as Head :- Body, le_at stripped.
rule(KB, Functor, Arity, Head, Body) :-
    functor(Head, Functor, Arity),
    clause(KB:Head, Body0),
    deep_strip_le_at(Body0, Body).

%  The conjuncts of a body, in order.
conjuncts(and(A, B), Cs) :- !, conjuncts(A, As), conjuncts(B, Bs), append(As, Bs, Cs).
conjuncts(G, [G]).

issue(KB, Type) :-
    current_predicate(KB:le_issue/6),
    KB:le_issue(_, Type, _, _, _, _), !.

cups(KB) :-
    le_kbs:load('examples/moreExamples/language/templates/functions.le', KB).

:- begin_tests(functions).

%  "the price of a cup with capacity the capacity ml > 10": the goal that asks
%  the function comes FIRST, binding the value the comparison then reads. Get
%  that order wrong and the comparison is an unbound arithmetic operand.
test(compact_form_binds_the_value_before_it_is_used) :-
    cups(KB),
    rule(KB, is_expensive, 1, is_expensive(Cup), Body),
    conjuncts(Body, Cs),
    once(append(_, [the_price_of_a_cup_with_capacity_ml_is(Cap, Price), le_gt(Price2, 10)], Cs)),
    assertion(Price2 == Price),
    assertion(var(Price)),
    %  and the capacity is the one the earlier condition found for this cup
    assertion(memberchk(the_capacity_of_is_ml(Cup, Cap), Cs)).

%  Two writings of the same application, one goal: a function may be a relation
%  with several answers, and asking it twice would multiply them.
test(same_application_twice_is_one_goal) :-
    cups(KB),
    rule(KB, is_worth_its_price, 1, _, Body),
    conjuncts(Body, Cs),
    include([G]>>(nonvar(G), functor(G, the_price_of_a_cup_with_capacity_is, 2)), Cs, Calls),
    assertion(Calls = [_]),
    Calls = [the_price_of_a_cup_with_capacity_is(_, Price)],
    %  both comparisons read that one value
    assertion(memberchk(le_gt(Price, 5), Cs)),
    assertion(memberchk(le_lt(Price, 100), Cs)).

%  A function of no places of its own — "our currency" — is a value with a
%  name: what `; defines global` used to be for.
test(function_of_no_arguments_is_a_named_value) :-
    cups(KB),
    rule(KB, the_label_of_is, 2, the_label_of_is(_, Label), Body),
    conjuncts(Body, Cs),
    memberchk(our_currency_is(Currency), Cs),
    assertion(memberchk(le_is(Label, Currency), Cs)).

%  Declaring a function changes nothing about the sentence itself: the full form
%  is an ordinary literal, and the rule that defines it an ordinary rule.
test(the_full_sentence_still_works) :-
    cups(KB),
    rule(KB, the_price_of_a_cup_with_capacity_ml_is, 2,
         the_price_of_a_cup_with_capacity_ml_is(N, Amount), Body),
    conjuncts(Body, [le_is(Amount2, Expr)]),
    assertion(Amount2 == Amount),
    assertion(Expr == N / 10).

%  Which predicates were declared as functions, for the writer and the editor.
test(the_kb_records_its_functions) :-
    cups(KB),
    assertion(KB:le_function(the_price_of_a_cup_with_capacity_ml_is/2)),
    assertion(KB:le_function(our_currency_is/1)),
    assertion(\+ KB:le_function(is_expensive/1)).

test(the_example_program_raises_nothing) :-
    cups(KB),
    assertion(\+ issue(KB, _)).

%  A fact whose value is a function application is a rule: the goal that asks
%  the function is its body.
test(a_fact_whose_value_is_a_function_becomes_a_rule) :-
    le_kbs:load_text("the target language is: prolog.

the templates are:
    the label of *a cup* is *a text*.

the functions are:
    our currency is *a text*.

the knowledge base heads includes:

our currency is \"EUR\".

the label of thimble is our currency.
", KB),
    rule(KB, the_label_of_is, 2, the_label_of_is(thimble, Label), Body),
    conjuncts(Body, Cs),
    memberchk(our_currency_is(Currency), Cs),
    assertion(Currency == Label).

%  A function has to be a sentence with a value at the end. One that is not says
%  so, and the rest of the program still parses.
test(a_function_that_is_not_an_is_sentence_is_reported) :-
    le_kbs:load_text("the target language is: prolog.

the templates are:
    *a cup* is expensive.

the functions are:
    *a cup* holds *a number* ml.

the knowledge base badfunction includes:

a cup is expensive if the cup holds 200 ml.
", KB),
    assertion(issue(KB, function_not_is_form)),
    assertion(rule(KB, is_expensive, 1, _, _)).

%  `; defines global` is no longer part of the language (§2.2, §2.3): the
%  template that carries it is told so, at its own line.
test(defines_global_is_reported_as_removed) :-
    le_kbs:load_text("the target language is: prolog.

the templates are:
    the answer is *a policy*.
    our policy is *a policy*; defines global this policy.

the knowledge base oldglobal includes:

our policy is p123.

the answer is a policy if the policy is this policy.
", KB),
    assertion(issue(KB, defines_global_removed)).

%  The constants section is built on the same machinery underneath (a name for
%  the value of a template) but is not that syntax, and must not be reported as
%  it: the marker it synthesises is internal.
test(a_constants_section_is_not_reported) :-
    le_kbs:load_text("the target language is: prolog.

the templates are:
    *a person* pays the fee.

the constants are:
    the fee is 5.

the knowledge base fees includes:

a person pays the fee if the value of the fee is a fee and the fee > 1.
", KB),
    assertion(\+ issue(KB, defines_global_removed)),
    assertion(KB:le_constant('the fee', the_value_of_the_fee_is/1)).

:- end_tests(functions).
