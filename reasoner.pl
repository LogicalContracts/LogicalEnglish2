:- module(reasoner, [i/4]).

:- use_module(library(time)).
:- use_module(library(pairs)).

/** <module> Logical English Reasoner
    
    This module implements a meta-interpreter for Logical English (LE).
    It handles conjunctions, disjunctions, negation as failure, and 
    conditional answers (Unknowns).
    It constructs success explanation trees.
*/

:- dynamic equal_to/2.

% i(+Goal, +SessionModule, -Unknowns, -Why)
% Main entry point for the meta-interpreter.
i(Goal, SessionModule, Unknowns, Why) :-
    (   SessionModule:le_my_kb(KBmodule)
    ->  true
    ;   KBmodule = none
    ),
    % Default time limit of 2 seconds
    catch(call_with_time_limit(2, solve(Goal, SessionModule, KBmodule, [], Unknowns, Why)),
          time_limit_exceeded,
          (Unknowns = [timeout(Goal)], Why = success(Goal, timeout, []))).

% solve(+Goal, +SM, +KM, +Ancestors, -Us, -Why)
% Succeeds if Goal can be proven (possibly with Unknowns).

% Conjunction
solve((A, B), SM, KM, Anc, Us, success((A, B), conjunction, [WhyA, WhyB])) :- !,
    solve(A, SM, KM, Anc, UsA, WhyA),
    solve(B, SM, KM, Anc, UsB, WhyB),
    append(UsA, UsB, Us).
solve(and(A, B), SM, KM, Anc, Us, success(and(A, B), conjunction, [WhyA, WhyB])) :- !,
    solve(A, SM, KM, Anc, UsA, WhyA),
    solve(B, SM, KM, Anc, UsB, WhyB),
    append(UsA, UsB, Us).

% Disjunction
solve((A ; B), SM, KM, Anc, Us, success((A ; B), disjunction, [Why])) :- !,
    (   solve(A, SM, KM, Anc, Us, Why)
    ;   solve(B, SM, KM, Anc, Us, Why)
    ).
solve(or(A, B), SM, KM, Anc, Us, success(or(A, B), disjunction, [Why])) :- !,
    (   solve(A, SM, KM, Anc, Us, Why)
    ;   solve(B, SM, KM, Anc, Us, Why)
    ).

% Aggregates
solve(sum([each, Var], Goal, [Result]), SM, KM, Anc, Us, success(sum([each, Var], Goal, [Result]), aggregate, [WhyGoal])) :- !,
    findall(Var-Why, solve(Goal, SM, KM, Anc, [], Why), Pairs),
    pairs_keys_values(Pairs, List, Whys),
    sum_list(List, Result),
    Us = [],
    WhyGoal = success(Goal, aggregate_elements, Whys).

solve(count([each, Var], Goal, [Result]), SM, KM, Anc, Us, success(count([each, Var], Goal, [Result]), aggregate, [WhyGoal])) :- !,
    findall(Var-Why, solve(Goal, SM, KM, Anc, [], Why), Pairs),
    pairs_keys_values(Pairs, List, Whys),
    length(List, Result),
    Us = [],
    WhyGoal = success(Goal, aggregate_elements, Whys).

solve(min([each, Var], Goal, [Result]), SM, KM, Anc, Us, success(min([each, Var], Goal, [Result]), aggregate, [WhyGoal])) :- !,
    findall(Var-Why, solve(Goal, SM, KM, Anc, [], Why), Pairs),
    pairs_keys_values(Pairs, List, Whys),
    min_list(List, Result),
    Us = [],
    WhyGoal = success(Goal, aggregate_elements, Whys).

solve(max([each, Var], Goal, [Result]), SM, KM, Anc, Us, success(max([each, Var], Goal, [Result]), aggregate, [WhyGoal])) :- !,
    findall(Var-Why, solve(Goal, SM, KM, Anc, [], Why), Pairs),
    pairs_keys_values(Pairs, List, Whys),
    max_list(List, Result),
    Us = [],
    WhyGoal = success(Goal, aggregate_elements, Whys).

solve(average([each, Var], Goal, [Result]), SM, KM, Anc, Us, success(average([each, Var], Goal, [Result]), aggregate, [WhyGoal])) :- !,
    findall(Var-Why, solve(Goal, SM, KM, Anc, [], Why), Pairs),
    pairs_keys_values(Pairs, List, Whys),
    sum_list(List, Sum),
    length(List, Count),
    (Count > 0 -> Result is Sum / Count ; Result = 0),
    Us = [],
    WhyGoal = success(Goal, aggregate_elements, Whys).

% Negation as Failure
solve(not(Goal), SM, KM, Anc, Us, success(not(Goal), negation, [])) :- !,
    (   \+ ground(Goal)
    ->  Us = [not(Goal)]
    ;   findall(UsA, solve(Goal, SM, KM, Anc, UsA, _), AllUsA),
        (   member([], AllUsA)
        ->  fail % Certain success of Goal, so not(Goal) fails
        ;   AllUsA \== []
        ->  Us = [not(Goal)] % Only unknown successes
        ;   Us = []
        )
    ).

% True
solve(true, _, _, _, [], success(true, built_in, [])) :- !.

% Literals
solve(G, SM, KM, Anc, Us, Why) :-
    G \= (_ , _), G \= (_ ; _), G \= and(_, _), G \= or(_, _), G \= not(_), G \= true, G \= fail,
    G \= sum(_, _, _), G \= count(_, _, _), G \= min(_, _, _), G \= max(_, _, _), G \= average(_, _, _),
    (   KM \== none, current_predicate(KM:le_unknown/1), KM:le_unknown(G)
    ->  Us = [G], Why = success(G, unknown, [])
    ;   \+ SM:le_neg(G),
        (   (SM:clause(G, Body, Ref) ; (KM \== none, KM:clause(G, Body, Ref))),
            \+ member(G, Anc),
            solve(Body, SM, KM, [G|Anc], Us, WhyBody),
            Why = success(G, Ref, [WhyBody])
        ;   is_built_in(G),
            call(G), Us = [], Why = success(G, built_in, [])
        ;   % If it's not a built-in and has no clauses, it might be a fact in the session
            % that was added via addSessionFact/2.
            SM:sessionClause(Ref), clause(SM:G, true, Ref),
            Us = [], Why = success(G, Ref, [])
        )
    ).


% Helpers

is_built_in(G) :- predicate_property(G, built_in).
is_built_in(le_equal_to(_, _)).
is_built_in(le_assign(_, _)).
is_built_in(le_is(_, _)).
is_built_in(le_ge(_, _)).
is_built_in(le_le(_, _)).
is_built_in(le_gt(_, _)).
is_built_in(le_lt(_, _)).

le_equal_to(X, Y) :- X = Y.
le_assign(X, Y) :- X = Y.
le_is(X, Y) :- catch(X is Y, _, X = Y).
le_ge(X, Y) :- X >= Y.
le_le(X, Y) :- X =< Y.
le_gt(X, Y) :- X > Y.
le_lt(X, Y) :- X < Y.

equal_to(X, X).
