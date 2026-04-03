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
template_part(that(I)) --> t(word(that)), template(I).
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
template_instance_part(that(I)) --> t(word(that)), template_instance(I).
template_instance_part(list(L)) --> t(punct('[')), list_elements(L), t(punct(']')).
template_instance_part(expr(E)) --> t(punct('(')), template_instance(E), t(punct(')')).
template_instance_part(punct(P)) --> t(punct(P)), { \+ member(P, ['*', '[', ']', '.', ',', '(', ')']) }.
template_instance_part(punct('(')) --> t(punct('(')).
template_instance_part(punct(')')) --> t(punct(')')).

list_elements([E|Es]) --> template_instance(E), ( t(punct(',')), !, list_elements(Es) | { Es = [] } ).
list_elements([]) --> [].

body(Body) --> body_tokens(Body), t(punct('.')).
body_tokens([T|Ts]) --> \+ is_body_terminator, body_token(T), !, body_tokens(Ts).
body_tokens([]) --> [].

is_body_terminator --> any_indent, [punctuation('.', _)], \+ [number(_, _)].

body_token(indent(N, Loc)) --> [indent(N, Loc)].
body_token(word(W, Loc)) --> [word(W, Loc)].
body_token(number(N, Loc)) --> [number(N, Loc)].
body_token(date(D, Loc)) --> [date(D, Loc)].
body_token(string(S, Loc)) --> [quoteString(S, Loc)].
body_token(string(S, Loc)) --> [doubleQuoteString(S, Loc)].
body_token(punct(P, Loc)) --> [punctuation(P, Loc)].

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
process_template_parts([var(Words)|Ps], FWs, [V|Args], [Name-Type|NTs], [V|WVs]) :-
    extract_name_type(Words, Name, Type),
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([number(N)|Ps], [N_Atom|FWs], Args, NTs, [N|WVs]) :-
    atom_number(N_Atom, N),
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([date(D)|Ps], [D_Atom|FWs], Args, NTs, [D|WVs]) :-
    term_to_atom(D, D_Atom),
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([string(S)|Ps], [S|FWs], Args, NTs, [S|WVs]) :-
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([punct(P)|Ps], [P|FWs], Args, NTs, [P|WVs]) :-
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([that(I)|Ps], [that|FWs], Args, NTs, [that|WVs]) :-
    % 'that' is a meta-variable
    process_template_parts(I, IFWs, IArgs, INTs, IWVs),
    append(IFWs, RestFWs, FWs),
    append(IArgs, RestArgs, Args),
    append(INTs, RestNTs, NTs),
    append(IWVs, RestWVs, WVs),
    process_template_parts(Ps, RestFWs, RestArgs, RestNTs, RestWVs).
process_template_parts([list(_)|Ps], FWs, [V|Args], [list-list|NTs], [V|WVs]) :-
    % Treat list in template as a variable for now
    process_template_parts(Ps, FWs, Args, NTs, WVs).
process_template_parts([expr(_)|Ps], FWs, [V|Args], [expr-expr|NTs], [V|WVs]) :-
    % Treat expr in template as a variable for now
    process_template_parts(Ps, FWs, Args, NTs, WVs).

extract_name_type(Words, Name, Type) :-
    (   Words = [Art | Rest], is_article(Art) -> extract_name_type_no_art(Rest, Name, Type)
    ;   extract_name_type_no_art(Words, Name, Type)
    ).

extract_name_type_no_art([N], N, N) :- !.
extract_name_type_no_art([T, N], N, T) :- !.
extract_name_type_no_art(Words, Name, Type) :-
    last(Words, N),
    append(TypeWords, [N], Words),
    atomic_list_concat(TypeWords, '_', Type),
    Name = N.

is_article(a).
is_article(an).
is_article(the).
is_article(some).
is_article(any).
is_article(each).
is_article(which).

