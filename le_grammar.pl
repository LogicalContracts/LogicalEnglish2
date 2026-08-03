/** <module> Logical English Grammar and Parser
    
    This module implements the DCG for Logical English and the second-pass
    logic that transforms tokens into executable Prolog terms. It handles
    the structure of KBs, scenarios, queries, and templates.
*/

:- module(le_grammar, [parse_le_file/3, parse_le_text/3, parse_le_tokens/3, match_instance_to_template/6, match_instance_to_template/7, reconstruct_name/2,
    kb_items//1, second_pass_item/4, parse_literal/6, prepare_templates/2,
    set_token_pos/1, get_token_pos/1, is_id/1, is_article/1, is_reserved/1, is_ignorable/1, is_proper_name_atom/1, is_punct/1,
    extract_var_name_extension/2, unify_with_vmap_extension/5, post_parse_literal_hook/4, parse_node_extension/6, second_pass_item_extension/4,
    extract_var_name/2, unify_with_vmap/5, extract_simple_word/2, extract_var_info_from_words/3, head_noun_type/2]).

:- multifile extract_var_name_extension/2, unify_with_vmap_extension/5, post_parse_literal_hook/4, parse_node_extension/6, second_pass_item_extension/4, match_template_with_chaining/8.

:- use_module(tokenizer, [tokenize/2, tokenize_file/2, tokens_to_string/2]).
:- use_module(le_system_templates).
:- use_module(le_i18n).
:- use_module(library(dcg/basics)).
:- use_module(library(uri)).

:- thread_local current_token_pos/1.
% Source offsets at which a line's first token begins (see record_line_starts/1):
% what tells a section header from the same word inside a sentence.
:- thread_local line_start_offset/1.

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

:- thread_local current_le_target/1.

%!  set_le_target(+Target:atom) is det.
%
%   Records the target language declared by the document being parsed, so the
%   DCG can offer target-specific sentence forms. Reset by parse_le_tokens/3.
set_le_target(Target) :-
    retractall(current_le_target(_)),
    assertz(current_le_target(Target)).

%!  le_target(-Target:atom) is det.
%
%   The target of the document being parsed; `prolog` when none was declared.
le_target(Target) :-
    ( current_le_target(T) -> Target = T ; Target = prolog ).

%!  lps_target is semidet.
%
%   True while parsing a document that declared `the target language is: lps.`
lps_target :- current_le_target(lps).

:- thread_local current_allow_commas/1.

%!  set_allow_commas(+Val:boolean) is det.
%
%   Sets whether commas are allowed inside template instances.
set_allow_commas(Val) :-
    retractall(current_allow_commas(_)),
    assertz(current_allow_commas(Val)).

%!  get_allow_commas(-Val:boolean) is det.
%
%   Gets whether commas are allowed inside template instances.
get_allow_commas(Val) :-
    ( current_allow_commas(V) -> Val = V ; Val = true ).

%!  with_allow_commas(+Val:boolean, +DCGGoal)// is det.
%
%   DCG non-terminal that temporarily sets allow_commas to Val while executing DCGGoal,
%   ensuring the state is correctly restored on success, failure, or backtracking.
with_allow_commas(Val, DCGGoal, StateIn, StateOut) :-
    get_allow_commas(Old),
    set_allow_commas(Val),
    (   phrase(DCGGoal, StateIn, StateOut),
        set_allow_commas(Old)
    ;   set_allow_commas(Old),
        fail
    ).

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
    read_file_to_string(FilePath, Text, []),
    parse_le_text(Text, Doc, M).

parse_le_text(Text, Doc, M) :-
    tokenize_for_language(Text, Tokens),
    parse_le_tokens(Tokens, Doc, M).


%!  parse_le_text(+Text:string, -Doc:term) is det.
%
%   Tokenizes and parses Logical English source text.
parse_le_text(Text, Doc) :-
    tokenize_for_language(Text, Tokens),
    parse_le_tokens(Tokens, Doc).

%!  tokenize_for_language(+Text, -Tokens) is det.
%
%   Tokenizes Text respecting the number locale of the language its first
%   statement declares: a first pass with the default (English/ISO) locale is
%   enough to read the opener; when the declared language uses different
%   number separators (e.g. Portuguese "1.234,56"), the text is re-tokenized
%   with that locale.
tokenize_for_language(Text, Tokens) :-
    tokenize(Text, Tokens0),
    (   le_i18n:detect_language_tokens(Tokens0, Lang),
        le_i18n:language_param(Lang, decimal_sep, Dec),
        le_i18n:language_param(Lang, thousands_sep, Thou),
        Dec \== '', Thou \== '',
        \+ (Dec == '.', Thou == ',')
    ->  tokenizer:tokenize(Text, Dec, Thou, Tokens)
    ;   Tokens = Tokens0
    ).

