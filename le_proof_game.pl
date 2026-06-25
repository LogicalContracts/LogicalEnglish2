:- module(le_proof_game, [
    extract_rules_and_facts/6,
    unify_game_nodes/5,
    game_var_ids/2
]).

:- use_module(le_kbs).
:- use_module(le_grammar).

% Fallback counter for the SM == none case (e.g. tests); thread_local so it
% stays thread-safe. For real sessions the counter is stored in the SM module.
:- thread_local game_node_counter/1.

%!  extract_rules_and_facts(+KB, +SM, +Query, -Rules, -Facts, -QueryTokens) is det.
extract_rules_and_facts(KB, SM, Query, Rules, Facts, QueryTokens) :-
    ( SM \== none -> dynamic(SM:game_node_term/3), retractall(SM:game_node_term(_,_,_)) ; true ),
    counter_module(SM, CounterM),
    ( CounterM \== le_proof_game -> dynamic(CounterM:game_node_counter/1) ; true ),
    retractall(CounterM:game_node_counter(_)),
    assertz(CounterM:game_node_counter(0)),
    findall(RuleDict, (
        current_predicate(KB:F/N),
        \+ le_kbs:is_system_predicate(F/N),
        functor(Head, F, N),
        clause(KB:Head, Body, Ref),
        KB:le_source_info(Ref, Start, End, ID),
        \+ member(ID, [template, template_unknown, ontology, session_fact]),
        Body \== true,
        comma_list(Body, BodyList),
        flatten_body(BodyList, FlatBodyList),
        next_game_node_id(SM, rule, NodeId),
        game_var_ids((Head :- FlatBodyList), VarIds),
        % Variable-name map keyed by the variable ITSELF (not its term_variables
        % index): once a variable binds to a constant it leaves term_variables and
        % the indices shift, so an index-keyed map would mislabel the survivors
        % after unification. The variables are shared with Head/Body, so they copy
        % together in build_proof_fragment and stay aligned.
        ( KB \== none, KB:le_var_names(ID, IdxNames) ->
            term_variables((Head :- FlatBodyList), AllVars),
            idx_names_to_var_names(IdxNames, AllVars, NameMap)
        ; NameMap = [] ),
        literal_to_game(KB, Head, VarIds, NameMap, [], Seen1, HeadLE, HeadTokens),
        body_list_to_game(KB, FlatBodyList, VarIds, NameMap, Seen1, _SeenN, BodyLEs, BodyTokensList),
        findall(I, (nth0(I, FlatBodyList, Cond), is_naf_condition(Cond)), NafIndices),
        % For each "for all cases in which <Cond> it is the case that <Cons>" body
        % condition, expose its two sub-conditions so the UI can offer a separate
        % link target (sub-socket) for each (sub 0 = Cond, sub 1 = Cons).
        forall_meta_list(KB, FlatBodyList, VarIds, NameMap, ForallMeta),
        % Per-body-condition source ranges, so the (explanation-driven) Show Proof
        % and the failure-mode validation can match an explanation node to the
        % exact body condition it came from. For a NAF condition, also the range of
        % the negated (inner) goal.
        body_ranges(FlatBodyList, BodyRanges),
        ( SM \== none ->
            % Carry the rule's variable-name map so re-rendering (render_instances,
            % after unification) shows the author's names too, not just the initial
            % extract here.
            assertz(SM:game_node_term(NodeId, rule, term(Head, FlatBodyList, VarIds, NameMap)))
        ; true ),
        RuleDict = _{ id: NodeId, head: HeadLE, headTokens: HeadTokens,
                      body: BodyLEs, bodyTokens: BodyTokensList,
                      bodyNaf: NafIndices, bodyForall: ForallMeta,
                      bodyRanges: BodyRanges,
                      start: Start, end: End }
    ), Rules),
    findall(FactDict, (
        (   current_predicate(KB:F/N),
            \+ le_kbs:is_system_predicate(F/N),
            functor(Head, F, N),
            clause(KB:Head, true, Ref),
            KB:le_source_info(Ref, Start, End, ID),
            \+ member(ID, [template, template_unknown, ontology, session_fact])
        ;   SM \== none,
            current_predicate(SM:F/N),
            \+ le_kbs:is_system_predicate(F/N),
            functor(Head, F, N),
            clause(SM:Head, true, Ref),
            SM:le_source_info(Ref, Start, End, session_fact)
        ),
        next_game_node_id(SM, fact, NodeId),
        game_var_ids(Head, VarIds),
        literal_to_game(KB, Head, VarIds, [], [], _Seen, FactLE, FactTokens),
        ( SM \== none ->
            assertz(SM:game_node_term(NodeId, fact, term(Head, [], VarIds, [])))
        ; true ),
        FactDict = _{ id: NodeId, fact: FactLE, factTokens: FactTokens,
                      start: Start, end: End }
    ), Facts),
    ( SM \== none ->
        game_var_ids(Query, QVarIds),
        assertz(SM:game_node_term(query, query, term(Query, [Query], QVarIds, [])))
    ; true ),
    ( KB \== none ->
        game_var_ids(Query, QVarIds2),
        literal_to_game(KB, Query, QVarIds2, [], [], _Seen2, _QueryLE, QueryTokens)
    ; QueryTokens = [_{kind: "word", text: Query}] ).

