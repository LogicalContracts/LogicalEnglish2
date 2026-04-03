:- module(le_grammar, [parse_le/2, parse_le_file/2, test_all/0]).
:- use_module(tokenizer).
:- use_module(library(pcre)).

% Main entry point
parse_le(String, doc(NewSections)) :-
    % Replace non-standard whitespace with space to help tokenizer
    re_replace("\u2002"/g, " ", String, CleanString),
    tokenize(CleanString, Tokens),
    % Filter out comments
    exclude(is_comment, Tokens, CleanTokens),
    (   phrase(document(Doc), CleanTokens)
    ->  (   Doc = doc(Sections), Sections \== []
        ->  second_pass(Sections, NewSections)
        ;   Doc = doc([], Content)
        ->  second_pass_content(Content, NewContent),
            NewSections = [kb(anonymous, NewContent)]
        ;   NewSections = []
        )
    ;   NewSections = []
    ).

parse_le_file(File, AST) :-
    read_file_to_string(File, String, []),
    parse_le(String, AST).

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
sections([]) --> [].

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
    template(T),
    ( t(punct(',')), !, templates(Ts)
    | t(punct('.')), !, ( templates(Ts) | { Ts = [] } )
    ).

template([P|Ps]) -->
    template_part(P),
    template_tail(Ps).

template_tail([P|Ps]) -->
    \+ is_terminator,
    template_part(P), !,
    template_tail(Ps).
template_tail([]) --> [].

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
    kb_item(Item), !,
    kb_content(Items).
kb_content([]) --> [].

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
    template_instance_part(P), !,
    template_instance_tail(Ps).
template_instance_tail([]) --> [].

template_instance_part(word(W)) --> t(word(W)).
template_instance_part(number(N)) --> t(number(N)).
template_instance_part(date(D)) --> t(date(D)).
template_instance_part(string(S)) --> t(string(S)).
template_instance_part(list(L)) --> t(punct('[')), list_elements(L), t(punct(']')).
template_instance_part(expr(E)) --> t(punct('(')), template_instance(E), t(punct(')')).
template_instance_part(punct(P)) --> t(punct(P)), { \+ member(P, ['[', ']', '.', ',']) }.

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

% Semantics: Templates to Dicts
templatesToDicts([], []).
templatesToDicts([T|Ts], [D|Ds]) :-
    templateToDict(T, D),
    templatesToDicts(Ts, Ds).

templateToDict(T, dict([Functor|Args], NamesTypes, WordsAndVars)) :-
    process_template_parts(T, FunctorWords, Args, NamesTypes, WordsAndVars),
    atomic_list_concat(FunctorWords, '_', Functor).

process_template_parts([], [], [], [], []).
process_template_parts([word(W)|Ps], [W|FWs], Args, NTs, [W|WVs]) :-
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([var(Words)|Ps], FWs, [V|Args], [V-Type|NTs], [V|WVs]) :-
    extract_name_type(Words, _Name, Type),
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([number(N)|Ps], [N_Atom|FWs], Args, NTs, [N|WVs]) :-
    atom_number(N_Atom, N),
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([string(S)|Ps], [S|FWs], Args, NTs, [S|WVs]) :-
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
    (   append(TypeWords, [Last], Words), is_proper_name_atom(Last)
    ->  (   TypeWords = [] -> Type = any
        ;   last(TypeWords, T), Type = T
        ),
        atomic_list_concat(Words, '_', Name)
    ;   exclude(is_auxiliary, Words, BaseWords),
        (   BaseWords = [] -> Words = [Type], Name = Type % Fallback
        ;   last(BaseWords, Type),
            atomic_list_concat(Words, '_', Name)
        )
    ).

is_proper_name_atom(W) :-
    atom(W),
    atom_codes(W, [C|_]),
    code_type(C, upper).

is_proper_name(Words) :-
    (   Words = [Art | Rest], is_article(Art) -> is_proper_name_no_art(Rest)
    ;   is_proper_name_no_art(Words)
    ).

is_proper_name_no_art([W|_]) :- is_proper_name_atom(W).

