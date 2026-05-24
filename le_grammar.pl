/** <module> Logical English Grammar and Parser
    
    This module implements the DCG for Logical English and the second-pass
    logic that transforms tokens into executable Prolog terms. It handles
    the structure of KBs, scenarios, queries, and templates.
*/

:- module(le_grammar, [parse_le_file/3, parse_le_text/3, parse_le_tokens/3, match_instance_to_template/6, match_instance_to_template/7, reconstruct_name/2,
    kb_items//1, second_pass_item/4, parse_literal/6, prepare_templates/2,
    set_token_pos/1, get_token_pos/1, is_id/1, is_article/1, is_reserved/1, is_ignorable/1, is_proper_name_atom/1, is_punct/1,
    extract_var_name_extension/2, unify_with_vmap_extension/5, post_parse_literal_hook/4, parse_node_extension/6, second_pass_item_extension/4,
    extract_var_name/2, unify_with_vmap/5, extract_simple_word/2, extract_var_info_from_words/3]).

:- multifile extract_var_name_extension/2, unify_with_vmap_extension/5, post_parse_literal_hook/4, parse_node_extension/6, second_pass_item_extension/4, match_template_with_chaining/8.

:- use_module(tokenizer, [tokenize/2, tokenize_file/2, tokens_to_string/2]).
:- use_module(le_system_templates).
:- use_module(library(dcg/basics)).

:- thread_local current_token_pos/1.

%!  set_token_pos(+Pos:integer) is det.
%
%   Sets the current token position in a thread-local fact.
set_token_pos(Pos) :-
    retractall(current_token_pos(_)),
    assertz(current_token_pos(Pos)).

%!  get_token_pos(-Pos:integer) is det.
%
%   Gets the current token position from a thread-local fact.
get_token_pos(Pos) :-
    ( current_token_pos(P) -> Pos = P; Pos = 0).

:- discontiguous second_pass_item/4.
:- discontiguous second_pass_ontology_item/4.
:- discontiguous second_pass_scenario_item/4.
:- discontiguous second_pass_query_item/4.
:- discontiguous is_indent_or_comment/1.
:- discontiguous multi_word_var/3.
:- discontiguous is_operator/1.
:- discontiguous part_to_token/2.

%!  parse_le_file(+FilePath:atom, -Doc:term) is det.
%
%   Tokenizes and parses a Logical English file.
parse_le_file(FilePath, Doc, M) :-
    tokenize_file(FilePath, Tokens),
    parse_le_tokens(Tokens, Doc, M).

parse_le_text(Text, Doc, M) :-
    tokenize(Text, Tokens),
    parse_le_tokens(Tokens, Doc, M).


%!  parse_le_text(+Text:string, -Doc:term) is det.
%
%   Tokenizes and parses Logical English source text.
parse_le_text(Text, Doc) :-
    tokenize(Text, Tokens),
    parse_le_tokens(Tokens, Doc).

%!  parse_le_tokens(+Tokens:list, -Doc:term) is det.
%
%   Parses a list of tokens into a Logical English document structure.
%   Performs a second pass to resolve templates and variables.
parse_le_tokens(Tokens, doc(NewSections), M) :-
    ( le_kbs:do_log -> print_message(informational,'Parsing LE tokens...~n'); true),
    (   phrase(doc(Sections), Tokens) ->  true 
        ;   
        print_message(error, "DCG phrase(doc(Sections), Tokens) failed"),
        fail
    ),
    check_scenario_before_rules(Sections, M),
    (   second_pass(Sections, NewSections, M) ->  true 
        ;   
        print_message(error, "second_pass failed"),
        fail
    ).

check_scenario_before_rules(Sections, M) :-
    forall(
        ( nth1(_, Sections, scenario(Name, _, Start, End)),
          once((member(Other, Sections), is_rule_bearing_section(Other), section_start(Other, StartOther), StartOther > Start))
        ),
        ( format(atom(Desc), "Scenario '~w' defined before rules in knowledge base", [Name]),
          (nonvar(M) -> assertz(M:le_issue(error, scenario_before_rules, Desc, "Move the scenario after the rules.", Start, End)) ; true)
        )
    ).

section_start(kb(_, _, S, _), S).
section_start(scenario(_, _, S, _), S).
section_start(query(_, _, S, _), S).
section_start(ontology(_, S, _), S).
section_start(unknown_section(_, S, _), S).
section_start(meta(_), 0).
section_start(templates(_), 0).
section_start(predicates(_), 0).
section_start(fluents(_), 0).
section_start(events(_), 0).

is_rule_bearing_section(kb(_, Content, _, _)) :- member(Item, Content), is_rule_item(Item).
is_rule_bearing_section(scenario(_, Content, _, _)) :- member(rule(_, _, _, _, _, _), Content).
is_rule_bearing_section(query(_, Content, _, _)) :- member(rule(_, _, _, _, _, _), Content).
is_rule_bearing_section(unknown_section(Tokens, _, _)) :- 
    ( member(word(if, _), Tokens) ; member(word(unless, _), Tokens) ).

is_rule_item(rule(_, _, _, _, _, _)).
is_rule_item(fact(_, _, _)).

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

section(kb(Name, Content, Start, End)) --> 
    any_indent, t(word(the, loc(Start, _))), t(word(contract)), kb_name_tokens_contract(Tokens), t(word(states)), t(word(that)), t(punctuation(':', _)),
    { reconstruct_name(Tokens, Name) },
    { ( le_kbs:do_log -> print_message(informational,'Parsing KB (contract): ~w~n' - [Name]); true) },
    kb_content(Content, End),
    { ( le_kbs:do_log -> print_message(informational,'Finished KB (contract): ~w~n' - [Name]); true) }.

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
section(unknown_section(Tokens, Start, End)) -->
    [T], { get_token_start(T, Start) },
    consume_until_next_section(Ts),
    { append([T], Ts, Tokens) },
    { last(Tokens, Last), ( get_token_end(Last, End) -> true ; End = Start) }.

% kb_name_tokens(Tokens) consumes tokens until the 'includes' keyword.
kb_name_tokens([T|Ts]) -->
    \+ t(word(includes)),
    t(T), !,
    kb_name_tokens(Ts).
kb_name_tokens([]) --> [].

% kb_name_tokens_contract(Tokens) consumes tokens until the 'states' keyword.
kb_name_tokens_contract([T|Ts]) -->
    \+ t(word(states)),
    t(T), !,
    kb_name_tokens_contract(Ts).
kb_name_tokens_contract([]) --> [].

% section_name_tokens(Tokens) consumes tokens until 'is' or ':'.
section_name_tokens([T|Ts]) -->
    \+ t(word(is)),
    \+ t(punctuation(':', _)),
    t(T), !,
    section_name_tokens(Ts).
section_name_tokens([]) --> [].

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
next_section_start --> any_indent, t(word(the, _)), t(word(contract)).
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
    { ( Content = [] -> End = 0; last(Content, Last), get_item_end(Last, End)) }.

get_item_end(rule(_, _, _, _, End, _), End) :- !.
get_item_end(Item, End) :-
    Item =.. List,
    last(List, End).

% kb_items([I|Is]) parses a sequence of rules or facts.
kb_items([I|Is]) --> \+ next_section_start, kb_item(I), !, kb_items(Is).
kb_items([]) --> [].

% kb_item(expected(QueryName, Answers, Unknowns, Start, End)) parses "QueryName expects answers [Answers] and unknowns [Unknowns]."
kb_item(expected(QueryName, Answers, Unknowns, Start, End)) -->
    query_name_tokens(Tokens), { Tokens \== [], reconstruct_name(Tokens, QueryName) },
    { Tokens = [First|_], get_token_start(First, Start) },
    t(word(expects)), t(word(answers)),
    t(punctuation('[')), list_elements(Answers), t(punctuation(']')),
    (   t(word(and)), t(word(unknowns)), t(punctuation('[')), list_elements(Unknowns), t(punctuation(']'))
    ->  []
    ;   { Unknowns = [] }
    ),
    (   (any_indent, t(punctuation('.' , loc(_, End))))
    ->  []
    ;   { 
          le_kbs:current_compiling_module(M),
          get_token_pos(Pos),
          format(atom(Desc), "Missing trailing dot for 'expects answers' in scenario", []),
          (nonvar(M) -> assertz(M:le_issue(error, missing_trailing_dot, Desc, "Add a dot at the end of the line.", Start, Pos)) ; true),
          End = Pos
        }
    ).


