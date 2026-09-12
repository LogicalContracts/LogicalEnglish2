/** <module> Provenance-bearing facts

    A scenario fact (or a knowledge-base fact) may carry trailers saying who
    asserts it, where it is written and why:

        the burst pipe is accidental,
            according to the loss adjuster, as stated in report LA-17 at page 3,
            because "corrosion was not visible on inspection".

    The fact itself is compiled exactly as before — proof is unaffected. Its
    provenance is recorded beside it, keyed by the fact's source range:

        le_fact_provenance(Start, End, Head, prov(Source, Document, Locator, Rationale))

    with Source a constant (or `none`), Document `doc(Constant, VerbatimText)`
    (or `none`), Locator and Rationale strings (or `none`). A reasoning session
    loaded with a scenario gets the public form, one clause per fact:

        le_provenance(Fact, Source, Document, Locator, Rationale)

    where Source is the EFFECTIVE source (the document, when no `according to`
    was given) and Document is its verbatim text. Source-scoped proof reads it,
    explanations render it, and nothing else in the engine depends on it.
*/

:- module(le_provenance, [
    record_fact_provenance/5,     % +M, +CompiledItem, +TrailerTokens, +Start, +End
    record_rule_provenance/5,     % +M, +RuleID, +Tokens, +Start, +End
    with_default_provenance/2,    % +Default, :Goal
    default_provenance/1,         % -Default
    scenario_default_provenance/6,
    record_default_provenance/5,
    rule_provenance/3,            % +KB, +RuleID, -Prov
    provenance_dict/4,            % +SM, +KB, +Prov, -Dict
    quote_in_text/2,              % +Quote, +Text
    normalized_text/2,            % +Text, -Norm
    quote_in_normalized/2,        % +Quote, +Norm
    quoted_text/2,                % +Locator, -Quote
    same_document/2,              % +Doc1, +Doc2
    parse_provenance_trailers/2,  % +Tokens, -Prov
    prov_effective_source/2,      % +Prov, -Source
    prov_public/5,                % +Prov, -Source, -Document, -Locator, -Rationale
    with_provenance_sink/2,       % :Goal, -Collected   (custom scenario text)
    add_scenario_provenance/3,    % +SM, +KB, +ScenarioTerms
    clause_provenance/5,          % +SM, +KB, +Ref, +Goal, -Prov
    provenance_suffix/2,          % +Prov, -Suffix:string
    is_judged_goal/2,             % +KB, +Goal
    citation_spans/2,             % +KB, -Spans
    citation_at/6                 % +KB, +Pos, +LineStart, +LineEnd, -Prov, -Rule
]).

:- use_module(le_i18n).

