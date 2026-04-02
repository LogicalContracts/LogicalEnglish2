:- module(le_grammar, [parse_le/2, parse_le_file/2, test_all/0]).
:- use_module(tokenizer).
:- use_module(library(pcre)).

% Main entry point
parse_le(String, Doc) :-
    % Replace non-standard whitespace with space to help tokenizer
    re_replace("\u2002"/g, " ", String, CleanString),
    tokenize(CleanString, Tokens),
    % Filter out comments
    exclude(is_comment, Tokens, CleanTokens),
    phrase(document(Doc), CleanTokens).

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

body_token(indent(N)) --> [indent(N, _)].
body_token(word(W)) --> [word(W, _)].
body_token(number(N)) --> [number(N, _)].
body_token(date(D)) --> [date(D, _)].
body_token(string(S)) --> [quoteString(S, _)].
body_token(string(S)) --> [doubleQuoteString(S, _)].
body_token(punct(P)) --> [punctuation(P, _)].

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

% Test all examples
test_all :-
    expand_file_name('examples/moreExamples/*.le', Files),
    forall(member(File, Files),
           ( format('Parsing ~w... ', [File]),
             ( parse_le_file(File, _AST) -> writeln('OK') ; writeln('FAILED') )
           )).
