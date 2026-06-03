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
:- thread_local called/3, counter/1, success_in_not/2, succeeded/1.

%!  i(+Goal:term, +SessionModule:atom, -Unknowns:list, -Whys:list) is nondet.
i(Goal, SessionModule, Unknowns, Whys) :-
    retractall(called(_, _, _)),
    retractall(success_in_not(_, _)),
    retractall(succeeded(_)),
    init_counter,
    ( SessionModule:le_kb_module_fact(KBmodule) ->  true; KBmodule = none),
    setup_call_cleanup(
        le_kbs:set_kb_module(KBmodule),
        (
            solve(Goal, SessionModule, KBmodule, [], 0, none, Unknowns0, Whys),
            \+ (
                member(U, Unknowns0),
                solve(U, SessionModule, KBmodule, [], 0, none, [], _)
            ),
            Unknowns = Unknowns0
        ),
        le_kbs:clear_kb_module
    ).


%!  explain(+Goal:term, +SessionModule:atom, -Unknowns:list, -Whys:list) is nondet.
%
%   Similar to i/4, but always returns an explanation tree (success or failure).
explain(Goal, SessionModule, Unknowns, Whys) :-
    retractall(called(_, _, _)),
    retractall(success_in_not(_, _)),
    retractall(succeeded(_)),
    init_counter,
    ( SessionModule:le_kb_module_fact(KBmodule) ->  true; KBmodule = none),
    setup_call_cleanup(
        le_kbs:set_kb_module(KBmodule),
        (   solve(Goal, SessionModule, KBmodule, [], 0, 0, Unknowns0, Whys),
            \+ (
                member(U, Unknowns0),
                solve(U, SessionModule, KBmodule, [], 0, none, [], _)
            ) ->  
            Unknowns = Unknowns0
            ;   
            Unknowns = [],
            findall(W, (called(0, CID, _), build_failure_tree(CID, Ws), member(W, Ws)), Whys)
        ),
        le_kbs:clear_kb_module
    ).

%!  solve(+Goal:term, +SM:atom, +KM:atom, +Anc:list, +Depth:integer, +ParentID:any, -Us:list, -Whys:list) is nondet.
solve(G, SM, KM, Anc, D, ParentID, Us, Whys) :-
    (   is_trivial(G)
    ->  solve_real(G, SM, KM, Anc, D, ParentID, Us, Whys)
    ;   is_redundant(ParentID, G)
    ->  solve_real(G, SM, KM, Anc, D, ParentID, Us, Whys)
    ;           next_id(MyID),
        ( ParentID \== none -> assertz(called(ParentID, MyID, G)); true),
        (   SM:debug_mode

        ->  dap_server:dap_tracer_hook(call, SM, G, MyID, Anc, D),
            (   catch(solve_real(G, SM, KM, Anc, D, MyID, Us, Whys), E, 
                      (dap_server:dap_tracer_hook(exception(E), SM, G, MyID, Anc, D), throw(E)))
            ->  (succeeded(MyID) -> true ; assertz(succeeded(MyID))),
                dap_server:dap_tracer_hook(exit, SM, G, MyID, Anc, D)
            ;   dap_server:dap_tracer_hook(fail, SM, G, MyID, Anc, D),
                fail
            )
        ;   solve_real(G, SM, KM, Anc, D, MyID, Us, Whys),
            (succeeded(MyID) -> true ; assertz(succeeded(MyID)))
        )
    ).

% Conjunction
solve_real(G, SM, KM, Anc, D, MyID, Us, Whys) :-
    solve_real_actual(G, SM, KM, Anc, D, MyID, Us, Whys).

solve_real_actual((A, B), SM, KM, Anc, D, MyID, Us, Whys) :- !,
    solve(A, SM, KM, Anc, D, MyID, UsA, WhysA),
    solve(B, SM, KM, Anc, D, MyID, UsB, WhysB),
    append(UsA, UsB, Us),
    append(WhysA, WhysB, Whys).
solve_real_actual(and(A, B), SM, KM, Anc, D, MyID, Us, Whys) :- !,
    solve(A, SM, KM, Anc, D, MyID, UsA, WhysA),
    solve(B, SM, KM, Anc, D, MyID, UsB, WhysB),
    append(UsA, UsB, Us),
    append(WhysA, WhysB, Whys).
% Disjunction
solve_real_actual((A ; B), SM, KM, Anc, D, MyID, Us, Whys) :- !,
    (   solve(A, SM, KM, Anc, D, MyID, Us, Whys)
    ;   solve(B, SM, KM, Anc, D, MyID, Us, Whys)
    ).
solve_real_actual(or(A, B), SM, KM, Anc, D, MyID, Us, Whys) :- !,
    (   solve(A, SM, KM, Anc, D, MyID, Us, Whys)
    ;   solve(B, SM, KM, Anc, D, MyID, Us, Whys)
    ).
