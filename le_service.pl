/** <module> The LE language service — one module for an embedder to load

    LPS2 no longer talks to Logical English over HTTP or through a subprocess:
    it loads *this* module into its own SWI-Prolog image and calls predicates.
    This file is the documented surface of that arrangement, so an embedder
    never reaches into le_kbs or le_grammar and those two stay free to move.
    The plan is docs/LEintegrationImprovementPlan.md in the LPS2 repository,
    items R1 (this module), R2 (lifecycle and containment) and R3 (the
    editor-facing data).

    Nothing here parses, emits or renders anything itself. Parsing is
    le_grammar's, the LE->LPS emitter is le_lps's, the lexicon is le_i18n's
    and the CSV dictionaries under i18n/ are its single source; this module
    selects, shapes and hands over.

    ## What an embedder gets

      1. **The payload** — le_lps_text/4, le_lps_file/4, le_lps_module/5,
         le_lps_dict/4, le_lps_json/1, le_lps_json_text/1, re-exported from
         le_lps unchanged. This is the §2 object of docs/le_lps_interface.md
         and it does not change shape because it is now reached differently.
      2. **Lifecycle and containment** — le_kb_of_text/3, le_kb_dispose/1,
         and the network switch re-exported from le_kbs.
      3. **The editor-facing data** — le_lexicon/2, le_languages/1,
         le_templates/3, le_blocks/3, le_analyse/3, and the `*_dict`
         variants of those that an HTTP or JSON layer can serialise directly.

    ## Why loading this in another process is safe

    Loading a Logical English document parses and asserts; it does not run the
    document. le_kbs:load_prolog_resource/4 is assert-only — it honours
    dynamic/1, discontiguous/1 and use_module(library(Lib)) for atomic library
    names, strips module/2 with a warning, and skips initialization/1 and
    every other directive, precisely so that a fetched .pl cannot execute at
    load time. Runtime `prolog` bodies pass library(sandbox)'s safe_goal/1 in
    the reasoner. The one thing a document *can* still reach for on its own is
    the network, when a resource is given as a URL — which is what
    set_le_network_allowed/1 is for.

    ## The two things to know about KB modules

    le_kbs:load_text/2 is content-addressed: the module for a document is
    `m<sha1 of its text>`, and an error-free module is reused rather than
    reparsed. So compiling the same buffer twice is nearly free, and an editor
    should NOT dispose after every compile — it would throw that cache away on
    every keystroke. Dispose when a document is closed.

    le_kb_dispose/1 reclaims only what is safe to reclaim: le_kbs's own
    liveness check refuses to abolish a module a session or another reader
    still references. Calling it on a live KB is a no-op, not a corruption.

    ## Concurrency

    Safe to call from several threads at once, which is what an embedder
    serving HTTP needs to know. The three pieces of state that would have made
    it unsafe are already per-thread or already locked: le_i18n keeps the
    active language in a global variable, which in SWI is thread-local;
    le_kbs's le_include_base/1 is declared thread_local; and load_text/2 takes
    a per-module mutex. A Portuguese document analysed on one thread while an
    English one is analysed on another gives the same answers as either alone
    — which is a test, not an inference, and it is why an embedder does not
    need a mutex of its own around these calls.

    ## What is deliberately not here

    A route to the reasoner. An embedder that wants answers to queries wants
    le_kbs, and should say so; this module exists for the two jobs an editor
    has — turning a document into a program, and knowing enough about the
    language to highlight and complete it.

    The four declaration sections (`the fluents are:` and its siblings) do not
    record their own start and end offsets — le_grammar keeps offsets on each
    template, not on the section around it — so le_blocks/3 reports the
    sections that do (knowledge bases, scenarios, queries, the ontology) and
    each template individually. Aggregating a section extent from its
    templates would be a guess, and a guess is worse than an absence.
*/

