/** <module> Logical English Verifier
    
    This module performs load-time verifications on a Logical English knowledge base.
    It checks for missing templates, undefined predicates, untested predicates,
    rules without variables, and other potential issues.
*/

:- module(le_verifier, [verify/2, print_issue/1, is_intensional/3, find_in_body/2]).

:- use_module(le_kbs, [is_system_predicate/1, run_one_test/3, canonical_string/2]).
:- use_module(le_system_templates, [le_system_template/1]).

%!  verify(+KBModule:atom, -Issues:list) is det.
%
%   Performs load-time verifications on a Logical English knowledge base.
verify(KB, Issues) :-
    ( setof(Issue, check_issue(KB, Issue), Issues) -> true; Issues = []).

check_issue(KB, Issue) :- missing_template(KB, Issue).
check_issue(KB, Issue) :- undefined_predicate(KB, Issue).
check_issue(KB, Issue) :- untested_predicate(KB, Issue).
check_issue(KB, Issue) :- rule_without_variables(KB, Issue).
check_issue(KB, Issue) :- facts_rules_ratio(KB, Issue).
check_issue(KB, Issue) :- failed_test(KB, Issue).
check_issue(KB, Issue) :- redefined_system_template(KB, Issue).

% --- 1. Missing template ---
missing_template(KB, issue(missing_template, Description, Fix, Start, End)) :-
    (   current_predicate(KB:unknown_template/1), clause(KB:unknown_template(Tokens), _, Ref)
    ;   current_predicate(KB:F/A), functor(Head, F, A), clause(KB:Head, Body, Ref), find_in_body(Body, unknown_template(Tokens))
    ),
    le_grammar:reconstruct_name(Tokens, Name),
    format(atom(Description), "Missing template for '~w'", [Name]),
    tokens_to_template_hypothesis(Tokens, Hypothesis),
    format(atom(Fix), "~w.", [Hypothesis]),
    ( clause(KB:le_source_info(Ref, Start, End, _), true) -> true; Start = 0, End = 0).

tokens_to_template_hypothesis(Tokens, Hypothesis) :-
    group_hypothesis_parts(Tokens, Grouped),
    maplist(hyp_part_to_string, Grouped, Strings),
    atomic_list_concat(Strings, ' ', Hypothesis).

group_hypothesis_parts([], []).
group_hypothesis_parts([var(Words, _)|Rest], [var(Words)|Grouped]) :- !,
    group_hypothesis_parts(Rest, Grouped).
% Article + ID -> *article ID*
group_hypothesis_parts([word(Art, _), word(ID, _)|Rest], [var([LowArt, ID])|Grouped]) :-
    le_grammar:is_article(Art),
    le_grammar:is_id(ID), !,
    downcase_atom(Art, LowArt),
    group_hypothesis_parts(Rest, Grouped).
% Just an ID -> *ID*
group_hypothesis_parts([word(ID, _)|Rest], [var([ID])|Grouped]) :-
    le_grammar:is_id(ID), !,
    group_hypothesis_parts(Rest, Grouped).
% Article + Word -> *article Word* 
% Only if Word is followed by a stop word or end of tokens
group_hypothesis_parts([word(Art, _), word(W, _)|Rest], [var([LowArt, W])|Grouped]) :-
    le_grammar:is_article(Art),
    \+ is_stop_word(W),
    (   Rest = [] 
    ;   Rest = [T|_], le_grammar:extract_simple_word(T, NextW), is_stop_word(NextW)
    ), !,
    downcase_atom(Art, LowArt),
    group_hypothesis_parts(Rest, Grouped).
% Proper name -> *a Name*
group_hypothesis_parts([word(W, _)|Rest], [var([a, W])|Grouped]) :-
    le_grammar:is_proper_name_atom(W),
    \+ le_grammar:is_article(W), !,
    group_hypothesis_parts(Rest, Grouped).
% Regular word
group_hypothesis_parts([T|Rest], [word(W)|Grouped]) :-
    le_grammar:extract_simple_word(T, W),
    group_hypothesis_parts(Rest, Grouped).

