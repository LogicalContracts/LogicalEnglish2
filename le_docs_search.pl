/** <module> The documentation's search, for the assistants

    The user documentation (docs/user, the documents of its nav.json) searched
    section by section on the server, so that an assistant can look up what
    somebody asks about and answer with a few links to it. The same reading as
    the viewer's search (web_extras/docsview/docs-extras.js: its sections,
    words, stems and anchors), with one difference: the viewer's search wants
    every word of the query in a section, which a question written in plain
    words ("how do I say that something is unknown?") never satisfies. Here a
    section scores by the query's words it has, each weighted by how rare it
    is in the documentation, so "unknown" counts and "how" and "do" hardly do;
    a quoted phrase must still occur.

    Kept equal to LPS2's src/edges/lps_docs_search.pl (only the module name
    differs), as docs-extras.js is kept equal in the two repositories.
*/

:- module(le_docs_search, [
    docs_search/4,              % +Root, +Query, +Options, -Hits
    docs_search_material/4,     % +Root, +Question, +Options, -Text
    docs_search_answer/4        % +Root, +Query, +Options, -Text
]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(library(readutil)).
:- use_module(library(http/json)).
:- use_module(library(pcre)).

:- dynamic index_cache/3.       % Root, Stamp, Index

%!  docs_search(+Root, +Query, +Options, -Hits) is det.
%
%   Hits: a list of dicts {title, section, url, snippet, score}, best first.
%   Root is the directory holding nav.json and the documents (docs/user).
%   Options: limit(N) (default 5), per_document(N) (default 2), url_prefix(P)
%   (default '/docs/user/'), slug(le2|lps2) (the viewer's anchors; default
%   le2), min_coverage(F) (the share, 0..1, of the query's weight a hit must
%   have; default 0.5), relative(F) (a hit scoring less than F times the best
%   one is left out; default 0.25).
docs_search(Root, Query, Options, Hits) :-
    option_(limit(Limit), Options, 5),
    option_(per_document(PerDoc), Options, 2),
    option_(url_prefix(Prefix), Options, '/docs/user/'),
    option_(min_coverage(MinCov), Options, 0.5),
    parse_query(Query, Terms, Phrases),
    (   Terms == []
    ->  Hits = []
    ;   index(Root, Options, index(N, DF, Sections)),
        maplist(term_weight(N, DF), Terms, Weights),
        pairs_keys_values(TW, Terms, Weights),
        sum_list(Weights, Total),
        findall(Score-hit(Doc, Sec),
                ( member(Doc-Sec, Sections),
                  section_score(Sec, Doc, TW, Phrases, Total, MinCov, Score) ),
                Scored0),
        keysort(Scored0, Scored1), reverse(Scored1, Scored2),
        %  a hit far below the best one is noise beside it
        option_(relative(Rel), Options, 0.25),
        (   Scored2 = [Best-_|_]
        ->  Min is Rel * Best,
            include(scored_at_least(Min), Scored2, Scored)
        ;   Scored = []
        ),
        take_hits(Scored, Limit, PerDoc, [], Prefix, Terms, Hits)
    ).

%!  docs_search_material(+Root, +Question, +Options, -Text) is det.
%
%   The hits for Question as text for a prompt: one line per hit (title,
%   section, link, what it says around the words), or "" when nothing is
%   relevant enough.
docs_search_material(Root, Question, Options, Text) :-
    catch(docs_search(Root, Question, Options, Hits), _, Hits = []),
    (   Hits == []
    ->  Text = ""
    ;   maplist(hit_line, Hits, Lines),
        atomic_list_concat(Lines, '\n', Text0),
        atom_string(Text0, Text)
    ).

%!  docs_search_answer(+Root, +Query, +Options, -Text) is det.
%
%   What an assistant's documentation search (a tool, an action) answers:
%   the sections found, one per line, or a note that there was none.
%   Options as for docs_search/4.
docs_search_answer(Root, Query, Options, Text) :-
    append(Options, [limit(5), min_coverage(0.4)], Options1),
    docs_search_material(Root, Query, Options1, Lines),
    (   Lines == ""
    ->  format(string(Text), "No section of the documentation matches \"~w\". Try other keywords (the words the documentation would use), or answer without links.", [Query])
    ;   format(string(Text), "Sections of the documentation for \"~w\" (cite at most three, with the URL exactly as given):\n~w", [Query, Lines])
    ).

hit_line(H, Line) :-
    (   H.section == "" -> format(string(Where), "~w", [H.title])
    ;   format(string(Where), "~w — ~w", [H.title, H.section])
    ),
    format(string(Line), "- [~w](~w): ~w", [Where, H.url, H.snippet]).

option_(Opt, Options, Default) :-
    (   memberchk(Opt, Options) -> true ; arg(1, Opt, Default) ).

% ---------------------------------------------------------------------------
% Scoring

term_weight(N, DF, T, W) :-
    ( get_assoc_(T, DF, D) -> true ; D = 0 ),
    (   D =:= 0 -> W = 0.0
    ;   W is log((N + 1) / D)
    ).

get_assoc_(K, Pairs, V) :- memberchk(K-V, Pairs).

%   A heading word 10 (at most twice), the document's title 4, the text 1 per
%   occurrence up to 8 — the viewer's weights — each times the square of the
%   word's rarity, so that a word most sections have ("how") cannot outweigh
%   the one the question is about.
%   A section needs a quoted phrase of the query in its heading or text, and
%   words of the query in its heading or text weighing MinCov of the query.
section_score(sec(_, Anchor, HeadW, TextW, _), doc(_, _, TitleW, _), TW, Phrases, Total, MinCov, Score) :-
    %  a table of contents has every word and says nothing
    \+ memberchk(Anchor, ["table-of-contents", "contents"]),
    forall(member(P, Phrases), ( sublist_(P, HeadW) ; sublist_(P, TextW) )),
    foldl(term_score(HeadW, TextW, TitleW), TW, 0-0, Score0-Covered),
    Total > 0,
    Covered >= MinCov * Total,
    Score0 > 0,
    Score = Score0.

term_score(HeadW, TextW, TitleW, T-W, S0-C0, S-C) :-
    occurrences(T, HeadW, H), occurrences(T, TextW, X), occurrences(T, TitleW, D),
    S is S0 + W * W * (10 * min(H, 2) + 4 * min(D, 1) + min(X, 8)),
    (   H + X > 0 -> C is C0 + W ; C = C0 ).

scored_at_least(Min, Score-_) :- Score >= Min.

occurrences(T, Ws, N) :- aggregate_all(count, member(T, Ws), N).

sublist_(P, L) :- append(P, _, S), append(_, S, L), !.

take_hits(_, 0, _, _, _, _, []) :- !.
take_hits([], _, _, _, _, _, []).
take_hits([Score-hit(Doc, Sec)|Rest], Limit, PerDoc, Seen, Prefix, Terms, Hits) :-
    Doc = doc(Path, Title, _, _),
    aggregate_all(count, member(Path, Seen), K),
    (   K >= PerDoc
    ->  take_hits(Rest, Limit, PerDoc, Seen, Prefix, Terms, Hits)
    ;   Sec = sec(Heading, Anchor, _, _, Text),
        (   Anchor == "" -> format(string(Url), "~w~w", [Prefix, Path])
        ;   format(string(Url), "~w~w#~w", [Prefix, Path, Anchor])
        ),
        snippet(Text, Terms, Snippet),
        S is round(Score * 10) / 10,
        Hits = [_{title: Title, section: Heading, url: Url, snippet: Snippet, score: S}|Hits1],
        Limit1 is Limit - 1,
        take_hits(Rest, Limit1, PerDoc, [Path|Seen], Prefix, Terms, Hits1)
    ).

%   Some 200 characters of the text, from a little before the first word of
%   the query it has.
snippet(Text, Terms, Snippet) :-
    string_length(Text, Len),
    (   text_word_offsets(Text, Offsets),
        member(Off-W, Offsets), memberchk(W, Terms)
    ->  From0 is max(0, Off - 60)
    ;   From0 = 0
    ),
    (   From0 > 0, sub_string(Text, B, _, _, " "), B >= From0, B < From0 + 30
    ->  From is B + 1
    ;   From = From0
    ),
    To is min(Len, From + 200),
    L is To - From,
    sub_string(Text, From, L, _, S0),
    ( From > 0 -> P = "…" ; P = "" ),
    ( To < Len -> E = "…" ; E = "" ),
    string_concat(P, S0, S1), string_concat(S1, E, Snippet).

text_word_offsets(Text, Offsets) :-
    string_codes(Text, Cs),
    word_offsets(Cs, 0, Offsets).

word_offsets([], _, []).
word_offsets([C|Cs], I, Os) :-
    (   word_code(C)
    ->  span_word([C|Cs], W, Rest, N),
        fold_word(W, F),
        Os = [I-F|Os1],
        I1 is I + N,
        word_offsets(Rest, I1, Os1)
    ;   I1 is I + 1,
        word_offsets(Cs, I1, Os)
    ).

span_word(Cs, W, Rest, N) :-
    span_word_(Cs, W, Rest),
    length(W, N).

span_word_([C|Cs], [C|W], Rest) :- word_code(C), !, span_word_(Cs, W, Rest).
span_word_(Rest, [], Rest).

% ---------------------------------------------------------------------------
% Words: folded (lower case, no accents), split on anything that is not a
% letter, a digit or `_`, stemmed as the viewer stems them.

words(S, Ws) :-
    string_codes(S, Cs),
    words_(Cs, Ws).

words_([], []).
words_([C|Cs], Ws) :-
    (   word_code(C)
    ->  span_word_([C|Cs], W, Rest),
        fold_word(W, F),
        Ws = [F|Ws1],
        words_(Rest, Ws1)
    ;   words_(Cs, Ws)
    ).

word_code(C) :- code_type(C, csym).

fold_word(Codes, Stem) :-
    maplist(fold_code, Codes, Folded),
    atom_codes(A, Folded),
    stem(A, Stem).

fold_code(C, F) :-
    (   accent(C, B) -> F0 = B ; F0 = C ),
    (   code_type(F0, upper(L)) -> F = L ; F = F0 ).

accent(C, B) :-
    char_code(Ch, C),
    accent_char(Ch, BCh), !,
    char_code(BCh, B).

accent_char(Ch, B) :-
    member(Base-Accented, [a-"àáâãäåÀÁÂÃÄÅ", e-"èéêëÈÉÊË", i-"ìíîïÌÍÎÏ", o-"òóôõöÒÓÔÕÖ",
                           u-"ùúûüÙÚÛÜ", c-"çÇ", n-"ñÑ", y-"ýÿÝ"]),
    sub_atom(Accented, _, 1, _, Ch), !,
    B = Base.

stem(W, S) :-
    atom_length(W, L),
    (   L > 4, atom_concat(B, ies, W) -> atom_concat(B, y, S)
    ;   L > 4, member(E, [ches, shes, sses, xes]), atom_concat(_, E, W) -> sub_atom(W, 0, _, 2, S)
    ;   L > 3, atom_concat(B, s, W), \+ atom_concat(_, ss, W),
        \+ atom_concat(_, us, W), \+ atom_concat(_, is, W) -> S = B
    ;   S = W
    ).

%   The query's words (a word of two letters or less is left out: "I", "do",
%   "a" say nothing about where to look), and its quoted phrases.
parse_query(Q0, Terms, Phrases) :-
    atom_string(Q0, Q),
    re_foldl(quoted, "\"([^\"]+)\"", Q, [], Ps0, []),
    reverse(Ps0, Ps),
    findall(P, ( member(PT, Ps), words(PT, P), P \== [] ), Phrases),
    re_replace("\"[^\"]*\""/g, " ", Q, Rest),
    words(Rest, Ws0),
    append([Ws0|Phrases], Ws1),
    include(longer_than_two, Ws1, Ws2),
    exclude(question_word, Ws2, Ws3),
    list_to_set(Ws3, Terms).

