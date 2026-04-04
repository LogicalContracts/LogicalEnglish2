:- module(le_grammar, [parse_le/2, parse_le/3, parse_le_file/2, parse_le_file/3, test_all/0]).
:- use_module(tokenizer).
:- use_module(library(pcre)).
:- use_module(le_system_templates).

:- thread_local issue/1.

% Main entry point
parse_le(String, Doc) :-
    parse_le(String, Doc, _Issues).

parse_le(String, doc(NewSections), Issues) :-
    retractall(issue(_)),
    % Replace non-standard whitespace with space to help tokenizer
    re_replace("\u2002"/g, " ", String, CleanString),
    tokenize(CleanString, Tokens),
    % Filter out comments
    exclude(is_comment, Tokens, CleanTokens),
    (   phrase(document(Doc), CleanTokens, Remainder)
    ->  (   Remainder \== []
        ->  report_issue(error, 'Unexpected tokens at end of document', Remainder)
        ;   true
        ),
        (   Doc = doc(Sections), Sections \== []
        ->  second_pass(Sections, NewSections)
        ;   Doc = doc([], Content)
        ->  second_pass_content(Content, [], NewContent),
            NewSections = [kb(anonymous, NewContent)]
        ;   NewSections = []
        )
    ;   report_issue(error, 'Failed to parse document', CleanTokens),
        NewSections = []
    ),
    findall(I, retract(issue(I)), Issues).

parse_le_file(File, AST) :-
    parse_le_file(File, AST, _Issues).

parse_le_file(File, AST, Issues) :-
    read_file_to_string(File, String, []),
    parse_le(String, AST, Issues).

report_issue(_Type, Message, Tokens) :-
    (   is_list(Tokens), Tokens = [T|_]
    ->  (   T =.. [_, _, loc(Pos, _)] -> true
        ;   T =.. [_, loc(Pos, _)] -> true
        ;   Pos = 0
        )
    ;   (   Tokens =.. [_, _, loc(Pos, _)] -> true
        ;   Tokens =.. [_, loc(Pos, _)] -> true
        ;   Pos = 0
        )
    ),
    assertz(issue(error(Message, Pos))). % Using error/2 as requested, can be extended to Type(Message, Pos)

is_comment(line_comment(_, _)).
is_comment(multi_comment(_, _)).

% Helpers for non-significant indentation
any_indent --> [indent(_, _)], !, any_indent.
any_indent --> [].

t(word(W)) --> any_indent, [word(W, _)].
t(number(N)) --> any_indent, [number(N, _)].
t(date(D)) --> any_indent, [date(D, _)].
t(string(S)) --> any_indent, [quoteString(S, _)].
t(string(S)) --> any_indent, [doubleQuoteString(S, _)].
t(punct(P)) --> any_indent, [punctuation(P, _)].

% DCG
document(doc(Sections)) --> sections(Sections), any_indent, { Sections \== [] }.
document(doc([], Content)) --> kb_content(Content), any_indent.

sections([S|Ss]) --> section(S), !, sections(Ss).
sections([error_section(Tokens)|Ss]) -->
    \+ next_section_start,
    consume_until_next_section(Tokens),
    { Tokens \== [], report_issue(error, 'Invalid or unknown section', Tokens) },
    sections(Ss).
sections([]) --> [].

consume_until_next_section([T|Ts]) -->
    \+ next_section_start,
    [T], !,
    consume_until_next_section(Ts).
consume_until_next_section([]) --> [].

section(target_language(L)) -->
    t(word(the)), t(word(target)), t(word(language)), t(word(is)),
    ( t(punct(':')) | [] ),
    t(word(L)), t(punct('.')).

section(predicates(Dicts)) -->
    t(word(the)), t(word(predicates)), t(word(are)), t(punct(':')),
    templates(Ts),
    { templatesToDicts(Ts, Dicts) }.

section(templates(Dicts)) -->
    t(word(the)), t(word(templates)), t(word(are)), t(punct(':')),
    templates(Ts),
    { templatesToDicts(Ts, Dicts) }.

section(fluents(Dicts)) -->
    t(word(the)), t(word(fluents)), t(word(are)), t(punct(':')),
    templates(Ts),
    { templatesToDicts(Ts, Dicts) }.

section(events(Dicts)) -->
    t(word(the)), t(word(event)), t(word(predicates)), t(word(are)), t(punct(':')),
    templates(Ts),
    { templatesToDicts(Ts, Dicts) }.

section(meta(Dicts)) -->
    t(word(the)), t(word(meta)), t(word(predicates)), t(word(are)), t(punct(':')),
    templates(Ts),
    { templatesToDicts(Ts, Dicts) }.

section(ontology(Ts)) -->
    t(word(the)), t(word(ontology)), ( t(word(is)) | t(word(includes)) ), t(punct(':')),
    kb_content(Ts).

