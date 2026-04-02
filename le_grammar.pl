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

section(templates(Ts)) -->
    t(word(the)), t(word(templates)), t(word(are)), t(punct(':')),
    templates(Ts).

section(predicates(Ts)) -->
    t(word(the)), t(word(predicates)), t(word(are)), t(punct(':')),
    templates(Ts).

section(fluents(Ts)) -->
    t(word(the)), t(word(fluents)), t(word(are)), t(punct(':')),
    templates(Ts).

section(events(Ts)) -->
    t(word(the)), t(word(event)), t(word(predicates)), t(word(are)), t(punct(':')),
    templates(Ts).

section(meta(Ts)) -->
    t(word(the)), t(word(meta)), t(word(predicates)), t(word(are)), t(punct(':')),
    templates(Ts).

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
    template_instance(T),
    ( t(punct(',')), !, templates(Ts)
    | t(punct('.')), !, ( templates(Ts) | { Ts = [] } )
    ).

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

is_terminator --> any_indent, [punctuation('.', _)], \+ [number(_, _)].
is_terminator --> any_indent, [punctuation(',', _)].
is_terminator --> any_indent, [punctuation(']', _)].
is_terminator --> any_indent, [punctuation(')', _)].
is_terminator --> any_indent, [word(if, _)].
is_terminator --> [indent(_, _), word(and, _)].
is_terminator --> [indent(_, _), word(or, _)].

template_instance_part(word(W)) --> t(word(W)).
template_instance_part(number(N)) --> t(number(N)).
template_instance_part(var(Words)) --> t(punct('*')), words(Words), t(punct('*')).
template_instance_part(that(I)) --> t(word(that)), template_instance(I).

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

% Test all examples
test_all :-
    expand_file_name('examples/moreExamples/*.le', Files),
    forall(member(File, Files),
           ( format('Parsing ~w... ', [File]),
             ( parse_le_file(File, _AST) -> writeln('OK') ; writeln('FAILED') )
           )).