quoted(M, Ps, [T|Ps]) :- get_dict(1, M, T).

%   The words of a question that say nothing about what it is about. The
%   documentation is in English, and so are the questions it can answer;
%   rarity alone does not tell them apart in a corpus this small ("something"
%   is rarer in it than "unknown"). Stemmed as words/2 stems them.
question_word(W) :-
    memberchk(W, [how, what, when, where, why, which, who, whom, whose, can, could, would, should,
                  shall, will, may, might, must, doe, did, done, doing, are, was, were, been,
                  being, have, ha, had, having, the, and, for, with, that, thi, these, those, there,
                  their, them, they, you, your, our, into, onto, from, about, than, then, also,
                  just, some, something, anything, someone, somebody, thing, way, say, said, tell,
                  show, explain, know, want, need, like, make, use, using, get, give, let,
                  please, help, not, any, all, each, every, other, such, very, more, most, much,
                  many, few, only, own, same, too, hello, thank, yes, okay, don, doesn, isn,
                  can_t, won, possible, able, program, programs]).


longer_than_two(W) :- atom_length(W, L), L > 2.

% ---------------------------------------------------------------------------
% The index: every section of every document of nav.json, with the number of
% sections each word occurs in. Rebuilt when nav.json or a document changes.

index(Root, Options, Index) :-
    option_(slug(Slug), Options, le2),
    stamp(Root, Stamp),
    (   index_cache(Root-Slug, Stamp, Index)
    ->  true
    ;   build_index(Root, Slug, Index),
        retractall(index_cache(Root-Slug, _, _)),
        assertz(index_cache(Root-Slug, Stamp, Index))
    ).

