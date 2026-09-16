/** <module> Unit tests for the s(CASP) dual-engine backend (le_scasp.pl)

    Covers the WP2 emitter, WP3 runner, WP4 justification normaliser, the WP7
    stratification check, and — the payoff — WP7 differential testing: the same
    program/scenario/query answered by the s(CASP) engine must agree with the
    Prolog engine's recorded expectation.

    These tests are skipped (reported as passing) when the s(CASP) pack is not
    installed, so CI without the pack still goes green.

    Run with:  swipl -q -g run_tests -t halt testing/test_scasp.pl
*/
:- module(test_scasp, []).

:- use_module('../le_kbs').
:- use_module('../le_scasp').
:- use_module('../le_verifier').
:- use_module(library(plunit)).

:- begin_tests(scasp).

% A small non-stratified program (happy/sad loop through negation).
nonstrat_text("the target language is: scasp.

the predicates are:
    *a person* is happy.
    *a person* is sad.
    *a person* is around.

the knowledge base loop includes:
    a person is happy if
        the person is around
        and it is not the case that the person is sad.
    a person is sad if
        the person is around
        and it is not the case that the person is happy.

scenario s is:
    alice is around.

query q is:
    which person is happy.").

% --- WP1: target language declaration ---
test(target_language_scasp) :-
    nonstrat_text(T),
    load_text(T, M),
    kb_target_language(M, Target),
    assertion(Target == scasp).

test(target_language_default_prolog) :-
    load('examples/moreExamples/citizenship.le', M),
    kb_target_language(M, Target),
    assertion(Target == prolog).

% --- WP2: emitter ---
test(emitter_pred_and_rules, [condition(le_scasp_available)]) :-
    load('examples/moreExamples/citizenship.le', M),
    le_scasp_program_text(M, Text, Issues),
    assertion(Issues == []),
    % #pred directive with the LE sentence, and a lowered rule head.
    assertion(sub_string(Text, _, _, _, "#pred acquires_British_citizenship_on")),
    assertion(sub_string(Text, _, _, _, "acquires British citizenship on")),
    assertion(sub_string(Text, _, _, _, "acquires_British_citizenship_on(A,B) :-")).

% --- WP3 + WP4: runner and normaliser ---
test(runner_citizenship_binding, [condition(le_scasp_available)]) :-
    load('examples/moreExamples/citizenship.le', M),
    le_scasp_query(M, alice, acquires_British_citizenship_on(_P, _D), [time_limit(30)], Answers, Issues),
    assertion(Issues == []),
    assertion(Answers = [_|_]),
    Answers = [answer(Bindings, _Goal, _Model, _Tree)|_],
    assertion(memberchk('V1'='John', Bindings)),
    assertion(memberchk('V2'=date(2021,10,9), Bindings)).

test(normaliser_tree_shape, [condition(le_scasp_available)]) :-
    load('examples/moreExamples/citizenship.le', M),
    le_scasp_query(M, alice, acquires_British_citizenship_on(_P, _D), [time_limit(30)], [A|_], _),
    A = answer(_, _, _, Tree),
    le_scasp_tree_json(M, Tree, [], JSON),
    % NB: assertion/1 does not propagate bindings — bind with get_dict first.
    get_dict(type, JSON, Type), assertion(Type == "success"),
    get_dict(literal, JSON, Lit), assertion(string(Lit)),
    get_dict(children, JSON, Ch), assertion(Ch = [_|_]),
    % the node carries a clickable source span
    assertion(get_dict(start, JSON, _)).

% --- WP7: stratification check ---
test(stratification_detects_negation_loop, [condition(le_scasp_available)]) :-
    nonstrat_text(T),
    load_text(T, M),
    le_scasp_stratification(M, Cycles),
    assertion(Cycles \== []),
    verify(M, Issues),
    assertion(memberchk(issue(non_stratified, _, _, _, _), Issues)).

test(stratification_clean_program) :-
    load('examples/moreExamples/citizenship.le', M),
    ( le_scasp_available -> le_scasp_stratification(M, Cycles), assertion(Cycles == []) ; true ),
    verify(M, Issues),
    assertion(\+ memberchk(issue(non_stratified, _, _, _, _), Issues)).

% --- WP7: differential testing (s(CASP) agrees with the recorded expectation) ---
test(differential_citizenship, [condition(le_scasp_available), forall(member(Scenario, [alice, harry, trust_harry, alice_harry]))]) :-
    load('examples/moreExamples/citizenship.le', M),
    % The Prolog engine's recorded expectation for query `one` in this scenario.
    M:le_expected(one, Scenario, Expected, _),
    expected_strings(Expected, ExpectedStrs),
    % Run the same query under s(CASP) and collect its answer strings.
    M:query_info(one, Goal, _),
    le_scasp_query(M, Scenario, Goal, [time_limit(30)], Answers, _Issues),
    scasp_answer_strings(M, Answers, ScaspStrs),
    forall(member(E, ExpectedStrs),
           assertion(memberchk(E, ScaspStrs))).

% --- §5b: constraint / symbolic answers ---
test(symbolic_constraint_answer, [condition(le_scasp_available)]) :-
    load('examples/moreExamples/language/scasp/clp_coverage.le', M),
    M:query_info(covered, Goal, _),
    le_scasp_query(M, none, Goal, [time_limit(30)], [answer(_, GoalInstance, _, _)|_], _),
    % The answer variable is non-ground (a CLP constraint), not a value.
    assertion(\+ ground(GoalInstance)),
    le_scasp_symbolic_goal(M, GoalInstance, Display, Constraints),
    le_kbs:item_to_instance(M, Display, Toks),
    le_kbs:canonical_string(Toks, S),
    assertion(sub_string(S, _, _, _, "any amount greater than 25000")),
    assertion(memberchk('greater than 25000', Constraints)).

% --- §5c: abduction set ---
test(abduction_assumption_set, [condition(le_scasp_available)]) :-
    load('examples/moreExamples/language/abduction/sunglasses.le', M),
    M:query_info(plan, Goal, _),
    le_scasp_query(M, planning, Goal, [time_limit(30)], [answer(_, _, _, Tree)|_], _),
    le_scasp_assumptions(M, Tree, Assumptions),
    assertion(memberchk("you wears sunglasses", Assumptions)).

% --- verifier: suppress rule_without_variables for wholly-propositional KBs ---
test(propositional_program_no_rule_without_variables) :-
    load('examples/moreExamples/language/abduction/grass_is_wet.le', M),
    verify(M, Issues),
    assertion(\+ memberchk(issue(rule_without_variables, _, _, _, _), Issues)).

test(mixed_program_still_warns_ground_rule) :-
    load_text("the target language is: prolog.
the predicates are:
    *a person* is happy.
    *a person* is rich.
    the sky is blue.
    it is daytime.
the knowledge base mix includes:
    a person is happy if the person is rich.
    the sky is blue if it is daytime.
scenario s is:
    alice is rich.
    it is daytime.
query happy is:
    which person is happy.", M),
    verify(M, Issues),
    assertion(memberchk(issue(rule_without_variables, _, _, _, _), Issues)).

expected_strings([], []).
expected_strings([string(S, _)|T], [S|R]) :- !, expected_strings(T, R).
expected_strings([S|T], [S|R]) :- expected_strings(T, R).

scasp_answer_strings(_, [], []).
scasp_answer_strings(M, [answer(_, Goal, _, _)|T], [S|R]) :-
    ( catch((le_kbs:item_to_instance(M, Goal, Toks), le_kbs:canonical_string(Toks, S0)), _, fail)
    -> S = S0
    ; term_string(Goal, S) ),
    scasp_answer_strings(M, T, R).

% --- OR handling: s(CASP) forbids ;/2 in a body ---

or_program(T) :-
    T = "the target language is: scasp.
the predicates are:
    *a person* is happy.
    *a person* is rich.
    *a person* is famous.
    *a person* is content.
the knowledge base ortest includes:
    a person is happy if
        the person is rich
        or the person is famous.
    a person is content if
        it is not the case that
            the person is rich
            or the person is famous.
scenario s is:
    alice is rich.
query happy is:
    which person is happy.".

% A positive `or` is DNF-expanded into one clause per disjunct; no ;/2 survives
% and no issue is raised.
test(or_positive_dnf_expands, [condition(le_scasp_available)]) :-
    or_program(T), load_text(T, M),
    le_scasp_program_text(M, Text, Issues),
    assertion(Issues == []),
    assertion(\+ sub_string(Text, _, _, _, ";")),
    % is_happy got two clauses, one per disjunct.
    findall(x, sub_string(Text, _, _, _, "is_happy("), Occurrences),
    length(Occurrences, N),
    assertion(N >= 3).   % #pred + two rule heads

% An `or` under a negation is De Morgan'd to `not .. , not ..` (sound for default
% negation), so it stays legal s(CASP) and runs without a raw permission_error.
test(or_under_negation_demorgan, [condition(le_scasp_available)]) :-
    or_program(T), load_text(T, M),
    le_scasp_program_text(M, Text, _Issues),
    assertion(\+ sub_string(Text, _, _, _, ";")),
    catch(le_scasp_query(M, s, is_content(_P), [time_limit(30)], _Answers, QIssues),
          Err, true),
    assertion(var(Err)),                           % no raw permission_error escapes
    assertion(\+ memberchk(le_scasp_issue(unsupported_construct, _, _), QIssues)).

dneg_program("the target language is: scasp.
the predicates are:
    *a person* is safe.
    *a person* is risky.
    *a person* is insured.
the knowledge base dneg includes:
    a person is safe if
        it is not the case that
            the person is risky
            and it is not the case that the person is insured.
scenario s is:
    alice is risky.
query safe is:
    which person is safe.").

% Double negation cannot be expressed in this s(CASP): a targeted, non-crashing
% issue is reported instead of emitting an illegal program.
test(double_negation_reports_issue, [condition(le_scasp_available)]) :-
    dneg_program(T), load_text(T, M),
    le_scasp_program_text(M, _Text, Issues),
    ( memberchk(le_scasp_issue(untranslatable_rule, _, Msg), Issues) -> true ; Msg = "" ),
    % Msg comes from i18n (an atom); the English text names the double negation.
    assertion(sub_atom_icasechk(Msg, _, "double negation")).

% le_scasp_issue messages are localized through i18n/messages.csv: under the
% Portuguese active language the same issue reads in Portuguese ("negação").
test(issue_message_localized, [condition(le_scasp_available)]) :-
    dneg_program(T), load_text(T, M),
    le_i18n:with_le_language(pt, le_scasp:le_scasp_program_text(M, _Text, Issues)),
    ( memberchk(le_scasp_issue(untranslatable_rule, _, Msg), Issues) -> true ; Msg = "" ),
    assertion(sub_atom_icasechk(Msg, _, "negação")).

% --- Queries of several conditions, LE's records, readable constraints ---
% (Sentry, scaspQuery: `existence_error: scasp_predicate '<unit>:and'/2`)

query_program("the target language is: scasp.

the templates are:
    *a person* is happy; opposite: *a person* is unhappy.
    *a person* is rich.
    *a person* is around.
    *a person* is sad.

the knowledge base k includes:
    the text of the source program is at \"sources/k.txt\".

    a person is happy if
        the person is around
        and it is not the case that the person is sad.

scenario s is:
    alice is around.
    alice is rich.
    bob is around.
    bob is sad.
    bob is rich.

query both is:
    which person is happy
    and the person is rich.

query either is:
    which person is happy
    or the person is sad.

query listed is:
    which person is rich
    and the person is in [alice, bob].
").

%   Every literal of a lowered query clause is a predicate of the program or
%   s(CASP)'s own — never one of LE's connectives.
query_lines_ok(Lines) :-
    forall(member(L, Lines),
           ( assertion(\+ sub_string(L, _, _, _, "and(")),
             assertion(\+ sub_string(L, _, _, _, "or(")),
             assertion(\+ sub_string(L, _, _, _, "le_at(")) )).

%   A conjunctive query was handed to s(CASP) as the LE goal and/2 itself.
test(query_conjunction_is_lowered) :-
    query_program(T), load_text(T, M),
    M:query_info(both, G, _),
    le_scasp:strip_positions(G, G1),
    le_scasp:le_scasp_query_goal(M, G1, Query, Shown, Lines, Issues),
    assertion(Issues == []),
    assertion(functor(Query, le_query, 1)),
    assertion(Shown == G1),
    assertion(Lines = [_]),
    query_lines_ok(Lines),
    Lines = [L],
    assertion(sub_string(L, _, _, _, "not is_happy") ; sub_string(L, _, _, _, "is_rich(")).

test(query_disjunction_is_lowered) :-
    query_program(T), load_text(T, M),
    M:query_info(either, G, _),
    le_scasp:strip_positions(G, G1),
    le_scasp:le_scasp_query_goal(M, G1, _, _, Lines, Issues),
    assertion(Issues == []),
    assertion(length(Lines, 2)),          % one clause per disjunct
    query_lines_ok(Lines).

%   What has no s(CASP) statement in a query is an issue that refuses it.
test(query_list_membership_is_refused) :-
    query_program(T), load_text(T, M),
    M:query_info(listed, G, _),
    le_scasp:strip_positions(G, G1),
    le_scasp:le_scasp_query_goal(M, G1, _, _, _, Issues),
    assertion(( member(I, Issues), le_scasp_blocking_issue(I) )),
    le_scasp_check(M, Issues, Problems),
    assertion(Problems \== []).

%   A construct left as it was by the lowering is caught, not emitted.
test(leftover_connective_is_caught) :-
    assertion(le_scasp:leftover_in_clauses([(h(X) :- (p(X), and(p(X), q(X))))], and/2)),
    assertion(le_scasp:leftover_in_clauses([(h(X) :- not(le_flip(X, _)))], le_flip/2)),
    assertion(le_scasp:leftover_in_clauses([(h(X) :- '#='(le_is(X, 'the sum of'), 1))], le_is/2)),
    assertion(\+ le_scasp:leftover_in_clauses([(h(X) :- (p(X), not(q(X)), '#>'(X+1, 3), -(r(X)), le_forall_1(X)))], _)).

%   LE's document records are not the program's clauses, and the opposite
%   constraint names its variables.
test(program_text_without_records_readable_constraints) :-
    query_program(T), load_text(T, M),
    once(le_scasp_program_text(M, Text, _)),
    assertion(\+ sub_string(Text, _, _, _, "le_text_at")),
    assertion(\+ sub_string(Text, _, _, _, "sources/")),
    assertion(sub_string(Text, _, _, _, "false :- is_happy(A), -is_happy(A).")),
    assertion(\+ sub_string(Text, _, _, _, "(_")).

test(query_conjunction_answers, [condition(le_scasp_available)]) :-
    query_program(T), load_text(T, M),
    M:query_info(both, G, _),
    catch(le_scasp_query(M, s, G, [time_limit(30)], Answers, Issues), E, true),
    assertion(var(E)),
    assertion(\+ ( member(I, Issues), le_scasp_blocking_issue(I) )),
    findall(P, member(answer(_, and(is_happy(P), is_rich(P)), _, _), Answers), Ps0),
    sort(Ps0, Ps),
    assertion(Ps == [alice]).

%   A query whose predicate has no clause in the unit fails, as in Prolog,
%   rather than s(CASP) throwing that it does not exist.
test(query_of_an_undefined_predicate_fails, [condition(le_scasp_available)]) :-
    query_program(T), load_text(T, M),
    catch(le_scasp_query(M, none, is_sad(_), [time_limit(30)], Answers, _), E, true),
    assertion(var(E)),
    assertion(Answers == []).

:- end_tests(scasp).