%!  unify_game_nodes(+KB, +SM, +NodeSpecs, +Edges, -Response) is det.
unify_game_nodes(KB, SM, NodeSpecs, Edges, Response) :-
    (   catch(
            build_proof_fragment(SM, NodeSpecs, Instances),
            _Err, fail)
    ->  (   apply_edges(Instances, Edges)
        ->  render_instances(KB, Instances, NodeResults),
            Response = _{ status: "ok", nodes: NodeResults }
        ;   Response = _{ status: "clash" }
        )
    ;   Response = _{ status: "error", error: "Unknown node template" }
    ).

% --- Internal Helpers ---

next_game_node_id(SM, Kind, NodeId) :-
    counter_module(SM, M),
    retract(M:game_node_counter(N)),
    N1 is N + 1,
    assertz(M:game_node_counter(N1)),
    format(atom(NodeId), "~w_~w", [Kind, N]).

% Module holding the per-session node counter fact. Real sessions store it in
% the session module SM; the SM == none case falls back to this module's
% thread_local fact.
counter_module(none, le_proof_game) :- !.
counter_module(SM, SM).

game_var_ids(Term, VarIds) :-
    term_variables(Term, Vars),
    number_var_ids(Vars, 0, VarIds).

number_var_ids([], _, []).
number_var_ids([V|Vs], N, [N-V|T]) :-
    N1 is N + 1,
    number_var_ids(Vs, N1, T).

literal_to_game(KB, Literal, VarIds, NameMap, SeenIn, SeenOut, LE, Tokens) :-
    ( KB \== none, item_to_typed_instance(KB, Literal, Tagged) ->
        tagged_tokens_to_game(KB, Tagged, VarIds, NameMap, SeenIn, SeenOut, Tokens),
        game_tokens_text(Tokens, LE)
    ;   term_string(Literal, LE), Tokens = [_{kind: "word", text: LE}], SeenOut = SeenIn
    ).

% body_ranges(+BodyList, -Ranges): a dict per body condition with its source
% range, plus (for a negation) the range of the negated inner goal — so an
% explanation node can be matched to the precise condition it derives from.
body_ranges(BodyList, Ranges) :-
    findall(R,
        ( nth0(I, BodyList, Cond),
          le_at_range(Cond, S, E),
          ( naf_inner_range(Cond, IS, IE)
            -> R = _{ index: I, start: S, end: E, innerStart: IS, innerEnd: IE }
            ;  R = _{ index: I, start: S, end: E } )
        ), Ranges).

