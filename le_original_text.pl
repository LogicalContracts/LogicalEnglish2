:- module(le_original_text, [
    original_text_at/8,          % +SM, +KB, +Pos, +LineStart, +LineEnd, +Base, +Roles, -Reply
    original_files/3,            % +Base, +Roles, -Files
    locate_passage/5,            % +Keys, +Files, +Base, +Roles, -Found
    locate_passage/6             % +Keys, +Files, +Base, +Roles, +Prefer, -Found
]).

/** <module> View Original Text: the passage of the original under the cursor

    The editor's "View Original Text" (context menu and File menu) asks, for
    the construct under the cursor of a program, where its original text is.
    The answer, in order:

    1. a citation at the cursor (le_provenance:citation_at/6) whose document
       can be shown — the cited passage (`kind: citation`);
    2. the rule, fact, table, template, scenario or query under the cursor,
       found in the originals the program keeps — the files of the `sources/`
       folder beside it and the documents it says the text of is at — by the
       program's own links (`kind: passage`):
         - its label (`rule ps1:`, a table's or scenario's name), found as an
           identifier of the original;
         - the entries of the program's ledger (`<program>.ledger.json`, see
           le_migration.pl) whose `in_program` is that label or the template
           of the construct's predicate: their `element` — the element's text
           itself, the identifiers in it, a file it names;
         - the document the construct cites: its constant, the anchor of its
           published address, the identifiers of its locator;
    3. otherwise, when the program keeps originals, the originals themselves
       (`kind: originals`), saying no passage was located;
    4. otherwise `kind: none`.

    Nothing here knows any translator or format. An identifier is looked for
    as a word of the text (letters, digits, `_` and `-`), compared without
    case, `_` and `-` (`ps2_tblock1` is `ps2-tblock1`, `sec_504_cls_b` is
    `sec_504__cls_b`). An occurrence that DEFINES it is preferred over one that
    mentions it: an attribute or property naming it (`key="…"`, `id="…"`,
    `"name": "…"`, `name: …`), a key (`"…":`, `…:` starting a line), a head at
    the start of a line (`…(`, `… :-`, `… =`), a definition keyword before it
    (`def`, `function`, `rule`, ...), a heading. The passage is the element
    around it (an XML-like start tag up to its end tag) or the block that
    starts on its line (the lines indented under it, and a closing line).
    What the viewer shows of a file is its readable text
    (le_documents:document_text/4), so that is what is searched, and the
    passage is sent as a quote the viewer highlights.
*/

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(http/json)).
:- use_module(le_provenance).
:- use_module(le_documents).

%!  original_text_at(+SM, +KB, +Pos, +LineStart, +LineEnd, +Base, +Roles, -Reply:dict) is det.
%
%   LineStart and LineEnd bound the cursor's line (or `none`). Base is the
%   program's folder, or `-` for the KB's own (le_program_base/1).
original_text_at(SM, KB, Pos, LS, LE, Base0, Roles, Reply) :-
    ( Base0 == (-) -> program_base(KB, Base) ; Base = Base0 ),
    (   le_provenance:citation_at(KB, Pos, LS, LE, Prov, Rule0),
        le_provenance:provenance_dict(SM, KB, Prov, P0),
        ( get_dict(url, P0, U0), U0 \== null ; get_dict(text, P0, T0), T0 \== null )
    ->  ( Rule0 \== none, le_kbs:user_rule_name(Rule0) -> Rule = Rule0 ; Rule = null ),
        citation_passage(KB, Prov, P0, Base, Roles, P),
        Reply = _{kind: "citation", provenance: P, rule: Rule}
    ;   construct_at(KB, Pos, LS, LE, Construct)
    ->  construct_description(Construct, Desc),
        original_documents(SM, KB, Base, Roles, Files),
        (   Files == []
        ->  Reply = _{kind: "none", construct: Desc}
        ;   construct_keys(KB, Base, Construct, Keys, Hints),
            order_files(Hints, Files, Ordered),
            (   Keys \== [],
                construct_preference(Construct, Prefer),
                locate_passage(Keys, Ordered, Base, Roles, Prefer, found(File, Key, Via, S, E, Quote))
            ->  label_of(Construct, Label),
                get_dict(document, File, FileDoc), get_dict(text, File, FileText),
                ( S == null -> At = null ; At = [S, E] ),
                Reply = _{kind: "passage", construct: Desc, rule: Label, via: Via,
                          provenance: _{document: FileDoc, text: FileText,
                                        locator: Key, quote: Quote, at: At,
                                        source: null, rationale: null, url: null}}
            ;   hinted_files(Hints, Files, Hinted),
                Reply = _{kind: "originals", construct: Desc, files: Files, hinted: Hinted}
            )
        )
    ;   original_documents(SM, KB, Base, Roles, Files),
        (   Files == []
        ->  Reply = _{kind: "none", construct: null}
        ;   Reply = _{kind: "originals", construct: null, files: Files, hinted: []}
        )
    ).

program_base(KB, Base) :-
    (   atom(KB), KB \== none, catch(KB:le_program_base(B), _, fail), atom(B)
    ->  Base = B
    ;   Base = (-)
    ).

% ---------------------------------------------------------------------------
% A citation: as provenance_dict/4 says, plus — when it quotes nothing and
% names no lines — the passage its locator's identifiers define
% ("at MathVariable PremiumTaxMV").
% ---------------------------------------------------------------------------