is_auxiliary(W) :- member(W, [first, second, third, fourth, fifth, sixth, seventh, eighth, ninth, tenth, other, another]).

is_article(a).
is_article(an).
is_article(the).
is_article(some).
is_article(any).
is_article(each).
is_article(which).

% Second Pass: Transform AST into Clauses
second_pass(Sections, NewSections) :-
    collect_templates(Sections, UserTemplates),
    default_templates(DefaultTemplates),
    append(UserTemplates, DefaultTemplates, AllTemplates),
    maplist(transform_section(AllTemplates), Sections, NewSections).

second_pass_content(Content, NewContent) :-
    default_templates(AllTemplates),
    VarMap = vmap([]),
    maplist(transform_kb_item(AllTemplates, VarMap), Content, NewContent).

collect_templates(Sections, Templates) :-
    findall(D, (member(S, Sections), section_dicts(S, Ds), member(D, Ds)), Templates).

section_dicts(templates(Ds), Ds) :- !.
section_dicts(predicates(Ds), Ds) :- !.
section_dicts(fluents(Ds), Ds) :- !.
section_dicts(events(Ds), Ds) :- !.
section_dicts(meta(Ds), Ds) :- !.
section_dicts(_, []).

default_templates([
    dict([=, A, B], [A-any, B-any], [A, '=', B]),
    dict([>=, A, B], [A-any, B-any], [A, '>=', B]),
    dict([<=, A, B], [A-any, B-any], [A, '<=', B]),
    dict([>, A, B], [A-any, B-any], [A, '>', B]),
    dict([<, A, B], [A-any, B-any], [A, '<', B]),
    dict([is, A, B], [A-any, B-any], [A, is, B]),
    dict([=, A, B], [A-any, B-any], [A, is, B]),
    dict([=, A, B], [A-any, B-any], [A, is, a, number, B]),
    dict([=, A, B], [A-any, B-any], [A, is, a, percentage, B]),
    dict([=, A, B], [A-any, B-any], [A, is, an, amount, B])
]).



transform_section(Templates, kb(Name, Content), kb(Name, NewContent)) :- !,
    maplist(transform_kb_item_with_vmap(Templates), Content, NewContent).
transform_section(Templates, ontology(Content), ontology(NewContent)) :- !,
    maplist(transform_kb_item_with_vmap(Templates), Content, NewContent).
transform_section(Templates, scenario(Name, Content), scenario(Name, NewContent)) :- !,
    maplist(transform_kb_item_with_vmap(Templates), Content, NewContent).
transform_section(Templates, query(Name, Content), query(Name, NewContent)) :- !,
    maplist(transform_kb_item_with_vmap(Templates), Content, NewContent).
transform_section(_, S, S).

transform_kb_item_with_vmap(Templates, Item, NewItem) :-
    VarMap = vmap([]),
    transform_kb_item(Templates, VarMap, Item, NewItem).

transform_kb_item(Templates, VarMap, rule(Head, BodyTokens), clause(HeadTerm, StructuredBody)) :- !,
    (   transform_instance(Head, Templates, VarMap, HeadTerm)
    ->  parse_body(BodyTokens, Templates, VarMap, StructuredBody)
    ;   HeadTerm = unknown_head(Head), StructuredBody = unknown_body(BodyTokens)
    ).
transform_kb_item(Templates, VarMap, fact(Head), clause(HeadTerm, true)) :- !,
    (   transform_instance(Head, Templates, VarMap, HeadTerm)
    ->  true
    ;   HeadTerm = unknown_fact(Head)
    ).

transform_instance(Instance, Templates, VarMap, Literal) :-
    match_template(Instance, Templates, VarMap, Literal).

match_template(Instance, Templates, VarMap, Literal) :-
    member(Dict, Templates),
    copy_term(Dict, dict(FunctorArgs, NamesTypes, WordsAndVars)),
    match_instance_to_template(Instance, WordsAndVars, NamesTypes, VarMap, Templates),
    !,
    (   FunctorArgs = [Op, A, B], is_binary_operator(Op)
    ->  Literal =.. [Op, A, B]
    ;   Literal = FunctorArgs
    ).