section(kb(Name, Content)) -->
    t(word(the)), t(word(knowledge)), t(word(base)),
    kb_name(NameWords),
    t(word(includes)), t(punct(':')),
    { atomic_list_concat(NameWords, '', Name) },
    kb_content(Content).

section(scenario(Name, Content)) -->
    t(word(scenario)), scenario_name(NameWords), t(word(is)), t(punct(':')),
    { atomic_list_concat(NameWords, '', Name) },
    kb_content(Content).

section(query(Name, Content)) -->
    t(word(query)), query_name(NameWords), t(word(is)), t(punct(':')),
    { atomic_list_concat(NameWords, '', Name) },
    kb_content(Content).

kb_name([W|Ws]) --> \+ (any_indent, [word(includes, _)]), name_part(W), !, kb_name(Ws).
kb_name([]) --> [].

scenario_name([W|Ws]) --> \+ (any_indent, [word(is, _)]), name_part(W), !, scenario_name(Ws).
scenario_name([]) --> [].

query_name([W|Ws]) --> \+ (any_indent, [word(is, _)]), name_part(W), !, query_name(Ws).
query_name([]) --> [].

name_part(W) --> t(word(W)).
name_part(N) --> t(number(N)).
name_part(P) --> t(punct(P)).

% Templates
templates([T|Ts]) -->
    \+ next_section_start,
    (   template(T) -> !
    ;   consume_until_template_terminator(Tokens),
        { T = error_template(Tokens), report_issue(error, 'Invalid template', Tokens) }
    ),
    ( t(punct(',')), !, templates(Ts)
    | t(punct('.')), !, ( templates(Ts) | { Ts = [] } )
    | { Ts = [] }
    ).

consume_until_template_terminator([T|Ts]) -->
    \+ is_template_terminator,
    \+ next_section_start,
    [T], !,
    consume_until_template_terminator(Ts).
consume_until_template_terminator([]) --> [].

template([P|Ps]) -->
    template_part(P),
    template_tail(Ps).

template_tail([P|Ps]) -->
    \+ is_template_terminator,
    \+ next_section_start,
    template_part(P), !,
    template_tail(Ps).
template_tail([]) --> [].

is_template_terminator --> any_indent, [punctuation('.', _)], \+ [number(_, _)].
is_template_terminator --> any_indent, [punctuation(',', _)].

template_part(word(W)) --> t(word(W)).
template_part(number(N)) --> t(number(N)).
template_part(string(S)) --> t(string(S)).
template_part(var(Words)) --> t(punct('*')), words(Words), t(punct('*')).
template_part(punct(P)) --> t(punct(P)), { \+ member(P, ['*', '[', ']', '.', ',', '(', ')']) }.
template_part(punct('(')) --> t(punct('(')).
template_part(punct(')')) --> t(punct(')')).

is_terminator --> any_indent, [punctuation('.', _)], \+ [number(_, _)].
is_terminator --> any_indent, [punctuation(',', _)].
is_terminator --> any_indent, [punctuation(']', _)].
is_terminator --> any_indent, [punctuation(')', _)].
is_terminator --> any_indent, [word(if, _)].
is_terminator --> [indent(_, _), word(and, _)].
is_terminator --> [indent(_, _), word(or, _)].

next_section_start --> any_indent, [word(the, _), word(knowledge, _), word(base, _)].
next_section_start --> any_indent, [word(the, _), word(ontology, _)].
next_section_start --> any_indent, [word(the, _), word(templates, _)].
next_section_start --> any_indent, [word(the, _), word(predicates, _)].
next_section_start --> any_indent, [word(the, _), word(fluents, _)].
next_section_start --> any_indent, [word(the, _), word(event, _)].
next_section_start --> any_indent, [word(the, _), word(meta, _)].
next_section_start --> any_indent, [word(scenario, _)].
next_section_start --> any_indent, [word(query, _)].

% KB Content
kb_content([Item|Items]) -->
    \+ next_section_start,
    (   kb_item(Item) -> !
    ;   consume_until_kb_terminator(Tokens),
        { Item = error_item(Tokens), report_issue(error, 'Invalid KB item', Tokens) }
    ),
    kb_content(Items).
kb_content([]) --> [].

consume_until_kb_terminator([T|Ts]) -->
    \+ is_kb_terminator,
    \+ next_section_start,
    [T], !,
    consume_until_kb_terminator(Ts).
consume_until_kb_terminator([T]) --> [T]. % Consume the terminator if possible

is_kb_terminator --> any_indent, [punctuation('.', _)], \+ [number(_, _)].

kb_item(rule(Head, Body)) -->
    template_instance(Head),
    t(word(if)),
    body(Body).
kb_item(fact(Head)) -->
    template_instance(Head),
    t(punct('.')).

% Template Instance
template_instance([P|Ps]) -->
    template_instance_part(P),
    template_instance_tail(Ps).