% Second Pass: Transform AST into Clauses
second_pass(Sections, NewSections) :-
    is_list(Sections), !,
    collect_templates(Sections, UserTemplates),
    default_templates(DefaultTemplates),
    append(UserTemplates, DefaultTemplates, AllTemplates),
    maplist(transform_section(AllTemplates), Sections, NewSections).


second_pass_content(Content, NewContent) :-
    default_templates(AllTemplates),
    maplist(transform_kb_item(AllTemplates), Content, NewContent).

collect_templates(Sections, Templates) :-
    findall(D, (member(S, Sections), section_dicts(S, Ds), member(D, Ds)), Templates).

section_dicts(templates(Ds), Ds) :- !.
section_dicts(predicates(Ds), Ds) :- !.
section_dicts(fluents(Ds), Ds) :- !.
section_dicts(events(Ds), Ds) :- !.
section_dicts(meta(Ds), Ds) :- !.
section_dicts(_, []).

default_templates([
    dict([=, A, B], [any-any, any-any], [A, punct(=), B]),
    dict([>=, A, B], [any-any, any-any], [A, punct(>=), B]),
    dict([<=, A, B], [any-any, any-any], [A, punct(<=), B]),
    dict([>, A, B], [any-any, any-any], [A, punct(>), B]),
    dict([<, A, B], [any-any, any-any], [A, punct(<), B]),
    dict([is, A, B], [any-any, any-any], [A, word(is), B])
]).

transform_section(Templates, kb(Name, Content), kb(Name, NewContent)) :- !,
    maplist(transform_kb_item(Templates), Content, NewContent).
transform_section(Templates, ontology(Content), ontology(NewContent)) :- !,
    maplist(transform_kb_item(Templates), Content, NewContent).
transform_section(Templates, scenario(Name, Content), scenario(Name, NewContent)) :- !,
    maplist(transform_kb_item(Templates), Content, NewContent).
transform_section(Templates, query(Name, Content), query(Name, NewContent)) :- !,
    maplist(transform_kb_item(Templates), Content, NewContent).
transform_section(_, S, S).

transform_kb_item(Templates, rule(Head, BodyTokens), clause(HeadTerm, StructuredBody)) :- !,
    (   transform_instance(Head, Templates, HeadTerm)
    ->  parse_body(BodyTokens, Templates, StructuredBody)
    ;   HeadTerm = unknown_head(Head), StructuredBody = unknown_body(BodyTokens)
    ).
transform_kb_item(Templates, fact(Head), clause(HeadTerm, true)) :- !,
    (   transform_instance(Head, Templates, HeadTerm)
    ->  true
    ;   HeadTerm = unknown_fact(Head)
    ).

transform_instance(Instance, Templates, Literal) :-
    match_template(Instance, Templates, Literal).

match_template(Instance, Templates, Literal) :-
    member(Dict, Templates),
    copy_term(Dict, dict(FunctorArgs, _NamesTypes, WordsAndVars)),
    match_instance_to_template(Instance, WordsAndVars, Templates),
    !,
    Literal = FunctorArgs.

match_instance_to_template([], [], _).
match_instance_to_template(Instance, [WAV|WAVs], Templates) :-
    (   var(WAV)
    ->  % Greedy match for variables
        append(MatchedParts, RestInstance, Instance),
        MatchedParts \= [],
        % Lookahead to next non-variable word in template to prune search
        (   WAVs = [NextWAV|_], \+ var(NextWAV)
        ->  RestInstance = [NextPart|_],
            match_part(NextPart, NextWAV, Templates)
        ;   true
        ),
        extract_value_from_parts(MatchedParts, WAV, Templates),
        match_instance_to_template(RestInstance, WAVs, Templates)
    ;   % WAV is an atom or punct
        Instance = [Part|RestInstance],
        match_part(Part, WAV, Templates),
        match_instance_to_template(RestInstance, WAVs, Templates)
    ).

match_part(word(W), W, _) :- atom(W), !.
match_part(number(N), N, _) :- number(N), !.
match_part(string(S), S, _) :- string(S), !.
match_part(punct(P), P, _) :- atom(P), !.
match_part(Part, V, Templates) :- var(V), !, extract_value(Part, V, Templates).
match_part(that(I), V, Templates) :- var(V), !, transform_instance(I, Templates, V).