is_binary_operator(Op) :- member(Op, [=, >=, <=, >, <, is, ==, (\=), '!=']).

match_instance_to_template([], [], _, _, _).
match_instance_to_template(Instance, [WAV|WAVs], NTs, VarMap, Templates) :-
    (   var(WAV)
    ->  % Find the type for this variable
        find_type(WAV, NTs, Type),
        % Greedy match for variables
        append(MatchedParts, RestInstance, Instance),
        MatchedParts \= [],
        % Lookahead to next non-variable word in template to prune search
        (   WAVs = [NextWAV|_], \+ var(NextWAV)
        ->  RestInstance = [NextPart|_],
            match_part(NextPart, NextWAV, VarMap, Templates)
        ;   true
        ),
        % Verify type compatibility
        (   check_type_compatibility(MatchedParts, Type, Templates) -> true
        ;   % If type check fails, maybe it's a symbolic variable that was already bound
            extract_value_from_parts(MatchedParts, Value, VarMap, Templates),
            Value == WAV % Check if it unifies with the existing variable
        ),
        extract_value_from_parts(MatchedParts, WAV, VarMap, Templates),
        match_instance_to_template(RestInstance, WAVs, NTs, VarMap, Templates)
    ;   % WAV is an atom or punct
        (   Instance = [Part|RestInstance],
            match_part(Part, WAV, VarMap, Templates)
        ->  match_instance_to_template(RestInstance, WAVs, NTs, VarMap, Templates)
        ;   % Special case: WAV is a multi-character punctuation that might be split in Instance
            atom(WAV), atom_length(WAV, L), L > 1,
            append(PunctParts, RestInstance, Instance),
            maplist(is_punct_token, PunctParts),
            maplist(extract_simple_value, PunctParts, PunctChars),
            atomic_list_concat(PunctChars, WAV),
            match_instance_to_template(RestInstance, WAVs, NTs, VarMap, Templates)
        )
    ).

is_punct_token(punct(_)).
is_punct_token(punctuation(_, _)).

find_type(V, [V1-Type|_], Type) :- V == V1, !.
find_type(V, [_|Rest], Type) :- find_type(V, Rest, Type).
find_type(_, [], any).

check_type_compatibility([date(_)], date, _) :- !.
check_type_compatibility([number(_)], number, _) :- !.
check_type_compatibility([number(_)], amount, _) :- !.
check_type_compatibility([number(_)], percentage, _) :- !.
check_type_compatibility([string(_)], string, _) :- !.
check_type_compatibility(_Parts, any, _Templates) :- !.
check_type_compatibility(Parts, Type, _Templates) :-
    maplist(extract_simple_value, Parts, Words),
    (   \+ is_generic_type(Type), member(W, Words), is_reserved(W) -> fail
    ;   is_proper_name(Words) -> true
    ;   extract_name_type(Words, _Name, BaseType),
        (   BaseType == Type -> true
        ;   is_generic_type(Type) -> true
        ;   false
        )
    ).

is_reserved(W) :- member(W, [says, that, if, and, or]).

is_generic_type(T) :- member(T, [thing, object, item, sentence, event, fluent, any]).

match_part(word(W), W, _, _) :- atom(W), !.
match_part(number(N), N, _, _) :- number(N), !.
match_part(string(S), S, _, _) :- string(S), !.
match_part(punct(P), P, _, _) :- atom(P), !.
match_part(word(W, _), W, _, _) :- atom(W), !.
match_part(number(N, _), N, _, _) :- number(N), !.
match_part(quoteString(S, _), S, _, _) :- string(S), !.
match_part(doubleQuoteString(S, _), S, _, _) :- string(S), !.
match_part(punctuation(P, _), P, _, _) :- atom(P), !.
match_part(Part, V, VarMap, Templates) :- var(V), !, extract_value(Part, V, VarMap, Templates).

