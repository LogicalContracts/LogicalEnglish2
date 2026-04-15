:- module(le_grammar, [parse_le_file/2, parse_le_tokens/2, match_instance_to_template/6, match_instance_to_template/7]).

:- use_module(tokenizer).
:- use_module(le_system_templates).
:- use_module(library(dcg/basics)).

% Main entry point
parse_le_file(FilePath, Doc) :-
    tokenize_file(FilePath, Tokens),
    parse_le_tokens(Tokens, Doc).

parse_le_tokens(Tokens, doc(NewSections)) :-
    phrase(doc(Sections), Tokens),
    second_pass(Sections, NewSections).

% DCG for Logical English
doc(Sections) --> sections(Sections), any_indent.

sections([S|Ss]) --> section(S), !, sections(Ss).
sections([]) --> [].

section(kb(Name, Content, Start, End)) --> 
    any_indent, t(word(the, loc(Start, _))), t(word(knowledge)), t(word(base)), t(word(Name)), t(word(includes)), t(punctuation(':', _)),
    { (le_kbs:do_log -> format('Parsing KB: ~w~n', [Name]) ; true) },
    kb_content(Content, End),
    { (le_kbs:do_log -> format('Finished KB: ~w~n', [Name]) ; true) }.

section(scenario(Name, Content, Start, End)) -->
    any_indent, t(word(scenario, loc(Start, _))), section_name(Name), t(word(is)), t(punctuation(':', _)),
    kb_content(Content, End).

section(query(Name, Content, Start, End)) -->
    any_indent, t(word(query, loc(Start, _))), section_name(Name), t(word(is)), t(punctuation(':', _)),
    kb_content(Content, End).

section(ontology(Content, Start, End)) -->
    any_indent, t(word(the, loc(Start, _))), t(word(ontology)), t(word(is)), t(punctuation(':', _)),
    kb_content(Content, End).

section(predicates(Dicts)) -->
    any_indent, t(word(the, _)), t(word(predicates)), t(word(are)), t(punctuation(':', _)),
    templates(Dicts).

section(templates(Dicts)) -->
    any_indent, t(word(the, _)), t(word(templates)), t(word(are)), t(punctuation(':', _)),
    templates(Dicts).

section(fluents(Dicts)) -->
    any_indent, t(word(the, _)), t(word(fluents)), t(word(are)), t(punctuation(':', _)),
    templates(Dicts).

section(events(Dicts)) -->
    any_indent, t(word(the, _)), t(word(events)), t(word(are)), t(punctuation(':', _)),
    templates(Dicts).

section(meta(Dicts)) -->
    any_indent, t(word(the, _)), t(word(target)), t(word(language)), t(word(is)), t(punctuation(':', _)), t(word(prolog)), t(punctuation('.', _)),
    { Dicts = [] }.

section(unknown_section(Tokens)) -->
    [T], { T =.. [_, _, loc(_, _)] },
    consume_until_next_section(Ts),
    { Tokens = [T|Ts] }.

section_name(Name) -->
    t(word(W)),
    (   \+ t(word(is)), \+ t(punctuation(':', _))
    ->  section_name(Rest),
        { atomic_list_concat([W, Rest], ' ', Name) }
    ;   { Name = W }
    ).

consume_until_next_section([T|Ts]) -->
    \+ next_section_start,
    [T], !,
    consume_until_next_section(Ts).
consume_until_next_section([]) --> [].

next_section_start --> any_indent, t(word(the, _)), t(word(knowledge)).
next_section_start --> any_indent, t(word(scenario, _)).
next_section_start --> any_indent, t(word(query, _)).
next_section_start --> any_indent, t(word(the, _)), t(word(ontology)).
next_section_start --> any_indent, t(word(the, _)), t(word(predicates)).
next_section_start --> any_indent, t(word(the, _)), t(word(templates)).
next_section_start --> any_indent, t(word(the, _)), t(word(fluents)).
next_section_start --> any_indent, t(word(the, _)), t(word(events)).
next_section_start --> any_indent, t(word(the, _)), t(word(target)).

kb_content(Content, End) -->
    kb_items(Content),
    { (Content = [] -> End = 0 ; last(Content, Last), (Last =.. [_, _, _, _, End] -> true ; Last =.. [_, _, _, End] -> true ; End = 0)) }.

kb_items([I|Is]) --> \+ next_section_start, kb_item(I), !, kb_items(Is).
kb_items([]) --> [].

kb_item(rule(Head, Body, Start, End)) -->
    template_instance(Head),
    any_indent, t(word(if, loc(Start, _))),
    body(Body, End).
kb_item(fact(Head, Start, End)) -->
    template_instance(Head),
    any_indent, t(punctuation('.', loc(Start, End))).

templates([T|Ts]) -->
    \+ next_section_start,
    template(T),
    (   (t(punct('.')) ; t(punct(','))) -> ( templates(Ts) | { Ts = [] } )
    ;   { Ts = [] }
    ).
templates([]) --> [].

template(dict(FunctorArgs, NamesTypes, WordsAndVars)) -->
    template_instance(Tokens),
    { process_template(Tokens, FunctorArgs, NamesTypes, WordsAndVars) }.

process_template(Tokens, [Functor|Args], NamesTypes, WordsAndVars) :-
    extract_functor(Tokens, Functor),
    process_template_parts(Tokens, Args, NamesTypes, WordsAndVars).