%!  parse_le_tokens(+Tokens:list, -Doc:term) is det.
%
%   Parses a list of tokens into a Logical English document structure.
%   Performs a second pass to resolve templates and variables.
parse_le_tokens(Tokens, doc(NewSections), M) :-
    ( le_kbs:do_log -> print_message(informational,'Parsing LE tokens...~n'); true),
    % Detect the program's language from its first statement (the opener
    % declared in i18n/languages.csv, e.g. "the target language is" /
    % "a linguagem alvo é"). Per O-1: when no opener matches, default to
    % English. The active language drives every kw//1 terminal below.
    ( le_i18n:detect_language_tokens(Tokens, Lang) -> true ; Lang = en ),
    le_i18n:set_le_language(Lang),
    retractall(current_le_target(_)),
    ( nonvar(M), M \== (-) ->
        retractall(M:le_lang(_)), assertz(M:le_lang(Lang))
    ; true ),
    % The line-start table belongs to THIS document (see next_section_start//0):
    % an included resource is parsed by a nested call, so save and restore.
    findall(O, line_start_offset(O), SavedStarts),
    (   setup_call_cleanup(record_line_starts(Tokens),
                           phrase(doc(Sections), Tokens),
                           restore_line_starts(SavedStarts))
    ->  true
        ;
        print_message(error, "DCG phrase(doc(Sections), Tokens) failed"),
        fail
    ),
    check_scenario_before_rules(Sections, M),
    le_kbs:fetch_resources(Sections, MergedSections, M),
    (   second_pass(MergedSections, NewSections, M) ->  true 
        ;   
        print_message(error, "second_pass failed"),
        fail
    ).

check_scenario_before_rules(Sections, M) :-
    forall(
        ( nth1(_, Sections, scenario(Name, _, Start, End)),
          once((member(Other, Sections), is_rule_bearing_section(Other), section_start(Other, StartOther), StartOther > Start))
        ),
        ( le_i18n:le_msg(scenario_before_rules_desc, [name-Name], Desc),
          le_i18n:le_msg(scenario_before_rules_fix, [], Fix),
          (nonvar(M) -> assertz(M:le_issue(error, scenario_before_rules, Desc, Fix, Start, End)) ; true)
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
section_start(actions(_), 0).
section_start(prolog_events(_), 0).
section_start(lps_setting(_, _, S, _), S).

% Only KNOWLEDGE BASE rules count for the "scenario before rules" ordering check.
% Scenarios (and queries) may legitimately contain their own local rules, so they
% must NOT be treated as rule-bearing here — otherwise an earlier scenario would
% be wrongly flagged as appearing before a later scenario's rule.
is_rule_bearing_section(kb(_, Content, _, _)) :- member(Item, Content), is_rule_item(Item).
is_rule_bearing_section(unknown_section(Tokens, _, _)) :-
    member(word(W, _), Tokens),
    ( le_i18n:class_member(if, W) ; le_i18n:class_member(unless, W) ), !.

is_rule_item(rule(_, _, _, _, _, _)).
is_rule_item(fact(_, _, _)).

% ---------------------------------------------------------------------------
% Lexicon-driven keyword terminals
%
% The DCG below matches keywords through kw//1 and friends rather than inline
% English atoms: the surface words come from i18n/keywords.csv for the ACTIVE
% language (set from the program's first statement), so the grammar STRUCTURE
% is shared across languages and only the terminals are data-driven.
% ---------------------------------------------------------------------------

%!  kw(+Key)// is nondet.
%
%   Matches one synonym (a word sequence, longest first) of keyword Key in the
%   active language, skipping indents/comments between words like t//1 does.
kw(Key) -->
    { le_i18n:kw_synonym_words(Key, Words) },
    kw_words(Words).

kw_words([]) --> [].
kw_words([W|Ws]) --> t(word(W)), kw_words(Ws).

%!  kw_start(+Key, -Start)// is nondet.
%
%   As kw//1, also returning the source start of the first word.
kw_start(Key, Start) -->
    { le_i18n:kw_synonym_words(Key, Words), Words = [W0|Ws] },
    t(word(W0, loc(Start, _))),
    kw_words(Ws).

%!  kw_loc(+Key, -Start, -End)// is nondet.
%
%   As kw//1, also returning the full source range of the matched phrase.
kw_loc(Key, Start, End) -->
    { le_i18n:kw_synonym_words(Key, Words) },
    (   { Words = [W] }
    ->  t(word(W, loc(Start, End)))
    ;   { Words = [W0|Ws] },
        t(word(W0, loc(Start, _))),
        kw_words_end(Ws, End)
    ).

kw_words_end([W], End) --> !, t(word(W, loc(_, End))).
kw_words_end([W|Ws], End) --> t(word(W)), kw_words_end(Ws, End).

%!  kw_words_eq(+Key, +Atoms) is semidet.
%
%   Atoms (a full word list) is exactly one synonym of Key in the active
%   language. Non-DCG counterpart of kw//1 for token-list checks.
kw_words_eq(Key, Atoms) :-
    le_i18n:kw_synonym_words(Key, Words),
    Words == Atoms, !.

%!  match_word_prefix(+Words, +Tokens, -Rest) is semidet.
%
%   Tokens starts with word tokens spelling Words; Rest is what follows.
match_word_prefix([], Rest, Rest).
match_word_prefix([W|Ws], [word(W0, _)|Ts], Rest) :-
    W0 == W,
    match_word_prefix(Ws, Ts, Rest).

%!  tokens_match_words(+Tokens, +Words) is semidet.
%
%   The token list spells exactly the given word list.
tokens_match_words([], []).
tokens_match_words([T|Ts], [W|Ws]) :-
    extract_simple_word(T, W0),
    W0 == W,
    tokens_match_words(Ts, Ws).

% DCG for Logical English
% doc(Sections) parses the entire document into a list of sections.
doc(Sections) --> { set_allow_commas(true) }, sections(Sections), any_indent.

% sections([S|Ss]) parses one or more sections.
sections([S|Ss]) --> section(S), !, sections(Ss).
sections([]) --> [].

% section(resources(...)) parses a resources inclusion section.
section(resources(Name, Resources, Start, End)) -->
    any_indent, kw_start(kb_open, Start), kb_name_tokens(Tokens), kw(resources_include), t(punctuation(':', _)),
    { reconstruct_name(Tokens, Name) },
    resource_list(Resources, End).

section(resources(Name, Resources, Start, End)) -->
    any_indent, kw_start(contract_open, Start), kb_name_tokens(Tokens), kw(resources_include), t(punctuation(':', _)),
    { reconstruct_name(Tokens, Name) },
    resource_list(Resources, End).

% section(kb(...)) parses a knowledge base section.
section(kb(Name, Content, Start, End)) -->
    any_indent, kw_start(kb_open, Start), kb_name_tokens(Tokens), kw(kb_include), t(punctuation(':', _)),
    { reconstruct_name(Tokens, Name) },
    { ( le_kbs:do_log -> print_message(informational,'Parsing KB: ~w~n' - [Name]); true) },
    kb_content(Content, End),
    { ( le_kbs:do_log -> print_message(informational,'Finished KB: ~w~n' - [Name]); true) }.

section(kb(Name, Content, Start, End)) -->
    any_indent, kw_start(contract_open, Start), kb_name_tokens_contract(Tokens), kw(contract_states), t(punctuation(':', _)),
    { reconstruct_name(Tokens, Name) },
    { ( le_kbs:do_log -> print_message(informational,'Parsing KB (contract): ~w~n' - [Name]); true) },
    kb_content(Content, End),
    { ( le_kbs:do_log -> print_message(informational,'Finished KB (contract): ~w~n' - [Name]); true) }.

% A misplaced expectation: an "expects answers [...]" line prefixed with a section
% keyword such as 'query', e.g. "query one expects answers [...]" written inside a
% scenario. Tried before the scenario/query section rules so it is reported as a
% clear syntactic error instead of silently starting a bogus query section that
% swallows the real queries.
section(misplaced_expectation(Start, End)) -->
    any_indent, t(word(Kw, loc(Start, _))),
    { ( le_i18n:class_member(query, Kw) -> true ; le_i18n:class_member(scenario, Kw) ) },
    section_name_tokens(NameTokens),
    kw(expects), ( kw(answers) -> [] ; [] ),
    t(punctuation('[')), list_elements(_), t(punctuation(']')),
    (   kw(and_unknowns), t(punctuation('[')), list_elements(_), t(punctuation(']')) -> [] ; [] ),
    (   any_indent, t(punctuation('.', loc(_, End))) -> [] ; { get_token_pos(End) } ),
    {   reconstruct_name(NameTokens, Name),
        le_i18n:le_msg(misplaced_expectation_desc, [kw-Kw, name-Name], Desc),
        le_i18n:le_msg(misplaced_expectation_fix, [kw-Kw], Fix),
        ( le_kbs:current_compiling_module(M), nonvar(M)
          -> assertz(M:le_issue(error, misplaced_expectation, Desc, Fix, Start, End))
          ;  true )
    }.

% section(scenario(...)) parses a scenario section.
section(scenario(Name, Content, Start, End)) -->
    any_indent, kw_start(scenario, Start), section_name_tokens(Tokens), kw(marker_is), t(punctuation(':', _)),
    { reconstruct_name(Tokens, Name) },
    kb_content(Content, End).

% section(query(...)) parses a query section. The body is captured with its
% indentation preserved (like a rule body) so it can be a full body expression —
% and / or / "it is not the case that …" / "for all cases …" — not just a single
% template instance. The whole body is one raw item, parsed in the second pass.
section(query(Name, [query_raw(BodyTokens, BStart, End)], Start, End)) -->
    any_indent, kw_start(query, Start), section_name_tokens(Tokens), kw(marker_is), t(punctuation(':', _)),
    { reconstruct_name(Tokens, Name) },
    body(BodyTokens, End),
    { ( body_first_start(BodyTokens, BStart) -> true ; BStart = Start ) }.

% section(ontology(...)) parses an ontology section.
section(ontology(Content, Start, End)) -->
    any_indent, kw_start(ontology, Start), t(punctuation(':', _)),
    kb_content(Content, End).

% section(predicates(...)) parses a predicates declaration section.
section(predicates(Dicts)) -->
    any_indent, kw(predicates), t(punctuation(':', _)),
    templates(Dicts).

% section(templates(...)) parses a templates declaration section.
section(templates(Dicts)) -->
    any_indent, kw(templates), t(punctuation(':', _)),
    templates(Dicts).

% section(fluents(...)) parses a fluents declaration section.
section(fluents(Dicts)) -->
    any_indent, kw(fluents), t(punctuation(':', _)),
    templates(Dicts).

% section(events(...)) parses an events declaration section.
section(events(Dicts)) -->
    any_indent, kw(events), t(punctuation(':', _)),
    templates(Dicts).

% section(actions(...)) and section(prolog_events(...)) are the two declaration
% sections LPS needs and plain LE has no use for (docs/le_lps_surface.md §2).
% LPS distinguishes ACTIONS, which the agent performs and whose preconditions
% are checked, from EVENTS, which happen to it; that distinction is
% load-bearing in the engine and cannot be inferred from use. Both are ordinary
% template sections — only the role differs, and le_kbs records it.
section(actions(Dicts)) -->
    any_indent, kw(actions), t(punctuation(':', _)),
    templates(Dicts).

section(prolog_events(Dicts)) -->
    any_indent, kw(prolog_events), t(punctuation(':', _)),
    templates(Dicts).

% section(meta(...)) parses a meta-information section (the target-language
% opener; its phrase per language comes from i18n/languages.csv). The declared
% execution target (an atom from le_allowed_target/1) is captured so the loader
% can select the backend; an unrecognised target makes this rule fail, falling
% back to unknown_section as before.
section(meta(Target)) -->
    any_indent,
    { le_i18n:le_active_language(Lang),
      ( le_i18n:language_opener(Lang, OpenerWords) -> true
      ; le_i18n:language_opener(en, OpenerWords) ) },
    kw_words(OpenerWords),
    t(punctuation(':', _)), t(word(Target)), { le_allowed_target(Target) },
    t(punctuation('.', _)),
    %  The declared target is needed DURING the parse, not only after it: the
    %  LPS sentence forms (kb_item(lps_*)) are gated on it so that a plain-LE
    %  document keeps exactly the grammar it has today. The declaration is the
    %  first section, so by the time any rule is read the flag is set.
    { set_le_target(Target) }.

% section(lps_setting(...)) parses one of the LPS run-length settings, which
% are written at the top level of a document rather than inside a knowledge
% base -- they are about the run, not about the domain.
section(lps_setting(Key, Value, Start, End)) -->
    { lps_target },
    any_indent, { member(Key-Kw, [maxTime-lps_max_time,
                                  maxRealTime-lps_max_real_time,
                                  minCycleTime-lps_min_cycle_time]) },
    kw_start(Kw, Start),
    t(number(Value)),
    any_indent, t(punctuation('.', loc(_, End))).

% section(unknown_section(...)) is a fallback for unrecognized sections.
section(unknown_section(Tokens, Start, End)) -->
    [T], { get_token_start(T, Start) },
    consume_until_next_section(Ts),
    { append([T], Ts, Tokens) },
    { last(Tokens, Last), ( get_token_end(Last, End) -> true ; End = Start) }.

% le_allowed_target(?Target) enumerates the execution backends a program may
% declare via the target-language opener line (kept out of the section/3 DCG
% clauses so they stay contiguous).
le_allowed_target(prolog).
le_allowed_target(scasp).
% LPS: the document is a reactive program, not a query-answering knowledge
% base. See docs/le_lps_surface.md and le_lps.pl.
le_allowed_target(lps).

% body_first_start(+BodyTokens, -Start): source start of a query body (its first
% non-indent token), used for the query item's location.
body_first_start([indent(_, _)|Ts], S) :- !, body_first_start(Ts, S).
body_first_start([T|_], S) :- get_token_start(T, S).

% kb_name_tokens(Tokens) consumes tokens until the 'includes' keyword.
kb_name_tokens([T|Ts]) -->
    \+ kw(kb_include),
    t(T), !,
    kb_name_tokens(Ts).
kb_name_tokens([]) --> [].

% kb_name_tokens_contract(Tokens) consumes tokens until the 'states that' keyword.
kb_name_tokens_contract([T|Ts]) -->
    \+ kw(contract_states),
    t(T), !,
    kb_name_tokens_contract(Ts).
kb_name_tokens_contract([]) --> [].

% section_name_tokens(Tokens) consumes tokens forming a scenario/query name. It
% stops at 'is'/':' (the header terminator) and also at 'expects' or '.', which a
% name never legitimately contains — without those guards a malformed expectation
% prefixed with a section keyword (e.g. "query one expects answers [...]") would
% greedily swallow the rest of the document, including the real queries.
section_name_tokens([T|Ts]) -->
    \+ kw(marker_is),
    \+ t(punctuation(':', _)),
    \+ kw(expects),
    \+ t(punctuation('.', _)),
    t(T), !,
    section_name_tokens(Ts).
section_name_tokens([]) --> [].

% query_name_tokens(Tokens) consumes tokens until 'expects'.
query_name_tokens([T|Ts]) -->
    \+ kw(expects),
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
% The per-language guard prefixes live under the 'guard' key in
% i18n/keywords.csv (for English: "the knowledge", "the contract", "scenario",
% "query", "the ontology", "the predicates", "the templates", "the fluents",
% "the events", "the target").
%
% A section header starts a LINE. The same words inside a sentence are ordinary
% vocabulary: `*a claim* involves a scenario tested of *a description*` was
% being cut in half at "scenario", and everything after it reported as an
% unknown section. The test is on the keyword's own source offset (recorded by
% record_line_starts/1 when the document is tokenized) rather than on a
% preceding indent token, because by the time an item parser looks ahead for
% the next section it has usually consumed the indent already.
next_section_start --> any_indent, at_line_start, kw(guard).

% Non-consuming: the next token begins a line. With no table recorded — a
% fragment parsed directly through kb_items//1, say — every position qualifies,
% which is what those callers saw before line starts were tracked at all.
at_line_start(S, S) :-
    (   \+ line_start_offset(_)
    ->  true
    ;   S = [T|_],
        token_offset(T, Off),
        line_start_offset(Off)
    ).

token_offset(T, Off) :-
    compound(T),
    T =.. [_|Args],
    last(Args, loc(Off, _)).

%!  record_line_starts(+Tokens) is det.
%
%   The source offsets at which a line's first token begins: the very first
%   token, and every token that follows an indent (the tokenizer emits one per
%   line, collapsing runs of blank lines). Thread-local, rebuilt per document —
%   parses are per-thread and one document at a time.
record_line_starts(Tokens) :-
    retractall(line_start_offset(_)),
    record_line_starts_(Tokens, true).

restore_line_starts(Saved) :-
    retractall(line_start_offset(_)),
    forall(member(O, Saved), assertz(line_start_offset(O))).

record_line_starts_([], _).
record_line_starts_([T|Ts], First) :-
    (   T = indent(_, _)
    ->  record_line_starts_(Ts, true)
    ;   ( First == true, token_offset(T, Off)
        ->  ( line_start_offset(Off) -> true ; assertz(line_start_offset(Off)) )
        ;   true
        ),
        record_line_starts_(Ts, false)
    ).

resource_list([R|Rs], End) -->
    any_indent, resource_item(R),
    (   t(punctuation(',', _)) -> resource_list(Rs, End)
    ;   t(punctuation('.', loc(_, End))), peek_next_section_start -> { Rs = [] }
    ).

peek_next_section_start(Tokens, Tokens) :-
    phrase(next_section_start, Tokens, _).

resource_item(Resource) -->
    resource_tokens(Tokens),
    { reconstruct_resource_name(Tokens, Resource) }.

%!  reconstruct_resource_name(+Tokens, -Resource) is det.
%
%   A resource identifier (URL or file path) contains no internal spaces, but
%   the tokenizer splits it at digit<->letter and punctuation boundaries (a
%   UUID like 89d78cb0 becomes number(89), word(d78cb0)). Reconstruct it from
%   the tokens' SOURCE POSITIONS: emit each token's text directly when it abuts
%   the previous one (prev end == next start), inserting a single space only
%   across a genuine source gap. This preserves the exact URL/path.
reconstruct_resource_name(Tokens, Resource) :-
    reconstruct_resource_parts(Tokens, none, Parts),
    atomic_list_concat(Parts, '', Joined),
    normalize_space(atom(Resource), Joined).

reconstruct_resource_parts([], _, []).
reconstruct_resource_parts([T|Ts], Prev, Parts) :-
    extract_simple_word(T, W),
    get_token_start(T, Start),
    get_token_end(T, End),
    ( ( Prev = prev(PrevEnd), integer(PrevEnd), integer(Start), Start > PrevEnd )
    -> Parts = [' ', W | Rest]
    ;  Parts = [W | Rest] ),
    reconstruct_resource_parts(Ts, prev(End), Rest).

resource_tokens([T]) -->
    [T], { \+ is_punctuation(T, ','), \+ is_punctuation(T, '.') }.
resource_tokens([T|Ts]) -->
    [T], { \+ is_punctuation(T, ',') },
    resource_tokens(Ts).

is_punctuation(punctuation(P, _), P).

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

% kb_item(section_marker(Name, Start, End)) divides the rules of a knowledge
% base into named sections. Every rule that follows the marker belongs to
% section Name until the next marker (recorded via le_source_section/2). Rules
% before any marker, or in a KB with no markers, belong to section 'main'.
kb_item(section_marker(Name, Start, End)) -->
    kw_start(marker, Start), section_name_tokens(Tokens), { Tokens \== [] },
    kw(marker_is), t(punctuation(':', loc(_, End))),
    { reconstruct_name(Tokens, Name) }.
% Shorthand for "section annexes is:": "the annexes to the contract are:"
% (synonym: "the annexes to the knowledge base are:").
kb_item(section_marker(annexes, Start, End)) -->
    kw_start(annexes, Start), t(punctuation(':', loc(_, End))).

% kb_item(expected(QueryName, Answers, Unknowns, Start, End)) parses "QueryName expects answers [Answers] and unknowns [Unknowns]."
% The 'answers' word is optional: "QueryName expects [Answers]" means the same
% thing, and reads better for a numbered query. Without this, such a line
% matched no kb_item at all and the whole tail of the scenario was swallowed by
% the unknown_section fallback — the expectation just never ran.
kb_item(expected(QueryName, Answers, Unknowns, Start, End)) -->
    query_name_tokens(Tokens), { Tokens \== [], reconstruct_name(Tokens, QueryName) },
    { Tokens = [First|_], get_token_start(First, Start) },
    kw(expects), ( kw(answers) -> [] ; [] ),
    t(punctuation('[')), list_elements(Answers), t(punctuation(']')),
    (   kw(and_unknowns), t(punctuation('[')), list_elements(Unknowns), t(punctuation(']'))
    ->  []
    ;   { Unknowns = [] }
    ),
    (   (any_indent, t(punctuation('.' , loc(_, End))))
    ->  []
    ;   {
          le_kbs:current_compiling_module(M),
          get_token_pos(Pos),
          le_i18n:le_msg(missing_trailing_dot_desc, [], Desc),
          le_i18n:le_msg(missing_trailing_dot_fix, [], Fix),
          (nonvar(M) -> assertz(M:le_issue(error, missing_trailing_dot, Desc, Fix, Start, Pos)) ; true),
          End = Pos
        }
    ).


% ---------------------------------------------------------------------------
% LPS sentence forms (docs/le_lps_surface.md §3).
%
% Every one of these is gated on `lps_target`, so a plain-LE document keeps
% exactly the grammar it has today: none of these clauses can even be tried.
% They come BEFORE kb_item(rule(...)) because each starts with a keyword that
% would otherwise be read as the first word of a template instance.
%
% None of them interprets anything. The antecedent and consequent are captured
% as token lists and handed to the ordinary second-pass body parser, so `and`,
% `or`, `it is not the case that`, aggregates and indentation all behave as
% they do everywhere else. What the temporal suffixes mean, and which literal
% is a fluent and which an event, is settled later still — in le_lps.pl, which
% is the only module that knows anything about LPS.
% ---------------------------------------------------------------------------

% "when <antecedent> then <consequent>." — a causal law.
kb_item(lps_rule(when, Ante, Cons, Indent, Start, End)) -->
    { lps_target },
    any_indent(Indent), kw_start(lps_when, Start), !,
    lps_antecedent(Ante),
    kw(lps_then),
    body(Cons, End).

% "if <antecedent> then <consequent>." — a reactive rule.
kb_item(lps_rule(if, Ante, Cons, Indent, Start, End)) -->
    { lps_target },
    any_indent(Indent), kw_start(lps_if, Start),
    lps_antecedent(Ante),
    kw(lps_then), !,
    body(Cons, End).

% "it must not be true that <conditions>." — an integrity constraint.
kb_item(lps_denial(Body, Indent, Start, End)) -->
    { lps_target },
    any_indent(Indent), kw_start(lps_must_not, Start), !,
    body(Body, End).

% "initially <fluents>." — the initial state.
kb_item(lps_initially(Body, Indent, Start, End)) -->
    { lps_target },
    any_indent(Indent), kw_start(lps_initially, Start), !,
    body(Body, End).

% "the goal is that <fluents>." — a planning goal.
kb_item(lps_goal(Body, Indent, Start, End)) -->
    { lps_target },
    any_indent(Indent), kw_start(lps_goal, Start), !,
    body(Body, End).

% "the maximum time is N." and its two real-time siblings.
kb_item(lps_setting(Key, Value, Start, End)) -->
    { lps_target },
    any_indent, { member(Key-Kw, [maxTime-lps_max_time,
                                  maxRealTime-lps_max_real_time,
                                  minCycleTime-lps_min_cycle_time]) },
    kw_start(Kw, Start), !,
    t(number(Value)),
    any_indent, t(punctuation('.', loc(_, End))).

% kb_item(rule(Head, Body, Indent, Start, End, ID)) parses a Logical English rule (Head if Body).
kb_item(rule(Head, Body, Indent, Start, End, ID)) -->
    kw(rule), !, (t(word(ID)) | t(number(ID))), t(punctuation(':')),
    template_instance(Head),
    { Head = [First|_], get_token_start(First, Start) },
    any_indent(N),
    (   kw(if), t(punctuation(':')) ->
        numbered_body(Body, End)
    ;   kw(only_if) ->
        body(Body0, End), { Body = only_if(Body0) }
    ;   kw(if) ->
        body(Body, End)
    ;   kw(unless), t(punctuation(':')) ->
        numbered_body(Body0, End), { Body = unless(Body0) }
    ;   kw(unless) ->
        body(Body0, End), { Body = unless(Body0) }
    ),
    { Indent = N }.

kb_item(rule(Head, Body, Indent, Start, End, ID)) -->
    template_instance(Head),
    { Head = [First|_], get_token_start(First, Start) },
    any_indent(N),
    (   kw(if), t(punctuation(':')) ->
        numbered_body(Body, End)
    ;   kw(only_if) ->
        body(Body0, End), { Body = only_if(Body0) }
    ;   kw(if) ->
        body(Body, End)
    ;   kw(unless), t(punctuation(':')) ->
        numbered_body(Body0, End), { Body = unless(Body0) }
    ;   kw(unless) ->
        body(Body0, End), { Body = unless(Body0) }
    ),
    { Indent = N, ID = _ }.

% kb_item(unknown_fact(Head, Start, End)) parses "it is unknown whether <template instance>."
kb_item(unknown_fact(Head, Start, End)) -->
    kw(it_is), unknown_keyword, kw(whether),
    template_instance(Head),
    { Head = [First|_], get_token_start(First, Start) },
    any_indent, t(punctuation('.', loc(_, End))).

% kb_item(fact_image(...)) parses a fact carrying an image addition:
%     <fact>; image "https://…".
% The template instance stops at ';' (is_terminator), so the addition parses
% cleanly after it. The image is meant for GROUND scenario facts (rendered by
% the Bento Box); the second pass validates and stores it — a non-ground fact
% or an ill-formed URL yields a warning instead.
kb_item(fact_image(Head, URL, UStart, UEnd, Start, End)) -->
    template_instance(Head),
    { Head = [First|_], get_token_start(First, Start) },
    any_indent, t(punct(';')), kw(image),
    ( t(doubleQuoteString(URL, loc(UStart, UEnd))) | t(quoteString(URL, loc(UStart, UEnd))) ),
    any_indent, t(punctuation('.', loc(_, End))).

% kb_item(fact(Head, Start, End)) parses a Logical English fact (Head.).
kb_item(fact(Head, Start, End)) -->
    template_instance(Head),
    { Head = [First|_], get_token_start(First, Start) },
    any_indent, t(punctuation('.', loc(_, End))).

% The antecedent of a when/if: every token up to the `then` that starts a line
% (or follows the antecedent inline). `then` cannot appear inside a template
% instance — it is a reserved word in every language column of keywords.csv —
% so this needs no lookahead beyond the keyword itself.
lps_antecedent([T|Ts]) --> \+ lps_then_ahead, \+ is_body_terminator, body_token(T), !, lps_antecedent(Ts).
lps_antecedent([]) --> [].

lps_then_ahead --> any_indent, kw(lps_then).

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
    (   (t(punct('.')) ; t(punct(',')))
    ->  ( templates(MoreDicts) | { MoreDicts = [] } ),
        { append(TDicts, MoreDicts, AllDicts) }
    ;   reserved_word_template_error(TDicts)
    ->  % recover: drop the truncated template, parse the rest of the section
        ( templates(AllDicts) | { AllDicts = [] } )
    ;   warn_truncated_template(TDicts), { AllDicts = TDicts }
    ).
templates([]) --> [].

% A parsed template is not followed by its '.'/',' terminator and the next token
% is one of the reserved words that end a template instance (if, unless, either,
% only if, any of, all of, expects): the template was silently cut off at that
% word. Without recovery the remainder of the templates section is lost too, so
% missing_template errors then surface on unrelated templates further down.
% Report a targeted error at the offending template, skip to the end of its
% line, and let the rest of the section parse. The truncated template itself is
% dropped, so the rule or fact using the full sentence is flagged as missing its
% template rather than silently matching a cut-off one.
reserved_word_template_error(TDicts) -->
    any_indent,
    reserved_template_truncator(Word, WEnd),
    { ( TDicts = [dict(_, _, _, TStart, _, _, _, _, _) | _] -> true ; TStart = WEnd ),
      ( le_kbs:current_compiling_module(M), M \== (-)
      ->  le_i18n:le_msg(reserved_word_in_template_desc, [word-Word], Desc),
          le_i18n:le_msg(reserved_word_in_template_fix, [], Fix),
          assertz(M:le_issue(error, reserved_word_in_template, Desc, Fix, TStart, WEnd))
      ;   true
      ) },
    skip_to_period.

reserved_template_truncator(Phrase, End) -->
    { member(Key, [only_if, any_of, all_of]),
      le_i18n:kw_synonym_words(Key, Words) },
    kw_words_end_open(Words, End), !,
    { atomic_list_concat(Words, ' ', Phrase) }.
reserved_template_truncator(W, End) -->
    t(word(W, loc(_, End))),
    { ( le_i18n:class_member(if, W)
      ; le_i18n:class_member(unless, W)
      ; le_i18n:class_member(either, W)
      ; le_i18n:class_member(expects, W)
      ), ! }.

% Like kw_words_end//2 but also accepts a single-word phrase without a cut.
kw_words_end_open([W], End) --> t(word(W, loc(_, End))).
kw_words_end_open([W|Ws], End) --> { Ws \== [] }, t(word(W)), kw_words_end_open(Ws, End).

% Skip everything up to and including the next '.', so the templates section can
% continue after a truncated template line.
skip_to_period --> [punctuation('.', _)], !.
skip_to_period --> [_], !, skip_to_period.
skip_to_period --> [].

% A template was parsed but is not followed by a '.'/',' terminator: if what
% follows is a section keyword (scenario, query, the knowledge base, ...) on a
% line that ends with '.' (rather than a ':' section header), the template was
% silently cut off by a reserved word appearing inside it. Warn about it. This is
% a non-consuming look-ahead (S, S), so parsing is unaffected.
warn_truncated_template(TDicts, S, S) :-
    (   reserved_word_truncation(S, Word, DotEnd),
        TDicts = [dict(_, _, _, TStart, _, _, _, _, _) | _]
    ->  ( le_kbs:current_compiling_module(M), M \== (-)
        ->  le_i18n:le_msg(reserved_word_in_template_section_desc, [word-Word], Desc),
            le_i18n:le_msg(reserved_word_in_template_section_fix, [], Fix),
            assertz(M:le_issue(warning, reserved_word_in_template, Desc, Fix, TStart, DotEnd))
        ;   true )
    ;   true
    ).

% True when the upcoming tokens are a section keyword followed (on the same '.'-
% terminated line, before any ':') by more content — i.e. a truncated template.
reserved_word_truncation(Tokens0, Word, DotEnd) :-
    skip_indents(Tokens0, Tokens),
    section_keyword_head(Tokens, Word),
    period_before_colon(Tokens, DotEnd).

skip_indents([indent(_, _) | T], T2) :- !, skip_indents(T, T2).
skip_indents(T, T).

section_keyword_head([word(W, _) | _], W) :- le_i18n:class_member(scenario, W), !.
section_keyword_head([word(W, _) | _], W) :- le_i18n:class_member(query, W), !.
section_keyword_head([word(A, _), word(KW, _) | _], KW) :-
    le_i18n:class_member(definite_article, A),
    le_i18n:class_member(reserved_word, KW).

period_before_colon([punctuation('.', loc(_, E)) | _], E) :- !.
period_before_colon([punctuation(':', _) | _], _) :- !, fail.
period_before_colon([_ | T], E) :- period_before_colon(T, E).

% template(Dicts) parses a single template definition into a list of dicts.
% The list always contains the main dict and, if an opposite was declared, a
% second synthesized dict for the opposite words so it can be matched directly.
% The Prep field is bound to the atom 'prepositional' if the template is marked
% prepositional; otherwise it is left unbound.
template(Dicts) -->
    template_instance(Tokens),
    { Tokens = [First|_], get_token_start(First, Start), last(Tokens, Last), get_token_end(Last, End) },
    { process_template(Tokens, FunctorArgs, NamesTypes, WordsAndVars) },
    template_additions(Globals, Opposite, OppositeWV, Prep, Unknown, Synonyms, NamesTypes, FunctorArgs, Start, End),
    { validate_prepositional_template(Prep, FunctorArgs, WordsAndVars, Start, End) },
    { validate_synonym_template(Synonyms, Globals, Opposite, Prep, Unknown, Start, End) },
    { MainDict = dict(FunctorArgs, NamesTypes, WordsAndVars, Start, End, Globals, Opposite, Prep, Unknown),
      (   nonvar(Opposite), nonvar(OppositeWV) ->
          MainLit =.. FunctorArgs,
          Opposite =.. [OppF | OppArgs],
          OppFA = [OppF | OppArgs],
          OppositeDict = dict(OppFA, NamesTypes, OppositeWV, Start, End, Globals, MainLit, Prep, Unknown),
          BaseDicts = [MainDict, OppositeDict]
      ;   BaseDicts = [MainDict]
      ),
      % Each synonym becomes an extra dict with the SAME FunctorArgs (so its surface
      % form parses to the same literal). Copy each so its variables are independent.
      findall(SynDict,
              ( member(SynWV, Synonyms),
                copy_term(dict(FunctorArgs, NamesTypes, SynWV), dict(SynFA, SynNTs, SynWVc)),
                SynDict = dict(SynFA, SynNTs, SynWVc, Start, End, [], _, _, _) ),
              SynDicts),
      append(BaseDicts, SynDicts, Dicts)
    }.

% A template with a synonym must not carry any other addition (defines global,
% opposite, prepositional, unknown, undefined). Report an issue if it does; the
% synonym dicts are still produced so the surface forms remain usable.
validate_synonym_template([], _, _, _, _, _, _) :- !.
validate_synonym_template(Synonyms, Globals, Opposite, Prep, Unknown, Start, End) :-
    Synonyms \== [],
    ( Globals \== [] ; nonvar(Opposite) ; nonvar(Prep) ; nonvar(Unknown) ),
    !,
    ( le_kbs:current_compiling_module(M), M \== (-) ->
        le_i18n:le_msg(synonym_with_other_additions_desc, [], Desc),
        le_i18n:le_msg(synonym_with_other_additions_fix, [], Fix),
        assertz(M:le_issue(error, synonym_with_other_additions, Desc, Fix, Start, End))
    ;   true ).
validate_synonym_template(_, _, _, _, _, _, _).

template_additions(Globals, Opposite, OppositeWV, Prep, Unknown, Synonyms, NTs, FunctorArgs, TStart, TEnd) -->
    t(punctuation(';', _)),
    (   kw(defines_global) ->
        template_instance(Tokens),
        { reconstruct_name(Tokens, G) },
        template_additions(Gs, Opposite, OppositeWV, Prep, Unknown, Synonyms, NTs, FunctorArgs, TStart, TEnd),
        { Globals = [G|Gs] }
    ;   kw(opposite) ->
        template_instance(OppositeTokens0),
        % The colon written after 'opposite:' is captured as a punct token here;
        % strip it before processing so it doesn't show up in WordsAndVars.
        { (OppositeTokens0 = [punct(':', _)|RestTokens] -> OppositeTokens = RestTokens ; OppositeTokens = OppositeTokens0) },
        { process_template(OppositeTokens, OppositeFunctorArgs, _OppositeNamesTypes, OppositeWV) },
        % Unify variables by position so main args and opposite args share Prolog vars.
        { FunctorArgs = [_|Args], OppositeFunctorArgs = [OppF|OppArgs], unify_args(Args, OppArgs) },
        { Opposite =.. [OppF | OppArgs] },
        template_additions(Globals, _, _, Prep, Unknown, Synonyms, NTs, FunctorArgs, TStart, TEnd)
    ;   kw(synonym) ->
        % A synonym maps a second surface form to the SAME predicate. Parse the
        % alternative template and unify its arguments (by position) with the main
        % template's so they share Prolog variables; its words become an extra dict
        % with the main FunctorArgs. Several synonyms may be chained.
        template_instance(SynonymTokens0),
        { (SynonymTokens0 = [punct(':', _)|SynRest] -> SynonymTokens = SynRest ; SynonymTokens = SynonymTokens0) },
        { process_template(SynonymTokens, SynonymFunctorArgs, _SynNTs, SynonymWV) },
        { FunctorArgs = [_|Args2], SynonymFunctorArgs = [_|SynArgs], unify_args(Args2, SynArgs) },
        template_additions(Globals, Opposite, OppositeWV, Prep, Unknown, Syns, NTs, FunctorArgs, TStart, TEnd),
        { Synonyms = [SynonymWV|Syns] }
    ;   prepositional_keyword ->
        { Prep = prepositional },
        template_additions(Globals, Opposite, OppositeWV, _, Unknown, Synonyms, NTs, FunctorArgs, TStart, TEnd)
    ;   unknown_keyword ->
        { Unknown = unknown },
        template_additions(Globals, Opposite, OppositeWV, Prep, _, Synonyms, NTs, FunctorArgs, TStart, TEnd)
    ;   undefined_keyword ->
        { Unknown = scenario_element },
        template_additions(Globals, Opposite, OppositeWV, Prep, _, Synonyms, NTs, FunctorArgs, TStart, TEnd)
    ;   kw(known_as) ->
        % "; known as played" binds this template to an LPS functor
        % (docs/le_lps_surface.md §2). The generated internal syntax, the
        % timeline lanes, the state-transitions diagram and any companion .lps
        % file all name the predicate, so the author needs to be able to
        % choose it rather than accept LE2's derived `has_played`.
        t(word(Functor)),
        { record_template_functor(FunctorArgs, Functor, TStart, TEnd) },
        template_additions(Globals, Opposite, OppositeWV, Prep, Unknown, Synonyms, NTs, FunctorArgs, TStart, TEnd)
    ;   kw(image) ->
        % "; image "URL"" on a TEMPLATE: only meaningful on a no-variable
        % (propositional) template — its single ground literal then renders as
        % that image in the Bento Box (a fallback when the scenario fact
        % carries no image of its own). A template with variables gets a
        % warning and the image is dropped.
        ( t(doubleQuoteString(URL, loc(UStart, UEnd))) | t(quoteString(URL, loc(UStart, UEnd))) ),
        { record_template_image(FunctorArgs, URL, UStart, UEnd) },
        template_additions(Globals, Opposite, OppositeWV, Prep, Unknown, Synonyms, NTs, FunctorArgs, TStart, TEnd)
    ).
template_additions([], _, _, _, _, [], _, _, _, _) --> [].

%!  record_template_functor(+FunctorArgs, +Functor, +TStart, +TEnd) is det.
%
%   Records `; known as f` for the template whose derived functor is the head
%   of FunctorArgs. Recorded as a fact in the compiling module rather than
%   carried in the dict, so that nothing about the dict's shape — which nine
%   other predicates destructure — has to change for a target-specific
%   annotation.
record_template_functor(FunctorArgs, Functor, TStart, TEnd) :-
    (   le_kbs:current_compiling_module(M), M \== (-)
    ->  FunctorArgs = [Derived|Args],
        length(Args, Arity),
        (   le_grammar:lps_target
        ->  assertz(M:le_lps_functor(Derived/Arity, Functor))
        ;   le_i18n:le_msg(known_as_not_lps_desc, [], Desc),
            le_i18n:le_msg(known_as_not_lps_fix, [], Fix),
            assertz(M:le_issue(warning, known_as_not_lps, Desc, Fix, TStart, TEnd))
        )
    ;   true
    ).

%!  record_template_image(+FunctorArgs, +URL, +UStart, +UEnd) is det.
%
%   Stores le_template_image(Functor, URL) for a no-variable template with a
%   well-formed http(s) URL; otherwise asserts a warning and drops the image.
record_template_image(FunctorArgs, URL0, UStart, UEnd) :-
    (   \+ ( le_kbs:current_compiling_module(M), M \== (-) ) -> true
    ;   le_kbs:current_compiling_module(M),
        (   FunctorArgs = [_|Args], Args \== []
        ->  le_i18n:le_msg(image_template_vars_desc, [], Desc),
            le_i18n:le_msg(image_template_vars_fix, [], Fix),
            assertz(M:le_issue(warning, image_template_vars, Desc, Fix, UStart, UEnd))
        ;   \+ well_formed_image_url(URL0)
        ->  le_i18n:le_msg(image_bad_url_desc, [url-URL0], Desc),
            le_i18n:le_msg(image_bad_url_fix, [], Fix),
            assertz(M:le_issue(warning, image_bad_url, Desc, Fix, UStart, UEnd))
        ;   FunctorArgs = [F],
            atom_string(URL, URL0),
            assertz(M:le_template_image(F, URL))
        )
    ).

% prepositional_keyword matches the marker declaring a template prepositional (a
% chainable phrase constraining a variable). English accepts 'prepositional' and
% its synonym 'composite'; both map to the same downstream 'prepositional'
% semantics. The surface words come from the 'prepositional' lexicon key.
prepositional_keyword --> kw(prepositional).

% unknown_keyword matches the marker declaring a template (or fact) as
% assumable/abducible. English accepts 'unknown' and its synonyms 'assumed' and
% 'assumable'; all map to the same downstream 'unknown' semantics.
unknown_keyword --> kw(unknown).

% undefined_keyword marks a template as a scenario element: facts matching it
% are expected only in scenarios, never defined in the knowledge base. The
% verifier will suppress 'undefined_predicate' warnings for it and instead warn
% if it appears as a fact or rule head in the knowledge base.
undefined_keyword --> kw(undefined).


% validate_prepositional_template(+Prep, +FunctorArgs, +WordsAndVars, +Start, +End)
% Reports an issue if the template marked 'prepositional' is malformed.
validate_prepositional_template(Prep, _, _, _, _) :- var(Prep), !.
validate_prepositional_template(prepositional, [_Functor|Args], WordsAndVars, Start, End) :-
    ( le_kbs:current_compiling_module(M) -> true ; M = (-) ),
    length(Args, N),
    (   N == 2 -> true
    ;   le_i18n:le_msg(prepositional_arity_desc, [n-N], Desc),
        le_i18n:le_msg(prepositional_arity_fix, [], Fix),
        (M \== (-) -> assertz(M:le_issue(error, prepositional_arity, Desc, Fix, Start, End)) ; true)
    ),
    (   WordsAndVars = [V|_], var(V) -> true
    ;   le_i18n:le_msg(prepositional_first_arg_desc, [], Desc2),
        le_i18n:le_msg(prepositional_first_arg_fix, [], Fix2),
        (M \== (-) -> assertz(M:le_issue(error, prepositional_first_arg, Desc2, Fix2, Start, End)) ; true)
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
    WordsAndVars = [Type | Rest],
    le_i18n:kw_synonym_words(is_a, IsAWords),
    append(Prefix, [SuperType], Rest),
    Prefix == IsAWords,
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
process_template_parts([list(_, _)|Ps], [V|Args], [V-list|NTs], [V|WVs]) :-
    !, process_template_parts(Ps, Args, NTs, WVs).
process_template_parts([list(_)|Ps], [V|Args], [V-list|NTs], [V|WVs]) :-
    !, process_template_parts(Ps, Args, NTs, WVs).

extract_var_info_from_words(Words, Name, Type) :-
    ( Words = [Art | Rest], Rest \== [], is_article(Art) -> atomic_list_concat(Rest, ' ', Type); atomic_list_concat(Words, ' ', Type)),
    Name = Type.

is_article(A) :- le_i18n:class_member(article, A).

is_ignorable(W) :- le_i18n:class_member(ignorable, W).

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
% A list part carries its source location like every other part — without it,
% an item STARTING with a list (e.g. the fact "[Alice, Bob] is a set.") got
% Start = 0, which downstream (addSessionFact) means "no source info", so such
% scenario facts lost their source ranges and e.g. never appeared as Proof
% Game cards.
template_instance_part(list(L, loc(Start, End))) --> t(punct('[', loc(Start, _))), list_elements(L), t(punct(']', loc(_, End))).
template_instance_part(expr(E)) --> t(punct('(')), template_instance(E), t(punct(')')).
template_instance_part(punct(P, Loc)) --> t(punctuation(P, Loc)), { \+ member(P, ['[', ']', '(', ')']) }.
template_instance_part(punct('(', Loc)) --> t(punctuation('(', Loc)).
template_instance_part(punct(')', Loc)) --> t(punctuation(')', Loc)).

% template_var_words(Words) parses the words inside a *variable*.
template_var_words([W|Ws]) --> t(word(W)), !, template_var_words(Ws).
template_var_words([]) --> [].

% list_elements(Elements) parses a comma-separated list of template instances.
list_elements([E|Es]) --> with_allow_commas(false, template_instance(E)), ( t(punct(',')), !, list_elements(Es) | { Es = [] } ).
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
is_terminator --> any_indent, kw(only_if).
is_terminator --> any_indent, t(punctuation(';', _)).
is_terminator --> any_indent, kw(if), t(punctuation(':', _)).
is_terminator --> any_indent, kw(unless), t(punctuation(':', _)).
is_terminator --> any_indent, t(punctuation('.', _)), peek_terminator.
is_terminator --> any_indent, t(punctuation(',', _)), { \+ get_allow_commas(true) }.
is_terminator --> any_indent, t(punctuation(',', _)), peek_terminator.
is_terminator --> any_indent, kw(if).
is_terminator --> any_indent, kw(unless).
is_terminator --> any_indent, kw(either).
is_terminator --> any_indent, kw(any_of).
is_terminator --> any_indent, kw(all_of).
is_terminator --> any_indent, kw(and_unless).
is_terminator --> any_indent, kw(expects).

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

is_reserved(W) :- le_i18n:class_member(reserved, W).

extract_id(Words, Name) :-
    \+ (member(W, Words), is_reserved(W)),
    ( append(TypeWords, [ID], Words), TypeWords \== [], is_id(ID) -> Name = ID; atomic_list_concat(Words, ' ', Name)).

extract_var_name(Words, Name) :-
    extract_var_name_extension(Words, Name), !.
extract_var_name(Words, Name) :-
    (   Words = [Art | Rest], Rest \== [], is_article(Art) ->
            length(Rest, L), L =< 5,
            extract_id(Rest, Name)
        ; Words = [W1 | Rest], Rest \== [], le_i18n:class_member(each, W1) ->
            length(Rest, L), L =< 5,
            extract_id(Rest, Name)
        ; Words = [W1 | Rest], Rest \== [], le_i18n:class_member(wh_var, W1) ->
            length(Rest, L), L =< 5,
            extract_id(Rest, Name)
        ; Words = [W], wh_pronoun(W) -> capitalize_atom(W, Name)
        ; Words = [W], is_id(W) -> Name = W
    ).

% A standalone interrogative pronoun usable as a variable ("who", "what",
% "when", "where" in English); its capitalised surface becomes the variable
% name ('Who', 'What', ...), whatever the language.
wh_pronoun(W) :-
    (   le_i18n:class_member(who, W)
    ;   le_i18n:class_member(what, W)
    ;   le_i18n:class_member(when, W)
    ;   le_i18n:class_member(where, W)
    ), !.

capitalize_atom(W, Cap) :-
    atom_codes(W, [C|Cs]),
    ( code_type(C, lower(U)) -> atom_codes(Cap, [U|Cs]) ; Cap = W ).

%!  allow_var_name(+Mode, +Words, -Name) is semidet.
%
%   Decides whether a sequence of Words introduces a variable, and under
%   what determiner policy:
%   - Mode == true: any article (a/an/the/some) or id introduces a variable
%     (the classic rule/query behaviour).
%   - Mode == indefinite: only an indefinite determiner (a/an/some) introduces
%     a fresh variable. A definite phrase ("the repair cost") is left to be
%     treated as a constant individual. Used when parsing scenario facts, where
%     "a damage" is an (existentially) typed variable but "the repair cost" is a
%     specific individual.
allow_var_name(true, Words, Name) :- extract_var_name(Words, Name).
allow_var_name(indefinite, Words, Name) :- \+ definite_phrase(Words), extract_var_name(Words, Name).

definite_phrase([Art | _]) :- le_i18n:class_member(definite_article, Art).

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
              ; allow_var_name(AllowVars, Words, Name) -> unify_with_vmap(Name, Value, VMIn, VMOut, true)
              ; NoTransform \== true, transform_instance(Parts, Templates, VMIn, VMOut, Value, AllowVars, Depth) -> true
              ; is_proper_name(Words) -> tokens_to_string(Parts, Value), VMOut = VMIn
              ; parse_expression(Parts, VMIn, VMOut, Templates, Value, AllowVars),
                \+ is_hyphenated_id(Value, VMIn) -> true
              ; (AllowVars == false ; AllowVars == indefinite) -> ( Words = [Value] -> true; tokens_to_string(Parts, Value)), VMOut = VMIn
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
extract_simple_value(list(_, _), '[]').
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

%!  head_noun_type(+Phrase, -HeadType) is det.
%
%   Derives the *type* of a variable phrase by dropping (a) a leading determiner,
%   (b) a trailing all-caps identifier — the "a person X" naming convention — and
%   (c) any leading qualifier words (ordinals, "other", "another", ...). So both
%   "first person" and "person X" yield the type "person", while a genuine
%   multi-word type such as "bodily injury" is left intact. A variable's stored
%   descriptive phrase ("first person") is kept as its name elsewhere — this only
%   derives the type used for type checking and ontology registration.
head_noun_type(Phrase, HeadType) :-
    ( atom(Phrase) -> true ; string(Phrase) ),
    atomic_list_concat(Words0, ' ', Phrase),
    exclude(==(''), Words0, Words1),
    ( Words1 = [Art|AfterArt], is_article(Art) -> WordsA = AfterArt ; WordsA = Words1 ),
    ( append(WordsNoId, [Last], WordsA), WordsNoId \== [], is_id(Last) -> WordsB = WordsNoId ; WordsB = WordsA ),
    strip_leading_qualifiers(WordsB, WordsHead),
    atomic_list_concat(WordsHead, ' ', HeadType).

% Strip leading qualifier words, always leaving at least the final (head) word.
strip_leading_qualifiers([W|Rest], Head) :-
    Rest \== [], is_var_qualifier(W), !,
    strip_leading_qualifiers(Rest, Head).
strip_leading_qualifiers(Words, Words).

%!  is_var_qualifier(?Word) is semidet.
%
%   Words that may precede a noun to distinguish several variables of the same
%   type (e.g. "a first person" vs "a second person") without forming part of
%   the type itself.
is_var_qualifier(W) :- le_i18n:class_member(qualifier, W).

extract_value(var(Words, _), Val, VMIn, VMOut, Templates, AllowVars) :- !,
    extract_value(var(Words), Val, VMIn, VMOut, Templates, AllowVars).
extract_value(var(Words), Val, VMIn, VMOut, _Templates, AllowVars) :-
    !, extract_var_info_from_words(Words, Name, _Type),
    ( AllowVars == true -> unify_with_vmap(Name, Val, VMIn, VMOut, true); Val = Name, VMOut = VMIn).
extract_value(word(W, _), Val, VMIn, VMOut, _Templates, AllowVars) :-
    ( le_kbs:do_log -> print_message(informational,'Extract value word: ~w (AllowVars: ~w)~n' - [W, AllowVars]); true),
    ( (AllowVars == false ; AllowVars == indefinite) -> Val = W, VMOut = VMIn;
      (extract_var_name([W], Name) -> unify_with_vmap(Name, Val, VMIn, VMOut, true) ; unify_with_vmap(W, Val, VMIn, VMOut, false))
    ).
extract_value(number(N, _), N, VM, VM, _, _).
extract_value(date(D, _), D, VM, VM, _, _).
extract_value(quoteString(S, _), S, VM, VM, _, _).
extract_value(doubleQuoteString(S, _), S, VM, VM, _, _).
extract_value(punctuation(P, _), P, VM, VM, _, _).
extract_value(punct(P, _), P, VM, VM, _, _).
extract_value(word(W), Val, VMIn, VMOut, _Templates, AllowVars) :-
    ( (AllowVars == false ; AllowVars == indefinite) -> Val = W, VMOut = VMIn;
      (extract_var_name([W], Name) -> unify_with_vmap(Name, Val, VMIn, VMOut, true) ; unify_with_vmap(W, Val, VMIn, VMOut, false))
    ).
extract_value(number(N), N, VM, VM, _, _).
extract_value(date(D), D, VM, VM, _, _).
extract_value(string(S), S, VM, VM, _, _).
extract_value(punct(P), P, VM, VM, _, _).
extract_value(list(L, _), TransformedL, VMIn, VMOut, Templates, AllowVars) :- !,
    transform_list(L, Templates, VMIn, VMOut, TransformedL, AllowVars).
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
    candidate_template(Templates, Words, dict(FunctorArgs, _NTs, WordsAndVars, _Start, _End, NIW, _Globals, _Opposite, _Prep, _Unknown)),
    copy_term(dict(FunctorArgs, WordsAndVars, NIW), dict(FunctorArgsCopy, WordsAndVarsCopy, NIWCopy)),
    contains_subsequence(NIWCopy, Words),
    match_instance_to_template(Instance, WordsAndVarsCopy, VMIn, VMOut, Templates, AllowVars, Depth),
    Literal =.. FunctorArgsCopy.

%!  candidate_template(+Templates, +Words, -Dict) is nondet.
%
%   Enumerates the templates whose fixed words all occur (in order) in Words —
%   META templates first, then the rest, each group in the usual specificity
%   order. A meta template's 'that'/'says'-marked slot is, by the LE convention,
%   the LAST slot and swallows the remainder of the sentence, so when such a
%   template matches it must be tried as the OUTER literal. Trying a wordier
%   template first would let it absorb the meta phrase into an ordinary slot —
%   e.g. "a third person says that the person is the father of the other person"
%   used to parse as is_the_father_of(says_that(C, 'the person'), B) instead of
%   says_that(C, is_the_father_of(A, B)). Non-meta candidates still follow on
%   backtracking, so nothing that parsed before becomes unparseable.
candidate_template(Templates, Words, Dict) :-
    % Fetch the active language's meta-marker word list ONCE per call: this
    % predicate scans every template, and a per-word lexicon lookup here is a
    % measurable parse-time regression on large programs.
    le_i18n:class_word_list(meta_marker, Ms),
    template_partition(Templates, Ms, Metas, Rest),
    ( member(Dict, Metas) ; member(Dict, Rest) ),
    Dict = dict(_FA, _NTs, _WV, _Start, _End, NIW, _Globals, _Opposite, _Prep, _Unknown),
    contains_subsequence(NIW, Words).

%!  template_partition(+Templates, +MetaMarkers, -Metas, -Rest) is det.
%
%   The meta templates and the others — computed ONCE per template list rather
%   than once per sentence parsed.
%
%   The split itself is cheap; doing it per sentence is not. The meta test walks
%   a template's whole word list, and the two branches this replaces ran it over
%   every template twice: on a 386-template program with no meta template at all
%   that was 3.5 million failing scans, a third of the parse time, for a
%   partition that never changes while a section is being parsed.
%
%   The cache is the identity of the list: `prepare_templates/2` builds it once
%   per section and the same term is then handed to every sentence, so `==`
%   settles it by pointer in the hit case and a miss merely recomputes. It lives
%   in a backtrackable global (per-thread, so the server's sessions cannot see
%   each other's, and a value restored by backtracking is still a correct
%   partition of whatever list it was computed from).
template_partition(Templates, Ms, Metas, Rest) :-
    (   catch(b_getval(le_template_partition, part(Cached, M0, R0)), _, fail),
        Cached == Templates
    ->  Metas = M0, Rest = R0
    ;   partition(meta_candidate(Ms), Templates, Metas, Rest),
        b_setval(le_template_partition, part(Templates, Metas, Rest))
    ).

% A template that gets META parse priority: not a built-in, and its word list
% has a marked slot.
meta_candidate(Ms, dict(FA, _, WV, _, _, _, _, _, _, _)) :-
    \+ system_template_fa(FA),
    meta_template_wv(WV, Ms).

% A built-in (le_-prefixed) template. System templates never get META parse
% priority: in Romance languages the meta marker 'que' also occurs in ordinary
% comparison phrasings, and giving built-ins meta priority would reorder the
% whole template list (O-14 guard; a no-op for English, whose system templates
% contain no meta markers).
system_template_fa([F|_]) :-
    atom(F),
    sub_atom(F, 0, 3, _, le_).

%!  meta_template_wv(+WV) is semidet.
%
%   The template's word list has a META slot: a variable immediately preceded by
%   a meta marker word (a word of the meta_marker lexicon class, see
%   is_meta_prev/1).
meta_template_wv(WV) :-
    le_i18n:class_word_list(meta_marker, Ms),
    meta_template_wv(WV, Ms).

meta_template_wv([W, V|_], Ms) :-
    atom(W), memberchk(W, Ms), var(V), !.
meta_template_wv([_|T], Ms) :-
    meta_template_wv(T, Ms).

match_instance_to_template(Instance, WordsAndVars, VMIn, VMOut, Templates, AllowVars) :-
    match_instance_to_template(Instance, WordsAndVars, VMIn, VMOut, Templates, AllowVars, 0).

match_instance_to_template(Instance, WordsAndVars, VMIn, VMOut, Templates, AllowVars, Depth) :-
    match_instance_to_template_acc(Instance, WordsAndVars, VMIn, VMOut, Templates, AllowVars, Depth, none).

% The last argument (Prev) is the most recently consumed template *constant*. It
% lets us recognise a meta-variable: per the LE convention a meta-variable (an
% embedded eventuality, e.g. the "*an eventuality*" in "it is prohibited that
% *an eventuality*") is always the last template slot and is immediately preceded
% by the word "that" (or "says"). Such a slot must be parsed as an embedded
% literal rather than captured wholesale as a single variable name.
match_instance_to_template_acc([], [], VM, VM, _, _, _, _).
match_instance_to_template_acc(Instance, [T|Ts], VMIn, VMOut, Templates, AllowVars, Depth, _Prev) :-
    \+ var(T), is_ignorable(T), !,
    ( Instance = [I|Is], extract_simple_word(I, W), W == T ->
        match_instance_to_template_acc(Is, Ts, VMIn, VMOut, Templates, AllowVars, Depth, T)
        ; match_instance_to_template_acc(Instance, Ts, VMIn, VMOut, Templates, AllowVars, Depth, T)
        ).
match_instance_to_template_acc([I|Is], [T|Ts], VMIn, VMOut, Templates, AllowVars, Depth, Prev) :-
    \+ var(T), extract_simple_word(I, W), is_ignorable(W), W \== T, !,
    match_instance_to_template_acc(Is, [T|Ts], VMIn, VMOut, Templates, AllowVars, Depth, Prev).
match_instance_to_template_acc(Instance, [T|Ts], VMIn, VMOut, Templates, AllowVars, Depth, Prev) :-
    (   \+ var(T) ->
        Instance = [I|Is],
        match_part(I, T, VMIn, VM1, Templates, AllowVars),
        match_instance_to_template_acc(Is, Ts, VM1, VMOut, Templates, AllowVars, Depth, T)
        ;
        % T is a variable (from the template dict). A meta-variable (preceded by
        % "that"/"says") is parsed as an embedded literal; an ordinary variable
        % captures its token span as a value/name.
        ( is_meta_prev(Prev) -> Meta = true ; Meta = false ),
        % Lookahead to avoid over-consuming
        (   Ts = [NextT|RestTs], \+ var(NextT) ->
                % Optimization: find a split that matches the next constant part
                % and satisfies the variable extraction.
                (
                    append(VarTokens, [NextI|Rest], Instance),
                    VarTokens \== [],
                    match_part(NextI, NextT, VMIn, VM1, Templates, AllowVars),
                    extract_template_var(VarTokens, T, VM1, VM2, Templates, AllowVars, Depth, Meta),
                    match_instance_to_template_acc(Rest, RestTs, VM2, VMOut, Templates, AllowVars, Depth, NextT)
                )
            ; Ts = [] ->
                VarTokens = Instance,
                VarTokens \== [],
                extract_template_var(VarTokens, T, VMIn, VMOut, Templates, AllowVars, Depth, Meta)
            ; % Next part is also a variable, must try all splits
              (
                append(VarTokens, Rest, Instance),
                VarTokens \== [],
                extract_template_var(VarTokens, T, VMIn, VM1, Templates, AllowVars, Depth, Meta),
                match_instance_to_template_acc(Rest, Ts, VM1, VMOut, Templates, AllowVars, Depth, none)
              )
        )
    ).

%!  is_meta_prev(+Prev) is semidet.
%
%   True when the template constant just consumed marks the following variable as
%   a meta-variable (an embedded eventuality/clause).
is_meta_prev(W) :- le_i18n:class_member(meta_marker, W).

%!  extract_template_var(+Parts, -Value, +VMIn, -VMOut, +Templates, +AllowVars, +Depth, +Meta) is semidet.
%
%   Extract the value for a template variable slot. For a meta-variable
%   (Meta == true) the token span is parsed as an embedded literal first, so e.g.
%   "a creature attends a tea party" becomes attends(Creature, TeaParty) instead
%   of being captured as a single variable named "creature attends a tea party".
%   It falls back to ordinary value extraction when no embedded template matches.
extract_template_var(Parts, Value, VMIn, VMOut, Templates, AllowVars, Depth, true) :-
    transform_instance(Parts, Templates, VMIn, VMOut, Value, AllowVars, Depth), !.
extract_template_var(Parts, Value, VMIn, VMOut, Templates, AllowVars, Depth, _Meta) :-
    extract_value_from_parts(Parts, Value, VMIn, VMOut, Templates, false, AllowVars, Depth).

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
           forall(member(_-Type, NTs),
                  ( atom(Type) ->
                        assert_is_a_type(Type),
                        % Also register the head-noun type, so that a qualified
                        % variable like "a first person" contributes the type
                        % "person" to the ontology.
                        ( head_noun_type(Type, HeadType), HeadType \== Type -> assert_is_a_type(HeadType) ; true )
                  ; true ))),
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
% Stored le_dict templates (see assert_dict_with_source/2 in le_kbs) keep the
% layout dict(FA, NT, WV, Globals, Opposite, Prep, Unknown) — Start/End are
% dropped on assertion. Preserve Prep and Unknown here; mapping them as if they
% were (Start,End,Globals,Opposite) silently loses the prepositional marker and
% breaks prepositional chaining for post-load queries.
add_non_ignorable(dict(FA, NT, WV, Globals, Opposite, Prep, Unknown), dict(FA, NT, WV, 0, 0, NIW, Globals, Opposite, Prep, Unknown)) :- !,
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


is_meta_template(dict(FA, _, WordsAndVars, _, _, _, _, _, _)) :-
    \+ system_template_fa(FA),
    member(W, WordsAndVars),
    atom(W),
    is_meta_prev(W).

get_dicts(predicates(Ds), Ds).
get_dicts(templates(Ds), Ds).
get_dicts(fluents(Ds), Ds).
get_dicts(events(Ds), Ds).
get_dicts(actions(Ds), Ds).
get_dicts(prolog_events(Ds), Ds).
get_dicts(meta(_), []).       % meta carries the target atom, not user dicts
get_dicts(_, []).

second_pass_section(Templates, M, kb(Name, Content, Start, End), kb(Name, NewContent, Start, End)) :-
    second_pass_content(Content, Templates, NewContent, M).
second_pass_section(_, _, unknown_section(Tokens, Start, End), unknown_section(Tokens, Start, End)).
% Section markers are only meaningful in knowledge base sections; strip any that
% appear in ontology/scenario/query content (they share kb_content with the KB).
second_pass_section(Templates, M, ontology(Content, Start, End), ontology(NewContent, Start, End)) :-
    exclude(is_section_marker, Content, Content1),
    maplist(second_pass_ontology_item_with_module(Templates, M), Content1, NewContent).
second_pass_section(Templates, M, scenario(Name, Content, Start, End), scenario(Name, NewContent, Start, End)) :-
    exclude(is_section_marker, Content, Content1),
    maplist(second_pass_scenario_item_with_module(Templates, M), Content1, NewContent).
second_pass_section(Templates, M, query(Name, Content, Start, End), query(Name, NewContent, Start, End)) :-
    exclude(is_section_marker, Content, Content1),
    maplist(second_pass_query_item_with_module(Templates, M), Content1, NewContent).
second_pass_section(_, _, S, S). % Keep other sections as is

is_section_marker(section_marker(_, _, _)).

second_pass_ontology_item_with_module(Templates, M, Item, NewItem) :-
    second_pass_ontology_item(Templates, Item, NewItem, M),
    check_stray_asterisks(Item, NewItem, M).

second_pass_scenario_item_with_module(Templates, M, Item, NewItem) :-
    %  The extension is tried here too, not only in a knowledge base: under the
    %  LPS target a scenario is a list of timed observations, and its facts
    %  carry the temporal suffix that plain LE has no use for.
    ( second_pass_item_extension(Templates, Item, NewItem, M) -> true
    ; second_pass_scenario_item(Templates, Item, NewItem, M)
    ),
    check_stray_asterisks(Item, NewItem, M).

second_pass_query_item_with_module(Templates, M, Item, NewItem) :-
    second_pass_query_item(Templates, Item, NewItem, M),
    check_stray_asterisks(Item, NewItem, M).

second_pass_content(Items, Templates, NewItems, M) :-
    ( le_kbs:do_log -> length(Items, L), print_message(informational,'Second pass content: ~w items~n' - [L]); true),
    maplist(second_pass_item_with_module(Templates, M), Items, NewItems).

second_pass_item_with_module(Templates, M, Item, NewItem) :-
    ( second_pass_item_extension(Templates, Item, NewItem, M) -> true
    ; second_pass_item(Templates, Item, NewItem, M)
    ),
    check_stray_asterisks(Item, NewItem, M).

%!  check_stray_asterisks(+Item, +NewItem, +M) is det.
%
%   Outside the templates sections, '*' is only valid as multiplication inside an
%   arithmetic expression. A '*' anywhere else (e.g. the typo "a claim*") is
%   silently swallowed into a variable name, detaching the variable from its
%   other occurrences ("the claim" no longer refers to it) and corrupting its
%   type — so flag it as a syntax error. Detection: count the '*' tokens in the
%   source Item and the '*'/2 (multiplication) subterms in the compiled NewItem;
%   any excess token is stray. Located at the first '*' token when none were
%   multiplications, otherwise at the last one (a stray '*' typically trails the
%   sentence, while multiplications sit mid-expression).
check_stray_asterisks(Item, NewItem, M) :-
    (   nonvar(M), M \== (-),
        asterisk_token_locs(Item, Locs),
        Locs \== [],
        mult_use_count(NewItem, NMult),
        length(Locs, NTok),
        NTok > NMult
    ->  ( NMult =:= 0 -> Locs = [loc(S, E)|_] ; last(Locs, loc(S, E)) ),
        le_i18n:le_msg(stray_asterisk_desc, [], Desc),
        le_i18n:le_msg(stray_asterisk_fix, [], Fix),
        assertz(M:le_issue(error, stray_asterisk, Desc, Fix, S, E))
    ;   true
    ).

% All source locations of '*' punctuation tokens anywhere in Term, in textual order.
asterisk_token_locs(Term, Locs) :-
    findall(loc(S, E), asterisk_token_loc(Term, S, E), Locs).

asterisk_token_loc(Term, S, E) :-
    compound(Term),
    (   (Term = punctuation('*', loc(S, E)) ; Term = punct('*', loc(S, E)))
    ->  true
    ;   arg(_, Term, Arg),
        asterisk_token_loc(Arg, S, E)
    ).

% Number of multiplication ('*'/2) subterms in the compiled item.
mult_use_count(Term, N) :-
    findall(x, mult_subterm(Term), Xs),
    length(Xs, N).

mult_subterm(Term) :-
    compound(Term),
    (   functor(Term, '*', 2)
    ;   arg(_, Term, Arg),
        mult_subterm(Arg)
    ).

% An image addition on a RULE ("… if <body>; image "URL"."): images can only
% annotate facts. The body-token scan strips the addition, warns, and the rule
% compiles normally without it. Placed before the rule clauses so it runs
% first; the memberchk guard keeps the common (no ';') case cheap.
second_pass_item(Templates, rule(Head, Body0, Indent, Start, End, ID), NewItem, M) :-
    rule_body_wrapper(Body0, Tokens, Wrapper),
    memberchk(punctuation(';', _), Tokens),
    strip_trailing_image_tokens(Tokens, CleanTokens, IStart, IEnd),
    !,
    (   ( var(M) ; M == (-) ) -> true
    ;   le_i18n:le_msg(image_on_rule_desc, [], Desc),
        le_i18n:le_msg(image_on_rule_fix, [], Fix),
        assertz(M:le_issue(warning, image_on_rule, Desc, Fix, IStart, IEnd))
    ),
    rule_body_wrapper(Body1, CleanTokens, Wrapper),
    second_pass_item(Templates, rule(Head, Body1, Indent, Start, End, ID), NewItem, M).

% rule_body_wrapper(?Body, ?Tokens, ?Wrapper): a rule body is its token list,
% possibly inside an only_if/unless/numbered wrapper. Bidirectional, so the
% image check can unwrap and rebuild.
rule_body_wrapper(only_if(T), T, only_if) :- !.
rule_body_wrapper(unless(T), T, unless) :- !.
rule_body_wrapper(numbered(T), T, numbered) :- !.
rule_body_wrapper(T, T, none) :- is_list(T).

% strip_trailing_image_tokens(+Tokens, -Clean, -IStart, -IEnd): Tokens end in
% "; image "URL"" (ignoring indentation/comments); Clean is Tokens without it,
% IStart-IEnd the addition's source range.
strip_trailing_image_tokens(Tokens, Clean, IStart, IEnd) :-
    append(Clean, [punctuation(';', loc(IStart, _)) | Rest0], Tokens),
    skip_noise(Rest0, [word(W, _) | Rest1]),
    le_i18n:kw_synonym_words(image, [W]),
    skip_noise(Rest1, [StrTok | Rest2]),
    ( StrTok = doubleQuoteString(_, loc(_, IEnd)) ; StrTok = quoteString(_, loc(_, IEnd)) ),
    skip_noise(Rest2, []),
    !.

skip_noise([indent(_, _)|Ts], Out) :- !, skip_noise(Ts, Out).
skip_noise([line_comment(_, _)|Ts], Out) :- !, skip_noise(Ts, Out).
skip_noise([multi_comment(_, _)|Ts], Out) :- !, skip_noise(Ts, Out).
skip_noise(Ts, Ts).

second_pass_item(Templates, rule(Head, only_if(BodyTokens), Indent, Start, End, ID), clause(NewHead, NewBody, Start, End, ActualID), _M) :-
    (var(ID) -> format(atom(ActualID), 'rule_~w', [Start]) ; ActualID = ID),
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
            ( ExtraGoals == [] -> NewBody = not(SubBody) ; append(ExtraGoals, [not(SubBody)], AllGoals), list_to_conj(AllGoals, NewBody) )
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
            % Wrap the "unless" negation in an le_at spanning the whole rule, so the
            % negation node in a failure explanation carries a source range (and
            % navigates to the unless rule) — mirroring how an explicit "it is not
            % the case that ..." is compiled (parse_node/6). Without this the bare
            % not/1 has no range and the node points nowhere.
            NegGoal = le_at(not(SubBody), Start, End),
            ( ExtraGoals == [] -> NewBody = NegGoal ; append(ExtraGoals, [NegGoal], AllGoals), list_to_conj(AllGoals, NewBody) )
            ;
            NewBody = true % Fallback
        )
        ;
        NewHead = unknown_template(Head),
        ( parse_body(BodyTokens, Indent, Templates, [], _VMOut, SubBody) -> NewBody = le_at(not(SubBody), Start, End); NewBody = true)
    ).

second_pass_item(Templates, rule(Head, numbered(BodyTokens), _Indent, Start, End, ID), clause(NewHead, NewBody, Start, End, ActualID), M) :-
    (var(ID) -> format(atom(ActualID), 'rule_~w', [Start]) ; ActualID = ID),
    (   parse_literal(Head, Templates, [], VM1, NewHead, _, true) ->  
        (   le_extensions:parse_numbered_body(BodyTokens, Templates, VM1, VMOut, Body0, ActualID, M) ->  
            collect_extra_goals(VMOut, ExtraGoals),
            ( ExtraGoals == [] -> NewBody = Body0 ; append(ExtraGoals, [Body0], AllGoals), list_to_conj(AllGoals, NewBody) )
            ;   
            NewBody = true % Fallback
        )
        ;   
        NewHead = unknown_template(Head),
        ( le_extensions:parse_numbered_body(BodyTokens, Templates, [], _VMOut, NewBody, ActualID, M) -> true; NewBody = true)
    ).

second_pass_item(Templates, rule(Head, BodyTokens, Indent, Start, End, ID), clause(NewHead, NewBody, Start, End, ActualID), _M) :-
    (var(ID) -> format(atom(ActualID), 'rule_~w', [Start]) ; ActualID = ID),
    ( le_kbs:do_log -> maplist(extract_simple_word, Head, Words), print_message(informational,'Processing rule: ~w~n' - [Words]); true),
    (   parse_literal(Head, Templates, [], VM1, NewHead, HeadInst, true) ->
        maybe_record_synonym_use(Templates, NewHead, HeadInst, Start, End),
        (   parse_body(BodyTokens, Indent, Templates, VM1, VMOut, Body0) ->
            ( le_kbs:do_log -> print_message(informational,'  Rule succeeded~n'); true),
            collect_extra_goals(VMOut, ExtraGoals0),
            order_extra_goals_by_source(ExtraGoals0, ExtraGoals),
            % Constrain each head variable to the type named by that variable, so
            % rules sharing a functor but with differently-typed heads (e.g.
            % "a payment in respect of a claim if ..." vs "an amount in respect of
            % a claim if ...") only fire for arguments of the matching type.
            head_var_type_checks(NewHead, VM1, Templates, TypeChecks),
            append(TypeChecks, ExtraGoals, PreGoals),
            ( PreGoals == [] -> NewBody = Body0 ; append(PreGoals, [Body0], AllGoals), list_to_conj(AllGoals, NewBody) ),
            store_rule_var_names(ActualID, NewHead, NewBody, VMOut)
            ;
            ( le_kbs:do_log -> print_message(informational,'  Rule body failed to parse~n'); true),
            NewBody = true % Fallback
        )
        ;
        ( le_kbs:do_log -> print_message(informational,'  Rule head failed to match template~n'); true),
        NewHead = unknown_template(Head),
        % The rule's own Indent must be passed here: an unbound indent ends up
        % in line/2 terms and crashes take_nested_hierarchy's M > N, aborting
        % the WHOLE parse ("Parsing failed") instead of leaving a tidy
        % missing_template report for this one rule.
        ( parse_body(BodyTokens, Indent, Templates, [], _VMOut, NewBody) -> true; NewBody = true)
    ).

%!  head_var_type_checks(+HeadLiteral, +VM, +Templates, -Checks) is det.
%
%   le_type_check/2 goals constraining a head argument to the type named by its
%   variable in VM (its head-noun type) — but ONLY at *ambiguous* argument
%   positions: positions where the functor's templates disagree on the type
%   (e.g. argument 1 of in_respect_of/2 is 'payment' in one template and 'amount'
%   in another). At unambiguous positions the type is not a discriminator (e.g. a
%   single 'affiliate' template, where a company may legitimately be an
%   affiliate), so no check is imposed. A head variable with no name in VM, or
%   whose type is 'any', also imposes no check.
%
%   NB: do NOT use findall/3 to collect the checks — it would copy the
%   le_type_check terms and detach them from the head variables they constrain.
head_var_type_checks(HeadLiteral, VM, Templates, Checks) :-
    ( compound(HeadLiteral), HeadLiteral =.. [F | Args], atom(F)
    -> length(Args, A), head_arg_type_checks(Args, 1, F, A, Templates, VM, Checks)
    ;  Checks = [] ).

head_arg_type_checks([], _, _, _, _, _, []).
head_arg_type_checks([Arg|Args], I, F, A, Templates, VM, Checks) :-
    (   var(Arg),
        vm_var_name(VM, Arg, Name),
        head_noun_type(Name, Type), Type \== any,
        ambiguous_position(F, A, I, Templates)
    ->  Checks = [le_type_check(Arg, Type) | Checks0]
    ;   Checks = Checks0
    ),
    I1 is I + 1,
    head_arg_type_checks(Args, I1, F, A, Templates, VM, Checks0).

% True when two templates for F/A declare different (non-any) types at position I.
ambiguous_position(F, A, I, Templates) :-
    findall(T,
        ( member(dict([F|FormalArgs], NTs, _, _, _, _, _, _, _, _), Templates),
          length(FormalArgs, A),
          nth1(I, FormalArgs, FormalArg),
          ( member(K-Ty, NTs), K == FormalArg -> T = Ty ; T = any )
        ),
        Types),
    exclude(==(any), Types, NonAny),
    sort(NonAny, Distinct),
    Distinct = [_, _ | _].

vm_var_name(VM, Var, Name) :-
    member(Name-V, VM), atom(Name), Name \== '$last_var', V == Var, !.

%!  store_rule_var_names(+ActualID, +Head, +Body, +VM) is det.
%
%   Records the source name of each variable in the rule clause Head:-Body, keyed
%   by ActualID and by each variable's position in term_variables/2 order. That
%   ordering matches the Proof Game's game_var_ids/2 numbering, so the game can
%   label a variable with the words the author actually used — a descriptive
%   phrase ("other creature") or an explicit id ("X") — rather than the template
%   slot's type. This keeps distinct same-typed variables distinct and a variable
%   consistent across the differently-typed slots it fills. The first-occurrence
%   name (from the variable map) is used as the variable's canonical name.
store_rule_var_names(ActualID, Head, Body, VM) :-
    (   le_kbs:current_compiling_module(M),
        term_variables((Head :- Body), Vars),
        findall(Idx-Name,
                ( nth0(Idx, Vars, V), vm_var_name(VM, V, Name) ),
                Pairs0),
        sort(Pairs0, Pairs),   % one entry per (index,name); drop vmap duplicates
        Pairs \== []
    ->  dynamic(M:le_var_names/2),
        assertz(M:le_var_names(ActualID, Pairs))
    ;   true
    ).

% Section markers carry no logic; keep them as-is so KB processing can pick up
% the current section for the rules that follow (see process_item/2).
second_pass_item(_Templates, section_marker(Name, Start, End), section_marker(Name, Start, End), _M).

second_pass_item(Templates, unknown_fact(Head, Start, End), clause(NewHead, NewBody, Start, End, ActualID), _M) :-
    format(atom(ActualID), 'rule_~w', [Start]),
    (   parse_literal(Head, Templates, [], VMOut, Literal, _, true) ->  
        NewHead = le_unknown(Literal),
        collect_extra_goals(VMOut, ExtraGoals),
        ( ExtraGoals == [] -> NewBody = true ; list_to_conj(ExtraGoals, NewBody) )
        ;   
        NewHead = unknown_template(Head),
        NewBody = true
    ).

second_pass_item(Templates, fact(Head, Start, End), clause(NewHead, NewBody, Start, End, ActualID), _M) :-
    format(atom(ActualID), 'rule_~w', [Start]),
    (   parse_literal(Head, Templates, [], VMOut, NewHead, HeadInst, true) ->
        maybe_record_synonym_use(Templates, NewHead, HeadInst, Start, End),
        collect_extra_goals(VMOut, ExtraGoals),
        ( ExtraGoals == [] -> NewBody = true ; list_to_conj(ExtraGoals, NewBody) )
        ;
        NewHead = unknown_template(Head),
        NewBody = true
    ).

% A fact with an image addition ("<fact>; image "URL"."): compile the fact
% exactly as a plain fact, then validate and record the image against the
% fact's source range (the same range its explanation nodes carry, which is
% how the Bento Box finds it).
second_pass_item(Templates, fact_image(Head, URL, UStart, UEnd, Start, End), NewItem, M) :-
    second_pass_item(Templates, fact(Head, Start, End), NewItem, M),
    record_fact_image(M, NewItem, URL, UStart, UEnd, Start, End).

%!  record_fact_image(+M, +CompiledFact, +URL, +UStart, +UEnd, +Start, +End) is det.
%
%   Stores le_fact_image(Start, End, URL) in M for a GROUND fact with a
%   well-formed absolute http(s) URL; otherwise asserts a warning and drops
%   the image. An unparsable fact (unknown_template) already got its own
%   error — the image is silently dropped then.
record_fact_image(M, Item, URL0, UStart, UEnd, Start, End) :-
    (   ( var(M) ; M == (-) ) -> true
    ;   Item = clause(NewHead, _, _, _, _),
        compound(NewHead), functor(NewHead, unknown_template, _) -> true
    ;   Item = clause(NewHead, _, _, _, _),
        \+ ground(NewHead)
    ->  le_i18n:le_msg(image_nonground_desc, [], Desc),
        le_i18n:le_msg(image_nonground_fix, [], Fix),
        assertz(M:le_issue(warning, image_nonground, Desc, Fix, UStart, UEnd))
    ;   \+ well_formed_image_url(URL0)
    ->  le_i18n:le_msg(image_bad_url_desc, [url-URL0], Desc),
        le_i18n:le_msg(image_bad_url_fix, [], Fix),
        assertz(M:le_issue(warning, image_bad_url, Desc, Fix, UStart, UEnd))
    ;   atom_string(URL, URL0),
        assertz(M:le_fact_image(Start, End, URL))
    ).

% An absolute http(s) URL with a host.
well_formed_image_url(URL0) :-
    atom_string(URL, URL0),
    catch(uri_components(URL, Components), _, fail),
    uri_data(scheme, Components, Scheme),
    memberchk(Scheme, [http, https]),
    uri_data(authority, Components, Authority),
    atom(Authority), Authority \== ''.

% is_global_extra_goal(+Templates, +Goal) is semidet.
%
%   True when Goal was introduced by a "defines global" abbreviation: its functor
%   is the head of a template that declares a (non-empty) global. Such goals bind
%   the global's value and so are placed before the literal that uses them, unlike
%   prepositional extra goals which constrain a variable the literal introduces.
is_global_extra_goal(Templates, Goal) :-
    callable(Goal),
    functor(Goal, F, _),
    member(dict([F|_], _, _, _, _, _, Globals, _, _, _), Templates),
    is_list(Globals), Globals \== [], !.

collect_extra_goals(VM, Goals) :-
    collect_extra_goals_acc(VM, Goals).

collect_extra_goals_acc([], []).
collect_extra_goals_acc([extra_goal(G)|Rest], [G|Gs]) :- !, collect_extra_goals_acc(Rest, Gs).
collect_extra_goals_acc([_|Rest], Gs) :- collect_extra_goals_acc(Rest, Gs).

%!  order_extra_goals_by_source(+Goals, -Ordered) is det.
%
%   Prepositional chain goals are collected (via the var-map) in reverse of the
%   order the phrases were written. When every extra goal carries a le_at source
%   range (i.e. they are all prepositional-chain goals), reorder them by that range
%   so the compiled body reflects the textual order — e.g. for "we will make a
%   payment under this policy in respect of a claim", the `under` goal precedes the
%   `in respect of` goal. When any goal lacks a range (e.g. a "defines global"
%   binding), the collected order is kept unchanged.
order_extra_goals_by_source(Goals, Ordered) :-
    (   maplist(extra_goal_source_key, Goals, Keys)
    ->  pairs_keys_values(Pairs, Keys, Goals),
        keysort(Pairs, Sorted),
        pairs_values(Sorted, Ordered)
    ;   Ordered = Goals
    ).

extra_goal_source_key(le_at(_, Start, _), Start).

%!  collect_literal_extra_goals(+VM1, +VMIn, -LiteralExtraGoals) is det.
%
%   The extra goals (e.g. prepositional or global-abbreviation conditions)
%   introduced while parsing the current literal, i.e. those present in VM1
%   but not yet in VMIn. extra_goal/1 entries are only ever prepended during
%   parsing (never reordered or removed: post_parse_literal_hook only churns
%   the $last_var entry), so VMIn's extra goals remain as a suffix of VM1's
%   and the new ones are exactly the leading (Total - Kept) goals. We cannot
%   rely on a length-based VM prefix here because $last_var churn means VM1 is
%   not always VMIn with a clean prepended prefix, and structural equality
%   would wrongly treat a re-stated condition as an existing one.
collect_literal_extra_goals(VM1, VMIn, LiteralExtraGoals) :-
    collect_extra_goals(VMIn, ExistingGoals),
    length(ExistingGoals, Kept),
    collect_extra_goals(VM1, AllGoals),
    length(AllGoals, Total),
    NumNew is Total - Kept,
    ( NumNew > 0 -> length(LiteralExtraGoals, NumNew), append(LiteralExtraGoals, _, AllGoals)
    ; LiteralExtraGoals = []
    ).

%!  remove_leading_extra_goals(+VM, +N, -VMOut) is det.
%
%   Removes the first N extra_goal/1 entries from VM (the goals just
%   introduced by the current literal), leaving every other entry untouched:
%   variable bindings, $last_var, and VMIn's own extra goals (which remain as
%   a suffix). This keeps the literal's conditions from being re-collected at
%   the clause level while preserving all shared variable bindings.
remove_leading_extra_goals(VM, 0, VM) :- !.
remove_leading_extra_goals([extra_goal(_)|Rest], N, Out) :-
    N > 0, !,
    N1 is N - 1,
    remove_leading_extra_goals(Rest, N1, Out).
remove_leading_extra_goals([X|Rest], N, [X|Out]) :-
    remove_leading_extra_goals(Rest, N, Out).

list_to_conj([G], G) :- !.
list_to_conj([G|Gs], and(G, Rest)) :- list_to_conj(Gs, Rest).
list_to_conj([], true).

% Set (per worker thread) only while parse_query_body/3 builds a QUERY goal, so
% parse_node/6 can order a prepositional chain's constraint goals BEFORE the main
% verb (constraints-first). Rule bodies parse with the flag absent and keep their
% constraints AFTER the literal (see parse_node/6). Thread-local: queries run on
% per-request worker threads.
:- thread_local in_query_body_parse/0.

%!  query_chain_goal(+ExtraGoals, +MainGoal, -Goal) is det.
%
%   Assemble a prepositional-chain query goal ("we will make X under this policy
%   in respect of this claim") with the prepositional constraint goals BEFORE the
%   main-verb goal, mirroring how a RULE head compiles its prepositional goals to
%   the front of the body (see second_pass_item/4). Solving the constraints first
%   binds the shared variables (e.g. the claim in "... in respect of this claim")
%   before the main predicate is proven, so its rule bodies run with those
%   bindings injected. Main-verb-first instead lets the main predicate pick an
%   unrelated witness for those variables (e.g. a different claim), which then
%   pollutes the failure explanation. ExtraGoals are already in textual (source)
%   order via order_extra_goals_by_source/2.
query_chain_goal([], MainGoal, MainGoal) :- !.
query_chain_goal(ExtraGoals, MainGoal, Goal) :-
    append(ExtraGoals, [MainGoal], AllGoals),
    list_to_conj(AllGoals, Goal).


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
    (var(ID) -> format(atom(ActualID), 'rule_~w', [Start]) ; ActualID = ID),
    ( parse_literal(Head, Templates, [], VM1, NewHead, _, true) -> 
        parse_body(BodyTokens, Indent, Templates, VM1, VMOut4, Body0),
        collect_extra_goals(VMOut4, ExtraGoals),
        ( (NewHead = is_a(Var, SuperType), member(Name-Var, VM1), is_a_type(Name), Name \== SuperType, \+ memberchk(Name, [thing, asset, person, object, entity, element])) ->
            (Body0 == true -> Body1 = is_a(Var, Name) ; Body1 = and(is_a(Var, Name), Body0))
          ; Body1 = Body0
        ),
        ( ExtraGoals == [] -> NewBody = Body1 ; append(ExtraGoals, [Body1], AllGoals), list_to_conj(AllGoals, NewBody) )
        ; 
        NewHead = unknown_template(Head, Start, End), 
        parse_body(BodyTokens, Indent, Templates, [], _VMOut5, NewBody)
    ).

second_pass_scenario_item(Templates, rule(Head, BodyTokens, Indent, Start, End, ID), clause(NewHead, NewBody, Start, End, ActualID), M) :-
    (var(ID) -> format(atom(ActualID), 'rule_~w', [Start]) ; ActualID = ID),
    ( parse_literal(Head, Templates, [], VM1, NewHead, HeadInst, true) ->
        maybe_record_synonym_use(M, Templates, NewHead, HeadInst, Start, End),
        parse_body(BodyTokens, Indent, Templates, VM1, VMOut6, Body0),
        collect_extra_goals(VMOut6, ExtraGoals),
        ( ExtraGoals == [] -> NewBody = Body0 ; append(ExtraGoals, [Body0], AllGoals), list_to_conj(AllGoals, NewBody) )
        ; 
        NewHead = unknown_template(Head, Start, End), 
        parse_body(BodyTokens, Indent, Templates, [], _VMOut7, NewBody)
    ).
second_pass_scenario_item(Templates, fact(Head, Start, End), clause(NewHead, NewBody, Start, End, _ID), M) :-
    % Scenario facts parse with the 'indefinite' policy: an indefinite determiner
    % ("a damage", "a burst pipe") introduces a typed variable, while a definite
    % phrase ("the repair cost") stays a concrete individual. The resulting
    % variables are constrained by a TypesRestriction body so the fact only
    % applies to arguments of the proper type.
    ( parse_literal(Head, Templates, [], VMOut8, NewHead, HeadInst, indefinite) ->
        maybe_record_synonym_use(M, Templates, NewHead, HeadInst, Start, End),
        collect_extra_goals(VMOut8, ExtraGoals),
        build_type_restriction(NewHead, Templates, TypeRestriction),
        ( TypeRestriction == true -> Goals = ExtraGoals ; append(ExtraGoals, [TypeRestriction], Goals) ),
        ( Goals == [] -> NewBody = true ; list_to_conj(Goals, NewBody) )
        ; NewHead = unknown_template(Head, Start, End), NewBody = true).

%!  build_type_restriction(+Literal, +Templates, -Restriction) is det.
%
%   Builds a TypesRestriction goal that constrains every variable argument of
%   Literal to its declared type (from the matching template). Constant
%   arguments and arguments typed 'any' impose no restriction. When no
%   restriction is needed the Restriction is 'true'. Variables are checked
%   with le_type_check/2, which the reasoner evaluates lazily (it only fires
%   once the argument is bound), mirroring check_args_compatibility/6.
build_type_restriction(Literal, Templates, Restriction) :-
    ( literal_arg_types(Literal, Templates, ArgTypes) ->
        % Do not use findall/3 here: it would copy the terms and detach the
        % type checks from the actual head variables they must constrain.
        type_checks(ArgTypes, Checks)
    ; Checks = [] ),
    list_to_conj(Checks, Restriction).

type_checks([], []).
type_checks([Arg-Type | Rest], Checks) :-
    ( var(Arg), Type \== any ->
        Checks = [le_type_check(Arg, Type) | Checks0]
    ; Checks = Checks0
    ),
    type_checks(Rest, Checks0).

%!  literal_arg_types(+Literal, +Templates, -ArgTypes) is semidet.
%
%   Pairs each argument of Literal with its declared type, by positionally
%   matching against the template whose functor/arity match Literal.
literal_arg_types(Literal, Templates, ArgTypes) :-
    compound(Literal),
    functor(Literal, F, A),
    Literal =.. [F | Args],
    member(dict([F | FormalArgs], NTs, _, _, _, _, _, _, _, _), Templates),
    length(FormalArgs, A),
    !,
    maplist(arg_type(NTs), Args, FormalArgs, ArgTypes).

arg_type(NTs, Arg, FormalArg, Arg-Type) :-
    ( member(K-T, NTs), K == FormalArg -> Type = T ; Type = any ).

% A scenario fact with an image addition: compile as a plain scenario fact,
% then validate and record the image (see record_fact_image/7).
second_pass_scenario_item(Templates, fact_image(Head, URL, UStart, UEnd, Start, End), NewItem, M) :-
    second_pass_scenario_item(Templates, fact(Head, Start, End), NewItem, M),
    record_fact_image(M, NewItem, URL, UStart, UEnd, Start, End).

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

second_pass_query_item(Templates, query_raw(BodyTokens, Start, End), Item, _M) :-
    !,
    (   parse_query_body(BodyTokens, Templates, BodyGoal)
    ->  % A multi-condition query (and / or / not / for all cases), parsed like a
        % rule body. Rendered from its goal (with bindings) when showing answers.
        Item = query_body(BodyGoal, BodyTokens, Start, End)
    ;   query_literal_tokens(BodyTokens, LiteralTokens),
        parse_literal(LiteralTokens, Templates, [], VMOut9, NewHead0, Instance, true)
    ->  collect_extra_goals(VMOut9, ExtraGoals0),
        order_extra_goals_by_source(ExtraGoals0, ExtraGoals),
        query_chain_goal(ExtraGoals, NewHead0, NewHead),
        Item = query_clause(NewHead, LiteralTokens, Instance, Start, End)
    ;   Item = query_clause(unknown_template(BodyTokens, Start, End), BodyTokens, BodyTokens, Start, End)
    ).

% query_literal_tokens(+BodyTokens, -LiteralTokens): a single-literal query's body
% tokens reparsed as a template instance, so an explicit *variable* becomes a var
% token (as in rule heads and the previous query path) rather than the literal text
% "*the id*". Falls back to the raw (indent/comment-free) tokens if that fails.
query_literal_tokens(BodyTokens, LiteralTokens) :-
    exclude(is_indent_or_comment, BodyTokens, Flat),
    ( phrase(template_instance(LiteralTokens), Flat) -> true ; LiteralTokens = Flat ).
second_pass_query_item(Templates, fact(Head, Start, End), Item, _M) :-
    (   parse_query_body(Head, Templates, BodyGoal)
    ->  Item = query_body(BodyGoal, Head, Start, End)
    ;   parse_literal(Head, Templates, [], VMOut9, NewHead0, Instance, true)
    ->  collect_extra_goals(VMOut9, ExtraGoals0),
        order_extra_goals_by_source(ExtraGoals0, ExtraGoals),
        query_chain_goal(ExtraGoals, NewHead0, NewHead),
        Item = query_clause(NewHead, Head, Instance, Start, End)
    ;   Item = query_clause(unknown_template(Head, Start, End), Head, Head, Start, End)
    ).

% parse_query_body(+Tokens, +Templates, -Goal): succeeds only when the query is a
% multi-condition body — connected with and / or / not the case that / for all
% cases — parsing it exactly as a rule body would. A single template instance
% (the common case) does NOT match here and keeps its query_clause rendering,
% which preserves the exact instance tokens for the answer. parse_body handles the
% multi-line form; parse_inline_body the single-line "a and b" form.
parse_query_body(Tokens, Templates, Goal) :-
    % A single complete template instance takes priority over a connective-based
    % reading. Templates may legitimately contain words like "for", "or", "and"
    % and "under" (e.g. "*an amount* for all relevant claims or losses covered
    % under *a section* ..."); without this guard parse_body would mistake those
    % words for a for/or/under body structure and split the template apart.
    \+ single_template_query(Tokens, Templates),
    % Baseline indent = that of the body's continuation lines (the first indent
    % token), mirroring the N a rule passes to parse_body — needed so that, e.g.,
    % the goal under "it is not the case that" nests correctly.
    ( member(indent(BaseIndent, _), Tokens) -> true ; BaseIndent = 0 ),
    % Mark this as query parsing so a prepositional chain folds constraints-first
    % (parse_node/6), binding shared variables before the main verb is proven.
    setup_call_cleanup(
        assertz(in_query_body_parse),
        (   catch(parse_body(Tokens, BaseIndent, Templates, [], _, G), _, fail), has_query_connective(G)
        ->  Goal = G
        ;   catch(parse_inline_body(Tokens, Templates, [], _, G2), _, fail), has_query_connective(G2)
        ->  Goal = G2
        ),
        retractall(in_query_body_parse)).

% single_template_query(+Tokens, +Templates): the query body, taken whole, is a
% single instance of ONE defined template (matched directly, without prepositional
% chaining). Used to veto connective parsing so a template whose fixed words happen
% to include connective-like words ("for", "or", "under", ...) is not torn apart.
%
% Only a *direct* single-template match qualifies: a chained match (a main template
% plus one or more prepositional phrases, e.g. "we will make X under Y in respect of
% Z") must keep the connective/body path so its prepositional goals are captured and
% folded — it is not a single template.
single_template_query(Tokens, Templates) :-
    query_literal_tokens(Tokens, LiteralTokens),
    exclude(is_indent_or_comment, LiteralTokens, CleanTokens),
    % Reject a prepositional chain (a main template plus one or more prepositional
    % phrases): match_template_with_chaining only succeeds when such a chain exists,
    % and those chains must stay on the connective/body path so their prepositional
    % goals are folded into the rendered answer.
    \+ catch(match_template_with_chaining(CleanTokens, Templates, [], _, _, _, true, 0), _, fail),
    maplist(extract_simple_word, CleanTokens, Words),
    % Some ONE template matches the whole body directly, and the body contains no
    % genuine body-level connective (and / or / "it is not the case that" / "for all
    % cases ...") that the template does not itself carry as fixed words. A free
    % connective means the single-template match could only succeed by swallowing it
    % into a variable — the query is really a multi-condition body, so leave it alone.
    member(dict(FunctorArgs, _NTs, WordsAndVars, _S, _E, NIW, _G, _O, _P, _U), Templates),
    \+ (FunctorArgs = [le_is|_]),
    contains_subsequence(NIW, Words),
    % The template's fixed words are the non-variable atoms of its pattern (NIW drops
    % "ignorable" words like "and"/"or", so it can't tell a fixed "or" from a
    % connective one — WordsAndVars keeps them).
    include(atom, WordsAndVars, FixedWords),
    \+ body_has_free_connective(Words, FixedWords),
    copy_term(WordsAndVars, WordsAndVarsCopy),
    catch(match_instance_to_template(CleanTokens, WordsAndVarsCopy, [], _, Templates, true, 0), _, fail),
    !.

% body_has_free_connective(+Words, +FixedWords): the body word list contains a
% body-level connective keyword/phrase that is NOT among the matched template's fixed
% words. Such a connective would have to be captured inside a template variable for a
% single-template match to succeed, which means the query is a genuine multi-
% condition body (and / or / negation / for-all) rather than one template instance.
body_has_free_connective(Words, FixedWords) :-
    (   member(W, Words), le_i18n:class_member(and, W), \+ memberchk(W, FixedWords)
    ;   member(W, Words), le_i18n:class_member(or, W), \+ memberchk(W, FixedWords)
    ;   member(W, Words), le_i18n:class_member(unless, W), \+ memberchk(W, FixedWords)
    ;   naf_marker_subseq(Sub), contig_subseq(Sub, Words), \+ contig_subseq(Sub, FixedWords)
    ;   forall_marker_subseq(Sub), contig_subseq(Sub, Words), \+ contig_subseq(Sub, FixedWords)
    ), !.

% The distinctive inner words of a negation phrase (English: [not, the, case]
% from "it is not the case that") — each synonym minus a leading pronoun+copula
% and the trailing meta marker, falling back to the whole phrase when short.
naf_marker_subseq(Sub) :-
    le_i18n:kw_synonym_words(not_the_case, Words),
    marker_core(Words, Sub).

% The distinctive prefix of a for-all phrase (English: [for, all, cases]).
forall_marker_subseq(Sub) :-
    le_i18n:kw_synonym_words(forall, Words),
    ( length(Sub, 3), append(Sub, _, Words) -> true ; Sub = Words ).

marker_core(Words, Core) :-
    length(Words, L),
    (   L =< 3 -> Core = Words
    ;   append(Core0, [Last], Words),
        ( le_i18n:class_member(meta_marker, Last) -> ToTrim = Core0 ; ToTrim = Words ),
        length(ToTrim, TL),
        ( TL > 3 -> N is TL - 3, length(Drop, N), append(Drop, Core, ToTrim) ; Core = ToTrim )
    ).

% contig_subseq(+Sub, +List): Sub occurs as a contiguous block within List.
contig_subseq(Sub, List) :- append(_, Tail, List), append(Sub, _, Tail), !.

has_query_connective(le_at(G, _, _)) :- !, has_query_connective(G).
has_query_connective(and(_, _)).
has_query_connective((_ , _)).
has_query_connective(or(_, _)).
has_query_connective((_ ; _)).
has_query_connective(not(_)).
has_query_connective(forall(_, _)).

second_pass_query_item(Templates, rule(Head, BodyTokens, Indent, Start, End, ID), query_clause(NewHead, Head, BodyTokens, Instance, Indent, Start, End, ActualID), _M) :-
    (var(ID) -> format(atom(ActualID), 'rule_~w', [Start]) ; ActualID = ID),
    ( parse_literal(Head, Templates, [], VM1, NewHead0, Instance, true) -> 
        parse_body(BodyTokens, Indent, Templates, VM1, VMOut10, Body0),
        collect_extra_goals(VMOut10, ExtraGoals),
        ( ExtraGoals == [] -> NewHead = and(NewHead0, Body0) ; append([NewHead0 | ExtraGoals], [Body0], AllGoals), list_to_conj(AllGoals, NewHead) )
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
        le_i18n:kw_synonym_words(is_a, IsAWords),
        append(TypeWords, Tail, Words),
        append(IsAWords, SuperTypeWords, Tail)
    )),
    TypeWords \== [], SuperTypeWords \== [],
    % Find the corresponding tokens for TypeWords and SuperTypeWords: the word
    % list is elementwise-derived from Parts, so the split positions coincide.
    length(TypeWords, TL), length(TypeTokens, TL),
    length(IsAWords, IL), length(MidTokens, IL),
    append(TypeTokens, MidPlus, Parts),
    append(MidTokens, SuperTypeTokens, MidPlus),
    !,
    extract_value_from_parts(TypeTokens, Type, VMIn, VM1, [], false, AllowVars, 0),
    extract_name_type(TypeWords, TypeAtom, _),
    extract_name_type(SuperTypeWords, SuperTypeAtom, _),
    % The supertype after "is a" is the named type itself (a constant), UNLESS it
    % is written as an explicit variable reference — "... is a the type", "... is
    % a which other thing", an all-caps id, etc. (anything extract_var_name/2
    % recognises). A bare type word must NOT co-refer with a same-named variable
    % already in scope: "the dragon is a dragon" is is_a(Dragon, dragon), not
    % is_a(Dragon, Dragon).
    ( extract_var_name(SuperTypeWords, _) ->
        extract_value_from_parts(SuperTypeTokens, SuperType, VM1, VMOut, [], false, AllowVars, 0)
    ;   SuperType = SuperTypeAtom, VMOut = VM1
    ).

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

%!  maybe_record_synonym_use(+Templates, +Literal, +Instance, +Start, +End) is det.
%
%   If the goal Literal was written (at source range Start-End) with a SYNONYM
%   surface form rather than its main template, record it so explanations can later
%   render the goal with the form actually written. Instance is the matched
%   template's words with this goal's argument variables in place; comparing its
%   word skeleton (arg positions blanked to '$v') against the main template's tells
%   us whether a synonym was used. A no-op when the main form was used, when there
%   are no alternative forms, or when not compiling a KB module.
maybe_record_synonym_use(Templates, Literal, Instance, Start, End) :-
    ( le_kbs:current_compiling_module(M), M \== (-), nonvar(M) -> true ; M = (-) ),
    maybe_record_synonym_use(M, Templates, Literal, Instance, Start, End).

% Explicit-module variant, for the (later) scenario second pass where the current
% compiling module is no longer set but the target module is passed in.
maybe_record_synonym_use(M, Templates, Literal, Instance, Start, End) :-
    (   nonvar(M), M \== (-),
        nonvar(Literal), is_list(Instance),
        functor(Literal, F, A),
        primary_template_wv(Templates, F, A, PrimaryWV),
        wv_skeleton_with_args(Instance, Literal, InstanceSkel),
        wv_skeleton(PrimaryWV, PrimarySkel),
        InstanceSkel \== PrimarySkel
    ->  ( M:le_synonym_at(Start, End, InstanceSkel) -> true
        ; assertz(M:le_synonym_at(Start, End, InstanceSkel)) )
    ;   true
    ).

% The MAIN template's WordsAndVars for predicate F/A, from the in-memory template
% list. A synonym dict shares the main's FunctorArgs but keeps the synonym's own
% words, so the main is the dict whose OWN words derive the functor F (default
% rendering, item_to_instance, likewise uses this first/main dict).
primary_template_wv(Templates, F, A, WV) :-
    once(( member(Dict, Templates),
           dict_fa_wv(Dict, [F|Args], WV0),
           length(Args, A),
           wv_functor(WV0, F) )),
    WV = WV0.

dict_fa_wv(dict(FA, _, WV, _, _, _, _, _, _, _), FA, WV) :- !.
dict_fa_wv(dict(FA, _, WV, _, _, _, _, _, _), FA, WV) :- !.
dict_fa_wv(dict(FA, _, WV, _, _, _, _), FA, WV) :- !.
dict_fa_wv(dict(FA, _, WV), FA, WV).

% wv_functor(+WordsAndVars, -Functor): the functor derived from the literal words
% (the atoms), joined with '_' — matching extract_functor/2 over the template.
wv_functor(WV, Functor) :-
    include(atom, WV, Words),
    Words \== [],
    atomic_list_concat(Words, '_', Functor).

% wv_skeleton(+WordsAndVars, -Skeleton): each variable becomes '$v', each atom is
% kept, so two surface forms compare equal iff they share the same words in the
% same layout.
wv_skeleton([], []).
wv_skeleton([X|Xs], [S|Ss]) :- ( var(X) -> S = '$v' ; S = X ), wv_skeleton(Xs, Ss).

% Like wv_skeleton but for a matched Instance whose argument slots hold Literal's
% arguments (possibly bound to constants): those positions are blanked to '$v' too.
wv_skeleton_with_args(Instance, Literal, Skel) :-
    Literal =.. [_|Args],
    maplist(skeleton_elem(Args), Instance, Skel).

skeleton_elem(Args, X, '$v') :- ( var(X) ; member_eq(X, Args) ), !.
skeleton_elem(_, X, X).

member_eq(X, [Y|_]) :- X == Y, !.
member_eq(X, [_|Ys]) :- member_eq(X, Ys).

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
        % Meta templates first (see candidate_template/3): a 'that'-marked slot
        % must be the outer literal, not get absorbed into another template's slot.
        candidate_template(Templates, Words, dict(FunctorArgs, _NTs, WordsAndVars, _Start, _End, _NIW, _Globals, _Opposite, _Prep, _Unknown)),
        \+ (FunctorArgs = [le_is|_]),
        copy_term(dict(FunctorArgs, WordsAndVars), dict(FunctorArgsCopy, WordsAndVarsCopy)),
        match_instance_to_template(Tokens, WordsAndVarsCopy, VMIn, VMOut0, Templates, AllowVars, 0),
        Literal =.. FunctorArgsCopy,
        Instance = WordsAndVarsCopy,
        ( post_parse_literal_hook(WordsAndVarsCopy, Literal, VMOut0, VMOut) -> true ; VMOut = VMOut0 ) -> true
        ;
        match_is_a(Tokens, Type, SuperType, VMIn, VMOut, AllowVars) ->
        Literal = is_a(Type, SuperType),
        ( le_i18n:kw_main_words(is_a, IsAWords) -> true ; IsAWords = [is, a] ),
        append([Type|IsAWords], [SuperType], Instance)
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
    % Optimization: only try parsing as expression if it looks like one — it
    % contains an arithmetic operator, or a known arithmetic function (so a bare
    % "ceiling(...)" without a surrounding operator is still recognised).
    (   (   member(Part, Parts), (Part = punct(Op, _) ; Part = punctuation(Op, _)), member(Op, ['+', '-', '*', '/', '(', ')', '=', '>', '<', '>=', '<=', '=<', '==', '!='])
        ;   member(FPart, Parts), (FPart = word(Fn, _) ; FPart = word(Fn)), is_arith_function(Fn)
        ) ->
            exclude(is_indent_or_comment, Parts, CleanParts),
            maplist(part_to_token, CleanParts, Tokens),
            phrase(expr_logic(Expr, VMIn, VMOut, Templates, AllowVars), Tokens)
        ; fail
    ).

% Unary arithmetic functions that may appear in an expression, applied to a
% parenthesised argument, e.g. "ceiling(the amount / a multiple)". They are
% evaluated by Prolog's is/2 at solve time (see le_is in the reasoner).
is_arith_function(ceiling).
is_arith_function(floor).
is_arith_function(round).
is_arith_function(truncate).
is_arith_function(integer).
is_arith_function(abs).
is_arith_function(sign).
is_arith_function(sqrt).

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
% Unary function application: a function name followed by its parenthesised
% argument, which is either a pre-grouped expr(...) token or explicit "( ... )".
factor_logic(F, VMIn, VMOut, Ts, AllowVars) -->
    [word(Fn, _)], { is_arith_function(Fn) },
    function_arg(Arg, VMIn, VMOut, Ts, AllowVars),
    { F =.. [Fn, Arg] }.
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

% function_arg(Arg, ...) parses the parenthesised argument of a unary function,
% accepting either a pre-grouped expr(...) token or explicit "( ... )".
function_arg(Arg, VMIn, VMOut, Ts, AllowVars) -->
    [expr(E)], !, { parse_expression(E, VMIn, VMOut, Ts, Arg, AllowVars) }.
function_arg(Arg, VMIn, VMOut, Ts, AllowVars) -->
    [punctuation('(', _)], expr_logic(Arg, VMIn, VMOut, Ts, AllowVars), [punctuation(')', _)].

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

%!  parse_inline_body(+Tokens, +Templates, +VMIn, -VMOut, -Logic) is semidet.
%
%   Parse a flat (single-line) token sequence that may contain top-level inline
%   'and'/'or' connectives, building the corresponding conjunction/disjunction.
%   With no top-level connective it is a single literal (unchanged behaviour).
%   Used e.g. for the part after 'unless' on one line, so
%   "... unless the policy is cancelled and it rains a lot" yields
%   not(and(is_cancelled, it_rains_a_lot)) rather than swallowing the conjunct.
parse_inline_body(Tokens, Templates, VMIn, VMOut, Logic) :-
    inline_segments(Tokens, Segments),
    (   Segments = [_]                                   % no top-level connective
    ->  parse_literal(Tokens, Templates, VMIn, VMOut, Logic, _)
    ;   all_segments_parse(Segments, Templates)          % each conjunct is a valid literal
    ->  maplist(inline_seg_to_line, Segments, Lines),
        lines_to_hierarchy(Lines, Hierarchy),
        hierarchy_to_logic(Hierarchy, Templates, VMIn, VMOut, Logic)
    ;   % An 'and'/'or' that is part of a template (e.g. "*a payment* and *a
        % claim* are admissible ...") — keep the whole thing as one literal.
        parse_literal(Tokens, Templates, VMIn, VMOut, Logic, _)
    ).

%!  parse_inline_connective(+Tokens, +Templates, +VMIn, -VMOut, -Logic) is semidet.
%
%   Parse a single line that contains at least one top-level inline 'and'/'or'
%   connective into the corresponding conjunction/disjunction. Each segment
%   (minus its connective) must parse as a literal on its own; otherwise this
%   fails so the caller can keep the whole line as a single literal (e.g. a
%   template that legitimately contains 'and'). Used by parse_node so that
%   "p if q and r." parses like the multi-line form.
parse_inline_connective(Tokens, Templates, VMIn, VMOut, Logic) :-
    inline_segments(Tokens, Segments),
    Segments = [_, _|_],                       % at least one top-level connective
    all_segments_parse(Segments, Templates),
    maplist(inline_seg_to_line, Segments, Lines),
    lines_to_hierarchy(Lines, Hierarchy),
    hierarchy_to_logic(Hierarchy, Templates, VMIn, VMOut, Logic).

inline_seg_to_line(Seg, line(0, Seg)).

% Every segment (minus its leading and/or) must parse as a literal on its own,
% otherwise the connective is not a top-level conjunction. Checked without
% keeping any bindings (\+ \+ ...).
all_segments_parse([], _).
all_segments_parse([Seg|Segs], Templates) :-
    strip_leading_op(Seg, _Op, Body),
    Body \== [],
    (   \+ \+ parse_literal(Body, Templates, [], _, _, _)
    ;   inline_naf_goal(Body, GoalTokens), \+ \+ parse_literal(GoalTokens, Templates, [], _, _, _)
    ),
    all_segments_parse(Segs, Templates).

% Split a token list into segments at every top-level 'and'/'or'; each segment
% after the first begins with its connective word (so strip_op/3 can read it).
inline_segments([], []).
inline_segments([T|Ts], [[T|Seg]|Segs]) :-
    take_until_connective(Ts, Seg, Rest),
    inline_segments(Rest, Segs).

take_until_connective([], [], []).
take_until_connective([word(W, L)|Ts], [], [word(W, L)|Ts]) :-
    ( le_i18n:class_member(and, W) ; le_i18n:class_member(or, W) ), !.
take_until_connective([T|Ts], [T|Seg], Rest) :- take_until_connective(Ts, Seg, Rest).

tokens_to_lines(Tokens, DefaultIndent, Lines) :-
    tokens_to_lines_acc(Tokens, DefaultIndent, [], Lines).

tokens_to_lines_acc([], _, Acc, Lines) :- reverse(Acc, Lines).
tokens_to_lines_acc([indent(N, _)|Ts], DefaultIndent, Acc, Lines) :- !,
    get_line_tokens(Ts, LineTokens, Rest),
    (   LineTokens == [] -> tokens_to_lines_acc(Rest, DefaultIndent, Acc, Lines)
        ;
        LineTokens = [word(That, _)|_], le_i18n:class_member(that, That),
        Acc = [line(PrevN, PrevTokens)|RestAcc] ->
        append(PrevTokens, LineTokens, NewPrevTokens),
        tokens_to_lines_acc(Rest, DefaultIndent, [line(PrevN, NewPrevTokens)|RestAcc], Lines)
        ;
        tokens_to_lines_acc(Rest, DefaultIndent, [line(N, LineTokens)|Acc], Lines)
    ).
tokens_to_lines_acc(Ts, DefaultIndent, Acc, Lines) :-
    get_line_tokens(Ts, LineTokens, Rest),
    (   LineTokens == [] -> tokens_to_lines_acc(Rest, DefaultIndent, Acc, Lines)
        ;
        LineTokens = [word(That, _)|_], le_i18n:class_member(that, That),
        Acc = [line(PrevN, PrevTokens)|RestAcc] ->
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

% The "chain anchor" is the indentation of the FIRST line at a given sibling
% level. A META CONNECTIVE (a line ending in "that", such as "it is not the case
% that") that is written at a SHALLOWER indent than the anchor — outdented to
% column 0 while the surrounding conjuncts sit at column 4, with its own argument
% nested deeper still — is misindented: its children must be captured relative to
% the chain level, not its own lower column, so a following conjunct that RETURNS
% to the chain level stays a sibling rather than being swallowed as the
% connective's second argument (hiscoxhappypath.le's "... fulfills all the
% general conditions"). The gate on ends_with_that/1 keeps ordinary and/or
% branches untouched: a shallower "or" alternative followed by its own deeper
% "and" conjunct (tax/gst.le) must still nest that conjunct under itself.
lines_to_hierarchy(Lines, Nodes) :-
    ( Lines = [line(Anchor, _)|_] -> true ; Anchor = 0 ),
    lines_to_hierarchy_(Lines, Anchor, Nodes).

lines_to_hierarchy_([], _, []).
lines_to_hierarchy_([line(N, Tokens)|Lines], Anchor, [node(N, Tokens, Children)|RestNodes]) :-
    ( N < Anchor, ends_with_that(Tokens) -> Threshold = Anchor ; Threshold = N ),
    take_nested_hierarchy(Lines, Threshold, Nested0, Remaining00),
    % If the deepest trailing line of this node's subtree is itself a dangling
    % meta connective ("... that" with no argument nested under it) whose
    % argument was written at a SHALLOWER indentation as a following sibling
    % (inconsistent indentation we tolerate — e.g. the connective indented more
    % deeply than the conjunct before it while its argument sits at column 0),
    % pull that following block into the subtree so the connective can absorb it
    % as its child rather than being left with an empty (true) scope.
    absorb_trailing_dangling_that(Nested0, Remaining00, Nested, Remaining0),
    (   Nested == [],
        ends_with_that(Tokens),
        Remaining0 = [line(M, NextTokens)|AfterNext]
    ->  % A dangling meta connective ("... that" with nothing after it on the
        % line — e.g. "it is not the case that") whose scope was written at the
        % same indentation instead of nested underneath. Absorb the next sibling
        % line (together with its own deeper-nested subtree) as this node's
        % child, so the connective applies to it.
        take_nested_hierarchy(AfterNext, M, NextNested, Remaining),
        ChildLines = [line(M, NextTokens)|NextNested]
    ;   ChildLines = Nested, Remaining = Remaining0
    ),
    lines_to_hierarchy(ChildLines, Children),
    % format('Node ~w has ~w children~n', [Tokens, Children]),
    lines_to_hierarchy_(Remaining, Anchor, RestNodes).

%!  absorb_trailing_dangling_that(+Nested0, +Remaining0, -Nested, -Remaining) is det.
%
%   When the last line of a node's nested subtree is a dangling "... that"
%   connective with no argument of its own, move the first following sibling
%   block (the line plus its deeper-nested subtree) from Remaining0 into the
%   nested subtree. The subsequent recursion then attaches it as the
%   connective's child via the same-indentation absorption above.
absorb_trailing_dangling_that(Nested0, Remaining0, Nested, Remaining) :-
    Nested0 \== [],
    last(Nested0, line(_, LastTokens)),
    ends_with_that(LastTokens),
    Remaining0 = [line(M, MTokens)|AfterNext], !,
    take_nested_hierarchy(AfterNext, M, ArgNested, Remaining),
    append(Nested0, [line(M, MTokens)|ArgNested], Nested).
absorb_trailing_dangling_that(Nested, Remaining, Nested, Remaining).

%!  ends_with_that(+Tokens) is semidet.
%
%   True when the line's last meaningful token is the word "that" — i.e. a meta
%   connective (such as "it is not the case that") that expects a following
%   clause as its argument.
ends_with_that(Tokens) :-
    drop_trailing_comments(Tokens, Stripped),
    Stripped \== [],
    last(Stripped, word(That, _)),
    le_i18n:class_member(that, That).

take_nested_hierarchy([line(M, Tokens)|Lines], N, [line(M, Tokens)|Nested], Remaining) :-
    M > N, !,
    take_nested_hierarchy(Lines, N, Nested, Remaining).
take_nested_hierarchy(Lines, _, [], Lines).

hierarchy_to_logic([], _, VM, VM, true) :- !.
hierarchy_to_logic(Nodes0, Templates, VMIn, VMOut, Logic) :-
    adopt_orphan_forall_markers(Nodes0, [node(_, Tokens, Children)|RestNodes]),
    strip_op(Tokens, _Op, RestTokens),
    parse_node(RestTokens, Children, Templates, VMIn, VM1, FirstLogic),
    fold_nodes(FirstLogic, RestNodes, Templates, VM1, VMOut, Logic).

%!  adopt_orphan_forall_markers(+Nodes:list, -Nodes1:list) is det.
%
%   Re-parents an "it is the case that" marker that indentation stranded as a
%   SIBLING of its forall instead of a child of it.
%
%   A forall written on the same line as `if` — "... if for all cases in which"
%   — takes the indentation of the `if`, so a marker written at that same
%   indentation becomes the forall's sibling. split_forall_children/3 then finds
%   no marker anywhere in the subtree, the forall silently gets `true` for its
%   consequent, and the marker line goes on to parse as a literal of its own
%   (the generic "*X* is *Y*" fallback: le_is(it, 'the case that')). The rule
%   compiles without complaint and means something quite different from what it
%   says.
%
%   Nothing but a preceding forall can own that marker, so adopt it. When the
%   marker carries its consequent as its own children, only the marker moves;
%   when it does not, the consequent is whatever follows, so the rest of the
%   siblings move with it — matching what split_forall_children_direct/3 already
%   does for a marker that IS a direct child.
adopt_orphan_forall_markers([], []).
adopt_orphan_forall_markers([node(Id, Tokens, Children), Marker | Rest], [node(Id, Tokens, Children1) | Rest1]) :-
    node_is_forall(Tokens),
    \+ subtree_has_marker(Children),
    Marker = node(_, MTokens, MChildren),
    node_is_marker(MTokens),
    !,
    (   MChildren == []
    ->  append(Children, [Marker | Rest], Children1), Rest1 = []
    ;   append(Children, [Marker], Children1),
        adopt_orphan_forall_markers(Rest, Rest1)
    ).
adopt_orphan_forall_markers([Node | Rest], [Node | Rest1]) :-
    adopt_orphan_forall_markers(Rest, Rest1).

% The node-level tests carry the leading connective ('if'/'and'/'or') that
% parse_node strips, so strip it here too before matching the keyword.
node_is_forall(Tokens) :- strip_op(Tokens, _, T), is_forall(T).
node_is_marker(Tokens) :- strip_op(Tokens, _, T), is_it_the_case(T).

subtree_has_marker(Nodes) :-
    member(node(_, Tokens, Children), Nodes),
    ( node_is_marker(Tokens) -> true ; subtree_has_marker(Children) ),
    !.

fold_nodes(Acc, [], _, VM, VM, Acc).
fold_nodes(Acc, [node(_, Tokens, Children)|Rest], Templates, VMIn, VMOut, Logic) :-
    strip_op(Tokens, Op, RestTokens),
    parse_node(RestTokens, Children, Templates, VMIn, VM1, ChildLogic),
    NewAcc =.. [Op, Acc, ChildLogic],
    fold_nodes(NewAcc, Rest, Templates, VM1, VMOut, Logic).

strip_op(Tokens, Op, RestTokens) :-
    strip_leading_op(Tokens, Op, Tokens1),
    strip_trailing_conjunction(Tokens1, RestTokens).

strip_leading_op([word(W, _)|Rest], Op, Rest) :-
    (   le_i18n:class_member(if, W) -> Op = and
    ;   le_i18n:class_member(and, W) -> Op = and
    ;   le_i18n:class_member(or, W) -> Op = or
    ), !.
strip_leading_op(Tokens, and, Tokens).

% Strip a trailing "and" or "or" used as a line continuation marker. Don't strip
% if the line is just the connective alone. Trailing comments are also dropped.
strip_trailing_conjunction(Tokens, Stripped) :-
    drop_trailing_comments(Tokens, Tokens1),
    Tokens1 \== [],
    last(Tokens1, word(W, _)),
    ( le_i18n:class_member(and, W) ; le_i18n:class_member(or, W) ),
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
        ; ( Children == [], inline_naf_goal(Tokens, GoalTokens) ) ->
            % Inline negation: "it is not the case that <goal>" all on one line.
            % Unambiguous because the negation has a single condition (the rest of
            % the line), so the goal need not be on a nested line.
            parse_literal(GoalTokens, Templates, VMIn, VMOut, GoalLit, NafInstance),
            tokens_range(GoalTokens, GStart, GEnd),
            maybe_record_synonym_use(Templates, GoalLit, NafInstance, GStart, GEnd),
            Logic0 = not(le_at(GoalLit, GStart, GEnd)),
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
        ; parse_literal(Tokens, Templates, VMIn, VM1, Literal, LitInstance) ->
            collect_literal_extra_goals(VM1, VMIn, LiteralExtraGoals),
            % A global ("defines global") abbreviation contributes a goal that
            % BINDS the global's variable, so it must run immediately BEFORE the
            % literal that uses it. Prepositional extra goals instead further
            % constrain a variable the literal itself introduces, so they stay
            % AFTER it (preserving the previous behaviour for them).
            partition(is_global_extra_goal(Templates), LiteralExtraGoals, GlobalGoals, OtherGoals),
            (   in_query_body_parse
            ->  % In a QUERY, the prepositional constraints run BEFORE the main
                % literal, so they bind the shared variables (e.g. the claim in
                % "we will make X in respect of THIS claim") before the main
                % predicate is proven — otherwise it picks an unrelated witness for
                % them, polluting the failure explanation.
                append(GlobalGoals, OtherGoals, PreGoals),
                append(PreGoals, [Literal], OrderedGoals)
            ;   append(GlobalGoals, [Literal | OtherGoals], OrderedGoals)
            ),
            (   OrderedGoals = [SingleGoal] -> Logic0 = SingleGoal
            ;   list_to_conj(OrderedGoals, Logic0)
            ),
            length(LiteralExtraGoals, NumNew),
            remove_leading_extra_goals(VM1, NumNew, VM2),
            fold_nodes(Logic0, Children, Templates, VM2, VMOut, Logic1),
            ( (Tokens \== [], tokens_range(Tokens, Start, End)) ->
                  maybe_record_synonym_use(Templates, Literal, LitInstance, Start, End),
                  Logic = le_at(Logic1, Start, End)
              ;   Logic = Logic1 )
        ; Children == [], parse_inline_connective(Tokens, Templates, VMIn, VMOut, Logic0) ->
            % A single-line body with top-level inline 'and'/'or' connectives,
            % e.g. "p if q and r." — split into conjuncts/disjuncts.
            tokens_range(Tokens, Start, End),
            Logic = le_at(Logic0, Start, End)
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


% is_aggregate(+Tokens, -Op, -ElementTokens, -ResultTokens): matches
% "<result> is the <op> of each <element> such that" (with each phrase piece —
% "is the", the operator word, "of each", "such that" — coming from the
% aggregate lexicon keys). Op is the CANONICAL operator (sum/count/average/
% min/max — the reasoner's functor), whatever the surface language.
is_aggregate(Tokens, Op, ElementTokens, ResultTokens) :-
    Tokens = [_, _, _, _, _, _, _, _ | _],
    % Cheap guard (this runs on every body line): the line must END with the
    % last word of a "such that" phrase.
    last(Tokens, LastTok),
    extract_simple_word(LastTok, LastW),
    le_i18n:kw_synonym_words(such_that, SuchThat),
    last(SuchThat, LastW),
    length(SuchThat, SK), length(SuchTokens, SK),
    append(Rest, SuchTokens, Tokens),
    tokens_match_words(SuchTokens, SuchThat),
    member(Op, [sum, count, average, min, max]),
    le_i18n:kw_synonym_words(Op, OpWords),
    le_i18n:kw_synonym_words(is_the, IsThe),
    le_i18n:kw_synonym_words(of_each, OfEach),
    append([IsThe, OpWords, OfEach], MidWords),
    length(MidWords, ML), length(MidTokens, ML),
    append(ResultTokens, MidPlus, Rest),
    append(MidTokens, ElementTokens, MidPlus),
    tokens_match_words(MidTokens, MidWords),
    !.

build_aggregate_list(Tokens, VMIn, VMOut, List) :-
    ( Tokens = [word(W, _)|Rest], le_i18n:class_member(and, W) -> TokensToUse = Rest; TokensToUse = Tokens),
    maplist(extract_simple_word, TokensToUse, Words),
    (   extract_var_name(Words, Name) -> true
    ;   extract_id(Words, Name) -> true
    ;   atomic_list_concat(Words, ' ', Name)
    ),
    unify_with_vmap(Name, Var, VMIn, VMOut, true),
    List = [var(Name, Var)].

is_forall(Tokens) :-
    maplist(extract_word_atom, Tokens, Atoms0),
    optional_leading_and(Atoms0, Atoms),
    kw_words_eq(forall, Atoms).

% optional_leading_and(+Atoms0, -Atoms): strips a leading 'and' connective
% (in the active language) when present; also yields the untouched list.
optional_leading_and(Atoms, Atoms).
optional_leading_and([W|Rest], Rest) :- le_i18n:class_member(and, W).

% Split the children of a "for all cases in which" node into the condition
% nodes and the consequence nodes, divided by the "it is the case that" marker.
split_forall_children(Children, CondNodes, ConsNodes) :-
    (   has_direct_marker(Children)
    ->  split_forall_children_direct(Children, CondNodes, ConsNodes)
    ;   % The "it is the case that" marker is not a direct child of the forall.
        % This happens with inconsistent indentation (e.g. tabs mixed with
        % spaces): when the marker line is indented more deeply than its
        % condition, the hierarchy builder nests the marker and the
        % consequences under the last condition instead of as siblings of it.
        % Recover by flattening the forall subtree into document order and
        % splitting at the marker.
        flatten_forall_nodes(Children, Flat),
        split_forall_children_direct(Flat, CondNodes, ConsNodes)
    ).

has_direct_marker(Children) :-
    member(node(_, Tokens, _), Children),
    is_it_the_case(Tokens), !.

split_forall_children_direct([], [], []).
split_forall_children_direct([node(_, Tokens, Children)|Rest], [], Consequences) :-
    is_it_the_case(Tokens), !,
    ( Children == [] -> Consequences = Rest; Consequences = Children).
split_forall_children_direct([Node|Rest], [Node|Conds], Cons) :-
    split_forall_children_direct(Rest, Conds, Cons).

% Flatten a node hierarchy into a flat sibling list in document order, dropping
% the nesting (each node keeps its tokens but no children). Used to recover the
% intended condition/consequence sequence of a forall when bad indentation has
% mis-nested it.
flatten_forall_nodes([], []).
flatten_forall_nodes([node(N, Tokens, Children)|Rest], Flat) :-
    flatten_forall_nodes(Children, FlatChildren),
    flatten_forall_nodes(Rest, FlatRest),
    append([node(N, Tokens, [])|FlatChildren], FlatRest, Flat).

is_it_the_case(Tokens) :-
    maplist(extract_word_atom, Tokens, Atoms0),
    optional_leading_and(Atoms0, Atoms),
    kw_words_eq(it_the_case, Atoms).

is_not_the_case(Tokens) :-
    maplist(extract_word_atom, Tokens, Atoms),
    (   kw_words_eq(not_the_case, Atoms)
    ;   kw_words_eq(unless, Atoms)
    ;   kw_words_eq(and_unless, Atoms)
    ), !.

% inline_naf_goal(+Tokens, -GoalTokens): when Tokens are "it is not the case that
% <goal>" (or "not the case that <goal>") with the goal on the SAME line, GoalTokens
% is that goal. Fails for the keyword-only form (goal on a nested line).
inline_naf_goal(Tokens, GoalTokens) :-
    naf_prefix_tokens(Tokens, GoalTokens),
    GoalTokens \== [].

naf_prefix_tokens(Tokens, Rest) :-
    le_i18n:kw_synonym_words(not_the_case, Words),   % longest synonyms first
    match_word_prefix(Words, Tokens, Rest),
    !.

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
