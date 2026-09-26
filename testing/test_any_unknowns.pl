/** <module> `... expects answers [...] and any unknowns.`

    An expectation that checks the answers only, whatever unknowns they rest
    on (docs/user/reference/language.md §12): parsed in every language, run
    by the test runner, and written back by le_writer.

    Run with:  swipl -q -g run_tests -t halt testing/test_any_unknowns.pl
*/

:- module(test_any_unknowns, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_writer').
:- use_module('../le_i18n').

program("the target language is: prolog.

the templates are:
    *a counterparty* is covered.
    *a counterparty* holds a banking licence.
    *a counterparty* is regulated; unknown.

the knowledge base k includes:

a counterparty is covered if
    the counterparty holds a banking licence
    and the counterparty is regulated.

scenario banks is:
    acme holds a banking licence.
    q expects answers [\"acme is covered\"] and any unknowns.
    q expects answers [\"zeta is covered\"] and any unknowns.
    q expects answers [\"acme is covered\"].

query q is:
    which counterparty is covered.
").

results(Results) :-
    program(P),
    tmp_file_stream(text, File, S), write(S, P), close(S),
    le_kbs:runTestsFor(File, test_file(_, Results)),
    delete_file(File).

:- begin_tests(any_unknowns).

test(parsed_as_any) :-
    program(P),
    le_kbs:load_text(P, test_any_unknowns, KB),
    findall(U, KB:le_expected(q, banks, [string("acme is covered", _)], U), Us),
    assertion(Us == [any, []]).

test(the_answers_alone_decide) :-
    results(Rs),
    assertion(Rs = [pass(q, banks), fail(q, banks, _, _), fail(q, banks, _, _, _, _)]),
    %  the failure of `and any unknowns` says nothing about unknowns
    Rs = [_, fail(_, _, Expected, Actual), _],
    assertion(Expected == ["zeta is covered"]),
    assertion(Actual == ["acme is covered"]).

test(written_back_by_the_writer) :-
    IR = program([kb(k)], [
        template(covered, "*a counterparty* is covered", []),
        template(licensed, "*a counterparty* holds a banking licence", [undefined]),
        rule(covered(C), licensed(C), []),
        scenario(banks, [fact(licensed(acme)), expects(q, [covered(acme)], any)], []),
        query(q, covered(_))]),
    le_write(IR, Text, _),
    assertion(sub_string(Text, _, _, _, "q expects answers [\"acme is covered\"] and any unknowns.")).

test(a_phrase_in_every_language) :-
    forall(known_language(L),
           assertion(kw_synonym_words(L, and_any_unknowns, [_|_]))).

:- end_tests(any_unknowns).