:- module(le_service, [
    % — R2: lifecycle and containment
    le_kb_of_text/3,            % +LEText, +Options, -KB
    le_kb_dispose/1,            % +KB
    % — R3: the editor-facing data
    le_lexicon/2,               % +Lang, -Lexicon
    le_languages/1,             % -Languages
    le_templates/3,             % +KB, +LEText, -Templates
    le_blocks/3,                % +KB, +LEText, -Blocks
    le_analyse/3,               % +LEText, +Options, -Analysis
    % — the same, shaped for JSON
    le_lexicon_dict/2,          % +Lang, -Dict
    le_analyse_dict/3,          % +LEText, +Options, -Dict
    % — English in, Logical English out (loaded on first use)
    le_english_to_le/8,         % +Kind, +Sentence, +Templates, +Program, +Model, +Options, -LEText, -Issues
    set_le_llm_provider/1,      % +Module
    le_service_version/1        % -Version
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(library(error)).

%   The payload predicates keep their names and their meaning; only the way
%   they are reached has changed.
:- reexport(le_lps, [
    le_lps_text/4,
    le_lps_file/4,
    le_lps_module/5,
    le_lps_json/1,
    le_lps_json_text/1,
    le_lps_dict/4
  ]).
:- reexport(le_kbs, [
    le_network_allowed/0,
    set_le_network_allowed/1,
    le_issue_reporting/0,
    set_le_issue_reporting/1
  ]).

:- use_module(le_lps, [offset_line_col/4]).
:- use_module(le_kbs, [
    load_text/2, load_text/3,
    maybe_destroy_kb/1,
    with_kb_reference/2,
    text_language/2,
    kb_target_language/2,
    ensure_kb_language/1
  ]).
:- use_module(le_i18n, [
    kw_category_key/2,
    kw_synonym_words/3,
    known_language/1,
    language_param/3,
    language_autonym/2,
    language_opener/2
  ]).

%!  le_service_version(-Version:atom) is det.
%
%   The version of the surface described in this module's header. An embedder
%   that cares whether the LE2 checkout it loaded is new enough checks this;
%   it moves when a predicate here changes shape, not when LE itself grows.
le_service_version('1.1').


		 /*******************************
		 *   English → Logical English  *
		 *******************************/

%   The broker, not the client: an embedder that has its own LLM plumbing
%   substitutes it and every LE feature that needs a model uses theirs.
:- reexport(llm/le_llm, [set_le_llm_provider/1]).

%!  le_english_to_le(+Kind, +Sentence, +Templates, +Program, +Model, +Options,
%!                   -LEText, -NewIssues) is det.
%
%   nl_to_le:english_to_le/8, loaded on first use.
%
%   Lazily, because it is the one part of this surface that costs something to
%   have: it pulls in the verifier's refinement loop and an HTTP client, and a
%   program that never converts an English sentence should not pay for the
%   possibility. Everything else here is already in memory by the time this
%   module has loaded.
le_english_to_le(Kind, Sentence, Templates, Program, Model, Options, LEText, NewIssues) :-
    ensure_nl_to_le,
    nl_to_le:english_to_le(Kind, Sentence, Templates, Program, Model, Options,
                           LEText, NewIssues).

ensure_nl_to_le :-
    current_predicate(nl_to_le:english_to_le/8), !.
ensure_nl_to_le :-
    use_module(le2(nl_to_le), []).


		 /*******************************
		 *   R2 — lifecycle            *
		 *******************************/

%!  le_kb_of_text(+LEText:string, +Options:list, -KB:atom) is semidet.
%
%   The knowledge-base module for a document, loading it if this text has not
%   been seen (or was last seen with errors). Fails, having printed the
%   exception, when the document does not parse at all — le_analyse/3 is the
%   call to make when the diagnostics matter more than the KB.
%
%   Options:
%
%     * base(Dir)
%     Directory to resolve the document's relative resource includes against.
%     Default: the working directory. An editor that has a file path for the
%     buffer should pass its directory, or `resources` lines that worked from
%     the command line will not find their siblings.
le_kb_of_text(LEText, Options, KB) :-
    must_be(list, Options),
    catch(load_kb(LEText, Options, KB), E, (print_message(error, E), fail)).

load_kb(LEText, Options, KB) :-
    (   memberchk(base(Base), Options), Base \== '', Base \== (-)
    ->  load_text(LEText, Base, KB)
    ;   load_text(LEText, KB)
    ).

%!  le_kb_dispose(+KB:atom) is det.
%
%   Releases the memory a KB module holds, if nothing is using it. A module
%   still referenced by a reasoning session or by a concurrent reader is left
%   alone, so this is safe to call speculatively — when an editor closes a
%   document, say. See the header for why an editor should not call it after
%   every compile.
le_kb_dispose(KB) :-
    (   atom(KB), KB \== none
    ->  catch(maybe_destroy_kb(KB), _, true)
    ;   true
    ).


		 /*******************************
		 *   R3 — the lexicon          *
		 *******************************/

%!  le_lexicon(+Lang:atom, -Lexicon) is det.
%
%   Every grammar keyword of one program language:
%
%       lexicon(Lang, [keyword(Key, Category, Synonyms), ...])
%
%   `Synonyms` is a list of word lists — `[[when], [if]]` — longest phrase
%   first, which is the order a regex alternation has to try them in. A key
%   the language does not define falls back to English, exactly as the parser
%   does, so a caller always gets a usable table.
%
%   This is the single source that keeps a keyword table out of an embedder's
%   own sources: i18n/keywords.csv is read by the Prolog grammar and served
%   from here, and nobody has a second copy to drift.
le_lexicon(Lang, lexicon(Lang, Keywords)) :-
    must_be(atom, Lang),
    findall(keyword(Key, Category, Synonyms),
            (   kw_category_key(Category, Key),
                key_synonyms(Lang, Key, Synonyms),
                Synonyms \== []
            ),
            Keywords0),
    sort(Keywords0, Keywords).

key_synonyms(Lang, Key, Synonyms) :-
    findall(Words, kw_synonym_words(Lang, Key, Words), Raw),
    map_list_to_pairs(phrase_length, Raw, Pairs0),
    sort(1, @>=, Pairs0, Pairs),
    pairs_values(Pairs, Ordered),
    list_to_set(Ordered, Synonyms).

phrase_length(Words, Length) :-
    atomic_list_concat(Words, ' ', Phrase),
    atom_length(Phrase, Length).

%!  le_languages(-Languages:list) is det.
%
%   The registry of program languages (i18n/languages.csv), as
%   `language(Code, Autonym, OpenerWords, Params)`. `Params` is the
%   key-value list le_i18n keeps: decimal_sep, thousands_sep, list_sep,
%   status, english_name. The opener is what tells one language's documents
%   from another's.
le_languages(Languages) :-
    findall(language(Code, Autonym, Opener, Params),
            (   known_language(Code),
                (   language_autonym(Code, Autonym) -> true ; Autonym = Code ),
                (   language_opener(Code, Opener) -> true ; Opener = [] ),
                findall(P-V,
                        (   member(P, [decimal_sep, thousands_sep, list_sep,
                                       status, english_name]),
                            language_param(Code, P, V)
                        ),
                        Params)
            ),
            Languages).


		 /*******************************
		 *   R3 — templates and blocks *
		 *******************************/

%!  le_templates(+KB:atom, +LEText:string, -Templates:list) is det.
%
%   Every template the KB knows, as
%
%       le_template(Functor/Arity, Role, Surface, Slots, Position, Flags)
%
%   `Role` is the declaration section the template came from —
%   `fluent | event | action | prolog_event` for a document targeting LPS,
%   and `predicate` for an ordinary template. It is the one thing LPS cannot
%   infer and the author must state, so it is what an editor needs in order
%   to complete the right thing in the right place.
%
%   `Surface` is the template's own words with each slot rendered
%   `*a <type>*` — the canonical form to complete from, and close to what the
%   author wrote without being a promise of it: le_grammar keeps a slot's
%   head-noun type but not the words it was declared with, so a slot written
%   `*a first person*` comes back `*a person*`. The declaration verbatim is a
%   slice of the source at `Position`, which the caller has.
%
%   `Slots` is `[slot(Index, Type), ...]`, Index 0-based over the arguments,
%   Type the head noun the author typed the slot with (`unknown` when the
%   slot is untyped). `Position` is `pos(Start, End, Line, Col)` with Start
%   and End character offsets and Line/Col 1-based and 0-based respectively —
%   the convention docs/le_lps_interface.md §2 fixes for everything crossing
%   this boundary — or `pos(none, none, 0, 0)` for a template with no source.
%
%   `Flags` carries what the additions said: `prepositional`, `unknown`,
%   `opposite(F/A)`, `defines_global(G)`.
le_templates(KB, LEText, Templates) :-
    (   atom(KB), KB \== none, current_module(KB)
    ->  with_kb_reference(KB, templates_of(KB, LEText, Templates))
    ;   Templates = []
    ).

templates_of(KB, LEText, Templates) :-
    findall(T, kb_template(KB, LEText, T), Templates0),
    sort(Templates0, Templates).

kb_template(KB, LEText, le_template(F/A, Role, Surface, Slots, Position, Flags)) :-
    current_predicate(KB:le_dict/1),
    catch(clause(KB:le_dict(Dict), true, Ref), _, fail),
    dict_parts(Dict, FA, NamesTypes, WordsAndVars, Flags0),
    FA = [F|Args],
    atom(F),
    length(Args, A),
    template_role(KB, F/A, Role),
    template_position(KB, Ref, LEText, Position),
    reconstruct_surface(WordsAndVars, NamesTypes, Surface),
    template_slots(Args, NamesTypes, 0, Slots),
    sort(Flags0, Flags).

%   Stored templates are dict/7 (assert_dict_with_source/2 drops the offsets
%   into le_source_info and keeps the rest); the built-ins arrive as dict/3.
%   Both shapes are read here rather than assumed, because which one a KB
%   holds depends on how the template was declared.
dict_parts(dict(FA, NTs, WV, Globals, Opposite, Prep, Unknown), FA, NTs, WV, Flags) :-
    !,
    findall(Flag, dict_flag(Globals, Opposite, Prep, Unknown, Flag), Flags).
dict_parts(dict(FA, NTs, WV), FA, NTs, WV, []).

dict_flag(_, _, Prep, _, prepositional) :- Prep == prepositional.
dict_flag(_, _, _, Unknown, unknown) :- Unknown == unknown.
dict_flag(_, Opposite, _, _, opposite(OF/OA)) :-
    nonvar(Opposite),
    functor(Opposite, OF, OA).
dict_flag(Globals, _, _, _, defines_global(G)) :-
    is_list(Globals),
    member(G0, Globals),
    (   G0 = _-G1 -> G = G1 ; G = G0 ).

template_role(KB, F/A, Role) :-
    (   current_predicate(KB:le_lps_role/2),
        catch(KB:le_lps_role(F/A, Role0), _, fail)
    ->  Role = Role0
    ;   Role = predicate
    ).

template_position(KB, Ref, LEText, Position) :-
    (   current_predicate(KB:le_source_info/4),
        catch(KB:le_source_info(Ref, Start, End, _), _, fail),
        integer(Start)
    ->  position(Start, End, LEText, Position)
    ;   Position = pos(none, none, 0, 0)
    ).

%!  position(+Start, +End, +LEText, -Position) is det.
position(Start, End, LEText, pos(Start, End, Line, Col)) :-
    (   integer(Start), LEText \== "", LEText \== ''
    ->  offset_line_col(LEText, Start, Line, Col)
    ;   Line = 0, Col = 0
    ).

%   Words are atoms and slots are variables shared with the argument list, so
%   a slot is rendered from the type recorded for that very variable.
%
%   The surface is always reconstructed, never sliced out of the source at
%   Start..End, because a template's derived forms — its `opposite:` and its
%   synonyms — are recorded against the *parent's* offsets. Slicing would give
%   all of them the parent's text and quietly lose exactly the alternate
%   phrasings an editor wants to offer.
reconstruct_surface(WordsAndVars, NamesTypes, Surface) :-
    maplist(surface_piece(NamesTypes), WordsAndVars, Pieces),
    join_pieces(Pieces, Surface).

surface_piece(NamesTypes, Element, Piece) :-
    (   var(Element)
    ->  slot_type(NamesTypes, Element, Type),
        format(atom(Piece), "*a ~w*", [Type])
    ;   format(atom(Piece), "~w", [Element])
    ).

%   Punctuation joins to the word before it; everything else takes a space.
join_pieces([], "") :- !.
join_pieces([P|Ps], Surface) :-
    foldl(join_piece, Ps, P, Joined),
    atom_string(Joined, Surface).

join_piece(Piece, Acc, Joined) :-
    (   punctuation_piece(Piece)
    ->  atomic_list_concat([Acc, Piece], Joined)
    ;   atomic_list_concat([Acc, ' ', Piece], Joined)
    ).

punctuation_piece(P) :-
    atom(P),
    memberchk(P, [',', '.', ';', ':', '?', '!', ')', ']']).

template_slots([], _, _, []).
template_slots([Arg|Args], NamesTypes, I, [slot(I, Type)|Slots]) :-
    slot_type(NamesTypes, Arg, Type),
    I1 is I + 1,
    template_slots(Args, NamesTypes, I1, Slots).

slot_type(NamesTypes, Var, Type) :-
    (   member(V-T, NamesTypes), V == Var, nonvar(T)
    ->  Type = T
    ;   Type = unknown
    ).

%!  le_blocks(+KB:atom, +LEText:string, -Blocks:list) is det.
%
%   The document's structure, as `le_block(Kind, Detail, Name, Position)` —
%   one entry per thing le_grammar recorded a start and an end for, in source
%   order:
%
%     | `kb` | a knowledge-base section |
%     | `scenario` | a scenario block |
%     | `query` | a query block |
%     | `ontology` | the ontology section |
%     | `expectation` | one `expects answers` line inside a scenario |
%     | `template` | one template declaration |
%     | `template_unknown` | a template declared as possibly unknown |
%     | `setting` | an LPS setting line (`the maximum time is: 12.`) |
%     | `lps_sentence` | one LPS sentence; Detail is its kind (`head_rule`, `denial`, `initially`, `goal`, ...) |
%     | `rule` | an ordinary LE rule or fact; Detail is its `Functor/Arity` |
%
%   `Detail` is `none` where a kind has nothing to add. `Name` is whatever
%   names the block — a scenario's or query's name, a setting's key, the
%   identifier le_kbs generated for a sentence (`lps_616`, `rule_240`), which
%   is also the key le_source_section/2 files it under. Position is as in
%   le_templates/3.
%
%   The kind is decided from the clause each record points at, not guessed
%   from its name. The declaration sections themselves are absent, and the
%   module header says why.
le_blocks(KB, LEText, Blocks) :-
    (   atom(KB), KB \== none, current_module(KB)
    ->  with_kb_reference(KB, blocks_of(KB, LEText, Blocks))
    ;   Blocks = []
    ).

blocks_of(KB, LEText, Blocks) :-
    findall(Start-le_block(Kind, Detail, Name, Position),
            (   current_predicate(KB:le_source_info/4),
                catch(KB:le_source_info(Ref, Start, End, Name), _, fail),
                integer(Start),
                block_kind(KB, Ref, Kind, Detail),
                position(Start, End, LEText, Position)
            ),
            Pairs0),
    keysort(Pairs0, Pairs),
    pairs_values(Pairs, Blocks0),
    list_to_set(Blocks0, Blocks).

%   What kind of block a source record belongs to is decided by the clause it
%   references, not by guessing from its name. The last clause is the
%   catch-all — an ordinary LE rule or fact is asserted as a clause of the KB
%   module under its own functor, so there is nothing else to match on.
block_kind(KB, Ref, Kind, Detail) :-
    catch(clause(KB:Head, _, Ref), _, fail),
    nonvar(Head),
    once(block_head_kind(Head, Kind, Detail)).

block_head_kind(le_kb(_),                kb,               none).
block_head_kind(scenario(_, _),          scenario,         none).
block_head_kind(query_info(_, _, _),     query,            none).
block_head_kind(ontology(_),             ontology,         none).
block_head_kind(le_expected(_, _, _, _), expectation,      none).
block_head_kind(le_dict(_),              template,         none).
block_head_kind(le_unknown(_),           template_unknown, none).
block_head_kind(le_lps_item(setting, _, _), setting,       none).
block_head_kind(le_lps_item(Kind, _, _), lps_sentence,     Kind).
block_head_kind(Head,                    rule,             F/A) :-
    functor(Head, F, A).


		 /*******************************
		 *   R3 — one call for an IDE  *
		 *******************************/

%!  le_analyse(+LEText:string, +Options:list, -Analysis) is det.
%
%   Everything an editor wants about a buffer, in one call:
%
%       analysis(Language, Target, Templates, Blocks, Issues)
%
%   `Language` is the program's own language, detected from its opener;
%   `Target` its target language (`lps`, `prolog`, `scasp`); Templates and
%   Blocks are le_templates/3 and le_blocks/3; Issues are the LE-side
%   diagnostics, as `le_issue(Severity, Type, Message, Fix, Line, Col)` with
%   positions already resolved.
%
%   This always answers. A document LE can load but disagrees with comes back
%   with whatever it did understand and its own diagnostics — a malformed
%   section is an `unknown_section` issue, not a refusal. Only a document that
%   cannot be loaded at all falls back to no templates, no blocks and a single
%   `parse_error`. An editor must never be left with nothing to show.
%
%   Options are le_kb_of_text/3's, plus:
%
%     * dispose(Bool)
%     Reclaim the KB module before returning. Default false: the module is
%     the parse cache, and an editor that disposes here reparses on every
%     keystroke.
le_analyse(LEText, Options, analysis(Language, Target, Templates, Blocks, Issues)) :-
    must_be(list, Options),
    document_language(LEText, Language),
    (   le_kb_of_text(LEText, Options, KB)
    ->  ensure_kb_language(KB),
        kb_target_language(KB, Target),
        le_templates(KB, LEText, Templates),
        le_blocks(KB, LEText, Blocks),
        kb_issues(KB, LEText, Issues),
        (   memberchk(dispose(true), Options)
        ->  le_kb_dispose(KB)
        ;   true
        )
    ;   Target = unknown,
        Templates = [], Blocks = [],
        Issues = [le_issue(error, parse_error,
                           'the document did not parse', '', 0, 0)]
    ).

document_language(LEText, Language) :-
    (   catch(text_language(LEText, L), _, fail)
    ->  Language = L
    ;   Language = en
    ).

kb_issues(KB, LEText, Issues) :-
    (   current_predicate(KB:le_issue/6)
    ->  findall(le_issue(Sev, Type, Msg, Fix, Line, Col),
                (   catch(KB:le_issue(Sev, Type, Msg, Fix, Start, _End), _, fail),
                    position(Start, Start, LEText, pos(_, _, Line, Col))
                ),
                Issues)
    ;   Issues = []
    ).


		 /*******************************
		 *   The same, shaped for JSON *
		 *******************************/

%!  le_lexicon_dict(+Lang:atom, -Dict) is det.
%
%   le_lexicon/2 and le_languages/1 as one dict, in the shape a Monaco mode
%   consumes:
%
%       _{ lang: "en",
%          keywords:   _{ Key: [["when"], ["if"]], ... },
%          categories: _{ Key: "connective", ... },
%          languages:  [ _{code:"en", autonym:"English", opener:"the target
%                          language is", decimalSep:".", ...}, ... ] }
%
%   `keywords` and `categories` are separate maps rather than one map of
%   objects because that is what a tokenizer builder actually indexes, and
%   because it is the shape editor/scripts/gen-i18n.cjs already produces from
%   the same CSVs — an embedder porting that builder does not have to reshape
%   anything.
le_lexicon_dict(Lang, Dict) :-
    le_lexicon(Lang, lexicon(Lang, Keywords)),
    findall(Key-Phrases,
            (   member(keyword(Key, _, Synonyms), Keywords),
                maplist(words_strings, Synonyms, Phrases)
            ),
            KeywordPairs),
    findall(Key-CategoryS,
            (   member(keyword(Key, Category, _), Keywords),
                atom_string(Category, CategoryS)
            ),
            CategoryPairs),
    dict_pairs(KeywordsDict, _, KeywordPairs),
    dict_pairs(CategoriesDict, _, CategoryPairs),
    le_languages(Languages),
    maplist(language_dict, Languages, LanguageDicts),
    atom_string(Lang, LangS),
    Dict = _{ lang: LangS,
              keywords: KeywordsDict,
              categories: CategoriesDict,
              languages: LanguageDicts }.

words_strings(Words, Strings) :-
    maplist(atom_string, Words, Strings).

language_dict(language(Code, Autonym, Opener, Params),
              _{ code: CodeS, autonym: AutonymS, opener: OpenerS,
                 decimalSep: Dec, thousandsSep: Thou, listSep: ListSep,
                 status: Status, englishName: English }) :-
    atom_string(Code, CodeS),
    atom_string(Autonym, AutonymS),
    atomic_list_concat(Opener, ' ', OpenerAtom),
    atom_string(OpenerAtom, OpenerS),
    param_string(Params, decimal_sep, Dec),
    param_string(Params, thousands_sep, Thou),
    param_string(Params, list_sep, ListSep),
    param_string(Params, status, Status),
    param_string(Params, english_name, English).

param_string(Params, Key, Value) :-
    (   memberchk(Key-V, Params)
    ->  atom_string(V, Value)
    ;   Value = ""
    ).

%!  le_analyse_dict(+LEText:string, +Options:list, -Dict) is det.
%
%   le_analyse/3 as a dict, ready for json_write_dict/2. Offsets travel as
%   well as line and column: an editor that keeps character positions does not
%   have to convert them back.
le_analyse_dict(LEText, Options, Dict) :-
    le_analyse(LEText, Options,
               analysis(Language, Target, Templates, Blocks, Issues)),
    maplist(template_dict, Templates, TemplateDicts),
    maplist(block_dict, Blocks, BlockDicts),
    maplist(issue_dict, Issues, IssueDicts),
    atom_string(Language, LanguageS),
    atom_string(Target, TargetS),
    Dict = _{ language: LanguageS,
              target: TargetS,
              templates: TemplateDicts,
              blocks: BlockDicts,
              issues: IssueDicts }.

template_dict(le_template(F/A, Role, Surface, Slots, Position, Flags),
              Dict) :-
    atom_string(F, FS),
    atom_string(Role, RoleS),
    text_to_string(Surface, SurfaceS),
    maplist(slot_dict, Slots, SlotDicts),
    maplist(term_text, Flags, FlagStrings),
    position_pairs(Position, PositionPairs),
    dict_pairs(PositionDict, _, PositionPairs),
    Dict = PositionDict.put(_{ functor: FS, arity: A, role: RoleS,
                               surface: SurfaceS, slots: SlotDicts,
                               flags: FlagStrings }).

slot_dict(slot(Index, Type), _{ index: Index, type: TypeS }) :-
    atom_string(Type, TypeS).

block_dict(le_block(Kind, Detail, Name, Position), Dict) :-
    atom_string(Kind, KindS),
    term_text(Detail, DetailS),
    term_text(Name, NameS),
    position_pairs(Position, PositionPairs),
    dict_pairs(PositionDict, _, PositionPairs),
    Dict = PositionDict.put(_{ kind: KindS, detail: DetailS, name: NameS }).

term_text(Term, Text) :-
    (   atom(Term) -> atom_string(Term, Text)
    ;   string(Term) -> Text = Term
    ;   term_string(Term, Text)
    ).

issue_dict(le_issue(Severity, Type, Message, Fix, Line, Col),
           _{ severity: SeverityS, type: TypeS, message: MessageS,
              fix: FixS, line: Line, col: Col }) :-
    atom_string(Severity, SeverityS),
    atom_string(Type, TypeS),
    text_to_string(Message, MessageS),
    (   Fix == '' -> FixS = "" ; text_to_string(Fix, FixS) ).

position_pairs(pos(Start, End, Line, Col),
               [line-Line, col-Col, start-Start1, end-End1]) :-
    (   integer(Start) -> Start1 = Start ; Start1 = -1 ),
    (   integer(End) -> End1 = End ; End1 = -1 ).
