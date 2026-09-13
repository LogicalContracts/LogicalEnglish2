/** <module> Why not, calendar months, and what came with them

    The unmet conditions of a failed query (le_why_not.pl): only the
    alternatives that came closest, each leaf "not stated" or "not met", with
    the rule that asks for it, its provenance and the facts it compared; the
    answeringQuery `unmet` reply and the openQuestions it now prunes. Also:
    "*a date* is *a number* months after *a date*" (calendar months), dates
    rendered as written (2021-10-09), a view's "the flip keeps …", "the
    section … reads …" and "the draft reads … when it holds / does not", the
    verifier's silence on an included library's unused vocabulary, and the
    English-to-LE check of values no rule reads.

    Run with:  swipl -q -g run_tests -t halt testing/test_why_not.pl
*/

:- module(test_why_not, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_why_not').
:- use_module('../classic_web_api').
:- use_module('../nl_to_le').

oxygen("the target language is: prolog.

the templates are:
    *a claim* is payable.
    *a claim* is for *an item*; undefined.
    the code of *an item* is *a code*; undefined.
    *an item* is furnished to *a person*; undefined.
    the saturation of *a person* is *a number*; undefined.
    *a person* is hypoxemic.
    *a person* has a qualifying condition; undefined.
    *an item* was made by the supplier; undefined.

the knowledge base oxygen includes:

the policy is published at \"https://example.org/policy\".

rule oxygen_route with provenance the policy, confer \"oxygen is covered when the person is hypoxemic\":
a claim is payable
    if the claim is for an item
    and the code of the item is \"A1\"
    and the item is furnished to a person
    and it is not the case that
        the item was made by the supplier
    and the person is hypoxemic.

rule other_route with provenance the policy, confer \"the other device is covered for a qualifying condition\":
a claim is payable
    if the claim is for an item
    and the code of the item is \"B2\"
    and the item is furnished to a person
    and the person has a qualifying condition.

rule saturation with provenance the policy, confer \"a saturation at or below 88 percent\":
a person is hypoxemic
    if the saturation of the person is a number
    and the number <= 88.

scenario ben is:
    claim 1 is for the concentrator.
    the code of the concentrator is \"A1\".
    the concentrator is furnished to Ben.
    the saturation of Ben is 90.

scenario ann is:
    claim 1 is for the concentrator.
    the code of the concentrator is \"A1\".
    the concentrator is furnished to Ann.

scenario cy is:
    claim 1 is for the concentrator.
    the code of the concentrator is \"A1\".
    the concentrator is furnished to Cy.
    the concentrator was made by the supplier.
    the saturation of Cy is 80.

query pay is:
    which claim is payable.
").

unmet(Scenario, Items) :-
    once(unmet_(Scenario, Items)).

unmet_(Scenario, Items) :-
    oxygen(P), load_text(P, KB),
    createSession(KB, SM), setScenarion(SM, Scenario),
    assertz(SM:detailed_failures),
    le_kbs:query_explain(SM, pay, _, _, Why),
    le_why_not:unmet_json(SM, KB, Why, Items),
    destroySession(SM).

:- begin_tests(why_not).

% The closest route fails on a comparison: that is the reason, cited, with the
% fact it compared; the other route (another code) is not a reason.
test(comparison_not_met) :-
    unmet(ben, Items),
    assertion(Items = [_]),
    Items = [I],
    assertion(I.kind == not_met),
    assertion(I.literal == "90 is less than or equal to 88"),
    assertion(I.rule == saturation),
    assertion(I.provenance.quote == "a saturation at or below 88 percent"),
    assertion(memberchk("the saturation of Ben is 90", I.facts)).

% The record is silent: "not stated", with what to state and its template.
test(silent_record_not_stated) :-
    unmet(ann, Items),
    Items = [I],
    assertion(I.kind == not_stated),
    assertion(sub_string(I.literal, 0, _, _, "the saturation of Ann is")),
    assertion(I.label == "the saturation of *a person* is *a number*").

% A negation whose subject holds is not met, the fact that holds given.
test(negation_not_met) :-
    unmet(cy, Items),
    Items = [I],
    assertion(I.kind == not_met),
    assertion(I.rule == oxygen_route),
    assertion(memberchk("the concentrator was made by the supplier", I.facts)).

% The rule attempts count the conditions that held before the failure.
test(rule_progress_counts, [nondet]) :-
    oxygen(P), load_text(P, KB),
    createSession(KB, SM), setScenarion(SM, ben),
    assertz(SM:detailed_failures),
    le_kbs:query_explain(SM, pay, _, _, Why),
    findall(M/T, ( sub_term(X, Why), compound(X), X = rule_attempt(_, M, T) ), MTs0), msort(MTs0, MTs),
    destroySession(SM),
    assertion(MTs == [1/4, 4/5]).

% answeringQuery replies with `unmet` when asked (whyNot), and the section
% of openQuestions asks only what the closest route lacks.
test(api_unmet_and_open_questions) :-
    oxygen(P), load_text(P, KB),
    createSession(KB, SM), atom_string(SM, SMS),
    classic_web_api:handle_answering_query(_{sessionModule: SMS, scenario: "ann", query: "pay", whyNot: true}, R),
    assertion(R.results == []),
    R.unmet = [U],
    assertion(U.kind == not_stated),
    classic_web_api:handle_open_questions(_{sessionModule: SMS, scenario: "ann", query: "pay"}, Q),
    get_dict(missing, Q, Missing),
    Missing = [L|_], get_dict(literal, L, Lit),
    assertion(sub_string(Lit, 0, _, _, "the saturation of Ann")),
    assertion(\+ ( member(M2, Missing), get_dict(literal, M2, Lit2), sub_string(Lit2, _, _, _, "B2") )),
    destroySession(SM).

:- end_tests(why_not).

% ---------------------------------------------------------------------------

:- begin_tests(calendar_months).

test(months_after_computes_and_counts) :-
    reasoner:le_is_months_after(L, 6, date(2025, 8, 28)), assertion(L == date(2026, 2, 28)),
    reasoner:le_is_months_after(L2, 6, date(2025, 8, 31)), assertion(L2 == date(2026, 2, 28)),
    reasoner:le_is_months_after(L3, 6, date(2023, 8, 31)), assertion(L3 == date(2024, 2, 29)),
    reasoner:le_is_months_after(date(2026, 2, 28), N, date(2025, 8, 28)), assertion(N == 6),
    reasoner:le_is_months_after(date(2026, 2, 27), N2, date(2025, 8, 28)), assertion(N2 == 5),
    reasoner:le_is_months_after(date(2025, 8, 28), N3, date(2026, 2, 28)), assertion(N3 == -6),
    reasoner:le_is_months_after(date(2026, 3, 1), 6, B), assertion(B == date(2025, 9, 1)).

test(months_in_a_program) :-
    load_text("the target language is: prolog.

the templates are:
    *a person* was examined on *a date*; undefined.
    *a person* was ordered on *a date*; undefined.
    the order of *a person* is timely.

the knowledge base months includes:

the order of a person is timely
    if the person was examined on a date
    and the person was ordered on an other date
    and a limit is 6 months after the date
    and the other date is before or equal to the limit.

scenario edge is:
    ann was examined on 2025-08-28.
    ann was ordered on 2026-02-28.
    bob was examined on 2025-08-27.
    bob was ordered on 2026-02-28.

query timely is:
    the order of which person is timely.
", KB),
    createSession(KB, SM), setScenarion(SM, edge),
    findall(A, ( query(SM, timely, I, _, _), canonical_string(I, A) ), As),
    destroySession(SM),
    assertion(As == ["the order of ann is timely"]).

% A date reads as it is written.
test(dates_render_iso) :-
    le_kbs:token_to_atom(date(2021, 10, 9), A), assertion(A == '2021-10-09').

:- end_tests(calendar_months).

% ---------------------------------------------------------------------------

:- begin_tests(flip_keeps).

recoding("the target language is: prolog.

the templates are:
    *a claim* is payable.
    *a claim* is for *an item*; undefined.
    the code of *an item* is *a code*; undefined.
    *an item* was delivered; undefined.

the knowledge base recoding includes:

a claim is payable
    if the claim is for an item
    and the code of the item is \"A1\"
    and the item was delivered.

a claim is payable
    if the claim is for an item
    and the code of the item is \"B2\".

scenario chair is:
    claim 1 is for the chair.
    the code of the chair is \"A1\".

query flip is:
    which minimal change to the scenario makes it the case that
        claim 1 is payable.
").

flips(KB, Keep, Answers) :-
    le_flip:keep_templates(KB, Keep),
    createSession(KB, SM), setScenarion(SM, chair),
    findall(A, ( query(SM, flip, I, _, _), canonical_string(I, A) ), As0),
    destroySession(SM),
    le_flip:keep_templates(none, []),
    msort(As0, Answers).

% Without keeping it, "another code" is one of the smallest changes; kept, the
% code is left as it is.
test(keep_the_code) :-
    recoding(P), load_text(P, KB),
    flips(KB, [], All),
    assertion(( member(X, All), sub_string(X, _, _, _, "B2") )),
    flips(KB, ["the code of *an item* is *a code*"], Kept),
    assertion(Kept == ["add: the chair was delivered"]).

:- end_tests(flip_keeps).

% ---------------------------------------------------------------------------

:- begin_tests(view_sentences_2).

view_program(View, Text) :-
    format(string(Text), "the target language is: prolog.

the templates are:
    *a person* gets help.
    *a person* is resident; undefined.

the knowledge base help includes:

section question is:

a person gets help
    if the person is resident.

scenario ann is:
    ann is resident.

query help is:
    which person gets help.

~w", [View]).

test(keeps_sections_and_drafts) :-
    view_program("the view desk is:
    the result is the answer to query help.
    the section question reads \"The criteria\".
    the result can be flipped.
    the flip keeps
        a person is resident.
    the draft reads \"Granted: {the result}\" when it holds.
    the draft reads \"Refused:\\n{the reasons}\" when it does not.
", P),
    load_text(P, KB),
    le_views:program_views(KB, [V]),
    assertion(V.keep == ["*a person* is resident"]),
    V.sections = [Sec], assertion(Sec.section == "question"), assertion(Sec.text == "The criteria"),
    assertion(V.draftHolds == "Granted: {the result}"),
    assertion(sub_string(V.draftNot, 0, _, _, "Refused:")),
    assertion(\+ ( le_views:view_issue(KB, issue(T, _, _, _, _)), sub_atom(T, 0, _, _, view_) )).

test(unknown_section_is_reported) :-
    view_program("the view desk is:
    the result is the answer to query help.
    the section remedy reads \"Payment\".
", P),
    load_text(P, KB),
    findall(T, le_views:view_issue(KB, issue(T, _, _, _, _)), Ts),
    assertion(Ts == [view_unknown_section]).

:- end_tests(view_sentences_2).

% ---------------------------------------------------------------------------

:- begin_tests(library_vocabulary).

write_file(Path, Text) :-
    setup_call_cleanup(open(Path, write, S), write(S, Text), close(S)).

lib_dir(Dir) :- tmp_file(le_lib, Dir), make_directory(Dir).

% An included library's templates this program leaves unused, and a template
% the library's rules read that this program need not state, are not this
% program's warnings; its own unused template is.
test(library_templates_not_warned, [setup(lib_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    directory_file_path(Dir, 'library.le', Lib),
    write_file(Lib, "the target language is: prolog.

the templates are:
    *a person* is tall; undefined.
    *a person* is covered.
    *a person* has no exclusion.

the knowledge base library includes:

a person is covered
    if the person has no exclusion.
"),
    directory_file_path(Dir, 'main.le', Main),
    write_file(Main, "the target language is: prolog.

the knowledge base main includes these resources:
    library.

the templates are:
    *a thing* is odd.

the knowledge base main includes:

scenario s is:
    bob has no exclusion.

query q is:
    which person is covered.
"),
    load(Main, KB),
    le_verifier:verify(KB, Issues),
    findall(T-D, ( member(issue(T, D, _, _, _), Issues), memberchk(T, [unused_template, undefined_predicate]) ), Found),
    assertion(Found = [unused_template-_]),
    Found = [_-Desc], assertion(sub_string(Desc, _, _, _, "odd")).

:- end_tests(library_vocabulary).

% ---------------------------------------------------------------------------

:- begin_tests(fragment_values).

% A fact the model wrote with a value no rule reads, where the rules read a
% short list: reported, with the list.
test(unread_value_in_a_fragment) :-
    P = "the target language is: prolog.

the templates are:
    *a person* is covered.
    the finding *a finding* about *a person* is *an outcome*; judged.

the knowledge base k includes:

a person is covered
    if the finding trained on the monitor about the person is established.

scenario s is:
    the finding trained on the monitor about ann is established.

query q is:
    which person is covered.
",
    nl_to_le:baseline(P, false, B),
    nl_to_le:check_fragment(facts, P, B, "the finding trained to use it about hal is established.\n", New),
    include([I]>>get_dict(type, I, "unread_value"), New, [I2|_]),
    get_dict(message, I2, Msg),
    assertion(sub_string(Msg, _, _, _, "trained on the monitor")).

:- end_tests(fragment_values).