stamp(Root, Stamp) :-
    nav_items(Root, Items),
    findall(P-T, ( member(P-_, Items), doc_file(Root, P, F),
                   ( exists_file(F) -> time_file(F, T) ; T = 0 ) ), Stamp0),
    directory_file_path(Root, 'nav.json', Nav),
    ( exists_file(Nav) -> time_file(Nav, NT) ; NT = 0 ),
    Stamp = NT-Stamp0.

nav_items(Root, Items) :-
    directory_file_path(Root, 'nav.json', Nav),
    (   exists_file(Nav),
        catch(setup_call_cleanup(open(Nav, read, In, [encoding(utf8)]),
                                 json_read_dict(In, D),
                                 close(In)), _, fail)
    ->  findall(P-T, ( member(S, D.sections), member(I, S.items),
                       atom_string(P, I.path), T = I.title ), Items)
    ;   Items = []
    ).

doc_file(Root, Path, File) :-
    atomic_list_concat([Root, '/', Path, '.md'], File).

build_index(Root, Slug, index(N, DF, Sections)) :-
    nav_items(Root, Items),
    findall(Doc-Sec,
            ( member(Path-Title, Items),
              doc_file(Root, Path, File),
              exists_file(File),
              catch(read_file_to_string(File, Md, [encoding(utf8)]), _, fail),
              words(Title, TitleW),
              Doc = doc(Path, Title, TitleW, File),
              md_sections(Md, Slug, Secs),
              member(Sec, Secs) ),
            Sections),
    length(Sections, N),
    findall(W, ( member(_-sec(_, _, HW, TW, _), Sections),
                 append(HW, TW, All), list_to_set(All, Set), member(W, Set) ), Ws),
    msort(Ws, Sorted),
    clumped(Sorted, DF).

