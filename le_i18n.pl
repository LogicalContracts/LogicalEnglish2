/** <module> Logical English i18n lexicon and catalogs

    Single source of truth for every natural-language surface of Logical
    English: grammar keywords, system-template phrases, diagnostic messages
    and UI chrome strings. The data lives in translator-friendly CSV files
    under i18n/ (one canonical key column, one column per language); this
    module loads them and exposes lookup predicates keyed by the ACTIVE
    LANGUAGE, a thread-local flag set from a program's first statement
    ("the target language is: prolog" -> en; "a linguagem alvo é: prolog"
    -> pt; ...).

    The module is deliberately self-contained (no dependency on the rest of
    the LE system) so extension modules living in sibling repositories
    (e.g. InsurLE2's le_extensions.pl) can consume the same lexicon API.
*/

:- module(le_i18n, [
    % active language
    le_active_language/1,       % -Lang (defaults to en)
    set_le_language/1,          % +Lang
    with_le_language/2,         % +Lang, :Goal
    % language registry (i18n/languages.csv)
    known_language/1,           % ?Lang
    language_autonym/2,         % ?Lang, ?Autonym
    language_opener/2,          % ?Lang, ?OpenerWords:list(atom)
    language_param/3,           % +Lang, +Param, -Value  (decimal_sep|thousands_sep|list_sep|status|english_name)
    localized_asset/3,          % +BaseNoExt, +Ext, -Path (active-language file variant)
    detect_language_tokens/2,   % +Tokens, -Lang
    % grammar keywords (i18n/keywords.csv)
    kw_synonym_words/2,         % +Key, -Words:list(atom)   (nondet, active language)
    kw_synonym_words/3,         % +Lang, +Key, -Words
    kw_main_words/2,            % +Key, -Words (the principal/longest synonym)
    indefinite_isa_words/2,     % +Noun, -Words ("is a"/"is an" rendering hook)
    kw_category_key/2,          % ?Category, ?Key
    class_member/2,             % +Class, +Word  (single-word class membership, active language)
    class_member/3,             % +Lang, +Class, +Word
    class_words/2,              % +Class, -Words:list(atom) (all single-word members, active language)
    class_word_list/2,          % +Class, -Words (cached list for the active language)
    % system templates (i18n/system_templates.csv)
    system_template_row/3,      % -Functor, -Types:list, -Parts:list  (active language; Parts: word atom | slot(N))
    system_template_row/4,      % +Lang, -Functor, -Types, -Parts
    % messages (i18n/messages.csv)
    le_msg/3,                   % +Id, +Pairs, -Atom  (active language, en fallback)
    le_msg/4,                   % +Lang, +Id, +Pairs, -Atom
    % UI chrome (i18n/ui.csv)
    ui_text/2,                  % +Key, -Text (active language, en fallback)
    ui_text/3,                  % +Lang, +Key, -Text
    % administration
    i18n_dir/1,
    reload_i18n/0
]).

:- use_module(library(csv)).
:- use_module(library(apply)).
:- use_module(library(lists)).

%   Everything Logical English reads is UTF-8 — the dictionaries under i18n/,
%   and the .le programs themselves, whose whole point is that they are written
%   in the author's own language ("um número", "é igual a"). SWI derives the
%   default file encoding from LANG/LC_ALL, which is plain `text` under e.g.
%   LANG=C, so under a non-UTF-8 locale every accented byte became U+FFFD:
%   the dictionaries failed to load, and a Portuguese program that was
%   perfectly well formed was reported as a malformed section. Stating the
%   encoding here removes the dependency on the ambient locale for every file
%   the system opens without saying otherwise. (This is the in-process
%   equivalent of exporting LANG=C.UTF-8, which is what users were told to do.)
:- set_prolog_flag(encoding, utf8).