% While parsing custom scenario text (the editor's free-form scenario), the
% source offsets are relative to that text, not to the program: its provenance
% is collected here and handed back as le_provenance/5 terms instead of being
% recorded in the knowledge base against meaningless ranges.
:- thread_local provenance_sink/0, sunk_provenance/2.

%!  record_fact_provenance(+M, +Item, +Trailers, +Start, +End) is det.
%
%   Records the provenance of the compiled fact Item (clause(Head, ...)) whose
%   source range is Start-End. Malformed trailers are reported as a warning
%   against the fact; a fact whose template did not match already has its own
%   error and records nothing.
record_fact_provenance(M, Item, Trailers, Start, End) :-
    (   Item = clause(Head, _, _, _, _), compound(Head),
        \+ functor(Head, unknown_template, _)
    ->  (   parse_provenance_trailers(Trailers, Prov0)
        ->  with_default(Prov0, Prov),
            store_provenance(M, Start, End, Head, Prov)
        ;   malformed_provenance(M, Start, End)
        )
    ;   true
    ).

% A scenario's default provenance ("scenario s is, as stated in <document>:")
% while its facts are compiled: a fact with no trailers takes it; a fact whose
% trailers name no document ("confer \"...\"", "according to X") takes its
% document; a fact that names its own document keeps its own provenance.
:- thread_local current_default_provenance/1.

%!  with_default_provenance(+Default, :Goal) is semidet.
:- meta_predicate with_default_provenance(+, 0).
with_default_provenance(none, Goal) :- !, call(Goal).
with_default_provenance(Default, Goal) :-
    setup_call_cleanup(asserta(current_default_provenance(Default), Ref),
                       Goal,
                       erase(Ref)).

default_provenance(Default) :-
    current_default_provenance(Default), !.

%!  scenario_default_provenance(+M, +Name, +Tokens, +Start, +End, -Default) is det.
scenario_default_provenance(M, Name, Tokens0, Start, End, Default) :-
    exclude(le_grammar:is_indent_or_comment, Tokens0, Tokens),
    (   parse_provenance_trailers(Tokens, Default)
    ->  (   nonvar(M), M \== (-)
        ->  assertz(M:le_scenario_provenance(Name, Default))
        ;   true
        )
    ;   malformed_provenance(M, Start, End),
        Default = none
    ).

%!  record_default_provenance(+M, +Item, +Default, +Start, +End) is det.
record_default_provenance(M, Item, Default, Start, End) :-
    (   Item = clause(Head, _, _, _, _), compound(Head),
        \+ functor(Head, unknown_template, _)
    ->  store_provenance(M, Start, End, Head, Default)
    ;   true
    ).

% A fact's own provenance, completed by the default in force.
with_default(Prov0, Prov) :-
    (   default_provenance(prov(DS, DD, DL, _)),
        Prov0 = prov(S0, none, L0, R0)
    ->  ( S0 == none -> S = DS ; S = S0 ),
        ( L0 == none -> L = DL ; L = L0 ),
        Prov = prov(S, DD, L, R0)
    ;   Prov = Prov0
    ).

store_provenance(_M, _Start, _End, Head, Prov) :-
    provenance_sink, !,
    assertz(sunk_provenance(Head, Prov)).
store_provenance(M, Start, End, Head, Prov) :-
    (   nonvar(M), M \== (-)
    ->  assertz(M:le_fact_provenance(Start, End, Head, Prov))
    ;   true
    ).

malformed_provenance(M, Start, End) :-
    (   nonvar(M), M \== (-)
    ->  le_msg(malformed_provenance_desc, [], Desc),
        le_msg(malformed_provenance_fix, [], Fix),
        assertz(M:le_issue(warning, malformed_provenance, Desc, Fix, Start, End))
    ;   true
    ).

%!  record_rule_provenance(+M, +ID, +Tokens, +Start, +End) is det.
%
%   Records the provenance of the rule labelled ID ("rule ID with provenance
%   <Tokens>: ..."), as le_rule_provenance(ID, Prov) — Prov as for a fact. The
%   provenance is either the trailers of a fact (it opens with according to /
%   as stated in / because) or a single quoted string (a URL or a citation),
%   read as `as stated in <string>`. Anything else is kept verbatim as the
%   document, with a malformed_provenance warning when trailers do not parse.
record_rule_provenance(M, ID, Tokens0, Start, End) :-
    exclude(le_grammar:is_indent_or_comment, Tokens0, Tokens),
    (   le_grammar:starts_with_trailer_keyword(Tokens),
        parse_provenance_trailers(Tokens, Prov0)
    ->  Prov = Prov0                        % the trailers of a fact
    ;   light_provenance(Tokens, Prov0)
    ->  Prov = Prov0                        % <document> [at <locator>] [, confer "..."]
    ;   malformed_provenance(M, Start, End),
        Prov = none
    ),
    (   Prov \== none, nonvar(M), M \== (-)
    ->  assertz(M:le_rule_provenance(ID, Prov)),
        % The rule's own range starts at its head; the label's provenance —
        % where the author wrote which document the rule cites — comes before.
        (   Tokens = [First|_], le_grammar:get_token_start(First, PS), integer(PS), PS > 0
        ->  SpanStart is min(PS, Start)
        ;   SpanStart = Start
        ),
        assertz(M:le_rule_provenance_span(ID, SpanStart, End))
    ;   true
    ).

% The light form of a rule's (or table's) provenance: a document — a name, or
% a quoted string such as a URL — optionally "at <locator>", optionally
% followed by (", ") confer "<passage>" and other trailers.
light_provenance(Tokens, Prov) :-
    Tokens \== [],
    (   append(DocPart, [Sep|Rest], Tokens),
        (   le_grammar:comma_part(Sep), le_grammar:starts_with_trailer_keyword(Rest)
        ->  TrailerToks = Rest
        ;   le_grammar:starts_with_trailer_keyword([Sep|Rest])
        ->  TrailerToks = [Sep|Rest]
        )
    ->  true
    ;   DocPart = Tokens, TrailerToks = []
    ),
    (   DocPart == []
    ->  D = none, L0 = none
    ;   split_locator(DocPart, DocToks, LocToks),
        document_parts(DocToks, Const, Text),
        D = doc(Const, Text),
        ( LocToks == [] -> L0 = none ; locator_text(LocToks, L0) )
    ),
    (   TrailerToks == []
    ->  Prov = prov(none, D, L0, none)
    ;   parse_provenance_trailers(TrailerToks, prov(S, D1, L1, R)),
        ( D1 == none -> D2 = D ; D2 = D1 ),
        ( L1 == none -> L = L0 ; L = L1 ),
        Prov = prov(S, D2, L, R)
    ).

%!  rule_provenance(+KB, +ID, -Prov) is semidet.
rule_provenance(KB, ID, Prov) :-
    atom(KB), KB \== none,
    current_predicate(KB:le_rule_provenance/2),
    KB:le_rule_provenance(ID, Prov), !.

%!  provenance_dict(+SM, +KB, +Prov, -Dict) is det.
%
%   The provenance as the editor shows it: who, which document, where in it,
%   why — plus `url`, the address to open (the document when it is a URL, else
%   its published address, "<document> is published at <address>"), and
%   `text`, the address of the document's text when the program gives one
%   ("the text of <document> is at <address>"), so the editor can show the
%   passage quoted by the locator.
provenance_dict(SM, KB, Prov, Dict) :-
    Prov = prov(Src0, D, Loc0, Rat0),
    ( Src0 == none -> Src = null ; term_string_plain(Src0, Src) ),
    (   D = doc(Const, Text)
    ->  Doc = Text,
        atom_string(Const, ConstS),
        ( document_address(SM, KB, le_published_at, Const, U) -> Url0 = U
        ; is_url_text(ConstS) -> Url0 = ConstS
        ; Url0 = null ),
        ( document_address(SM, KB, le_text_at, Const, T) -> TextAt = T ; TextAt = null )
    ;   Doc = null, Url0 = null, TextAt = null
    ),
    ( Loc0 == none -> Loc = null ; Loc = Loc0 ),
    ( Loc0 \== none, quoted_text(Loc0, Q) -> Quote = Q ; Quote = null ),
    ( Rat0 == none -> Rat = null ; Rat = Rat0 ),
    Dict = _{source: Src, document: Doc, locator: Loc, quote: Quote,
             rationale: Rat, url: Url0, text: TextAt}.

%!  quote_in_text(+Quote, +Text) is semidet.
%
%   Quote occurs in Text, white space collapsed — and, failing that, letter
%   case ignored. (The editor's source viewer finds it the same way.)
quote_in_text(Quote, Text) :-
    normalized_text(Text, Norm),
    quote_in_normalized(Quote, Norm).

%!  normalized_text(+Text, -Norm) is det.
%
%   Text prepared for quote_in_normalized/2: Unicode spaces as plain ones,
%   white space collapsed, and a lower-case copy — norm(Exact, Lower).
normalized_text(Text, norm(T, TL)) :-
    plain_spaces(Text, Text1),
    normalize_space(string(T), Text1),
    string_lower(T, TL).

quote_in_normalized(Quote, norm(T, TL)) :-
    plain_spaces(Quote, Quote1),
    normalize_space(string(Q), Quote1),
    Q \== "",
    (   sub_string(T, _, _, _, Q)
    ->  true
    ;   string_lower(Q, QL),
        sub_string(TL, _, _, _, QL)
    ).

% Unicode spaces (no-break, thin, ...) as plain ones: documents copied from
% the web are full of them, and a quotation typed by hand has none.
plain_spaces(S0, S) :-
    string_codes(S0, Cs0),
    maplist(plain_space, Cs0, Cs),
    string_codes(S, Cs).

plain_space(C0, C) :-
    (   memberchk(C0, [0xA0, 0x1680, 0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005,
                       0x2006, 0x2007, 0x2008, 0x2009, 0x200A, 0x202F, 0x205F, 0x3000])
    ->  C = 0' 
    ;   C = C0
    ).

% The text inside a quoted locator: the passage it quotes.
quoted_text(Loc, Quote) :-
    string_concat("\"", Rest, Loc),
    string_concat(Quote, "\"", Rest).

term_string_plain(T, S) :- ( atom(T) ; string(T) ), !, atom_string(T, S).
term_string_plain(T, S) :- term_string(T, S).

is_url_text(Text) :-
    ( sub_string(Text, 0, _, _, "http://") ; sub_string(Text, 0, _, _, "https://") ), !.

% "<document> is published at <address>" / "the text of <document> is at
% <address>" (built-in templates), as facts of the session or the program.
document_address(SM, KB, F, Doc, Address) :-
    Goal =.. [F, Doc0, Address0],
    (   atom(SM), SM \== none, catch(SM:Goal, _, fail)
    ;   atom(KB), KB \== none, catch(KB:Goal, _, fail)
    ;   % stated in a scenario rather than in the knowledge base
        atom(KB), KB \== none,
        catch(KB:scenario(_, Terms), _, fail),
        member(T, Terms),
        ( T = fact_with_source(Goal, _, _) ; T = Goal )
    ),
    same_document(Doc0, Doc), !,
    atom_string(Address0, Address).

same_document(A, B) :- A == B, !.
same_document(A, B) :- atomic(A), atomic(B), atom_string(A, S), atom_string(B, S).

%!  with_provenance_sink(:Goal, -Collected) is semidet.
%
%   Runs Goal (a parse of custom scenario text) collecting the provenance of
%   its facts as le_provenance(Fact, Source, Document, Locator, Rationale)
%   terms, ready to be added to a session like any other scenario fact.
:- meta_predicate with_provenance_sink(0, -).
with_provenance_sink(Goal, Collected) :-
    setup_call_cleanup(
        ( retractall(sunk_provenance(_, _)), assertz(provenance_sink) ),
        Goal,
        retractall(provenance_sink)),
    findall(le_provenance(H, S, D, L, R),
            ( retract(sunk_provenance(H, Prov)), prov_public(Prov, S, D, L, R) ),
            Collected).

% ---------------------------------------------------------------------------
% Trailer parsing
% ---------------------------------------------------------------------------

%!  parse_provenance_trailers(+Tokens, -Prov) is semidet.
%
%   Tokens are the trailers of one fact, each opening with its keyword and
%   separated by commas. Fails when a trailer is empty or repeated.
parse_provenance_trailers(Tokens0, Prov) :-
    exclude(le_grammar:is_indent_or_comment, Tokens0, Tokens),
    trailer_groups(Tokens, Groups),
    Groups \== [],
    foldl(apply_trailer, Groups, prov(none, none, none, none), Prov).

% Split at every comma that is followed by a trailer keyword.
trailer_groups([], []).
trailer_groups(Tokens, [Group|Groups]) :-
    Tokens \== [],
    (   append(Group, [Comma|Rest], Tokens),
        le_grammar:comma_part(Comma),
        le_grammar:starts_with_trailer_keyword(Rest)
    ->  trailer_groups(Rest, Groups)
    ;   Group = Tokens, Groups = []
    ).

apply_trailer(Group, prov(S0, D0, L0, R0), prov(S, D, L, R)) :-
    (   trailer_body(according_to, Group, Rest)
    ->  S0 == none, Rest \== [],
        token_constant(Rest, S), D = D0, L = L0, R = R0
    ;   trailer_body(as_stated_in, Group, Rest)
    ->  D0 == none, Rest \== [],
        split_locator(Rest, DocToks, LocToks),
        DocToks \== [],
        document_parts(DocToks, DocConst, DocText),
        D = doc(DocConst, DocText),
        ( LocToks == [] -> L = L0 ; locator_text(LocToks, L) ),
        S = S0, R = R0
    ;   trailer_body(confer, Group, Rest)
    ->  % confer "<passage>": the passage of the document (quoted locator)
        L0 == none, Rest \== [],
        locator_text(Rest, L),
        S = S0, D = D0, R = R0
    ;   trailer_body(because, Group, Rest)
    ->  R0 == none, Rest \== [],
        (   Rest = [StrTok], token_string(StrTok, Str) -> R = Str
        ;   verbatim(Rest, R)
        ),
        S = S0, D = D0, L = L0
    ).

trailer_body(Key, Tokens, Rest) :-
    le_i18n:kw_synonym_words(Key, Words),
    le_grammar:tokens_word_prefix(Words, Tokens, Rest), !.

% "report LA-17 at page 3": the document, and the locator after its LAST
% locator word (a document name rarely contains "at"; a locator never does).
split_locator(Tokens, DocToks, LocToks) :-
    (   append(DocToks, [AtTok|LocToks], Tokens),
        DocToks \== [], LocToks \== [],
        le_grammar:extract_simple_word(AtTok, W),
        le_i18n:class_member(at_locator, W),
        \+ ( member(T, LocToks), le_grammar:extract_simple_word(T, W2),
             le_i18n:class_member(at_locator, W2) )
    ->  true
    ;   DocToks = Tokens, LocToks = []
    ).

% A document is a constant ("report LA-17"), or a quoted string — a URL, or a
% citation with punctuation of its own — standing for itself.
document_parts([Tok], Const, Text) :-
    token_string(Tok, Str), !,
    atom_string(Const, Str),
    verbatim([Tok], Text).
document_parts(Toks, Const, Text) :-
    token_constant(Toks, Const),
    verbatim(Toks, Text).

% A locator is its verbatim text — a quoted locator (a quotation of the
% passage) keeps its quotes, which is how provenance_dict/4 knows it is one.
locator_text(Toks, Text) :-
    verbatim(Toks, Text).

token_string(string(S, _), S).
token_string(doubleQuoteString(S, _), S).
token_string(quoteString(S, _), S).

%   A source or document is an ordinary constant, read exactly as a scenario
%   argument is: "the loss adjuster" names the individual 'the loss adjuster',
%   which is also what `according to the loss adjuster` names in a rule.
token_constant(Tokens, Value) :-
    le_grammar:extract_value_from_parts(Tokens, Value, [], _, [], true, indefinite, 0).

% The verbatim source text spanned by Tokens (falling back to a rebuild from
% the tokens when the text is not at hand).
verbatim(Tokens, Text) :-
    Tokens = [First|_], last(Tokens, Last),
    le_grammar:get_token_start(First, S),
    le_grammar:get_token_end(Last, E),
    (   S > 0, le_grammar:source_substring(S, E, Text0)
    ->  Text = Text0
    ;   tokenizer:tokens_to_string(Tokens, Text1),
        ( string(Text1) -> Text = Text1 ; atom_string(Text1, Text) )
    ).

% ---------------------------------------------------------------------------
% Reading provenance back
% ---------------------------------------------------------------------------

%!  prov_effective_source(+Prov, -Source) is det.
%
%   Who asserts the fact: the `according to` source, else the document (a
%   fact "as stated in" a document with no `according to` has the document as
%   its source), else `none`.
prov_effective_source(prov(S, D, _, _), Source) :-
    (   S \== none -> Source = S
    ;   D = doc(Const, _) -> Source = Const
    ;   Source = none
    ).

%!  prov_public(+Prov, -Source, -Document, -Locator, -Rationale) is det.
prov_public(Prov, Source, Document, Locator, Rationale) :-
    Prov = prov(_, D, Locator, Rationale),
    prov_effective_source(Prov, Source),
    ( D = doc(_, Text) -> Document = Text ; Document = none ).

%!  add_scenario_provenance(+SM, +KB, +Terms) is det.
%
%   Asserts le_provenance/5 in session SM for every fact of a scenario (the
%   fact_with_source/3 terms of scenario/2) that carries provenance.
add_scenario_provenance(SM, KB, Terms) :-
    (   atom(KB), KB \== none, current_predicate(KB:le_fact_provenance/4)
    ->  forall(( member(fact_with_source(F, S, E), Terms),
                 ( F = (H :- _) -> true ; H = F ),
                 provenance_at(KB, S, E, H, Prov) ),
               ( prov_public(Prov, Src, Doc, Loc, Rat),
                 assertz(SM:le_provenance(H, Src, Doc, Loc, Rat)) ))
    ;   true
    ).

%!  clause_provenance(+SM, +KB, +Ref, +Goal, -Prov) is semidet.
%
%   The provenance of the clause Ref (a session or knowledge-base fact) that
%   proved Goal. Looked up by the clause's source range first (the precise,
%   parse-time record), then by the fact itself in the session's
%   le_provenance/5 (facts added from custom scenario text).
clause_provenance(SM, KB, Ref, _Goal, Prov) :-
    atom(KB), KB \== none,
    current_predicate(KB:le_fact_provenance/4),
    (   catch(SM:le_source_info(Ref, S, E, _), _, fail)
    ;   catch(KB:le_source_info(Ref, S, E, _), _, fail)
    ),
    integer(S),
    (   catch(clause(SM:Head, _, Ref), _, fail) -> true
    ;   catch(clause(KB:Head, _, Ref), _, fail) -> true
    ;   true
    ),
    provenance_at(KB, S, E, Head, Prov), !.
clause_provenance(SM, _KB, Ref, _Goal, prov(Src, Doc, Loc, Rat)) :-
    catch(clause(SM:Head, true, Ref), _, fail),
    current_predicate(SM:le_provenance/5),
    SM:le_provenance(H, Src, Doc0, Loc, Rat),
    H =@= Head, !,
    ( Doc0 == none -> Doc = none ; Doc = doc(Doc0, Doc0) ).

%!  provenance_at(+KB, +Start, +End, ?Head, -Prov) is nondet.
%
%   The provenance recorded for the fact Head at Start-End. Ranges are offsets
%   into the file that holds the fact, so a fact of an included resource can
%   share its range with one of the including program: the head tells them
%   apart (an unknown Head matches any).
provenance_at(KB, S, E, Head, Prov) :-
    KB:le_fact_provenance(S, E, H, Prov),
    (   var(Head) -> true
    ;   \+ \+ H = Head
    ).

%!  provenance_suffix(+Prov, -Suffix:string) is det.
%
%   The trailers as the author wrote them, for appending to a rendered fact:
%   ", according to the loss adjuster, as stated in report LA-17 at page 3".
provenance_suffix(prov(S, D, L, R), Suffix) :-
    findall(Part,
            (   S \== none, main_phrase(according_to, KW), format(string(Part), "~w ~w", [KW, S])
            ;   D = doc(_, DocText), main_phrase(as_stated_in, KW),
                (   L \== none, \+ quoted_text(L, _)
                ->  main_phrase(at_locator, AtW),
                    format(string(Part), "~w ~w ~w ~w", [KW, DocText, AtW, L])
                ;   format(string(Part), "~w ~w", [KW, DocText])
                )
            ;   L \== none, quoted_text(L, _), main_phrase(confer, KW),
                format(string(Part), "~w ~w", [KW, L])
            ;   R \== none, main_phrase(because, KW), format(string(Part), "~w \"~w\"", [KW, R])
            ),
            Parts),
    atomic_list_concat(Parts, ', ', Joined),
    ( Parts == [] -> Suffix = "" ; format(string(Suffix), ", ~w", [Joined]) ).

main_phrase(Key, Phrase) :-
    ( kw_main_words(Key, Words) -> atomic_list_concat(Words, ' ', Phrase) ; Phrase = Key ).

%!  is_judged_goal(+KB, +Goal) is semidet.
%
%   Goal is an instance of a template declared `; judged`.
is_judged_goal(KB, Goal) :-
    atom(KB), KB \== none,
    callable(Goal),
    functor(Goal, F, A),
    current_predicate(KB:le_dict/1),
    catch(KB:le_dict(dict([F|Args], _, _, _, _, _, Unknown)), _, fail),
    Unknown == judged,
    length(Args, A), !.

% ---------------------------------------------------------------------------
% Citations: where the program cites a document the reader can be shown
% (the editor's "Show original text").
% ---------------------------------------------------------------------------

%!  citation(+KB, -Start, -End, -Prov, -Rule) is nondet.
%
%   A source range of the program that cites a document, and what it cites:
%   a fact with provenance (its trailers, or its scenario's default); a rule or
%   a decision table labelled with provenance, from the label to the end of the
%   rule (Rule is its id, else `none`); a scenario whose header names its
%   document ("scenario s is, as stated in <document>:"), the whole scenario;
%   and the statements that say where a document is published or where its
%   text is ("<document> is published at ...", "the text of <document> is at
%   ...").
citation(KB, S, E, Prov, none) :-
    current_predicate(KB:le_fact_provenance/4),
    KB:le_fact_provenance(S, E, _, Prov).
citation(KB, S, E, Prov, ID) :-
    current_predicate(KB:le_rule_provenance/2),
    KB:le_rule_provenance(ID, Prov),
    (   current_predicate(KB:le_rule_provenance_span/3),
        KB:le_rule_provenance_span(ID, S, E)
    ->  true
    ;   once(KB:le_source_info(_, S, E, ID))
    ).
citation(KB, S, E, Prov, none) :-
    current_predicate(KB:le_scenario_provenance/2),
    KB:le_scenario_provenance(Name, Prov),
    KB:le_source_info(Ref, S, E, Name),
    catch(clause(KB:scenario(Name, _), true, Ref), _, fail).
citation(KB, S, E, prov(none, doc(Doc, Text), none, none), none) :-
    member(F, [le_published_at, le_text_at]),
    current_predicate(KB:F/2),
    Goal =.. [F, Doc, _],
    catch(clause(KB:Goal, true, Ref), _, fail),
    KB:le_source_info(Ref, S, E, _),
    atom_string(Doc, Text).

%!  openable(+KB, +Prov) is semidet.
%
%   The document Prov cites can be shown: the program says where its text is
%   or where it is published, or the document is itself a URL.
openable(KB, prov(_, doc(Const, _), _, _)) :-
    openable_document(KB, Const).

openable_document(KB, Const) :-
    (   document_address(none, KB, le_text_at, Const, _)
    ;   document_address(none, KB, le_published_at, Const, _)
    ;   atom_string(Const, S), is_url_text(S)
    ), !.

%!  citation_spans(+KB, -Spans:list) is det.
%
%   The [Start, End] ranges of the program itself (not of the resources it
%   includes, whose offsets are moved out of its range) that cite a document
%   that can be shown. The editor keeps them to know where to offer "Show
%   original text"; which document is shown is asked for then (citation_at/6).
citation_spans(KB, Spans) :-
    (   atom(KB), KB \== none
    ->  le_grammar:resource_offset_unit(Unit),
        findall(c(S, E, Const),
                ( citation(KB, S, E, prov(_, doc(Const, _), _, _), _),
                  integer(S), integer(E), S < Unit ),
                Cs),
        findall(Const, member(c(_, _, Const), Cs), Consts0),
        sort(Consts0, Consts),
        include(openable_document(KB), Consts, Openable),
        findall([S, E], ( member(c(S, E, Const), Cs), memberchk(Const, Openable) ), Spans0),
        sort(Spans0, Spans)
    ;   Spans = []
    ).

%!  citation_at(+KB, +Pos, +LineStart, +LineEnd, -Prov, -Rule) is semidet.
%
%   The document cited at offset Pos: by the smallest range that holds Pos (a
%   fact before its scenario) or, when none does, by the smallest range that
%   meets the line LineStart-LineEnd (a rule's label, which comes before the
%   rule's head); LineStart and LineEnd may be `none`. The innermost citation
%   wins even when the program does not say where its document is — a fact
%   that names its own document is not about its scenario's — so the caller
%   checks whether it can be shown (provenance_dict/4 then has no `url` and no
%   `text`).
citation_at(KB, Pos, LineStart, LineEnd, Prov, Rule) :-
    atom(KB), KB \== none, integer(Pos),
    findall(Len-c(P, R),
            ( cited_document(KB, S, E, P, R),
              S =< Pos, Pos =< E, Len is E - S ),
            Inside),
    (   Inside \== []
    ->  Candidates = Inside
    ;   integer(LineStart), integer(LineEnd)
    ->  findall(Len-c(P, R),
                ( cited_document(KB, S, E, P, R),
                  S =< LineEnd, E >= LineStart, Len is E - S ),
                Candidates)
    ;   Candidates = []
    ),
    keysort(Candidates, [_-c(Prov, Rule)|_]).

% A citation that names a document (a fact "according to" someone, with no
% document of its own or of its scenario, cites none).
cited_document(KB, S, E, Prov, Rule) :-
    citation(KB, S, E, Prov, Rule),
    Prov = prov(_, doc(_, _), _, _),
    integer(S), integer(E).
