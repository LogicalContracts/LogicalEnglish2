/** <module> Logical English Grammar and Parser
    
    This module implements the DCG for Logical English and the second-pass
    logic that transforms tokens into executable Prolog terms.
*/

:- module(le_grammar, [parse_le_file/2, parse_le_tokens/2, match_instance_to_template/6, match_instance_to_template/7]).

:- use_module(tokenizer).
:- use_module(le_system_templates).
:- use_module(library(dcg/basics)).

:- discontiguous section/3.
:- discontiguous is_indent_or_comment/1.
:- discontiguous multi_word_var/3.
:- discontiguous is_operator/1.
:- discontiguous part_to_token/2.

%!  parse_le_file(+FilePath:atom, -Doc:term) is det.
%
%   Tokenizes and parses a Logical English file.
parse_le_file(FilePath, Doc) :-
    tokenize_file(FilePath, Tokens),
    parse_le_tokens(Tokens, Doc).

%!  parse_le_tokens(+Tokens:list, -Doc:term) is det.
%
%   Parses a list of tokens into a Logical English document structure.
%   Performs a second pass to resolve templates and variables.
parse_le_tokens(Tokens, doc(NewSections)) :-
    ( le_kbs:do_log -> print_message(informational,'Parsing LE tokens...~n'); true),
    (   phrase(doc(Sections), Tokens) ->  true 
        ;   
        print_message(error, "DCG phrase(doc(Sections), Tokens) failed"),
        fail
    ),
    (   second_pass(Sections, NewSections) ->  true 
        ;   
        print_message(error, "second_pass failed"),
        fail
    ).

% DCG for Logical English
% doc(Sections) parses the entire document into a list of sections.
doc(Sections) --> sections(Sections), any_indent.

% sections([S|Ss]) parses one or more sections.
sections([S|Ss]) --> section(S), !, sections(Ss).
sections([]) --> [].

% section(kb(...)) parses a knowledge base section.
section(kb(Name, Content, Start, End)) --> 
    any_indent, t(word(the, loc(Start, _))), t(word(knowledge)), t(word(base)), kb_name_tokens(Tokens), t(word(includes)), t(punctuation(':', _)),
    { reconstruct_name(Tokens, Name) },
    { ( le_kbs:do_log -> print_message(informational,'Parsing KB: ~w~n' - [Name]); true) },
    kb_content(Content, End),
    { ( le_kbs:do_log -> print_message(informational,'Finished KB: ~w~n' - [Name]); true) }.

% section(scenario(...)) parses a scenario section.
section(scenario(Name, Content, Start, End)) -->
    any_indent, t(word(scenario, loc(Start, _))), section_name_tokens(Tokens), t(word(is)), t(punctuation(':', _)),
    { reconstruct_name(Tokens, Name) },
    kb_content(Content, End).

% section(query(...)) parses a query section.
section(query(Name, Content, Start, End)) -->
    any_indent, t(word(query, loc(Start, _))), section_name_tokens(Tokens), t(word(is)), t(punctuation(':', _)),
    { reconstruct_name(Tokens, Name) },
    kb_content(Content, End).

% section(ontology(...)) parses an ontology section.
section(ontology(Content, Start, End)) -->
    any_indent, t(word(the, loc(Start, _))), t(word(ontology)), t(word(is)), t(punctuation(':', _)),
    kb_content(Content, End).

% section(predicates(...)) parses a predicates declaration section.
section(predicates(Dicts)) -->
    any_indent, t(word(the, _)), t(word(predicates)), t(word(are)), t(punctuation(':', _)),
    templates(Dicts).

% section(templates(...)) parses a templates declaration section.
section(templates(Dicts)) -->
    any_indent, t(word(the, _)), t(word(templates)), t(word(are)), t(punctuation(':', _)),
    templates(Dicts).

% section(fluents(...)) parses a fluents declaration section.
section(fluents(Dicts)) -->
    any_indent, t(word(the, _)), t(word(fluents)), t(word(are)), t(punctuation(':', _)),
    templates(Dicts).

% section(events(...)) parses an events declaration section.
section(events(Dicts)) -->
    any_indent, t(word(the, _)), t(word(events)), t(word(are)), t(punctuation(':', _)),
    templates(Dicts).

% section(meta(...)) parses a meta-information section (e.g., target language).
section(meta(Dicts)) -->
    any_indent, t(word(the, _)), t(word(target)), t(word(language)), t(word(is)), t(punctuation(':', _)), t(word(prolog)), t(punctuation('.', _)),
    { Dicts = [] }.

% section(unknown_section(...)) is a fallback for unrecognized sections.
section(unknown_section(Tokens)) -->
    [T], { T =.. [_, _, loc(_, _)] },
    consume_until_next_section(Ts),
    { Tokens = [T|Ts] }.

% kb_name_tokens(Tokens) consumes tokens until the 'includes' keyword.
kb_name_tokens([T|Ts]) -->
    t(T),
    ( \+ t(word(includes)) -> kb_name_tokens(Ts); { Ts = [] }).

% section_name_tokens(Tokens) consumes tokens until 'is' or ':'.
section_name_tokens([T|Ts]) -->
    t(T),
    ( \+ t(word(is)), \+ t(punctuation(':', _)) -> section_name_tokens(Ts); { Ts = [] }).

% query_name_tokens(Tokens) consumes tokens until 'expects'.
query_name_tokens([T|Ts]) -->
    \+ t(word(expects)),
    \+ t(punctuation('.')),
    t(T),
    !,
    query_name_tokens(Ts).
query_name_tokens([]) --> [].