is_stop_word(W) :- le_grammar:is_reserved(W).
is_stop_word(W) :- le_grammar:is_ignorable(W).
is_stop_word(W) :- le_grammar:is_punct(W).

hyp_part_to_string(var(Words), String) :-
    atomic_list_concat(Words, ' ', Name),
    format(atom(String), '*~w*', [Name]).
hyp_part_to_string(word(W), W).

% --- 2. Undefined predicate ---
undefined_predicate(KB, issue(undefined_predicate, Description, Fix, Start, End)) :-
    current_predicate(KB:F/A), functor(Head, F, A),
    \+ is_system_predicate(F/A),
    \+ predicate_property(KB:Head, imported_from(_)),
    clause(KB:Head, Body, Ref),
    find_in_body(Body, Literal),
    Literal \= unknown_template(_),
    \+ is_defined(KB, Literal),
    \+ is_built_in_literal(Literal),
    functor(Literal, FL, AL),
    format(atom(Description), "Undefined predicate '~w/~w'", [FL, AL]),
    Fix = "add a rule defining the predicate, or add fact sentences for it in the relevant scenarios.",
    ( clause(KB:le_source_info(Ref, Start, End, _), true) -> true; Start = 0, End = 0).

% find_in_body(+Body, -Literal)
% Recursively finds literals in a rule body.
% WARNING: This logic is dependent on the structure of solve_real/8 in reasoner.pl
find_in_body(prolog_call(_), _) :- !, fail.
find_in_body(le_at(G, _, _), L) :- !, find_in_body(G, L).
find_in_body((A, B), L) :- !, (find_in_body(A, L) ; find_in_body(B, L)).
find_in_body(and(A, B), L) :- !, (find_in_body(A, L) ; find_in_body(B, L)).
find_in_body((A ; B), L) :- !, (find_in_body(A, L) ; find_in_body(B, L)).
find_in_body(or(A, B), L) :- !, (find_in_body(A, L) ; find_in_body(B, L)).
find_in_body(not(B), L) :- !, find_in_body(B, L).
find_in_body(forall(A, B), L) :- !, (find_in_body(A, L) ; find_in_body(B, L)).
find_in_body(sum(_, G, _), L) :- !, find_in_body(G, L).
find_in_body(count(_, G, _), L) :- !, find_in_body(G, L).
find_in_body(min(_, G, _), L) :- !, find_in_body(G, L).
find_in_body(max(_, G, _), L) :- !, find_in_body(G, L).
find_in_body(average(_, G, _), L) :- !, find_in_body(G, L).
find_in_body(true, _) :- !, fail.
find_in_body(fail, _) :- !, fail.
find_in_body(unknown_tokens(_), _) :- !, fail.
find_in_body(L, L).

is_defined(KB, Literal) :-
    catch(is_defined_real(KB, Literal), _, fail).

is_defined_real(KB, Literal) :-
    functor(Literal, F, A),
    (   Literal = is_a(_, _) -> true
    ;   memberchk(F/A, [and/2, or/2, not/1, forall/2, true/0, fail/0, sum/3, count/3, min/3, max/3, average/3]) -> true
    ;   memberchk(F/A, [le_is/2, le_equal_to/2, le_assign/2, le_ge/2, le_le/2, le_gt/2, le_lt/2, le_known/1, le_is_in/2]) -> true
    ;   (F == says_that, A == 2) -> true
    ;   safe_clause(KB, Literal) -> true
    ;   safe_scenario_fact(KB, F, A) -> true
    ;   clause(KB:le_unknown(Literal), _) -> true
    ;   fail
    ).

safe_clause(KB, Literal) :-
    functor(Literal, F, A),
    current_predicate(KB:F/A),
    clause(KB:Literal, _).

safe_scenario_fact(KB, F, A) :-
    current_predicate(KB:scenario/2),
    clause(KB:scenario(_, Facts), _),
    member(FactItem, Facts),
    ( FactItem = fact_with_source(Fact, _, _) -> true ; Fact = FactItem ),
    functor(Fact, F, A).

