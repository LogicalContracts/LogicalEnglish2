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
    parse_provenance_trailers/2,  % +Tokens, -Prov
    prov_effective_source/2,      % +Prov, -Source
    prov_public/5,                % +Prov, -Source, -Document, -Locator, -Rationale
    with_provenance_sink/2,       % :Goal, -Collected   (custom scenario text)
    add_scenario_provenance/3,    % +SM, +KB, +ScenarioTerms
    clause_provenance/5,          % +SM, +KB, +Ref, +Goal, -Prov
    provenance_suffix/2,          % +Prov, -Suffix:string
    is_judged_goal/2              % +KB, +Goal
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
    ->  (   parse_provenance_trailers(Trailers, Prov)
        ->  store_provenance(M, Start, End, Head, Prov)
        ;   malformed_provenance(M, Start, End)
        )
    ;   true
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
        token_constant(DocToks, DocConst),
        verbatim(DocToks, DocText),
        D = doc(DocConst, DocText),
        ( LocToks == [] -> L = L0 ; verbatim(LocToks, L) ),
        S = S0, R = R0
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
                (   L \== none
                ->  main_phrase(at_locator, AtW),
                    format(string(Part), "~w ~w ~w ~w", [KW, DocText, AtW, L])
                ;   format(string(Part), "~w ~w", [KW, DocText])
                )
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
