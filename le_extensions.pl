:- module(le_extensions, [resolve_prolog_tokens/5, parse_numbered_body/7]).

:- use_module(le_grammar).

:- multifile le_grammar:extract_var_name_extension/2.
:- multifile le_grammar:unify_with_vmap_extension/5.
:- multifile le_grammar:post_parse_literal_hook/4.
:- multifile le_grammar:parse_node_extension/6.

% 1. Recognize 'which' as a variable name
le_grammar:extract_var_name_extension([which], which).

% 2. Resolve 'which' to the last variable in the VM
le_grammar:unify_with_vmap_extension(which, Var, VMIn, VMIn, _IsVar) :-
    member('$last_var'-Var, VMIn), !.

% 3. After parsing a literal, record the last variable found
le_grammar:post_parse_literal_hook(WordsAndVars, _Literal, VMIn, VMOut) :-
    reverse(WordsAndVars, Rev),
    ( member(Var, Rev), var(Var) ->
        % Found the last variable. Update VM.
        % Remove any existing $last_var to avoid multiple entries
        exclude(is_last_var_entry, VMIn, VM1),
        VMOut = ['$last_var'-Var | VM1]
    ; VMOut = VMIn
    ).

is_last_var_entry('$last_var'-_).

resolve_prolog_tokens(Tokens, Templates, VMIn, VMOut, Goal) :-
    % 1. Identify LE variables in Tokens and replace them with unique Prolog variable names
    tokens_to_prolog_string(Tokens, Templates, VMIn, VMOut, String, VarNames),
    % 2. Parse the string as a Prolog term
    ( VarNames == [] -> 
        (catch(term_string(Goal, String), _, fail) -> true ; fail)
    ; 
        (catch(read_term_from_atom(String, Goal, [variable_names(PrologVarNames)]), _, fail) -> true ; fail),
        % 3. Unify the parsed variables with the LE variables
        unify_prolog_vars(PrologVarNames, VarNames)
    ).

tokens_to_prolog_string(Tokens, Templates, VMIn, VMOut, String, VarNames) :-
    tokens_to_prolog_parts(Tokens, Templates, VMIn, VMOut, Parts, VarNames),
    atomic_list_concat(Parts, String).

tokens_to_prolog_parts([], _, VM, VM, [], []).
tokens_to_prolog_parts([var(Words, _)|Ts], Templates, VMIn, VMOut, [Part|Parts], [PName-Var|VarNames]) :-
    !,
    le_grammar:extract_var_info_from_words(Words, Name, _Type),
    le_grammar:unify_with_vmap(Name, Var, VMIn, VM1, true),
    variant_sha1(Name, Hash),
    sub_atom(Hash, 0, 8, _, ShortHash),
    atomic_list_concat(['VAR_', ShortHash], PName),
    Part = PName,
    tokens_to_prolog_parts(Ts, Templates, VM1, VMOut, Parts, VarNames).
tokens_to_prolog_parts(Tokens, Templates, VMIn, VMOut, [Part|Parts], VarNames) :-
    % Try to match a variable (greedy: try longer sequences first)
    findall(L-VT-R, (append(VT, R, Tokens), VT \== [], length(VT, L)), Splits),
    sort(1, @>=, Splits, SortedSplits),
    member(_-VarTokens-Rest, SortedSplits),
    extract_var_name_from_tokens(VarTokens, Name),
    !,
    le_grammar:unify_with_vmap(Name, Var, VMIn, VM1, true),
    % Generate a unique name for this variable in the Prolog string
    variant_sha1(Name, Hash),
    sub_atom(Hash, 0, 8, _, ShortHash),
    atomic_list_concat(['VAR_', ShortHash], PName),
    Part = PName,
    VarNames = [PName-Var | RestVarNames],
    tokens_to_prolog_parts(Rest, Templates, VM1, VMOut, Parts, RestVarNames).