% Once
solve_real_actual(once(Goal), SM, KM, Anc, D, MyID, Us, Whys) :- !,
    once(solve(Goal, SM, KM, Anc, D, MyID, Us, Whys)).
% Aggregates
solve_real_actual(Aggregate, SM, KM, Anc, D, MyID, Us, [success(Aggregate, aggregate, WhysGoal)]) :-
    is_aggregate(Aggregate, Type, VarTerm, Goal, ResultTerm), !,
    D1 is D + 1,
    extract_var(VarTerm, Var),
    findall(Var-Whys, solve(Goal, SM, KM, Anc, D1, MyID, [], Whys), Pairs),
    (   Pairs == [] ->  
        % Goal failed, build failure tree for the goal
        % We need to ensure the failure is recorded under MyID
        next_id(GoalID),
        ( (MyID \== none, ground(Goal)) -> assertz(called(MyID, GoalID, Goal)); true),
        ( solve(Goal, SM, KM, Anc, D1, GoalID, [], _) -> true ; true ),
        build_failure_tree(GoalID, WhysGoal),
        List = []
    ;   pairs_keys_values(Pairs, List, WhysList),
        flatten(WhysList, WhysGoal)
    ),
    apply_aggregate(Type, List, Result),

    Us = [],
    extract_var(ResultTerm, Result).
% Forall
% The explanation is a single nested branch that mirrors the LE surface syntax:
%   for all cases in which <Cond>
%     it is the case that
%       <Cons>
% (Previously this produced two stacked nodes carrying the whole forall term,
% which rendered the line twice.)
solve_real_actual(forall(Cond, Cons), SM, KM, Anc, D, MyID, Us, [success(for_all_cases(Cond), universal, ConsWhy)]) :- !,
    D1 is D + 1,
    findall(UsC-WhysC, solve(Cond, SM, KM, Anc, D1, MyID, UsC, WhysC), CondResults),
    (   CondResults == [] -> true % vacuously true: no matching cases
        ;
        % For each solution of Cond, Cons must succeed
        forall(member(UsC-WhysC, CondResults),
               ( UsC == [] -> solve(Cons, SM, KM, Anc, D1, MyID, [], _); true))
    ),
    Us = [], % TODO: handle unknowns in forall
    ( Cons = le_at(ConsGoal, CS, CE) -> ConsRef = range(CS, CE) ; ConsGoal = Cons, ConsRef = universal_body ),
    ConsWhy = [success(it_is_the_case, universal_consequent, [success(ConsGoal, ConsRef, [])])].

% Negation as Failure
solve_real_actual(not(Goal), SM, KM, Anc, D, MyID, Us, [success(not(Goal), negation, FailureTrees)]) :- !,
    D1 is D + 1,
    next_id(GoalID),
    assertz(called(MyID, GoalID, Goal)),
    findall(UsA-WhysA, solve_real(Goal, SM, KM, Anc, D1, GoalID, UsA, WhysA), AllResults),
    (   member([]-WhysA, AllResults) ->  
        assertz(success_in_not(GoalID, WhysA)),
        fail % Certain success of Goal, so not(Goal) fails
    ;   pairs_keys(AllResults, AllUsA),
        AllUsA \== [] ->  
            Us = [not(Goal)], % Only unknown successes
            build_failure_tree(GoalID, FailureTrees),
            assertz(success_in_not(GoalID, FailureTrees))
        ; Us = [], % Certain failure of Goal, so not(Goal) succeeds
            build_failure_tree(GoalID, FailureTrees),
            assertz(success_in_not(GoalID, FailureTrees))
    ).

% True
solve_real_actual(true, _, _, _, _, _, [], []) :- !.

% Type restriction on a (scenario) variable: succeeds immediately, attaching a
% lazy constraint that fires once Arg is bound (mirrors check_args_compatibility).
solve_real_actual(le_type_check(Arg, Type), SM, KM, _Anc, _D, _MyID, [], [success(le_type_check(Arg, Type), built_in, [])]) :- !,
    ( KM \== none -> M = KM ; M = SM ),
    when(nonvar(Arg),
         ( M:le_type(Arg) -> once(is_a_simple(Arg, Type, M)) ; true )).

% Literals
solve_real_actual(le_at(Goal, Start, End), SM, KM, Anc, D, MyID, Us, Whys) :- !,
    solve(Goal, SM, KM, Anc, D, MyID, Us, Whys0),
    maplist(attach_range(Start, End), Whys0, Whys).
