/** <module> Source-scoped proof ("according to <scope>" in a rule body)

    LE_extensions_proposal §3.5, docs/le_summary.md §17.5.

    Run with:  swipl -q -g run_tests -t halt testing/test_scoped_proof.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_scoped_proof, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

answers(KB, Scenario, Query, Answers) :-
    createSession(KB, SM),
    setScenarion(SM, Scenario),
    findall(A, ( query(SM, Query, I, _, _), canonical_string(I, A) ), Answers0),
    destroySession(SM),
    msort(Answers0, Answers).

why_literals(Why, Lits) :- findall(L, why_literal(Why, L), Lits).
why_literal(L0, L) :- is_list(L0), !, member(X, L0), why_literal(X, L).
why_literal(success(_, _, LE, Cs), L) :- ( L = LE ; why_literal(Cs, L) ).
why_literal(failure(_, _, LE, Cs), L) :- ( L = LE ; why_literal(Cs, L) ).

program(Rule, Extra, Text) :-
    format(string(Text), "the target language is: prolog.

the templates are:
    *a tenant* owes the late penalty.
    the rent of *a tenant* is overdue; undefined.
    the notice was delivered to *a tenant*.
    the notice to *a tenant* was left at the door; undefined.
~w
the knowledge base scoped notice includes:

~w

the notice was delivered to a tenant
    if the notice to the tenant was left at the door.

the courier is admissible under the landlord.

scenario proven is:
    the rent of ann is overdue, according to the landlord.
    the notice to ann was left at the door, according to the courier, as stated in delivery slip 44.

scenario by_ann is:
    the rent of ann is overdue, according to the landlord.
    the notice was delivered to ann, according to ann.

scenario unattributed is:
    the rent of ann is overdue, according to the landlord.
    the notice was delivered to ann.

scenario ledger is:
    the rent of ann is overdue, according to the landlord.
    the notice was delivered to ann, as stated in the landlord.

query penalty is:
    which tenant owes the late penalty.
", [Extra, Rule]).

nested_rule("a tenant owes the late penalty
    if the rent of the tenant is overdue
    and the notice was delivered to the tenant
        according to the landlord.").

inline_rule("a tenant owes the late penalty
    if the rent of the tenant is overdue
    and the notice was delivered to the tenant according to the landlord.").

:- begin_tests(scoped_proof).

test(example_program) :-
    load('examples/RulesRus/scoped_notice.le', KB),
    answers(KB, proven, penalty, A1), A1 == ["ann owes the late penalty"],
    answers(KB, not_proven, penalty, A2), A2 == [],
    answers(KB, unattributed, penalty, A3), A3 == [].

test(nested_line_form) :-
    nested_rule(R), program(R, "", P), load_text(P, KB),
    answers(KB, proven, penalty, A1), A1 == ["ann owes the late penalty"],
    answers(KB, by_ann, penalty, A2), A2 == [],
    answers(KB, unattributed, penalty, A3), A3 == [].

test(inline_form) :-
    inline_rule(R), program(R, "", P), load_text(P, KB),
    answers(KB, proven, penalty, A1), A1 == ["ann owes the late penalty"],
    answers(KB, by_ann, penalty, A2), A2 == [].

% Without "according to", every fact counts — ann's own statement included.
test(unscoped_rule_uses_all_facts) :-
    program("a tenant owes the late penalty
    if the rent of the tenant is overdue
    and the notice was delivered to the tenant.", "", P),
    load_text(P, KB),
    answers(KB, by_ann, penalty, A), A == ["ann owes the late penalty"].

% A fact "as stated in" a document has that document as its source.
test(document_is_the_source) :-
    nested_rule(R), program(R, "", P), load_text(P, KB),
    answers(KB, ledger, penalty, A), A == ["ann owes the late penalty"].

% A scope on a sibling line inside a negation block scopes the condition
% before it: here the penalty is owed unless the TENANT's own evidence shows
% the notice was delivered (a contrived rule, to exercise the layout).
test(scope_in_a_negation_block) :-
    program("a tenant owes the late penalty
    if the rent of the tenant is overdue
    and it is not the case that
        the notice was delivered to the tenant
        according to the tenant.", "", P),
    load_text(P, KB),
    % ann herself says the notice was delivered: the negation fails.
    answers(KB, by_ann, penalty, A1), A1 == [],
    % only the courier says so: ann's evidence does not establish it.
    answers(KB, proven, penalty, A2), A2 == ["ann owes the late penalty"].

% Declaring the built-in admissibility template again is harmless.
test(user_declared_admissibility_template) :-
    nested_rule(R),
    program(R, "    *a source* is admissible under *a scope*.\n", P),
    load_text(P, KB),
    answers(KB, proven, penalty, A), A == ["ann owes the late penalty"].

% "according to a party": whose evidence establishes it.
test(variable_scope) :-
    load_text("the target language is: prolog.

the templates are:
    *a party* proves that *a tenant* was notified.
    the notice was delivered to *a tenant*; undefined.

the knowledge base k includes:
a party proves that a tenant was notified
    if the notice was delivered to the tenant
        according to the party.

scenario s is:
    the notice was delivered to ann, according to the courier.

query q is:
    which party proves that which tenant was notified.
", KB),
    answers(KB, s, q, A),
    A == ["the courier proves that ann was notified"].

test(explanation_names_inadmissible_evidence) :-
    nested_rule(R), program(R, "", P), load_text(P, KB),
    createSession(KB, SM), setScenarion(SM, by_ann),
    once(query_explain(SM, penalty, _, _, Why)),
    clearSession(SM), setScenarion(SM, unattributed),
    once(query_explain(SM, penalty, _, _, Why2)),
    destroySession(SM),
    why_literals(Why, Lits),
    memberchk("the notice was delivered to ann, according to ann, is not admissible under the landlord", Lits),
    why_literals(Why2, Lits2),
    memberchk("the notice was delivered to ann has no source, so it is not admissible under the landlord", Lits2).

test(success_explanation_shows_the_scope) :-
    nested_rule(R), program(R, "", P), load_text(P, KB),
    createSession(KB, SM), setScenarion(SM, proven),
    once(query(SM, penalty, _, _, Why)),
    destroySession(SM),
    why_literals(Why, Lits),
    memberchk("the notice was delivered to ann according to the landlord", Lits).

:- end_tests(scoped_proof).
