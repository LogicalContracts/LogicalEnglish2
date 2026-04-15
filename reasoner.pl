/** <module> Logical English Reasoner
    
    This module implements a meta-interpreter for Logical English (LE).
    It handles conjunctions, disjunctions, negation as failure, and 
    conditional answers (Unknowns).
    It constructs success explanation trees.
*/

:- module(reasoner, [i/4]).

:- use_module(library(time)).
:- use_module(library(pairs)).

:- dynamic equal_to/2.

%!  i(+Goal:term, +SessionModule:atom, -Unknowns:list, -Why:term) is semidet.
%
%   Main entry point for the meta-interpreter.
%   Goal is the term to prove.
%   SessionModule is the module containing session-specific facts.
%   Unknowns is a list of goals that were assumed true (if defined as unknown).
%   Why is an explanation tree of the proof.
i(Goal, SessionModule, Unknowns, Why) :-
    (   SessionModule:le_my_kb(KBmodule) ->  true;   KBmodule = none
    ),
    solve(Goal, SessionModule, KBmodule, [], 0, Unknowns, Why).

%!  solve(+Goal:term, +SM:atom, +KM:atom, +Anc:list, +Depth:integer, -Us:list, -Why:term) is semidet.
%
%   Succeeds if Goal can be proven (possibly with Unknowns).
%   SM is the Session Module.
%   KM is the Knowledge Base Module.
%   Anc is the ancestor list for loop detection.
%   Depth is the current recursion depth.
%   Us is the list of Unknowns encountered.
%   Why is the explanation tree.
solve(G, SM, KM, Anc, D, Us, Why) :-
    (   le_kbs:do_log -> writeln(solve(G)) ; true),
    solve_real(G, SM, KM, Anc, D, Us, Why).

% Conjunction
solve_real((A, B), SM, KM, Anc, D, Us, success((A, B), conjunction, [WhyA, WhyB])) :- !,
    solve(A, SM, KM, Anc, D, UsA, WhyA),
    solve(B, SM, KM, Anc, D, UsB, WhyB),
    append(UsA, UsB, Us).
solve_real(and(A, B), SM, KM, Anc, D, Us, success(and(A, B), conjunction, [WhyA, WhyB])) :- !,
    solve(A, SM, KM, Anc, D, UsA, WhyA),
    solve(B, SM, KM, Anc, D, UsB, WhyB),
    append(UsA, UsB, Us).
% Disjunction
solve_real((A ; B), SM, KM, Anc, D, Us, success((A ; B), disjunction, [Why])) :- !,
    (   solve(A, SM, KM, Anc, D, Us, Why)
    ;   solve(B, SM, KM, Anc, D, Us, Why)
    ).
solve_real(or(A, B), SM, KM, Anc, D, Us, success(or(A, B), disjunction, [Why])) :- !,
    (   solve(A, SM, KM, Anc, D, Us, Why)
    ;   solve(B, SM, KM, Anc, D, Us, Why)
    ).
% Aggregates
solve_real(sum([each, Var], Goal, [Result]), SM, KM, Anc, D, Us, success(sum([each, Var], Goal, [Result]), aggregate, [WhyGoal])) :- !,
    D1 is D + 1,
    findall(Var-Why, solve(Goal, SM, KM, Anc, D1, [], Why), Pairs),
    pairs_keys_values(Pairs, List, Whys),
    sum_list(List, Result),
    Us = [],
    WhyGoal = success(Goal, aggregate_elements, Whys).
solve_real(count([each, Var], Goal, [Result]), SM, KM, Anc, D, Us, success(count([each, Var], Goal, [Result]), aggregate, [WhyGoal])) :- !,
    D1 is D + 1,
    findall(Var-Why, solve(Goal, SM, KM, Anc, D1, [], Why), Pairs),
    pairs_keys_values(Pairs, List, Whys),
    length(List, Result),
    Us = [],
    WhyGoal = success(Goal, aggregate_elements, Whys).
solve_real(min([each, Var], Goal, [Result]), SM, KM, Anc, D, Us, success(min([each, Var], Goal, [Result]), aggregate, [WhyGoal])) :- !,
    D1 is D + 1,
    findall(Var-Why, solve(Goal, SM, KM, Anc, D1, [], Why), Pairs),
    pairs_keys_values(Pairs, List, Whys),
    min_list(List, Result),
    Us = [],
    WhyGoal = success(Goal, aggregate_elements, Whys).
solve_real(max([each, Var], Goal, [Result]), SM, KM, Anc, D, Us, success(max([each, Var], Goal, [Result]), aggregate, [WhyGoal])) :- !,
    D1 is D + 1,
    findall(Var-Why, solve(Goal, SM, KM, Anc, D1, [], Why), Pairs),
    pairs_keys_values(Pairs, List, Whys),
    max_list(List, Result),
    Us = [],
    WhyGoal = success(Goal, aggregate_elements, Whys).
solve_real(average([each, Var], Goal, [Result]), SM, KM, Anc, D, Us, success(average([each, Var], Goal, [Result]), aggregate, [WhyGoal])) :- !,
    D1 is D + 1,
    findall(Var-Why, solve(Goal, SM, KM, Anc, D1, [], Why), Pairs),
    pairs_keys_values(Pairs, List, Whys),
    sum_list(List, Sum),
    length(List, Count),
    (Count > 0 -> Result is Sum / Count ; Result = 0),
    Us = [],
    WhyGoal = success(Goal, aggregate_elements, Whys).