reconstruct_name(Parts, Name) :-
    maplist(extract_simple_word, Parts, Words),
    reconstruct_name_acc(Words, Name).

reconstruct_name_acc([], '') :- !.
reconstruct_name_acc([W], W) :- !.
reconstruct_name_acc([W1, W2 | Rest], Name) :-
    ( (is_punct(W1) ; is_punct(W2)) -> Sep = ''; Sep = ' '),
    reconstruct_name_acc([W2 | Rest], RestName),
    atomic_list_concat([W1, Sep, RestName], '', Name).

is_punct(W) :- member(W, ['-', '.', ',', ':', ';', '(', ')', '[', ']', '{', '}', '/', '\\', '\'', '"', '*', '>=', '<=', '==', '!=', '=', '>', '<', '+']).

% consume_until_next_section(Tokens) consumes all tokens until the start of a new section.
consume_until_next_section([T|Ts]) -->
    \+ next_section_start,
    [T], !,
    consume_until_next_section(Ts).
consume_until_next_section([]) --> [].

% next_section_start matches the beginning of any Logical English section.
next_section_start --> any_indent, t(word(the, _)), t(word(knowledge)).
next_section_start --> any_indent, t(word(scenario, _)).
next_section_start --> any_indent, t(word(query, _)).
next_section_start --> any_indent, t(word(the, _)), t(word(ontology)).
next_section_start --> any_indent, t(word(the, _)), t(word(predicates)).
next_section_start --> any_indent, t(word(the, _)), t(word(templates)).
next_section_start --> any_indent, t(word(the, _)), t(word(fluents)).
next_section_start --> any_indent, t(word(the, _)), t(word(events)).
next_section_start --> any_indent, t(word(the, _)), t(word(target)).

% kb_content(Content, End) parses the items within a knowledge base or scenario.
kb_content(Content, End) -->
    kb_items(Content),
    { ( Content = [] -> End = 0; last(Content, Last), ( Last =.. [_, _, _, _, End] -> true; Last =.. [_, _, _, End] -> true; End = 0)) }.

% kb_items([I|Is]) parses a sequence of rules or facts.
kb_items([I|Is]) --> \+ next_section_start, kb_item(I), !, kb_items(Is).
kb_items([]) --> [].

% kb_item(expected(QueryName, Answers, Start, End)) parses "QueryName expects answers [Answers]."
kb_item(expected(QueryName, Answers, Start, End)) -->
    { b_getval(current_token_pos, Start) },
    query_name_tokens(Tokens), { Tokens \== [], reconstruct_name(Tokens, QueryName) },
    t(word(expects)), t(word(answers)),
    t(punctuation('[')), list_elements(Answers), t(punctuation(']')),
    any_indent, t(punctuation('.', loc(_, End))).
% kb_item(rule(...)) parses a Logical English rule (Head if Body).
kb_item(rule(Head, Body, Indent, Start, End)) -->
    { b_getval(current_token_pos, Start) },
    template_instance(Head),
    any_indent(N), t(word(if, _)),
    body(Body, End),
    { Indent = N }.
% kb_item(fact(...)) parses a Logical English fact (Head.).
kb_item(fact(Head, Start, End)) -->
    { b_getval(current_token_pos, Start) },
    template_instance(Head),
    any_indent, t(punctuation('.', loc(_, End))).
% kb_item(expected(QueryName, Answers, Start, End)) parses "QueryName expects answers [Answers]."
kb_item(expected(QueryName, Answers, Start, End)) -->
    { b_getval(current_token_pos, Start) },
    query_name_tokens(Tokens), { Tokens \== [], reconstruct_name(Tokens, QueryName) },
    t(word(expects)), t(word(answers)),
    t(punctuation('[')), list_elements(Answers), t(punctuation(']')),
    any_indent, t(punctuation('.', loc(_, End))).

% templates([T|Ts]) parses a list of template definitions.
templates([T|Ts]) -->
    \+ next_section_start,
    template(T),
    ( (t(punct('.')) ; t(punct(','))) -> ( templates(Ts) | { Ts = [] }); { Ts = [] }).
templates([]) --> [].

% template(dict(...)) parses a single template definition into a dictionary term.
template(dict(FunctorArgs, NamesTypes, WordsAndVars)) -->
    template_instance(Tokens),
    { process_template(Tokens, FunctorArgs, NamesTypes, WordsAndVars) }.

process_template(Tokens, [Functor|Args], NamesTypes, WordsAndVars) :-
    extract_functor(Tokens, Functor),
    process_template_parts(Tokens, Args, NamesTypes, WordsAndVars).

extract_functor(Tokens, Functor) :-
    findall(W, (member(T, Tokens), (T = word(W, _) ; T = number(W, _))), Words),
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
    ( Words = [Art | Rest], Rest \== [], is_article(Art) -> atomic_list_concat(Rest, ' ', Type); atomic_list_concat(Words, ' ', Type)),
    Name = Type.

is_article(A) :- memberchk(A, [a, an, the, some, 'A', 'An', 'The', 'Some']).

is_ignorable(W) :- memberchk(W, [a, an, the, is, are, was, were, has, have, had, do, does, did, been]).

% template_instance(Tokens) parses a sequence of tokens that form a template instance.
template_instance([P|Ps]) -->
    template_instance_part(P),
    template_instance_tail(Ps).

% template_instance_tail(Tokens) parses the remainder of a template instance.
template_instance_tail([P|Ps]) -->
    \+ is_terminator,
    \+ next_section_start,
    template_instance_part(P), !,
    template_instance_tail(Ps).
template_instance_tail([]) --> [].

% template_instance_part(Part) parses a single component of a template instance.
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