is_built_in_literal(L) :- reasoner:is_built_in(L).
is_built_in_literal(says_that(_, _)).

% --- 3. Untested predicate ---
untested_predicate(KB, issue(untested_predicate, Description, Fix, 0, 0)) :-
    current_predicate(KB:F/A),
    functor(G, F, A),
    \+ is_system_predicate(F/A),
    \+ reasoner:is_built_in(G),
    \+ predicate_property(KB:G, imported_from(_)),
    is_intensional(KB, F, A),
    \+ is_reachable_from_query(KB, F, A),
    format(atom(Description), "This predicate is not tested by any query: '~w/~w'", [F, A]),
    Fix = "add a query that exercises the predicate, and add expected answers to the .le.tests file or using 'expects answers' in a scenario.".

is_intensional(KB, F, A) :-
    functor(G, F, A),
    KB:clause(G, Body),
    Body \== true, !.

is_reachable_from_query(KB, F, A) :-
    current_predicate(KB:query_info/3),
    KB:query_info(_, Goal, _),
    is_reachable(KB, Goal, F, A, []).

is_reachable(_KB, Goal, F, A, _) :-
    find_in_body(Goal, Literal),
    functor(Literal, F, A).
is_reachable(KB, Goal, F, A, Anc) :-
    find_in_body(Goal, Literal),
    functor(Literal, F1, A1),
    \+ member(F1/A1, Anc),
    functor(G1, F1, A1),
    current_predicate(KB:F1/A1),
    KB:clause(G1, Body),
    is_reachable(KB, Body, F, A, [F1/A1|Anc]).

% --- 4. Rule without variables ---
rule_without_variables(KB, issue(rule_without_variables, Description, Fix, Start, End)) :-
    current_predicate(KB:F/A), functor(Head, F, A),
    \+ predicate_property(KB:Head, imported_from(_)),
    clause(KB:Head, Body, Ref),
    Body \== true,
    ground(Head),
    ground(Body),
    format(atom(Description), "Rule without variables: ~w if ~w", [Head, Body]),
    Fix = "move the concrete data into a scenario; rules should use variables.",
    ( clause(KB:le_source_info(Ref, Start, End, _), true) -> true; Start = 0, End = 0).

% --- 5. Facts/Rules ratio ---
facts_rules_ratio(KB, issue(missing_rules, Description, Fix, 0, 0)) :-
    count_rules(KB, Rules),
    Rules == 0,
    count_facts(KB, Facts),
    Facts > 0,
    Description = "Missing rules: the program contains only facts and no rules.",
    Fix = "add rules that derive conclusions from the facts.".
facts_rules_ratio(KB, issue(too_many_facts, Description, Fix, 0, 0)) :-
    count_rules(KB, Rules),
    Rules > 0,
    count_facts(KB, Facts),
    Facts > Rules * 5,
    format(atom(Description), "Too many facts: facts (~w) outnumber rules (~w) by more than 5:1.", [Facts, Rules]),
    Fix = "add rules that derive conclusions from the facts.".

% --- 6. Failed tests ---
failed_test(KB, issue(failed_test, Description, Fix, Start, End)) :-
    current_predicate(KB:le_expected/4),
    clause(KB:le_expected(QueryName, ScenarioName, ExpectedStrings, ExpectedUnknowns), true, Ref),
    run_one_test(KB, test(QueryName, ScenarioName, ExpectedStrings, ExpectedUnknowns), Result),
    Result \= pass(_, _),
    (   Result = fail(_, _, Expected, Actual) ->
        format(atom(Description), "Test failed for query '~w' in scenario '~w'.~nExpected: ~w~nActual: ~w", [QueryName, ScenarioName, Expected, Actual])
    ;   Result = fail(_, _, Expected, Actual, ExpectedU, ActualU) ->
        format(atom(Description), "Test failed for query '~w' in scenario '~w'.~nExpected: ~w~nActual: ~w~nExpected Unknowns: ~w~nActual Unknowns: ~w", [QueryName, ScenarioName, Expected, Actual, ExpectedU, ActualU])
    ;   Result = error(_, _, Error) ->
        format(atom(Description), "Test error for query '~w' in scenario '~w': ~w", [QueryName, ScenarioName, Error])
    ;   format(atom(Description), "Test failed for query '~w' in scenario '~w'", [QueryName, ScenarioName])
    ),
    Fix = "check the logic of your rules or the facts in the scenario.",
    ( clause(KB:le_source_info(Ref, Start, End, _), true) -> true; Start = 0, End = 0).