extract_value_from_parts([Part], Value, Templates) :- !,
    extract_value(Part, Value, Templates).
extract_value_from_parts(Parts, Value, _Templates) :-
    maplist(extract_simple_value, Parts, Values),
    atomic_list_concat(Values, ' ', Value).

extract_simple_value(word(W), W).
extract_simple_value(number(N), N).
extract_simple_value(string(S), S).
extract_simple_value(punct(P), P).

extract_value(word(W), W, _).
extract_value(number(N), N, _).
extract_value(date(D), D, _).
extract_value(string(S), S, _).
extract_value(list(L), TransformedL, Templates) :-
    maplist(transform_instance_rec(Templates), L, TransformedL).
extract_value(expr(E), TransformedE, Templates) :-
    transform_instance(E, Templates, TransformedE).

transform_instance_rec(Templates, I, T) :- transform_instance(I, Templates, T).

% Structured Body Parsing
parse_body(Tokens, Templates, StructuredBody) :-
    tokens_to_lines(Tokens, Lines),
    lines_to_tree(Lines, Templates, StructuredBody).

tokens_to_lines([], []) :- !.
tokens_to_lines([indent(N, _)|Ts], [line(N, LineTokens)|Lines]) :- !,
    get_line_tokens(Ts, LineTokens, Rest),
    tokens_to_lines(Rest, Lines).
tokens_to_lines(Ts, [line(0, LineTokens)|Lines]) :-
    get_line_tokens(Ts, LineTokens, Rest),
    tokens_to_lines(Rest, Lines).

get_line_tokens([], [], []) :- !.
get_line_tokens([indent(N, Loc)|Ts], [], [indent(N, Loc)|Ts]) :- !.
get_line_tokens([T|Ts], [T|LTs], Rest) :-
    get_line_tokens(Ts, LTs, Rest).

lines_to_tree([], _, true) :- !.
lines_to_tree(Lines, Templates, Tree) :-
    lines_to_groups(Lines, Groups),
    groups_to_logic(Groups, Templates, Tree).

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

groups_to_logic([group(_, Tokens, SubGroups)], Templates, Logic) :- !,
    parse_group(Tokens, SubGroups, Templates, Logic).
groups_to_logic(Groups, Templates, Logic) :-
    (   member(group(_, [word(or, _)|_], _), Groups)
    ->  Op = or
    ;   Op = and
    ),
    maplist(group_to_logic_child(Templates), Groups, Children),
    list_to_binary(Op, Children, Logic).

list_to_binary(_, [Child], Child) :- !.
list_to_binary(Op, [C|Cs], Term) :-
    list_to_binary(Op, Cs, Rest),
    Term =.. [Op, C, Rest].

group_to_logic_child(Templates, group(_, Tokens, SubGroups), Logic) :-
    (   Tokens = [word(Op, _)|Rest], (Op == and ; Op == or)
    ->  parse_group(Rest, SubGroups, Templates, Logic)
    ;   parse_group(Tokens, SubGroups, Templates, Logic)
    ).

parse_group(Tokens, [], Templates, Literal) :- !,
    parse_literal(Tokens, Templates, Literal).
parse_group(Tokens, SubGroups, Templates, Special) :-
    (   is_not_the_case(Tokens)
    ->  groups_to_logic(SubGroups, Templates, SubLogic),
        Special = not(SubLogic)
    ;   parse_literal(Tokens, Templates, Literal),
        groups_to_logic(SubGroups, Templates, SubLogic),
        Special = and(Literal, SubLogic)
    ).

is_not_the_case([word(it, _), word(is, _), word(not, _), word(the, _), word(case, _), word(that, _)]).

parse_literal(Tokens, Templates, Literal) :-
    (   phrase(template_instance(Instance), Tokens)
    ->  (   match_template(Instance, Templates, Literal)
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
