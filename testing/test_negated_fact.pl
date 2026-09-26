/** <module> A scenario states that something is not so

    `it is not the case that <sentence>.` in a scenario: the sentence is
    neither proved nor assumed while the scenario is loaded, even where its
    template is `; unknown` (language.md §3, Negated Fact). Outside a
    scenario, the line is an error. It used to parse as a fact of the
    template with "it" and "not the case that <subject>" for arguments, and
    say nothing.

    Run with:  swipl -q -g run_tests -t halt testing/test_negated_fact.pl
*/

:- module(test_negated_fact, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

program(Extra, P) :-
    format(string(P), "the target language is: prolog.

the templates are:
    *a counterparty* is covered.
    *a counterparty* holds a banking licence.
    *a counterparty* is outside the water undertaker class; unknown.

the knowledge base k includes:
~w
a counterparty is covered if
    the counterparty holds a banking licence
    and the counterparty is outside the water undertaker class.

scenario open is:
    acme holds a banking licence.

scenario inside is:
    acme holds a banking licence.
    it is not the case that acme is outside the water undertaker class.

query q is:
    which counterparty is covered.
", [Extra]).

answers(P, S, As) :-
    le_kbs:load_text(P, test_negated_fact, KB),
    le_kbs:createSession(KB, SM), le_kbs:setScenarion(SM, S),
    findall(A, ( le_kbs:query(SM, q, I, _, _), le_kbs:canonical_string(I, A) ), As).

:- begin_tests(negated_fact).

test(an_unknown_is_assumed_where_nothing_is_said) :-
    program("", P), answers(P, open, As),
    assertion(As == ["acme is covered"]).

test(a_negated_fact_is_neither_proved_nor_assumed) :-
    program("", P), answers(P, inside, As),
    assertion(As == []).

test(outside_a_scenario_it_is_an_error) :-
    program("\nit is not the case that acme is outside the water undertaker class.\n", P),
    le_kbs:load_text(P, test_negated_fact, KB),
    assertion(KB:le_issue(error, negated_fact_outside_scenario, _, _, _, _)).

:- end_tests(negated_fact).