extract_functor(Tokens, Functor) :-
    findall(W, (member(T, Tokens), T = word(W, _)), Words),
    atomic_list_concat(Words, '_', Functor).

process_template_parts([], [], [], []).
process_template_parts([var(Words)|Ps], [V|Args], [V-Type|NTs], [V|WVs]) :-
    !, extract_var_info_from_words(Words, _Name, Type),
    process_template_parts(Ps, Args, NTs, WVs).
process_template_parts([word(W, _)|Ps], Args, NTs, [W|WVs]) :-
    !, process_template_parts(Ps, Args, NTs, WVs).
process_template_parts([number(N, _)|Ps], Args, NTs, [N|WVs]) :-
    !, process_template_parts(Ps, Args, NTs, WVs).
process_template_parts([punct(P, _)|Ps], Args, NTs, [P|WVs]) :-
    !, process_template_parts(Ps, Args, NTs, WVs).
process_template_parts([punctuation(P, _)|Ps], Args, NTs, [P|WVs]) :-
    !, process_template_parts(Ps, Args, NTs, WVs).
process_template_parts([expr(_)|Ps], [V|Args], [V-expr|NTs], [V|WVs]) :-
    !, process_template_parts(Ps, Args, NTs, WVs).
process_template_parts([date(D, _)|Ps], Args, NTs, [D|WVs]) :-
    !, process_template_parts(Ps, Args, NTs, WVs).
process_template_parts([string(S, _)|Ps], Args, NTs, [S|WVs]) :-
    !, process_template_parts(Ps, Args, NTs, WVs).
process_template_parts([list(_)|Ps], [V|Args], [V-list|NTs], [V|WVs]) :-
    !, process_template_parts(Ps, Args, NTs, WVs).

extract_var_info_from_words(Words, Name, Type) :-
    (   Words = [Art | Rest], Rest \== [], is_article(Art)
    ->  atomic_list_concat(Rest, ' ', Type)
    ;   atomic_list_concat(Words, ' ', Type)
    ),
    Name = Type.

is_article(a).
is_article(an).
is_article(the).
is_article(some).

template_instance([P|Ps]) -->
    template_instance_part(P),
    template_instance_tail(Ps).

template_instance_tail([P|Ps]) -->
    \+ is_terminator,
    \+ next_section_start,
    template_instance_part(P), !,
    template_instance_tail(Ps).
template_instance_tail([]) --> [].

template_instance_part(var(Words)) --> t(punctuation('*')), template_var_words(Words), t(punctuation('*')).
template_instance_part(word(W, Loc)) --> t(word(W, Loc)).
template_instance_part(number(N, Loc)) --> t(number(N, Loc)).
template_instance_part(date(D, Loc)) --> t(date(D, Loc)).
template_instance_part(string(S, Loc)) --> t(quoteString(S, Loc)).
template_instance_part(string(S, Loc)) --> t(doubleQuoteString(S, Loc)).
template_instance_part(list(L)) --> t(punct('[')), list_elements(L), t(punct(']')).
template_instance_part(expr(E)) --> t(punct('(')), template_instance(E), t(punct(')')).
template_instance_part(punct(P, Loc)) --> t(punctuation(P, Loc)), { \+ member(P, ['[', ']', '.', ',', '(', ')']) }.
template_instance_part(punct('(', Loc)) --> t(punctuation('(', Loc)).
template_instance_part(punct(')', Loc)) --> t(punctuation(')', Loc)).

template_var_words([W|Ws]) --> t(word(W)), !, template_var_words(Ws).
template_var_words([]) --> [].

list_elements([E|Es]) --> template_instance(E), ( t(punct(',')), !, list_elements(Es) | { Es = [] } ).
list_elements([]) --> [].

body(Body, End) --> body_tokens(Body), any_indent, t(punctuation('.', loc(_, End))).

body_tokens([T|Ts]) --> \+ is_body_terminator, body_token(T), !, body_tokens(Ts).
body_tokens([]) --> [].

body_token(indent(N, L)) --> [indent(N, L)].
body_token(T) --> template_instance_part(T).

is_terminator --> any_indent, t(punctuation('.', _)).
is_terminator --> any_indent, t(punctuation(',', _)).
is_terminator --> any_indent, t(word(if, _)).

is_body_terminator --> any_indent, t(punctuation('.', _)).

any_indent --> [indent(_, _)], !, any_indent.
any_indent --> [line_comment(_, _)], !, any_indent.
any_indent --> [multi_comment(_, _)], !, any_indent.
any_indent --> [].

t(word(W, L)) --> any_indent, [word(W, L)].
t(word(W)) --> any_indent, [word(W, _)].
t(number(N, L)) --> any_indent, [number(N, L)].
t(number(N)) --> any_indent, [number(N, _)].
t(punctuation(P, L)) --> any_indent, [punctuation(P, L)].
t(punctuation(P)) --> any_indent, [punctuation(P, _)].
t(punct(P, L)) --> any_indent, [punctuation(P, L)].
t(punct(P)) --> any_indent, [punctuation(P, _)].
t(date(D, L)) --> any_indent, [date(D, L)].
t(date(D)) --> any_indent, [date(D, _)].
t(quoteString(S, L)) --> any_indent, [quoteString(S, L)].
t(doubleQuoteString(S, L)) --> any_indent, [doubleQuoteString(S, L)].

skip_comments --> any_indent.