%   A document's sections: sec(Heading, Anchor, HeadingWords, TextWords,
%   Text), the text as a reader sees it (Markdown syntax out).
md_sections(Md, Slug, Secs) :-
    split_string(Md, "\n", "", Lines),
    sections_(Lines, none, "", "", [], [], Slug, [], Raw),
    findall(sec(H, A, HW, TW, Text),
            ( member(raw(H, A, Ls), Raw),
              atomic_list_concat(Ls, '\n', Body0),
              plain(Body0, Body1),
              re_replace("^\\s*[|>*-]+\\s*"/gm, " ", Body1, Body2),
              re_replace("\\|"/g, " ", Body2, Body3),
              normalize_space(string(Text), Body3),
              once(( H \== "" ; Text \== "" )),
              words(H, HW), words(Text, TW) ),
            Secs).

sections_([], _, H, A, Ls, Acc, _, _, Raw) :-
    reverse(Ls, L1),
    reverse([raw(H, A, L1)|Acc], Raw).
sections_([Line|Lines], Fence, H, A, Ls, Acc, Slug, Seen, Raw) :-
    (   re_matchsub("^\\s*(```+|~~~+)", Line, M, [])
    ->  sub_atom(M.1, 0, 1, _, FC),
        (   Fence == none -> Fence1 = FC
        ;   Fence == FC -> Fence1 = none
        ;   Fence1 = Fence
        ),
        re_replace("^\\s*(```+|~~~+)\\w*", "", Line, L1),
        sections_(Lines, Fence1, H, A, [L1|Ls], Acc, Slug, Seen, Raw)
    ;   Fence == none,
        re_matchsub("^(#{1,6})\\s+(.+?)\\s*#*\\s*$", Line, M, [])
    ->  reverse(Ls, L1),
        plain(M.2, HText0),
        normalize_space(string(HText), HText0),
        slug(Slug, HText0, Base),
        aggregate_all(count, member(Base, Seen), K),
        (   K =:= 0 -> Anchor = Base ; format(string(Anchor), "~w-~w", [Base, K]) ),
        sections_(Lines, Fence, HText, Anchor, [], [raw(H, A, L1)|Acc], Slug, [Base|Seen], Raw)
    ;   sections_(Lines, Fence, H, A, [Line|Ls], Acc, Slug, Seen, Raw)
    ).