template_instance_tail([P|Ps]) -->
    \+ is_terminator,
    \+ next_section_start,
    template_instance_part(P), !,
    template_instance_tail(Ps).
template_instance_tail([]) --> [].

template_instance_part(word(W, Loc)) --> any_indent, [word(W, Loc)].
template_instance_part(number(N, Loc)) --> any_indent, [number(N, Loc)].
template_instance_part(date(D, Loc)) --> any_indent, [date(D, Loc)].
template_instance_part(string(S, Loc)) --> any_indent, [quoteString(S, Loc)].
template_instance_part(string(S, Loc)) --> any_indent, [doubleQuoteString(S, Loc)].
template_instance_part(list(L)) --> t(punct('[')), list_elements(L), t(punct(']')).
template_instance_part(expr(E)) --> t(punct('(')), template_instance(E), t(punct(')')).
template_instance_part(punct(P, Loc)) --> any_indent, [punctuation(P, Loc)], { \+ member(P, ['[', ']', '.', ',', '(', ')']) }.
template_instance_part(punct('(', Loc)) --> any_indent, [punctuation('(', Loc)].
template_instance_part(punct(')', Loc)) --> any_indent, [punctuation(')', Loc)].

list_elements([E|Es]) --> template_instance(E), ( t(punct(',')), !, list_elements(Es) | { Es = [] } ).
list_elements([]) --> [].

body(Body) --> body_tokens(Body), t(punct('.')).
body_tokens([T|Ts]) --> \+ is_body_terminator, body_token(T), !, body_tokens(Ts).
body_tokens([]) --> [].

is_body_terminator --> any_indent, [punctuation('.', _)], \+ [number(_, _)].

body_token(T) --> [T], { is_token(T) }.

is_token(indent(_, _)).
is_token(word(_, _)).
is_token(number(_, _)).
is_token(date(_, _)).
is_token(quoteString(_, _)).
is_token(doubleQuoteString(_, _)).
is_token(punctuation(_, _)).
is_token(line_comment(_, _)).
is_token(multi_comment(_, _)).

% Helpers
words([W|Ws]) --> t(word(W)), !, words(Ws).
words([]) --> [].

is_article(a).
is_article(an).
is_article(the).
is_article(some).

is_auxiliary(other).
is_auxiliary(another).
is_auxiliary(first).
is_auxiliary(second).
is_auxiliary(third).
is_auxiliary(fourth).
is_auxiliary(fifth).

is_proper_name_atom(Atom) :-
    atom(Atom),
    atom_length(Atom, L), L > 1,
    atom_codes(Atom, [C|_]),
    code_type(C, upper),
    \+ is_all_caps(Atom).

is_all_caps(Atom) :-
    atom_codes(Atom, Codes),
    maplist(is_upper_code, Codes).