%!  ensure_utf8_ctype is det.
%
%   Decoding the bytes is only half of it: code_type/2 — which the tokenizer
%   uses to decide what a word is — classifies characters through the C
%   library's LC_CTYPE. Under LANG=C, 'ã' is not `alpha` and not `csym`, so
%   "são" tokenized as three words and a Portuguese program that was perfectly
%   well formed came back as a malformed section. Switch LC_CTYPE to a UTF-8
%   locale when the ambient one cannot classify letters outside ASCII; if no
%   UTF-8 locale is installed, say so once, plainly, rather than leaving the
%   user to read the damage as an error in their own file.
ensure_utf8_ctype :-
    (   utf8_ctype_ok
    ->  true
    ;   member(Loc, ['C.UTF-8', 'C.utf8', 'en_US.UTF-8', 'UTF-8']),
        catch(setlocale(ctype, _, Loc), _, fail),
        utf8_ctype_ok
    ->  true
    ;   ( getenv('LANG', Lang) -> true ; Lang = '<unset>' ),
        print_message(warning,
            format('Logical English: no UTF-8 locale is installed (LANG=~w). Letters \c
outside ASCII will not be recognised as letters, so non-English LE programs will be \c
mis-tokenized and reported as malformed. Install/select a UTF-8 locale (e.g. \c
LANG=C.UTF-8).', [Lang]))
    ).

%   Latin small letter a with tilde (U+00E3) and e with acute (U+00E9) stand in
%   for every letter the ASCII-only ctype cannot see. Written as numeric codes,
%   not as literals: this very file would be mis-decoded under the locale the
%   check exists to detect.
utf8_ctype_ok :-
    code_type(0'\xE3\, csym),
    code_type(0'\xE9\, alpha).

:- thread_local active_language_flag/1.

:- dynamic kw_syn/4.            % kw_syn(Lang, Category, Key, Words:list(atom))
:- dynamic kw_word/4.           % kw_word(Lang, Category, Key, Word)  single-word synonyms
:- dynamic class_list_cache/3.  % class_list_cache(Lang, Key, Words) — materialized word lists
:- dynamic class_word/3.        % class_word(Lang, Key, Word) — materialized fast path
                                % (includes capitalised variants for determiner classes
                                % and English fallback rows for languages missing a key)
:- dynamic msg_entry/3.         % msg_entry(Lang, Id, Template:atom)
:- dynamic ui_entry/3.          % ui_entry(Lang, Key, Text:atom)
:- dynamic lang_entry/2.        % lang_entry(Code, params dict-like list)
:- dynamic sys_row/4.           % sys_row(Lang, Functor, Types:list(atom), Parts:list)
:- dynamic i18n_dir_cached/1.

% ---------------------------------------------------------------------------
% Active language
% ---------------------------------------------------------------------------

%!  le_active_language(-Lang) is det.
%
%   The active language for parsing/rendering on this thread. Defaults to en.
%   Kept in a (per-thread) global variable: this is read on the parser's
%   hottest paths (is_article/is_ignorable), where a dynamic-predicate lookup
%   is measurably slower.
le_active_language(Lang) :-
    ( nb_current(le_active_language, L), L \== [] -> Lang = L ; Lang = en ).

%!  set_le_language(+Lang) is det.
set_le_language(Lang) :-
    must_be(atom, Lang),
    ( Lang == default -> nb_setval(le_active_language, []) ; nb_setval(le_active_language, Lang) ).

%!  with_le_language(+Lang, :Goal) is nondet.
%
%   Runs Goal with the active language set to Lang, restoring the previous
%   language afterwards (also on failure/exception).
:- meta_predicate with_le_language(+, 0).
with_le_language(Lang, Goal) :-
    ( nb_current(le_active_language, Old0), Old0 \== [] -> Old = Old0 ; Old = default ),
    setup_call_cleanup(
        set_le_language(Lang),
        Goal,
        set_le_language(Old)).

% ---------------------------------------------------------------------------
% Language registry
% ---------------------------------------------------------------------------

known_language(Lang) :- lang_entry(Lang, _).

language_autonym(Lang, Autonym) :-
    lang_entry(Lang, Params),
    memberchk(autonym-Autonym, Params).

language_opener(Lang, Words) :-
    lang_entry(Lang, Params),
    memberchk(opener-Words, Params).

language_param(Lang, Param, Value) :-
    lang_entry(Lang, Params),
    memberchk(Param-Value, Params).

%!  detect_language_tokens(+Tokens, -Lang) is semidet.
%
%   Matches the first statement of a token list against every registered
%   language's opener phrase ("the target language is", "a linguagem alvo é",
%   ...). Fails when no opener matches (caller decides the default, per O-1).
detect_language_tokens(Tokens, Lang) :-
    skip_noise_tokens(Tokens, Ts),
    known_language(Lang),
    language_opener(Lang, OpenerWords),
    OpenerWords \== [],
    opener_prefix(OpenerWords, Ts),
    !.

opener_prefix([], _).
opener_prefix([W|Ws], Tokens0) :-
    skip_noise_tokens(Tokens0, [word(W0, _)|Rest]),
    W0 == W,
    opener_prefix(Ws, Rest).

skip_noise_tokens([indent(_, _)|Ts], Out) :- !, skip_noise_tokens(Ts, Out).
skip_noise_tokens([line_comment(_, _)|Ts], Out) :- !, skip_noise_tokens(Ts, Out).
skip_noise_tokens([multi_comment(_, _)|Ts], Out) :- !, skip_noise_tokens(Ts, Out).
skip_noise_tokens(Ts, Ts).

%!  localized_asset(+BaseNoExt, +Ext, -Path) is det.
%
%   Path of the active language's variant of a text asset: for language L
%   (other than en), Base.L.Ext when that file exists (also trying a '../'
%   prefix, mirroring how the assistants locate their assets), else Base.Ext
%   (again trying '../' when needed). E.g. localized_asset('docs/le_summary',
%   md, P) gives 'docs/le_summary.pt.md' for Portuguese when present.
localized_asset(Base, Ext, Path) :-
    le_active_language(Lang),
    (   Lang \== en,
        atomic_list_concat([Base, '.', Lang, '.', Ext], Localized),
        first_existing([Localized], P0)
    ->  Path = P0
    ;   atomic_list_concat([Base, '.', Ext], Plain),
        first_existing([Plain], P1)
    ->  Path = P1
    ;   atomic_list_concat([Base, '.', Ext], Path)
    ).

first_existing(Bases, Path) :-
    member(B, Bases),
    ( exists_file(B) -> Path = B
    ; atom_concat('../', B, Up), exists_file(Up) -> Path = Up
    ),
    !.

% ---------------------------------------------------------------------------
% Keywords
% ---------------------------------------------------------------------------

%!  kw_synonym_words(+Key, -Words) is nondet.
%
%   Words is one synonym expansion (a list of word atoms) of keyword Key in
%   the active language, longest synonyms first. Falls back to English when
%   the active language has no entry for Key.
kw_synonym_words(Key, Words) :-
    le_active_language(Lang),
    kw_synonym_words(Lang, Key, Words).

kw_synonym_words(Lang, Key, Words) :-
    ( kw_syn(Lang, _, Key, _) ->
        kw_syn(Lang, _, Key, Words)
    ;   kw_syn(en, _, Key, Words)
    ).

%!  indefinite_isa_words(+Noun, -Words) is det.
%
%   The words linking a value to its type when RENDERING "X is a <Noun>" text
%   (le_type_check goals, hypothesised templates). Per-language hook (§3.3 of
%   the multilingual plan): English chooses a/an phonologically; other
%   languages fall back to their principal is-a phrase — refine per language
%   as morphology support lands (O-8: minimal for now).
indefinite_isa_words(Noun, Words) :-
    le_active_language(Lang),
    indefinite_isa_words(Lang, Noun, Words).

indefinite_isa_words(en, Noun, [is, Art]) :-
    !,
    ( atom(Noun), atom_codes(Noun, [C|_]), memberchk(C, `aeiouAEIOU`)
    -> Art = an
    ;  Art = a
    ).
indefinite_isa_words(_, _, Words) :-
    ( kw_main_words(is_a, Words) -> true ; Words = [is, a] ).

%!  kw_main_words(+Key, -Words) is semidet.
%
%   The principal surface form of Key in the active language (the longest
%   synonym — the fully-spelled-out phrase). Used when GENERATING text.
kw_main_words(Key, Words) :-
    once(kw_synonym_words(Key, Words)).

kw_category_key(Category, Key) :-
    distinct(Category-Key, kw_syn(_, Category, Key, _)).

%!  class_member(+Class, +Word) is semidet.
%
%   Word belongs to the single-word class Class (article, ignorable, reserved,
%   qualifier, copula, meta_marker, ...) in the active language. For the
%   determiner classes (article, definite_article) a capitalised variant
%   ('The' for 'the') is also accepted, mirroring the historical English lists.
%
%   This sits on the parser's hottest path, so it is a single lookup against
%   the class_word/3 facts materialized at CSV-load time (which already carry
%   the capitalised variants and the English fallback for languages that lack
%   a class).
class_member(Class, Word) :-
    atom(Word),
    le_active_language(Lang),
    class_word(Lang, Class, Word).

class_member(Lang, Class, Word) :-
    atom(Word),
    class_word(Lang, Class, Word).

cap_allowed(article).
cap_allowed(article_narrow).
cap_allowed(definite_article).

initial_upper(Word, Upper) :-
    atom_codes(Word, [C|Cs]),
    code_type(C, lower(U)),   % code_type(+Lower, lower(-Upper))
    atom_codes(Upper, [U|Cs]).

%!  class_words(+Class, -Words) is det.
%
%   All single-word members of Class in the active language (without the
%   materialized capitalisation variants).
class_words(Class, Words) :-
    le_active_language(Lang),
    ( setof(W, kw_word_class(Lang, Class, W), Words) -> true
    ; setof(W, kw_word_class(en, Class, W), Words) -> true
    ; Words = [] ).

kw_word_class(Lang, Key, Word) :- kw_word(Lang, _, Key, Word).

%!  materialize_class_words is det.
%
%   Builds the class_word/3 fast-path table: for every language registered in
%   languages.csv (plus en), every single-word keyword entry — falling back to
%   the English rows for a (language, key) pair with no translation — plus the
%   initial-capital variants for the determiner classes (mirroring the
%   historical English lists [a, an, the, some, 'A', 'An', 'The', 'Some']).
materialize_class_words :-
    retractall(class_word(_, _, _)),
    retractall(class_list_cache(_, _, _)),
    findall(L, ( lang_entry(L, _) ; L = en ), Ls0),
    sort(Ls0, Langs),
    forall(member(Lang, Langs),
           forall(distinct(Key, kw_word(_, _, Key, _)),
                  materialize_key(Lang, Key))),
    forall(( member(Lang, Langs), distinct(Key, class_word(Lang, Key, _)) ),
           ( findall(W, class_word(Lang, Key, W), Ws),
             assertz(class_list_cache(Lang, Key, Ws)) )).

%!  class_word_list(+Class, -Words) is det.
%
%   The cached single-word member list of Class for the active language
%   (including materialized capitalisation variants). Callers on hot paths use
%   this to fetch the list once and memberchk against it, rather than paying a
%   class_member/2 lookup per word.
class_word_list(Class, Words) :-
    le_active_language(Lang),
    (   class_list_cache(Lang, Class, Words) -> true
    ;   class_list_cache(en, Class, Words) -> true
    ;   Words = []
    ).

materialize_key(Lang, Key) :-
    ( kw_word(Lang, _, Key, _) -> Src = Lang ; Src = en ),
    forall(kw_word(Src, _, Key, Word),
           ( assert_class_word(Lang, Key, Word),
             ( cap_allowed(Key), initial_upper(Word, Cap)
             -> assert_class_word(Lang, Key, Cap)
             ;  true )
           )).

assert_class_word(Lang, Key, Word) :-
    ( class_word(Lang, Key, Word) -> true ; assertz(class_word(Lang, Key, Word)) ).

% ---------------------------------------------------------------------------
% System templates
% ---------------------------------------------------------------------------

system_template_row(Functor, Types, Parts) :-
    le_active_language(Lang),
    system_template_row(Lang, Functor, Types, Parts).

system_template_row(Lang, Functor, Types, Parts) :-
    ( sys_row(Lang, _, _, _) ->
        sys_row(Lang, Functor, Types, Parts)
    ;   sys_row(en, Functor, Types, Parts)
    ).

% ---------------------------------------------------------------------------
% Messages
% ---------------------------------------------------------------------------

%!  le_msg(+Id, +Pairs, -Atom) is det.
%
%   Formats catalog message Id with named placeholders, e.g.
%   le_msg(missing_template_desc, [name-'the person flies'], Msg).
%   {newline} is predefined. Missing translations fall back to English;
%   an unknown Id yields a diagnostic placeholder rather than failing.
le_msg(Id, Pairs, Out) :-
    le_active_language(Lang),
    le_msg(Lang, Id, Pairs, Out).

le_msg(Lang, Id, Pairs, Out) :-
    (   msg_entry(Lang, Id, T), T \== ''
    ->  true
    ;   msg_entry(en, Id, T), T \== ''
    ->  true
    ;   format(atom(T), 'missing message: ~w', [Id])
    ),
    substitute_placeholders(T, ['newline'-'\n'|Pairs], Out).

%!  substitute_placeholders(+Template, +Pairs, -Out) is det.
%
%   Replaces every {name} in Template by the value paired with the atom name
%   in Pairs (rendered with ~w). Unknown placeholders are left verbatim so a
%   translator's typo is visible instead of crashing.
substitute_placeholders(Template, Pairs, Out) :-
    atom_codes(Template, Codes),
    subst_codes(Codes, Pairs, OutCodes),
    atom_codes(Out, OutCodes).

subst_codes([], _, []).
subst_codes([0'{|Cs], Pairs, Out) :-
    append(NameCodes, [0'}|Rest], Cs),
    \+ member(0'{, NameCodes),
    atom_codes(Name, NameCodes),
    memberchk(Name-Value, Pairs),
    !,
    format(codes(ValCodes), '~w', [Value]),
    subst_codes(Rest, Pairs, OutRest),
    append(ValCodes, OutRest, Out).
subst_codes([C|Cs], Pairs, [C|Out]) :-
    subst_codes(Cs, Pairs, Out).

% ---------------------------------------------------------------------------
% UI chrome strings
% ---------------------------------------------------------------------------

ui_text(Key, Text) :-
    le_active_language(Lang),
    ui_text(Lang, Key, Text).

ui_text(Lang, Key, Text) :-
    (   ui_entry(Lang, Key, Text0), Text0 \== ''
    ->  Text = Text0
    ;   ui_entry(en, Key, Text0), Text0 \== ''
    ->  Text = Text0
    ;   Text = Key   % English string is the canonical key: fall back to it
    ).

% ---------------------------------------------------------------------------
% CSV loading
% ---------------------------------------------------------------------------

i18n_dir(Dir) :-
    ( i18n_dir_cached(Dir) -> true
    ; module_property(le_i18n, file(File)),
      file_directory_name(File, Base),
      atomic_list_concat([Base, '/i18n'], Dir),
      assertz(i18n_dir_cached(Dir))
    ).

reload_i18n :-
    retractall(kw_syn(_, _, _, _)),
    retractall(kw_word(_, _, _, _)),
    retractall(msg_entry(_, _, _)),
    retractall(ui_entry(_, _, _)),
    retractall(lang_entry(_, _)),
    retractall(sys_row(_, _, _, _)),
    load_i18n.

%!  load_i18n is det.
%
%   Reads every dictionary under i18n/. A failure here is fatal and must SAY
%   so: with the tables empty, nothing downstream is broken visibly — the
%   keyword lexicon is gone, so every section header stops being recognised,
%   and le_msg/3 falls back to "missing message: <id>", which then gets
%   attached to whatever LE file happened to be loading. The user reads it as
%   a syntax error in their own file. So the reason is reported here, at the
%   point where it is still knowable, instead of leaking out downstream.
load_i18n :-
    i18n_dir(Dir),
    catch(load_i18n_files(Dir), E, i18n_load_failed(Dir, E)),
    !.
load_i18n :-
    i18n_dir(Dir),
    i18n_load_failed(Dir, failed).

load_i18n_files(Dir) :-
    load_languages_csv(Dir),
    load_keywords_csv(Dir),
    load_system_templates_csv(Dir),
    load_messages_csv(Dir),
    load_ui_csv(Dir),
    materialize_class_words.

%!  i18n_load_failed(+Dir, +Reason) is det.
%
%   Fails loudly, in English — the message catalog is exactly what is missing,
%   so this one string cannot come from it.
i18n_load_failed(Dir, Reason) :-
    (   Reason == failed
    ->  Detail = 'a dictionary is missing or malformed'
    ;   format(atom(Detail), '~p', [Reason])
    ),
    format(user_error,
           'FATAL: cannot read the Logical English i18n dictionaries in ~w~n\c
            ~8|reason: ~w~n\c
            ~8|Every keyword, template and diagnostic is read from those CSV files. Without~n\c
            ~8|them no LE file can be parsed, and diagnostics degrade to~n\c
            ~8|"missing message: <id>", which looks like an error in the LE file and is not.~n',
           [Dir, Detail]),
    throw(error(le_i18n_unavailable(Dir, Reason), _)).

:- multifile prolog:message//1.
prolog:message(error(le_i18n_unavailable(Dir, _), _)) -->
    [ 'cannot read the Logical English i18n dictionaries in ~w — see the FATAL line above'-[Dir] ].

%!  read_csv_rows(+File, -Header, -Rows) is det.
%
%   The dictionaries are UTF-8 whatever the machine's locale is, so the
%   encoding is stated rather than inherited from the `encoding` Prolog flag
%   (which follows LANG/LC_ALL and is plain `text` under e.g. LANG=C). Without
%   this, every accented row raised "Illegal multibyte Sequence", load_i18n
%   failed, and the empty message table then surfaced as
%   "missing message: <id>" attached to whatever LE file was being read — a
%   diagnostic that looks like a syntax error in the user's own file.
read_csv_rows(File, Header, Rows) :-
    csv_read_file(File, [Header0|Rows0],
                  [convert(false), match_arity(false), encoding(utf8)]),
    Header0 =.. [row|Header1],
    maplist(to_atom, Header1, Header),
    Rows = Rows0.

to_atom(X, A) :- ( atom(X) -> A = X ; term_to_atom(X, A) ).

cell_value(Row, Header, Col, Value) :-
    nth1(I, Header, Col),
    !,
    Row =.. [row|Cells],
    ( nth1(I, Cells, V0) -> true ; V0 = '' ),
    ( atom(V0) -> Value = V0
    ; number(V0) -> atom_number(Value, V0)
    ; string(V0) -> atom_string(Value, V0)
    ; term_to_atom(V0, Value)
    ).
cell_value(_, _, _, '').

lang_columns(Header, Langs) :-
    findall(L, ( member(L, Header),
                 \+ memberchk(L, [category, key, id, functor, types, code,
                                  autonym, opener, decimal_sep, thousands_sep,
                                  list_sep, status]) ),
            Langs).

% --- languages.csv ---
load_languages_csv(Dir) :-
    atomic_list_concat([Dir, '/languages.csv'], File),
    read_csv_rows(File, Header, Rows),
    forall(member(Row, Rows), load_language_row(Header, Row)).

load_language_row(Header, Row) :-
    cell_value(Row, Header, code, Code),
    Code \== '',
    cell_value(Row, Header, autonym, Autonym),
    cell_value(Row, Header, opener, OpenerAtom),
    split_phrase_words(OpenerAtom, OpenerWords),
    cell_value(Row, Header, decimal_sep, Dec),
    cell_value(Row, Header, thousands_sep, Thou),
    cell_value(Row, Header, list_sep, ListSep),
    cell_value(Row, Header, status, Status),
    cell_value(Row, Header, english_name, EnglishName),
    assertz(lang_entry(Code, [autonym-Autonym, opener-OpenerWords,
                              decimal_sep-Dec, thousands_sep-Thou,
                              list_sep-ListSep, status-Status,
                              english_name-EnglishName])).

% --- keywords.csv ---
load_keywords_csv(Dir) :-
    atomic_list_concat([Dir, '/keywords.csv'], File),
    read_csv_rows(File, Header, Rows),
    lang_columns(Header, Langs),
    forall(member(Row, Rows), load_keyword_row(Header, Langs, Row)).

load_keyword_row(Header, _Langs, Row) :-
    cell_value(Row, Header, category, Category),
    cell_value(Row, Header, key, Key),
    ( Category == '' ; Key == '' ), !.
load_keyword_row(Header, Langs, Row) :-
    cell_value(Row, Header, category, Category),
    cell_value(Row, Header, key, Key),
    forall(member(Lang, Langs),
           ( cell_value(Row, Header, Lang, Cell),
             ( Cell == '' -> true
             ; split_synonyms(Cell, Syns),
               % longest synonyms first (stable for equal lengths), so e.g.
               % "it is not the case that" is tried before "not the case that"
               % wherever order matters
               map_list_to_pairs(phrase_neg_length_key, Syns, Pairs),
               keysort(Pairs, SortedPairs),
               pairs_values(SortedPairs, Ordered),
               forall(member(Words, Ordered),
                      ( assertz(kw_syn(Lang, Category, Key, Words)),
                        ( Words = [OneWord]
                        -> assertz(kw_word(Lang, Category, Key, OneWord))
                        ;  true )
                      ))
             ))).

phrase_neg_length_key(Words, NL) :- length(Words, L), NL is -L.

split_synonyms(Cell, Syns) :-
    atomic_list_concat(Alts, '|', Cell),
    findall(Words, ( member(A, Alts), A \== '', split_phrase_words(A, Words), Words \== [] ), Syns).

split_phrase_words('', []) :- !.
split_phrase_words(Phrase, Words) :-
    atomic_list_concat(Parts0, ' ', Phrase),
    exclude(==(''), Parts0, Words).

% --- system_templates.csv ---
load_system_templates_csv(Dir) :-
    atomic_list_concat([Dir, '/system_templates.csv'], File),
    read_csv_rows(File, Header, Rows),
    lang_columns(Header, Langs),
    forall(member(Row, Rows), load_sys_row(Header, Langs, Row)).

load_sys_row(Header, Langs, Row) :-
    cell_value(Row, Header, functor, Functor),
    ( Functor == '' -> true
    ; cell_value(Row, Header, types, TypesAtom),
      split_phrase_words(TypesAtom, Types),
      forall(member(Lang, Langs),
             ( cell_value(Row, Header, Lang, Cell),
               ( Cell == '' -> true
               ; split_synonyms(Cell, Syns),
                 forall(member(Words, Syns),
                        ( maplist(word_to_part, Words, Parts),
                          assertz(sys_row(Lang, Functor, Types, Parts)) ))
               )))
    ).

word_to_part(Word, Part) :-
    (   atom_concat('{', Rest, Word),
        atom_concat(NAtom, '}', Rest),
        atom_number(NAtom, N)
    ->  Part = slot(N)
    ;   Part = Word
    ).

% --- messages.csv ---
load_messages_csv(Dir) :-
    atomic_list_concat([Dir, '/messages.csv'], File),
    read_csv_rows(File, Header, Rows),
    lang_columns(Header, Langs),
    forall(member(Row, Rows),
           ( cell_value(Row, Header, id, Id),
             ( Id == '' -> true
             ; forall(member(Lang, Langs),
                      ( cell_value(Row, Header, Lang, Cell),
                        ( Cell == '' -> true
                        ; assertz(msg_entry(Lang, Id, Cell)) )))
             ))).

% --- ui.csv ---
load_ui_csv(Dir) :-
    atomic_list_concat([Dir, '/ui.csv'], File),
    (   exists_file(File)
    ->  read_csv_rows(File, Header, Rows),
        lang_columns(Header, Langs),
        forall(member(Row, Rows),
               ( cell_value(Row, Header, key, Key),
                 ( Key == '' -> true
                 ; forall(member(Lang, Langs),
                          ( cell_value(Row, Header, Lang, Cell),
                            ( Cell == '' -> true
                            ; assertz(ui_entry(Lang, Key, Cell)) )))
                 )))
    ;   true
    ).

% The ctype locale has to be right BEFORE the dictionaries are parsed: the
% keyword and template rows are full of accented words, and splitting them
% into words uses the same character classification the tokenizer does.
:- initialization((ensure_utf8_ctype, load_i18n), now).