% Forall
solve_real(forall(Cond, Cons), SM, KM, Anc, D, Us, success(forall(Cond, Cons), universal, [Why])) :- !,
    D1 is D + 1,
    findall(UsC-WhyC, solve(Cond, SM, KM, Anc, D1, UsC, WhyC), CondResults),
    (   CondResults == [] -> Us = [], Why = success(Cond, empty_forall, [])
    ;   % For each solution of Cond, Cons must succeed
        forall(member(UsC-WhyC, CondResults),
               (UsC == [] -> solve(Cons, SM, KM, Anc, D1, [], _) ; true)),
        Us = [], % TODO: handle unknowns in forall
        Why = success(forall(Cond, Cons), universal_success, [])
    ).

% Negation as Failure
solve_real(not(Goal), SM, KM, Anc, D, Us, success(not(Goal), negation, [])) :- !,
    D1 is D + 1,
    findall(UsA, solve(Goal, SM, KM, Anc, D1, UsA, _), AllUsA),
    (   member([], AllUsA)
    ->  fail % Certain success of Goal, so not(Goal) fails
    ;   AllUsA \== []
    ->  Us = [not(Goal)] % Only unknown successes
    ;   Us = [] % Certain failure of Goal, so not(Goal) succeeds
    ).

% True
solve_real(true, _, _, _, _, [], success(true, built_in, [])) :- !.

% Literals
solve_real(G, SM, KM, Anc, D, Us, Why) :-
    G \= (_ , _), G \= (_ ; _), G \= and(_, _), G \= or(_, _), G \= not(_), G \= true, G \= fail,
    G \= sum(_, _, _), G \= count(_, _, _), G \= min(_, _, _), G \= max(_, _, _), G \= average(_, _, _),
    (   D > 100 -> fail ; true % Depth limit
    ),

    (   KM \== none, current_predicate(KM:le_unknown/1), KM:le_unknown(G)
    ->  Us = [G], Why = success(G, unknown, [])
    ;   is_built_in(G)
    ->  call_reasoner_built_in(G), Us = [], Why = success(G, built_in, [])
    ;   G = is_a(X, Z)
    ->  D1 is D + 1,
        (   get_clause(is_a(X, Z), SM, KM, Body, Ref),
            \+ SM:le_neg(is_a(X, Z)),
            \+ member(is_a(X, Z), Anc),
            solve(Body, SM, KM, [is_a(X, Z)|Anc], D1, Us, WhyBody),
            Why = success(is_a(X, Z), Ref, [WhyBody])
        ;   % Transitivity: X is a Y and Y is a Z
            % Use a base fact for the first step to avoid infinite recursion
            (SM:clause(is_a(X, Y), true, Ref1) ; (KM \== none, KM:clause(is_a(X, Y), true, Ref1))),
            Y \== Z,
            \+ SM:le_neg(is_a(X, Y)),
            \+ member(is_a(X, Y), Anc),
            solve(is_a(Y, Z), SM, KM, [is_a(X, Z)|Anc], D1, Us, WhyBody2),
            Why = success(is_a(X, Z), transitivity, [success(is_a(X, Y), Ref1, []), WhyBody2])
        )
    ;   get_clause(G, SM, KM, Body, Ref),
        \+ SM:le_neg(G),
        \+ member(G, Anc),
        D1 is D + 1,
        solve(Body, SM, KM, [G|Anc], D1, Us, WhyBody),
        Why = success(G, Ref, [WhyBody])
    ).

% get_clause(+Goal, +SM, +KM, -Body, -Ref)
get_clause(G, SM, _KM, Body, Ref) :-
    SM:clause(G, Body, Ref).
get_clause(G, _SM, KM, Body, Ref) :-
    KM \== none,
    KM:clause(G, Body, Ref).

% Helpers

is_built_in(G) :- predicate_property(G, built_in).
is_built_in(le_known(_)).
is_built_in(le_equal_to(_, _)).
is_built_in(le_assign(_, _)).
is_built_in(le_is(_, _)).
is_built_in(le_ge(_, _)).
is_built_in(le_le(_, _)).
is_built_in(le_gt(_, _)).
is_built_in(le_lt(_, _)).
is_built_in(le_is_in(_, _)).
is_built_in(equal_to(_, _)).

call_reasoner_built_in(le_known(X)) :- !, ground(X).
call_reasoner_built_in(le_equal_to(X, Y)) :- !, X = Y.
call_reasoner_built_in(le_assign(X, Y)) :- !, (number(Y) -> X is Y ; catch(X is Y, _, X = Y)).
call_reasoner_built_in(le_is(X, Y)) :- !, (number(Y) -> X is Y ; catch(X is Y, _, X = Y)).
call_reasoner_built_in(le_is_in(X, Y)) :- !, is_list(Y), member(X, Y).
call_reasoner_built_in(le_ge(X, Y)) :- !, le_compare(>=, X, Y).
call_reasoner_built_in(le_le(X, Y)) :- !, le_compare(=<, X, Y).
call_reasoner_built_in(le_gt(X, Y)) :- !, le_compare(>, X, Y).
call_reasoner_built_in(le_lt(X, Y)) :- !, le_compare(<, X, Y).
call_reasoner_built_in(equal_to(X, Y)) :- !, X = Y.
call_reasoner_built_in(G) :- call(G).

le_compare(Op, X, Y) :-
    number(X), number(Y), !,
    Goal =.. [Op, X, Y],
    call(Goal).
le_compare(>=, X, Y) :- !, X @>= Y.
le_compare(=<, X, Y) :- !, X @=< Y.
le_compare(>, X, Y) :- !, X @> Y.
le_compare(<, X, Y) :- !, X @< Y.

equal_to(X, X).