is_upper_code(C) :- code_type(C, upper).
is_upper_code(C) :- code_type(C, digit).
is_upper_code(0'_).

is_proper_name(Words) :-
    last(Words, Last),
    is_proper_name_atom(Last).

% Semantics: Second Pass
second_pass(Sections, NewSections) :-
    % Collect all templates from all sections first
    findall(Dict, (member(S, Sections), get_dicts(S, Dicts), member(Dict, Dicts)), UserDicts),
    findall(SystemDict, le_system_template(SystemDict), SystemDicts),
    append(UserDicts, SystemDicts, AllDicts),
    maplist(second_pass_section(AllDicts), Sections, NewSections).

get_dicts(predicates(Ds), Ds).
get_dicts(templates(Ds), Ds).
get_dicts(fluents(Ds), Ds).
get_dicts(events(Ds), Ds).
get_dicts(meta(Ds), Ds).
get_dicts(_, []).

second_pass_section(Templates, kb(Name, Content), kb(Name, NewContent)) :-
    second_pass_content(Content, Templates, NewContent).
second_pass_section(Templates, ontology(Content), ontology(NewContent)) :-
    maplist(second_pass_ontology_item(Templates), Content, NewContent).
second_pass_section(Templates, scenario(Name, Content), scenario(Name, NewContent)) :-
    maplist(second_pass_scenario_item(Templates), Content, NewContent).
second_pass_section(Templates, query(Name, Content), query(Name, NewContent)) :-
    maplist(second_pass_query_item(Templates), Content, NewContent).
second_pass_section(_, S, S). % Keep other sections as is

second_pass_content(Items, Templates, NewItems) :-
    maplist(second_pass_item(Templates), Items, NewItems).

second_pass_item(Templates, rule(Head, BodyTokens), clause(NewHead, NewBody)) :-
    (   transform_instance(Head, Templates, [], VM1, NewHead, true)
    ->  parse_body(BodyTokens, Templates, VM1, _VMOut, NewBody)
    ;   match_is_a(Head, Type, SuperType, [], VM1, true)
    ->  NewHead = is_a(Type, SuperType),
        parse_body(BodyTokens, Templates, VM1, _VMOut, NewBody)
    ;   NewHead = unknown_template(Head),
        report_issue(error, 'Unknown template in rule head', Head),
        parse_body(BodyTokens, Templates, [], _VMOut, NewBody)
    ).
second_pass_item(Templates, fact(Head), clause(NewHead, true)) :-
    (   transform_instance(Head, Templates, [], _VMOut, NewHead, true)
    ->  true
    ;   match_is_a(Head, Type, SuperType, [], _VMOut, true)
    ->  NewHead = is_a(Type, SuperType)
    ;   NewHead = unknown_template(Head),
        report_issue(error, 'Unknown template in fact', Head)
    ).
second_pass_item(_, error_item(Tokens), error_item(Tokens)).

second_pass_ontology_item(Templates, fact(Head), Item) :-
    (   match_is_a(Head, Type, SuperType, [], _VMOut, false)
    ->  concatenate_if_list(Type, CType),
        concatenate_if_list(SuperType, CSuperType),
        Item = is_a(CType, CSuperType)
    ;   transform_instance(Head, Templates, [], _VMOut, RawItem, false)
    ->  RawItem =.. [Functor|Args],
        maplist(concatenate_if_list, Args, CArgs),
        Item =.. [Functor|CArgs]
    ;   Item = unknown_template(Head),
        report_issue(error, 'Unknown template in ontology fact', Head)
    ).
second_pass_ontology_item(Templates, rule(Head, Body), Item) :-
    second_pass_item(Templates, rule(Head, Body), Item).

concatenate_if_list(Val, Result) :-
    is_list(Val),
    maplist(atomic, Val),
    !,
    atomic_list_concat(Val, '', Result).
concatenate_if_list(Val, Val).

second_pass_scenario_item(Templates, fact(Head), Item) :-
    (   transform_instance(Head, Templates, [], _VMOut, NewHead, false)
    ->  Item = NewHead
    ;   match_is_a(Head, Type, SuperType, [], _VMOut, false)
    ->  Item = is_a(Type, SuperType)
    ;   Item = unknown_template(Head),
        report_issue(error, 'Unknown template in scenario fact', Head)
    ).
second_pass_scenario_item(Templates, rule(Head, BodyTokens), clause(NewHead, NewBody)) :-
    (   transform_instance(Head, Templates, [], VM1, NewHead, true)
    ->  parse_body(BodyTokens, Templates, VM1, _VMOut, NewBody)
    ;   match_is_a(Head, Type, SuperType, [], VM1, true)
    ->  NewHead = is_a(Type, SuperType),
        parse_body(BodyTokens, Templates, VM1, _VMOut, NewBody)
    ;   NewHead = unknown_template(Head),
        report_issue(error, 'Unknown template in scenario rule head', Head),
        parse_body(BodyTokens, Templates, [], _VMOut, NewBody)
    ).
second_pass_scenario_item(_, error_item(Tokens), error_item(Tokens)).

second_pass_query_item(Templates, fact(Head), Item) :-
    (   transform_instance(Head, Templates, [], _VMOut, NewHead, true)
    ->  Item = NewHead
    ;   match_is_a(Head, Type, SuperType, [], _VMOut, true)
    ->  Item = is_a(Type, SuperType)
    ;   Item = unknown_template(Head),
        report_issue(error, 'Unknown template in query', Head)
    ).
second_pass_query_item(Templates, rule(Head, BodyTokens), clause(NewHead, NewBody)) :-
    (   transform_instance(Head, Templates, [], VM1, NewHead, true)
    ->  parse_body(BodyTokens, Templates, VM1, _VMOut, NewBody)
    ;   match_is_a(Head, Type, SuperType, [], VM1, true)
    ->  NewHead = is_a(Type, SuperType),
        parse_body(BodyTokens, Templates, VM1, _VMOut, NewBody)
    ;   NewHead = unknown_template(Head),
        report_issue(error, 'Unknown template in query rule head', Head),
        parse_body(BodyTokens, Templates, [], _VMOut, NewBody)
    ).
second_pass_query_item(_, error_item(Tokens), error_item(Tokens)).

match_is_a(Parts, Type, SuperType, VMIn, VMOut, AllowVars) :-
    maplist(extract_simple_word, Parts, Words),
    (   append(TypeWords, [is, a | SuperTypeWords], Words)
    ;   append(TypeWords, [is, an | SuperTypeWords], Words)
    ;   append(TypeWords, [is, the | SuperTypeWords], Words)
    ),
    TypeWords \== [], SuperTypeWords \== [],
    extract_words_to_value(TypeWords, Type, VMIn, VM1, AllowVars),
    extract_words_to_value(SuperTypeWords, SuperType, VM1, VMOut, AllowVars).

extract_words_to_value(Words, Value, VMIn, VMOut, AllowVars) :-
    (   AllowVars == true, extract_var_name(Words, Name)
    ->  unify_with_vmap(Name, Value, VMIn, VMOut)
    ;   is_proper_name(Words)
    ->  atomic_list_concat(Words, ' ', Value), VMOut = VMIn
    ;   AllowVars == false
    ->  (Words = [Value] -> true ; Value = Words), VMOut = VMIn
    ;   extract_name_type(Words, Name, _Type),
        (AllowVars == true -> unify_with_vmap(Name, Value, VMIn, VMOut) ; Value = Name, VMOut = VMIn)
    ).

% Semantics: Templates to Dicts
templatesToDicts([], []).
templatesToDicts([T|Ts], [D|Ds]) :-
    templateToDict(T, D),
    templatesToDicts(Ts, Ds).

templateToDict(T, dict([Functor|Args], NamesTypes, WordsAndVars)) :-
    process_template_parts(T, FunctorWords, Args, NamesTypes, WordsAndVars),
    atomic_list_concat(FunctorWords, '_', Functor).

process_template_parts([], [], [], [], []).
process_template_parts([word(W, _)|Ps], [W|FWs], Args, NTs, [W|WVs]) :-
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([word(W)|Ps], [W|FWs], Args, NTs, [W|WVs]) :-
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([var(Words)|Ps], FWs, [V|Args], [V-Type|NTs], [V|WVs]) :-
    extract_name_type(Words, _Name, Type),
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([number(N, _)|Ps], [N_Atom|FWs], Args, NTs, [N|WVs]) :-
    atom_number(N_Atom, N),
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([number(N)|Ps], [N_Atom|FWs], Args, NTs, [N|WVs]) :-
    atom_number(N_Atom, N),
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([string(S, _)|Ps], [S|FWs], Args, NTs, [S|WVs]) :-
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([string(S)|Ps], [S|FWs], Args, NTs, [S|WVs]) :-
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([punct(P, _)|Ps], [P|FWs], Args, NTs, [P|WVs]) :-
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([punct(P)|Ps], [P|FWs], Args, NTs, [P|WVs]) :-
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([list(_)|Ps], FWs, [V|Args], [V-list|NTs], [V|WVs]) :-
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([expr(_)|Ps], FWs, [V|Args], [V-expr|NTs], [V|WVs]) :-
    process_template_parts(Ps, FWs, Args, NTs, WVs).

extract_name_type(Words, Name, Type) :-
    (   Words = [Art | Rest], is_article(Art) -> extract_name_type_no_art(Rest, Name, Type)
    ;   extract_name_type_no_art(Words, Name, Type)
    ).

extract_name_type_no_art(Words, Name, Type) :-
    exclude(is_auxiliary, Words, BaseWords),
    (   BaseWords = [] -> Words = [Type], Name = Type % Fallback
    ;   (   append(TypeWords, [Last], BaseWords), is_proper_name_atom(Last)
        ->  (   TypeWords = [] -> Type = Last
            ;   last(TypeWords, Type)
            ),
            atomic_list_concat(Words, '_', Name)
        ;   last(BaseWords, Type),
            atomic_list_concat(Words, '_', Name)
        )
    ).

types_compatible(T, T) :- !.
types_compatible(any, _) :- !.
types_compatible(_, any) :- !.
types_compatible(number, amount) :- !.
types_compatible(amount, number) :- !.
types_compatible(number, percentage) :- !.
types_compatible(percentage, number) :- !.
types_compatible(number, fraction) :- !.
types_compatible(fraction, number) :- !.
types_compatible(amount, percentage) :- !.
types_compatible(percentage, amount) :- !.

is_reserved(W) :- member(W, [says, that, if, and, or]).
is_generic_type(T) :- member(T, [thing, object, item, sentence, event, fluent, any]).

match_part(word(W, _), W, VM, VM, _, _) :- atom(W), !.
match_part(word(W), W, VM, VM, _, _) :- atom(W), !.
match_part(number(N, _), N, VM, VM, _, _) :- number(N), !.
match_part(number(N), N, VM, VM, _, _) :- number(N), !.
match_part(string(S, _), S, VM, VM, _, _) :- string(S), !.
match_part(string(S), S, VM, VM, _, _) :- string(S), !.
match_part(punctuation(P, _), P, VM, VM, _, _) :- atom(P), !.
match_part(punct(P, _), P, VM, VM, _, _) :- atom(P), !.
match_part(punct(P), P, VM, VM, _, _) :- atom(P), !.
match_part(Part, V, VMIn, VMOut, Templates, AllowVars) :- var(V), !, extract_value(Part, V, VMIn, VMOut, Templates, AllowVars).

extract_value_from_parts(Parts, Value, VMIn, VMOut, Templates, NoTransform, AllowVars) :-
    (   (Parts = [number(N, _)] ; Parts = [number(N)]) -> Value = N, VMOut = VMIn
    ;   (Parts = [string(S, _)] ; Parts = [string(S)]) -> Value = S, VMOut = VMIn
    ;   (Parts = [date(D, _)] ; Parts = [date(D)]) -> Value = D, VMOut = VMIn
    ;   parse_expression(Parts, VMIn, VMOut, Templates, Expr)
    ->  Value = Expr
    ;   maplist(extract_simple_word, Parts, Words),
        (   AllowVars == true, extract_var_name(Words, Name)
        ->  unify_with_vmap(Name, Value, VMIn, VMOut)
        ;   (NoTransform == false, transform_instance(Parts, Templates, VMIn, VMOut, Transformed, AllowVars))
        ->  Value = Transformed
        ;   is_proper_name(Words)
        ->  atomic_list_concat(Words, ' ', Value), VMOut = VMIn
        ;   AllowVars == false
        ->  (Words = [Value] -> true ; Value = Words), VMOut = VMIn
        ;   extract_name_type(Words, Name, _Type),
            unify_with_vmap(Name, Value, VMIn, VMOut)
        )
    ).

extract_var_name(Words, Name) :-
    (   Words = [Art | Rest], is_article(Art) -> extract_id(Rest, Name)
    ;   Words = [each | Rest] -> extract_id(Rest, Name)
    ;   Words = [which | Rest] -> extract_id(Rest, Name)
    ;   Words = [W], \+ is_proper_name_atom(W) -> Name = W
    ).

extract_id(Words, Name) :-
    (   append(_TypeWords, [ID], Words), is_id(ID)
    ->  Name = ID
    ;   atomic_list_concat(Words, '_', Name)
    ).

is_id(W) :- atom(W), (atom_length(W, 1) ; is_all_caps(W)).

unify_with_vmap(Name, Var, VMIn, VMOut) :-
    (   member(Name-ExistingVar, VMIn)
    ->  Var = ExistingVar, VMOut = VMIn
    ;   VMOut = [Name-Var|VMIn]
    ).

extract_simple_value(word(W, _), W).
extract_simple_value(number(N, _), N).
extract_simple_value(quoteString(S, _), S).
extract_simple_value(doubleQuoteString(S, _), S).
extract_simple_value(punctuation(P, _), P).
extract_simple_value(date(D, _), D).
extract_simple_value(word(W), W).
extract_simple_value(number(N), N).
extract_simple_value(string(S), S).
extract_simple_value(punct(P), P).
extract_simple_value(date(D), D).
extract_simple_value(var(Words), Atom) :- atomic_list_concat(Words, '_', Atom).

extract_simple_word(Part, Word) :-
    extract_simple_value(Part, Val),
    (   compound(Val), Val = date(Y, M, D)
    ->  format(atom(Word), '~w-~w-~w', [Y, M, D])
    ;   Word = Val
    ).

extract_value(word(W, _), Val, VMIn, VMOut, _Templates, AllowVars) :-
    (   is_proper_name_atom(W) -> Val = W, VMOut = VMIn
    ;   AllowVars == true -> unify_with_vmap(W, Val, VMIn, VMOut)
    ;   Val = W, VMOut = VMIn
    ).
extract_value(number(N, _), N, VM, VM, _, _).
extract_value(date(D, _), D, VM, VM, _, _).
extract_value(quoteString(S, _), S, VM, VM, _, _).
extract_value(doubleQuoteString(S, _), S, VM, VM, _, _).
extract_value(punctuation(P, _), P, VM, VM, _, _).
extract_value(punct(P, _), P, VM, VM, _, _).
extract_value(word(W), Val, VMIn, VMOut, _Templates, AllowVars) :-
    (   is_proper_name_atom(W) -> Val = W, VMOut = VMIn
    ;   AllowVars == true -> unify_with_vmap(W, Val, VMIn, VMOut)
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
    match_template(Instance, Templates, VMIn, VMOut, Transformed, AllowVars).

match_template(Instance, Templates, VMIn, VMOut, Literal, AllowVars) :-
    member(Dict, Templates),
    copy_term(Dict, dict(FunctorArgs, _NTs, WordsAndVars)),
    match_instance_to_template(Instance, WordsAndVars, VMIn, VMOut, Templates, AllowVars),
    Literal =.. FunctorArgs.

match_instance_to_template([], [], VM, VM, _, _).
match_instance_to_template(Instance, [T|Ts], VMIn, VMOut, Templates, AllowVars) :-
    (   \+ var(T)
    ->  Instance = [I|Is],
        match_part(I, T, VMIn, VM1, Templates, AllowVars),
        match_instance_to_template(Is, Ts, VM1, VMOut, Templates, AllowVars)
    ;   % T is a variable (from the template dict)
        append(VarTokens, Rest, Instance),
        VarTokens \== [],
        % Lookahead to avoid over-consuming
        (   Ts = [NextT|_], \+ var(NextT)
        ->  Rest = [NextI|_], match_part(NextI, NextT, VMIn, _, Templates, AllowVars)
        ;   Ts = [] -> Rest = []
        ;   true
        ),
        % Use NoTransform=true to avoid infinite recursion
        extract_value_from_parts(VarTokens, T, VMIn, VM1, Templates, true, AllowVars),
        match_instance_to_template(Rest, Ts, VM1, VMOut, Templates, AllowVars)
    ).

parse_literal(Tokens, Templates, VMIn, VMOut, Literal) :-
    parse_literal(Tokens, Templates, VMIn, VMOut, Literal, true).

parse_literal(Tokens, Templates, VMIn, VMOut, Literal, AllowVars) :-
    (   phrase(template_instance(Instance), Tokens)
    ->  (   transform_instance(Instance, Templates, VMIn, VMOut, Literal, AllowVars)
        ->  true
        ;   % Try matching tokens directly for built-ins
            match_template(Tokens, Templates, VMIn, VMOut, Literal, AllowVars)
        )
    ;   fail
    ).

% Simple Expression Parser
parse_expression(Parts, VMIn, VMOut, Templates, Expr) :-
    % Convert parts to a list of tokens for the expression DCG
    maplist(part_to_token, Parts, Tokens),
    phrase(expr_logic(Expr, VMIn, VMOut, Templates), Tokens).

part_to_token(word(W), word(W, loc(0,0))).
part_to_token(number(N), number(N, loc(0,0))).
part_to_token(punct(P), punctuation(P, loc(0,0))).
part_to_token(word(W, L), word(W, L)).
part_to_token(number(N, L), number(N, L)).
part_to_token(punctuation(P, L), punctuation(P, L)).
part_to_token(expr(E), expr(E)).

expr_logic(E, VMIn, VMOut, T) --> term_logic(T1, VMIn, VM1, T), expr_tail(T1, E, VM1, VMOut, T).

expr_tail(T1, E, VMIn, VMOut, T) --> [punctuation(Op, _)], { member(Op, ['+', '-']) }, term_logic(T2, VMIn, VM1, T), { E1 =.. [Op, T1, T2] }, expr_tail(E1, E, VM1, VMOut, T).
expr_tail(E, E, VM, VM, _) --> [].

term_logic(T, VMIn, VMOut, Ts) --> factor_logic(F1, VMIn, VM1, Ts), term_tail(F1, T, VM1, VMOut, Ts).

term_tail(F1, T, VMIn, VMOut, Ts) --> [punctuation(Op, _)], { member(Op, ['*', '/']) }, factor_logic(F2, VMIn, VM1, Ts), { T1 =.. [Op, F1, F2] }, term_tail(T1, T, VM1, VMOut, Ts).
term_tail(T, T, VM, VM, _) --> [].

factor_logic(F, VMIn, VMOut, Ts) --> [punctuation('(', _)], expr_logic(F, VMIn, VMOut, Ts), [punctuation(')', _)].
factor_logic(F, VMIn, VMOut, Ts) --> [expr(E)], { parse_expression(E, VMIn, VMOut, Ts, F) }.
factor_logic(V, VMIn, VMOut, _) --> [word(W, _)], { \+ is_proper_name_atom(W), unify_with_vmap(W, V, VMIn, VMOut) }.
factor_logic(W, VM, VM, _) --> [word(W, _)], { is_proper_name_atom(W) }.
factor_logic(N, VM, VM, _) --> [number(N, _)].

% Structured Body Parsing
parse_body(Tokens, Templates, VMIn, VMOut, StructuredBody) :-
    tokens_to_lines(Tokens, Lines),
    lines_to_tree(Lines, Templates, VMIn, VMOut, StructuredBody).

tokens_to_lines(Tokens, Lines) :-
    tokens_to_lines_acc(Tokens, [], Lines).

tokens_to_lines_acc([], Acc, Lines) :- reverse(Acc, Lines).
tokens_to_lines_acc([indent(N, _)|Ts], Acc, Lines) :- !,
    get_line_tokens(Ts, LineTokens, Rest),
    (   LineTokens = [word(that, _)|_], Acc = [line(PrevN, PrevTokens)|RestAcc]
    ->  append(PrevTokens, LineTokens, NewPrevTokens),
        tokens_to_lines_acc(Rest, [line(PrevN, NewPrevTokens)|RestAcc], Lines)
    ;   tokens_to_lines_acc(Rest, [line(N, LineTokens)|Acc], Lines)
    ).
tokens_to_lines_acc(Ts, Acc, Lines) :-
    get_line_tokens(Ts, LineTokens, Rest),
    (   LineTokens = [word(that, _)|_], Acc = [line(PrevN, PrevTokens)|RestAcc]
    ->  append(PrevTokens, LineTokens, NewPrevTokens),
        tokens_to_lines_acc(Rest, [line(PrevN, NewPrevTokens)|RestAcc], Lines)
    ;   tokens_to_lines_acc(Rest, [line(0, LineTokens)|Acc], Lines)
    ).

get_line_tokens([], [], []) :- !.
get_line_tokens([indent(N, Loc)|Ts], [], [indent(N, Loc)|Ts]) :- !.
get_line_tokens([T|Ts], [T|LTs], Rest) :-
    get_line_tokens(Ts, LTs, Rest).

lines_to_tree([], _, VM, VM, true) :- !.
lines_to_tree(Lines, Templates, VMIn, VMOut, Tree) :-
    lines_to_hierarchy(Lines, Hierarchy),
    hierarchy_to_logic(Hierarchy, Templates, VMIn, VMOut, Tree).

% hierarchy: list of node(Indent, Tokens, Children)
lines_to_hierarchy([], []).
lines_to_hierarchy([line(N, Tokens)|Lines], [node(N, Tokens, Children)|RestNodes]) :-
    take_nested_hierarchy(Lines, N, Nested, Remaining),
    lines_to_hierarchy(Nested, Children),
    lines_to_hierarchy(Remaining, RestNodes).

take_nested_hierarchy([line(M, Tokens)|Lines], N, [line(M, Tokens)|Nested], Remaining) :-
    M > N, !,
    take_nested_hierarchy(Lines, N, Nested, Remaining).
take_nested_hierarchy(Lines, _, [], Lines).

hierarchy_to_logic([], _, VM, VM, true) :- !.
hierarchy_to_logic([node(_, Tokens, Children)|RestNodes], Templates, VMIn, VMOut, Logic) :-
    strip_op(Tokens, _Op, RestTokens),
    parse_node(RestTokens, Children, Templates, VMIn, VM1, FirstLogic),
    fold_nodes(FirstLogic, RestNodes, Templates, VM1, VMOut, Logic).

fold_nodes(Acc, [], _, VM, VM, Acc).
fold_nodes(Acc, [node(_, Tokens, Children)|Rest], Templates, VMIn, VMOut, Logic) :-
    strip_op(Tokens, Op, RestTokens),
    parse_node(RestTokens, Children, Templates, VMIn, VM1, ChildLogic),
    NewAcc =.. [Op, Acc, ChildLogic],
    fold_nodes(NewAcc, Rest, Templates, VM1, VMOut, Logic).

strip_op([word(if, _)|Rest], and, Rest) :- !.
strip_op([word(Op, _)|Rest], Op, Rest) :- (Op == and ; Op == or), !.
strip_op(Tokens, and, Tokens).

parse_node(Tokens, Children, Templates, VMIn, VMOut, Logic) :-
    (   is_not_the_case(Tokens)
    ->  hierarchy_to_logic(Children, Templates, VMIn, VMOut, SubLogic),
        Logic = not(SubLogic)
    ;   is_aggregate(Tokens, Op, ElementTokens, ResultTokens)
    ->  hierarchy_to_logic(Children, Templates, VMIn, VM1, Goal),
        build_aggregate_list(ElementTokens, VM1, VM2, ElementList),
        build_aggregate_list(ResultTokens, VM2, VMOut, ResultList),
        Logic =.. [Op, [each|ElementList], Goal, ResultList]
    ;   parse_literal(Tokens, Templates, VMIn, VM1, Literal)
    ->  fold_nodes(Literal, Children, Templates, VM1, VMOut, Logic)
    ;   match_is_a(Tokens, Type, SuperType, VMIn, VM1, true)
    ->  Literal = is_a(Type, SuperType),
        fold_nodes(Literal, Children, Templates, VM1, VMOut, Logic)
    ;   phrase(template_instance(Instance), Tokens)
    ->  Literal = unknown_template(Instance),
        report_issue(error, 'Unknown template in body', Instance),
        fold_nodes(Literal, Children, Templates, VMIn, VMOut, Logic)
    ;   Literal = unknown_tokens(Tokens),
        report_issue(error, 'Unknown tokens in body', Tokens),
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
    ->  unify_with_vmap(Name, Var, VMIn, VMOut),
        maplist(replace_name_with_var(Name, Var), Words, List)
    ;   List = Words, VMOut = VMIn
    ).

replace_name_with_var(Name, Var, Word, Out) :-
    (Word == Name -> Out = Var ; Out = Word).

is_not_the_case(Tokens) :-
    maplist(extract_word_atom, Tokens, Atoms),
    (   Atoms = [it, is, not, the, case, that]
    ;   Atoms = [not, the, case, that]
    ).

extract_word_atom(word(A, _), A) :- !.
extract_word_atom(punctuation(P, _), P) :- !.
extract_word_atom(number(N, _), N) :- !.
extract_word_atom(_, unknown).

% Test all examples
test_all :-
    expand_file_name('examples/moreExamples/*.le', Files),
    forall(member(File, Files),
           ( format('Parsing ~w... ', [File]),
             ( parse_le_file(File, _AST) -> writeln('OK') ; writeln('FAILED') )
           )).
