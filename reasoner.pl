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
:- thread_local called/3, counter/1.

%!  i(+Goal:term, +SessionModule:atom, -Unknowns:list, -Why:term) is semidet.
%
%   Main entry point for the meta-interpreter.
%   Goal is the term to prove.
%   SessionModule is the module containing session-specific facts.
%   Unknowns is a list of goals that were assumed true (if defined as unknown).
%   Why is an explanation tree of the proof.
i(Goal, SessionModule, Unknowns, Why) :-
    retractall(called(_, _, _)),
    init_counter,
    (   SessionModule:le_my_kb(KBmodule) ->  true;   KBmodule = none
    ),
    solve(Goal, SessionModule, KBmodule, [], 0, none, Unknowns, Whys),
    (Whys = [Why] -> true ; Why = Whys).

%!  solve(+Goal:term, +SM:atom, +KM:atom, +Anc:list, +Depth:integer, +ParentID:any, -Us:list, -Whys:list) is semidet.
%
%   Succeeds if Goal can be proven (possibly with Unknowns).
%   SM is the Session Module.
%   KM is the Knowledge Base Module.
%   Anc is the ancestor list for loop detection.
%   Depth is the current recursion depth.
%   ParentID is the ID of the calling goal.
%   Us is the list of Unknowns encountered.
%   Whys is a list of "juicy" explanation trees.
solve(G, SM, KM, Anc, D, ParentID, Us, Whys) :-
    next_id(MyID),
    (   ParentID \== none
    ->  assertz(called(ParentID, MyID, G))
    ;   true
    ),
    solve_real(G, SM, KM, Anc, D, MyID, Us, Whys).

% Conjunction
solve_real((A, B), SM, KM, Anc, D, MyID, Us, Whys) :- !,
    solve(A, SM, KM, Anc, D, MyID, UsA, WhysA),
    solve(B, SM, KM, Anc, D, MyID, UsB, WhysB),
    append(UsA, UsB, Us),
    append(WhysA, WhysB, Whys).
solve_real(and(A, B), SM, KM, Anc, D, MyID, Us, Whys) :- !,
    solve(A, SM, KM, Anc, D, MyID, UsA, WhysA),
    solve(B, SM, KM, Anc, D, MyID, UsB, WhysB),
    append(UsA, UsB, Us),
    append(WhysA, WhysB, Whys).
% Disjunction
solve_real((A ; B), SM, KM, Anc, D, MyID, Us, Whys) :- !,
    (   solve(A, SM, KM, Anc, D, MyID, Us, Whys)
    ;   solve(B, SM, KM, Anc, D, MyID, Us, Whys)
    ).
solve_real(or(A, B), SM, KM, Anc, D, MyID, Us, Whys) :- !,
    (   solve(A, SM, KM, Anc, D, MyID, Us, Whys)
    ;   solve(B, SM, KM, Anc, D, MyID, Us, Whys)
    ).
% Aggregates
solve_real(sum([each, Var], Goal, [Result]), SM, KM, Anc, D, MyID, Us, [success(sum([each, Var], Goal, [Result]), aggregate, [WhyGoal])]) :- !,
    D1 is D + 1,
    findall(Var-Whys, solve(Goal, SM, KM, Anc, D1, MyID, [], Whys), Pairs),
    pairs_keys_values(Pairs, List, WhysList),
    flatten(WhysList, WhysGoal),
    sum_list(List, Result),
    Us = [],
    WhyGoal = success(Goal, aggregate_elements, WhysGoal).
solve_real(count([each, Var], Goal, [Result]), SM, KM, Anc, D, MyID, Us, [success(count([each, Var], Goal, [Result]), aggregate, [WhyGoal])]) :- !,
    D1 is D + 1,
    findall(Var-Whys, solve(Goal, SM, KM, Anc, D1, MyID, [], Whys), Pairs),
    pairs_keys_values(Pairs, List, WhysList),
    flatten(WhysList, WhysGoal),
    length(List, Result),
    Us = [],
    WhyGoal = success(Goal, aggregate_elements, WhysGoal).
solve_real(min([each, Var], Goal, [Result]), SM, KM, Anc, D, MyID, Us, [success(min([each, Var], Goal, [Result]), aggregate, [WhyGoal])]) :- !,
    D1 is D + 1,
    findall(Var-Whys, solve(Goal, SM, KM, Anc, D1, MyID, [], Whys), Pairs),
    pairs_keys_values(Pairs, List, WhysList),
    flatten(WhysList, WhysGoal),
    min_list(List, Result),
    Us = [],
    WhyGoal = success(Goal, aggregate_elements, WhysGoal).
solve_real(max([each, Var], Goal, [Result]), SM, KM, Anc, D, MyID, Us, [success(max([each, Var], Goal, [Result]), aggregate, [WhyGoal])]) :- !,
    D1 is D + 1,
    findall(Var-Whys, solve(Goal, SM, KM, Anc, D1, MyID, [], Whys), Pairs),
    pairs_keys_values(Pairs, List, WhysList),
    flatten(WhysList, WhysGoal),
    max_list(List, Result),
    Us = [],
    WhyGoal = success(Goal, aggregate_elements, WhysGoal).
