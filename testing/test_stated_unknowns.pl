/** <module> A goal both stated and declared unknown is not also assumed

    A scenario that states many of a rule's `; unknown` conditions used to
    make the reasoner try each of them twice — from the fact, and by assuming
    it — 2^n branches for n stated conditions, all but one of which i/4 then
    dropped ("a definite proof wins"). A signed determination stating eleven
    conditions of one row ran past the test runner's 30 seconds. reasoner.pl
    now assumes a ground goal only when the program cannot prove it.

    Run with:  swipl -q -g run_tests -t halt testing/test_stated_unknowns.pl
*/

:- module(test_stated_unknowns, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

program("the target language is: prolog.

the templates are:
    *a counterparty* is covered.
    *a counterparty* holds a banking licence.
    *a counterparty* meets *a condition*; unknown.

the knowledge base k includes:

a counterparty is covered if
    the counterparty holds a banking licence
    and the counterparty meets condition c1
    and the counterparty meets condition c2
    and the counterparty meets condition c3
    and the counterparty meets condition c4
    and the counterparty meets condition c5
    and the counterparty meets condition c6
    and the counterparty meets condition c7
    and the counterparty meets condition c8
    and the counterparty meets condition c9
    and the counterparty meets condition c10
    and the counterparty meets condition c11
    and the counterparty meets condition c12
    and the counterparty meets condition c13
    and the counterparty meets condition c14
    and the counterparty meets condition c15
    and the counterparty meets condition c16.

scenario stated is:
    acme holds a banking licence.
    acme meets condition c1.
    acme meets condition c2.
    acme meets condition c3.
    acme meets condition c4.
    acme meets condition c5.
    acme meets condition c6.
    acme meets condition c7.
    acme meets condition c8.
    acme meets condition c9.
    acme meets condition c10.
    acme meets condition c11.
    acme meets condition c12.
    acme meets condition c13.
    acme meets condition c14.
    acme meets condition c15.
    acme meets condition c16.
    q expects answers [\"acme is covered\"].

scenario half is:
    acme holds a banking licence.
    acme meets condition c1.
    acme meets condition c2.
    acme meets condition c3.
    acme meets condition c4.
    acme meets condition c5.
    acme meets condition c6.
    acme meets condition c7.
    acme meets condition c8.
    q expects answers [\"acme is covered\"] and unknowns [\"acme meets condition c9\", \"acme meets condition c10\", \"acme meets condition c11\", \"acme meets condition c12\", \"acme meets condition c13\", \"acme meets condition c14\", \"acme meets condition c15\", \"acme meets condition c16\"].

query q is:
    which counterparty is covered.
").

:- begin_tests(stated_unknowns).

test(sixteen_stated_conditions_answer_at_once) :-
    program(P),
    tmp_file_stream(text, File, S), write(S, P), close(S),
    call_with_time_limit(20, le_kbs:runTestsFor(File, test_file(_, Results))),
    delete_file(File),
    %  both: all stated (no unknowns), half stated (the other half assumed)
    assertion(Results == [pass(q, stated), pass(q, half)]).

:- end_tests(stated_unknowns).
