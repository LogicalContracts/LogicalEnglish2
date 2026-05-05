/** <module> Logical English Reasoner
    
    This module implements a meta-interpreter for Logical English (LE).
    It handles conjunctions, disjunctions, negation as failure, aggregates,
    and conditional answers (Unknowns). It constructs success and failure
    explanation trees.
*/

:- module(reasoner, [i/4, explain/4, is_built_in/1, solve/8]).

:- use_module(library(time)).
:- use_module(library(pairs)).

:- dynamic equal_to/2.
:- thread_local called/3, counter/1, success_in_not/2.

%!  i(+Goal:term, +SessionModule:atom, -Unknowns:list, -Whys:list) is nondet.
%
%   Main entry point for the meta-interpreter.
i(Goal, SessionModule, Unknowns, Whys) :-
    retractall(called(_, _, _)),
    retractall(success_in_not(_, _)),
    init_counter,
    ( SessionModule:le_kb_module_fact(KBmodule) ->  true; KBmodule = none),
    setup_call_cleanup(
        le_kbs:set_kb_module(KBmodule),
        solve(Goal, SessionModule, KBmodule, [], 0, none, Unknowns, Whys),
        le_kbs:clear_kb_module
    ).

%!  explain(+Goal:term, +SessionModule:atom, -Unknowns:list, -Whys:list) is nondet.
%
%   Similar to i/4, but always returns an explanation tree (success or failure).
explain(Goal, SessionModule, Unknowns, Whys) :-
    retractall(called(_, _, _)),
    retractall(success_in_not(_, _)),
    init_counter,
    ( SessionModule:le_kb_module_fact(KBmodule) ->  true; KBmodule = none),
    setup_call_cleanup(
        le_kbs:set_kb_module(KBmodule),
        (   solve(Goal, SessionModule, KBmodule, [], 0, 0, Unknowns, Whys) ->  true 
            ;   
            Unknowns = [],
            findall(W, (called(0, CID, _), build_failure_tree(CID, Ws), member(W, Ws)), Whys)
        ),
        le_kbs:clear_kb_module
    ).

%!  solve(+Goal:term, +SM:atom, +KM:atom, +Anc:list, +Depth:integer, +ParentID:any, -Us:list, -Whys:list) is nondet.
solve(G, SM, KM, Anc, D, ParentID, Us, Whys) :-
    next_id(MyID),
    ( ParentID \== none -> assertz(called(ParentID, MyID, G)); true),
    (   SM:debug_mode
    ->  dap_server:dap_tracer_hook(call, SM, G, MyID, Anc, D),
        (   catch(solve_real(G, SM, KM, Anc, D, MyID, Us, Whys), E, 
                  (dap_server:dap_tracer_hook(exception(E), SM, G, MyID, Anc, D), throw(E)))
        ->  dap_server:dap_tracer_hook(exit, SM, G, MyID, Anc, D)
        ;   dap_server:dap_tracer_hook(fail, SM, G, MyID, Anc, D),
            fail
        )
    ;   solve_real(G, SM, KM, Anc, D, MyID, Us, Whys)
    ).

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
solve_real(Aggregate, SM, KM, Anc, D, MyID, Us, [success(Aggregate, aggregate, WhysGoal)]) :-
    is_aggregate(Aggregate, Type, VarTerm, Goal, ResultTerm), !,
    D1 is D + 1,
    extract_var(VarTerm, Var),
    findall(Var-Whys, solve(Goal, SM, KM, Anc, D1, MyID, [], Whys), Pairs),
    pairs_keys_values(Pairs, List, WhysList),
    flatten(WhysList, WhysGoal),
    apply_aggregate(Type, List, Result),
    Us = [],
    extract_var(ResultTerm, Result).