% template_var_words(Words) parses the words inside a *variable*.
template_var_words([W|Ws]) --> t(word(W)), !, template_var_words(Ws).
template_var_words([]) --> [].

% list_elements(Elements) parses a comma-separated list of template instances.
list_elements([E|Es]) --> template_instance(E), ( t(punct(',')), !, list_elements(Es) | { Es = [] } ).
list_elements([]) --> [].

% body(Body, End) parses the body of a rule, ending with a period.
body(Body, End) --> body_tokens(Body), any_indent, t(punctuation('.', loc(_, End))).

% body_tokens(Tokens) parses the sequence of tokens in a rule body.
body_tokens([T|Ts]) --> \+ is_body_terminator, body_token(T), !, body_tokens(Ts).
body_tokens([]) --> [].

% body_token(Token) parses a single token in a rule body, including indentation.
body_token(indent(N, L)) --> [indent(N, L)].
body_token(T) --> template_instance_part(T).

% is_terminator matches tokens that end a template instance (period, comma, or 'if').
is_terminator --> any_indent, t(punctuation('.', _)).
is_terminator --> any_indent, t(punctuation(',', _)).
is_terminator --> any_indent, t(word(if, _)).

% is_body_terminator matches the period that ends a rule body.
is_body_terminator --> any_indent, t(punctuation('.', _)).

% any_indent matches any number of indentation tokens and comments.
any_indent --> any_indent(_).

% any_indent(N) matches indentation and returns the level N.
any_indent(N) --> [indent(N1, _)], !, any_indent_tail(N1, N).
any_indent(N) --> [line_comment(_, _)], !, any_indent(N).
any_indent(N) --> [multi_comment(_, _)], !, any_indent(N).
any_indent(0) --> [].

% any_indent_tail(N1, N) handles subsequent indentation tokens and comments.
any_indent_tail(_, N) --> [indent(N2, _)], !, any_indent_tail(N2, N).
any_indent_tail(N1, N) --> [line_comment(_, _)], !, any_indent_tail(N1, N).
any_indent_tail(N1, N) --> [multi_comment(_, _)], !, any_indent_tail(N1, N).
any_indent_tail(N, N) --> [].

% t(Token) is a helper to match a token while skipping preceding indentation/comments.
t(T) --> any_indent, [T], { T \= indent(_, _), T \= line_comment(_, _), T \= multi_comment(_, _), ( T =.. [_, _, loc(Start, _)] -> b_setval(current_token_pos, Start); true) }.
t(word(W, L)) --> any_indent, [word(W, L)], { L = loc(Start, _), b_setval(current_token_pos, Start) }.
t(word(W)) --> any_indent, [word(W, L)], { L = loc(Start, _), b_setval(current_token_pos, Start) }.
t(number(N, L)) --> any_indent, [number(N, L)], { L = loc(Start, _), b_setval(current_token_pos, Start) }.
t(number(N)) --> any_indent, [number(N, L)], { L = loc(Start, _), b_setval(current_token_pos, Start) }.
t(punctuation(P, L)) --> any_indent, [punctuation(P, L)], { L = loc(Start, _), b_setval(current_token_pos, Start) }.
t(punctuation(P)) --> any_indent, [punctuation(P, L)], { L = loc(Start, _), b_setval(current_token_pos, Start) }.
t(punct(P, L)) --> any_indent, [punctuation(P, L)], { L = loc(Start, _), b_setval(current_token_pos, Start) }.
t(punct(P)) --> any_indent, [punctuation(P, L)], { L = loc(Start, _), b_setval(current_token_pos, Start) }.
t(date(D, L)) --> any_indent, [date(D, L)], { L = loc(Start, _), b_setval(current_token_pos, Start) }.
t(date(D)) --> any_indent, [date(D, L)], { L = loc(Start, _), b_setval(current_token_pos, Start) }.
t(quoteString(S, L)) --> any_indent, [quoteString(S, L)], { L = loc(Start, _), b_setval(current_token_pos, Start) }.
t(doubleQuoteString(S, L)) --> any_indent, [doubleQuoteString(S, L)], { L = loc(Start, _), b_setval(current_token_pos, Start) }.

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
is_id(W) :- atom(W), atom_length(W, L), L =< 6, is_all_caps(W), \+ (W == 'UK').
is_id(W) :- atom(W), atom_length(W, L), L =< 3, is_proper_name_atom(W).

is_reserved(W) :- member(W, [says, that, if, and, or]).

extract_id(Words, Name) :-
    \+ (member(W, Words), is_reserved(W)),
    ( append(TypeWords, [ID], Words), TypeWords \== [], is_id(ID) -> Name = ID; atomic_list_concat(Words, ' ', Name)).

extract_var_name(Words, Name) :-
    (   Words = [Art | Rest], Rest \== [], is_article(Art) ->  
            length(Rest, L), L =< 5,
            extract_id(Rest, Name)
        ; Words = [each | Rest], Rest \== [] ->  
            length(Rest, L), L =< 5,
            extract_id(Rest, Name)
        ; Words = [which | Rest], Rest \== [] ->  
            length(Rest, L), L =< 5,
            extract_id(Rest, Name)
        ; Words = [who] -> Name = who
        ; Words = [what] -> Name = what
        ; Words = [when] -> Name = when
        ; Words = [where] -> Name = where
        ; Words = [W], is_id(W) -> Name = W
    ).

unify_with_vmap(Name, Var, VMIn, VMOut) :-
    unify_with_vmap(Name, Var, VMIn, VMOut, false).