%   Markdown inline syntax out (docs-extras.js plain/1).
plain(Md, Text) :-
    foldl(replace, [ "!\\[([^\\]]*)\\]\\([^)]*\\)"/g-"$1",
                     "\\[([^\\]]*)\\]\\([^)]*\\)"/g-"$1",
                     "<[^>]+>"/g-" ",
                     "`+"/g-"",
                     "\\*\\*|__"/g-"",
                     "(^|\\W)[*_](\\S[^*_]*?)[*_](?=\\W|$)"/g-"$1$2",
                     "&nbsp;"/g-" ", "&amp;"/g-"&", "&lt;"/g-"<", "&gt;"/g-">",
                     "&quot;"/g-"\"", "&#39;"/g-"'" ],
          Md, Text0),
    atom_string(Text0, Text).

replace(Pattern-With, In, Out) :- re_replace(Pattern, With, In, Out).

%   The viewers' anchors. LE2's (viewer.html): trimmed, lower case, only
%   letters, marks, digits, `_`, `-` and spaces kept, spaces as `-`. LPS2's
%   (ui/src/docs.js): lower case, only ASCII word characters, spaces and `-`
%   kept, each space as `-`.
slug(le2, Text, Slug) :-
    normalize_space(string(T0), Text),
    string_lower(T0, T1),
    string_codes(T1, Cs),
    include(le2_slug_code, Cs, Kept),
    maplist(space_as_dash, Kept, Ds),
    string_codes(Slug, Ds).
slug(lps2, Text, Slug) :-
    string_lower(Text, T1),
    string_codes(T1, Cs),
    include(lps2_slug_code, Cs, Kept),
    maplist(space_as_dash, Kept, Ds),
    string_codes(Slug, Ds).

le2_slug_code(C) :- ( code_type(C, csym) ; C == 0'- ; C == 0'  ), !.
lps2_slug_code(C) :- ( C < 128, code_type(C, csym) ; C == 0'- ; code_type(C, space) ), !.

space_as_dash(C, D) :- ( code_type(C, space) -> D = 0'- ; D = C ).
