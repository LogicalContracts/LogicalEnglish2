/** <module> Logical English Reasoner
    
    This module implements a meta-interpreter for Logical English (LE).
    It handles conjunctions, disjunctions, negation as failure, aggregates,
    and conditional answers (Unknowns). It constructs success and failure
    explanation trees.
*/

:- module(reasoner, [i/4, explain/4, is_built_in/1, solve/8,
                     hide_repeated_explanations/0, set_show_repeated_explanations/1]).

:- use_module(library(time)).
:- use_module(library(pairs)).

:- dynamic equal_to/2.
:- thread_local called/3, called_clause/3, counter/1, success_in_not/2, succeeded/1, solved_binding/2.

% When set (the default), repeated sub-explanations are collapsed; the client can
% turn this off per query so the full tree is built and shown. Tracked per worker
% thread, alongside the query it belongs to (set in classic_web_api before the
% query runs). Absent flag = hide (the default).
:- thread_local show_repeated_explanations/0.

%!  hide_repeated_explanations is semidet.
%   True when repeated sub-explanations should be collapsed (the default).
hide_repeated_explanations :- \+ show_repeated_explanations.

%!  set_show_repeated_explanations(+Show) is det.
%   Records the client's preference for the current query thread: Show == true
%   keeps every repeated sub-explanation; anything else hides them (the default).
set_show_repeated_explanations(Show) :-
    retractall(show_repeated_explanations),
    ( Show == true -> assertz(show_repeated_explanations) ; true ).

%!  i(+Goal:term, +SessionModule:atom, -Unknowns:list, -Whys:list) is nondet.
i(Goal, SessionModule, Unknowns, Whys) :-
    retractall(called(_, _, _)),
    retractall(called_clause(_, _, _)),
    retractall(success_in_not(_, _)),
    retractall(succeeded(_)),
    retractall(solved_binding(_, _)),
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
            % One assumption reached through several branches of the proof (the
            % same unclassified receipt feeding two sums, say) is one assumption
            % to the caller, and reads as one line in a list of what is missing.
            remove_variant_duplicates(Unknowns0, Unknowns)
        ),
        le_kbs:clear_kb_module
    ).


