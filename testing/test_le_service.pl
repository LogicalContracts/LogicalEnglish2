% Tests for le_service.pl — the module an embedder loads instead of reaching
% into le_kbs and le_grammar (docs/LEintegrationImprovementPlan.md, R1–R3 in
% the LPS2 repository).
%
% What is worth testing here is not that Logical English parses — every other
% suite does that — but that the three promises this module makes hold:
%
%   R1  the §2 payload still arrives, reached this new way;
%   R2  a KB can be reclaimed, and a document cannot reach the network when
%       the embedder has said it must not;
%   R3  the lexicon and the templates carry what a Monaco mode needs — every
%       keyword of a language with its synonyms longest-first, and every
%       template with the ROLE its declaration section conferred, which is the
%       one thing an editor cannot work out for itself.

:- use_module('../le_service').
:- use_module('../le_kbs').

%   An LPS-target program: two declaration sections that confer roles, one
%   setting, and one sentence of each shape le_blocks/3 classifies.
lps_program("the target language is: lps.

the maximum time is 6.

the actions are:
    *a person* switches the light in *a room* to *a setting*.

the fluents are:
    the light in *a room* is *a setting*.

the knowledge base tiny includes:

initially the light in kitchen is off.

if bob stands in a room at a first time
then bob switches the light in the room to on from the first time to a second time.

when a person switches the light in a room to a setting
then the light in the room is the setting.

it must not be true that
    bob switches the light in a room to on from a first time to a second time
    and the light in the room is on at the first time.
").

%   A plain (Prolog-target) program, for the block kinds an LPS document has
%   none of: ordinary rules, a scenario, a query.
le_program("the target language is: prolog.

the templates are:
    *a person* is happy ; opposite: *a person* is sad.
    *a person* is healthy.

the knowledge base tiny includes:

a person is happy
    if the person is healthy.

scenario one is:
    mary is healthy.

query who is:
    which person is happy.
").

lps_kb(KB) :- lps_program(P), le_kb_of_text(P, [], KB).
le_kb(KB)  :- le_program(P),  le_kb_of_text(P, [], KB).

template_named(Templates, Functor, Template) :-
    Template = le_template(Functor/_, _, _, _, _, _),
    memberchk(Template, Templates).

:- begin_tests(le_service).

% --- R1: the payload, unchanged ------------------------------------------

test(payload_reexported) :-
    lps_program(P),
    le_lps_text(P, Text, Provenance, Issues),
    assertion(Text \== ""),
    assertion(Provenance \== []),
    assertion(\+ memberchk(le_lps_issue(error, _, _, _, _), Issues)),
    % the emitter's vocabulary, not a paraphrase of it
    assertion(sub_string(Text, _, _, _, "reactive_rule(")),
    assertion(sub_string(Text, _, _, _, "initial_state(")).

test(version) :-
    le_service_version(V),
    assertion(atom(V)).

% --- R2: lifecycle --------------------------------------------------------

test(kb_is_content_addressed_and_reusable) :-
    lps_kb(KB1),
    lps_kb(KB2),
    assertion(KB1 == KB2).

test(dispose_reclaims_and_reload_rebuilds) :-
    lps_kb(KB),
    assertion(catch(KB:le_dict(_), _, fail)),
    le_kb_dispose(KB),
    assertion(\+ catch(KB:le_dict(_), _, fail)),
    lps_kb(KB2),
    assertion(KB2 == KB),
    assertion(catch(KB2:le_dict(_), _, fail)).

test(dispose_of_a_non_module_is_a_no_op) :-
    le_kb_dispose(none),
    le_kb_dispose(no_such_module_at_all).

% A URL-valued resource must not be fetched once the embedder has said so,
% and the document must be told why rather than silently losing its contents.
test(network_switch, [cleanup(set_le_network_allowed(true))]) :-
    Program = "the templates are:
    *a person* supports *a team*.

the knowledge base netcheck includes these resources:
    http://localhost:1/nothing.

the knowledge base netcheck includes:
    mary supports arsenal.
",
    assertion(le_network_allowed),
    set_le_network_allowed(false),
    assertion(\+ le_network_allowed),
    le_analyse(Program, [dispose(true)], analysis(_, _, _, _, Issues)),
    assertion(( member(le_issue(error, _, Message, _, _, _), Issues),
                sub_atom(Message, _, _, _, 'network access is disabled') )),
    set_le_network_allowed(true),
    assertion(le_network_allowed).

% --- R3: the lexicon ------------------------------------------------------

test(lexicon_has_keys_with_categories) :-
    le_lexicon(en, lexicon(en, Keywords)),
    assertion(Keywords \== []),
    assertion(memberchk(keyword(if, _, _), Keywords)),
    forall(member(keyword(Key, Category, Synonyms), Keywords),
           ( assertion(atom(Key)),
             assertion(atom(Category)),
             assertion(Synonyms \== []),
             assertion(forall(member(S, Synonyms), is_list(S))) )).

test(lexicon_synonyms_are_longest_phrase_first) :-
    le_lexicon(en, lexicon(en, Keywords)),
    forall(member(keyword(_, _, Synonyms), Keywords),
           assertion(descending_lengths(Synonyms))).

% A language that does not define a key falls back to English, exactly as the
% parser does — an editor is never handed a language with holes in it.
test(lexicon_falls_back_to_english) :-
    le_lexicon(pt, lexicon(pt, Portuguese)),
    le_lexicon(en, lexicon(en, English)),
    assertion(memberchk(keyword(if, _, [[se]]), Portuguese)),
    forall(member(keyword(Key, _, _), English),
           assertion(memberchk(keyword(Key, _, _), Portuguese))).

test(languages_registry) :-
    le_languages(Languages),
    assertion(memberchk(language(en, _, _, _), Languages)),
    memberchk(language(en, _, Opener, Params), Languages),
    assertion(Opener \== []),
    assertion(memberchk(status-_, Params)).

test(lexicon_dict_shape) :-
    le_lexicon_dict(en, Dict),
    get_dict(keywords, Dict, Keywords),
    get_dict(categories, Dict, Categories),
    get_dict(languages, Dict, Languages),
    assertion(get_dict(if, Keywords, [["if"]])),
    assertion(get_dict(if, Categories, _)),
    assertion(Languages \== []).

% --- R3: templates --------------------------------------------------------

% The role is the point: it comes from the section the template was declared
% in, and nothing else can supply it.
test(templates_carry_their_declared_role) :-
    lps_kb(KB),
    lps_program(P),
    le_templates(KB, P, Templates),
    template_named(Templates, switches_the_light_in_to, Action),
    template_named(Templates, the_light_in_is, Fluent),
    assertion(Action = le_template(_, action, _, _, _, _)),
    assertion(Fluent = le_template(_, fluent, _, _, _, _)).

test(templates_have_surface_slots_and_position) :-
    lps_kb(KB),
    lps_program(P),
    le_templates(KB, P, Templates),
    template_named(Templates, switches_the_light_in_to,
                   le_template(_/Arity, _, Surface, Slots, Position, _)),
    assertion(Arity == 3),
    assertion(sub_string(Surface, _, _, _, "switches the light in")),
    assertion(Slots = [slot(0, person), slot(1, room), slot(2, setting)]),
    Position = pos(Start, End, Line, Col),
    assertion(integer(Start)), assertion(integer(End)), assertion(End > Start),
    assertion(Line > 1), assertion(integer(Col)).

% An ordinary template gets `predicate`; a built-in has no source position.
test(plain_templates_and_builtins) :-
    le_kb(KB),
    le_program(P),
    le_templates(KB, P, Templates),
    template_named(Templates, is_happy, le_template(_, Role, _, _, _, Flags)),
    assertion(Role == predicate),
    assertion(memberchk(opposite(_), Flags)),
    assertion(( member(le_template(_, _, _, _, pos(none, none, 0, 0), _), Templates) )).

test(templates_of_no_kb_are_empty) :-
    le_templates(none, "", Templates),
    assertion(Templates == []).

% --- R3: blocks -----------------------------------------------------------

test(lps_blocks_are_classified) :-
    lps_kb(KB),
    lps_program(P),
    le_blocks(KB, P, Blocks),
    assertion(memberchk(le_block(setting, none, maxTime, _), Blocks)),
    assertion(memberchk(le_block(kb, none, tiny, _), Blocks)),
    assertion(memberchk(le_block(template, none, _, _), Blocks)),
    assertion(memberchk(le_block(lps_sentence, initially, _, _), Blocks)),
    assertion(memberchk(le_block(lps_sentence, if, _, _), Blocks)),
    assertion(memberchk(le_block(lps_sentence, when, _, _), Blocks)),
    assertion(memberchk(le_block(lps_sentence, denial, _, _), Blocks)).

test(plain_blocks_are_classified) :-
    le_kb(KB),
    le_program(P),
    le_blocks(KB, P, Blocks),
    assertion(memberchk(le_block(rule, is_happy/1, _, _), Blocks)),
    assertion(memberchk(le_block(scenario, none, one, _), Blocks)),
    assertion(memberchk(le_block(query, none, who, _), Blocks)).

test(blocks_are_in_source_order) :-
    le_kb(KB),
    le_program(P),
    le_blocks(KB, P, Blocks),
    findall(S, member(le_block(_, _, _, pos(S, _, _, _)), Blocks), Starts),
    assertion(ascending(Starts)).

% --- R3: one call for an editor ------------------------------------------

test(analyse_reports_language_and_target) :-
    lps_program(P),
    le_analyse(P, [], analysis(Language, Target, Templates, Blocks, Issues)),
    assertion(Language == en),
    assertion(Target == lps),
    assertion(Templates \== []),
    assertion(Blocks \== []),
    assertion(\+ memberchk(le_issue(error, _, _, _, _, _), Issues)).

% A document that says nothing LE recognises still answers, with the error
% against it — an editor must never be left with nothing to show. It gets the
% built-in templates and no blocks, because the document declared none.
test(analyse_of_nonsense_still_answers) :-
    le_analyse("this is not a Logical English document at all",
               [dispose(true)],
               analysis(_, _, Templates, Blocks, Issues)),
    assertion(Blocks == []),
    assertion(forall(member(le_template(_, _, _, _, Position, _), Templates),
                     Position == pos(none, none, 0, 0))),
    assertion(memberchk(le_issue(error, _, _, _, _, _), Issues)).

test(analyse_dict_is_json_ready) :-
    lps_program(P),
    le_analyse_dict(P, [], Dict),
    get_dict(templates, Dict, [T|_]),
    get_dict(blocks, Dict, [B|_]),
    assertion(get_dict(role, T, _)),
    assertion(get_dict(surface, T, _)),
    assertion(get_dict(slots, T, _)),
    assertion(get_dict(line, T, _)),
    assertion(get_dict(kind, B, _)),
    assertion(get_dict(detail, B, _)),
    assertion(is_dict(Dict)),
    with_output_to(string(Json), json_write_dict(current_output, Dict, [width(0)])),
    assertion(sub_string(Json, _, _, _, "\"role\"")).

:- end_tests(le_service).

descending_lengths(Lists) :-
    maplist(phrase_len, Lists, Lengths),
    \+ ( append(_, [A, B|_], Lengths), A < B ).

phrase_len(Words, Length) :-
    atomic_list_concat(Words, ' ', Phrase),
    atom_length(Phrase, Length).

ascending(Numbers) :-
    \+ ( append(_, [A, B|_], Numbers), A > B ).
