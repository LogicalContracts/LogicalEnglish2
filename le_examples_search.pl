/** <module> The examples' search: by name, by template, or through the text

    "Open example from server" and the landing page's search box ask here.
    A query is a few words, or a phrase in quotes, and a scope: the names
    (the program's path and its title), the templates (its declaration
    sections: the templates, the predicates, the ontology, the fluents and
    the events), the text (everything, rules, scenarios and comments), or
    all three, which is the default. Every word of the query must occur in
    the scope; a program scores by the words it has, each weighted by how
    rare it is among the examples, and by where it has them: a name counts
    for more than a template, a template for more than a line of text.

    The index is a Prolog term: for each program, the set of the words of
    each field. It is built from the files once, by the deployment's build
    (`write_index/0`: the Dockerfile and wasm/build.sh write it to
    `examples/search-index.fast`, a fast-term file that is not committed),
    and read back in a few milliseconds when the first search asks for it,
    provided the files it was built from are the ones on disk (their paths
    and sizes are its stamp). Without the file — a checkout — it is built on
    the spot, which takes a few seconds for five hundred programs, and kept
    in the process; either way it is rebuilt when a file changes. Phrases
    and the line shown with a hit are read from the hit's own file, so the
    index holds no text. The words are the documentation's
    (le_docs_search.pl: folded, without accents, stemmed), so the two
    searches agree on what a word is.

    What a visitor may see is decided at search time, not at indexing time:
    the index holds every example, and restricted_paths:is_path_allowed/2
    keeps a hit out of the answer exactly as it keeps the program out of the
    listing (le_api.pl, handle_list_examples/2).
*/