tokens_to_prolog_parts([expr(E)|Ts], Templates, VMIn, VMOut, [Part|Parts], VarNames) :-
    !,
    tokens_to_prolog_string(E, Templates, VMIn, VM1, InnerString, InnerVarNames),
    format(atom(Part), '(~w)', [InnerString]),
    append(InnerVarNames, RestVarNames, VarNames),
    tokens_to_prolog_parts(Ts, Templates, VM1, VMOut, Parts, RestVarNames).
tokens_to_prolog_parts([T|Ts], Templates, VMIn, VMOut, [Part|Parts], VarNames) :-
    le_grammar:extract_simple_word(T, Word),
    ( Word == '' -> Part = ' ' ; Part = Word ), % avoid empty parts
    tokens_to_prolog_parts(Ts, Templates, VMIn, VMOut, Parts, VarNames).

unify_prolog_vars([], _).
unify_prolog_vars([PName=Var|Rest], VarNames) :-
    ( member(PName-LEVar, VarNames) -> Var = LEVar ; true ),
    unify_prolog_vars(Rest, VarNames).

% Helper to extract variable name from tokens
extract_var_name_from_tokens(Tokens, Name) :-
    maplist(le_grammar:extract_simple_word, Tokens, Words),
    (   Words = ['*' | Rest], append(VarWords, ['*'], Rest), \+ member('*', VarWords) ->
        le_grammar:extract_var_info_from_words(VarWords, Name, _)
    ;   Words = [Art | Rest], Rest \== [], member(Art, [the, an, a, 'The', 'An', 'A']),
        forall(member(W, Rest), (atom(W), \+ le_grammar:is_punct(W))) ->
        le_grammar:extract_var_info_from_words(Words, Name, _)
    ;   Words = [ID], le_grammar:is_id(ID) -> Name = ID
    ).

% 6. Rules with numbering

parse_numbered_body(Tokens, Templates, VMIn, VMOut, Logic, RuleID, M) :-
    exclude(is_indent_token, Tokens, CleanTokens),
    tokens_to_numbered_lines(CleanTokens, Lines),
    lines_to_numbered_hierarchy(Lines, Hierarchy),
    hierarchy_to_numbered_logic(Hierarchy, Templates, VMIn, VMOut, Logic, RuleID, M).

is_indent_token(indent(_, _)).

tokens_to_numbered_lines([], []).
tokens_to_numbered_lines(Tokens, [line(Designator, LineTokens)|Lines]) :-
    extract_designator(Tokens, Designator, Rest0),
    consume_until_next_designator_or_end(Rest0, LineTokens, Rest),
    tokens_to_numbered_lines(Rest, Lines).

extract_designator(Tokens, Designator, Rest) :-
    % Match something like 1. or 4.2.1. or a. or i.
    extract_designator_parts(Tokens, Parts, Rest),
    Parts \== [],
    atomic_list_concat(Parts, '.', Designator).

extract_designator_parts([T, punctuation(P, _)|Ts], [Part|Parts], Rest) :-
    (T = number(_, _) ; T = word(_, _)),
    P == '.',
    le_grammar:extract_simple_word(T, Part),
    !,
    (   (Ts = [word(_, _)|_] ; Ts = [number(_, _)|_]) ->
        extract_designator_parts(Ts, Parts, Rest)
    ;   Rest = Ts, Parts = []
    ).

consume_until_next_designator_or_end([], [], []).
consume_until_next_designator_or_end(Tokens, [], Tokens) :-
    extract_designator(Tokens, _, _), !.
consume_until_next_designator_or_end([T|Ts], [T|LTs], Rest) :-
    consume_until_next_designator_or_end(Ts, LTs, Rest).

lines_to_numbered_hierarchy([], []).
lines_to_numbered_hierarchy([line(D, Tokens)|Lines], [node(D, Tokens, Children)|RestNodes]) :-
    take_nested_numbered_hierarchy(Lines, D, Nested, Remaining),
    lines_to_numbered_hierarchy(Nested, Children),
    lines_to_numbered_hierarchy(Remaining, RestNodes).