% kb_item(rule(Head, Body, Indent, Start, End, ID)) parses a Logical English rule (Head if Body).
kb_item(rule(Head, Body, Indent, Start, End, ID)) -->
    t(word(rule)), !, (t(word(ID)) | t(number(ID))), t(punctuation(':')),
    template_instance(Head),
    { Head = [First|_], get_token_start(First, Start) },
    any_indent(N), 
    (   t(word(if)), t(punctuation(':')) ->
        numbered_body(Body, End)
    ;   t(word(if, _)) ->
        body(Body, End)
    ;   t(word(only)), t(word(if)) ->
        body(Body0, End), { Body = only_if(Body0) }
    ;   t(word(unless)), t(punctuation(':')) ->
        numbered_body(Body0, End), { Body = unless(Body0) }
    ;   t(word(unless, _)) ->
        body(Body0, End), { Body = unless(Body0) }
    ),
    { Indent = N }.

kb_item(rule(Head, Body, Indent, Start, End, ID)) -->
    template_instance(Head),
    { Head = [First|_], get_token_start(First, Start) },
    any_indent(N), 
    (   t(word(if)), t(punctuation(':')) ->
        numbered_body(Body, End)
    ;   t(word(if, _)) ->
        body(Body, End)
    ;   t(word(only)), t(word(if)) ->
        body(Body0, End), { Body = only_if(Body0) }
    ;   t(word(unless)), t(punctuation(':')) ->
        numbered_body(Body0, End), { Body = unless(Body0) }
    ;   t(word(unless, _)) ->
        body(Body0, End), { Body = unless(Body0) }
    ),
    { Indent = N, ID = _ }.

% kb_item(unknown_fact(Head, Start, End)) parses "it is unknown whether <template instance>."
kb_item(unknown_fact(Head, Start, End)) -->
    t(word(it)), t(word(is)), t(word(unknown)), t(word(whether)),
    template_instance(Head),
    { Head = [First|_], get_token_start(First, Start) },
    any_indent, t(punctuation('.', loc(_, End))).

% kb_item(fact(Head, Start, End)) parses a Logical English fact (Head.).
kb_item(fact(Head, Start, End)) -->
    template_instance(Head),
    { Head = [First|_], get_token_start(First, Start) },
    any_indent, t(punctuation('.', loc(_, End))).

get_token_start(T, Start) :-
    ( T =.. [_, _, loc(Start, _)] -> true; T =.. [_, loc(Start, _)] -> true; Start = 0).

get_token_end(T, End) :-
    ( T =.. [_, _, loc(_, End)] -> true; T =.. [_, loc(_, End)] -> true; End = 0).

% templates(Ds) parses a list of template definitions. Each template definition
% may produce one or more dicts (a main dict plus an optional synthesized opposite
% dict that allows the opposite form to be matched directly during parsing).
templates(AllDicts) -->
    \+ next_section_start,
    template(TDicts), !,
    ( (t(punct('.')) ; t(punct(','))) -> ( templates(MoreDicts) | { MoreDicts = [] }); { MoreDicts = [] }),
    { append(TDicts, MoreDicts, AllDicts) }.
templates([]) --> [].

% template(Dicts) parses a single template definition into a list of dicts.
% The list always contains the main dict and, if an opposite was declared, a
% second synthesized dict for the opposite words so it can be matched directly.
% The Prep field is bound to the atom 'prepositional' if the template is marked
% prepositional; otherwise it is left unbound.
template(Dicts) -->
    template_instance(Tokens),
    { Tokens = [First|_], get_token_start(First, Start), last(Tokens, Last), get_token_end(Last, End) },
    { process_template(Tokens, FunctorArgs, NamesTypes, WordsAndVars) },
    template_additions(Globals, Opposite, OppositeWV, Prep, Unknown, NamesTypes, FunctorArgs, Start, End),
    { validate_prepositional_template(Prep, FunctorArgs, WordsAndVars, Start, End) },
    { MainDict = dict(FunctorArgs, NamesTypes, WordsAndVars, Start, End, Globals, Opposite, Prep, Unknown),
      (   nonvar(Opposite), nonvar(OppositeWV) ->
          MainLit =.. FunctorArgs,
          Opposite =.. [OppF | OppArgs],
          OppFA = [OppF | OppArgs],
          OppositeDict = dict(OppFA, NamesTypes, OppositeWV, Start, End, Globals, MainLit, Prep, Unknown),
          Dicts = [MainDict, OppositeDict]
      ;   Dicts = [MainDict]
      )
    }.

template_additions(Globals, Opposite, OppositeWV, Prep, Unknown, NTs, FunctorArgs, TStart, TEnd) -->
    t(punctuation(';', _)),
    (   t(word(defines)), t(word(global)) ->
        template_instance(Tokens),
        { reconstruct_name(Tokens, G) },
        template_additions(Gs, Opposite, OppositeWV, Prep, Unknown, NTs, FunctorArgs, TStart, TEnd),
        { Globals = [G|Gs] }
    ;   t(word(opposite)) ->
        template_instance(OppositeTokens0),
        % The colon written after 'opposite:' is captured as a punct token here;
        % strip it before processing so it doesn't show up in WordsAndVars.
        { (OppositeTokens0 = [punct(':', _)|RestTokens] -> OppositeTokens = RestTokens ; OppositeTokens = OppositeTokens0) },
        { process_template(OppositeTokens, OppositeFunctorArgs, _OppositeNamesTypes, OppositeWV) },
        % Unify variables by position so main args and opposite args share Prolog vars.
        { FunctorArgs = [_|Args], OppositeFunctorArgs = [OppF|OppArgs], unify_args(Args, OppArgs) },
        { Opposite =.. [OppF | OppArgs] },
        template_additions(Globals, _, _, Prep, Unknown, NTs, FunctorArgs, TStart, TEnd)
    ;   t(word(prepositional)) ->
        { Prep = prepositional },
        template_additions(Globals, Opposite, OppositeWV, _, Unknown, NTs, FunctorArgs, TStart, TEnd)
    ;   t(word(unknown)) ->
        { Unknown = unknown },
        template_additions(Globals, Opposite, OppositeWV, Prep, _, NTs, FunctorArgs, TStart, TEnd)
    ).
template_additions([], _, _, _, _, _, _, _, _) --> [].


% validate_prepositional_template(+Prep, +FunctorArgs, +WordsAndVars, +Start, +End)
% Reports an issue if the template marked 'prepositional' is malformed.
validate_prepositional_template(Prep, _, _, _, _) :- var(Prep), !.
validate_prepositional_template(prepositional, [_Functor|Args], WordsAndVars, Start, End) :-
    ( le_kbs:current_compiling_module(M) -> true ; M = (-) ),
    length(Args, N),
    (   N == 2 -> true
    ;   format(atom(Desc), "A prepositional template must have exactly two arguments (found ~w)", [N]),
        (M \== (-) -> assertz(M:le_issue(error, prepositional_arity, Desc, "Use exactly two *variables* in the template.", Start, End)) ; true)
    ),
    (   WordsAndVars = [V|_], var(V) -> true
    ;   Desc2 = "A prepositional template must start with an argument (its first token must be a *variable*)",
        (M \== (-) -> assertz(M:le_issue(error, prepositional_first_arg, Desc2, "Move the *variable* to the very beginning of the template.", Start, End)) ; true)
    ).
validate_prepositional_template(_, _, _, _, _).

unify_args([], []).
unify_args([A|As], [B|Bs]) :- A = B, unify_args(As, Bs).

