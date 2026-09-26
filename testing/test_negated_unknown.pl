/** <module> The verifier's negated_unknown warning

    `it is not the case that X`, where X's template is declared `; unknown`,
    never holds: LE never proves false what it could assume. The verifier
    says so, where the negation is written.

    Run with:  swipl -q -g run_tests -t halt testing/test_negated_unknown.pl
*/

:- module(test_negated_unknown, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

program(Unknown, P) :-
    format(string(P), "the target language is: prolog.

the templates are:
    *a counterparty* is covered.
    *a counterparty* holds a banking licence.
    *a counterparty* has entered administration~w.

the knowledge base k includes:

a counterparty is covered if
    the counterparty holds a banking licence
    and it is not the case that
        the counterparty has entered administration.

scenario banks is:
    acme holds a banking licence.

query q is:
    which counterparty is covered.
", [Unknown]).

issues(Unknown, Types) :-
    program(Unknown, P),
    le_kbs:load_text(P, test_negated_unknown, KB),
    findall(T, KB:le_issue(_, T, _, _, _, _), Types).

:- begin_tests(negated_unknown).

test(reported_over_an_unknown) :-
    issues("; unknown", Types),
    assertion(memberchk(negated_unknown, Types)).

test(not_reported_over_a_closed_template) :-
    issues("", Types),
    assertion(\+ memberchk(negated_unknown, Types)).

:- end_tests(negated_unknown).