extract_value_from_parts(Parts, Value, VarMap, Templates) :-
    (   parse_expression(Parts, VarMap, Templates, Expr)
    ->  Value = Expr
    ;   transform_instance(Parts, Templates, VarMap, Transformed)
    ->  Value = Transformed
    ;   maplist(extract_simple_value, Parts, Words),
        (   is_proper_name(Words)
        ->  atomic_list_concat(Words, ' ', Value)
        ;   extract_name_type(Words, Name, _Type),
            (   is_proper_name_atom(Name) -> unify_with_vmap(Name, Value, VarMap)
            ;   Value = Name % Fallback for simple words
            )
        )
    ).

% Simple Expression Parser
parse_expression(Parts, VarMap, Templates, Expr) :-
    % Convert parts to a list of tokens for the expression DCG
    maplist(part_to_token, Parts, Tokens),
    phrase(expr_logic(Expr, VarMap, Templates), Tokens).

part_to_token(word(W), word(W, loc(0,0))).
part_to_token(number(N), number(N, loc(0,0))).
part_to_token(punct(P), punctuation(P, loc(0,0))).
part_to_token(word(W, L), word(W, L)).
part_to_token(number(N, L), number(N, L)).
part_to_token(punctuation(P, L), punctuation(P, L)).
part_to_token(expr(E), expr(E)).

expr_logic(E, VM, T) --> term_logic(T1, VM, T), expr_tail(T1, E, VM, T).

expr_tail(T1, E, VM, T) --> [punctuation(Op, _)], { member(Op, ['+', '-']) }, term_logic(T2, VM, T), { E1 =.. [Op, T1, T2] }, expr_tail(E1, E, VM, T).
expr_tail(E, E, _, _) --> [].

term_logic(T, VM, Ts) --> factor_logic(F1, VM, Ts), term_tail(F1, T, VM, Ts).

term_tail(F1, T, VM, Ts) --> [punctuation(Op, _)], { member(Op, ['*', '/']) }, factor_logic(F2, VM, Ts), { T1 =.. [Op, F1, F2] }, term_tail(T1, T, VM, Ts).
term_tail(T, T, _, _) --> [].

factor_logic(F, VM, Ts) --> [punctuation('(', _)], expr_logic(F, VM, Ts), [punctuation(')', _)].
factor_logic(F, VM, Ts) --> [expr(E)], { parse_expression(E, VM, Ts, F) }.
factor_logic(V, VM, _) --> [word(W, _)], { \+ is_proper_name_atom(W), unify_with_vmap(W, V, VM) }.
factor_logic(W, _, _) --> [word(W, _)], { is_proper_name_atom(W) }.
factor_logic(N, _, _) --> [number(N, _)].

unify_with_vmap(Name, Var, VarMap) :-
    VarMap = vmap(Map),
    (   member(Name-ExistingVar, Map)
    ->  Var = ExistingVar
    ;   nb_setarg(1, VarMap, [Name-Var|Map])
    ).

extract_simple_value(word(W, _), W).
extract_simple_value(number(N, _), N).
extract_simple_value(quoteString(S, _), S).
extract_simple_value(doubleQuoteString(S, _), S).
extract_simple_value(punctuation(P, _), P).
extract_simple_value(date(D, _), D_Atom) :- term_to_atom(D, D_Atom).
extract_simple_value(word(W), W).
extract_simple_value(number(N), N).
extract_simple_value(string(S), S).
extract_simple_value(punct(P), P).
extract_simple_value(date(D), D_Atom) :- term_to_atom(D, D_Atom).


extract_value(word(W, _), Val, VarMap, _Templates) :-
    (   is_proper_name_atom(W) -> Val = W
    ;   unify_with_vmap(W, Val, VarMap)
    ).
extract_value(number(N, _), N, _, _).
extract_value(date(D, _), D, _, _).
extract_value(quoteString(S, _), S, _, _).
extract_value(doubleQuoteString(S, _), S, _, _).
extract_value(word(W), Val, VarMap, _Templates) :-
    (   is_proper_name_atom(W) -> Val = W
    ;   unify_with_vmap(W, Val, VarMap)
    ).
extract_value(number(N), N, _, _).
extract_value(date(D), D, _, _).
extract_value(string(S), S, _, _).
extract_value(list(L), TransformedL, VarMap, Templates) :-
    maplist(transform_instance_rec(Templates, VarMap), L, TransformedL).
