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
% The explanation mirrors the LE surface syntax, with the condition and the
% consequent as separate child branches:
%   for all cases in which          (success node — the universal holds)
%     <Cond>                        (its own branch; a FAILURE branch — red — when
%                                     no cases match, i.e. the universal is vacuously true)
%     it is the case that
%       <Cons>
solve_real_actual(forall(Cond, Cons), SM, KM, Anc, D, MyID, Us,
        [success(for_all_cases, universal, [CondWhy, ConsequentWhy])]) :- !,
    D1 is D + 1,
    next_id(CondID),
    assertz(called(MyID, CondID, Cond)),
    % For every solution of the condition (WITH its bindings) the consequent must
    % hold for those same bindings. The consequent is solved INSIDE the findall
    % conjunction so that variables shared between Cond and Cons flow from each
    % condition case to the consequent. (Solving the consequent separately, after
    % a findall over Cond alone, would lose those bindings and merely check that
    % the consequent holds for *some* value — a bug that wrongly made e.g. "family
    % one is a subset of family two" true when Bob ∈ family one but Bob ∉ family two.)
    findall(Case,
        ( solve(Cond, SM, KM, Anc, D1, CondID, UsC, WhysCond),
          ( UsC == []
            -> ( solve(Cons, SM, KM, Anc, D1, MyID, [], _) -> Case = ok(WhysCond) ; Case = consequent_failed )
            ;  Case = unknown_condition(WhysCond)
          )
        ),
        Cases),
    (   Cases == [] ->
            % Vacuously true: no matching cases. Explain the condition's FAILURE
            % so it renders as a (red) negative branch.
            build_failure_tree(CondID, CondFailWhys),
            ( CondFailWhys = [CondWhy] -> true ; CondWhy = failure(Cond, CondFailWhys) )
        ;   \+ memberchk(consequent_failed, Cases) ->
            % Consequent holds for every definite case: the universal holds.
            ( member(ok(WhysCondOk), Cases) -> CaseWhys = WhysCondOk
            ; Cases = [unknown_condition(CaseWhys)|_]
            ),
            ( CaseWhys = [CondWhy] -> true ; CondWhy = success(Cond, universal_condition, CaseWhys) )
        ;   % Some definite case's consequent failed: the universal fails.
            fail
    ),
    Us = [], % TODO: handle unknowns in forall
    ( Cons = le_at(ConsGoal, CS, CE) -> ConsRef = range(CS, CE) ; ConsGoal = Cons, ConsRef = universal_body ),
    ConsequentWhy = success(it_is_the_case, universal_consequent, [success(ConsGoal, ConsRef, [])]).

% Negation as Failure
solve_real_actual(not(Goal), SM, KM, Anc, D, MyID, Us, [success(not(Goal), negation, FailureTrees)]) :- !,
    D1 is D + 1,
    next_id(GoalID),
    assertz(called(MyID, GoalID, Goal)),
    % A definite (Us == []) success of Goal makes not(Goal) fail — and is the
    % only thing we need from Goal in that case. So short-circuit: stop exploring
    % the moment one is found (via a throw out of findall), instead of
    % enumerating Goal's entire — possibly explosive — search space. If there is
    % no definite success we still enumerate the rest to distinguish "only
    % unknown successes" (not(Goal) is unknown) from "no success at all"
    % (not(Goal) succeeds).
    (   catch(
            ( findall(UsA-WhysA,
                  ( solve_real(Goal, SM, KM, Anc, D1, GoalID, UsA, WhysA),
                    ( UsA == [] -> throw('$definite_success'(WhysA)) ; true )
                  ),
                  UnknownResults),
              DefiniteWhys = none ),
            '$definite_success'(DefW),
            DefiniteWhys = DefW )
    ),
    (   DefiniteWhys \== none ->
            assertz(success_in_not(GoalID, DefiniteWhys)),
            fail % Certain success of Goal, so not(Goal) fails
    ;   UnknownResults \== [] ->
            Us = [not(Goal)], % Only unknown successes
            build_failure_tree(GoalID, FailureTrees),
            assertz(success_in_not(GoalID, FailureTrees))
    ;   Us = [], % Certain failure of Goal, so not(Goal) succeeds
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
% A qualified/named type ("first person", "person X") is satisfied by its
% head-noun type ("person"), so that *a first person* and *a second person* are
% accepted as values of type person.
is_a_simple(X, Z, M) :- atom(Z), le_grammar:head_noun_type(Z, HZ), HZ \== Z, is_a_simple(X, HZ, M).

% build_failure_tree(+ID, -Whys)
% Reconstructs a list of "juicy" failure trees of all calls made under ID.
build_failure_tree(ID, Whys) :-
    (   success_in_not(ID, Whys) -> true
    ;   succeeded(ID) -> Whys = []
    ;   ( findall(W, (called(ID, CID, _), build_failure_tree(CID, Ws), member(W, Ws)), AllWhys0) -> true ; AllWhys0 = []),
        group_variant_whys(AllWhys0, AllWhys),
        (   called(_PID, ID, Term)
        ->  (   (AllWhys = [failure(Term2, Children)], variant_or_le_at_variant(Term, Term2))
            ->  Whys = [failure(Term, Children)] % Collapse pass-through
            ;   Whys = [failure(Term, AllWhys)]
            )
        ;   Whys = AllWhys
        )
    ).

% group_variant_whys(+Whys, -Grouped)
% Collapses sibling sub-explanations that are variants of each other (same shape
% modulo variable renaming) into a single representative, wrapped as
% repeated_group(Count, Why) when Count > 1. This both shrinks the failure tree
% at the source (so the expensive downstream passes — postprocess_why/2,
% convert_why/3, rendering — operate on a small tree) and records how many times
% each sub-explanation occurred under the same parent.
group_variant_whys(Whys, Grouped) :-
    maplist(variant_key_pair, Whys, Keyed),
    group_keyed_whys(Keyed, Grouped).

% Group on a key that ignores le_at/3 source positions (which differ between
% otherwise-identical explanations coming from different rule locations), so
% logically-identical sub-explanations collapse regardless of where in the
% source they originated. The original W (with positions) is kept as the rep.
variant_key_pair(W, Key-W) :- strip_le_at_deep(W, WStripped), variant_sha1(WStripped, Key).

% strip_le_at_deep(+Term, -Stripped): recursively replace every le_at(G,_,_)
% subterm with G, dropping all embedded source positions.
strip_le_at_deep(T, T) :- var(T), !.
strip_le_at_deep(le_at(G, _, _), Out) :- !, strip_le_at_deep(G, Out).
strip_le_at_deep(T, Out) :-
    compound(T), !,
    T =.. [F|Args],
    maplist(strip_le_at_deep, Args, Args1),
    Out =.. [F|Args1].
strip_le_at_deep(T, T).

group_keyed_whys([], []).
group_keyed_whys([Key-W|Rest], [Group|Groups]) :-
    partition_by_key(Key, Rest, NSame, Different),
    Count is NSame + 1,
    ( Count =:= 1 -> Group = W ; Group = repeated_group(Count, W) ),
    group_keyed_whys(Different, Groups).

% partition_by_key(+Key, +Keyed, -CountSame, -Different): counts (and drops)
% the pairs whose key == Key, keeping the rest in Different (order preserved).
partition_by_key(_, [], 0, []).
partition_by_key(Key, [K-W|Rest], CountSame, Different) :-
    partition_by_key(Key, Rest, CountSame1, Different1),
    ( K == Key
    ->  CountSame is CountSame1 + 1, Different = Different1
    ;   CountSame = CountSame1, Different = [K-W|Different1]
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
is_built_in(le_not_equal_to(_, _)).
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
    % Resolve the goal in the first module context that yields a solution and
    % commit to it (soft-cut), so we don't re-enumerate the same solutions in
    % each fallback context (which would return duplicate answers).
    (   compound(G), G = M:Goal
    ->  M:call(Goal)
    ;   catch(SM:call(G), _, fail) *-> true
    ;   catch(le_kbs:call(G), _, fail) *-> true
    ;   SM:call(G)
    ).
call_reasoner_built_in(le_at(G, _, _), SM) :- !, call_reasoner_built_in(G, SM).
call_reasoner_built_in(le_known(X), _) :- !, ground(X).
call_reasoner_built_in(le_equal_to(X, Y), _) :- !, X = Y.
call_reasoner_built_in(le_not_equal_to(X, Y), _) :- !, X \= Y.
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
