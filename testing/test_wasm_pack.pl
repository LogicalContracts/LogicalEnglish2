/* test_wasm_pack.pl — what the browser (WebAssembly) build carries.

   wasm/pack.pl decides the files the browser build unpacks. Two rules are
   checked here: nothing a visitor without an account could not read, and
   none of the large public trees the "light" build leaves out
   (light_excluded/1) — in a `--private` build as well.
*/

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module('../wasm/pack').

:- begin_tests(wasm_pack).

test(light_trees_left_out, [forall(le_wasm_pack:light_excluded(Tree))]) :-
    payload_files(Files),
    \+ ( member(F, Files), sub_atom(F, 0, _, _, Tree) ).

test(light_trees_left_out_of_a_private_build, [forall(le_wasm_pack:light_excluded(Tree))]) :-
    payload_files([private(true)], Files),
    \+ ( member(F, Files), sub_atom(F, 0, _, _, Tree) ).

test(light_trees_exist, [forall(le_wasm_pack:light_excluded(Tree))]) :-
    %  A row naming a directory that moved would silently exclude nothing.
    exists_directory(Tree).

test(the_rest_of_regulatory_is_carried) :-
    payload_files(Files),
    memberchk('examples/regulatory/eu261_integration.le', Files),
    memberchk('examples/migration/README.md', Files).

test(restricted_trees_left_out) :-
    payload_files(Files),
    \+ ( member(F, Files), sub_atom(F, _, _, _, 'moreExamples/lpsPlus') ),
    \+ ( member(F, Files), sub_atom(F, 0, _, _, 'testing/fixtures') ).

:- end_tests(wasm_pack).