% Forall
solve_real(forall(Cond, Cons), SM, KM, Anc, D, MyID, Us, [success(forall(Cond, Cons), universal, Whys)]) :- !,
    D1 is D + 1,
    findall(UsC-WhysC, solve(Cond, SM, KM, Anc, D1, MyID, UsC, WhysC), CondResults),
    (   CondResults == [] -> Us = [], Whys = [success(Cond, empty_forall, [])]
        ;   
        % For each solution of Cond, Cons must succeed
        forall(member(UsC-WhysC, CondResults),
               ( UsC == [] -> solve(Cons, SM, KM, Anc, D1, MyID, [], _); true)),
        Us = [], % TODO: handle unknowns in forall
        Whys = [success(forall(Cond, Cons), universal_success, [])]
    ).

% Negation as Failure
solve_real(not(Goal), SM, KM, Anc, D, MyID, Us, [success(not(Goal), negation, FailureTrees)]) :- !,
    D1 is D + 1,
    next_id(GoalID),
    assertz(called(MyID, GoalID, Goal)),
    findall(UsA-WhysA, solve(Goal, SM, KM, Anc, D1, GoalID, UsA, WhysA), AllResults),
    (   member([]-WhysA, AllResults) ->  
        assertz(success_in_not(GoalID, WhysA)),
        fail % Certain success of Goal, so not(Goal) fails
    ;   pairs_keys(AllResults, AllUsA),
        AllUsA \== [] ->  
            Us = [not(Goal)], % Only unknown successes
            build_failure_tree(GoalID, FailureTrees)
        ; Us = [], % Certain failure of Goal, so not(Goal) succeeds
            build_failure_tree(GoalID, FailureTrees)
    ).

% True
solve_real(true, _, _, _, _, _, [], []) :- !.

% Literals
solve_real(le_at(Goal, Start, End), SM, KM, Anc, D, MyID, Us, Whys) :- !,
    solve(Goal, SM, KM, Anc, D, MyID, Us, Whys0),
    maplist(attach_range(Start, End), Whys0, Whys).

solve_real(G, SM, KM, Anc, D, MyID, Us, [success(G, Ref, WhysBody)]) :-
    (   D > 100 -> fail ; true % Depth limit
    ),

    (   KM \== none, current_predicate(KM:le_unknown/1), KM:le_unknown(G) ->  
            Us = [G], WhysBody = [success(G, unknown, [])]
        ; is_built_in(G) ->  
            call_reasoner_built_in(G, SM), Us = [], Ref = built_in, WhysBody = []
        ; G = is_a(X, Z) ->  
            D1 is D + 1,
            (   X == Z -> Us = [], WhysBody = [success(G, identity, [])]
            ;   get_clause(is_a(X, Z), SM, KM, Body, Ref),
                \+ SM:le_neg(is_a(X, Z)),
                \+ member(is_a(X, Z), Anc),
                solve(Body, SM, KM, [is_a(X, Z)|Anc], D1, MyID, Us, WhysBody)
            ;   % Transitivity: X is a Y and Y is a Z
                % Use a base fact for the first step to avoid infinite recursion
                (SM:clause(is_a(X, Y), true, Ref1) ; (KM \== none, KM:clause(is_a(X, Y), true, Ref1))),
                Y \== Z, Y \== X,
                \+ SM:le_neg(is_a(X, Y)),
                \+ member(is_a(X, Y), Anc),
                % Record the fact call
                next_id(FactID),
                assertz(called(MyID, FactID, is_a(X, Y))),
                solve(is_a(Y, Z), SM, KM, [is_a(X, Z)|Anc], D1, MyID, Us, WhysBody2),
                Ref = transitivity,
                WhysBody = [success(is_a(X, Y), Ref1, []) | WhysBody2]
            )
        ; get_clause(G, SM, KM, Body, Ref),
            ( KM \== none -> le_kbs:set_id_from_ref(Ref, KM) ; le_kbs:set_id_from_ref(Ref, SM) ),
            \+ SM:le_neg(G),
            \+ member(G, Anc),
            D1 is D + 1,
            solve(Body, SM, KM, [G|Anc], D1, MyID, Us, WhysBody)
    ).