% Semantics: Helper functions
is_proper_name_atom(W) :-
    atom(W),
    atom_codes(W, [C|_]),
    code_type(C, upper).

is_upper_atom(W) :-
    atom(W),
    atom_codes(W, Codes),
    forall(member(C, Codes), (code_type(C, upper) ; code_type(C, digit) ; C == 0'_)).

is_all_caps(Atom) :-
    atom_codes(Atom, Codes),
    maplist(is_upper_code, Codes).

is_upper_code(C) :- code_type(C, upper).
is_upper_code(C) :- code_type(C, digit).
is_upper_code(0'_).

is_proper_name(Words) :-
    Words \== [],
    forall(member(W, Words), is_proper_name_atom(W)).

is_id(W) :- atom(W), atom_length(W, 1), is_upper_atom(W).
is_id(W) :- atom(W), is_all_caps(W).

is_reserved(W) :- member(W, [says, that, if, and, or]).

extract_id(Words, Name) :-
    \+ (member(W, Words), is_reserved(W)),
    (   append(TypeWords, [ID], Words), TypeWords \== [], is_id(ID)
    ->  Name = ID
    ;   atomic_list_concat(Words, ' ', Name)
    ).

extract_var_name(Words, Name) :-
    (   Words = [Art | Rest], Rest \== [], is_article(Art) -> extract_id(Rest, Name)
    ;   Words = [each | Rest], Rest \== [] -> extract_id(Rest, Name)
    ;   Words = [which | Rest], Rest \== [] -> extract_id(Rest, Name)
    ;   Words = [W], is_id(W) -> Name = W
    ).

unify_with_vmap(Name, Var, VMIn, VMOut) :-
    unify_with_vmap(Name, Var, VMIn, VMOut, false).

unify_with_vmap(Name, Var, VMIn, VMOut, IsVar) :-
    (   (IsVar == true ; is_id(Name))
    ->  (   member(Name-ExistingVar, VMIn)
        ->  Var = ExistingVar, VMOut = VMIn
        ;   VMOut = [Name-Var|VMIn]
        )
    ;   is_proper_name_atom(Name)
    ->  Var = Name, VMOut = VMIn
    ;   member(Name-ExistingVar, VMIn)
    ->  Var = ExistingVar, VMOut = VMIn
    ;   VMOut = [Name-Var|VMIn]
    ).

match_part(punctuation(P, _), P, VM, VM, _, _) :- atom(P), !.
match_part(punct(P, _), P, VM, VM, _, _) :- atom(P), !.
match_part(punct(P), P, VM, VM, _, _) :- atom(P), !.
match_part(word(W, _), W, VM, VM, _, _) :- atom(W), !.
match_part(word(W), W, VM, VM, _, _) :- atom(W), !.
match_part(number(N, _), N, VM, VM, _, _) :- number(N), !.
match_part(number(N), N, VM, VM, _, _) :- number(N), !.
match_part(string(S, _), S, VM, VM, _, _) :- string(S), !.
match_part(string(S), S, VM, VM, _, _) :- string(S), !.
match_part(Part, V, VMIn, VMOut, Templates, AllowVars) :- var(V), !, extract_value(Part, V, VMIn, VMOut, Templates, AllowVars).

extract_value_from_parts(Parts, Value, VMIn, VMOut, Templates, _NoTransform, AllowVars, _Depth) :-
    (   Parts = [Part], extract_value(Part, Value, VMIn, VMOut, Templates, AllowVars) -> true
    ;   (Parts = [number(N, _)] ; Parts = [number(N)]) -> Value = N, VMOut = VMIn
    ;   (Parts = [string(S, _)] ; Parts = [string(S)]) -> Value = S, VMOut = VMIn
    ;   (Parts = [date(D, _)] ; Parts = [date(D)]) -> Value = D, VMOut = VMIn
    ;   maplist(extract_simple_word, Parts, Words),
        (   AllowVars == true, extract_var_name(Words, Name)
        ->  unify_with_vmap(Name, Value, VMIn, VMOut, true)
        ;   is_proper_name(Words)
        ->  atomic_list_concat(Words, ' ', Value), VMOut = VMIn
        ;   parse_expression(Parts, VMIn, VMOut, Templates, Value, AllowVars) -> true
        ;   AllowVars == false
        ->  (Words = [Value] -> true ; atomic_list_concat(Words, ' ', Value)), VMOut = VMIn
        ;   % Fallback: treat as constant if not a variable name
            atomic_list_concat(Words, ' ', Value), VMOut = VMIn
        )
    ).

extract_simple_value(word(W, _), W).
extract_simple_value(number(N, _), N).
extract_simple_value(quoteString(S, _), S).
extract_simple_value(doubleQuoteString(S, _), S).
extract_simple_value(punctuation(P, _), P).
extract_simple_value(punct(P, _), P).
extract_simple_value(date(D, _), D).
extract_simple_value(word(W), W).
extract_simple_value(number(N), N).
extract_simple_value(string(S), S).
extract_simple_value(punct(P), P).
extract_simple_value(date(D), D).
extract_simple_value(var(Words), Atom) :- atomic_list_concat(Words, ' ', Atom).

extract_simple_word(Part, Word) :-
    extract_simple_value(Part, Val),
    (   compound(Val), Val = date(Y, M, D)
    ->  format(atom(Word), '~w-~w-~w', [Y, M, D])
    ;   Word = Val
    ).

extract_name_type(Words, Name, Type) :-
    (   Words = [Art | Rest], Rest \== [], is_article(Art) -> extract_name_type_no_art(Rest, Name, Type)
    ;   extract_name_type_no_art(Words, Name, Type)
    ).

extract_name_type_no_art(Words, Name, Type) :-
    (   Words = [W] -> Name = W, Type = W
    ;   last(Words, Last),
        (   is_id(Last)
        ->  append(TypeWords, [Last], Words),
            (   TypeWords = [] -> Type = Last
            ;   atomic_list_concat(TypeWords, ' ', Type)
            ),
            Name = Last
        ;   atomic_list_concat(Words, ' ', Name),
            Type = Name
        )
    ).

extract_value(var(Words), Val, VMIn, VMOut, _Templates, AllowVars) :-
    !, extract_var_info_from_words(Words, Name, _Type),
    (   AllowVars == true -> unify_with_vmap(Name, Val, VMIn, VMOut, true)
    ;   Val = Name, VMOut = VMIn
    ).
extract_value(word(W, _), Val, VMIn, VMOut, _Templates, AllowVars) :-
    (le_kbs:do_log -> format('Extract value word: ~w (AllowVars: ~w)~n', [W, AllowVars]) ; true),
    (   AllowVars == true, member(W-Val, VMIn) -> VMOut = VMIn
    ;   is_proper_name_atom(W) -> Val = W, VMOut = VMIn
    ;   AllowVars == true, is_id(W) -> unify_with_vmap(W, Val, VMIn, VMOut, true)
    ;   Val = W, VMOut = VMIn
    ).
extract_value(number(N, _), N, VM, VM, _, _).
extract_value(date(D, _), D, VM, VM, _, _).
extract_value(quoteString(S, _), S, VM, VM, _, _).
extract_value(doubleQuoteString(S, _), S, VM, VM, _, _).
extract_value(punctuation(P, _), P, VM, VM, _, _).
extract_value(punct(P, _), P, VM, VM, _, _).
extract_value(word(W), Val, VMIn, VMOut, _Templates, AllowVars) :-
    (   AllowVars == true, member(W-Val, VMIn) -> VMOut = VMIn
    ;   is_proper_name_atom(W) -> Val = W, VMOut = VMIn
    ;   AllowVars == true, is_id(W) -> unify_with_vmap(W, Val, VMIn, VMOut, true)
    ;   Val = W, VMOut = VMIn
    ).
extract_value(number(N), N, VM, VM, _, _).
extract_value(date(D), D, VM, VM, _, _).
extract_value(string(S), S, VM, VM, _, _).
extract_value(punct(P), P, VM, VM, _, _).
extract_value(list(L), TransformedL, VMIn, VMOut, Templates, AllowVars) :-
    transform_list(L, Templates, VMIn, VMOut, TransformedL, AllowVars).
extract_value(expr(E), TransformedE, VMIn, VMOut, Templates, AllowVars) :-
    transform_instance(E, Templates, VMIn, VMOut, TransformedE, AllowVars).

transform_list([], _, VM, VM, [], _).
transform_list([I|Is], Templates, VMIn, VMOut, [T|Ts], AllowVars) :-
    transform_instance(I, Templates, VMIn, VM1, T, AllowVars),
    transform_list(Is, Templates, VM1, VMOut, Ts, AllowVars).

transform_instance(Instance, Templates, VMIn, VMOut, Transformed) :-
    transform_instance(Instance, Templates, VMIn, VMOut, Transformed, true).

transform_instance(Instance, Templates, VMIn, VMOut, Transformed, AllowVars) :-
    transform_instance(Instance, Templates, VMIn, VMOut, Transformed, AllowVars, 0).

transform_instance(Instance, Templates, VMIn, VMOut, Transformed, AllowVars, Depth) :-
    (   Depth > 1 -> fail ; true
    ),
    D1 is Depth + 1,
    (   match_template(Instance, Templates, VMIn, VMOut, Transformed, AllowVars, D1)
    ->  true
    ;   extract_value_from_parts(Instance, Transformed, VMIn, VMOut, Templates, true, AllowVars, D1)
    ).

match_template(Instance, Templates, VMIn, VMOut, Literal, AllowVars, Depth) :-
    member(Dict, Templates),
    copy_term(Dict, dict(FunctorArgs, _NTs, WordsAndVars)),
    match_instance_to_template(Instance, WordsAndVars, VMIn, VMOut, Templates, AllowVars, Depth),
    Literal =.. FunctorArgs.

match_instance_to_template(Instance, WordsAndVars, VMIn, VMOut, Templates, AllowVars) :-
    match_instance_to_template(Instance, WordsAndVars, VMIn, VMOut, Templates, AllowVars, 0).

match_instance_to_template(Instance, WordsAndVars, VMIn, VMOut, Templates, AllowVars, Depth) :-
    once(match_instance_to_template_acc(Instance, WordsAndVars, VMIn, VMOut, Templates, AllowVars, Depth)).

match_instance_to_template_acc([], [], VM, VM, _, _, _).
match_instance_to_template_acc(Instance, [T|Ts], VMIn, VMOut, Templates, AllowVars, Depth) :-
    (   \+ var(T)
    ->  Instance = [I|Is],
        match_part(I, T, VMIn, VM1, Templates, AllowVars),
        match_instance_to_template_acc(Is, Ts, VM1, VMOut, Templates, AllowVars, Depth)
    ;   % T is a variable (from the template dict)
        % Lookahead to avoid over-consuming
        (   Ts = [NextT|RestTs], \+ var(NextT)
        ->  % Optimization: find the first split that matches the next constant part
            % and satisfies the variable extraction. This avoids exponential backtracking.
            once((
                append(VarTokens, [NextI|Rest], Instance),
                match_part(NextI, NextT, VMIn, VM1, Templates, AllowVars),
                extract_value_from_parts(VarTokens, T, VM1, VM2, Templates, false, AllowVars, Depth)
            )),
            match_instance_to_template_acc(Rest, RestTs, VM2, VMOut, Templates, AllowVars, Depth)
        ;   Ts = []
        ->  VarTokens = Instance,
            VarTokens \== [],
            extract_value_from_parts(VarTokens, T, VMIn, VMOut, Templates, false, AllowVars, Depth)
        ;   % Next part is also a variable, must try all splits
            once(append(VarTokens, Rest, Instance)),
            VarTokens \== [],
            extract_value_from_parts(VarTokens, T, VMIn, VM1, Templates, false, AllowVars, Depth),
            match_instance_to_template_acc(Rest, Ts, VM1, VMOut, Templates, AllowVars, Depth)
        )
    ).

% Semantics: Second Pass
second_pass(Sections, NewSections) :-
    % Collect all templates from all sections first
    findall(Dict, (member(S, Sections), get_dicts(S, Dicts), member(Dict, Dicts)), UserDicts),
    findall(SystemDict, le_system_template(SystemDict), SystemDicts),
    append(UserDicts, SystemDicts, AllDicts),
    % Sort templates: meta-templates first, then by specificity
    sort_templates(AllDicts, SortedDicts),
    maplist(second_pass_section(SortedDicts), Sections, NewSections).

sort_templates(Dicts, Sorted) :-
    partition(is_meta_template, Dicts, Meta, Regular),
    map_list_to_pairs(template_specificity, Regular, Pairs),
    keysort(Pairs, SortedPairs),
    reverse(SortedPairs, RevSortedPairs),
    pairs_values(RevSortedPairs, SortedRegular),
    append(Meta, SortedRegular, Sorted).

template_specificity(dict(_, _, WordsAndVars), Score) :-
    findall(1, (member(W, WordsAndVars), atom(W)), Words),
    length(Words, Score).

is_meta_template(dict(_, _, WordsAndVars)) :-
    member(W, WordsAndVars),
    (W == that ; W == says).

get_dicts(predicates(Ds), Ds).
get_dicts(templates(Ds), Ds).
get_dicts(fluents(Ds), Ds).
get_dicts(events(Ds), Ds).
get_dicts(meta(Ds), Ds).
get_dicts(_, []).

second_pass_section(Templates, kb(Name, Content, Start, End), kb(Name, NewContent, Start, End)) :-
    second_pass_content(Content, Templates, NewContent).
second_pass_section(Templates, ontology(Content, Start, End), ontology(NewContent, Start, End)) :-
    maplist(second_pass_ontology_item(Templates), Content, NewContent).
second_pass_section(Templates, scenario(Name, Content, Start, End), scenario(Name, NewContent, Start, End)) :-
    maplist(second_pass_scenario_item(Templates), Content, NewContent).
second_pass_section(Templates, query(Name, Content, Start, End), query(Name, NewContent, Start, End)) :-
    maplist(second_pass_query_item(Templates), Content, NewContent).
second_pass_section(_, S, S). % Keep other sections as is

second_pass_content(Items, Templates, NewItems) :-
    maplist(second_pass_item(Templates), Items, NewItems).

second_pass_item(Templates, rule(Head, BodyTokens, Start, End), clause(NewHead, NewBody, Start, End)) :-
    (   parse_literal(Head, Templates, [], VM1, NewHead, true)
    ->  parse_body(BodyTokens, Templates, VM1, _VMOut, NewBody)
    ;   NewHead = unknown_template(Head),
        parse_body(BodyTokens, Templates, [], _VMOut, NewBody)
    ).
second_pass_item(Templates, fact(Head, Start, End), clause(NewHead, true, Start, End)) :-
    (   parse_literal(Head, Templates, [], _VM1, NewHead, true)
    ->  true
    ;   NewHead = unknown_template(Head)
    ).

second_pass_ontology_item(Templates, fact(Head, Start, End), clause(NewHead, true, Start, End)) :-
    (   match_is_a(Head, Type, SuperType, TypeAtom, SuperTypeAtom, [], _VMOut, true)
    ->  (   NewHead = is_a(Type, SuperType),
            assertz(is_a_taxonomy_edge(TypeAtom, SuperTypeAtom, Start))
        )
    ;   parse_literal(Head, Templates, [], _VM1, NewHead, true)
    ->  true
    ;   NewHead = unknown_template(Head, Start, End)
    ).
second_pass_ontology_item(Templates, rule(Head, BodyTokens, Start, End), clause(NewHead, NewBody, Start, End)) :-
    (   parse_literal(Head, Templates, [], VM1, NewHead, true)
    ->  parse_body(BodyTokens, Templates, VM1, _VMOut, NewBody)
    ;   NewHead = unknown_template(Head, Start, End),
        parse_body(BodyTokens, Templates, [], _VMOut, NewBody)
    ).

second_pass_scenario_item(Templates, fact(Head, Start, End), clause(NewHead, true, Start, End)) :-
    (   parse_literal(Head, Templates, [], _VM1, NewHead, true)
    ->  true
    ;   NewHead = unknown_template(Head, Start, End)
    ).
second_pass_scenario_item(Templates, rule(Head, BodyTokens, Start, End), clause(NewHead, NewBody, Start, End)) :-
    (   parse_literal(Head, Templates, [], VM1, NewHead, true)
    ->  parse_body(BodyTokens, Templates, VM1, _VMOut, NewBody)
    ;   NewHead = unknown_template(Head, Start, End),
        parse_body(BodyTokens, Templates, [], _VMOut, NewBody)
    ).

second_pass_query_item(Templates, fact(Head, Start, End), clause(NewHead, true, Start, End)) :-
    (   parse_literal(Head, Templates, [], _VM1, NewHead, true)
    ->  true
    ;   NewHead = unknown_template(Head, Start, End)
    ).
second_pass_query_item(Templates, rule(Head, BodyTokens, Start, End), clause(NewHead, NewBody, Start, End)) :-
    (   parse_literal(Head, Templates, [], VM1, NewHead, true)
    ->  parse_body(BodyTokens, Templates, VM1, _VMOut, NewBody)
    ;   NewHead = unknown_template(Head, Start, End),
        parse_body(BodyTokens, Templates, [], _VMOut, NewBody)
    ).

match_is_a(Parts, Type, SuperType, VMIn, VMOut, AllowVars) :-
    match_is_a(Parts, Type, SuperType, _, _, VMIn, VMOut, AllowVars).

match_is_a(Parts, Type, SuperType, TypeAtom, SuperTypeAtom, VMIn, VMOut, AllowVars) :-
    maplist(extract_simple_word, Parts, Words),
    once((
        append(TypeWords, [is, a | SuperTypeWords], Words)
    ;   append(TypeWords, [is, an | SuperTypeWords], Words)
    )),
    TypeWords \== [], SuperTypeWords \== [],
    (   SuperTypeWords = [_] -> true
    ;   SuperTypeWords = [Art, _], is_article(Art) -> true
    ;   fail
    ),
    extract_words_to_value(TypeWords, Type, VMIn, VM1, AllowVars),
    extract_words_to_value(SuperTypeWords, SuperType, VM1, VMOut, AllowVars),
    extract_name_type(TypeWords, TypeAtom, _),
    extract_name_type(SuperTypeWords, SuperTypeAtom, _).

extract_words_to_value(Words, Value, VMIn, VMOut, AllowVars) :-
    (   AllowVars == true, extract_var_name(Words, Name)
    ->  unify_with_vmap(Name, Value, VMIn, VMOut)
    ;   Words = [Value], (number(Value) ; string(Value))
    ->  VMOut = VMIn
    ;   atomic_list_concat(Words, ' ', Value),
        VMOut = VMIn
    ).

parse_literal(Tokens, Templates, VMIn, VMOut, Literal) :-
    parse_literal(Tokens, Templates, VMIn, VMOut, Literal, true).

parse_literal(Tokens, Templates, VMIn, VMOut, Literal, AllowVars) :-
    % length(Templates, L), writeln(templates_count(L, Tokens)),
    once(parse_literal_real(Tokens, Templates, VMIn, VMOut, Literal, AllowVars)).

parse_literal_real(Tokens, Templates, VMIn, VMOut, Literal, AllowVars) :-
    (   match_is_a(Tokens, Type, SuperType, VMIn, VMOut, AllowVars)
    ->  Literal = is_a(Type, SuperType)
    ;   maplist(extract_simple_word, Tokens, Words),
        member(dict(FunctorArgs, NTs, WordsAndVars), Templates),
        \+ (FunctorArgs = [le_is|_]),
        template_could_match(Words, WordsAndVars),
        copy_term(dict(FunctorArgs, NTs, WordsAndVars), dict(FunctorArgsCopy, _, WordsAndVarsCopy)),
        match_instance_to_template(Tokens, WordsAndVarsCopy, VMIn, VMOut, Templates, AllowVars, 0),
        Literal =.. FunctorArgsCopy
    ->  true
    ;   % Fallback to le_is
        member(dict([le_is, V1, V2], NTs, WordsAndVars), Templates),
        copy_term(dict([le_is, V1, V2], NTs, WordsAndVars), dict([le_is, V1Copy, V2Copy], _, WordsAndVarsCopy)),
        match_instance_to_template(Tokens, WordsAndVarsCopy, VMIn, VMOut, Templates, AllowVars, 0)
    ->  Literal = le_is(V1Copy, V2Copy)
    ).

template_could_match(Words, WordsAndVars) :-
    forall((member(W, WordsAndVars), atom(W), \+ is_reserved(W), \+ memberchk(W, [a, an, the, is])),
           memberchk(W, Words)).

% Simple Expression Parser
parse_expression(Parts, VMIn, VMOut, Templates, Expr) :-
    parse_expression(Parts, VMIn, VMOut, Templates, Expr, true).

parse_expression(Parts, VMIn, VMOut, Templates, Expr, AllowVars) :-
    % Optimization: only try parsing as expression if it looks like one
    (   member(Part, Parts), (Part = punct(Op, _) ; Part = punctuation(Op, _)), member(Op, ['+', '-', '*', '/', '(', ')', '=', '>', '<', '>=', '<=', '=<'])
    ->  maplist(part_to_token, Parts, Tokens),
        phrase(expr_logic(Expr, VMIn, VMOut, Templates, AllowVars), Tokens)
    ;   fail
    ).

part_to_token(word(W), word(W, loc(0,0))).
part_to_token(number(N), number(N, loc(0,0))).
part_to_token(punct(P), punctuation(P, loc(0,0))).
part_to_token(word(W, L), word(W, L)).
part_to_token(number(N, L), number(N, L)).
part_to_token(punct(P, L), punctuation(P, L)).
part_to_token(punctuation(P, L), punctuation(P, L)).
part_to_token(expr(E), expr(E)).

expr_logic(E, VMIn, VMOut, T, AllowVars) --> term_logic(T1, VMIn, VM1, T, AllowVars), expr_tail(T1, E, VM1, VMOut, T, AllowVars).
expr_tail(T1, E, VMIn, VMOut, T, AllowVars) --> [punctuation(Op, _)], { member(Op, ['+', '-']) }, term_logic(T2, VMIn, VM1, T, AllowVars), { E1 =.. [Op, T1, T2] }, expr_tail(E1, E, VM1, VMOut, T, AllowVars).
expr_tail(E, E, VM, VM, _, _) --> [].

term_logic(T, VMIn, VMOut, Ts, AllowVars) --> factor_logic(F1, VMIn, VM1, Ts, AllowVars), term_tail(F1, T, VM1, VMOut, Ts, AllowVars).
term_tail(F1, T, VMIn, VMOut, Ts, AllowVars) --> [punctuation(Op, _)], { member(Op, ['*', '/']) }, factor_logic(F2, VMIn, VM1, Ts, AllowVars), { T1 =.. [Op, F1, F2] }, term_tail(T1, T, VM1, VMOut, Ts, AllowVars).
term_tail(T, T, VM, VM, _, _) --> [].

factor_logic(F, VMIn, VMOut, Ts, AllowVars) --> [punctuation('(', _)], expr_logic(F, VMIn, VMOut, Ts, AllowVars), [punctuation(')', _)].
factor_logic(F, VMIn, VMOut, Ts, AllowVars) --> [expr(E)], { parse_expression(E, VMIn, VMOut, Ts, F, AllowVars) }.
factor_logic(V, VMIn, VMOut, _, true) --> [word(W, _)], { unify_with_vmap(W, V, VMIn, VMOut, true) }.
factor_logic(W, VM, VM, _, false) --> [word(W, _)], { is_proper_name_atom(W) }.
factor_logic(N, VM, VM, _, _) --> [number(N, _)].

% Structured Body Parsing
parse_body(Tokens, Templates, VMIn, VMOut, StructuredBody) :-
    tokens_to_lines(Tokens, Lines),
    once(lines_to_tree(Tokens, Lines, Templates, VMIn, VMOut, StructuredBody)).

tokens_to_lines(Tokens, Lines) :-
    tokens_to_lines_acc(Tokens, [], Lines).

tokens_to_lines_acc([], Acc, Lines) :- reverse(Acc, Lines).
tokens_to_lines_acc([indent(N, _)|Ts], Acc, Lines) :- !,
    get_line_tokens(Ts, LineTokens, Rest),
    (   LineTokens == []
    ->  tokens_to_lines_acc(Rest, Acc, Lines)
    ;   LineTokens = [word(that, _)|_], Acc = [line(PrevN, PrevTokens)|RestAcc]
    ->  append(PrevTokens, LineTokens, NewPrevTokens),
        tokens_to_lines_acc(Rest, [line(PrevN, NewPrevTokens)|RestAcc], Lines)
    ;   tokens_to_lines_acc(Rest, [line(N, LineTokens)|Acc], Lines)
    ).
tokens_to_lines_acc(Ts, Acc, Lines) :-
    get_line_tokens(Ts, LineTokens, Rest),
    (   LineTokens == []
    ->  tokens_to_lines_acc(Rest, Acc, Lines)
    ;   LineTokens = [word(that, _)|_], Acc = [line(PrevN, PrevTokens)|RestAcc]
    ->  append(PrevTokens, LineTokens, NewPrevTokens),
        tokens_to_lines_acc(Rest, [line(PrevN, NewPrevTokens)|RestAcc], Lines)
    ;   tokens_to_lines_acc(Rest, [line(0, LineTokens)|Acc], Lines)
    ).

get_line_tokens([], [], []) :- !.
get_line_tokens([indent(N, Loc)|Ts], [], [indent(N, Loc)|Ts]) :- !.
get_line_tokens([T|Ts], [T|LTs], Rest) :-
    get_line_tokens(Ts, LTs, Rest).

lines_to_tree(_Tokens, Lines, Templates, VMIn, VMOut, Tree) :-
    lines_to_hierarchy(Lines, Hierarchy),
    hierarchy_to_logic(Hierarchy, Templates, VMIn, VMOut, Tree).

lines_to_hierarchy([], []).
lines_to_hierarchy([line(N, Tokens)|Lines], [node(N, Tokens, Children)|RestNodes]) :-
    take_nested_hierarchy(Lines, N, Nested, Remaining),
    lines_to_hierarchy(Nested, Children),
    % format('Node ~w has ~w children~n', [Tokens, Children]),
    lines_to_hierarchy(Remaining, RestNodes).

take_nested_hierarchy([line(M, Tokens)|Lines], N, [line(M, Tokens)|Nested], Remaining) :-
    M > N, !,
    take_nested_hierarchy(Lines, N, Nested, Remaining).
take_nested_hierarchy(Lines, _, [], Lines).

hierarchy_to_logic([], _, VM, VM, true) :- !.
hierarchy_to_logic([node(_, Tokens, Children)|RestNodes], Templates, VMIn, VMOut, Logic) :-
    strip_op(Tokens, _Op, RestTokens),
    once(parse_node(RestTokens, Children, Templates, VMIn, VM1, FirstLogic)),
    fold_nodes(FirstLogic, RestNodes, Templates, VM1, VMOut, Logic).

fold_nodes(Acc, [], _, VM, VM, Acc).
fold_nodes(Acc, [node(_, Tokens, Children)|Rest], Templates, VMIn, VMOut, Logic) :-
    strip_op(Tokens, Op, RestTokens),
    once(parse_node(RestTokens, Children, Templates, VMIn, VM1, ChildLogic)),
    NewAcc =.. [Op, Acc, ChildLogic],
    once(fold_nodes(NewAcc, Rest, Templates, VM1, VMOut, Logic)).

strip_op([word(if, _)|Rest], and, Rest) :- !.
strip_op([word(Op, _)|Rest], Op, Rest) :- (Op == and ; Op == or), !.
strip_op(Tokens, and, Tokens).

parse_node([], Children, Templates, VMIn, VMOut, Logic) :- !,
    hierarchy_to_logic(Children, Templates, VMIn, VMOut, Logic).
parse_node(Tokens, Children, Templates, VMIn, VMOut, Logic) :-
    % format('Parse node: ~w~n', [Tokens]),
    (   is_forall(Tokens)
    ->  split_forall_children(Children, CondNodes, ConsNodes),
        hierarchy_to_logic(CondNodes, Templates, VMIn, VM1, CondLogic),
        hierarchy_to_logic(ConsNodes, Templates, VM1, VMOut, ConsLogic),
        Logic = forall(CondLogic, ConsLogic)
    ;   is_not_the_case(Tokens)
    ->  hierarchy_to_logic(Children, Templates, VMIn, VMOut, SubLogic),
        Logic = not(SubLogic)
    ;   is_aggregate(Tokens, Op, ElementTokens, ResultTokens)
    ->  build_aggregate_list(ElementTokens, VMIn, VM1, ElementList),
        build_aggregate_list(ResultTokens, VM1, VM2, ResultList),
        once(hierarchy_to_logic(Children, Templates, VM2, VMOut, Goal)),
        Logic =.. [Op, [each|ElementList], Goal, ResultList]
    ;   parse_literal(Tokens, Templates, VMIn, VM1, Literal)
    ->  fold_nodes(Literal, Children, Templates, VM1, VMOut, Logic)
    ;   match_is_a(Tokens, Type, SuperType, VMIn, VM1, true)
    ->  Literal = is_a(Type, SuperType),
        fold_nodes(Literal, Children, Templates, VM1, VMOut, Logic)
    ;   phrase(template_instance(Instance), Tokens)
    ->  Literal = unknown_template(Instance),
        fold_nodes(Literal, Children, Templates, VMIn, VMOut, Logic)
    ;   Literal = unknown_tokens(Tokens),
        fold_nodes(Literal, Children, Templates, VMIn, VMOut, Logic)
    ).



is_aggregate(Tokens, Op, ElementTokens, ResultTokens) :-
    append(Rest, [word(such, _), word(that, _)], Tokens),
    append(ResultTokens, [word(is, _), word(the, _), word(Op, _), word(of, _), word(each, _)|ElementTokens], Rest),
    member(Op, [sum, count, average, min, max]),
    !.

build_aggregate_list(Tokens, VMIn, VMOut, List) :-
    maplist(extract_simple_word, Tokens, Words),
    (   extract_var_name(Words, Name)
    ->  unify_with_vmap(Name, Var, VMIn, VMOut, true),
        List = [Var]
    ;   \+ is_proper_name(Words),
        atomic_list_concat(Words, ' ', Name),
        unify_with_vmap(Name, Var, VMIn, VMOut, true),
        List = [Var]
    ).

is_forall(Tokens) :-
    maplist(extract_word_atom, Tokens, Atoms),
    (   Atoms = [for, all, cases, in, which]
    ;   Atoms = [and, for, all, cases, in, which]
    ).

split_forall_children([], [], []).
split_forall_children([node(_, Tokens, Children)|Rest], [], Consequences) :-
    is_it_the_case(Tokens), !,
    (   Children == [] -> Consequences = Rest
    ;   Consequences = Children
    ).
split_forall_children([Node|Rest], [Node|Conds], Cons) :-
    split_forall_children(Rest, Conds, Cons).

is_it_the_case(Tokens) :-
    maplist(extract_word_atom, Tokens, Atoms),
    (   Atoms = [it, is, the, case, that]
    ;   Atoms = [and, it, is, the, case, that]
    ).

is_not_the_case(Tokens) :-
    maplist(extract_word_atom, Tokens, Atoms),
    (   Atoms = [it, is, not, the, case, that]
    ;   Atoms = [not, the, case, that]
    ).

extract_word_atom(word(A, _), A) :- !.
extract_word_atom(punctuation(P, _), P) :- !.
extract_word_atom(number(N, _), N) :- !.
extract_word_atom(_, unknown).

:- dynamic is_a_taxonomy_edge/3.