take_nested_numbered_hierarchy([line(D2, Tokens)|Lines], D, [line(D2, Tokens)|Nested], Remaining) :-
    atom_concat(D, '.', Prefix),
    atom_concat(Prefix, _, D2), !,
    take_nested_numbered_hierarchy(Lines, D, Nested, Remaining).
take_nested_numbered_hierarchy(Lines, _, [], Lines).

hierarchy_to_numbered_logic([], _, VM, VM, true, _, _) :- !.
hierarchy_to_numbered_logic([node(D, Tokens, Children)|RestNodes], Templates, VMIn, VMOut, Logic, RuleID, M) :-
    parse_numbered_node(D, Tokens, Children, Templates, VMIn, VM1, FirstLogic, RuleID, Op, M),
    fold_numbered_nodes(FirstLogic, Op, RestNodes, Templates, VM1, VMOut, Logic, RuleID, M).

fold_numbered_nodes(Acc, _, [], _, VM, VM, Acc, _, _).
fold_numbered_nodes(Acc, Op, [node(D, Tokens, Children)|Rest], Templates, VMIn, VMOut, Logic, RuleID, M) :-
    parse_numbered_node(D, Tokens, Children, Templates, VMIn, VM1, ChildLogic, RuleID, NextOp, M),
    NewAcc =.. [Op, Acc, ChildLogic],
    fold_numbered_nodes(NewAcc, NextOp, Rest, Templates, VM1, VMOut, Logic, RuleID, M).

parse_numbered_node(D, Tokens, Children, Templates, VMIn, VMOut, Logic, RuleID, Op, M) :-
    strip_numbered_noise(Tokens, CleanTokens, Op),
    (   CleanTokens == [], Children \== [] ->
        hierarchy_to_numbered_logic(Children, Templates, VMIn, VMOut, Logic0, RuleID, M)
    ;   (member(word(one, _), CleanTokens), member(word(of, _), CleanTokens)) ->
        hierarchy_to_numbered_logic(Children, Templates, VMIn, VMOut, Logic0, RuleID, M),
        change_op(Logic0, and, or, Logic1),
        Logic0 = Logic1
    ;   (member(word(all, _), CleanTokens), member(word(of, _), CleanTokens)) ->
        hierarchy_to_numbered_logic(Children, Templates, VMIn, VMOut, Logic0, RuleID, M)
    ;   CleanTokens = [word(prolog, _)|Rest], Children == [] ->
        resolve_prolog_tokens(Rest, Templates, VMIn, VMOut, Goal),
        Logic0 = prolog_call(Goal)
    ;   le_grammar:parse_literal(CleanTokens, Templates, VMIn, VMOut, Literal) ->
        ( Children == [] -> Logic0 = Literal ; 
          hierarchy_to_numbered_logic(Children, Templates, VMOut, VM2, ChildLogic, RuleID, M),
          Logic0 =.. [Op, Literal, ChildLogic],
          VMOut = VM2
        )
    ;   Logic0 = unknown_template(CleanTokens)
    ),
    retractall(M:le_source_element(RuleID, D, _)),
    assertz(M:le_source_element(RuleID, D, Logic0)),
    Logic = Logic0.


strip_numbered_noise(Tokens, Clean, Op) :-
    ( append(Clean, [punctuation(':', _)], Tokens) -> Op = and
    ; append(Clean, [punctuation(';', _), word(and, _)], Tokens) -> Op = and
    ; append(Clean, [punctuation(';', _), word(or, _)], Tokens) -> Op = or
    ; append(Clean, [punctuation(';', _)], Tokens) -> Op = and
    ; Clean = Tokens, Op = and
    ).

change_op(and(A, B), and, or, or(A1, B1)) :- !, change_op(A, and, or, A1), change_op(B, and, or, B1).
change_op(X, _, _, X).
