/** <module> Integrity constraints on assumptions: `it must not be true that …`

    In a Prolog-target program the sentence is a denial that answers must
    respect (le_summary.md §3.3): an answer found by assuming something (the
    `; unknown` templates) is kept only if the case with those assumptions
    breaks no constraint — or can be kept by assuming more — and a case whose
    facts break a constraint on their own answers nothing.

    Run with:  swipl -q -g run_tests -t halt testing/test_constraints.pl
*/

:- module(test_constraints, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_scasp').
:- use_module('../le_writer').
:- use_module('../le_verifier').

example('examples/moreExamples/language/unknowns/assumption_constraints.le').

kb(KB) :-
    example(File),
    read_file_to_string(File, Text, []),
    le_kbs:load_text(Text, 'examples/moreExamples', KB).

%   The answers of a named query in a scenario, each as Answer-Unknowns
%   (strings), sorted.
answers(Scenario, Query, Answers) :-
    kb(KB),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, Scenario),
    findall(A-Us,
            ( le_kbs:query(SM, Query, Instance, Us0, _),
              le_kbs:canonical_string(Instance, A),
              maplist(unknown_string(KB), Us0, Us) ),
            Answers0),
    sort(Answers0, Answers).

unknown_string(KB, U, S) :-
    le_kbs:item_to_instance(KB, U, I), le_kbs:canonical_string(I, S).

:- begin_tests(constraints).

test(assumption_breaking_a_constraint_is_rejected) :-
    answers(commuters, commuters, As),
    assertion(As == ["alice pays tax in spain"-[],
                     "bob pays tax in france"-["bob is resident in france"]]).

test(broken_constraint_kept_by_assuming_more) :-
    answers('one sided', filers, As),
    assertion(As == ["dan files jointly"-["dan is married to erin", "erin is married to dan"]]).

test(unmendable_assumption_is_rejected) :-
    answers(taken, filers, As),
    assertion(As == []).

test(facts_breaking_a_constraint_make_the_case_inconsistent) :-
    answers('two homes', commuters, As),
    assertion(As == []).

test(inconsistent_case_explained_by_the_constraint) :-
    kb(KB),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, 'two homes'),
    le_kbs:query_explain(SM, commuters, _, Us, Why),
    assertion(Us == []),
    assertion(( sub_term(S, Why), compound(S), S = success(le_constraint_broken(_), _, Text, _),
                sub_string(Text, 0, _, _, "the case breaks a constraint") )).

test(consistent_case_is_unaffected) :-
    answers('both sides', filers, As),
    assertion(As == ["dan files jointly"-["dan is married to erin"]]).

test(rejected_sets_are_remembered) :-
    reasoner:clear_rejected_assumptions,
    answers(taken, filers, _),
    reasoner:rejected_assumption_sets(Sets),
    assertion(Sets \== []).

test(constraints_are_scasp_global_constraints) :-
    kb(KB),
    le_scasp:le_scasp_program_text(KB, Text, _),
    assertion(sub_string(Text, _, _, _, "false :-\n    is_married_to(A,B),not(is_married_to(B,A)).")).

test(writer_writes_constraints_back) :-
    kb(KB),
    le_writer:le_write_kb(KB, Text),
    assertion(sub_string(Text, _, _, _, "it must not be true that\n    a person is married to a second person\n    and it is not the case that the second person is married to the person.")).

test(program_without_constraints_unchanged) :-
    read_file_to_string('examples/moreExamples/language/unknowns/unknowns.le', Text, []),
    le_kbs:load_text(Text, 'examples/moreExamples', KB),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, one),
    findall(A, ( le_kbs:query(SM, one, I, _, _), le_kbs:canonical_string(I, A) ), As0),
    sort(As0, As),
    assertion(As == ["alice becomes rich", "bob becomes rich"]).

%   A constraint reads the facts its conditions mention, and is a rule: a
%   program of facts and one constraint draws no missing_rules or
%   unconsumed_facts warning.
test(verifier_counts_constraints_as_rules) :-
    Text = "the target language is: prolog.\n\nthe templates are:\n    *a person* is a person.\n    *a person* is *a number* years of age.\n\nthe knowledge base vc includes:\n\nbob is a person.\nbob is 40 years of age.\n\nit must not be true that\n    a person is a person\n    and the person is a number years of age\n    and the person is a second number years of age\n    and the number is not equal to the second number.\n",
    le_kbs:load_text(Text, '.', KB),
    findall(K, ( le_verifier:check_issue(KB, _, I), arg(1, I, K) ), Ks),
    assertion(\+ memberchk(missing_rules, Ks)),
    assertion(\+ memberchk(unconsumed_facts, Ks)).

:- end_tests(constraints).