% --- 7. Redefined system template ---
redefined_system_template(KB, issue(redefined_system_template, Description, Fix, Start, End)) :-
    current_predicate(KB:le_dict/1),
    clause(KB:le_dict(Dict), true, Ref),
    (Dict = dict(FA, NTs, WV, _, _, _, _) ; Dict = dict(FA, NTs, WV, _, _, _) ; Dict = dict(FA, NTs, WV, _, _) ; Dict = dict(FA, NTs, WV, _) ; Dict = dict(FA, NTs, WV)),
    % It's a user template if it's not in system templates
    \+ le_system_template(dict(FA, NTs, WV)),
    % And it matches a system template's words
    le_system_template(dict(_SysFA, _SysNTs, SysWV)),
    templates_match(WV, SysWV),
    % And it has no rules or facts
    FA = [F|Args],
    length(Args, Arity),
    functor(G, F, Arity),
    \+ is_defined(KB, G),
    % Get source info
    ( clause(KB:le_source_info(Ref, Start, End, _), true) -> true; Start = 0, End = 0),
    canonical_string(WV, TemplateStr),
    format(atom(Description), "Template '~w' redefines a similar system template and there are no rules for it", [TemplateStr]),
    Fix = "Either change the template slightly or add some rules".

templates_match(WV1, WV2) :-
    length(WV1, L), length(WV2, L),
    maplist(match_token, WV1, WV2).

match_token(T1, T2) :-
    (is_var_placeholder(T1) ; var(T1)),
    (is_var_placeholder(T2) ; var(T2)), !.
match_token(T, T).

is_var_placeholder(var(_)).
is_var_placeholder(var(_, _)).

count_rules(KB, Count) :-
    findall(1, (
        current_predicate(KB:F/A),
        \+ is_system_predicate(F/A),
        functor(Head, F, A),
        KB:clause(Head, Body),
        Body \== true
    ), L),
    length(L, Count).

count_facts(KB, Count) :-
    findall(1, (
        current_predicate(KB:F/A),
        \+ is_system_predicate(F/A),
        functor(Head, F, A),
        KB:clause(Head, true)
    ), L1),
    length(L1, Count).

% --- Printing ---
print_issues(Issues) :-
    forall(member(Issue, Issues), print_issue(Issue)).

print_issue(issue(Type, Description, Fix, Start, End)) :-
    format(atom(Msg), "~w~n    Fix: ~w~n    Position: ~w-~w", [Description, Fix, Start, End]),
    print_message(warning, Type - [Msg]).

% Extend prolog:message to handle our issues
:- multifile prolog:message//1.
prolog:message(Type - [Msg, Start, End]) -->
    { memberchk(Type, [missing_template, undefined_predicate, untested_predicate, rule_without_variables, missing_rules, too_many_facts, failed_test, redefined_system_template, scenario_before_rules, missing_trailing_dot, prepositional_arity, prepositional_first_arg]) },
    [ '~w: ~w at ~w-~w' - [Type, Msg, Start, End] ].
prolog:message(Type - [Msg]) -->
    { memberchk(Type, [missing_template, undefined_predicate, untested_predicate, rule_without_variables, missing_rules, too_many_facts, failed_test, redefined_system_template, scenario_before_rules, missing_trailing_dot, prepositional_arity, prepositional_first_arg]) },
    [ '~w: ~w' - [Type, Msg] ].