le_at_range(le_at(_, S, E), S, E) :- !.
le_at_range(_, 0, 0).

% naf_inner_range(+Cond, -S, -E): the source range of the negated goal G in an
% "it is not the case that G" condition.
naf_inner_range(le_at(C, _, _), S, E) :- !, naf_inner_range(C, S, E).
naf_inner_range(not(le_at(_, S, E)), S, E).

% forall_meta_list(+KB, +BodyList, +VarIds, +NameMap, -Meta): for each "for all
% cases in which <Cond> it is the case that <Cons>" body condition, a dict with
% its index and the rendered Cond/Cons (carrying whatever variable bindings are
% currently in effect, so the UI can show them once they get bound).
forall_meta_list(KB, BodyList, VarIds, NameMap, Meta) :-
    findall(_{ index: FI, condLE: CondLE, condTokens: CondToks,
               consLE: ConsLE, consTokens: ConsToks },
        (   nth0(FI, BodyList, ForallCond),
            strip_le_at(ForallCond, forall(ForallC, ForallK)),
            literal_to_game(KB, ForallC, VarIds, NameMap, [], _SF1, CondLE, CondToks),
            literal_to_game(KB, ForallK, VarIds, NameMap, [], _SF2, ConsLE, ConsToks)
        ), Meta).

body_list_to_game(_KB, [], _VarIds, _NameMap, Seen, Seen, [], []).
body_list_to_game(KB, [L|Ls], VarIds, NameMap, SeenIn, SeenOut, [LE|LEs], [Tokens|TokensT]) :-
    literal_to_game(KB, L, VarIds, NameMap, SeenIn, Seen1, LE, Tokens),
    body_list_to_game(KB, Ls, VarIds, NameMap, Seen1, SeenOut, LEs, TokensT).

build_proof_fragment(_SM, [], []).
build_proof_fragment(SM, [Spec|Specs], [inst(IId, Kind, Head, Body, NameMap)|Insts]) :-
    get_dict(instanceId, Spec, IIdVal), atom_string(IId, IIdVal),
    get_dict(templateId, Spec, TIdVal), atom_string(TId, TIdVal),
    (   TId == fail
    ->  % Generic FAIL node: represents negation-as-failure. It carries no head
        % or body; its only role is to satisfy a NAF body condition.
        Kind = fail, Head = fail, Body = [], NameMap = []
    ;   SM:game_node_term(TId, Kind, term(Head0, Body0, _VarIds, NameMap0)),
        % Copy the name map together with the head/body so its keys remain the very
        % same variables (binding-stable lookup by ==).
        copy_term(Head0-Body0-NameMap0, Head-Body-NameMap)
    ),
    build_proof_fragment(SM, Specs, Insts).

apply_edges(_Instances, []).
apply_edges(Instances, [Edge|Edges]) :-
    get_dict(child, Edge, ChildVal), atom_string(Child, ChildVal),
    get_dict(parent, Edge, ParentVal), atom_string(Parent, ParentVal),
    get_dict(bodyIndex, Edge, BodyIndex),
    ( get_dict(subIndex, Edge, SubVal), integer(SubVal) -> SubIndex = SubVal ; SubIndex = -1 ),
    member(inst(Child, ChildKind, ChildHead, _, _), Instances),
    member(inst(Parent, _, _, ParentBody, _), Instances),
    nth0(BodyIndex, ParentBody, ParentCond),
    target_condition(ParentCond, SubIndex, Target),
    satisfy_condition(ChildKind, ChildHead, Target),
    apply_edges(Instances, Edges).

% target_condition(+Cond, +SubIndex, -Target): for a "for all cases" condition,
% pick the sub-goal addressed by SubIndex (0 = the "for all cases in which ..."
% condition, 1 = the "it is the case that ..." consequence); otherwise the whole
% condition.
target_condition(Cond0, SubIndex, Target) :-
    (   SubIndex >= 0, strip_le_at(Cond0, forall(CondPart, ConsPart))
    ->  ( SubIndex =:= 0 -> Target = CondPart ; Target = ConsPart )
    ;   Target = Cond0
    ).