unify_with_vmap(Name, Var, VMIn, VMOut, IsVar) :-
    normalize_var_name(Name, NormName),
    (   (IsVar == true ; is_id(Name)) ->  
        ( member(NormName-ExistingVar, VMIn) -> Var = ExistingVar, VMOut = VMIn; VMOut = [NormName-Var|VMIn])
        ;   
        member(NormName-ExistingVar, VMIn) -> Var = ExistingVar, VMOut = VMIn
        ;   
        % Not a known variable and no article/ID, so it's a constant
        Var = Name, VMOut = VMIn
    ).

normalize_var_name(Name, Norm) :-
    re_replace("_"/g, " ", Name, N1),
    re_replace("  +"/g, " ", N1, N2),
    atom_string(Norm, N2).

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

extract_value_from_parts(Parts, Value, VMIn, VMOut, Templates, NoTransform, AllowVars, Depth) :-
    (   Parts = [Part], extract_value(Part, Value, VMIn, VMOut, Templates, AllowVars) -> true
        ; (Parts = [number(N, _)] ; Parts = [number(N)]) -> Value = N, VMOut = VMIn
        ; (Parts = [string(S, _)] ; Parts = [string(S)]) -> Value = S, VMOut = VMIn
        ; (Parts = [date(D, _)] ; Parts = [date(D)]) -> Value = D, VMOut = VMIn
        ; maplist(extract_simple_word, Parts, Words),
          (   AllowVars == true, extract_var_name(Words, Name) -> unify_with_vmap(Name, Value, VMIn, VMOut, true)
              ; NoTransform \== true, AllowVars == true, transform_instance(Parts, Templates, VMIn, VMOut, Value, AllowVars, Depth) -> true
              ; is_proper_name(Words) -> atomic_list_concat(Words, ' ', Value), VMOut = VMIn
              ; parse_expression(Parts, VMIn, VMOut, Templates, Value, AllowVars) -> true
              ; AllowVars == false -> ( Words = [Value] -> true; atomic_list_concat(Words, ' ', Value)), VMOut = VMIn
              ; % Fallback: treat as constant if not a variable name
                atomic_list_concat(Words, ' ', Value), VMOut = VMIn
          )
    ).

extract_simple_value(word(W, _), W).
extract_simple_value(number(N, _), N).
extract_simple_value(quoteString(S, _), S).
extract_simple_value(doubleQuoteString(S, _), S).
extract_simple_value(string(S, _), S).
extract_simple_value(punctuation(P, _), P).
extract_simple_value(punct(P, _), P).
extract_simple_value(date(D, _), D).
extract_simple_value(word(W), W).
extract_simple_value(number(N), N).
extract_simple_value(string(S), S).
extract_simple_value(punct(P), P).
extract_simple_value(date(D), D).
extract_simple_value(list(_), '[]').
extract_simple_value(expr(_), '()').
extract_simple_value(var(Words), Atom) :- atomic_list_concat(Words, ' ', Atom).

extract_simple_word(Part, Word) :-
    extract_simple_value(Part, Val),
    ( compound(Val), Val = date(Y, M, D) -> format(atom(Word), '~w-~w-~w', [Y, M, D]); Word = Val).

extract_name_type(Words, Name, Type) :-
    ( Words = [Art | Rest], Rest \== [], is_article(Art) -> extract_name_type_no_art(Rest, Name, Type); extract_name_type_no_art(Words, Name, Type)).

extract_name_type_no_art(Words, Name, Type) :-
    (   Words = [W] -> Name = W, Type = W
        ; last(Words, Last),
          (   is_id(Last) ->  
                  append(TypeWords, [Last], Words),
                  ( TypeWords = [] -> Type = Last; reconstruct_name_acc(TypeWords, Type)),
                  Name = Last
              ; reconstruct_name_acc(Words, Name),
                Type = Name
          )
    ).

extract_value(var(Words), Val, VMIn, VMOut, _Templates, AllowVars) :-
    !, extract_var_info_from_words(Words, Name, _Type),
    ( AllowVars == true -> unify_with_vmap(Name, Val, VMIn, VMOut, true); Val = Name, VMOut = VMIn).
extract_value(word(W, _), Val, VMIn, VMOut, _Templates, AllowVars) :-
    ( le_kbs:do_log -> print_message(informational,'Extract value word: ~w (AllowVars: ~w)~n' - [W, AllowVars]); true),
    ( AllowVars == false -> Val = W, VMOut = VMIn; unify_with_vmap(W, Val, VMIn, VMOut, false)).
extract_value(number(N, _), N, VM, VM, _, _).
extract_value(date(D, _), D, VM, VM, _, _).
extract_value(quoteString(S, _), S, VM, VM, _, _).
extract_value(doubleQuoteString(S, _), S, VM, VM, _, _).
extract_value(punctuation(P, _), P, VM, VM, _, _).
extract_value(punct(P, _), P, VM, VM, _, _).
extract_value(word(W), Val, VMIn, VMOut, _Templates, AllowVars) :-
    ( AllowVars == false -> Val = W, VMOut = VMIn; unify_with_vmap(W, Val, VMIn, VMOut, false)).
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
    ( Depth > 1 -> fail; true),
    ( le_kbs:do_log -> maplist(extract_simple_word, Instance, Words), print_message(informational,'Transform instance (depth ~w): ~w~n' - [Depth, Words]); true),
    D1 is Depth + 1,
    ( match_template(Instance, Templates, VMIn, VMOut, Transformed, AllowVars, D1) -> true; extract_value_from_parts(Instance, Transformed, VMIn, VMOut, Templates, true, AllowVars, D1)).

