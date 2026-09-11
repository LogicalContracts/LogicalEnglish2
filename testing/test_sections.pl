/** <module> The decision skeleton: reserved section names

    LE_extensions_proposal §3.4, docs/le_summary.md §17.4. Sections named
    applicability / question / remedy change nothing about solving; a failed
    query is read against them: "the query fails at section *a section*" and
    the checklist that failure explanations lead with.

    Run with:  swipl -q -g run_tests -t halt testing/test_sections.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_sections, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

example(KB) :- load('examples/RulesRus/sections_benefit.le', KB).

answers_for(KB, Scenario, QueryText, Answers) :-
    createSession(KB, SM),
    setScenarion(SM, Scenario),
    once(parse_custom_query(KB, QueryText, Goal)),
    findall(A, ( query(SM, Goal, I, _, _), canonical_string(I, A) ), Answers0),
    destroySession(SM),
    msort(Answers0, Answers).

:- begin_tests(sections).

test(fails_at_the_earliest_section) :-
    example(KB),
    % A custom query renders with the template's main form.
    answers_for(KB, out_of_scope, "the query fails at which section", A1),
    A1 == ["the query fails at section applicability"],
    answers_for(KB, not_eligible, "the query fails at which section", A2),
    A2 == ["the query fails at section question"],
    answers_for(KB, no_rent, "the query fails at which section", A3),
    A3 == ["the query fails at section remedy"],
    answers_for(KB, yes, "the query fails at which section", A4),
    A4 == [].

test(check_form_with_section_word) :-
    example(KB),
    answers_for(KB, out_of_scope, "the query fails at section applicability", A1),
    A1 == ["the query fails at section applicability"],
    answers_for(KB, out_of_scope, "the query fails at section remedy", A2),
    A2 == [].

test(named_query_form) :-
    example(KB),
    answers_for(KB, not_eligible, "the query help fails at section question", A),
    A == ["the query help fails at section question"].

test(failure_explanation_leads_with_the_checklist) :-
    example(KB),
    createSession(KB, SM), setScenarion(SM, not_eligible),
    once(query_explain(SM, help, _, _, Why)),
    destroySession(SM),
    Why = [failure(le_section_checklist(Checklist), _, LE, [])|_],
    Checklist == [applicability-passed, question-failed, remedy-not_reached],
    LE == "section checklist: applicability passed, question failed, remedy not reached".

test(no_checklist_without_reserved_names) :-
    load_text("the target language is: prolog.

the templates are:
    *a person* is eligible.
    *a person* lives here; undefined.
    *a person* gets help.
    *a person* is a visitor; undefined.

the knowledge base k includes:
section eligibility is:
a person is eligible if the person lives here.
section payment is:
a person gets help if the person is eligible.

scenario s is:
    bob is a visitor.

query help is:
    which person gets help.
", KB),
    createSession(KB, SM), setScenarion(SM, s),
    once(query_explain(SM, help, _, _, Why)),
    \+ memberchk(failure(le_section_checklist(_), _, _, _), Why),
    once(parse_custom_query(KB, "the query fails at which section", Goal)),
    findall(A, ( query(SM, Goal, I, _, _), canonical_string(I, A) ), As),
    destroySession(SM),
    % Other named sections still answer, in source order.
    As == ["the query fails at section eligibility"].

test(portuguese_section_names) :-
    load_text("a linguagem alvo é: prolog.

os modelos são:
    *uma pessoa* é residente; indefinido.
    *uma pessoa* é elegível.
    *uma pessoa* recebe ajuda.

a base de conhecimento k inclui:
secção aplicabilidade é:
uma pessoa é elegível se a pessoa é residente.
secção remédio é:
uma pessoa recebe ajuda se a pessoa é elegível.

cenário s é:
    ana é elegível.

consulta ajuda é:
    qual pessoa recebe ajuda.
", KB),
    createSession(KB, SM),
    once(query_explain(SM, ajuda, _, _, Why)),
    destroySession(SM),
    Why = [failure(le_section_checklist(Checklist), _, _, [])|_],
    Checklist == [aplicabilidade-failed, 'remédio'-not_reached].

:- end_tests(sections).
