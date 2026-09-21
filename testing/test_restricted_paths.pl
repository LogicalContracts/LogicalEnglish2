/* test_restricted_paths.pl — what is closed stays closed, and what a public
   page links to opens.

   restricted_paths:open_to_everyone/1 lets a named file out of a restricted
   tree (the Medicare power mobility policy, linked from LPS2's /insurance
   page and the insurance leaflet). The exception is by file: these tests are
   the ways it could have been wider than that.
*/

:- use_module(library(plunit)).
:- use_module('../restricted_paths').

:- begin_tests(restricted_paths, [setup(unsetenv('NO_RESTRICTIONS'))]).

med(Rel, Path) :- atom_concat('examples/moreExamples/lpsPlus/medicare/', Rel, Path).

test(open_program_by_example_name) :- med(pmd_cases, P), is_path_allowed(P, []).
test(open_program_by_file_name)    :- med('pmd_cases.le', P), is_path_allowed(P, []).
test(open_included_library)        :- med('dmepos.le', P), is_path_allowed(P, []).
test(open_cited_text)              :- med('sources/lcd/L33789.txt', P), is_path_allowed(P, []).
test(open_with_an_absolute_path) :-
    med('pmd.le', P), atom_concat('/app/', P, Abs), is_path_allowed(Abs, []).
test(open_whatever_the_case) :-
    is_path_allowed('examples/moreExamples/LPSPLUS/medicare/PMD.le', []).

test(sibling_program_closed, [fail])   :- med('oxygen_cases.le', P), is_path_allowed(P, []).
test(name_with_open_prefix_closed, [fail]) :- med('pmd_cases_more.le', P), is_path_allowed(P, []).
test(name_with_open_suffix_closed, [fail]) :- med('council_pmd.le', P), is_path_allowed(P, []).
test(uncited_text_closed, [fail])      :- med('sources/lcd/L33797.txt', P), is_path_allowed(P, []).
test(folder_closed, [fail])            :- med('', P), is_path_allowed(P, []).
test(sources_folder_closed, [fail])    :- med(sources, P), is_path_allowed(P, []).
test(text_is_not_a_program, [fail])    :- med('sources/lcd/L33789.txt.le', P), is_path_allowed(P, []).
test(dot_dot_closed, [fail]) :-
    med('oxygen.le/../pmd.le', P), is_path_allowed(P, []).
test(dot_dot_out_closed, [fail]) :-
    med('pmd.le/../oxygen.le', P), is_path_allowed(P, []).
test(other_restricted_tree_closed, [fail]) :-
    is_path_allowed('examples/moreExamples/insureLE2/medicare/pmd.le', []).

test(role_still_opens_the_rest)  :- med('oxygen_cases.le', P), is_path_allowed(P, [insurLE2]).
test(public_example_untouched)   :- is_path_allowed('examples/moreExamples/citizenship.le', []).

%   Every open file exists where the link says (when lpsPlus is checked out
%   beside this repository), or the page sends visitors to "File not found".
test(open_files_exist, [condition(exists_directory('examples/moreExamples/lpsPlus/medicare'))]) :-
    forall(open_to_everyone(F),
           (   ( exists_file(F) ; atom_concat(F, '.le', LE), exists_file(LE) )
           ->  true
           ;   print_message(error, format("open_to_everyone: no such file ~w", [F])), fail
           )).

:- end_tests(restricted_paths).
