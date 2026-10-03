/*  The examples' search (le_examples_search.pl): by name, by template and
    through the text, what a visitor may see, and the operation the pickers
    and the landing page ask.

    Run with:  swipl -q -g run_tests -t halt testing/test_examples_search.pl
*/
:- module(test_examples_search, []).

:- use_module(library(plunit)).
:- use_module('../le_api').
:- use_module('../le_examples_search').

:- begin_tests(examples_search).

names(Hits, Names) :- findall(N, ( member(H, Hits), atom_string(N, H.name) ), Names).

test(by_name) :-
    examples_search("dragon", [scope(name)], Hits),
    names(Hits, Names),
    assertion(memberchk('domains/other/flying_dragon', Names)),
    assertion(memberchk(happy_dragon, Names)).

%   A template search finds the programs that declare the template, with the
%   template's own line as the snippet, and not the ones that merely mention
%   the words in a comment.
test(by_template) :-
    examples_search("parent of", [scope(templates)], Hits),
    names(Hits, Names),
    assertion(memberchk(royal_family, Names)),
    assertion(memberchk('domains/other/flying_dragon', Names)),
    member(H, Hits), atom_string(HN, H.name), HN == 'domains/other/flying_dragon', !,
    assertion(H.field == templates),
    assertion(sub_string(H.snippet, _, _, _, "is a parent of")).

%   Every word must occur; a phrase in quotes must occur as written.
test(all_words_and_phrases) :-
    examples_search("creature flies green", [scope(all)], Hits),
    names(Hits, Names),
    assertion(memberchk('domains/other/flying_dragon', Names)),
    examples_search("\"the other dragon flies\"", [], PHits),
    names(PHits, PNames),
    assertion(memberchk('domains/other/flying_dragon', PNames)),
    examples_search("\"dragon flies an other\"", [], None),
    assertion(None == []).

%   A name hit outranks a text hit for the same word.
test(names_first) :-
    examples_search("citizenship", [], [First|_]),
    assertion(First.field == name).

%   Nothing to search for, nothing found; the index is one term, built once.
test(empty_query_and_cached_index) :-
    examples_search("", [], Hits), assertion(Hits == []),
    examples_index_size(N), assertion(N > 100),
    statistics(cputime, T0),
    examples_search("dragon", [], _),
    statistics(cputime, T1),
    assertion(T1 - T0 < 2).

%   The declaration sections: the templates and the fluents, not the rules
%   and not a scenario.
test(declaration_lines) :-
    declaration_lines("the target language is: prolog.\n\nthe templates are:\n*a person* is happy.\n*a person* likes *a thing*.\n\nthe knowledge base k includes:\na person is happy if the person likes tea.\n\nthe fluents are:\n*a light* is on.\n\nscenario s is:\nbob likes tea.\n", Lines),
    assertion(Lines == ["*a person* is happy.", "*a person* likes *a thing*.", "*a light* is on."]).

%   A restricted program is indexed but is not answered to a visitor without
%   the capability that opens it, as the listing does not list it.
test(restricted_programs_stay_hidden, [condition(\+ getenv('NO_RESTRICTIONS', true))]) :-
    examples_search("policy", [scope(name), roles([])], Hits),
    names(Hits, Names),
    assertion(\+ ( member(N, Names), sub_atom(N, _, _, _, 'insureLE2') )).

%   The operation the pickers call.
test(operation) :-
    le_api:handle_operation(_{token: "myToken123", operation: "search_examples", query: "parent of", scope: "templates"}, R),
    assertion(is_list(R.hits)),
    names(R.hits, Names),
    assertion(memberchk(royal_family, Names)).

%   The index the build writes (write_index/0) is read back instead of built,
%   and only when it was written from these very files.
test(prebuilt_index_is_read, [setup(( le_examples_search:index_file(F), ( exists_file(F) -> delete_file(F) ; true ) )),
                              cleanup(( le_examples_search:index_file(F), ( exists_file(F) -> delete_file(F) ; true ) ))]) :-
    write_index,
    le_examples_search:index_file(File),
    assertion(exists_file(File)),
    retractall(le_examples_search:index_cache(_, _)),
    statistics(cputime, T0),
    examples_search("dragon", [scope(name)], Hits),
    statistics(cputime, T1),
    names(Hits, Names),
    assertion(memberchk(happy_dragon, Names)),
    assertion(T1 - T0 < 1.5),
    % a stale index — a file that changed since — is not trusted
    le_examples_search:index_cache(Stamp, _),
    assertion(\+ ( le_examples_search:prebuilt_index(Other, _), Other \== Stamp )).

:- end_tests(examples_search).