match_template(Instance, Templates, VMIn, VMOut, Literal, AllowVars, Depth) :-
    maplist(extract_simple_word, Instance, Words),
    member(Dict, Templates),
    copy_term(Dict, dict(FunctorArgs, _NTs, WordsAndVars, NIW)),
    contains_subsequence(NIW, Words),
    match_instance_to_template(Instance, WordsAndVars, VMIn, VMOut, Templates, AllowVars, Depth),
    Literal =.. FunctorArgs.

match_instance_to_template(Instance, WordsAndVars, VMIn, VMOut, Templates, AllowVars) :-
    match_instance_to_template(Instance, WordsAndVars, VMIn, VMOut, Templates, AllowVars, 0).

match_instance_to_template(Instance, WordsAndVars, VMIn, VMOut, Templates, AllowVars, Depth) :-
    match_instance_to_template_acc(Instance, WordsAndVars, VMIn, VMOut, Templates, AllowVars, Depth).

match_instance_to_template_acc([], [], VM, VM, _, _, _).
match_instance_to_template_acc(Instance, [T|Ts], VMIn, VMOut, Templates, AllowVars, Depth) :-
    \+ var(T), is_ignorable(T), !,
    ( Instance = [I|Is], extract_simple_word(I, W), W == T -> 
        match_instance_to_template_acc(Is, Ts, VMIn, VMOut, Templates, AllowVars, Depth)
        ; match_instance_to_template_acc(Instance, Ts, VMIn, VMOut, Templates, AllowVars, Depth)
        ).
match_instance_to_template_acc([I|Is], [T|Ts], VMIn, VMOut, Templates, AllowVars, Depth) :-
    \+ var(T), extract_simple_word(I, W), is_ignorable(W), W \== T, !,
    match_instance_to_template_acc(Is, [T|Ts], VMIn, VMOut, Templates, AllowVars, Depth).
match_instance_to_template_acc(Instance, [T|Ts], VMIn, VMOut, Templates, AllowVars, Depth) :-
    (   \+ var(T) ->  
        Instance = [I|Is],
        match_part(I, T, VMIn, VM1, Templates, AllowVars),
        match_instance_to_template_acc(Is, Ts, VM1, VMOut, Templates, AllowVars, Depth)
        ;   
        % T is a variable (from the template dict)
        % Lookahead to avoid over-consuming
        (   Ts = [NextT|RestTs], \+ var(NextT) ->  
                % Optimization: find the first split that matches the next constant part
                % and satisfies the variable extraction. This avoids exponential backtracking.
                once((
                    append(VarTokens, [NextI|Rest], Instance),
                    VarTokens \== [],
                    match_part(NextI, NextT, VMIn, VM1, Templates, AllowVars),
                    extract_value_from_parts(VarTokens, T, VM1, VM2, Templates, false, AllowVars, Depth)
                )),
                match_instance_to_template_acc(Rest, RestTs, VM2, VMOut, Templates, AllowVars, Depth)
            ; Ts = [] ->  
                VarTokens = Instance,
                VarTokens \== [],
                extract_value_from_parts(VarTokens, T, VMIn, VMOut, Templates, false, AllowVars, Depth)
            ; % Next part is also a variable, must try all splits
              once(append(VarTokens, Rest, Instance)),
              VarTokens \== [],
              extract_value_from_parts(VarTokens, T, VMIn, VM1, Templates, false, AllowVars, Depth),
              match_instance_to_template_acc(Rest, Ts, VM1, VMOut, Templates, AllowVars, Depth)
        )
    ).

% Semantics: Second Pass
second_pass(Sections, NewSections) :-
    ( le_kbs:do_log -> length(Sections, L), print_message(informational,'Second pass: ~w sections~n' - [L]); true),
    % Collect all templates from all sections first
    findall(Dict, (member(S, Sections), get_dicts(S, Dicts), member(Dict, Dicts)), UserDicts),
    findall(SystemDict, le_system_template(SystemDict), SystemDicts),
    append(UserDicts, SystemDicts, AllDicts),
    sort(AllDicts, UniqueDicts),
    % Pre-calculate non-ignorable words for each template to speed up matching
    maplist(add_non_ignorable, UniqueDicts, AllDictsWithWords),
    % Sort templates: meta-templates first, then by specificity
    sort_templates(AllDictsWithWords, SortedDicts),
    maplist(second_pass_section(SortedDicts), Sections, NewSections).

add_non_ignorable(dict(FA, NT, WV), dict(FA, NT, WV, NIW)) :-
    findall(W, (member(W, WV), atom(W), \+ is_reserved(W), \+ is_ignorable(W)), NIW).

sort_templates(Dicts, Sorted) :-
    partition(is_meta_template, Dicts, Meta, Regular),
    map_list_to_pairs(template_specificity, Regular, Pairs),
    keysort(Pairs, SortedPairs),
    reverse(SortedPairs, RevSortedPairs),
    pairs_values(RevSortedPairs, SortedRegular),
    append(Meta, SortedRegular, Sorted).

template_specificity(dict(_, _, WordsAndVars, _), Score) :-
    findall(1, (member(W, WordsAndVars), atom(W)), Words),
    length(Words, Score).

is_meta_template(dict(_, _, WordsAndVars, _)) :-
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
    ( le_kbs:do_log -> length(Items, L), print_message(informational,'Second pass content: ~w items~n' - [L]); true),
    maplist(second_pass_item(Templates), Items, NewItems).