process_template(Tokens, FunctorArgs, NamesTypes, WordsAndVars) :-
    extract_functor(Tokens, Functor),
    process_template_parts(Tokens, Args, NamesTypes, WordsAndVars),
    (   is_a_taxonomy_template(WordsAndVars, Args, Type, SuperType) ->
        FunctorArgs = [is_a, Type, SuperType]
    ;   FunctorArgs = [Functor|Args]
    ).

is_a_taxonomy_template(WordsAndVars, Args, Type, SuperType) :-
    (   WordsAndVars = [Type, is, a, SuperType]
    ;   WordsAndVars = [Type, is, an, SuperType]
    ;   WordsAndVars = [Type, is, of, SuperType]
    ),
    member_var(Type, Args),
    member_var(SuperType, Args).

member_var(V, [H|_]) :- V == H, !.
member_var(V, [_|T]) :- member_var(V, T).

extract_functor(Tokens, Functor) :-
    findall(W, (member(T, Tokens), (T = word(W, _) ; T = number(W, _))), Words),
    atomic_list_concat(Words, '_', Functor).

process_template_parts([], [], [], []).
process_template_parts([var(Words, _)|Ps], [V|Args], [V-Type|NTs], [V|WVs]) :-
    !, extract_var_info_from_words(Words, _Name, Type),
    process_template_parts(Ps, Args, NTs, WVs).
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

is_ignorable(W) :- memberchk(W, [a, an, the, are, was, were, has, have, had, do, does, did, been]).

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
template_instance_part(var(Words, loc(Start, End))) --> t(punctuation('*', loc(Start, _))), template_var_words(Words), t(punctuation('*', loc(_, End))).
template_instance_part(word(W, Loc)) --> t(word(W, Loc)).
template_instance_part(number(N, Loc)) --> t(number(N, Loc)).
template_instance_part(date(D, Loc)) --> t(date(D, Loc)).
template_instance_part(string(S, Loc)) --> t(quoteString(S, Loc)).
template_instance_part(string(S, Loc)) --> t(doubleQuoteString(S, Loc)).
template_instance_part(list(L)) --> t(punct('[')), list_elements(L), t(punct(']')).
template_instance_part(expr(E)) --> t(punct('(')), template_instance(E), t(punct(')')).
template_instance_part(punct(P, Loc)) --> t(punctuation(P, Loc)), { \+ member(P, ['[', ']', '(', ')']) }.
template_instance_part(punct('(', Loc)) --> t(punctuation('(', Loc)).
template_instance_part(punct(')', Loc)) --> t(punctuation(')', Loc)).

% template_var_words(Words) parses the words inside a *variable*.
template_var_words([W|Ws]) --> t(word(W)), !, template_var_words(Ws).
template_var_words([]) --> [].

% list_elements(Elements) parses a comma-separated list of template instances.
list_elements([E|Es]) --> template_instance(E), ( t(punct(',')), !, list_elements(Es) | { Es = [] } ).
list_elements([]) --> [].

numbered_body(numbered(Body), End) --> 
    numbered_body_tokens(Body), 
    any_indent, t(punctuation('.', loc(_, End))).

numbered_body_tokens([T|Ts]) -->
    \+ is_real_terminator,
    [T], !,
    numbered_body_tokens(Ts).
numbered_body_tokens([]) --> [].

is_real_terminator(Ts, Ts) :-
    Ts = [punctuation('.', _), indent(_, _) | _].
is_real_terminator(Ts, Ts) :-
    Ts = [punctuation('.', _)].

% body(Body, End) parses the body of a rule, ending with a period.
body(Body, End) --> body_tokens(Body), any_indent, t(punctuation('.', loc(_, End))).

% body_tokens(Tokens) parses the sequence of tokens in a rule body.
body_tokens([T|Ts]) --> \+ is_body_terminator, body_token(T), !, body_tokens(Ts).
body_tokens([]) --> [].

% body_token(Token) parses a single token in a rule body, including indentation.
body_token(T) --> [T].

% is_terminator matches tokens that end a template instance (period, comma, or 'if').
is_terminator --> any_indent, t(word(only)), t(word(if, _)).
is_terminator --> any_indent, t(punctuation(';', _)).
is_terminator --> any_indent, t(word(if)), t(punctuation(':', _)).
is_terminator --> any_indent, t(word(unless)), t(punctuation(':', _)).
is_terminator --> any_indent, t(punctuation('.', _)), peek_terminator.
is_terminator --> any_indent, t(punctuation(',', _)).
is_terminator --> any_indent, t(word(if, _)).
is_terminator --> any_indent, t(word(unless, _)).
is_terminator --> any_indent, t(word(either, _)).
is_terminator --> any_indent, t(word(any, _)), t(word(of, _)).
is_terminator --> any_indent, t(word(all, _)), t(word(of, _)).
is_terminator --> any_indent, t(word(and, _)), t(word(unless, _)).
is_terminator --> any_indent, t(word(expects, _)).

peek_terminator, [T] --> [T], { is_indent_or_comment(T) }, !.
peek_terminator --> eos.

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
t(T) --> any_indent, [T], { T \= indent(_, _), T \= line_comment(_, _), T \= multi_comment(_, _), ( T =.. [_, _, loc(Start, _)] -> set_token_pos(Start); true) }.
t(word(W, L)) --> any_indent, [word(W, L)], { L = loc(Start, _), set_token_pos(Start) }.
t(word(W)) --> any_indent, [word(W, L)], { L = loc(Start, _), set_token_pos(Start) }.
t(number(N, L)) --> any_indent, [number(N, L)], { L = loc(Start, _), set_token_pos(Start) }.
t(number(N)) --> any_indent, [number(N, L)], { L = loc(Start, _), set_token_pos(Start) }.
t(punctuation(P, L)) --> any_indent, [punctuation(P, L)], { L = loc(Start, _), set_token_pos(Start) }.
t(punctuation(P)) --> any_indent, [punctuation(P, L)], { L = loc(Start, _), set_token_pos(Start) }.
t(punct(P, L)) --> any_indent, [punctuation(P, L)], { L = loc(Start, _), set_token_pos(Start) }.
t(punct(P)) --> any_indent, [punctuation(P, L)], { L = loc(Start, _), set_token_pos(Start) }.
t(date(D, L)) --> any_indent, [date(D, L)], { L = loc(Start, _), set_token_pos(Start) }.
t(date(D)) --> any_indent, [date(D, L)], { L = loc(Start, _), set_token_pos(Start) }.
t(quoteString(S, L)) --> any_indent, [quoteString(S, L)], { L = loc(Start, _), set_token_pos(Start) }.
t(doubleQuoteString(S, L)) --> any_indent, [doubleQuoteString(S, L)], { L = loc(Start, _), set_token_pos(Start) }.

skip_comments --> any_indent.

% Semantics: Helper functions
is_proper_name_atom(W) :-
    atom(W),
    atom_codes(W, [C|Codes]),
    code_type(C, upper),
    % Must not be all caps (those are IDs/variables)
    ( Codes == [] -> true ; member(C2, Codes), code_type(C2, lower) ).

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

is_reserved(W) :- member(W, [says, that, if, and, or, unless]).

extract_id(Words, Name) :-
    \+ (member(W, Words), is_reserved(W)),
    ( append(TypeWords, [ID], Words), TypeWords \== [], is_id(ID) -> Name = ID; atomic_list_concat(Words, ' ', Name)).

extract_var_name(Words, Name) :-
    extract_var_name_extension(Words, Name), !.
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
        ; Words = [what | Rest], Rest \== [] ->  
            length(Rest, L), L =< 5,
            extract_id(Rest, Name)
        ; Words = [who] -> Name = 'Who'
        ; Words = [what] -> Name = 'What'
        ; Words = [when] -> Name = 'When'
        ; Words = [where] -> Name = 'Where'
        ; Words = [W], is_id(W) -> Name = W
    ).

unify_with_vmap(Name, Var, VMIn, VMOut, IsVar) :-
    unify_with_vmap_extension(Name, Var, VMIn, VMOut, IsVar), !.
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

