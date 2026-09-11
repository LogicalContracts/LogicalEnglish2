/** <module> Provenance trailers, judged templates, "scenario facts require provenance"

    LE_extensions_proposal §3.1, docs/le_summary.md §17.1. A fact may carry
    trailers — `according to <source>`, `as stated in <document> at
    <locator>`, `because "<text>"` — recorded as le_fact_provenance/4 against
    the fact's source range and asserted per session as le_provenance/5. Proof
    is unaffected; explanations render the trailers. A `; judged` template is
    solved like an assumable one, its open instances render as judgments
    needed, and the verifier reports rules concluding it and judgments without
    provenance.

    Run with:  swipl -q -g run_tests -t halt testing/test_provenance.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_provenance, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_documents').
:- use_module(library(pcre)).

program(Extra, ScenarioFacts, Text) :-
    format(string(Text), "the target language is: prolog.
scenario facts require provenance.

the templates are:
    *a claim* is payable.
    *a claim* is for *a damage*; undefined.
    *a damage* is accidental; judged.
    *a damage* is reported within the time limit; undefined.
    *a damage* is sudden; undefined.

the knowledge base judged damage includes:

a claim is payable
    if the claim is for a damage
    and the damage is reported within the time limit
    and the damage is accidental.
~w
scenario decided is:
~w
query payable is:
    which claim is payable.
", [Extra, ScenarioFacts]).

decided_facts("    claim one is for the burst pipe, as stated in the claim form at section 2.
    the burst pipe is reported within the time limit, according to the insurer, as stated in the claim log at entry 7.
    the burst pipe is accidental,
        according to the loss adjuster, as stated in report LA-17 at page 3,
        because \"corrosion was not visible, and the pipe was new\".
").

load_decided(KB) :-
    decided_facts(F),
    program("", F, P),
    load_text(P, KB).

issue_types(KB, Severity, Types) :-
    findall(T, KB:le_issue(Severity, T, _, _, _, _), Ts),
    msort(Ts, Types).

answers(KB, Scenario, Query, Answers) :-
    createSession(KB, SM),
    setScenarion(SM, Scenario),
    findall(A-Us, ( query(SM, Query, I, Us0, _), canonical_string(I, A),
                    maplist(unknown_text(KB), Us0, Us) ), Answers),
    destroySession(SM).

unknown_text(KB, U, S) :- item_to_instance(KB, U, T), canonical_string(T, S).

resource_dir(Dir) :-
    tmp_file(le_prov, Dir),
    make_directory(Dir).

write_file(Path, Text) :-
    setup_call_cleanup(open(Path, write, S), write(S, Text), close(S)).

why_literals(Why, Lits) :-
    findall(L, why_literal(Why, L), Lits).
why_literal(L0, L) :- is_list(L0), !, member(X, L0), why_literal(X, L).
why_literal(success(_, _, LE, Cs), L) :- ( L = LE ; why_literal(Cs, L) ).
why_literal(failure(_, _, LE, Cs), L) :- ( L = LE ; why_literal(Cs, L) ).

:- begin_tests(provenance).

test(trailers_recorded_verbatim) :-
    load_decided(KB),
    KB:le_fact_provenance(_, _, is_accidental('the burst pipe'), Prov), !,
    Prov == prov('the loss adjuster', doc('report LA-17', "report LA-17"), "page 3",
                 "corrosion was not visible, and the pipe was new").

test(document_without_source_is_the_source) :-
    load_decided(KB),
    KB:le_fact_provenance(_, _, is_for('claim one', 'the burst pipe'), Prov), !,
    le_provenance:prov_effective_source(Prov, 'the claim form').

test(proof_is_unaffected) :-
    load_decided(KB),
    answers(KB, decided, payable, Answers),
    Answers == ["claim one is payable"-[]].

test(session_gets_public_provenance) :-
    load_decided(KB),
    createSession(KB, SM),
    setScenarion(SM, decided),
    findall(S, SM:le_provenance(_, S, _, _, _), Sources0),
    msort(Sources0, Sources),
    destroySession(SM),
    Sources == ['the claim form', 'the insurer', 'the loss adjuster'].

test(explanation_carries_trailers) :-
    load_decided(KB),
    createSession(KB, SM),
    setScenarion(SM, decided),
    once(query(SM, payable, _, [], Why)),
    destroySession(SM),
    why_literals(Why, Lits),
    memberchk("the burst pipe is accidental, according to the loss adjuster, as stated in report LA-17 at page 3, because \"corrosion was not visible, and the pipe was new\"", Lits),
    memberchk("claim one is for the burst pipe, as stated in the claim form at section 2", Lits).

test(judged_unknown_is_a_judgment_needed) :-
    program("", "    claim one is for the burst pipe, as stated in the claim form at section 2.
    the burst pipe is reported within the time limit, as stated in the claim log at entry 7.
", P),
    load_text(P, KB),
    answers(KB, decided, payable, Answers),
    Answers == ["claim one is payable"-["the burst pipe is accidental"]],
    createSession(KB, SM),
    setScenarion(SM, decided),
    once(query(SM, payable, _, _, Why)),
    destroySession(SM),
    why_literals(Why, Lits),
    memberchk("the burst pipe is accidental (judgment needed)", Lits).

test(no_issues_when_everything_is_attributed) :-
    load_decided(KB),
    issue_types(KB, error, []),
    issue_types(KB, warning, Ws),
    \+ memberchk(fact_without_provenance, Ws),
    \+ memberchk(judgment_without_provenance, Ws).

test(judged_with_rules_is_an_error) :-
    decided_facts(F),
    program("\na damage is accidental if the damage is sudden.\n", F, P),
    load_text(P, KB),
    issue_types(KB, error, Errors),
    memberchk(judged_with_rules, Errors).

test(fact_without_provenance_warns) :-
    program("", "    claim one is for the burst pipe.
    the burst pipe is reported within the time limit, as stated in the claim log at entry 7.
    the burst pipe is accidental, according to the loss adjuster.
", P),
    load_text(P, KB),
    findall(D, KB:le_issue(warning, fact_without_provenance, D, _, _, _), Ds),
    Ds = [D1],
    once(sub_atom(D1, _, _, _, 'claim one is for the burst pipe')).

test(judgment_needs_who_or_why) :-
    program("", "    claim one is for the burst pipe, as stated in the claim form at section 2.
    the burst pipe is reported within the time limit, as stated in the claim log at entry 7.
    the burst pipe is accidental, as stated in report LA-17.
", P),
    load_text(P, KB),
    issue_types(KB, warning, Ws),
    memberchk(judgment_without_provenance, Ws).

% A comma inside a fact that is NOT followed by a trailer keyword is still part
% of the fact, exactly as before.
test(plain_commas_untouched) :-
    load_text("the target language is: prolog.

the templates are:
    *a person* lives at *an address*.

the knowledge base k includes:
a person is housed if the person lives at an address.

scenario s is:
    ann lives at 12 High Street, Oxford.

query q is:
    which person lives at which address.
", KB),
    createSession(KB, SM), setScenarion(SM, s),
    findall(A, SM:lives_at(ann, A), As),
    destroySession(SM),
    As == ['12 High Street, Oxford'].

% A template may itself contain a trailer phrase: the sentence is then an
% ordinary fact of that template.
test(template_owning_trailer_words) :-
    load_text("the target language is: prolog.

the templates are:
    the limit for *a section* is *an amount*, as stated in your schedule.
    *a section* is capped.

the knowledge base k includes:
a section is capped if the limit for the section is an amount, as stated in your schedule.

scenario s is:
    the limit for section one is 100, as stated in your schedule.
    the limit for section two is 200, as stated in your schedule, according to the broker.

query q is:
    which section is capped.
", KB),
    findall(E, KB:le_issue(error, E, _, _, _, _), []),
    createSession(KB, SM), setScenarion(SM, s),
    findall(A, ( query(SM, q, I, _, _), canonical_string(I, A) ), As0), msort(As0, As),
    destroySession(SM),
    As == ["section one is capped", "section two is capped"],
    \+ KB:le_fact_provenance(_, _, the_limit_for_is_as_stated_in_your_schedule('section one', _), _),
    once(KB:le_fact_provenance(_, _, _, prov('the broker', none, none, none))).

test(custom_facts_carry_provenance) :-
    load_decided(KB),
    once(parse_custom_facts(KB, "the burst pipe is accidental, according to the ombudsman.", Terms)),
    memberchk(le_provenance(is_accidental('the burst pipe'), 'the ombudsman', none, none, none), Terms).

% A judged template with two or more arguments: the last is the outcome. Once
% an outcome is recorded for a question, no other outcome of it is assumed;
% a question with nothing recorded stays open (a judgment needed).
test(judged_outcome_closes_the_question) :-
    load_text("the target language is: prolog.

the templates are:
    *a good* is an article.
    the principal use of *a good* is *a use*; judged.
    *a good* is described by heading *a heading*.

the knowledge base uses includes:

a good is described by heading 3923
    if the good is an article
    and the principal use of the good is packing.

a good is described by heading 3924
    if the good is an article
    and the principal use of the good is household use.

scenario s is:
    the bin is an article.
    the principal use of the bin is household use, according to CBP, because \"it holds laundry\".
    the crate is an article.

query q is:
    which good is described by heading which heading.
", KB),
    answers(KB, s, q, Answers0),
    msort(Answers0, Answers),
    Answers == ["the bin is described by heading 3924"-[],
                "the crate is described by heading 3923"-["the principal use of the crate is packing"],
                "the crate is described by heading 3924"-["the principal use of the crate is household use"]].

% A fact of an included resource keeps the verbatim spelling of its trailers,
% read from the resource's own text (its offsets are offsets into it), and its
% provenance is not confused with a fact of the includer at the same offsets.
test(resource_fact_trailers_verbatim, [setup(resource_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    directory_file_path(Dir, 'lib.le', Lib),
    directory_file_path(Dir, 'main.le', Main),
    write_file(Lib, "the target language is: prolog.

the templates are:
    *a heading* beats *an other heading*.

the knowledge base lib includes:

6106 beats 6109,
    according to CBP, as stated in HQ H325360 at page 07,
    because \"loose tops are blouses\".
"),
    write_file(Main, "the target language is: prolog.

the knowledge base main includes these resources:
    lib.

the knowledge base main includes:

query q is:
    which heading beats which other heading.
"),
    load(Main, KB),
    KB:le_fact_provenance(_, _, beats(6106, 6109), Prov), !,
    Prov == prov('CBP', doc('HQ H325360', "HQ H325360"), "page 07", "loose tops are blouses").

% "rule <name> with provenance <provenance>:" (docs/le_summary.md §15.5): the
% trailers of a fact, or one quoted string (a URL or a citation); a table
% header may carry the same. Recorded as le_rule_provenance(ID, Prov).
cited_program("the target language is: prolog.

the templates are:
    *a person* is eligible.
    *a person* is resident; undefined.
    *a person* is old; undefined.
    the rate for *a person* is *a rate* under table rates.

the table rates is, with first match, with provenance \"https://example.org/rates.html\":
    kind | person | rate
    r1   | any    | 5

the knowledge base cited includes:

the benefit act is published at \"https://example.org/act.html\".
the text of the benefit act is at \"sources/act.txt\".

rule s2 with provenance as stated in the benefit act at \"a resident is eligible\",
        because \"section 2\":
a person is eligible
    if the person is resident.

rule s3 with provenance \"https://example.org/act.html#s3\":
a person is eligible
    if the person is old.

scenario s is:
    ann is resident.

query q is:
    which person is eligible.
").

test(rule_label_provenance) :-
    cited_program(P),
    load_text(P, KB),
    KB:le_rule_provenance(s2, prov(none, doc('the benefit act', _), "\"a resident is eligible\"", "section 2")),
    KB:le_rule_provenance(s3, prov(none, doc('https://example.org/act.html#s3', _), none, none)),
    KB:le_rule_provenance(table_rates, prov(none, doc('https://example.org/rates.html', _), none, none)),
    % the labelled rules still reason as before
    answers(KB, s, q, ["ann is eligible"-[]]).

% The editor's view of a provenance: the published address and the text
% address come from "<document> is published at" / "the text of <document>
% is at"; a quoted locator is the quotation.
test(provenance_dict_addresses) :-
    cited_program(P),
    load_text(P, KB),
    KB:le_rule_provenance(s2, Prov),
    le_provenance:provenance_dict(none, KB, Prov, D),
    D.url == "https://example.org/act.html",
    D.text == "sources/act.txt",
    D.quote == "a resident is eligible",
    KB:le_rule_provenance(s3, Prov3),
    le_provenance:provenance_dict(none, KB, Prov3, D3),
    D3.url == "https://example.org/act.html#s3".

% A quotation must be in the document's text when the program says where the
% text is (white space, no-break spaces and case aside); otherwise the
% verifier warns quote_not_found.
test(quote_checked_against_the_text, [setup(resource_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    directory_file_path(Dir, 'sources', Src),
    make_directory(Src),
    directory_file_path(Src, 'act.txt', Act),
    write_file(Act, "Section 2. A\u00a0resident   is\nELIGIBLE for help."),
    cited_program(P),
    directory_file_path(Dir, 'good.le', Good),
    write_file(Good, P),
    load(Good, KB1),
    issue_types(KB1, warning, W1),
    \+ memberchk(quote_not_found, W1),
    split_string(P, "", "", [P0]),
    re_replace("a resident is eligible"/g, "a resident is wealthy", P0, P1),
    directory_file_path(Dir, 'bad.le', Bad),
    write_file(Bad, P1),
    load(Bad, KB2),
    issue_types(KB2, warning, W2),
    memberchk(quote_not_found, W2).

% A document's text: a file inside the program's folder, never outside it.
test(document_text_stays_in_the_folder, [setup(resource_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    directory_file_path(Dir, 'doc.txt', F),
    write_file(F, "the text"),
    le_documents:document_text("doc.txt", Dir, [], T),
    T == "the text",
    catch(le_documents:document_text("../doc.txt", Dir, [], _), error(document_error(_), _), true),
    \+ catch(le_documents:document_text("../doc.txt", Dir, [], _), _, fail).

% The light notation: a scenario's default provenance ("scenario s is, as
% stated in <document>:"), facts pointing at passages with confer "...", a fact
% redefining the document with its own "as stated in"; a rule's provenance as
% just a document, a document at a locator, or a document and a confer.
light_program("the target language is: prolog.
scenario facts require provenance.

the templates are:
    *a person* is eligible.
    *a person* is resident; undefined.
    *a person* is old; undefined.
    *a person* is poor; undefined.

the knowledge base light includes:

rule s2 with provenance the benefit act, confer \"a resident is eligible\":
a person is eligible
    if the person is resident.

rule s3 with provenance the benefit act at section 3:
a person is eligible
    if the person is old.

rule s4 with provenance \"https://example.org/act.html#s4\":
a person is eligible
    if the person is poor.

scenario s is, as stated in the census:
    ann is resident.
    bob is resident,
        confer \"Bob, resident of York\".
    cy is old, as stated in the tax register at page 7.
    dee is poor, according to the council.
    q expects answers [\"ann is eligible\", \"bob is eligible\", \"cy is eligible\", \"dee is eligible\"].

query q is:
    which person is eligible.
").

test(light_notation) :-
    light_program(P),
    load_text(P, KB),
    issue_types(KB, warning, Ws),
    \+ memberchk(fact_without_provenance, Ws),
    \+ memberchk(malformed_provenance, Ws),
    KB:le_fact_provenance(_, _, is_resident(ann), prov(none, doc('the census', _), none, none)),
    KB:le_fact_provenance(_, _, is_resident(bob), prov(none, doc('the census', _), "\"Bob, resident of York\"", none)),
    KB:le_fact_provenance(_, _, is_old(cy), prov(none, doc('the tax register', _), "page 7", none)),
    KB:le_fact_provenance(_, _, is_poor(dee), prov('the council', doc('the census', _), none, none)),
    KB:le_rule_provenance(s2, prov(none, doc('the benefit act', _), "\"a resident is eligible\"", none)).

test(light_rule_forms) :-
    light_program(P),
    load_text(P, KB),
    KB:le_rule_provenance(s3, prov(none, doc('the benefit act', _), "section 3", none)),
    KB:le_rule_provenance(s4, prov(none, doc('https://example.org/act.html#s4', _), none, none)),
    answers(KB, s, q, Answers0), msort(Answers0, Answers),
    Answers == ["ann is eligible"-[], "bob is eligible"-[], "cy is eligible"-[], "dee is eligible"-[]].

% An explanation renders a quoted passage as confer "...".
test(confer_rendered) :-
    light_program(P),
    load_text(P, KB),
    createSession(KB, SM), setScenarion(SM, s),
    findall(W, query(SM, q, _, _, W), Whys),
    destroySession(SM),
    why_literals(Whys, Lits),
    memberchk("bob is resident, as stated in the census, confer \"Bob, resident of York\"", Lits).

test(portuguese_trailers) :-
    load_text("a linguagem alvo é: prolog.

os modelos são:
    *um sinistro* é pagável.
    *um dano* é acidental; julgado.

a base de conhecimento danos inclui:
um sinistro é pagável se o sinistro é acidental.

cenário s é:
    o cano é acidental, de acordo com o perito, porque \"não havia corrosão\".

consulta q é:
    qual sinistro é pagável.
", KB),
    KB:le_fact_provenance(_, _, _, Prov), !,
    Prov = prov(Src, none, none, "não havia corrosão"),
    Src == 'o perito'.

:- end_tests(provenance).