second_pass_item(Templates, rule(Head, BodyTokens, Indent, Start, End), clause(NewHead, NewBody, Start, End)) :-
    ( le_kbs:do_log -> maplist(extract_simple_word, Head, Words), print_message(informational,'Processing rule: ~w~n' - [Words]); true),
    (   parse_literal(Head, Templates, [], VM1, NewHead, true) ->  
        (   parse_body(BodyTokens, Indent, Templates, VM1, _VMOut, NewBody) ->  
            ( le_kbs:do_log -> print_message(informational,'  Rule succeeded~n'); true)
            ;   
            ( le_kbs:do_log -> print_message(informational,'  Rule body failed to parse~n'); true), fail
        )
        ;   
        ( le_kbs:do_log -> print_message(informational,'  Rule head failed to match template~n'); true),
        NewHead = unknown_template(Head),
        parse_body(BodyTokens, Indent, Templates, [], _VMOut, NewBody)
    ).
second_pass_item(Templates, fact(Head, Start, End), clause(NewHead, true, Start, End)) :-
    ( parse_literal(Head, Templates, [], _VM1, NewHead, true) -> true; NewHead = unknown_template(Head)).

second_pass_ontology_item(Templates, fact(Head, Start, End), clause(NewHead, true, Start, End)) :-
    (   match_is_a(Head, _Type, _SuperType, TypeAtom, SuperTypeAtom, [], _VMOut, true) ->  
        ( NewHead = is_a(TypeAtom, SuperTypeAtom), assertz(is_a_taxonomy_edge(TypeAtom, SuperTypeAtom, Start)))
        ;   
        parse_literal(Head, Templates, [], _VM1, NewHead, true) -> true
        ;   
        NewHead = unknown_template(Head, Start, End)
    ).
second_pass_ontology_item(Templates, rule(Head, BodyTokens, Indent, Start, End), clause(NewHead, NewBody, Start, End)) :-
    ( parse_literal(Head, Templates, [], VM1, NewHead, true) -> 
        parse_body(BodyTokens, Indent, Templates, VM1, _VMOut, NewBody)
        ; 
        NewHead = unknown_template(Head, Start, End), 
        parse_body(BodyTokens, Indent, Templates, [], _VMOut, NewBody)
    ).

second_pass_scenario_item(Templates, fact(Head, Start, End), clause(NewHead, true, Start, End)) :-
    ( parse_literal(Head, Templates, [], _VM1, NewHead, true) -> true; NewHead = unknown_template(Head, Start, End)).

second_pass_scenario_item(Templates, rule(Head, BodyTokens, Indent, Start, End), clause(NewHead, NewBody, Start, End)) :-
    ( parse_literal(Head, Templates, [], VM1, NewHead, true) -> 
        parse_body(BodyTokens, Indent, Templates, VM1, _VMOut, NewBody)
        ; 
        NewHead = unknown_template(Head, Start, End), 
        parse_body(BodyTokens, Indent, Templates, [], _VMOut, NewBody)
    ).
second_pass_scenario_item(_Templates, expected(QueryName, Answers, Start, End), expected(QueryName, AnswerStrings, Start, End)) :-
    maplist(extract_answer_string, Answers, AnswerStrings).

extract_answer_string(Tokens, String) :-
    maplist(extract_simple_word, Tokens, Words),
    atomic_list_concat(Words, ' ', String).

second_pass_query_item(Templates, fact(Head, Start, End), clause(NewHead, true, Start, End)) :-
    ( parse_literal(Head, Templates, [], _VM1, NewHead, true) -> true; NewHead = unknown_template(Head, Start, End)).

