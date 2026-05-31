:- module(le_proof_game, [
    extract_rules_and_facts/6,
    unify_game_nodes/5,
    game_var_ids/2
]).

:- use_module(le_kbs).
:- use_module(le_grammar).

%!  extract_rules_and_facts(+KB, +SM, +Query, -Rules, -Facts, -QueryTokens) is det.
extract_rules_and_facts(KB, SM, Query, Rules, Facts, QueryTokens) :-
    ( SM \== none -> dynamic(SM:game_node_term/3), retractall(SM:game_node_term(_,_,_)) ; true ),
    nb_setval(game_node_counter, 0),
    findall(RuleDict, (
        current_predicate(KB:F/N),
        \+ le_kbs:is_system_predicate(F/N),
        functor(Head, F, N),
        clause(KB:Head, Body, Ref),
        KB:le_source_info(Ref, Start, End, ID),
        \+ member(ID, [template, template_unknown, ontology, session_fact]),
        Body \== true,
        comma_list(Body, BodyList),
        maplist(strip_le_at, BodyList, StrippedBodyList),
        flatten_and(StrippedBodyList, FlatBodyList),
        next_game_node_id(rule, NodeId),
        game_var_ids((Head :- FlatBodyList), VarIds),
        literal_to_game(KB, Head, VarIds, [], Seen1, HeadLE, HeadTokens),
        body_list_to_game(KB, FlatBodyList, VarIds, Seen1, _SeenN, BodyLEs, BodyTokensList),
        ( SM \== none ->
            assertz(SM:game_node_term(NodeId, rule, term(Head, FlatBodyList, VarIds)))
        ; true ),
        RuleDict = _{ id: NodeId, head: HeadLE, headTokens: HeadTokens,
                      body: BodyLEs, bodyTokens: BodyTokensList,
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
        next_game_node_id(fact, NodeId),
        game_var_ids(Head, VarIds),
        literal_to_game(KB, Head, VarIds, [], _Seen, FactLE, FactTokens),
        ( SM \== none ->
            assertz(SM:game_node_term(NodeId, fact, term(Head, [], VarIds)))
        ; true ),
        FactDict = _{ id: NodeId, fact: FactLE, factTokens: FactTokens,
                      start: Start, end: End }
    ), Facts),
    ( SM \== none ->
        game_var_ids(Query, QVarIds),
        assertz(SM:game_node_term(query, query, term(Query, [Query], QVarIds)))
    ; true ),
    ( KB \== none ->
        game_var_ids(Query, QVarIds2),
        literal_to_game(KB, Query, QVarIds2, [], _Seen2, _QueryLE, QueryTokens)
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

next_game_node_id(Kind, NodeId) :-
    nb_getval(game_node_counter, N),
    N1 is N + 1,
    nb_setval(game_node_counter, N1),
    format(atom(NodeId), "~w_~w", [Kind, N]).

game_var_ids(Term, VarIds) :-
    term_variables(Term, Vars),
    number_var_ids(Vars, 0, VarIds).

number_var_ids([], _, []).
number_var_ids([V|Vs], N, [N-V|T]) :-
    N1 is N + 1,
    number_var_ids(Vs, N1, T).

literal_to_game(KB, Literal, VarIds, SeenIn, SeenOut, LE, Tokens) :-
    ( KB \== none, item_to_typed_instance(KB, Literal, Tagged) ->
        tagged_tokens_to_game(KB, Tagged, VarIds, SeenIn, SeenOut, Tokens),
        game_tokens_text(Tokens, LE)
    ;   term_string(Literal, LE), Tokens = [_{kind: "word", text: LE}], SeenOut = SeenIn
    ).

body_list_to_game(_KB, [], _VarIds, Seen, Seen, [], []).
body_list_to_game(KB, [L|Ls], VarIds, SeenIn, SeenOut, [LE|LEs], [Tokens|TokensT]) :-
    literal_to_game(KB, L, VarIds, SeenIn, Seen1, LE, Tokens),
    body_list_to_game(KB, Ls, VarIds, Seen1, SeenOut, LEs, TokensT).

build_proof_fragment(_SM, [], []).
build_proof_fragment(SM, [Spec|Specs], [inst(IId, Kind, Head, Body)|Insts]) :-
    get_dict(instanceId, Spec, IIdVal), atom_string(IId, IIdVal),
    get_dict(templateId, Spec, TIdVal), atom_string(TId, TIdVal),
    SM:game_node_term(TId, Kind, term(Head0, Body0, _VarIds)),
    copy_term(Head0-Body0, Head-Body),
    build_proof_fragment(SM, Specs, Insts).

apply_edges(_Instances, []).
apply_edges(Instances, [Edge|Edges]) :-
    get_dict(child, Edge, ChildVal), atom_string(Child, ChildVal),
    get_dict(parent, Edge, ParentVal), atom_string(Parent, ParentVal),
    get_dict(bodyIndex, Edge, BodyIndex),
    member(inst(Child, _, ChildHead, _), Instances),
    member(inst(Parent, _, _, ParentBody), Instances),
    nth0(BodyIndex, ParentBody, ParentCond),
    unify_condition(ChildHead, ParentCond),
    apply_edges(Instances, Edges).

unify_condition(Head, le_at(Cond, _, _)) :- !, unify_condition(Head, Cond).
unify_condition(Head, or(A, B)) :- !,
    ( unify_condition(Head, A) ; unify_condition(Head, B) ).
unify_condition(Head, Cond) :- Head = Cond.

render_instances(_KB, [], []).
render_instances(KB, [inst(IId, _Kind, Head, Body)|Insts], [Result|Results]) :-
    game_var_ids((Head :- Body), VarIds),
    literal_to_game(KB, Head, VarIds, [], Seen1, HeadLE, HeadTokens),
    body_list_to_game(KB, Body, VarIds, Seen1, _SeenN, BodyLEs, BodyTokensList),
    Result = _{ instanceId: IId, head: HeadLE, headTokens: HeadTokens,
                body: BodyLEs, bodyTokens: BodyTokensList },
    render_instances(KB, Insts, Results).

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

tagged_tokens_to_game(_KB, [], _VarIds, Seen, Seen, []).
tagged_tokens_to_game(KB, [gtypedvar(V, Type)|T], VarIds, SeenIn, SeenOut, [Tok|ToksT]) :- !,
    ( member(Vid-V0, VarIds), V0 == V -> Id = Vid ; Id = -1 ),
    ( memberchk(Id, SeenIn) -> Det = the, Seen1 = SeenIn
    ; ( starts_with_vowel(Type) -> Det = an ; Det = a ),
      Seen1 = [Id|SeenIn] ),
    ( Det == the -> Words = [the, Type] ; Words = [Det, Type] ),
    atomic_list_concat(Words, ' ', Text),
    Tok = _{ kind: "var", id: Id, type: Type, det: Det, text: Text },
    tagged_tokens_to_game(KB, T, VarIds, Seen1, SeenOut, ToksT).
tagged_tokens_to_game(KB, [W|T], VarIds, SeenIn, SeenOut, [Tok|ToksT]) :-
    ( le_kbs:token_to_atom(W, A) -> true ; term_to_atom(W, A) ),
    atom_string(A, S),
    Tok = _{ kind: "word", text: S },
    tagged_tokens_to_game(KB, T, VarIds, SeenIn, SeenOut, ToksT).

starts_with_vowel(Atom) :-
    atom(Atom), atom_codes(Atom, [C|_]),
    memberchk(C, [97, 101, 105, 111, 117, 65, 69, 73, 79, 85]).

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