unify_with_vmap(Name, Var, VMIn, VMOut) :-
    unify_with_vmap(Name, Var, VMIn, VMOut, false).

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

check_global_abbreviation(Words, Templates, Var, VMIn, VMOut) :-
    reconstruct_name_acc(Words, Name),
    % Find a template that defines this name as a global
    member(dict(FunctorArgs, _NTs, _WV, _S, _E, _NIW, Globals, _Opposite, _Prep, _Unknown), Templates),
    member(Name, Globals),
    !,
    % Use the template's identity (e.g., its Functor) to group variables in VM
    FunctorArgs = [Functor | _],
    (   member(global_template(Functor)-Var, VMIn) ->
        VMOut = VMIn
    ;   copy_term(FunctorArgs, [Functor | Args]),
        member(Var, Args),
        Goal =.. [Functor | Args],
        VMOut = [global_template(Functor)-Var, extra_goal(Goal) | VMIn]
    ).

extract_value_from_parts(Parts, Value, VMIn, VMOut, Templates, NoTransform, AllowVars, Depth) :-
    (   Parts = [Part], extract_value(Part, Value, VMIn, VMOut, Templates, AllowVars) -> true
        ; (Parts = [number(N, _)] ; Parts = [number(N)]) -> Value = N, VMOut = VMIn
        ; (Parts = [string(S, _)] ; Parts = [string(S)]) -> Value = S, VMOut = VMIn
        ; (Parts = [date(D, _)] ; Parts = [date(D)]) -> Value = D, VMOut = VMIn
        ; maplist(extract_simple_word, Parts, Words),
          (   check_global_abbreviation(Words, Templates, Value, VMIn, VMOut) -> true
              ; AllowVars == true, extract_var_name(Words, Name) -> unify_with_vmap(Name, Value, VMIn, VMOut, true)
              ; NoTransform \== true, transform_instance(Parts, Templates, VMIn, VMOut, Value, AllowVars, Depth) -> true
              ; is_proper_name(Words) -> tokens_to_string(Parts, Value), VMOut = VMIn
              ; parse_expression(Parts, VMIn, VMOut, Templates, Value, AllowVars),
                \+ is_hyphenated_id(Value, VMIn) -> true
              ; AllowVars == false -> ( Words = [Value] -> true; tokens_to_string(Parts, Value)), VMOut = VMIn
              ; % Fallback: treat as constant if not a variable name
                tokens_to_string(Parts, Value), VMOut = VMIn
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
extract_simple_value(indent(_, _), '').
extract_simple_value(line_comment(_, _), '').
extract_simple_value(multi_comment(_, _), '').
extract_simple_value(list(_), '[]').
extract_simple_value(expr(_), '()').
extract_simple_value(var(Words, _), Atom) :- !, atomic_list_concat(Words, ' ', Atom).
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

extract_value(var(Words, _), Val, VMIn, VMOut, Templates, AllowVars) :- !,
    extract_value(var(Words), Val, VMIn, VMOut, Templates, AllowVars).
extract_value(var(Words), Val, VMIn, VMOut, _Templates, AllowVars) :-
    !, extract_var_info_from_words(Words, Name, _Type),
    ( AllowVars == true -> unify_with_vmap(Name, Val, VMIn, VMOut, true); Val = Name, VMOut = VMIn).
extract_value(word(W, _), Val, VMIn, VMOut, _Templates, AllowVars) :-
    ( le_kbs:do_log -> print_message(informational,'Extract value word: ~w (AllowVars: ~w)~n' - [W, AllowVars]); true),
    ( AllowVars == false -> Val = W, VMOut = VMIn; 
      (extract_var_name([W], Name) -> unify_with_vmap(Name, Val, VMIn, VMOut, true) ; unify_with_vmap(W, Val, VMIn, VMOut, false))
    ).
extract_value(number(N, _), N, VM, VM, _, _).
extract_value(date(D, _), D, VM, VM, _, _).
extract_value(quoteString(S, _), S, VM, VM, _, _).
extract_value(doubleQuoteString(S, _), S, VM, VM, _, _).
extract_value(punctuation(P, _), P, VM, VM, _, _).
extract_value(punct(P, _), P, VM, VM, _, _).
extract_value(word(W), Val, VMIn, VMOut, _Templates, AllowVars) :-
    ( AllowVars == false -> Val = W, VMOut = VMIn; 
      (extract_var_name([W], Name) -> unify_with_vmap(Name, Val, VMIn, VMOut, true) ; unify_with_vmap(W, Val, VMIn, VMOut, false))
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
    ( Depth > 1 -> fail; true),
    ( le_kbs:do_log -> maplist(extract_simple_word, Instance, Words), print_message(informational,'Transform instance (depth ~w): ~w~n' - [Depth, Words]); true),
    D1 is Depth + 1,
    ( match_template(Instance, Templates, VMIn, VMOut, Transformed, AllowVars, D1) -> true; extract_value_from_parts(Instance, Transformed, VMIn, VMOut, Templates, true, AllowVars, D1)).

match_template(Instance, Templates, VMIn, VMOut, Literal, AllowVars, Depth) :-
    maplist(extract_simple_word, Instance, Words),
    member(dict(FunctorArgs, _NTs, WordsAndVars, _Start, _End, NIW, _Globals, _Opposite, _Prep, _Unknown), Templates),
    copy_term(dict(FunctorArgs, WordsAndVars, NIW), dict(FunctorArgsCopy, WordsAndVarsCopy, NIWCopy)),
    contains_subsequence(NIWCopy, Words),
    match_instance_to_template(Instance, WordsAndVarsCopy, VMIn, VMOut, Templates, AllowVars, Depth),
    Literal =.. FunctorArgsCopy.

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
                % Optimization: find a split that matches the next constant part
                % and satisfies the variable extraction.
                (
                    append(VarTokens, [NextI|Rest], Instance),
                    VarTokens \== [],
                    match_part(NextI, NextT, VMIn, VM1, Templates, AllowVars),
                    extract_value_from_parts(VarTokens, T, VM1, VM2, Templates, false, AllowVars, Depth),
                    match_instance_to_template_acc(Rest, RestTs, VM2, VMOut, Templates, AllowVars, Depth)
                )
            ; Ts = [] ->  
                VarTokens = Instance,
                VarTokens \== [],
                extract_value_from_parts(VarTokens, T, VMIn, VMOut, Templates, false, AllowVars, Depth)
            ; % Next part is also a variable, must try all splits
              (
                append(VarTokens, Rest, Instance),
                VarTokens \== [],
                extract_value_from_parts(VarTokens, T, VMIn, VM1, Templates, false, AllowVars, Depth),
                match_instance_to_template_acc(Rest, Ts, VM1, VMOut, Templates, AllowVars, Depth)
              )
        )
    ).

%!  prepare_templates(+DictsIn:list, -DictsOut:list) is det.
%
%   Prepares a list of template dictionaries for use in parsing.
%   Adds non-ignorable words and sorts them by specificity.
prepare_templates(DictsIn, DictsOut) :-
    sort(DictsIn, UniqueDicts),
    maplist(add_non_ignorable, UniqueDicts, AllDictsWithWords),
    sort_templates(AllDictsWithWords, DictsOut).

% Semantics: Second Pass
second_pass(Sections, NewSections, M) :-
    retractall(is_a_type(_)),
    retractall(is_a_taxonomy_edge(_, _, _)),
    ( le_kbs:do_log -> length(Sections, L), print_message(informational,'Second pass: ~w sections~n' - [L]); true),
    % Collect all templates from all sections first
    findall(Dict, (member(S, Sections), get_dicts(S, Dicts), member(Dict, Dicts)), UserDicts),
    findall(SystemDict, le_system_template(SystemDict), SystemDicts),
    append(UserDicts, SystemDicts, AllDicts),
    prepare_templates(AllDicts, SortedDicts),
    % Collect types from templates
    forall(member(dict(_, NTs, _, _, _, _, _, _, _, _), SortedDicts),
           forall(member(_-Type, NTs), (atom(Type) -> assert_is_a_type(Type) ; true))),
    % Collect types from ontology
    forall(member(S, Sections), collect_types_in_section(S, SortedDicts)),
    maplist(second_pass_section(SortedDicts, M), Sections, NewSections).

collect_types_in_section(ontology(Content, _, _), Templates) :-
    forall(member(Item, Content), collect_types_in_item(Item, Templates)).
collect_types_in_section(_, _).

collect_types_in_item(fact(Head, _, _), Templates) :-
    (   parse_literal(Head, Templates, [], _, Literal, _, false), Literal = is_a(_, _) ->
        match_is_a(Head, _, _, TypeAtom, SuperTypeAtom, [], _, false),
        assert_is_a_type(TypeAtom), assert_is_a_type(SuperTypeAtom)
    ; true).
collect_types_in_item(rule(Head, BodyTokens, Indent, _, _), Templates) :-
    (   parse_literal(Head, Templates, [], VM1, Literal, _, true), Literal = is_a(_, _) ->
        match_is_a(Head, _, _, TypeAtom, SuperTypeAtom, [], _, true),
        assert_is_a_type(TypeAtom), assert_is_a_type(SuperTypeAtom)
    ; true),
    % Also collect from body
    ( parse_body(BodyTokens, Indent, Templates, VM1, _, Body) -> collect_types_from_body(Body); true).

collect_types_from_body(and(A, B)) :- !, collect_types_from_body(A), collect_types_from_body(B).
collect_types_from_body(or(A, B)) :- !, collect_types_from_body(A), collect_types_from_body(B).
collect_types_from_body(not(A)) :- !, collect_types_from_body(A).
collect_types_from_body(is_a(_, Type)) :- !, assert_is_a_type(Type).
collect_types_from_body(_).

assert_is_a_type(T) :-
    (   atom(T), \+ is_id(T), \+ is_article(T), \+ is_reserved(T) ->
        (is_a_type(T) -> true; assertz(is_a_type(T)))
    ;   true
    ).


add_non_ignorable(dict(FA, NT, WV, Start, End, Globals, Opposite, Prep, Unknown), dict(FA, NT, WV, Start, End, NIW, Globals, Opposite, Prep, Unknown)) :- !,
    findall(W, (member(W, WV), atom(W), \+ is_reserved(W), \+ is_ignorable(W)), NIW).
add_non_ignorable(dict(FA, NT, WV, Start, End, Globals, Opposite, Prep), dict(FA, NT, WV, Start, End, NIW, Globals, Opposite, Prep, _)) :- !,
    findall(W, (member(W, WV), atom(W), \+ is_reserved(W), \+ is_ignorable(W)), NIW).
add_non_ignorable(dict(FA, NT, WV, Start, End, Globals, Opposite), dict(FA, NT, WV, Start, End, NIW, Globals, Opposite, _, _)) :- !,
    findall(W, (member(W, WV), atom(W), \+ is_reserved(W), \+ is_ignorable(W)), NIW).
add_non_ignorable(dict(FA, NT, WV, Start, End, Globals), dict(FA, NT, WV, Start, End, NIW, Globals, _, _, _)) :- !,
    findall(W, (member(W, WV), atom(W), \+ is_reserved(W), \+ is_ignorable(W)), NIW).
add_non_ignorable(dict(FA, NT, WV, Globals), dict(FA, NT, WV, 0, 0, NIW, Globals, _, _, _)) :- !,
    findall(W, (member(W, WV), atom(W), \+ is_reserved(W), \+ is_ignorable(W)), NIW).
add_non_ignorable(dict(FA, NT, WV, Start, End), dict(FA, NT, WV, Start, End, NIW, [], _, _, _)) :- !,
    findall(W, (member(W, WV), atom(W), \+ is_reserved(W), \+ is_ignorable(W)), NIW).
add_non_ignorable(dict(FA, NT, WV), dict(FA, NT, WV, 0, 0, NIW, [], _, _, _)) :-
    findall(W, (member(W, WV), atom(W), \+ is_reserved(W), \+ is_ignorable(W)), NIW).


sort_templates(Dicts, Sorted) :-
    partition(is_meta_template, Dicts, Meta, Regular),
    map_list_to_pairs(template_priority, Regular, Pairs),
    keysort(Pairs, SortedPairs),
    reverse(SortedPairs, RevSortedPairs),
    pairs_values(RevSortedPairs, SortedRegular),
    append(Meta, SortedRegular, Sorted).

template_priority(dict(FA, _, WordsAndVars, _, _, _, _, _, _, _), Priority-Score) :-
    findall(1, (member(W, WordsAndVars), atom(W)), Words),
    length(Words, Score),
    ( FA = [le_is|_] -> Priority = -2
    ; FA = [le_is_in|_] -> Priority = -1
    ; FA = [Functor|_], sub_atom(Functor, 0, 3, _, le_) -> Priority = -1
    ; Priority = 0
    ).


is_meta_template(dict(_, _, WordsAndVars, _, _, _, _, _, _)) :-
    member(W, WordsAndVars),
    (W == that ; W == says).

get_dicts(predicates(Ds), Ds).
get_dicts(templates(Ds), Ds).
get_dicts(fluents(Ds), Ds).
get_dicts(events(Ds), Ds).
get_dicts(meta(Ds), Ds).
get_dicts(_, []).

second_pass_section(Templates, M, kb(Name, Content, Start, End), kb(Name, NewContent, Start, End)) :-
    second_pass_content(Content, Templates, NewContent, M).
second_pass_section(_, _, unknown_section(Tokens, Start, End), unknown_section(Tokens, Start, End)).
second_pass_section(Templates, M, ontology(Content, Start, End), ontology(NewContent, Start, End)) :-
    maplist(second_pass_ontology_item_with_module(Templates, M), Content, NewContent).
second_pass_section(Templates, M, scenario(Name, Content, Start, End), scenario(Name, NewContent, Start, End)) :-
    maplist(second_pass_scenario_item_with_module(Templates, M), Content, NewContent).
second_pass_section(Templates, M, query(Name, Content, Start, End), query(Name, NewContent, Start, End)) :-
    maplist(second_pass_query_item_with_module(Templates, M), Content, NewContent).
second_pass_section(_, _, S, S). % Keep other sections as is

second_pass_ontology_item_with_module(Templates, M, Item, NewItem) :-
    second_pass_ontology_item(Templates, Item, NewItem, M).

second_pass_scenario_item_with_module(Templates, M, Item, NewItem) :-
    second_pass_scenario_item(Templates, Item, NewItem, M).

second_pass_query_item_with_module(Templates, M, Item, NewItem) :-
    second_pass_query_item(Templates, Item, NewItem, M).

second_pass_content(Items, Templates, NewItems, M) :-
    ( le_kbs:do_log -> length(Items, L), print_message(informational,'Second pass content: ~w items~n' - [L]); true),
    maplist(second_pass_item_with_module(Templates, M), Items, NewItems).

second_pass_item_with_module(Templates, M, Item, NewItem) :-
    ( second_pass_item_extension(Templates, Item, NewItem, M) -> true
    ; second_pass_item(Templates, Item, NewItem, M)
    ).

second_pass_item(Templates, rule(Head, only_if(BodyTokens), Indent, Start, End, ID), clause(NewHead, NewBody, Start, End, ActualID), _M) :-
    (var(ID) -> (le_kbs:rule_counter(C) -> true ; C = 1), format(atom(ActualID), 'rule_~w', [C]) ; ActualID = ID),
    (   parse_literal(Head, Templates, [], VM1, HeadLiteral, _, true) ->
        % Find the opposite of HeadLiteral
        functor(HeadLiteral, F, A),
        (   member(dict([F|Args], _NTs, _WV, _S, _E, _NIW, _Globals, Opposite, _Prep, _Unknown), Templates), length(Args, A), nonvar(Opposite) ->
            % Opposite is a term like I_will_not_marry(X)
            % We need to unify its variables with HeadLiteral's variables
            HeadLiteral =.. [F | HeadArgs],
            copy_term(dict(Args, Opposite), dict(HeadArgs, NewHead))
        ;   NewHead = not(HeadLiteral)
        ),
        (   parse_body(BodyTokens, Indent, Templates, VM1, VMOut, SubBody) ->
            collect_extra_goals(VMOut, ExtraGoals),
            ( ExtraGoals == [] -> NewBody = not(SubBody) ; list_to_conj([not(SubBody) | ExtraGoals], NewBody) )
        ;   NewBody = true
        ),
        ( le_kbs:do_log -> format('only_if rule: ~w if ~w~n', [NewHead, NewBody]) ; true )
    ;   NewHead = unknown_template(Head), NewBody = true
    ).

second_pass_item(Templates, rule(Head, unless(BodyTokens), Indent, Start, End, ID), clause(NewHead, NewBody, Start, End, ActualID), _M) :-
    (var(ID) -> format(atom(ActualID), 'rule_~w', [Start]) ; ActualID = ID),
    (   parse_literal(Head, Templates, [], VM1, NewHead, _, true) ->  
        (   parse_body(BodyTokens, Indent, Templates, VM1, VMOut, SubBody) ->  
            collect_extra_goals(VMOut, ExtraGoals),
            ( ExtraGoals == [] -> NewBody = not(SubBody) ; list_to_conj([not(SubBody) | ExtraGoals], NewBody) )
            ;   
            NewBody = true % Fallback
        )
        ;   
        NewHead = unknown_template(Head),
        ( parse_body(BodyTokens, Indent, Templates, [], _VMOut, SubBody) -> NewBody = not(SubBody); NewBody = true)
    ).

second_pass_item(Templates, rule(Head, numbered(BodyTokens), _Indent, Start, End, ID), clause(NewHead, NewBody, Start, End, ActualID), M) :-
    (var(ID) -> (le_kbs:rule_counter(C) -> true ; C = 1), format(atom(ActualID), 'rule_~w', [C]) ; ActualID = ID),
    (   parse_literal(Head, Templates, [], VM1, NewHead, _, true) ->  
        (   le_extensions:parse_numbered_body(BodyTokens, Templates, VM1, VMOut, Body0, ActualID, M) ->  
            collect_extra_goals(VMOut, ExtraGoals),
            ( ExtraGoals == [] -> NewBody = Body0 ; list_to_conj([Body0 | ExtraGoals], NewBody) )
            ;   
            NewBody = true % Fallback
        )
        ;   
        NewHead = unknown_template(Head),
        ( le_extensions:parse_numbered_body(BodyTokens, Templates, [], _VMOut, NewBody, ActualID, M) -> true; NewBody = true)
    ).

second_pass_item(Templates, rule(Head, BodyTokens, Indent, Start, End, ID), clause(NewHead, NewBody, Start, End, ActualID), _M) :-
    (var(ID) -> (le_kbs:rule_counter(C) -> true ; C = 1), format(atom(ActualID), 'rule_~w', [C]) ; ActualID = ID),
    ( le_kbs:do_log -> maplist(extract_simple_word, Head, Words), print_message(informational,'Processing rule: ~w~n' - [Words]); true),
    (   parse_literal(Head, Templates, [], VM1, NewHead, _, true) ->  
        (   parse_body(BodyTokens, Indent, Templates, VM1, VMOut, Body0) ->  
            ( le_kbs:do_log -> print_message(informational,'  Rule succeeded~n'); true),
            collect_extra_goals(VMOut, ExtraGoals),
            ( ExtraGoals == [] -> NewBody = Body0 ; list_to_conj([Body0 | ExtraGoals], NewBody) )
            ;   
            ( le_kbs:do_log -> print_message(informational,'  Rule body failed to parse~n'); true),
            NewBody = true % Fallback
        )
        ;   
        ( le_kbs:do_log -> print_message(informational,'  Rule head failed to match template~n'); true),
        NewHead = unknown_template(Head),
        ( parse_body(BodyTokens, _Indent, Templates, [], _VMOut, NewBody) -> true; NewBody = true)
    ).

second_pass_item(Templates, unknown_fact(Head, Start, End), clause(NewHead, NewBody, Start, End, ActualID), _M) :-
    (le_kbs:rule_counter(C) -> true ; C = 1), format(atom(ActualID), 'rule_~w', [C]),
    (   parse_literal(Head, Templates, [], VMOut, Literal, _, true) ->  
        NewHead = le_unknown(Literal),
        collect_extra_goals(VMOut, ExtraGoals),
        ( ExtraGoals == [] -> NewBody = true ; list_to_conj(ExtraGoals, NewBody) )
        ;   
        NewHead = unknown_template(Head),
        NewBody = true
    ).

second_pass_item(Templates, fact(Head, Start, End), clause(NewHead, NewBody, Start, End, ActualID), _M) :-
    (le_kbs:rule_counter(C) -> true ; C = 1), format(atom(ActualID), 'rule_~w', [C]),
    (   parse_literal(Head, Templates, [], VMOut, NewHead, _, true) ->  
        collect_extra_goals(VMOut, ExtraGoals),
        ( ExtraGoals == [] -> NewBody = true ; list_to_conj(ExtraGoals, NewBody) )
        ;   
        NewHead = unknown_template(Head),
        NewBody = true
    ).

collect_extra_goals(VM, Goals) :-
    collect_extra_goals_acc(VM, Goals).

collect_extra_goals_acc([], []).
collect_extra_goals_acc([extra_goal(G)|Rest], [G|Gs]) :- !, collect_extra_goals_acc(Rest, Gs).
collect_extra_goals_acc([_|Rest], Gs) :- collect_extra_goals_acc(Rest, Gs).

list_to_conj([G], G) :- !.
list_to_conj([G|Gs], and(G, Rest)) :- list_to_conj(Gs, Rest).
list_to_conj([], true).


second_pass_ontology_item(Templates, fact(Head, Start, End), clause(NewHead, NewBody, Start, End, _ID), _M) :-
    (   match_is_a(Head, _, _, TypeAtom, SuperTypeAtom, [], _VMOut1, false) ->
        NewHead = is_a(TypeAtom, SuperTypeAtom),
        NewBody = true,
        assertz(is_a_taxonomy_edge(TypeAtom, SuperTypeAtom, Start))
    ;   parse_literal(Head, Templates, [], VMOut2, NewHead0, _, false) -> 
        collect_extra_goals(VMOut2, ExtraGoals),
        ( ExtraGoals == [] -> NewBody = true ; list_to_conj(ExtraGoals, NewBody) ),
        ( NewHead0 = is_a(_, _) -> 
            match_is_a(Head, _, _, TypeAtom, SuperTypeAtom, [], _VMOut3, false),
            NewHead = is_a(TypeAtom, SuperTypeAtom),
            assertz(is_a_taxonomy_edge(TypeAtom, SuperTypeAtom, Start))
          ; NewHead = NewHead0
        )
    ;   NewHead = unknown_template(Head, Start, End), NewBody = true
    ).
second_pass_ontology_item(Templates, rule(Head, BodyTokens, Indent, Start, End, ID), clause(NewHead, NewBody, Start, End, ActualID), _M) :-
    (var(ID) -> (le_kbs:rule_counter(C) -> true ; C = 1), format(atom(ActualID), 'rule_~w', [C]) ; ActualID = ID),
    ( parse_literal(Head, Templates, [], VM1, NewHead, _, true) -> 
        parse_body(BodyTokens, Indent, Templates, VM1, VMOut4, Body0),
        collect_extra_goals(VMOut4, ExtraGoals),
        ( (NewHead = is_a(Var, SuperType), member(Name-Var, VM1), is_a_type(Name), Name \== SuperType, \+ memberchk(Name, [thing, asset, person, object, entity, element])) ->
            (Body0 == true -> Body1 = is_a(Var, Name) ; Body1 = and(is_a(Var, Name), Body0))
          ; Body1 = Body0
        ),
        ( ExtraGoals == [] -> NewBody = Body1 ; list_to_conj([Body1 | ExtraGoals], NewBody) )
        ; 
        NewHead = unknown_template(Head, Start, End), 
        parse_body(BodyTokens, Indent, Templates, [], _VMOut5, NewBody)
    ).

second_pass_scenario_item(Templates, rule(Head, BodyTokens, Indent, Start, End, ID), clause(NewHead, NewBody, Start, End, ActualID), _M) :-
    (var(ID) -> (le_kbs:rule_counter(C) -> true ; C = 1), format(atom(ActualID), 'rule_~w', [C]) ; ActualID = ID),
    ( parse_literal(Head, Templates, [], VM1, NewHead, _, true) -> 
        parse_body(BodyTokens, Indent, Templates, VM1, VMOut6, Body0),
        collect_extra_goals(VMOut6, ExtraGoals),
        ( ExtraGoals == [] -> NewBody = Body0 ; list_to_conj([Body0 | ExtraGoals], NewBody) )
        ; 
        NewHead = unknown_template(Head, Start, End), 
        parse_body(BodyTokens, Indent, Templates, [], _VMOut7, NewBody)
    ).
second_pass_scenario_item(Templates, fact(Head, Start, End), clause(NewHead, NewBody, Start, End, _ID), _M) :-
    ( parse_literal(Head, Templates, [], VMOut8, NewHead, _, false) -> 
        collect_extra_goals(VMOut8, ExtraGoals),
        ( ExtraGoals == [] -> NewBody = true ; list_to_conj(ExtraGoals, NewBody) )
        ; NewHead = unknown_template(Head, Start, End), NewBody = true).

second_pass_scenario_item(Templates, unknown_fact(Head, Start, End), clause(NewHead, NewBody, Start, End, _ID), _M) :-
    (   parse_literal(Head, Templates, [], VMOut, Literal, _, true) ->  
        NewHead = le_unknown(Literal),
        collect_extra_goals(VMOut, ExtraGoals),
        ( ExtraGoals == [] -> NewBody = true ; list_to_conj(ExtraGoals, NewBody) )
        ;   
        NewHead = unknown_template(Head),
        NewBody = true
    ).

second_pass_scenario_item(_Templates, expected(QueryName, Answers, Unknowns, Start, End), expected(QueryName, AnswerStrings, UnknownStrings, Start, End), _M) :-
    maplist(extract_answer_string, Unknowns, UnknownStrings),
    maplist(extract_answer_string, Answers, AnswerStrings).

second_pass_query_item(Templates, fact(Head, Start, End), query_clause(NewHead, Head, Instance, Start, End), _M) :-
    ( parse_literal(Head, Templates, [], VMOut9, NewHead0, Instance, true) -> 
        collect_extra_goals(VMOut9, ExtraGoals),
        ( ExtraGoals == [] -> NewHead = NewHead0 ; list_to_conj([NewHead0 | ExtraGoals], NewHead) )
        ; NewHead = unknown_template(Head, Start, End), Instance = Head).

second_pass_query_item(Templates, rule(Head, BodyTokens, Indent, Start, End, ID), query_clause(NewHead, Head, BodyTokens, Instance, Indent, Start, End, ActualID), _M) :-
    (var(ID) -> (le_kbs:rule_counter(C) -> true ; C = 1), format(atom(ActualID), 'rule_~w', [C]) ; ActualID = ID),
    ( parse_literal(Head, Templates, [], VM1, NewHead0, Instance, true) -> 
        parse_body(BodyTokens, Indent, Templates, VM1, VMOut10, Body0),
        collect_extra_goals(VMOut10, ExtraGoals),
        ( ExtraGoals == [] -> NewHead = and(NewHead0, Body0) ; list_to_conj([NewHead0, Body0 | ExtraGoals], NewHead) )
        ; 
        NewHead = unknown_template(Head, Start, End), Instance = Head,
        parse_body(BodyTokens, Indent, Templates, [], _VMOut11, _Body)
    ).

extract_answer_string(Tokens, string(String, loc(Start, End))) :-
    Tokens = [First|_],
    get_token_start(First, Start),
    last(Tokens, Last),
    get_token_end(Last, End),
    le_kbs:canonical_string(Tokens, String).

match_is_a(Parts, Type, SuperType, VMIn, VMOut, AllowVars) :-
    exclude(is_indent_or_comment, Parts, CleanParts),
    match_is_a(CleanParts, Type, SuperType, _, _, VMIn, VMOut, AllowVars).

match_is_a(Parts, Type, SuperType, TypeAtom, SuperTypeAtom, VMIn, VMOut, AllowVars) :-
    maplist(extract_simple_word, Parts, Words),
    once((
        append(TypeWords, [is, a | SuperTypeWords], Words)
    ;   append(TypeWords, [is, an | SuperTypeWords], Words)
    ;   append(TypeWords, [is, of | SuperTypeWords], Words)
    )),
    TypeWords \== [], SuperTypeWords \== [],
    % Find the corresponding tokens for TypeWords and SuperTypeWords
    append(TypeTokens, [Is, A | SuperTypeTokens], Parts),
    extract_simple_word(Is, is), (extract_simple_word(A, a) ; extract_simple_word(A, an) ; extract_simple_word(A, of)),
    !,
    extract_value_from_parts(TypeTokens, Type, VMIn, VM1, [], false, AllowVars, 0),
    extract_value_from_parts(SuperTypeTokens, SuperType, VM1, VMOut, [], false, AllowVars, 0),
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

parse_literal(Tokens, Templates, VMIn, VMOut, Literal, Instance) :-
    parse_literal(Tokens, Templates, VMIn, VMOut, Literal, Instance, true).

parse_literal(Tokens, Templates, VMIn, VMOut, Literal, Instance, AllowVars) :-
    exclude(is_indent_or_comment, Tokens, CleanTokens),
    ( le_kbs:do_log -> maplist(extract_simple_word, CleanTokens, Words), print_message(informational,'Parsing literal: ~w~n' - [Words]); true),
    parse_literal_real(CleanTokens, Templates, VMIn, VMOut, Literal, Instance, AllowVars),
    ( le_kbs:do_log -> print_message(informational,'  Succeeded: ~w~n' - [Literal]); true).

parse_literal_real(Tokens, Templates, VMIn, VMOut, Literal, Instance, AllowVars) :-
    maplist(extract_simple_word, Tokens, Words),
    (   % First try chained matching: a non-prepositional template consumes a prefix,
        % then one or more prepositional templates chain to the suffix, with their
        % leading argument bound to a type-compatible variable from the previous part.
        match_template_with_chaining(Tokens, Templates, VMIn, VMOut, Literal, Instance, AllowVars, 0) -> true
        ;
        member(dict(FunctorArgs, _NTs, WordsAndVars, _Start, _End, NIW, _Globals, _Opposite, _Prep, _Unknown), Templates),
        \+ (FunctorArgs = [le_is|_]),
        contains_subsequence(NIW, Words),
        copy_term(dict(FunctorArgs, WordsAndVars), dict(FunctorArgsCopy, WordsAndVarsCopy)),
        match_instance_to_template(Tokens, WordsAndVarsCopy, VMIn, VMOut0, Templates, AllowVars, 0),
        Literal =.. FunctorArgsCopy,
        Instance = WordsAndVarsCopy,
        ( post_parse_literal_hook(WordsAndVarsCopy, Literal, VMOut0, VMOut) -> true ; VMOut = VMOut0 ) -> true
        ;
        match_is_a(Tokens, Type, SuperType, VMIn, VMOut, AllowVars) -> Literal = is_a(Type, SuperType), Instance = [Type, is, a, SuperType]
        ;
        % Fallback to le_is
        member(dict([le_is, V1, V2], _NTs2, WordsAndVars, _Start2, _End2, _NIW2, _Globals2, _Opposite2, _Prep2, _Unknown2), Templates),
        copy_term(dict([le_is, V1, V2], WordsAndVars), dict([le_is, V1Copy, V2Copy], WordsAndVarsCopy)),
        match_instance_to_template(Tokens, WordsAndVarsCopy, VMIn, VMOut, Templates, AllowVars, 0) -> Literal = le_is(V1Copy, V2Copy), Instance = WordsAndVarsCopy
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
    (multi_word_var(Rest) ; { Rest = [] }).

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
expr_logic(E, VMIn, VMOut, T, AllowVars) --> 
    term_logic(T1, VMIn, VM1, T, AllowVars), 
    expr_tail(T1, E, VM1, VMOut, T, AllowVars).

expr_tail(T1, E, VM1, VMOut, T, AllowVars) --> 
    [punctuation(Op, _)], { member(Op, ['+', '-']) }, 
    term_logic(T2, VM1, VM2, T, AllowVars), 
    { E1 =.. [Op, T1, T2] }, 
    expr_tail(E1, E, VM2, VMOut, T, AllowVars).
expr_tail(E, E, VM, VM, _, _) --> [].

% term_logic(Term, ...) parses an arithmetic term with multiplication and division.
term_logic(T, VMIn, VMOut, Ts, AllowVars) --> 
    factor_logic(F1, VMIn, VM1, Ts, AllowVars), 
    term_tail(F1, T, VM1, VMOut, Ts, AllowVars).
term_tail(F1, T, VMIn, VMOut, Ts, AllowVars) --> 
    [punctuation(Op, _)], { member(Op, ['*', '/']) }, 
    factor_logic(F2, VMIn, VM1, Ts, AllowVars), 
    { T1 =.. [Op, F1, F2] }, 
    term_tail(T1, T, VM1, VMOut, Ts, AllowVars).
term_tail(T, T, VM, VM, _, _) --> [].

% factor_logic(Factor, ...) parses an arithmetic factor (parenthesized expression, variable, or number).
factor_logic(F, VMIn, VMOut, Ts, AllowVars) --> [punctuation('(', _)], expr_logic(F, VMIn, VMOut, Ts, AllowVars), [punctuation(')', _)].
factor_logic(F, VMIn, VMOut, Ts, AllowVars) --> [expr(E)], { parse_expression(E, VMIn, VMOut, Ts, F, AllowVars) }.
factor_logic(V, VMIn, VMOut, _, true) --> 
    multi_word_var(Words),
    { Words \== [],
      (   extract_var_name(Words, Name) 
      ->  unify_with_vmap(Name, V, VMIn, VMOut, true)
      ;   reconstruct_name_acc(Words, Name),
          member_var_name(Name, V, VMIn),
          VMOut = VMIn
      )
    }.
factor_logic(W, VM, VM, _, false) --> [word(W, _)], { is_proper_name_atom(W) }.
factor_logic(N, VM, VM, _, _) --> [number(N, _)].
factor_logic(_, VM, VM, _, _) --> [_], { fail }.

member_var_name(Name, V, VM) :-
    normalize_var_name(Name, Norm),
    member(Norm-V, VM).

is_hyphenated_id(-(V, N), VM) :-
    number(N),
    var(V),
    \+ (member(_-V1, VM), V1 == V).


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

strip_op(Tokens, Op, RestTokens) :-
    strip_leading_op(Tokens, Op, Tokens1),
    strip_trailing_conjunction(Tokens1, RestTokens).

strip_leading_op([word(if, _)|Rest], and, Rest) :- !.
strip_leading_op([word(Op, _)|Rest], Op, Rest) :- (Op == and ; Op == or), !.
strip_leading_op(Tokens, and, Tokens).

% Strip a trailing "and" or "or" used as a line continuation marker. Don't strip
% if the line is just the connective alone. Trailing comments are also dropped.
strip_trailing_conjunction(Tokens, Stripped) :-
    drop_trailing_comments(Tokens, Tokens1),
    Tokens1 \== [],
    last(Tokens1, word(W, _)),
    (W == and ; W == or),
    append(Stripped, [word(W, _)], Tokens1),
    Stripped \== [], !.
strip_trailing_conjunction(Tokens, Stripped) :-
    drop_trailing_comments(Tokens, Stripped).

drop_trailing_comments(Tokens, Stripped) :-
    append(Front, [Last], Tokens),
    is_indent_or_comment(Last), !,
    drop_trailing_comments(Front, Stripped).
drop_trailing_comments(Tokens, Tokens).

parse_node([], Children, Templates, VMIn, VMOut, Logic) :- !,
    hierarchy_to_logic(Children, Templates, VMIn, VMOut, Logic).
parse_node(Tokens, Children, Templates, VMIn, VMOut, Logic) :-
    ( le_kbs:do_log -> maplist(extract_simple_word, Tokens, Words), print_message(informational,'Parsing node: ~w~n' - [Words]); true),
    (   Tokens = [word(prolog, _)|Rest], Children == [] ->
        le_extensions:resolve_prolog_tokens(Rest, Templates, VMIn, VMOut, Goal),
        Logic = prolog_call(Goal)
    ;   parse_node_extension(Tokens, Children, Templates, VMIn, VMOut, Logic) -> 
        ( le_kbs:do_log -> print_message(informational,'  Extension succeeded: ~w~n' - [Logic]); true),
        true
    ;   is_forall(Tokens) ->  
            split_forall_children(Children, CondNodes, ConsNodes),
            hierarchy_to_logic(CondNodes, Templates, VMIn, VM1, CondLogic),
            hierarchy_to_logic(ConsNodes, Templates, VM1, VMOut, ConsLogic),
            Logic0 = forall(CondLogic, ConsLogic),
            tokens_range(Tokens, Start, End),
            Logic = le_at(Logic0, Start, End)
        ; is_not_the_case(Tokens) ->  
            hierarchy_to_logic(Children, Templates, VMIn, VMOut, SubLogic),
            Logic0 = not(SubLogic),
            tokens_range(Tokens, Start, End),
            Logic = le_at(Logic0, Start, End)
        ; is_aggregate(Tokens, Op, ElementTokens, ResultTokens) ->  
            build_aggregate_list(ElementTokens, VMIn, VM1, ElementList),
            build_aggregate_list(ResultTokens, VM1, VM2, ResultList),
            hierarchy_to_logic(Children, Templates, VM2, VMOut, Goal),
            Logic0 =.. [Op, [each|ElementList], Goal, ResultList],
            tokens_range(Tokens, Start, End),
            Logic = le_at(Logic0, Start, End)
        ; parse_literal(Tokens, Templates, VMIn, VM1, Literal, _Instance) ->  
            collect_extra_goals(VM1, ExtraGoals),
            (   ExtraGoals == [] -> Logic0 = Literal
            ;   list_to_conj([Literal | ExtraGoals], Logic0)
            ),
            fold_nodes(Logic0, Children, Templates, VM1, VMOut, Logic1),
            ( (Tokens \== [], tokens_range(Tokens, Start, End)) -> Logic = le_at(Logic1, Start, End) ; Logic = Logic1 )
        ; match_is_a(Tokens, Type, SuperType, VMIn, VM1, true) ->  
            Literal = is_a(Type, SuperType),
            fold_nodes(Literal, Children, Templates, VM1, VMOut, Logic0),
            ( (Tokens \== [], tokens_range(Tokens, Start, End)) -> Logic = le_at(Logic0, Start, End) ; Logic = Logic0 )
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
    (   extract_var_name(Words, Name) -> true
    ;   extract_id(Words, Name) -> true
    ;   atomic_list_concat(Words, ' ', Name)
    ),
    unify_with_vmap(Name, Var, VMIn, VMOut, true),
    List = [var(Name, Var)].

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
    ;   Atoms = [unless]
    ;   Atoms = [and, unless]
    ).

extract_word_atom(word(A, _), A) :- !.
extract_word_atom(punctuation(P, _), P) :- !.
extract_word_atom(number(N, _), N) :- !.
extract_word_atom(_, unknown).

tokens_range([First|Rest], Start, End) :-
    arg(2, First, loc(Start, _)),
    last([First|Rest], Last),
    arg(2, Last, loc(_, End)).

:- thread_local is_a_taxonomy_edge/3.
:- thread_local is_a_type/1.