citation_passage(_KB, prov(_, _, Loc, _), P0, Base, Roles, P) :-
    (   get_dict(text, P0, PT), PT \== null, get_dict(quote, P0, null),
        string(Loc), \+ le_lines_locator(Loc),
        locator_keys(Loc, Keys), Keys \== [],
        get_dict(document, P0, PD), Doc = _{document: PD, text: PT},
        locate_passage(Keys, [Doc], Base, Roles, found(_, _, _, S, E, Quote)),
        Quote \== null
    ->  put_dict(_{quote: Quote, at: [S, E]}, P0, P)
    ;   P = P0
    ).

% "line 12", "lines 2 to 9": the viewer takes those lines itself.
le_lines_locator(Loc) :-
    split_string(Loc, " ", " ", [W|_]),
    string_lower(W, WL),
    sub_string(WL, 0, _, _, "lin"), !.

locator_keys(Loc, Keys) :-
    words_of(Loc, Words),
    include(identifier_like, Words, Ids),
    findall(key(W, weak, citation), member(W, Ids), Keys).

% ---------------------------------------------------------------------------
% The construct under the cursor.
% ---------------------------------------------------------------------------

%!  construct_at(+KB, +Pos, +LS, +LE, -Construct) is semidet.
%
%   c(Kind, Label, Head, ID): Kind rule, fact, table, template, scenario, query;
%   Label its name or `none`; Head a term with the construct's predicate (or
%   `none`); ID the source id (a rule's id, for its provenance). The smallest
%   source range holding Pos, else — a label line before its rule — the one
%   starting on the next line.
construct_at(KB, Pos, LS, LE, Construct) :-
    atom(KB), KB \== none, integer(Pos),
    current_predicate(KB:le_source_info/4),
    findall(Len-r(Ref, ID),
            ( KB:le_source_info(Ref, S, E, ID), Ref \== none,
              integer(S), integer(E), S =< Pos, Pos =< E, Len is E - S ),
            Inside0),
    keysort(Inside0, Inside),
    (   integer(LE)
    ->  Next is LE + 2,
        findall(Len-r(Ref, ID),
                ( KB:le_source_info(Ref, S, E, ID), Ref \== none,
                  integer(S), integer(E), S > LS, S > Pos, S =< Next, Len is E - S ),
                Below0),
        keysort(Below0, Below)
    ;   Below = []
    ),
    append(Inside, Below, Candidates),
    member(_-r(Ref, ID), Candidates),
    catch(clause(KB:Item, Body, Ref), _, fail),
    item_construct(Item, Body, ID, Pos, Construct), !.

item_construct(scenario(Name, Facts), _, _, Pos, C) :- !,
    (   member(fact_with_source(Fact, FS, FE), Facts), FS =< Pos, Pos =< FE
    ->  C = c(fact, none, Fact, none)
    ;   C = c(scenario, Name, none, none)
    ).
item_construct(query_info(Name, _, _), _, _, _, c(query, Name, none, none)) :- !.
item_construct(le_dict(D), _, _, _, c(template, none, Head, none)) :- !,
    arg(1, D, [F|Args]), length(Args, A), functor(Head, F, A).
item_construct(Item, _, _, _, _) :-
    functor(Item, IF, IN),
    memberchk(IF/IN, [le_kb/1, le_expected/4, le_expected_changes/3, le_included_resource/3,
                      ontology/1, le_lps_item/3, le_lps_role/2, le_source_section/2,
                      le_issue/6, le_service/3, le_provenance_required/0, le_unknown/1]),
    !, fail.
item_construct(Head, le_table(Name, _), _, _, c(table, Name, Head, none)) :- !.
item_construct(Head, Body, ID, _, c(Kind, Label, Head, ID)) :-
    callable(Head),
    ( Body == true -> Kind = fact ; Kind = rule ),
    ( atom(ID), le_kbs:user_rule_name(ID) -> Label = ID ; Label = none ).

construct_preference(c(Kind, _, _, _), Prefer) :-
    ( memberchk(Kind, [rule, fact]) -> Prefer = head ; Prefer = any ).

label_of(c(Kind, Label, _, _), L) :-
    ( Label \== none, memberchk(Kind, [rule, table, fact]) -> atom_string(Label, L) ; L = null ).

construct_description(c(Kind, Label, _, _), _{kind: Kind, name: Name}) :-
    ( Label == none -> Name = null ; atom_string(Label, Name) ).

% ---------------------------------------------------------------------------
% The originals of a program.
% ---------------------------------------------------------------------------

%!  original_files(+Base, +Roles, -Files:list(string)) is det.
%
%   The text files of the `sources/` folder beside the program ("sources/…"),
%   sorted, at most 500.
original_files(Base, Roles, Files) :-
    (   atom(Base), Base \== (-),
        \+ sub_atom(Base, 0, _, _, 'http'),
        atomic_list_concat([Base, '/sources'], SDir), exists_directory(SDir),
        catch(restricted_paths:is_path_allowed(SDir, Roles), _, true)
    ->  findall(Rel,
                ( directory_member(SDir, F, [recursive(true)]),
                  exists_file(F), \+ binary_original(F),
                  atom_concat(SDir, '/', P), atom_concat(P, R, F),
                  atom_concat('sources/', R, Rel0), atom_string(Rel0, Rel) ),
                Files0),
        msort(Files0, Files1),
        length(Files1, N), ( N > 500 -> length(Files, 500), append(Files, _, Files1) ; Files = Files1 )
    ;   Files = []
    ).

%   Not text: the source viewer has nothing to show of these.
binary_original(F) :-
    file_name_extension(_, Ext0, F), downcase_atom(Ext0, Ext),
    memberchk(Ext, [pdf, png, jpg, jpeg, gif, zip, docx, xlsx, pptx, doc, xls, ppt, ico, woff, woff2, ttf, bin, exe, jar, class]).

%   The files of sources/ and the documents whose text the program says is
%   somewhere ("the text of <document> is at <address>"): _{document, text}.
original_documents(SM, KB, Base, Roles, Docs) :-
    original_files(Base, Roles, Files),
    findall(_{document: D, text: F},
            ( member(F, Files), sub_string(F, 8, _, 0, D) ),
            FromSources),
    findall(A-Doc,
            ( member(Pred, [le_text_at]),
              Goal =.. [Pred, Doc0, A0],
              (   atom(SM), SM \== none, catch(SM:Goal, _, fail)
              ;   atom(KB), KB \== none, catch(KB:Goal, _, fail)
              ),
              atom_string(A0, A), atom_string(Doc0, Doc),
              \+ binary_original(A) ),
            Stated0),
    findall(_{document: Doc, text: A},
            ( member(A-Doc, Stated0), \+ memberchk(A, Files) ),
            Stated1),
    remove_same_text(Stated1, Stated),
    append(Stated, FromSources, Docs).

remove_same_text([], []).
remove_same_text([D|Ds], [D|Rs]) :-
    get_dict(text, D, DT),
    exclude([X]>>get_dict(text, X, DT), Ds, Ds1),
    remove_same_text(Ds1, Rs).

hinted_files(Hints, Files, Hinted) :-
    findall(T, ( member(F, Files), file_hinted(Hints, F), get_dict(text, F, T) ), Hinted).

order_files(Hints, Files, Ordered) :-
    partition(file_hinted(Hints), Files, In, Out),
    append(In, Out, Ordered).

%   A hint names the file: its address, or a path the address ends with.
file_hinted(Hints, File) :-
    member(H, Hints),
    get_dict(text, File, FT), get_dict(document, File, FD),
    (   H == FT
    ;   H == FD
    ;   string_concat(_, H, FT), string_length(H, L), L > 3,
        sub_string(FT, B, _, L, _), B > 0,
        Before is B - 1, sub_string(FT, Before, 1, _, "/")
    ), !.

% ---------------------------------------------------------------------------
% What to look for: key(Text, Strength, Via), in order, and the files named.
% ---------------------------------------------------------------------------

construct_keys(KB, Base, c(Kind, Label, Head, ID), Keys, Hints) :-
    % its own name
    (   Label == none -> LabelKeys = []
    ;   memberchk(Kind, [scenario, query]) -> LabelKeys = [key(LabelS, weak, label)], atom_string(Label, LabelS)
    ;   atom_string(Label, LabelS), LabelKeys = [key(LabelS, strong, label)]
    ),
    % the ledger's entries about it
    ledger_entries(KB, Base, Entries),
    head_template(KB, Head, Template),
    head_words(Head, HeadWords),
    findall(E, ( member(E, Entries),
                 ledger_matches(E, Label, Template, HeadWords) ), Matching),
    findall(K, ( member(E, Matching), get_dict(element, E, El), element_keys(El, EK), member(K, EK) ), LedgerKeys),
    findall(H, ( member(E, Matching), get_dict(element, E, El), element_files(El, H) ), LedgerHints),
    % what it cites
    (   atom(ID), catch(KB:le_rule_provenance(ID, Prov), _, fail)
    ->  cited_keys(KB, Prov, CitedKeys, CitedHints)
    ;   CitedKeys = [], CitedHints = []
    ),
    append([LabelKeys, LedgerKeys, CitedKeys], Keys0),
    remove_duplicate_keys(Keys0, Keys),
    append(LedgerHints, CitedHints, Hints).

remove_duplicate_keys([], []).
remove_duplicate_keys([key(T, S, V)|Ks], [key(T, S, V)|Rs]) :-
    normalized_key(T, N),
    exclude([key(T2, _, _)]>>normalized_key(T2, N), Ks, Ks1),
    remove_duplicate_keys(Ks1, Rs).

head_template(KB, Head, Template) :-
    (   Head \== none, callable(Head), functor(Head, F, A),
        catch(le_kbs:template_of(KB, F, A, _, T), _, fail)
    ->  template_norm(T, Template)
    ;   Template = none
    ).

head_words(Head, Words) :-
    (   Head \== none, callable(Head), functor(Head, F, _)
    ->  atomic_list_concat(Ws, '_', F), maplist(atom_string, Ws, Words)
    ;   Words = []
    ).

%   A template as the ledger writes it and as template_of/5 does, compared
%   with its argument places as `*`: "*a person* is an infringer" is
%   "*person* is an infringer".
template_norm(T0, T) :-
    atom_string(T0, S0),
    string_codes(S0, Cs0),
    star_places(Cs0, Cs1),
    string_codes(S1, Cs1),
    normalize_space(string(S2), S1),
    string_lower(S2, S3),
    ( string_concat(S4, ".", S3) -> T = S4 ; T = S3 ).

star_places([], []).
star_places([0'*|Cs], [0'*|Rs]) :-
    once(( append(In, [0'*|Rest], Cs), \+ memberchk(0'*, In) )), !,
    star_places(Rest, Rs).
star_places([C|Cs], [C|Rs]) :- star_places(Cs, Rs).

%!  ledger_entries(+KB, +Base, -Entries:list(dict)) is det.
%
%   The entries of the ledger beside the program: `<name>.ledger.json`, the
%   one of the KB's name when there are several.
ledger_entries(KB, Base, Entries) :-
    (   atom(Base), Base \== (-), \+ sub_atom(Base, 0, _, _, 'http'),
        exists_directory(Base),
        directory_files(Base, Names),
        include([N]>>atom_concat(_, '.ledger.json', N), Names, Ledgers),
        Ledgers \== [],
        (   Ledgers = [One] -> Ledger = One
        ;   member(Ledger, Ledgers), atom_concat(Stem, '.ledger.json', Ledger),
            kb_name(KB, Stem) -> true
        ;   Ledgers = [Ledger|_]
        ),
        atomic_list_concat([Base, '/', Ledger], Path),
        catch(setup_call_cleanup(open(Path, read, In, [encoding(utf8)]),
                                 json_read_dict(In, J, [value_string_as(string)]),
                                 close(In)), _, fail)
    ->  (   is_dict(J), get_dict(entries, J, Es), is_list(Es) -> true
        ;   is_list(J) -> Es = J
        ;   Es = []
        ),
        include([E]>>( is_dict(E), get_dict(element, E, El), string(El),
                       get_dict(in_program, E, IP), string(IP) ), Es, Entries)
    ;   Entries = []
    ).

kb_name(KB, Stem) :-
    catch(KB:le_kb(Name), _, fail), Name == Stem, !.

%   An entry is about the construct when its `in_program` is the construct's
%   label (alone, or named in parentheses after a sentence), the template of
%   its predicate (bare or as `template "…"`), or one word of its predicate's
%   name that the program calls it by (a query or view named `anc` for
%   "*a thing* is the anc of *a second thing*").
ledger_matches(E, Label, Template, HeadWords) :-
    get_dict(in_program, E, IP0),
    normalize_space(string(IP), IP0),
    IP \== "",
    (   Label \== none, atom_string(Label, L),
        (   IP == L
        ;   format(string(Paren), "(~w)", [L]), string_concat(_, Paren, IP)
        ;   % one of the rules an element became: <in_program>_<n>
            string_concat(IP, Suffix, L),
            string_concat("_", N, Suffix), number_string(_, N)
        )
    ->  true
    ;   Template \== none,
        (   string_concat("template \"", R, IP), string_concat(T0, "\"", R) -> true ; T0 = IP ),
        strip_paren_suffix(T0, T1),
        sub_string(T1, _, _, _, "*"),
        template_norm(T1, T),
        T == Template
    ->  true
    ;   HeadWords \== [],
        identifier_text(IP),
        string_length(IP, Len), Len >= 2,
        memberchk(IP, HeadWords)
    ).

strip_paren_suffix(S0, S) :-
    (   string_concat(S1, ")", S0),
        sub_string(S1, B, _, _, " ("), \+ ( sub_string(S1, B2, _, _, " ("), B2 > B )
    ->  sub_string(S0, 0, B, _, S)
    ;   S = S0
    ).

identifier_text(S) :-
    string_codes(S, Cs), Cs \== [],
    forall(member(C, Cs), token_code(C)).

%   An element: its text itself when it is more than an identifier (a formula
%   the original writes, "and(pk(third_party),older(65535))"), then the
%   identifiers in it — the most identifier-like first.
element_keys(Element, Keys) :-
    normalize_space(string(El), Element),
    (   \+ identifier_text(El),
        string_length(El, L), L >= 4,
        \+ sub_string(El, _, _, _, "..."),
        \+ sub_string(El, _, _, _, " "),
        sub_string(El, _, _, _, "(")
    ->  Literal = [key(El, literal, ledger)]
    ;   Literal = []
    ),
    split_string(El, " ", "", Parts0),
    exclude(file_like, Parts0, Parts),
    atomic_list_concat(Parts, ' ', Rest),
    words_of(Rest, Words0),
    exclude([W]>>( string_length(W, WL), WL < 2 ), Words0, Words1),
    exclude([W]>>number_string(_, W), Words1, Words2),
    % an element written as a phrase ("the business event type") names
    % nothing to look for by its words; one or two words may be names
    % ("Rel Infringer/1", "anc/2")
    length(Words2, NW),
    ( NW =< 2 -> Words3 = Words2 ; include(identifier_like, Words2, Words3) ),
    predsort(by_identifier_likeness, Words3, Words),
    findall(key(W, weak, ledger), member(W, Words), TokenKeys),
    append(Literal, TokenKeys, Keys).

by_identifier_likeness(Order, A, B) :-
    likeness(A, LA), likeness(B, LB),
    (   LA > LB -> Order = (<)
    ;   LA < LB -> Order = (>)
    ;   compare(Order0, A, B), ( Order0 == (=) -> Order = (=) ; Order = Order0 )
    ).

likeness(W, L) :- ( identifier_like(W) -> L = 1 ; L = 0 ).

%   Looks made up rather than a word: a digit, `_` or `-` inside, or a capital
%   letter after the first.
identifier_like(W) :-
    string_codes(W, [_|Cs]),
    string_length(W, Len), Len >= 2,
    (   member(C, Cs), ( code_type(C, digit) ; C == 0'_ ; C == 0'- ; code_type(C, upper) )
    ->  true
    ), !.

capitalized(W) :-
    string_codes(W, [C|_]), code_type(C, upper), string_length(W, L), L >= 4.

file_like(P) :-
    ( sub_string(P, _, _, _, "/") ; file_name_extension(_, Ext, P), Ext \== '', atom_length(Ext, EL), EL =< 6,
      \+ sub_string(P, _, _, _, "(") ),
    \+ sub_string(P, 0, 1, _, "#"),
    sub_string(P, _, _, _, "."), !.

element_files(Element, File) :-
    split_string(Element, " ", ",;:", Parts),
    member(File, Parts),
    file_like(File).

%   A cited document: the constant naming it (a section written `sec_504_cls_b`),
%   the anchor of its published address, a file it is, the identifiers of the
%   locator.
cited_keys(KB, prov(_, Doc, Loc, _), Keys, Hints) :-
    (   Doc = doc(Const, Text)
    ->  atom_string(Const, CS),
        ( identifier_text(CS) -> K1 = [key(CS, strong, citation)] ; K1 = [] ),
        (   le_provenance:document_address(none, KB, le_published_at, Const, Url),
            sub_string(Url, B, _, _, "#"), B1 is B + 1,
            sub_string(Url, B1, _, 0, Anchor), Anchor \== ""
        ->  K2 = [key(Anchor, strong, citation)]
        ;   K2 = []
        ),
        (   le_provenance:document_address(none, KB, le_text_at, Const, TA) -> H1 = [TA] ; H1 = [] ),
        ( file_like(Text) -> H2 = [Text] ; H2 = [] ),
        append(H1, H2, Hints)
    ;   K1 = [], K2 = [], Hints = []
    ),
    ( string(Loc), \+ le_lines_locator(Loc) -> locator_keys(Loc, K3) ; K3 = [] ),
    append([K1, K2, K3], Keys).

% ---------------------------------------------------------------------------
% Finding a key in the originals.
% ---------------------------------------------------------------------------

%!  locate_passage(+Keys, +Files, +Base, +Roles, -Found) is semidet.
%!  locate_passage(+Keys, +Files, +Base, +Roles, +Prefer, -Found) is semidet.
%
%   Files are _{document, text} (text: the address documentText reads).
%   Found = found(File, KeyFound, Via, Start, End, Quote), the first of:
%     1. the first key, in order, that some file defines — when Prefer is
%        `head` (the construct is a rule or a fact), a definition as the head
%        of a clause first;
%     2. a file named by a strong key (a table's label that is the name of
%        the file it came from): the whole file, Start, End and Quote `null`;
%     3. the first strong or literal key some file mentions;
%     4. the first weak key that looks made up (or is capitalized) and that
%        some file mentions only a few times.
%   Start-End are offsets of the readable text; Quote the text between them.
locate_passage(Keys, Files, Base, Roles, Found) :-
    locate_passage(Keys, Files, Base, Roles, any, Found).

locate_passage(Keys, Files, Base, Roles, Prefer, Found) :-
    findall(F-T, ( member(F, Files), file_text(F, Base, Roles, T) ), Texts),
    Texts \== [],
    (   Prefer == head,
        member(key(K, _, Via), Keys),
        member(F-T, Texts),
        key_occurrence(T, K, definition(head), O, Len)
    ->  true
    ;   member(key(K, _, Via), Keys),
        member(F-T, Texts),
        key_occurrence(T, K, definition(_), O, Len)
    ->  true
    ;   member(key(K, strong, Via), Keys),
        identifier_text(K),
        normalized_key(K, NK),
        member(F-_, Texts),
        get_dict(text, F, Address),
        file_base_name(Address, BaseName),
        file_name_extension(Stem, _, BaseName),
        normalized_key(Stem, NK)
    ->  O = none
    ;   member(key(K, S, Via), Keys), memberchk(S, [literal, strong]),
        member(F-T, Texts),
        key_occurrence(T, K, _, O, Len)
    ->  true
    ;   member(key(K, weak, Via), Keys),
        ( identifier_like(K) -> Most = 10 ; capitalized(K) -> Most = 3 ; fail ),
        member(F-T, Texts),
        aggregate_all(count, key_occurrence(T, K, _, _, _), N), N > 0, N =< Most,
        key_occurrence(T, K, _, O, Len)
    ->  true
    ),
    (   O == none
    ->  atom_string(K, KeyFound),
        Found = found(F, KeyFound, Via, null, null, null)
    ;   T = t(Text, _),
        passage(Text, O, Len, S0, E0),
        sub_string(Text, O, Len, _, KeyFound),
        MaxLen = 20000,
        ( E0 - S0 > MaxLen -> E1 is S0 + MaxLen ; E1 = E0 ),
        Len1 is E1 - S0,
        sub_string(Text, S0, Len1, _, Quote),
        Found = found(F, KeyFound, Via, S0, E1, Quote)
    ).

% The readable text of an original (and its lower-case copy, to search),
% cached by path and modification time.
:- dynamic text_cache/4.

file_text(F, Base, Roles, t(Text, Lower)) :-
    get_dict(text, F, Address),
    \+ sub_string(Address, 0, _, _, "http"),
    atom(Base), Base \== (-),
    atomic_list_concat([Base, '/', Address], Path),
    exists_file(Path),
    time_file(Path, Stamp),
    size_file(Path, Size), Size =< 4 000 000,
    (   text_cache(Path, Stamp, Text0, Lower0)
    ->  Text = Text0, Lower = Lower0
    ;   catch(le_documents:document_text(Address, Base, Roles, Text), _, fail),
        string_lower(Text, Lower1),
        ( string_length(Text, L), string_length(Lower1, L) -> Lower = Lower1 ; Lower = Text ),
        retractall(text_cache(Path, _, _, _)),
        ( aggregate_all(count, text_cache(_, _, _, _), C), C > 50 -> retractall(text_cache(_, _, _, _)) ; true ),
        assertz(text_cache(Path, Stamp, Text, Lower))
    ).

%!  key_occurrence(+Texts, +Key, ?Kind, -Offset, -Length) is nondet.
%
%   An occurrence of Key in the text, in text order: a literal key as it is
%   written (Kind `mention`); an identifier as a whole word of the text equal
%   to it without case, `_` and `-` (Kind `definition(head)` — the head of a
%   clause at the start of a line —, `definition(other)` or `mention`).
key_occurrence(t(Text, Lower), Key, Kind, O, Len) :-
    (   identifier_text(Key)
    ->  normalized_key(Key, NK),
        string_length(NK, NL), NL >= 2,
        key_seed(Key, Seed),
        findall(O0-L0, seed_word(Text, Lower, Seed, NK, O0, L0), Os0),
        sort(Os0, Os),
        member(O-Len, Os),
        (   definition_at(Text, O, Len, DefKind) -> Kind0 = definition(DefKind) ; Kind0 = mention ),
        Kind = Kind0
    ;   sub_string(Text, O, Len, _, Key),
        Kind = mention
    ).

normalized_key(K, N) :-
    string_lower(K, L),
    split_string(L, "_-", "", Parts),
    atomic_list_concat(Parts, A), atom_string(A, N).

%   Where a word equal to the key could start: the key's first alphanumeric
%   run in lower case, found with sub_string/5 in the lower-case text (fast);
%   the whole word around it is then compared.
key_seed(Key, Seed) :-
    split_string(Key, "_-", "", Parts),
    include([P]>>(P \== ""), Parts, [First|_]),
    string_lower(First, Seed).

seed_word(Text, Lower, Seed, NK, O, Len) :-
    sub_string(Lower, B, _, _, Seed),
    word_bounds(Text, B, O, Len),
    sub_string(Text, O, Len, _, Word),
    normalized_key(Word, NK).

word_bounds(Text, B, Start, Len) :-
    string_length(Text, TL),
    word_start(Text, B, Start),
    word_end(Text, B, TL, End),
    Len is End - Start.

word_start(Text, B, S) :-
    (   B > 0, B1 is B - 1, sub_string(Text, B1, 1, _, C), string_code(1, C, Code), token_code(Code)
    ->  word_start(Text, B1, S)
    ;   S = B
    ).

word_end(Text, B, TL, E) :-
    (   B < TL, sub_string(Text, B, 1, _, C), string_code(1, C, Code), token_code(Code)
    ->  B1 is B + 1, word_end(Text, B1, TL, E)
    ;   E = B
    ).

token_code(C) :- code_type(C, alnum), !.
token_code(0'_).
token_code(0'-).

words_of(S, Words) :-
    string_codes(S, Cs),
    words_codes(Cs, Wss),
    maplist([W, Str]>>string_codes(Str, W), Wss, Words).

words_codes([], []) :- !.
words_codes([C|Cs], Ws) :-
    \+ token_code(C), !, words_codes(Cs, Ws).
words_codes(Cs, [W|Ws]) :-
    take_word(Cs, W, Rest), words_codes(Rest, Ws).

take_word([C|Cs], [C|W], Rest) :- token_code(C), !, take_word(Cs, W, Rest).
take_word(Rest, [], Rest).

%!  definition_at(+Text, +Offset, +Length, -Kind) is semidet.
%
%   The word at Offset is being defined, judged by the rest of its line:
%   Kind `head` when it starts the line as the head of a clause, else `other`.
definition_at(Text, O, Len, Kind) :-
    line_around(Text, O, LineStart, LineEnd),
    BL is O - LineStart,
    sub_string(Text, LineStart, BL, _, Before),
    AS is O + Len, AL is LineEnd - AS,
    sub_string(Text, AS, AL, _, After),
    string_lower(Before, B),
    defining_context(B, After), !,
    ( clause_head(B, After) -> Kind = head ; Kind = other ).

clause_head("", After) :-
    (   sub_string(After, 0, 1, _, "(")
    ;   strip_leading_blanks_quote(After, A), sub_string(A, 0, 2, _, ":-")
    ), !.

defining_context(B, _) :-                      % key="X", VARIABLENAME='X', xml:id="X"
    ( string_concat(B1, "\"", B) ; string_concat(B1, "'", B) ),
    strip_trailing_blanks(B1, B2), string_concat(B3, "=", B2),
    strip_trailing_blanks(B3, B4),
    naming_word_end(B4).
defining_context(B, _) :-                      % "id": "X", name: X
    (   string_concat(B1, "\"", B) -> true ; string_concat(B1, "'", B) -> true ; B1 = B ),
    strip_trailing_blanks(B1, B2), string_concat(B3, ":", B2),
    strip_trailing_blanks(B3, B4),
    ( string_concat(B5, "\"", B4) -> true ; B5 = B4 ),
    naming_word_end(B5).
defining_context(B, After) :-                  % "X": ... / X: ... starting a line
    ( string_concat(B1, "\"", B) -> true ; B1 = B ),
    only_blanks_or_dash(B1),
    strip_leading_blanks_quote(After, A),
    sub_string(A, 0, 1, _, ":"),
    \+ sub_string(A, 0, 2, _, "::").
defining_context("", After) :-                 % X(…) / X :- / X = / X { at the start of a line
    (   After == "" -> true
    ;   sub_string(After, 0, 1, _, C), memberchk(C, ["(", "."])
    ;   strip_leading_blanks_quote(After, A), A \== After,
        ( sub_string(A, 0, 2, _, ":-") ; sub_string(A, 0, 1, _, "=") ; sub_string(A, 0, 1, _, "{") )
    ), !.
defining_context(B, _) :-                      % def X, function X, rule X, # X
    normalize_space(string(N), B),
    split_string(N, " ", "", Ws),
    length(Ws, NW), NW =< 3,
    last(Ws, W),
    memberchk(W, ["def", "function", "fn", "rule", "let", "const", "var", "class",
                  "table", "policy", "macro", "view", "procedure", "define", "#pred",
                  "predicate", "struct", "type", "enum", "interface", "module",
                  "template", "contract", "choice", "#", "##", "###", "####"]).

naming_word_end(S) :-
    string_codes(S, Cs), reverse(Cs, Rs),
    take_word_rev(Rs, WRev), WRev \== [],
    reverse(WRev, W), string_codes(Word, W),
    (   member(Suffix, ["key", "id", "name", "label", "code"]),
        string_concat(_, Suffix, Word)
    ->  true
    ).

take_word_rev([C|Cs], [C|W]) :- ( code_type(C, alnum) ; C == 0'_ ; C == 0'- ; C == 0': ), !, take_word_rev(Cs, W).
take_word_rev(_, []).

strip_trailing_blanks(S0, S) :-
    ( string_concat(S1, " ", S0) -> strip_trailing_blanks(S1, S)
    ; string_concat(S1, "\t", S0) -> strip_trailing_blanks(S1, S)
    ; S = S0 ).

strip_leading_blanks_quote(S0, S) :-
    ( string_concat(" ", S1, S0) -> strip_leading_blanks_quote(S1, S)
    ; string_concat("\"", S1, S0) -> strip_leading_blanks_quote(S1, S)
    ; string_concat("'", S1, S0) -> strip_leading_blanks_quote(S1, S)
    ; S = S0 ).

only_blanks_or_dash(S) :-
    string_codes(S, Cs),
    forall(member(C, Cs), memberchk(C, [0' , 0'\t, 0'-])).

line_around(Text, O, LS, LE) :-
    string_length(Text, TL),
    line_start(Text, O, LS),
    ( sub_string(Text, O, _, 0, Rest), sub_string(Rest, NL, 1, _, "\n") -> LE is O + NL ; LE = TL ).

line_start(Text, O, LS) :-
    (   O > 0, O1 is O - 1, sub_string(Text, O1, 1, _, C), C \== "\n"
    ->  line_start(Text, O1, LS)
    ;   LS = O
    ).

% ---------------------------------------------------------------------------
% The passage around an occurrence.
% ---------------------------------------------------------------------------

%!  passage(+Text, +Offset, +Length, -Start, -End) is det.
%
%   The element whose start tag holds the occurrence; else the block of its
%   line — and, for the head of a clause, the clauses of the same head that
%   follow it.
passage(Text, O, _Len, S, E) :-
    in_start_tag(Text, O, TagStart, Name),
    element_end(Text, TagStart, Name, E0), !,
    S = TagStart, E = E0.
passage(Text, O, Len, S, E) :-
    line_around(Text, O, LS, LE),
    indentation_block(Text, LS, LE, S, E0),
    (   O =:= LS,
        definition_at(Text, O, Len, head)
    ->  sub_string(Text, O, Len, _, Word),
        following_clauses(Text, Word, E0, E)
    ;   E = E0
    ).

following_clauses(Text, Word, E0, E) :-
    string_length(Text, TL),
    (   next_nonblank_line(Text, TL, E0, LS, LE),
        string_length(Word, WL),
        sub_string(Text, LS, WL, _, Word),
        AS is LS + WL, AS < TL,
        sub_string(Text, AS, 1, _, C), \+ ( string_code(1, C, Code), token_code(Code) ),
        definition_at(Text, LS, WL, head)
    ->  indentation_block(Text, LS, LE, _, E1),
        following_clauses(Text, Word, E1, E)
    ;   E = E0
    ).

next_nonblank_line(Text, TL, From, LS, LE) :-
    From < TL,
    NS is From + 1, NS < TL,
    ( sub_string(Text, NS, _, 0, R), sub_string(R, NL, 1, _, "\n") -> NE is NS + NL ; NE = TL ),
    LL is NE - NS,
    sub_string(Text, NS, LL, _, Line),
    (   normalize_space(string(""), Line)
    ->  next_nonblank_line(Text, TL, NE, LS, LE)
    ;   LS = NS, LE = NE
    ).

%   Offset O is inside a start tag `<Name …` (possibly begun on earlier lines).
in_start_tag(Text, O, TagStart, Name) :-
    Window is min(O, 4000), From is O - Window,
    sub_string(Text, From, Window, _, Before),
    last_index(Before, "<", LT),
    ( last_index(Before, ">", GT) -> GT < LT ; true ),
    TagStart is From + LT,
    NameStart is TagStart + 1,
    sub_string(Text, NameStart, _, 0, AfterLT),
    string_codes(AfterLT, Cs),
    take_name(Cs, NameCs), NameCs = [First|_],
    code_type(First, alpha),
    string_codes(Name, NameCs).

take_name([C|Cs], [C|N]) :- ( code_type(C, alnum) ; memberchk(C, [0'_, 0'-, 0':, 0'.]) ), !, take_name(Cs, N).
take_name(_, []).

last_index(S, Sub, I) :-
    findall(B, sub_string(S, B, _, _, Sub), Bs), last(Bs, I).

%   The end of the element that starts at TagStart: after its start tag when
%   that closes itself, else after the matching end tag.
element_end(Text, TagStart, Name, End) :-
    sub_string(Text, TagStart, _, 0, From),
    sub_string(From, GT, 1, _, ">"), !,
    (   GT > 0, GT1 is GT - 1, sub_string(From, GT1, 1, _, "/")
    ->  End is TagStart + GT + 1
    ;   After is GT + 1,
        string_concat("<", Name, Open),
        string_concat("</", Name, Close),
        sub_string(From, After, _, 0, Rest),
        matching_close(Rest, Open, Close, 1, Off),
        sub_string(Rest, Off, _, 0, CloseRest),
        sub_string(CloseRest, G2, 1, _, ">"), !,
        End is TagStart + After + Off + G2 + 1
    ).

matching_close(Rest, Open, Close, Depth0, Off) :-
    findall(O-open, ( sub_string(Rest, O, _, _, Open), name_boundary(Rest, O, Open),
                      \+ self_closing_at(Rest, O) ), Opens),
    findall(C-close, ( sub_string(Rest, C, _, _, Close), name_boundary(Rest, C, Close) ), Closes),
    append(Opens, Closes, Events0),
    keysort(Events0, Events),
    close_at_depth(Events, Depth0, Off).

close_at_depth([At-Kind|Es], Depth, Off) :-
    (   Kind == open
    ->  D1 is Depth + 1, close_at_depth(Es, D1, Off)
    ;   D1 is Depth - 1,
        ( D1 =:= 0 -> Off = At ; close_at_depth(Es, D1, Off) )
    ).

name_boundary(S, At, Pat) :-
    string_length(Pat, L), P is At + L,
    (   sub_string(S, P, 1, _, C) -> \+ ( string_code(1, C, Code), ( code_type(Code, alnum) ; memberchk(Code, [0'_, 0'-, 0':, 0'.]) ) )
    ;   true
    ).

self_closing_at(S, O) :-
    sub_string(S, O, _, 0, From),
    sub_string(From, GT, 1, _, ">"), !,
    GT > 0, GT1 is GT - 1, sub_string(From, GT1, 1, _, "/").

%   A block by indentation: the line LS-LE, the lines after it indented more
%   deeply (and blank lines among them), and a closing line at its own depth
%   (`}`, `]`, `)`, `</…`, `end`).
indentation_block(Text, LS, LE, S, E) :-
    sub_string(Text, LS, _, 0, _),
    LL is LE - LS,
    sub_string(Text, LS, LL, _, Line),
    indent_of(Line, Ind),
    S is LS + Ind,
    string_length(Text, TL),
    block_lines(Text, TL, LE, Ind, LE, E0, 0),
    E = E0.

block_lines(Text, TL, Pos, Ind, Last, End, Count) :-
    (   Pos < TL, Count < 400,
        NS is Pos + 1, NS =< TL,
        ( sub_string(Text, NS, _, 0, R), sub_string(R, NL, 1, _, "\n") -> NE is NS + NL ; NE = TL ),
        LL is NE - NS,
        sub_string(Text, NS, LL, _, Line),
        normalize_space(string(Trim), Line)
    ->  (   Trim == ""
        ->  C1 is Count + 1,
            block_lines(Text, TL, NE, Ind, Last, End, C1)
        ;   indent_of(Line, I), I > Ind
        ->  C1 is Count + 1,
            block_lines(Text, TL, NE, Ind, NE, End, C1)
        ;   indent_of(Line, I), I =:= Ind, closing_line(Trim)
        ->  End = NE
        ;   End = Last
        )
    ;   End = Last
    ).

indent_of(Line, N) :-
    string_codes(Line, Cs),
    take_blanks(Cs, 0, N).

take_blanks([C|Cs], N0, N) :- memberchk(C, [0' , 0'\t]), !, N1 is N0 + 1, take_blanks(Cs, N1, N).
take_blanks(_, N, N).

closing_line(T) :-
    (   sub_string(T, 0, 1, _, C), memberchk(C, ["}", "]", ")"])
    ;   sub_string(T, 0, 2, _, "</")
    ;   sub_string(T, 0, 3, _, "end")
    ), !.