extract_value(expr(E), TransformedE, VarMap, Templates) :-
    transform_instance(E, Templates, VarMap, TransformedE).

transform_instance_rec(Templates, VarMap, I, T) :- transform_instance(I, Templates, VarMap, T).

% Structured Body Parsing
parse_body(Tokens, Templates, VarMap, StructuredBody) :-
    tokens_to_lines(Tokens, Lines),
    lines_to_tree(Lines, Templates, VarMap, StructuredBody).

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

lines_to_tree([], _, _, true) :- !.
lines_to_tree(Lines, Templates, VarMap, Tree) :-
    lines_to_groups(Lines, Groups),
    groups_to_logic(Groups, Templates, VarMap, Tree).

lines_to_groups([], []).
lines_to_groups([line(N, Tokens)|Lines], [group(N, Tokens, SubGroups)|RestGroups]) :-
    take_nested(Lines, N, Nested, Remaining),
    lines_to_groups(Nested, SubGroups),
    lines_to_groups(Remaining, RestGroups).

take_nested([line(M, Tokens)|Lines], N, [line(M, Tokens)|Nested], Remaining) :-
    M > N, 
    \+ starts_with_and_or(Tokens), !,
    take_nested(Lines, N, Nested, Remaining).
take_nested(Lines, _, [], Lines).

starts_with_and_or([word(Op, _)|_]) :- (Op == and ; Op == or).

groups_to_logic([group(_, Tokens, SubGroups)], Templates, VarMap, Logic) :- !,
    group_to_logic_child(Templates, VarMap, group(0, Tokens, SubGroups), Logic).
groups_to_logic(Groups, Templates, VarMap, Logic) :-
    (   member(group(_, [word(or, _)|_], _), Groups)
    ->  Op = or
    ;   Op = and
    ),
    maplist(group_to_logic_child(Templates, VarMap), Groups, Children),
    list_to_binary(Op, Children, Logic).

list_to_binary(_, [Child], Child) :- !.
list_to_binary(Op, [C|Cs], Term) :-
    list_to_binary(Op, Cs, Rest),
    Term =.. [Op, C, Rest].

group_to_logic_child(Templates, VarMap, group(_, Tokens, SubGroups), Logic) :-
    (   Tokens = [word(Op, _)|Rest], (Op == and ; Op == or)
    ->  parse_group(Rest, SubGroups, Templates, VarMap, Logic)
    ;   parse_group(Tokens, SubGroups, Templates, VarMap, Logic)
    ).

parse_group(Tokens, SubGroups, Templates, VarMap, Logic) :-
    (   is_not_the_case(Tokens)
    ->  groups_to_logic(SubGroups, Templates, VarMap, SubLogic),
        Logic = not(SubLogic)
    ;   parse_literal(Tokens, Templates, VarMap, Literal),
        (   SubGroups == []
        ->  Logic = Literal
        ;   groups_to_logic(SubGroups, Templates, VarMap, SubLogic),
            (   SubGroups = [group(_, [word(Op, _)|_], _)|_], (Op == and ; Op == or)
            ->  Logic =.. [Op, Literal, SubLogic]
            ;   Logic = and(Literal, SubLogic)
            )
        )
    ).

is_not_the_case([word(it, _), word(is, _), word(not, _), word(the, _), word(case, _), word(that, _)]).

parse_literal(Tokens, Templates, VarMap, Literal) :-
    (   phrase(template_instance(Instance), Tokens)
    ->  (   match_template(Instance, Templates, VarMap, Literal)
        ->  true
        ;   % Try matching tokens directly for built-ins
            match_template(Tokens, Templates, VarMap, Literal)
        ->  true
        ;   Literal = unknown_template(Instance)
        )
    ;   Literal = unknown_tokens(Tokens)
    ).

% Test all examples
test_all :-
    expand_file_name('examples/moreExamples/*.le', Files),
    forall(member(File, Files),
           ( format('Parsing ~w... ', [File]),
             ( parse_le_file(File, _AST) -> writeln('OK') ; writeln('FAILED') )
           )).