% build_failure_tree(+ID, -Whys)
% Reconstructs a list of "juicy" failure trees of all calls made under ID.
build_failure_tree(ID, Whys) :-
    (   success_in_not(ID, Whys) -> true
    ;   called(_PID, ID, Term), % ID is the MyID of the call
        (   is_trivial(Term)
        ->  findall(W, (called(ID, CID, _), build_failure_tree(CID, Ws), member(W, Ws)), Whys)
        ;   findall(W, (called(ID, CID, _), build_failure_tree(CID, Ws), member(W, Ws)), Children),
            Whys = [failure(Term, Children)]
        )
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
is_built_in(prolog_call(_)).
is_built_in(le_at(_, _, _)).
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

call_reasoner_built_in(prolog_call(G), SM) :- !, 
    (   compound(G), G = M:Goal -> M:call(Goal)
    ;   catch(SM:call(G), _, fail) *-> true
    ;   catch(le_kbs:call(G), _, fail) *-> true
    ;   call(G)
    ).
call_reasoner_built_in(le_at(G, _, _), SM) :- !, call_reasoner_built_in(G, SM).
call_reasoner_built_in(le_known(X), _) :- !, ground(X).
call_reasoner_built_in(le_equal_to(X, Y), _) :- !, X = Y.
call_reasoner_built_in(le_assign(X, Y), _) :- !, ( number(Y) -> X is Y; catch(X is Y, _, X = Y)).
call_reasoner_built_in(le_is(X, Y), _) :- !, ( number(Y) -> X is Y; catch(X is Y, _, X = Y)).
call_reasoner_built_in(le_is_in(X, Y), _) :- !, is_list(Y), member(X, Y).
call_reasoner_built_in(le_ge(X, Y), _) :- !, le_compare(>=, X, Y).
call_reasoner_built_in(le_le(X, Y), _) :- !, le_compare(=<, X, Y).
call_reasoner_built_in(le_gt(X, Y), _) :- !, le_compare(>, X, Y).
call_reasoner_built_in(le_lt(X, Y), _) :- !, le_compare(<, X, Y).
call_reasoner_built_in(equal_to(X, Y), _) :- !, X = Y.
call_reasoner_built_in(G, _) :- call(G).

le_compare(Op, X, Y) :-
    number(X), number(Y), !,
    Goal =.. [Op, X, Y],
    call(Goal).
le_compare(>=, X, Y) :- !, X @>= Y.
le_compare(=<, X, Y) :- !, X @=< Y.
le_compare(>, X, Y) :- !, X @> Y.
le_compare(<, X, Y) :- !, X @< Y.

equal_to(X, X).

attach_range(Start, End, success(G, _Ref, Children), success(G, range(Start, End), Children)) :- !.
attach_range(_, _, Why, Why).

extract_var(var(_, V), V) :- !.
extract_var(V, V).

is_aggregate(Term, Type, VarTerm, Goal, ResultTerm) :-
    Term =.. [Type, [each, VarTerm], Goal, [ResultTerm]],
    memberchk(Type, [sum, count, min, max, average]).

apply_aggregate(sum, List, Sum) :- (List == [] -> Sum = 0 ; sum_list(List, Sum)).
apply_aggregate(count, List, Count) :- length(List, Count).
apply_aggregate(min, List, Min) :- (List == [] -> Min = 0 ; min_list(List, Min)).
apply_aggregate(max, List, Max) :- (List == [] -> Max = 0 ; max_list(List, Max)).
apply_aggregate(average, List, Avg) :- 
    (   List == [] -> Avg = 0 
    ;   sum_list(List, Sum), length(List, Count), Avg is Sum / Count
    ).

init_counter :-
    retractall(counter(_)),
    assertz(counter(1)).

next_id(ID) :-
    retract(counter(ID)),
    NextID is ID + 1,
    assertz(counter(NextID)).