% satisfy_condition(+ChildKind, +ChildHead, +Target):
%  - a FAIL node satisfies a negation ("it is not the case that ...");
%  - a rule/fact head satisfies a positive condition by unifying with it, or a
%    negation by unifying with its negated (inner) goal — a "not the case" link.
satisfy_condition(fail, _, Target) :- !, is_naf_condition(Target).
satisfy_condition(_, ChildHead, Target) :-
    (   naf_inner_goal(Target, Inner)
    ->  unify_condition(ChildHead, Inner)
    ;   unify_condition(ChildHead, Target)
    ).

% naf_inner_goal(+Cond, -Inner): the negated goal of a NAF condition (the goal G
% in "it is not the case that G"), stripping source annotations.
naf_inner_goal(le_at(C, _, _), Inner) :- !, naf_inner_goal(C, Inner).
naf_inner_goal(not(Inner0), Inner) :- strip_le_at(Inner0, Inner).

unify_condition(Head, le_at(Cond, _, _)) :- !, unify_condition(Head, Cond).
unify_condition(Head, or(A, B)) :- !,
    ( unify_condition(Head, A) ; unify_condition(Head, B) ).
unify_condition(Head, Cond) :- Head = Cond.

%!  is_naf_condition(+Cond) is semidet.
%
%   True if Cond is a negation-as-failure condition (an "it is not the case
%   that ..." literal), optionally wrapped in le_at/3 source annotations.
is_naf_condition(le_at(Cond, _, _)) :- !, is_naf_condition(Cond).
is_naf_condition(not(_)).

render_instances(_KB, [], []).
render_instances(KB, [inst(IId, fail, _, _, _)|Insts], [Result|Results]) :- !,
    Result = _{ instanceId: IId, head: "", headTokens: [], body: [], bodyTokens: [] },
    render_instances(KB, Insts, Results).
render_instances(KB, [inst(IId, _Kind, Head, Body, NameMap)|Insts], [Result|Results]) :-
    game_var_ids((Head :- Body), VarIds),
    literal_to_game(KB, Head, VarIds, NameMap, [], Seen1, HeadLE, HeadTokens),
    body_list_to_game(KB, Body, VarIds, NameMap, Seen1, _SeenN, BodyLEs, BodyTokensList),
    % Re-render any "for all cases" sub-conditions too, so their bindings (e.g.
    % "the creature" -> alice) appear once the rule's variables are bound.
    forall_meta_list(KB, Body, VarIds, NameMap, ForallMeta),
    % The bound inner goal of each negation ("it is not the case that <G>"), so the
    % client can reject a negation link whose connected failing rule denotes a
    % different goal than the one this rule's bindings actually negate.
    naf_inner_list(KB, Body, NafInner),
    Result = _{ instanceId: IId, head: HeadLE, headTokens: HeadTokens,
                body: BodyLEs, bodyTokens: BodyTokensList,
                bodyForall: ForallMeta, bodyNafInner: NafInner },
    render_instances(KB, Insts, Results).

% naf_inner_list(+KB, +Body, -NafInner): for each negation-as-failure body
% condition, a dict with its index, the canonical rendering of its (possibly
% bound) inner goal, and whether that goal is ground.
naf_inner_list(KB, Body, NafInner) :-
    findall(_{ index: I, goal: GoalStr, ground: Ground },
        (   nth0(I, Body, Cond),
            is_naf_condition(Cond),
            naf_inner_goal(Cond, Inner),
            ( term_variables(Inner, []) -> Ground = true ; Ground = false ),
            (   KB \== none, le_kbs:item_to_instance(KB, Inner, Toks)
            ->  le_kbs:canonical_string(Toks, A),
                ( string(A) -> GoalStr = A ; atom_string(A, GoalStr) )
            ;   term_string(Inner, GoalStr) )
        ), NafInner).

% --- Typed Rendering Logic (moved from le_kbs) ---

item_to_typed_instance(KBmodule, le_at(Goal, _, _), WordsAndVars) :- !,
    item_to_typed_instance(KBmodule, Goal, WordsAndVars).
item_to_typed_instance(_KBmodule, var(Name, Value), [var(Name, Value)]) :- !.
item_to_typed_instance(KBmodule, not(Goal), WordsAndVars) :- !,
    ( item_to_typed_instance(KBmodule, Goal, GoalLE) ->
        WordsAndVars = [it, is, not, the, case, that | GoalLE]
    ; WordsAndVars = [it, is, not, the, case, that, Goal] ).
item_to_typed_instance(KBmodule, and(A, B), WordsAndVars) :- !,
    ( item_to_typed_instance(KBmodule, A, ALE), item_to_typed_instance(KBmodule, B, BLE) ->
        append(ALE, [and | BLE], WordsAndVars)
    ; WordsAndVars = [A, and, B] ).
item_to_typed_instance(KBmodule, or(A, B), WordsAndVars) :- !,
    ( item_to_typed_instance(KBmodule, A, ALE), item_to_typed_instance(KBmodule, B, BLE) ->
        append(ALE, [or | BLE], WordsAndVars)
    ; WordsAndVars = [A, or, B] ).
item_to_typed_instance(KBmodule, Head, WordsAndVars) :-
    (   ( KBmodule:le_dict(dict([Functor|Args], NTs, WordsAndVars0, _, _, _, _))
        ; KBmodule:le_dict(dict([Functor|Args], NTs, WordsAndVars0, _))
        ; KBmodule:le_dict(dict([Functor|Args], NTs, WordsAndVars0)) ),
        Head =.. [Functor|Args],
        le_kbs:check_types(NTs)
    ->  maplist(maybe_transform_typed(KBmodule), WordsAndVars0, WordsAndVars1),
        maplist(fill_variable_typed(NTs), WordsAndVars1, WordsAndVars2),
        flatten(WordsAndVars2, WordsAndVars)
    ;   ( le_kbs:item_to_instance(KBmodule, Head, WordsAndVars) -> true
        ; term_string(Head, Str), WordsAndVars = [Str] )
    ).

maybe_transform_typed(KBmodule, Val, Transformed) :-
    (   compound(Val), \+ is_list(Val), Val \= date(_), Val \= date(_,_,_),
        item_to_typed_instance(KBmodule, Val, Transformed)
    ->  true
    ;   Transformed = Val
    ).

fill_variable_typed(NTs, V, gtypedvar(V, Type)) :-
    var(V),
    member(V1-Type0, NTs),
    V1 == V, !,
    ( atom(Type0) -> Type = Type0 ; Type = variable ).
fill_variable_typed(_, V, gtypedvar(V, variable)) :- var(V), !.
fill_variable_typed(_, V, V).

tagged_tokens_to_game(_KB, [], _VarIds, _NameMap, Seen, Seen, []).
tagged_tokens_to_game(KB, [G|T], VarIds, NameMap, SeenIn, SeenOut, [Tok|ToksT]) :-
    nonvar(G), G = gtypedvar(V, Type), !,
    ( (member(Vid-V0, VarIds), V0 == V) -> Id = Vid ; Id = -1 ),
    % The noun phrase shown for this variable. A descriptive source name (e.g.
    % "other creature") replaces the template slot's type, so distinct same-typed
    % variables stay distinct and a variable keeps one name across the
    % differently-typed slots it fills. An explicit id (e.g. X) is kept as a
    % trailing tag after the type ("a thing X"); a name equal to the type (the
    % common "a creature" case) renders exactly as before.
    ( member(VN-Name, NameMap), VN == V, Name \== '' -> HasName = true ; HasName = false ),
    ( HasName == true, \+ is_id(Name), descriptive_noun_name(Name) -> Noun = Name, IdTag = []
    ; Noun = Type, ( HasName == true, is_id(Name) -> IdTag = [Name] ; IdTag = [] ) ),
    ( memberchk(Id, SeenIn) -> Det = the, Seen1 = SeenIn
    ; ( starts_with_vowel(Noun) -> Det = an ; Det = a ),
      Seen1 = [Id|SeenIn] ),
    append([Det, Noun], IdTag, Words),
    atomic_list_concat(Words, ' ', Text),
    ( IdTag = [IdName] ->
        Tok = _{ kind: "var", id: Id, type: Type, det: Det, name: IdName, text: Text }
    ;   Tok = _{ kind: "var", id: Id, type: Type, det: Det, text: Text }
    ),
    tagged_tokens_to_game(KB, T, VarIds, NameMap, Seen1, SeenOut, ToksT).
tagged_tokens_to_game(KB, [W|T], VarIds, NameMap, SeenIn, SeenOut, [Tok|ToksT]) :-
    ( le_kbs:token_to_atom(W, A) -> true ; term_to_atom(W, A) ),
    atom_string(A, S),
    Tok = _{ kind: "word", text: S },
    tagged_tokens_to_game(KB, T, VarIds, NameMap, SeenIn, SeenOut, ToksT).

% idx_names_to_var_names(+IdxNames, +AllVars, -VarNames): turn a list of
% Index-Name pairs (from le_var_names, indexed by term_variables position) into
% Variable-Name pairs whose keys are the ACTUAL variables in AllVars. Built by
% direct recursion, not findall/3, so the variables are shared (not copied) and
% the map keys stay == the head/body variables.
idx_names_to_var_names([], _, []).
idx_names_to_var_names([Idx-Name|T], AllVars, Result) :-
    ( nth0(Idx, AllVars, V) -> Result = [V-Name|T2] ; Result = T2 ),
    idx_names_to_var_names(T, AllVars, T2).

starts_with_vowel(Atom) :-
    atom(Atom), atom_codes(Atom, [C|_]),
    memberchk(C, [97, 101, 105, 111, 117, 65, 69, 73, 79, 85]).

% A variable's source name is shown in place of its slot type only when it is a
% descriptive common-noun phrase (lower-case initial, e.g. "other creature"). A
% proper noun or acronym ("UK", "John") read as an individual rather than a
% variable noun, so it falls back to the type to avoid odd output like "an UK".
descriptive_noun_name(Name) :-
    atom(Name), atom_codes(Name, [C|_]), code_type(C, lower).

game_tokens_text(Tokens, Text) :-
    maplist(get_dict(text), Tokens, Parts),
    atomic_list_concat(Parts, ' ', Atom),
    atom_string(Atom, Text).

% --- General Helpers ---

comma_list((A, B), [A|T]) :- !, comma_list(B, T).
comma_list(A, [A]).

strip_le_at(le_at(Term, _, _), Stripped) :- !, strip_le_at(Term, Stripped).
strip_le_at(Term, Term).

flatten_and([], []).
flatten_and([and(A, B)|T], Flat) :- !, flatten_and([A, B|T], Flat).
flatten_and([H|T], [H|FlatT]) :- flatten_and(T, FlatT).

% flatten_body(+BodyList, -FlatBodyList): flatten the top-level "and" structure
% of a rule body into one element per condition, preserving the le_at/3 source
% annotation on each leaf condition. A condition is split only when it strips to
% an and/2; otherwise it is kept verbatim (so a single-atom body like le_at(u,...)
% retains its range instead of being reduced to a bare atom).
flatten_body([], []).
flatten_body([Cond|T], Flat) :-
    ( strip_le_at(Cond, and(A, B))
    ->  flatten_body([A, B|T], Flat)
    ;   Flat = [Cond|FlatT], flatten_body(T, FlatT)
    ).