second_pass_query_item(Templates, rule(Head, BodyTokens, Indent, Start, End), clause(NewHead, NewBody, Start, End)) :-
    ( parse_literal(Head, Templates, [], VM1, NewHead, true) -> 
        parse_body(BodyTokens, Indent, Templates, VM1, _VMOut, NewBody)
        ; 
        NewHead = unknown_template(Head, Start, End), 
        parse_body(BodyTokens, Indent, Templates, [], _VMOut, NewBody)
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
    extract_words_to_value(TypeWords, Type, VMIn, VM1, AllowVars),
    extract_words_to_value(SuperTypeWords, SuperType, VM1, VMOut, AllowVars),
    extract_name_type(TypeWords, TypeAtom, _),
    extract_name_type(SuperTypeWords, SuperTypeAtom, _).

extract_words_to_value(Words, Value, VMIn, VMOut, AllowVars) :-
    (   AllowVars == true, extract_var_name(Words, Name) ->  
            unify_with_vmap(Name, Value, VMIn, VMOut, true)
        ; Words = [Value], (number(Value) ; string(Value)) ->  
            VMOut = VMIn
        ; reconstruct_name_acc(Words, Value),
          VMOut = VMIn
    ).

parse_literal(Tokens, Templates, VMIn, VMOut, Literal) :-
    parse_literal(Tokens, Templates, VMIn, VMOut, Literal, true).

parse_literal(Tokens, Templates, VMIn, VMOut, Literal, AllowVars) :-
    ( le_kbs:do_log -> maplist(extract_simple_word, Tokens, Words), print_message(informational,'Parsing literal: ~w~n' - [Words]); true),
    parse_literal_real(Tokens, Templates, VMIn, VMOut, Literal, AllowVars),
    ( le_kbs:do_log -> print_message(informational,'  Succeeded: ~w~n' - [Literal]); true).

parse_literal_real(Tokens, Templates, VMIn, VMOut, Literal, AllowVars) :-
    maplist(extract_simple_word, Tokens, Words),
    (   member(dict(FunctorArgs, NTs, WordsAndVars, NIW), Templates),
        \+ (FunctorArgs = [le_is|_]),
        ( le_kbs:do_log -> print_message(informational,'  Trying template: ~w~n' - [FunctorArgs]); true),
        contains_subsequence(NIW, Words),
        copy_term(dict(FunctorArgs, NTs, WordsAndVars, NIW), dict(FunctorArgsCopy, _, WordsAndVarsCopy, _)),
        match_instance_to_template(Tokens, WordsAndVarsCopy, VMIn, VMOut, Templates, AllowVars, 0),
        Literal =.. FunctorArgsCopy -> true
        ;   
        match_is_a(Tokens, Type, SuperType, VMIn, VMOut, AllowVars) -> Literal = is_a(Type, SuperType)
        ;   
        % Fallback to le_is
        member(dict([le_is, V1, V2], NTs, WordsAndVars, NIW), Templates),
        ( le_kbs:do_log -> print_message(informational,'  Trying fallback le_is~n'); true),
        copy_term(dict([le_is, V1, V2], NTs, WordsAndVars, NIW), dict([le_is, V1Copy, V2Copy], _, WordsAndVarsCopy, _)),
        match_instance_to_template(Tokens, WordsAndVarsCopy, VMIn, VMOut, Templates, AllowVars, 0) -> Literal = le_is(V1Copy, V2Copy)
    ).

contains_subsequence([], _).
contains_subsequence([W|Ws], Words) :-
    memberchk(W, Words),
    find_word_after(W, Words, Rest), !,
    contains_subsequence(Ws, Rest).

find_word_after(W, [W|Rest], Rest) :- !.
find_word_after(W, [_|Words], Rest) :- find_word_after(W, Words, Rest).

% Simple Expression Parser
parse_expression(Parts, VMIn, VMOut, Templates, Expr, AllowVars) :-
    % Optimization: only try parsing as expression if it looks like one
    (   member(Part, Parts), (Part = punct(Op, _) ; Part = punctuation(Op, _)), member(Op, ['+', '-', '*', '/', '(', ')', '=', '>', '<', '>=', '<=', '=<', '==', '!=']) ->  
            exclude(is_indent_or_comment, Parts, CleanParts),
            maplist(part_to_token, CleanParts, Tokens),
            phrase(expr_logic(Expr, VMIn, VMOut, Templates, AllowVars), Tokens)
        ; fail
    ).

is_indent_or_comment(indent(_, _)).
is_indent_or_comment(line_comment(_, _)).
is_indent_or_comment(multi_comment(_, _)).

is_operator(W) :- member(W, ['+', '-', '*', '/', '(', ')', '=', '>', '<', '>=', '<=', '=<', '==', '!=']).

% multi_word_var(Words) parses a sequence of words that form a multi-word variable.
multi_word_var([W|Rest]) --> 
    [word(W, _)], { \+ is_reserved(W), \+ is_operator(W) },
    (multi_word_var(Rest) | { Rest = [] }).

% part_to_token(Part, Token) converts various part terms into a uniform token structure.
part_to_token(word(W), word(W, loc(0,0))).
part_to_token(number(N), number(N, loc(0,0))).
part_to_token(punct(P), punctuation(P, loc(0,0))).
part_to_token(word(W, L), word(W, L)).
part_to_token(number(N, L), number(N, L)).
part_to_token(punct(P, L), punctuation(P, L)).
part_to_token(punctuation(P, L), punctuation(P, L)).
part_to_token(expr(E), expr(E)).

% expr_logic(Expr, ...) parses an arithmetic expression with addition and subtraction.
expr_logic(E, VMIn, VMOut, T, AllowVars) --> term_logic(T1, VMIn, VM1, T, AllowVars), expr_tail(T1, E, VM1, VMOut, T, AllowVars).
expr_tail(T1, E, VMIn, VMOut, T, AllowVars) --> [punctuation(Op, _)], { member(Op, ['+', '-']) }, term_logic(T2, VMIn, VM1, T, AllowVars), { E1 =.. [Op, T1, T2] }, expr_tail(E1, E, VM1, VMOut, T, AllowVars).
expr_tail(E, E, VM, VM, _, _) --> [].

% term_logic(Term, ...) parses an arithmetic term with multiplication and division.
term_logic(T, VMIn, VMOut, Ts, AllowVars) --> factor_logic(F1, VMIn, VM1, Ts, AllowVars), term_tail(F1, T, VM1, VMOut, Ts, AllowVars).
term_tail(F1, T, VMIn, VMOut, Ts, AllowVars) --> [punctuation(Op, _)], { member(Op, ['*', '/']) }, factor_logic(F2, VMIn, VM1, Ts, AllowVars), { T1 =.. [Op, F1, F2] }, term_tail(T1, T, VM1, VMOut, Ts, AllowVars).
term_tail(T, T, VM, VM, _, _) --> [].

% factor_logic(Factor, ...) parses an arithmetic factor (parenthesized expression, variable, or number).
factor_logic(F, VMIn, VMOut, Ts, AllowVars) --> [punctuation('(', _)], expr_logic(F, VMIn, VMOut, Ts, AllowVars), [punctuation(')', _)].
factor_logic(F, VMIn, VMOut, Ts, AllowVars) --> [expr(E)], { parse_expression(E, VMIn, VMOut, Ts, F, AllowVars) }.
factor_logic(V, VMIn, VMOut, _, true) --> 
    multi_word_var(Words),
    { ( extract_var_name(Words, Name) -> true; reconstruct_name_acc(Words, Name)),
      unify_with_vmap(Name, V, VMIn, VMOut, false) }.
factor_logic(W, VM, VM, _, false) --> [word(W, _)], { is_proper_name_atom(W) }.
factor_logic(N, VM, VM, _, _) --> [number(N, _)].

% Structured Body Parsing
parse_body(Tokens, Indent, Templates, VMIn, VMOut, StructuredBody) :-
    once(tokens_to_lines(Tokens, Indent, Lines)), % removing this once(..) causes nontermination in moreExamples/sbpp_0.le
    (   lines_to_tree(Tokens, Lines, Templates, VMIn, VMOut, StructuredBody) ->  
        ( le_kbs:do_log -> print_message(informational,'  Body succeeded~n'); true)
        ;   
        ( le_kbs:do_log -> print_message(informational,'  Body failed to parse~n'); true), fail
    ).

tokens_to_lines(Tokens, DefaultIndent, Lines) :-
    tokens_to_lines_acc(Tokens, DefaultIndent, [], Lines).

tokens_to_lines_acc([], _, Acc, Lines) :- reverse(Acc, Lines).
tokens_to_lines_acc([indent(N, _)|Ts], DefaultIndent, Acc, Lines) :- !,
    get_line_tokens(Ts, LineTokens, Rest),
    (   LineTokens == [] -> tokens_to_lines_acc(Rest, DefaultIndent, Acc, Lines)
        ;   
        LineTokens = [word(that, _)|_], Acc = [line(PrevN, PrevTokens)|RestAcc] ->  
        append(PrevTokens, LineTokens, NewPrevTokens),
        tokens_to_lines_acc(Rest, DefaultIndent, [line(PrevN, NewPrevTokens)|RestAcc], Lines)
        ;   
        tokens_to_lines_acc(Rest, DefaultIndent, [line(N, LineTokens)|Acc], Lines)
    ).
tokens_to_lines_acc(Ts, DefaultIndent, Acc, Lines) :-
    get_line_tokens(Ts, LineTokens, Rest),
    (   LineTokens == [] -> tokens_to_lines_acc(Rest, DefaultIndent, Acc, Lines)
        ;   
        LineTokens = [word(that, _)|_], Acc = [line(PrevN, PrevTokens)|RestAcc] ->  
        append(PrevTokens, LineTokens, NewPrevTokens),
        tokens_to_lines_acc(Rest, DefaultIndent, [line(PrevN, NewPrevTokens)|RestAcc], Lines)
        ;   
        tokens_to_lines_acc(Rest, DefaultIndent, [line(DefaultIndent, LineTokens)|Acc], Lines)
    ).

get_line_tokens([], [], []) :- !.
get_line_tokens([indent(N, Loc)|Ts], [], [indent(N, Loc)|Ts]) :- !.
get_line_tokens([T|Ts], [T|LTs], Rest) :-
    !,
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

parse_node([], Children, Templates, VMIn, VMOut, Logic) :- !,
    hierarchy_to_logic(Children, Templates, VMIn, VMOut, Logic).
parse_node(Tokens, Children, Templates, VMIn, VMOut, Logic) :-
    ( le_kbs:do_log -> maplist(extract_simple_word, Tokens, Words), print_message(informational,'Parsing node: ~w~n' - [Words]); true),
    (   is_forall(Tokens) ->  
            split_forall_children(Children, CondNodes, ConsNodes),
            hierarchy_to_logic(CondNodes, Templates, VMIn, VM1, CondLogic),
            hierarchy_to_logic(ConsNodes, Templates, VM1, VMOut, ConsLogic),
            Logic = forall(CondLogic, ConsLogic)
        ; is_not_the_case(Tokens) ->  
            hierarchy_to_logic(Children, Templates, VMIn, VMOut, SubLogic),
            Logic = not(SubLogic)
        ; is_aggregate(Tokens, Op, ElementTokens, ResultTokens) ->  
            build_aggregate_list(ElementTokens, VMIn, VM1, ElementList),
            build_aggregate_list(ResultTokens, VM1, VM2, ResultList),
            hierarchy_to_logic(Children, Templates, VM2, VMOut, Goal),
            Logic =.. [Op, [each|ElementList], Goal, ResultList]
        ; parse_literal(Tokens, Templates, VMIn, VM1, Literal) ->  
            fold_nodes(Literal, Children, Templates, VM1, VMOut, Logic)
        ; match_is_a(Tokens, Type, SuperType, VMIn, VM1, true) ->  
            Literal = is_a(Type, SuperType),
            fold_nodes(Literal, Children, Templates, VM1, VMOut, Logic)
        ; phrase(template_instance(Instance), Tokens) ->  
            Literal = unknown_template(Instance),
            fold_nodes(Literal, Children, Templates, VMIn, VMOut, Logic)
        ; Literal = unknown_tokens(Tokens),
            fold_nodes(Literal, Children, Templates, VMIn, VMOut, Logic)
    ),
    ( le_kbs:do_log -> print_message(informational,'  Node succeeded: ~w~n' - [Logic]); true).


is_aggregate(Tokens, Op, ElementTokens, ResultTokens) :-
    Tokens = [_, _, _, _, _, _, _, _ | _],
    last(Tokens, word(that, _)),
    append(Rest, [word(such, _), word(that, _)], Tokens),
    member(Op, [sum, count, average, min, max]),
    append(ResultTokens, [word(is, _), word(the, _), word(Op, _), word(of, _), word(each, _)|ElementTokens], Rest),
    !.

build_aggregate_list(Tokens, VMIn, VMOut, List) :-
    ( Tokens = [word(and, _)|Rest] -> TokensToUse = Rest; TokensToUse = Tokens),
    maplist(extract_simple_word, TokensToUse, Words),
    (   extract_var_name(Words, Name) ->  
        unify_with_vmap(Name, Var, VMIn, VMOut, true),
        List = [Var]
        ;   
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
    ( Children == [] -> Consequences = Rest; Consequences = Children).
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
