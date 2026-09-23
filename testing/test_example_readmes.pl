/* test_example_readmes.pl — the READMEs of the example folders lead somewhere.

   A folder's README is read on the landing page, in a panel, and its links
   open the programs it names (web_extras/landing/readme-panel.js): a link to
   `x.le?scenario=s&query=q` opens that program on that scenario and
   question. These tests check, for every README of the public example trees,
   that each relative link names a file or folder that exists, and that each
   scenario and query a link names is one the program has — so the "try this"
   steps of a README cannot drift away from the programs.
*/

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(pcre)).
:- use_module('../le_kbs').

readme_root('examples').

readme(File) :-
    readme_root(Root),
    directory_member(Root, File, [file_name_is_extension(false), recursive(true),
                                  matches('README.md')]),
    \+ sub_atom(File, _, _, _, '/sources/'),
    \+ sub_atom(File, _, _, _, 'node_modules'),
    \+ sub_atom(File, _, _, _, 'moreExamples/insureLE2'),
    \+ sub_atom(File, _, _, _, 'moreExamples/InsurLE2'),
    \+ sub_atom(File, _, _, _, 'moreExamples/lpsPlus').

%   The relative links of a README: Target (without its query) and Query.
readme_link(File, Target, Query) :-
    readme(File),
    read_file_to_string(File, Text, [encoding(utf8)]),
    re_foldl([M, L0, [T-Q|L0]]>>( get_dict(1, M, U0), split_link(U0, T, Q) ),
             "\\]\\(([^)\\s]+)\\)", Text, [], Links0, []),
    reverse(Links0, Links),
    member(Target-Query, Links),
    \+ re_match("^([a-z]+:|/|#)"/i, Target).

split_link(U0, T, Q) :-
    atom_string(U, U0),
    ( sub_atom(U, B, _, _, '#') -> sub_atom(U, 0, B, _, U1) ; U1 = U ),
    ( sub_atom(U1, B2, _, A2, '?') -> sub_atom(U1, 0, B2, _, T), sub_atom(U1, _, A2, 0, Q)
    ; T = U1, Q = '' ).

link_path(File, Target, Path) :-
    file_directory_name(File, Dir),
    directory_file_path(Dir, Target, Path0),
    ( sub_atom(Path0, _, 1, 0, '/') -> sub_atom(Path0, 0, _, 1, Path) ; Path = Path0 ).

:- begin_tests(example_readmes).

test(links_lead_to_files, [forall(readme_link(File, Target, _))]) :-
    Target \== '',
    link_path(File, Target, Path),
    (   ( exists_file(Path) ; exists_directory(Path) )
    ->  true
    ;   format(user_error, "~w: no such file or folder: ~w~n", [File, Target]), fail
    ).

test(scenarios_and_queries_exist, [forall(( readme_link(File, Target, Query), Query \== '',
                                            file_name_extension(_, le, Target) ))]) :-
    link_path(File, Target, Path),
    read_file_to_string(Path, Program, [encoding(utf8)]),
    atomic_list_concat(Params, '&', Query),
    forall(( member(P, Params), atomic_list_concat([K, V0], '=', P),
             memberchk(K, [scenario, query]) ),
           (   uri_encoded(query_value, V, V0),
               format(string(Re), "\\b~w\\s+~w\\b", [K, V]),
               (   re_match(Re, Program)
               ->  true
               ;   format(user_error, "~w: ~w has no ~w ~w~n", [File, Target, K, V]), fail
               )
           )).

%   The landing page shows the first line of a README as the folder's title,
%   so it is a heading.
test(first_line_is_a_title, [forall(readme(File))]) :-
    setup_call_cleanup(open(File, read, In, [encoding(utf8)]),
                       read_line_to_string(In, Line), close(In)),
    sub_string(Line, 0, 2, _, "# ").

:- end_tests(example_readmes).
