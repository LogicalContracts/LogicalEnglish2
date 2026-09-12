/** <module> Views (docs/le_summary.md §17.10)

    A view is a section of sentences saying how a screen shows the program:
    compiled by le_views.pl into the load's `views`, checked by the verifier,
    drafted by the LE Assistant's "Generate LE view" (le_views:draft_view/2).
    The screen's server operations: openQuestions, and the section
    `checklist` of answeringQuery.

    Run with:  swipl -q -g run_tests -t halt testing/test_views.pl
*/

:- module(test_views, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_views').
:- use_module('../classic_web_api').

program(View, Text) :-
    format(string(Text), "the target language is: prolog.
scenario facts require provenance.

the templates are:
    *a person* gets help.
    *a person* is resident; undefined.
    *a person* is on a low income; undefined.
    *a person* is deserving; judged.
    the help for *a person* is *an amount*.
    the rent of *a person* is *an amount*; undefined.

the knowledge base help includes:

the census is published at \"https://example.org/census\".

a person gets help
    if the person is resident
    and the person is on a low income.

the help for a person is an amount
    if the person gets help
    and the rent of the person is a rent
    and the amount is the rent / 2.

scenario ann is, as stated in the census:
    ann is resident.
    ann is on a low income.
    the rent of ann is 800.
    help expects answers [\"the help for ann is 400\"].

scenario bob is, as stated in the census:
    bob is resident.
    the rent of bob is 600.

query help is:
    the help for which person is which amount.

~w", [View]).

good_view("the view desk is:
    the title is \"Help desk\".
    the case is a scenario, with the documents it is stated in.
    the facts about \"the applicant\" are
        a person is resident,
        a person is on a low income,
        the rent of a person is an amount.
    the judgments are
        a person is deserving.
    every fact shows who states it.
    the result is the answer to query help, headed by the amount, in euros.
    the result shows its citations.
    the result shows its reasons.
    the result asks what is missing.
    the result can be flipped, as \"What would change it?\".
    the answers to \"which person is resident\" are listed as \"Residents\".
    the result is compared with scenario bob.
    the documents of the case are shown beside the facts.
    the cases are listed with their results.
    the draft reads \"The help is {the result}.\".
").

view_of(KB, Name, View) :-
    le_views:program_views(KB, Views),
    member(View, Views), View.name == Name, !.

view_issues(KB, Types) :-
    findall(T, ( KB:le_issue(_, T, _, _, _, _), sub_atom(T, 0, _, _, view_) ), Ts),
    msort(Ts, Types).

:- begin_tests(views).

% Every sentence form reads into the view the screen renders.
test(compiles_every_sentence) :-
    good_view(V), program(V, P), load_text(P, KB),
    view_issues(KB, Issues),
    assertion(Issues == []),
    view_of(KB, desk, D),
    assertion(D.title == "Help desk"),
    assertion(D.case.documents == true),
    D.groups = [G1, G2],
    assertion(G1.title == "the applicant"),
    findall(L, ( member(F, G1.facts), get_dict(label, F, L) ), Labels),
    assertion(Labels == ["*a person* is resident", "*a person* is on a low income", "the rent of *a person* is *an amount*"]),
    assertion(G2.judged == true),
    assertion(D.sources == true),
    assertion(D.result.query == "help"),
    assertion(D.result.headedBy == "the amount"),
    assertion(D.result.unit == "euros"),
    assertion(D.flip.label == "What would change it?"),
    assertion(D.tables = [_{question: "which person is resident", title: "Residents"}]),
    assertion(D.compare == ["bob"]),
    assertion(D.draft == "The help is {the result}."),
    assertion(D.order == [facts, result, citations, reasons, questions, whatif, tables, compare, documents, cases, draft]).

% An interview: the subject, the questions, the result as a yes/no.
test(interview) :-
    program("the view check is:
    the case is about the applicant.
    the facts are asked one at a time.
    the question for the applicant is resident is \"Do you live here?\".
    the question for the applicant is on a low income is \"Is your income low?\".
    the result is whether the applicant gets help.
    the result reads \"You can get help.\" when it holds.
    the result reads \"You cannot.\" when it does not.
", P),
    load_text(P, KB),
    view_issues(KB, Issues),
    assertion(Issues == []),
    view_of(KB, check, D),
    assertion(D.interview == true),
    assertion(D.case.subject == "the applicant"),
    assertion(D.result.whether == "the applicant gets help"),
    assertion(D.result.holds == "You can get help."),
    assertion(D.result.not == "You cannot."),
    D.questions = [Q1, Q2],
    assertion(Q1.text == "Do you live here?"),
    assertion(Q1.instance == "the applicant is resident"),
    assertion(Q2.label == "*a person* is on a low income").

% What the verifier says about a view that names what the program lacks.
test(ill_formed_views_are_reported) :-
    program("the view broken is:
    the facts about \"x\" are
        a person is resident,
        a person flies to the moon,
        a person gets help.
    the judgments are
        a person is resident.
    the colour is blue.
    the result is the answer to query helps.
    the result is compared with scenario nobody.
    the answers to \"which dragon breathes fire\" are listed as \"Dragons\".
    the result shows the stage it reaches.

the view broken is:
    the result is the answer to query help, headed by the colour.
", P),
    load_text(P, KB),
    view_issues(KB, Types),
    assertion(Types == [view_bad_question, view_derived_fact, view_duplicate_name, view_headed_by_unknown,
                        view_not_judged, view_stage_without_sections, view_unknown_query,
                        view_unknown_scenario, view_unknown_sentence, view_unknown_template]),
    % errors are errors
    assertion(KB:le_issue(error, view_unknown_template, _, _, _, _)),
    assertion(KB:le_issue(warning, view_derived_fact, _, _, _, _)).

test(no_result_and_nothing_cited) :-
    load_text("the target language is: prolog.

the templates are:
    *a person* is happy; undefined.

the knowledge base k includes:

bob is happy.

the view v is:
    the facts about \"mood\" are
        a person is happy.
    the result shows its citations.
", KB),
    view_issues(KB, Types),
    assertion(Types == [view_no_result, view_nothing_cited]).

% A view does not change what the program answers, nor its tests.
test(view_changes_nothing_else) :-
    good_view(V), program(V, P1), load_text(P1, KB1),
    program("", P2), load_text(P2, KB2),
    createSession(KB1, S1), setScenarion(S1, ann),
    createSession(KB2, S2), setScenarion(S2, ann),
    findall(I, query(S1, help, I, _, _), A1),
    findall(I, query(S2, help, I, _, _), A2),
    destroySession(S1), destroySession(S2),
    assertion(A1 == A2).

% The LE Assistant's draft: the case facts, the judged ones, the first query,
% what the program can show; a draft the verifier accepts.
test(draft_view) :-
    program("", P), load_text(P, KB),
    le_views:draft_view(KB, Text),
    assertion(sub_string(Text, 0, _, _, "the view help is:")),
    assertion(sub_string(Text, _, _, _, "a person is on a low income")),
    assertion(sub_string(Text, _, _, _, "the judgments are\n        a person is deserving.")),
    assertion(sub_string(Text, _, _, _, "the result is the answer to query help.")),
    assertion(sub_string(Text, _, _, _, "the result shows its citations.")),
    string_concat(P, Text, P2),
    load_text(P2, KB2),
    view_issues(KB2, Issues),
    assertion(Issues == []).

% A program whose knowledge base has no name (a contract's, say) drafted "the
% view is:", which no parser reads: the view takes the file's name instead. A
% template worded with a comma cannot be listed (the list's separator), so the
% draft leaves it out rather than write a list the verifier rejects.
test(draft_view_of_a_program_without_a_name) :-
    P = "the target language is: prolog.

the templates are:
    *a person* is resident.
    *a person* is covered, provided that the premium is paid.

scenario one is:
    ann is resident.

query q is:
    which person is resident.
",
    load_text(P, KB),
    le_views:draft_view(KB, "policy-GLM-5.2", Text),
    assertion(sub_string(Text, 0, _, _, "the view policy GLM 5 2 is:")),
    assertion(sub_string(Text, _, _, _, "the title is \"Policy GLM 5 2\".")),
    assertion(\+ sub_string(Text, _, _, _, "provided that")),
    atomic_list_concat([P, "\n", Text], P2),
    load_text(P2, KB2),
    view_issues(KB2, Issues),
    assertion(Issues == []),
    assertion(\+ KB2:le_issue(error, _, _, _, _, _)),
    view_of(KB2, 'policy GLM 5 2', _).

% A program that declares no view has an automatic one: the draft of Generate
% LE view, compiled when a screen asks for it (operation automaticView).
test(automatic_view) :-
    program("", P), load_text(P, KB),
    le_views:automatic_view(KB, "ignored", V),
    assertion(V.automatic == true),
    assertion(V.name == help),
    assertion(V.result.query == "help"),
    V.groups = [G, J],
    assertion(J.judged == true),
    assertion(length(G.facts, 3)),
    createSession(KB, SM), atom_string(SM, SMS),
    classic_web_api:handle_automatic_view(_{sessionModule: SMS, name: "RulesRus/benefit.le"}, R),
    assertion(R.view.title == "Help"),
    destroySession(SM).

% The screen's operations: the section checklist, the missing facts.
test(open_questions_and_checklist) :-
    program("", P), load_text(P, KB),
    createSession(KB, SM), atom_string(SM, SMS),
    classic_web_api:handle_open_questions(_{sessionModule: SMS, scenario: "bob", query: "help"}, R),
    assertion(R.holds == false),
    findall(L, member(_{literal: L, label: _, goal: _, values: _}, R.missing), Ls),
    assertion(Ls == ["bob is on a low income"]),
    classic_web_api:handle_answering_query(_{sessionModule: SMS, scenario: "ann", query: "help"}, A),
    assertion(A.checklist == []).

% A view in the program's language: its sentences are rows of keywords.csv,
% its facts keep the view's own words (the labels put English articles on the
% placeholders), and the verifier speaks the language too.
test(portuguese_view) :-
    read_file_to_string('examples/pt/cidadania.le', P0, []),
    string_concat(P0, "
a vista balcão é:
    o título é \"Cidadania britânica\".
    o caso é um cenário.
    os factos sobre \"o nascimento\" são
        uma pessoa nasceu em um lugar em uma data,
        uma pessoa é o pai de uma pessoa.
    o resultado é a resposta à consulta um, encabeçado por a pessoa.
    os casos são listados com os seus resultados.
", P),
    load_text(P, KB),
    view_of(KB, 'balcão', D),
    assertion(D.title == "Cidadania britânica"),
    assertion(D.result.query == "um"),
    D.groups = [G],
    findall(W, ( member(F, G.facts), get_dict(words, F, W) ), Ws),
    assertion(Ws == ["uma pessoa nasceu em um lugar em uma data", "uma pessoa é o pai de uma pessoa"]),
    % a rule concludes who the father is: stating it would bypass it
    view_issues(KB, Types),
    assertion(Types == [view_derived_fact]),
    once(KB:le_issue(_, view_derived_fact, Msg, _, _, _)),
    assertion(sub_string(Msg, _, _, _, "uma pessoa é o pai de uma pessoa")).

% The example programs' views compile without issues.
test(example_views, [forall(member(F, ['examples/RulesRus/eu261_integration.le', 'examples/RulesRus/flip_housing.le',
                                       'examples/RulesRus/judged_damage.le', 'examples/RulesRus/sections_benefit.le']))]) :-
    load(F, KB),
    le_views:program_views(KB, [_|_]),
    view_issues(KB, Issues),
    assertion(Issues == []).

:- end_tests(views).
