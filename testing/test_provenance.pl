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