:- module(le_examples_search, [
    examples_search/3,          % +Query, +Options, -Hits
    examples_index_size/1,      % -N
    write_index/0,              % the deployment's build
    write_index/2,              % +File, +Options
    declaration_lines/2         % +Text, -Lines  (the declaration sections)
]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(library(ordsets)).
:- use_module(library(readutil)).
:- use_module(le_docs_search, [words/2, parse_query/3]).
:- use_module(restricted_paths).

:- dynamic index_cache/2.       % Stamp, Index

%!  examples_search(+Query, +Options, -Hits) is det.
%
%   Hits: dicts {name, title, field, snippet, score}, best first. Options:
%   scope(all|name|templates|text) (default all), limit(N) (default 40),
%   roles(Capabilities) (what the visitor holds; default none).
examples_search(Query, Options, Hits) :-
    option_(scope(Scope), Options, all),
    option_(limit(Limit), Options, 40),
    option_(roles(Roles), Options, []),
    parse_query(Query, Terms, Phrases),
    (   Terms == [], Phrases == []
    ->  Hits = []
    ;   index(index(N, DF, Entries)),
        maplist(term_weight(N, DF), Terms, Weights),
        pairs_keys_values(TW, Terms, Weights),
        scope_fields(Scope, Fields),
        findall(Score-Hit,
                ( member(E, Entries),
                  E = ex(_, File, _, _, _, _, _),
                  is_path_allowed(File, Roles),
                  entry_hit(E, Fields, TW, Phrases, Score, Hit) ),
                Scored0),
        keysort(Scored0, Scored1), reverse(Scored1, Scored),
        take(Limit, Scored, Taken),
        findall(_{name: Name, title: Title, field: Field, snippet: Snippet, score: S},
                ( member(S-hit(Name, File, Title, Field, TLines), Taken),
                  snippet(Field, TW, Phrases, Title, TLines, File, Snippet) ),
                Hits)
    ).

option_(Opt, Options, _) :- memberchk(Opt, Options), !.
option_(Opt, _, Default) :- arg(1, Opt, Default).

take(_, [], []) :- !.
take(0, _, []) :- !.
take(N, [X|Xs], [X|Ys]) :- N1 is N - 1, take(N1, Xs, Ys).

%   A word's weight: rare among the examples counts for more, as in the
%   documentation's search.
term_weight(N, DF, Term, W) :-
    ( memberchk(Term-D, DF) -> true ; D = 0 ),
    W is log(1 + N / (D + 1)).

%   The fields a scope searches, each with its boost.
scope_fields(name,      [name-3]).
scope_fields(templates, [templates-2]).
scope_fields(text,      [text-1]).
scope_fields(all,       [name-3, templates-2, text-1]).

%   An entry is a hit when every term occurs in one of the fields, and every
%   phrase occurs, in order, in one of them (read from the file: the index
%   holds sets of words, not their order); it scores by each term's weight
%   times the boost of the best field that has it, and is reported under
%   that best field.
entry_hit(ex(Name, File, Title, FW, TW, XW, TLines), Fields, Terms, Phrases, Score, hit(Name, File, Title, Field, TLines)) :-
    term_scores(Terms, Fields, FW, TW, XW, Scores, BestFields),
    length(Terms, NT), length(Scores, NT),        % every term occurs somewhere
    Scores \== [],
    phrases_occur(Phrases, Fields, Name, Title, TLines, File),
    sum_list(Scores, Score),
    best_field(BestFields, Field).

term_scores([], _, _, _, _, [], []).
term_scores([T-W|Ts], Fields, FW, TW, XW, Scores, Bests) :-
    findall(B-F, ( member(F-B, Fields), field_set(F, FW, TW, XW, Set), ord_memberchk(T, Set) ), BFs),
    (   BFs == []
    ->  Scores = Scores1, Bests = Bests1          % the term is missing: no hit (checked by length)
    ;   max_member(B-F, BFs),
        S is W * B,
        Scores = [S|Scores1], Bests = [F|Bests1]
    ),
    term_scores(Ts, Fields, FW, TW, XW, Scores1, Bests1).

field_set(name, FW, _, _, FW).
field_set(templates, _, TW, _, TW).
field_set(text, _, _, XW, XW).

best_field(Fields, Best) :-
    ( memberchk(name, Fields) -> Best = name
    ; memberchk(templates, Fields) -> Best = templates
    ; Best = text ).

phrases_occur([], _, _, _, _, _) :- !.
phrases_occur(Phrases, Fields, Name, Title, TLines, File) :-
    findall(F-Seq, ( member(F-_, Fields), field_sequence(F, Name, Title, TLines, File, Seq) ), Seqs),
    forall(member(P, Phrases), ( member(_-Seq, Seqs), sublist_(P, Seq) )).

field_sequence(name, Name, Title, _, _, Seq) :- name_words(Name, Title, Seq).
field_sequence(templates, _, _, TLines, _, Seq) :- atomic_list_concat(TLines, ' ', T), words(T, Seq).
field_sequence(text, _, _, _, File, Seq) :- file_text(File, Text), words(Text, Seq).

sublist_(P, L) :- append(_, R, L), append(P, _, R), !.

%   The line to show: for a name hit the title, or, when there is none, the
%   line of text the words occur in; for the others the first line of the
%   field that has a query word (a phrase's first word counts).
snippet(name, Terms, Phrases, Title, TLines, File, Snippet) :- !,
    (   Title \== "" -> Snippet = Title
    ;   snippet(text, Terms, Phrases, Title, TLines, File, Snippet)
    ).
snippet(templates, Terms, Phrases, _, TLines, _, Snippet) :- !,
    first_line_with(Terms, Phrases, TLines, Snippet).
snippet(text, Terms, Phrases, _, _, File, Snippet) :-
    file_text(File, Text),
    split_string(Text, "\n", "\r", Lines),
    first_line_with(Terms, Phrases, Lines, Snippet).

first_line_with(Terms, Phrases, Lines, Snippet) :-
    pairs_keys(Terms, Ws0),
    findall(W, member([W|_], Phrases), Ws1),
    append(Ws0, Ws1, Ws),
    (   member(Line, Lines),
        words(Line, LW),
        member(W, Ws), memberchk(W, LW)
    ->  normalize_space(string(S0), Line),
        ( string_length(S0, L), L > 160 -> sub_string(S0, 0, 157, _, S1), string_concat(S1, "…", Snippet)
        ; Snippet = S0 )
    ;   Snippet = ""
    ).

file_text(File, Text) :-
    catch(read_file_to_string(File, Text, [encoding(utf8)]), _, Text = "").

% ---------------------------------------------------------------------------
% The index

%!  examples_index_size(-N) is det.
examples_index_size(N) :-
    index(index(N, _, _)).

%!  index_file(-File) is det.
%   Where the deployment's build writes the index, and where a search looks
%   for it: beside the examples, as a file their directory carries.
index_file('examples/search-index.fast').

index(Index) :-
    example_files(Pairs),
    stamp(Pairs, Stamp),
    (   index_cache(Stamp, Index)
    ->  true
    ;   (   prebuilt_index(Stamp, Index0) -> Index = Index0
        ;   build_index(Pairs, Index)
        ),
        retractall(index_cache(_, _)),
        assertz(index_cache(Stamp, Index))
    ).

%   The files the index describes, with their sizes: the same list on the
%   machine that built the index and on the one that reads it means the same
%   programs (modification times would not travel with a copy).
stamp(Pairs, Stamp) :-
    findall(F-S, ( member(_-F, Pairs), ( exists_file(F) -> size_file(F, S) ; S = 0 ) ), Stamp0),
    sort(Stamp0, Stamp).

%   The index the build wrote, when it was written from these very files.
prebuilt_index(Stamp, Index) :-
    index_file(File),
    exists_file(File),
    catch(setup_call_cleanup(open(File, read, In, [type(binary)]),
                             fast_read(In, Term),
                             close(In)),
          _, fail),
    Term = search_index(Stamp0, Index),
    Stamp0 == Stamp.

%!  write_index is det.
%!  write_index(+File, +Options) is det.
%
%   Build the index from the files and write it to File (write_index/0: to
%   index_file/1), as a fast term with its stamp, for the deployment to read
%   instead of building it. Options: only_list(ListFile) — index only the
%   files named, one relative path per line, in ListFile: the browser build's
%   payload list (wasm/build.sh), since that build carries fewer examples
%   than the server and its stamp must match what it carries.
write_index :-
    index_file(File),
    write_index(File, []).
write_index(File, Options) :-
    example_files(Pairs0),
    (   memberchk(only_list(ListFile), Options)
    ->  read_file_to_string(ListFile, S, []),
        split_string(S, "\n", " \t\r", Lines0),
        exclude(==(""), Lines0, Lines),
        findall(Name-F, ( member(Name-F, Pairs0), atom_string(F, FS), memberchk(FS, Lines) ), Pairs)
    ;   Pairs = Pairs0
    ),
    stamp(Pairs, Stamp),
    build_index(Pairs, Index),
    setup_call_cleanup(open(File, write, Out, [type(binary)]),
                       fast_write(Out, search_index(Stamp, Index)),
                       close(Out)),
    Index = index(N, _, _),
    print_message(informational, format("examples' search index: ~w programs written to ~w", [N, File])).

%   Every example the pickers can list, whatever the visitor's rights, with
%   its file: le_api's listing with every capability there is, so that the
%   names are the ones the picker opens (le_api.pl, every_example/2).
example_files(Pairs) :-
    findall(Name-File, le_api:every_example(Name, File), Pairs0),
    sort(Pairs0, Pairs).

build_index(Pairs, index(N, DF, Entries)) :-
    findall(E, ( member(Name-File, Pairs), catch(entry(Name, File, E), _, fail) ), Entries),
    length(Entries, N),
    findall(W, ( member(ex(_, _, _, FW, TW, XW, _), Entries),
                 ord_union([FW, TW, XW], Set), member(W, Set) ), Ws),
    msort(Ws, Sorted),
    clumped(Sorted, DF).

%   ex(Name, File, Title, NameWords, TemplateWords, TextWords, TemplateLines),
%   the words as sets.
entry(Name, File, ex(Name, File, Title, NameSet, TemplSet, TextSet, TLines)) :-
    read_file_to_string(File, Text, [encoding(utf8)]),
    split_string(Text, "\n", "\r", Lines),
    title(Lines, Title),
    name_words(Name, Title, NameWords), sort(NameWords, NameSet),
    declaration_lines(Text, TLines),
    atomic_list_concat(TLines, ' ', TText),
    words(TText, TemplWords), sort(TemplWords, TemplSet),
    words(Text, TextWords), sort(TextWords, TextSet).

%   The first comment line, as the program's own description.
title(Lines, Title) :-
    (   member(L, Lines),
        normalize_space(string(S), L), S \== "",
        (   sub_string(S, 0, 1, _, "%")
        ->  re_replace("^%+\\s*"/g, "", S, T0), normalize_space(string(Title), T0)
        ;   Title = ""
        )
    ->  true
    ;   Title = ""
    ).

name_words(Name, Title, Words) :-
    format(string(S0), "~w", [Name]),
    re_replace("[_/\\-.]"/g, " ", S0, S1),
    format(string(S), "~w ~w", [S1, Title]),
    words(S, Words).

%!  declaration_lines(+Text, -Lines) is det.
%
%   The lines of the declaration sections of a program: a section whose
%   header (a line ending in `:`) names the templates, the predicates, the
%   ontology, the fluents, the events, the actions, the constants or the
%   functions, in any of the dictionaries' languages, up to the next header.
declaration_lines(Text, Lines) :-
    split_string(Text, "\n", "\r", All),
    decl_lines_(All, no, Lines).

decl_lines_([], _, []).
decl_lines_([L|Ls], In, Out) :-
    (   section_header(L)
    ->  ( declaration_header(L) -> In1 = yes ; In1 = no ),
        Out = Out1
    ;   In1 = In,
        ( In1 == yes, normalize_space(string(S), L), S \== "" -> Out = [S|Out1] ; Out = Out1 )
    ),
    decl_lines_(Ls, In1, Out1).

section_header(L) :-
    normalize_space(string(S), L),
    sub_string(S, _, 1, 0, ":"),
    \+ sub_string(S, 0, 1, _, "%"),
    split_string(S, " ", "", Ws), length(Ws, N), N =< 12.

declaration_header(L) :-
    words(L, LW),
    declaration_phrase(P),
    sublist_(P, LW), !.

%   The headers' words, in every language of the dictionaries (i18n/keywords.csv).
:- dynamic declaration_phrase_cache/1.
declaration_phrase(P) :-
    (   declaration_phrase_cache(_) -> true
    ;   findall(Ws, ( member(Key, [templates, predicates, ontology, fluents, events,
                                   actions, prolog_events, constants, functions]),
                      catch(le_i18n:kw_syn(_, section, Key, Ws0), _, fail),
                      atomic_list_concat(Ws0, ' ', A), words(A, Ws), Ws \== [] ),
                Ps0),
        sort(Ps0, Ps),
        forall(member(P0, Ps), assertz(declaration_phrase_cache(P0)))
    ),
    declaration_phrase_cache(P).