solve_real_actual(G, SM, KM, Anc, D, MyID, Us, [success(G, Ref, WhysBody)]) :-

    (   D > 100 -> throw('Tried to solve too deep') ; true % Depth limit
    ),

    (   is_built_in(G) ->  
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
                ( ground(is_a(X, Y)) -> assertz(called(MyID, FactID, is_a(X, Y))) ; true ),
                solve(is_a(Y, Z), SM, KM, [is_a(X, Y), is_a(X, Z)|Anc], D1, MyID, Us, WhysBody2),
                Ref = transitivity,
                WhysBody = [success(is_a(X, Y), Ref1, []) | WhysBody2]
            )
        ; get_clause(G, SM, KM, Body, Ref),
            ( KM \== none -> le_kbs:set_id_from_ref(Ref, KM) ; le_kbs:set_id_from_ref(Ref, SM) ),
            \+ SM:le_neg(G),
            \+ member(G, Anc),
            is_type_compatible(SM, KM, G),
            D1 is D + 1,
            (   has_opposite(G, SM, KM, OppG), \+ member(OppG, Anc) ->
                ( le_kbs:do_log -> format('Solving ~w with opposite ~w\n', [G, OppG]) ; true ),
                % Solve Body, then check that OppG is not true for reasons OTHER than not(G)
                solve(Body, SM, KM, [G|Anc], D1, MyID, Us, WhysBody),
                \+ ( get_clause(OppG, SM, KM, OppBody, OppRef),
                     OppRef \== implicit_opposite,
                     % Use a fresh Anc for OppBody to avoid loop but allow checking G
                     solve(OppBody, SM, KM, [OppG], D1, MyID, [], _)
                   )
            ;   solve(Body, SM, KM, [G|Anc], D1, MyID, Us, WhysBody)
            )
        ; get_clause(le_unknown(G), SM, KM, UnkBody, _UnkRef),
          \+ SM:le_neg(le_unknown(G)),
          \+ member(le_unknown(G), Anc),
          D1 is D + 1,
          solve(UnkBody, SM, KM, [le_unknown(G)|Anc], D1, MyID, [], _) ->  
            Us = [G], WhysBody = [], Ref = unknown
    ).



has_opposite(G, SM, KM, OppG) :-
    ( KM \== none -> M = KM ; M = SM ),
    functor(G, F, A),
    (   M:le_dict(dict([F|Args], _, _, _, Opposite, _, _)), length(Args, A), nonvar(Opposite) ->
        % G is the main predicate
        G =.. [F | GArgs],
        copy_term(dict(Args, Opposite), dict(GArgs, OppG))
    ;   M:le_dict(dict(FA, _, _, _, Opposite, _, _)), nonvar(Opposite), functor(Opposite, F, A) ->
        % G is the opposite predicate
        Opposite =.. [F | OppArgs],
        G =.. [F | GArgs],
        OppArgs = GArgs,
        FA = [MainF | MainArgs],
        OppG =.. [MainF | MainArgs]
    ;   fail
    ).

is_type_compatible(SM, KM, G) :-
    ( KM \== none -> M = KM ; M = SM ),
    functor(G, F, N),
    ( (M:le_dict(dict([F|FormalArgs], NTs, _, _, _, _, _)) ; M:le_dict(dict([F|FormalArgs], NTs, _))), length(FormalArgs, N) ->
        G =.. [F|ActualArgs],
        check_args_compatibility(FormalArgs, ActualArgs, NTs, M, SM, KM)
    ; true
    ).

check_args_compatibility([], [], _, _, _, _).
check_args_compatibility([FA|FAs], [AA|AAs], NTs, M, SM, KM) :-
    ( member(FA_-FormalType, NTs), FA_==FA, FormalType \== any ->
        when(nonvar(AA), (
            ( M:le_type(AA) ->
                once(is_a_simple(AA, FormalType, M))
            ; true
            )
        ))
    ; true
    ),
    check_args_compatibility(FAs, AAs, NTs, M, SM, KM).

is_a_simple(X, Z, _) :- X == Z, !.
is_a_simple(X, Z, M) :- M:clause(is_a(X, Z), true), !.
is_a_simple(X, Z, M) :- M:clause(is_a(X, Y), true), Y \== Z, is_a_simple(Y, Z, M).

% build_failure_tree(+ID, -Whys)
% Reconstructs a list of "juicy" failure trees of all calls made under ID.
build_failure_tree(ID, Whys) :-
    (   success_in_not(ID, Whys) -> true
    ;   succeeded(ID) -> Whys = []
    ;   ( setof(W, CID^Ws^(called(ID, CID, _), build_failure_tree(CID, Ws), member(W, Ws)), AllWhys) -> true ; AllWhys = []),
        (   called(_PID, ID, Term)
        ->  (   (AllWhys = [failure(Term2, Children)], variant_or_le_at_variant(Term, Term2))
            ->  Whys = [failure(Term, Children)] % Collapse pass-through
            ;   Whys = [failure(Term, AllWhys)]
            )
        ;   Whys = AllWhys
        )
    ).