solve_real(average([each, Var], Goal, [Result]), SM, KM, Anc, D, MyID, Us, [success(average([each, Var], Goal, [Result]), aggregate, [WhyGoal])]) :- !,
    D1 is D + 1,
    findall(Var-Whys, solve(Goal, SM, KM, Anc, D1, MyID, [], Whys), Pairs),
    pairs_keys_values(Pairs, List, WhysList),
    flatten(WhysList, WhysGoal),
    sum_list(List, Sum),
    length(List, Count),
    (Count > 0 -> Result is Sum / Count ; Result = 0),
    Us = [],
    WhyGoal = success(Goal, aggregate_elements, WhysGoal).
% Forall
solve_real(forall(Cond, Cons), SM, KM, Anc, D, MyID, Us, [success(forall(Cond, Cons), universal, Whys)]) :- !,
    D1 is D + 1,
    findall(UsC-WhysC, solve(Cond, SM, KM, Anc, D1, MyID, UsC, WhysC), CondResults),
    (   CondResults == [] -> Us = [], Whys = [success(Cond, empty_forall, [])]
    ;   % For each solution of Cond, Cons must succeed
        forall(member(UsC-WhysC, CondResults),
               (UsC == [] -> solve(Cons, SM, KM, Anc, D1, MyID, [], _) ; true)),
        Us = [], % TODO: handle unknowns in forall
        Whys = [success(forall(Cond, Cons), universal_success, [])]
    ).

% Negation as Failure
solve_real(not(Goal), SM, KM, Anc, D, MyID, Us, [success(not(Goal), negation, FailureTrees)]) :- !,
    D1 is D + 1,
    next_id(GoalID),
    assertz(called(MyID, GoalID, Goal)),
    findall(UsA, solve(Goal, SM, KM, Anc, D1, GoalID, UsA, _), AllUsA),
    (   member([], AllUsA)
    ->  fail % Certain success of Goal, so not(Goal) fails
    ;   AllUsA \== []
    ->  Us = [not(Goal)], % Only unknown successes
        build_failure_tree(GoalID, FailureTrees)
    ;   Us = [], % Certain failure of Goal, so not(Goal) succeeds
        build_failure_tree(GoalID, FailureTrees)
    ).

% True
solve_real(true, _, _, _, _, _, [], []) :- !.

% Literals
solve_real(G, SM, KM, Anc, D, MyID, Us, [success(G, Ref, WhysBody)]) :-
    G \= (_ , _), G \= (_ ; _), G \= and(_, _), G \= or(_, _), G \= not(_), G \= true, G \= fail,
    G \= sum(_, _, _), G \= count(_, _, _), G \= min(_, _, _), G \= max(_, _, _), G \= average(_, _, _),
    (   D > 100 -> fail ; true % Depth limit
    ),

    (   KM \== none, current_predicate(KM:le_unknown/1), KM:le_unknown(G)
    ->  Us = [G], WhysBody = [success(G, unknown, [])]
    ;   is_built_in(G)
    ->  call_reasoner_built_in(G), Us = [], Ref = built_in, WhysBody = []
    ;   G = is_a(X, Z)
    ->  D1 is D + 1,
        (   get_clause(is_a(X, Z), SM, KM, Body, Ref),
            \+ SM:le_neg(is_a(X, Z)),
            \+ member(is_a(X, Z), Anc),
            solve(Body, SM, KM, [is_a(X, Z)|Anc], D1, MyID, Us, WhysBody)
        ;   % Transitivity: X is a Y and Y is a Z
            % Use a base fact for the first step to avoid infinite recursion
            (SM:clause(is_a(X, Y), true, Ref1) ; (KM \== none, KM:clause(is_a(X, Y), true, Ref1))),
            Y \== Z,
            \+ SM:le_neg(is_a(X, Y)),
            \+ member(is_a(X, Y), Anc),
            % Record the fact call
            next_id(FactID),
            assertz(called(MyID, FactID, is_a(X, Y))),
            solve(is_a(Y, Z), SM, KM, [is_a(X, Z)|Anc], D1, MyID, Us, WhysBody2),
            Ref = transitivity,
            WhysBody = [success(is_a(X, Y), Ref1, []) | WhysBody2]
        )
    ;   get_clause(G, SM, KM, Body, Ref),
        \+ SM:le_neg(G),
        \+ member(G, Anc),
        D1 is D + 1,
        solve(Body, SM, KM, [G|Anc], D1, MyID, Us, WhysBody)
    ).

% build_failure_tree(+ID, -Whys)
% Reconstructs a list of "juicy" failure trees of all calls made under ID.
build_failure_tree(ID, Whys) :-
    called(_, ID, Term),
    (   is_trivial(Term)
    ->  findall(W, (called(ID, CID, _), build_failure_tree(CID, Ws), member(W, Ws)), Whys)
    ;   findall(W, (called(ID, CID, _), build_failure_tree(CID, Ws), member(W, Ws)), Children),
        Whys = [failure(Term, Children)]
    ).

is_trivial((_, _)).
is_trivial(and(_, _)).
is_trivial((_ ; _)).
is_trivial(or(_, _)).
is_trivial(true).

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

init_counter :-
    retractall(counter(_)),
    assertz(counter(1)).

next_id(ID) :-
    retract(counter(ID)),
    NextID is ID + 1,
    assertz(counter(NextID)).