%!  explain(+Goal:term, +SessionModule:atom, -Unknowns:list, -Whys:list) is nondet.
%
%   Similar to i/4, but always returns an explanation tree (success or failure).
explain(Goal, SessionModule, Unknowns, Whys) :-
    retractall(called(_, _, _)),
    retractall(called_clause(_, _, _)),
    retractall(success_in_not(_, _)),
    retractall(succeeded(_)),
    retractall(solved_binding(_, _)),
    init_counter,
    ( SessionModule:le_kb_module_fact(KBmodule) ->  true; KBmodule = none),
    setup_call_cleanup(
        le_kbs:set_kb_module(KBmodule),
        (   solve(Goal, SessionModule, KBmodule, [], 0, 0, Unknowns0, Whys),
            \+ (
                member(U, Unknowns0),
                solve(U, SessionModule, KBmodule, [], 0, none, [], _)
            ) ->
            remove_variant_duplicates(Unknowns0, Unknowns)
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
            % Soft cut (*->) so backtracking into alternative solutions is preserved
            % while tracing: the exit port fires for EACH solution, so a user can step
            % through every answer, not only the first. (A plain -> would commit to the
            % first solution and make only the first answer traceable.)
            (   catch(solve_real(G, SM, KM, Anc, D, MyID, Us, Whys), E,
                      (dap_server:dap_tracer_hook(exception(E), SM, G, MyID, Anc, D), throw(E)))
            *-> (succeeded(MyID) -> true ; assertz(succeeded(MyID))),
                note_solved(MyID, G),
                dap_server:dap_tracer_hook(exit, SM, G, MyID, Anc, D)
            ;   dap_server:dap_tracer_hook(fail, SM, G, MyID, Anc, D),
                fail
            )
        ;   solve_real(G, SM, KM, Anc, D, MyID, Us, Whys),
            (succeeded(MyID) -> true ; assertz(succeeded(MyID))),
            note_solved(MyID, G)
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
% A term contributes to the aggregate whenever the aggregation goal holds for it,
% INCLUDING when it holds only by assuming some unknowns — exactly as an ordinary
% conjunct does. Those unknowns are returned in Us, so the total is reported as
% the conditional answer it is instead of being silently certified: collecting
% only the definite solutions (as this used to) dropped the assumable ones from
% the sum AND returned no unknowns at all, so a caller reading "unknowns == []"
% as "certified" got a confident wrong total with no signal.
%
% The `\+ definitely_provable(...)` guard is the aggregate-level counterpart of
% the "definite proof wins" rule i/4 applies to whole answers (see i/4): a goal
% that is both stated and declared unknown is solvable twice — once as a fact,
% once by assumption — and without the guard the same term would be counted
% twice in the sum.
solve_real_actual(Aggregate, SM, KM, Anc, D, MyID, Us, [success(Aggregate, aggregate, WhysGoal)]) :-
    is_aggregate(Aggregate, Type, VarTerm, Goal, ResultTerm), !,
    D1 is D + 1,
    extract_var(VarTerm, Var),
    findall(agg(Var, Us1, Whys),
            ( solve(Goal, SM, KM, Anc, D1, MyID, Us1, Whys),
              \+ ( member(U, Us1), definitely_provable(U, SM, KM, D1) )
            ),
            Solutions),
    (   Solutions == [] ->
        % Goal failed, build failure tree for the goal
        % We need to ensure the failure is recorded under MyID
        next_id(GoalID),
        ( (MyID \== none, ground(Goal)) -> assertz(called(MyID, GoalID, Goal)); true),
        ( solve(Goal, SM, KM, Anc, D1, GoalID, [], _) -> true ; true ),
        build_failure_tree(GoalID, WhysGoal),
        List = [], Us = []
    ;   maplist(agg_value, Solutions, List),
        maplist(agg_whys, Solutions, WhysList),
        flatten(WhysList, WhysGoal),
        maplist(agg_unknowns, Solutions, UsLists),
        append(UsLists, Us0),
        remove_variant_duplicates(Us0, Us)
    ),
    apply_aggregate(Type, List, Result),
    extract_var(ResultTerm, Result).
% Forall
% The explanation states the universal once in the header (with its quantified
% variable free) and then enumerates the actual cases, pairing each instantiated
% condition with the consequent that holds for it:
%   for all cases in which <general Cond>   (success node — the universal holds)
%     for case <Cond for case 1>            (with that case's own derivation)
%     it is true that <Cons for case 1>     (with its derivation)
%     for case <Cond for case 2>
%     it is true that <Cons for case 2>
%     ...
% When no case matches, the universal is vacuously true and the single child is
% the condition's FAILURE branch (red) instead.
solve_real_actual(forall(Cond, Cons), SM, KM, Anc, D, MyID, Us,
        [success(for_all_cases(GeneralCond), universal, CaseChildren)]) :- !,
    D1 is D + 1,
    next_id(CondID),
    assertz(called(MyID, CondID, Cond)),
    % The condition with its universally-quantified variable(s) still free, for
    % the header line "for all cases in which <general condition>" (e.g. "a thing
    % belongs to family two"). Taken before the findall binds them per case.
    copy_term(Cond, GeneralCond0),
    unwrap_le_at(GeneralCond0, GeneralCond),
    % For every solution of the condition (WITH its bindings) the consequent must
    % hold for those same bindings. The consequent is solved INSIDE the findall
    % conjunction so that variables shared between Cond and Cons flow from each
    % condition case to the consequent. (Solving the consequent separately, after
    % a findall over Cond alone, would lose those bindings and merely check that
    % the consequent holds for *some* value — a bug that wrongly made e.g. "family
    % one is a subset of family two" true when Bob ∈ family one but Bob ∉ family two.)
    % Each ok case keeps the *instantiated* condition and consequent together with
    % their derivations, so the explanation can pair them up per case.
    % Keep the forall itself on the ancestor stack while its condition and
    % consequent are solved, so the "for all cases in which …" frame stays visible
    % in the debugger instead of vanishing while its sub-goals run.
    % A case whose condition holds only by ASSUMING an unknown is still a case:
    % its consequent is required exactly as a definite case's is, and whatever
    % it assumed is returned in Us. Skipping the consequent for such a case (as
    % this used to) claimed the universal held while a case that may well exist
    % went unchecked, and reported no unknown to say so — a confident answer
    % with no signal, the same defect that used to hide unknowns inside
    % aggregates.
    ForallAnc = [forall(Cond, Cons) | Anc],
    findall(Case,
        ( solve(Cond, SM, KM, ForallAnc, D1, CondID, UsC, WhysCond),
          \+ ( member(U, UsC), definitely_provable(U, SM, KM, D1) ),
          ( solve(Cons, SM, KM, ForallAnc, D1, MyID, UsK, WhysCons)
            -> append(UsC, UsK, UsCase),
               Case = ok(Cond, WhysCond, Cons, WhysCons, UsCase)
            ;  Case = consequent_failed )
        ),
        Cases),
    (   Cases == [] ->
            % Vacuously true: no matching cases. Explain the condition's FAILURE
            % so it renders as a (red) negative branch under the header.
            build_failure_tree(CondID, CondFailWhys),
            ( CondFailWhys = [CondWhy] -> true ; CondWhy = failure(Cond, CondFailWhys) ),
            CaseChildren = [CondWhy],
            Us = []
        ;   \+ memberchk(consequent_failed, Cases) ->
            % Consequent holds for every case: the universal holds. Render one
            % "for case <condition>" / "it is true that <consequent>" pair per
            % case (each carrying that instance's own derivation), and report the
            % assumptions the cases rested on.
            findall(Nodes, ( member(C, Cases), forall_case_nodes(C, Nodes) ), NodeLists),
            append(NodeLists, CaseChildren),
            findall(U, ( member(ok(_, _, _, _, UsCase), Cases), member(U, UsCase) ), Us0),
            remove_variant_duplicates(Us0, Us)
        ;   % Some case's consequent failed: the universal fails.
            fail
    ).

% Negation as Failure
solve_real_actual(not(Goal), SM, KM, Anc, D, MyID, Us, [success(not(Goal), negation, FailureTrees)]) :- !,
    D1 is D + 1,
    next_id(GoalID),
    assertz(called(MyID, GoalID, Goal)),
    % not(Goal) fails as soon as Goal succeeds AT ALL — whether definitely or only
    % by assuming some unknowns true. An assumable success still establishes Goal,
    % so its negation must fail (it is not merely "unknown"). We therefore
    % short-circuit on the first success of any kind, recording its why-tree (which
    % explains, in the surrounding failure explanation, why the negation failed).
    % Only if Goal has NO proof at all does not(Goal) succeed.
    (   catch(
            ( solve_real(Goal, SM, KM, Anc, D1, GoalID, _UsA, WhysA),
              throw('$goal_succeeded'(WhysA)) ),
            '$goal_succeeded'(SuccWhys),
            true )
    ->  % Goal succeeded (possibly only under assumptions): not(Goal) fails.
        assertz(success_in_not(GoalID, SuccWhys)),
        fail
    ;   % Goal has no proof at all: not(Goal) succeeds.
        Us = [],
        build_failure_tree(GoalID, FailureTrees),
        assertz(success_in_not(GoalID, FailureTrees))
    ).

% True
solve_real_actual(true, _, _, _, _, _, [], []) :- !.

% Type restriction on a variable: succeeds immediately, attaching a lazy
% constraint that fires once Arg is bound (mirrors check_args_compatibility).
solve_real_actual(le_type_check(Arg, Type), SM, KM, _Anc, _D, _MyID, [], [success(le_type_check(Arg, Type), built_in, [])]) :- !,
    when(nonvar(Arg), once(type_arg_ok(Arg, Type, SM, KM))).

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
                solve_rule_body(Body, SM, KM, [G|Anc], D1, MyID, Ref, Us, WhysBody),
                \+ ( get_clause(OppG, SM, KM, OppBody, OppRef),
                     OppRef \== implicit_opposite,
                     % Use a fresh Anc for OppBody to avoid loop but allow checking G
                     solve(OppBody, SM, KM, [OppG], D1, MyID, [], _)
                   )
            ;   solve_rule_body(Body, SM, KM, [G|Anc], D1, MyID, Ref, Us, WhysBody)
            )
        ; get_clause(le_unknown(G), SM, KM, UnkBody, _UnkRef),
          \+ SM:le_neg(le_unknown(G)),
          \+ member(le_unknown(G), Anc),
          D1 is D + 1,
          solve(UnkBody, SM, KM, [le_unknown(G)|Anc], D1, MyID, [], _) ->  
            Us = [G], WhysBody = [], Ref = unknown
    ).

% One solution of an aggregation goal: the aggregated value, the unknowns that
% solution assumed, and its derivation.
agg_value(agg(V, _, _), V).
agg_unknowns(agg(_, Us, _), Us).
agg_whys(agg(_, _, Whys), Whys).

%!  remove_variant_duplicates(+Us0:list, -Us:list) is det.
%
%   Us0 without repeats, first occurrence kept. One assumption relied on by
%   several aggregated terms — a single unclassified receipt feeding two sums —
%   is reported once. sort/2 would do it, but it would also reorder the list;
%   unknowns read best in the order the proof met them.
remove_variant_duplicates([], []).
remove_variant_duplicates([U|Us0], [U|Us]) :-
    exclude(=@=(U), Us0, Rest),
    remove_variant_duplicates(Rest, Us).

%!  definitely_provable(+Goal, +SM, +KM, +D) is semidet.
%
%   True when Goal has a proof that assumes nothing. Used to discard an
%   assumption-based solution when the same goal is also established outright
%   (the "definite proof wins" rule, applied per aggregated term).
definitely_provable(Goal, SM, KM, D) :-
    \+ \+ solve(Goal, SM, KM, [], D, none, [], _).

% forall_case_nodes(+Case, -Nodes): explanation nodes for one universal case — a
% "for case <condition>" node and an "it is true that <consequent>" node, each
% carrying that instance's derivation. A case that rests on an assumption is not
% a separate node shape: the assumed literal already sits in the condition's own
% derivation with an `unknown` ref, which is what marks it as assumed.
forall_case_nodes(ok(Cond, WhysCond, Cons, WhysCons, _Us),
        [success(for_case(CondGoal), CondRef, CondChildren),
         success(it_is_true_that(ConsGoal), ConsRef, ConsChildren)]) :-
    unwrap_le_at(Cond, CondGoal),
    unwrap_le_at(Cons, ConsGoal),
    case_proof(WhysCond, CondRef, CondChildren),
    case_proof(WhysCons, ConsRef, ConsChildren).

unwrap_le_at(le_at(G, _, _), G) :- !.
unwrap_le_at(G, G).

% case_proof(+Whys, -Ref, -Children): how to attach a single case's derivation to
% its "for case"/"it is true that" node. When the derivation is a single node, the
% node already restates the instance, so lift its source ref and children (a plain
% fact then shows as just the one line); otherwise keep the derivation as children.
case_proof([success(_, Ref, GrandChildren)], Ref, GrandChildren) :- !.
case_proof(Whys, universal_case, Whys).

% Both lookups go through the functor indexes (le_dict_fa/3, le_dict_opposite/3
% — see assert_le_dict/3 in le_kbs): every le_dict/1 clause carries the same
% first-argument key, so asking it for one template used to walk the whole
% templates section, once per literal the verifier checks.
has_opposite(G, SM, KM, OppG) :-
    ( KM \== none -> M = KM ; M = SM ),
    functor(G, F, A),
    (   dict_by_functor(M, F, A, dict([F|Args], _, _, _, Opposite, _, _)), nonvar(Opposite) ->
        % G is the main predicate
        G =.. [F | GArgs],
        copy_term(dict(Args, Opposite), dict(GArgs, OppG))
    ;   dict_by_opposite(M, F, A, dict(FA, _, _, _, Opposite, _, _)), nonvar(Opposite) ->
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
    findall(FormalArgs-NTs, candidate_dict(M, F, N, FormalArgs, NTs), Candidates),
    (   Candidates == [] -> true
    ;   G =.. [F|ActualArgs],
        args_compatible_any(Candidates, ActualArgs, M, SM, KM)
    ).

% candidate_dict(+M, +F, +N, -FormalArgs, -NTs): every declared template whose
% predicate is F/N. Both the full dict/7 and the short dict/3 form are searched,
% as before.
candidate_dict(M, F, N, FormalArgs, NTs) :-
    (   dict_by_functor(M, F, N, dict([F|FormalArgs], NTs, _, _, _, _, _))
    ;   dict_by_functor(M, F, N, dict([F|FormalArgs], NTs, _))
    ).

%!  dict_by_functor(+M, +F, +A, ?Dict) is nondet.
%!  dict_by_opposite(+M, +F, +A, ?Dict) is nondet.
%
%   Templates by the predicate they declare, and by the predicate their
%   `opposite:` declares. The indexes are written when the template is asserted
%   (assert_le_dict/3); a KB loaded before they existed — or by a path that
%   never built them — falls back to the scan, so nothing depends on them
%   being there.
dict_by_functor(M, F, A, Dict) :-
    (   current_predicate(M:le_dict_fa/3)
    ->  M:le_dict_fa(F, A, Dict)
    ;   M:le_dict(Dict), arg(1, Dict, [F|Args]), length(Args, A)
    ).

dict_by_opposite(M, F, A, Dict) :-
    (   current_predicate(M:le_dict_opposite/3)
    ->  M:le_dict_opposite(F, A, Dict)
    ;   M:le_dict(Dict), Dict = dict(_, _, _, _, Opposite, _, _),
        nonvar(Opposite), functor(Opposite, F, A)
    ).

%!  args_compatible_any(+Candidates, +ActualArgs, +M, +SM, +KM) is semidet.
%
%   Several templates can share one functor and arity with DIFFERENT argument
%   types — "*a payment* is part of *a claim*" and "*a loss* is part of *a
%   claim*" both compile to is_part_of/2. Committing to the first declared one
%   (as this used to) silently made every other unusable: a scenario fact stated
%   through the second template was rejected by the first template's types, so a
%   fact sitting right there in the session could not be proved. The goal is
%   acceptable if ANY declared template accepts it.
%
%   With one candidate nothing changes — the per-argument `when(nonvar(...))`
%   checks are attached exactly as before, so an argument is constrained the
%   moment it binds. A disjunction cannot be decided argument by argument, so
%   with several candidates the whole check waits until the arguments are
%   ground and then tries each template in turn. That defers rejection rather
%   than tightening it, which matches the deliberate leniency of this check.
args_compatible_any([FormalArgs-NTs], ActualArgs, M, SM, KM) :- !,
    check_args_compatibility(FormalArgs, ActualArgs, NTs, M, SM, KM).
args_compatible_any(Candidates, ActualArgs, M, SM, KM) :-
    when(ground(ActualArgs),
         once(( member(FormalArgs-NTs, Candidates),
                check_args_compatibility(FormalArgs, ActualArgs, NTs, M, SM, KM) ))).

check_args_compatibility([], [], _, _, _, _).
check_args_compatibility([FA|FAs], [AA|AAs], NTs, M, SM, KM) :-
    ( member(FA_-FormalType, NTs), FA_==FA, FormalType \== any ->
        % Goal-level check: lenient — only constrains TYPE-valued arguments (for
        % taxonomy reasoning). Instance arguments are NOT constrained here, since
        % this fires for every goal and an instance may legitimately fill a role
        % slot (e.g. a company acting as an 'affiliate'). Per-rule discrimination
        % between same-functor templates is done by the head le_type_check goals
        % at ambiguous positions (see head_var_type_checks/4 in le_grammar).
        when(nonvar(AA), once(type_value_ok(AA, FormalType, SM, KM)))
    ; true
    ),
    check_args_compatibility(FAs, AAs, NTs, M, SM, KM).

% Like type_arg_ok/4 but only constrains TYPE-valued arguments (no instances).
type_value_ok(_AA, any, _SM, _KM) :- !.
type_value_ok(_AA, FormalType, _SM, _KM) :- universal_type(FormalType), !.
type_value_ok(AA, FormalType, SM, KM) :-
    ( is_type_value(AA, SM, KM), grounded_type(FormalType, SM, KM)
    -> type_compatible(AA, FormalType, SM, KM)
    ; true
    ).

%!  type_arg_ok(+Arg, +FormalType, +SM, +KM) is semidet.
%
%   True when the bound Arg is acceptable in a slot declared as FormalType. It is
%   lenient by design — it only REJECTS on a clear conflict:
%    * universal types (thing/object/…) and 'any' accept anything;
%    * if Arg is itself a TYPE, require it to be a sub-type of FormalType, but
%      only when FormalType is grounded (so a generic placeholder type like
%      *super* in "*sub* isa *super*" does not reject a real type value);
%    * if Arg is an INSTANCE with a known type (an is_a fact, e.g.
%      "this payment is a payment"), require it to be of type FormalType — so a
%      payment is rejected for an 'amount' slot;
%    * otherwise (no known type) accept.
type_arg_ok(_Arg, any, _SM, _KM) :- !.
type_arg_ok(_Arg, FormalType, _SM, _KM) :- universal_type(FormalType), !.
type_arg_ok(Arg, FormalType, SM, KM) :-
    (   is_type_value(Arg, SM, KM)
    ->  ( grounded_type(FormalType, SM, KM) -> type_compatible(Arg, FormalType, SM, KM) ; true )
    ;   instance_has_type(Arg, SM, KM)
    ->  type_compatible(Arg, FormalType, SM, KM)
    ;   true
    ).

universal_type(T) :- memberchk(T, [thing, object, entity, asset, element]).

is_type_value(Arg, SM, KM) :-
    ( catch(SM:le_type(Arg), _, fail) -> true
    ; KM \== none, catch(KM:le_type(Arg), _, fail)
    ).

instance_has_type(Arg, SM, KM) :-
    ( has_is_a_fact(SM, Arg) -> true
    ; KM \== none, has_is_a_fact(KM, Arg)
    ).

has_is_a_fact(Mod, Arg) :-
    current_predicate(Mod:is_a/2),
    catch(clause(Mod:is_a(Arg, _), true), _, fail).

% Arg satisfies FormalType via is_a facts in either the session or the KB module.
type_compatible(Arg, FormalType, SM, KM) :-
    ( is_a_simple(Arg, FormalType, SM) -> true
    ; KM \== none, is_a_simple(Arg, FormalType, KM)
    ).

% grounded_type(+Type, +SM, +KM): Type actually participates in the ontology —
% something is a Type, or Type is a something — in the session or KB module.
grounded_type(Type, SM, KM) :-
    ( has_is_a_edge(SM, Type) -> true
    ; KM \== none, has_is_a_edge(KM, Type) -> true
    ).

has_is_a_edge(Mod, Type) :-
    current_predicate(Mod:is_a/2),
    ( catch(clause(Mod:is_a(_, Type), _), _, fail) -> true
    ; catch(clause(Mod:is_a(Type, _), _), _, fail)
    ).

is_a_simple(X, Z, _) :- X == Z, !.
is_a_simple(X, Z, M) :- M:clause(is_a(X, Z), true), !.
is_a_simple(X, Z, M) :- M:clause(is_a(X, Y), true), Y \== Z, is_a_simple(Y, Z, M).
% A qualified/named type ("first person", "person X") is satisfied by its
% head-noun type ("person"), so that *a first person* and *a second person* are
% accepted as values of type person.
is_a_simple(X, Z, M) :- atom(Z), le_grammar:head_noun_type(Z, HZ), HZ \== Z, is_a_simple(X, HZ, M).

%!  detailed_failures_on(+SM) is semidet.
%   True when the session has requested detailed (per-rule) failure explanations.
detailed_failures_on(SM) :- catch(SM:detailed_failures, _, fail).

%!  solve_rule_body(+Body, +SM, +KM, +Anc, +D, +MyID, +Ref, -Us, -WhysBody)
%   Solves the body of a clause Ref under goal MyID. When detailed failures are
%   enabled and Body is a real rule body (not a fact's `true`), the body's
%   subgoals are solved under a FRESH clause id, recorded as
%   called_clause(MyID, ClauseID, Ref), so build_failure_tree/2 can group the
%   subgoal failures under a "failed rule" node. Otherwise (default) the body is
%   solved directly under MyID, exactly as before.
solve_rule_body(Body, SM, KM, Anc, D, MyID, Ref, Us, WhysBody) :-
    (   Body \== true, detailed_failures_on(SM)
    ->  next_id(ClauseID),
        assertz(called_clause(MyID, ClauseID, Ref)),
        solve(Body, SM, KM, Anc, D, ClauseID, Us, WhysBody)
    ;   solve(Body, SM, KM, Anc, D, MyID, Us, WhysBody)
    ).

% build_failure_tree(+ID, -Whys)
% Reconstructs a list of "juicy" failure trees of all calls made under ID. When
% detailed failures are enabled, each attempted rule body recorded via
% called_clause/3 becomes an intermediate failed_rule(Ref, BodyWhys) node — but a
% predicate with a single rule keeps its subgoal failures directly (no rule node).
build_failure_tree(ID, Whys) :-
    (   success_in_not(ID, Whys) -> true
    ;   succeeded(ID) -> Whys = []
    ;   failure_children(ID, AllWhys),
        (   called(_PID, ID, Term)
        ->  (   (AllWhys = [failure(Term2, Children)], variant_or_le_at_variant(Term, Term2))
            ->  Whys = [failure(Term, Children)] % Collapse pass-through
            ;   Whys = [failure(Term, AllWhys)]
            )
        ;   Whys = AllWhys
        )
    ).

%!  failure_children(+ID, -AllWhys)
%
%   The failure subtrees of the calls made under ID: per-rule failure nodes
%   (only present when detailed failures are on) plus the direct subgoal
%   failures (the default path, and non-rule calls). Shared by
%   build_failure_tree/2 and the choice-point display below.
failure_children(ID, AllWhys) :-
    findall(failed_rule(Ref, ClauseWhys),
            ( called_clause(ID, ClauseID, Ref),
              clause_failure_children(ClauseID, ClauseWhys) ),
            RuleNodes),
    clause_failure_children(ID, DirectWhys),
    combine_clause_children(RuleNodes, DirectWhys, AllWhys).

% Collect and group the failure subtrees of the calls made directly under ID.
clause_failure_children(ID, Grouped) :-
    ( findall(W, ( called(ID, CID, Goal), child_failure_or_choice(CID, Goal, W) ), Whys0) -> true ; Whys0 = [] ),
    group_variant_whys(Whys0, Grouped).

% child_failure_or_choice(+CID, +Goal, -Why): how a child call CID (Goal recorded
% at call time, so its groundness is the call-time groundness) contributes to its
% parent's failure explanation:
%  - a FAILED child contributes its own failure subtree;
%  - a child that SUCCEEDED but whose call was NON-GROUND is a choice point that
%    may have other solutions, each potentially explaining the failure, so the
%    succeeded condition itself is shown — together with WHY it could produce
%    no other solution (see choice_failure_children/2);
%  - a GROUND success is deterministic and irrelevant to the failure — omitted.
child_failure_or_choice(CID, _Goal, W) :-
    \+ succeeded(CID), !,
    build_failure_tree(CID, Ws), member(W, Ws).
child_failure_or_choice(CID, le_at(G, S, E), success(GShown, range(S, E), Kids)) :-
    succeeded(CID), \+ ground(G), !,
    choice_binding(CID, le_at(G, S, E), le_at(GShown, _, _)),
    choice_failure_children(CID, Kids).
child_failure_or_choice(CID, Goal, success(GShown, nonground_success, Kids)) :-
    succeeded(CID), \+ ground(Goal),
    choice_binding(CID, Goal, GShown),
    choice_failure_children(CID, Kids).

%!  choice_failure_children(+CID, -Kids)
%
%   Why the succeeded choice point CID yielded no OTHER solution: the failure
%   subtrees of its exhausted alternative branches — the ones backtracked into
%   after a later condition failed. Those branches' own succeeded-but-non-ground
%   conditions are shown too (the bindings they committed to are what made the
%   later goals fail), while their ground successes stay omitted as usual.
%   Without this, a failure explanation stopped at the bare succeeded choice
%   ("we will make previous payment") and never showed the candidate rule whose
%   near-miss — e.g. one retracted scenario fact — is the real story.
choice_failure_children(CID, Kids) :-
    failure_children(CID, Kids).

% note_solved(+CID, +Goal): snapshot a subgoal's bindings AT SUCCESS time. The
% call-time record (called/3) freezes a choice point before unification fills it
% in (e.g. "a creature is a parent of bob"); this captures the solved form (e.g.
% "alice is a parent of bob") so a failure explanation can show the binding the
% explored path actually used. Stored per distinct solution.
note_solved(CID, Goal) :-
    ( solved_binding(CID, Existing), Existing =@= Goal
    -> true
    ;  assertz(solved_binding(CID, Goal)) ).

% choice_binding(+CID, +CallGoal, -Shown): if the succeeded choice point had a
% UNIQUE solution on the explored path, show it with that binding; otherwise keep
% the call-time (non-ground) form, so a multi-solution choice still reads
% generally rather than committing to one arbitrary witness.
choice_binding(CID, CallGoal, Shown) :-
    ( findall(B, solved_binding(CID, B), Bindings), Bindings = [Unique]
    -> Shown = Unique
    ;  Shown = CallGoal ).

% combine_clause_children(+RuleNodes, +DirectWhys, -AllWhys)
% No rule nodes -> just the direct failures. A SINGLE rule -> drop the rule node
% and surface its subgoal failures directly. Several rules -> keep one
% failed_rule node per rule.
combine_clause_children([], DirectWhys, DirectWhys) :- !.
combine_clause_children([failed_rule(_Ref, ClauseWhys)], DirectWhys, AllWhys) :- !,
    append(ClauseWhys, DirectWhys, AllWhys).
combine_clause_children(RuleNodes, DirectWhys, AllWhys) :-
    append(RuleNodes, DirectWhys, AllWhys).

% group_variant_whys(+Whys, -Grouped)
% Collapses sibling sub-explanations that are variants of each other (same shape
% modulo variable renaming) into a single representative, wrapped as
% repeated_group(Count, Why) when Count > 1. This both shrinks the failure tree
% at the source (so the expensive downstream passes — postprocess_why/2,
% convert_why/3, rendering — operate on a small tree) and records how many times
% each sub-explanation occurred under the same parent.
group_variant_whys(Whys, Grouped) :-
    (   hide_repeated_explanations
    ->  maplist(variant_key_pair, Whys, Keyed),
        group_keyed_whys(Keyed, Grouped)
    ;   Grouped = Whys
    ).

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
is_built_in(le_minimum(_, _, _)).
is_built_in(le_maximum(_, _, _)).
is_built_in(le_is_in(_, _)).
is_built_in(equal_to(_, _)).

call_reasoner_built_in(prolog_call(G), SM) :- !,
    % Every `prolog` body goal must pass library(sandbox)'s safe_goal/1 before
    % running (flag le_sandbox_prolog, default true): together with the
    % assert-only loading of included .pl resources this is what makes remote
    % Prolog inclusion safe. LE's own metadata predicates are declared safe
    % below; a goal whose analysis needs bindings not yet available (the
    % dynamic-module idiom "le_my_kb(KM), KM:le_kb(X)") is allowed through and
    % its module-qualified part is checked at call time, when KM is bound.
    %
    % Resolve the goal in the first module context that yields a solution and
    % commit to it (soft-cut), so we don't re-enumerate the same solutions in
    % each fallback context (which would return duplicate answers).
    % Only catch "predicate not defined in this module" so we can fall through to
    % the next module context. Other exceptions — including the user's query
    % interrupt and time limits — MUST propagate, not be swallowed (which would
    % otherwise restart a looping goal in the next context).
    (   compound(G), G = M:Goal
    ->  check_safe_prolog(M:Goal),
        M:call(Goal)
    ;   check_safe_prolog(SM:G),
        (   catch(SM:call(G), error(existence_error(procedure, _), _), fail) *-> true
        ;   catch(le_kbs:call(G), error(existence_error(procedure, _), _), fail) *-> true
        ;   SM:call(G)
        )
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
call_reasoner_built_in(le_minimum(X, Y, Z), _) :- !, le_minimum(X, Y, Z).
call_reasoner_built_in(le_maximum(X, Y, Z), _) :- !, le_maximum(X, Y, Z).
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

%!  le_minimum(+X, +Y, -Z) is semidet.
%!  le_maximum(+X, +Y, -Z) is semidet.
%
%   "the minimum of *a number* and *an other number* is *a third number*" —
%   the smaller (larger) of two numbers. Least of / greater of is everywhere in
%   insurance and finance wording (a limit against a repair cost, an excess
%   against a loss), and without a template for it models write `Z = min(X, Y)`
%   — which is not an LE expression and dies at run time with "min(A,B)/0 is
%   not a function". Both arguments must be numbers; the result is compared
%   when it is already bound, so the goal can also be used as a test.
le_minimum(X, Y, Z) :-
    number(X), number(Y),
    M is min(X, Y),
    ( var(Z) -> Z = M ; number(Z), Z =:= M ).

le_maximum(X, Y, Z) :-
    number(X), number(Y),
    M is max(X, Y),
    ( var(Z) -> Z = M ; number(Z), Z =:= M ).

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

% ── Sandboxing of `prolog` body goals ────────────────────────────────────────

:- use_module(library(sandbox), []).

:- dynamic safe_prolog_cached/1.

%!  check_safe_prolog(+Goal) is det.
%
%   Throws error(le_unsafe_prolog_goal(G), ...) when library(sandbox) rejects
%   the goal; succeeds otherwise. Verdicts are cached per goal skeleton.
%   An instantiation error from the ANALYSIS (a module or goal part unknown
%   until run time) lets the goal through: its qualified sub-goals are checked
%   again, bound, when they reach the M:Goal branch above.
check_safe_prolog(_) :-
    current_prolog_flag(le_sandbox_prolog, false), !.
check_safe_prolog(Goal) :-
    goal_skeleton(Goal, Skel),
    ( safe_prolog_cached(Skel) -> true
    ; catch(le_safe_goal(Goal), Error, true),
      (   var(Error)
      ->  assertz(safe_prolog_cached(Skel))
      ;   Error = error(instantiation_error, _)
      ->  true                       % analysable only at run time
      ;   Error = error(existence_error(procedure, _), _)
      ->  true                       % undefined here: execution will raise it properly
      ;   term_string(Error, ES),
          format(atom(Msg), "prolog goal blocked by the sandbox: ~w (~w). Set the le_sandbox_prolog flag to false only on fully trusted installations.", [Goal, ES]),
          throw(error(le_unsafe_prolog_goal(Goal), context(reasoner, Msg)))
      )
    ).

goal_skeleton(Goal, Skel) :-
    copy_term(Goal, C, _),      % /3 strips attributes (LE vars carry 'when')
    numbervars(C, 0, _),
    variant_sha1(C, Skel).

% Structural pre-check: recurse over control constructs and module
% qualifications ourselves, approve LE's metadata predicates by functor (they
% are read-only lookups, legitimately called against dynamic modules — a shape
% sandbox's static declarations cannot express), and hand every other leaf to
% sandbox:safe_goal/1.
le_safe_goal(G) :- var(G), !, throw(error(instantiation_error, _)).
le_safe_goal(_:G) :- !, le_safe_goal(G).
le_safe_goal((A, B)) :- !, le_safe_goal(A), le_safe_goal(B).
le_safe_goal((A ; B)) :- !, le_safe_goal(A), le_safe_goal(B).
le_safe_goal((A -> B)) :- !, le_safe_goal(A), le_safe_goal(B).
le_safe_goal((A *-> B)) :- !, le_safe_goal(A), le_safe_goal(B).
le_safe_goal(\+ A) :- !, le_safe_goal(A).
le_safe_goal(G) :-
    functor(G, F, A),
    le_metadata_predicate(F/A), !.
le_safe_goal(G) :-
    sandbox:safe_goal(G).

% Read-only LE metadata lookups, callable from `prolog` bodies against any
% KB/session module.
le_metadata_predicate(le_my_kb/1).
le_metadata_predicate(le_my_id/1).
le_metadata_predicate(le_kb/1).
le_metadata_predicate(le_dict/1).
le_metadata_predicate(le_type/1).
le_metadata_predicate(is_a/2).
le_metadata_predicate(le_source_element/3).
le_metadata_predicate(le_source_info/4).
le_metadata_predicate(le_source_section/2).
le_metadata_predicate(le_target_language/1).
le_metadata_predicate(scenario/2).
le_metadata_predicate(query_info/3).
le_metadata_predicate(le_expected/4).