variant_or_le_at_variant(T1, T2) :-
    strip_le_at(T1, S1),
    strip_le_at(T2, S2),
    variant(S1, S2).

strip_le_at(le_at(G, _, _), G) :- !.
strip_le_at(G, G).

is_trivial((_, _)) :- !.
is_trivial(and(_, _)) :- !.
is_trivial((_ ; _)) :- !.
is_trivial(or(_, _)) :- !.
is_trivial(true) :- !.

is_redundant(PID, G) :-
    PID \== none,
    called(_, PID, le_at(G1, _, _)),
    variant(G, G1).
is_redundant(PID, le_at(G, _, _)) :-
    PID \== none,
    called(_, PID, G1),
    variant(G, G1).


% get_clause(+Goal, +SM, +KM, -Body, -Ref)
get_clause(G, SM, _KM, Body, Ref) :-
    clause(SM:G, Body, Ref).
get_clause(G, _SM, KM, Body, Ref) :-
    KM \== none,
    clause(KM:G, Body, Ref).

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
is_built_in(le_is_days_after(_, _, _)).
is_built_in(le_is_in(_, _)).
is_built_in(equal_to(_, _)).

call_reasoner_built_in(prolog_call(G), SM) :- !, 
    (   compound(G), G = M:Goal -> M:call(Goal)
    ;   catch(SM:call(G), _, fail)
    ;   catch(le_kbs:call(G), _, fail)
    ;   SM:call(G)
    ).
call_reasoner_built_in(le_at(G, _, _), SM) :- !, call_reasoner_built_in(G, SM).
call_reasoner_built_in(le_known(X), _) :- !, ground(X).
call_reasoner_built_in(le_equal_to(X, Y), _) :- !, X = Y.
call_reasoner_built_in(le_assign(X, Y), _) :- !, 
    ( number(Y) -> X = Y
    ; catch(X is Y, _, (
        (var(X) -> true ; true), % debug point
        X = Y
      ))
    ).
call_reasoner_built_in(le_is(X, Y), _) :- !, ( number(Y) -> X is Y; catch(X is Y, _, X = Y)).
call_reasoner_built_in(le_is_in(X, Y), _) :- !, is_list(Y), member(X, Y).
call_reasoner_built_in(le_ge(X, Y), _) :- !, le_compare(>=, X, Y).
call_reasoner_built_in(le_le(X, Y), _) :- !, le_compare(=<, X, Y).
call_reasoner_built_in(le_gt(X, Y), _) :- !, le_compare(>, X, Y).
call_reasoner_built_in(le_lt(X, Y), _) :- !, le_compare(<, X, Y).
call_reasoner_built_in(le_is_days_after(Later, Count, Before), _) :- !, le_is_days_after(Later, Count, Before).
call_reasoner_built_in(equal_to(X, Y), _) :- !, equal_to(X, Y).
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

le_is_days_after(Later, Count, Before) :-
    nonvar(Before), nonvar(Count), !, 
    le_date_stamp(Before, BeforeStamp),
    LaterStamp is Count*86400 + BeforeStamp,
    le_stamp_date(LaterStamp, Later).
le_is_days_after(Later, Count, Before) :-
    nonvar(Later), nonvar(Count), !, 
    le_date_stamp(Later, LaterStamp),
    BeforeStamp is LaterStamp - Count*86400,
    le_stamp_date(BeforeStamp, Before).
le_is_days_after(Later, Count, Before) :-
    nonvar(Later), nonvar(Before),
    le_date_stamp(Later, LaterStamp),
    le_date_stamp(Before, BeforeStamp),
    Count is round(LaterStamp - BeforeStamp) div 86400. % using negative number to indicate reserve order 

le_date_stamp(date(Y,M,D), Stamp) :-
    date_time_stamp(date(Y,M,D,0,0,0,0,'UTC',-), Stamp).
le_date_stamp(date(Y,M,D,H,Mn,S,Off,TZ,DST), Stamp) :-
    date_time_stamp(date(Y,M,D,H,Mn,S,Off,TZ,DST), Stamp).

le_stamp_date(Stamp, date(Y,M,D)) :-
    stamp_date_time(Stamp, date(Y,M,D,_,_,_,_,_,_), 'UTC').


attach_range(Start, End, success(G, unknown, Children), success(G, unknown(Start, End), Children)) :- !.
attach_range(Start, End, success(G, Ref, Children), success(G, NewRef, Children)) :- !,
    (   is_special_ref(Ref)
    ->  NewRef = range(Start, End)
    ;   NewRef = Ref
    ).
attach_range(_, _, Why, Why).

is_special_ref(Ref) :-
    memberchk(Ref, [built_in, identity, transitivity, aggregate, negation, universal, universal_success, empty_forall]).
is_special_ref(range(_, _)).

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
