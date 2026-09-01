/** <module> Unit tests for the core / core+extensions example-suite split.

    The LE example suite comes in two variants (le_kbs:le_suite/1):

      * core — the programs that run on this repository alone. This is what CI,
        ours and a downstream user's, gates on: it is the suite a clean checkout
        can make green.
      * all  — core plus the example trees that need the proprietary
        le_extensions.pl.

    The exclusion is a hardwired table of path fragments
    (le_kbs:extension_dependent_path_fragment/1). These tests pin down what that
    table must do, because getting it subtly wrong is silent in both directions:
    over-matching quietly drops core coverage (a green run that tested less than
    it looked like), and under-matching puts back the unparseable programs whose
    failures say nothing about core LE.

    Run with:  swipl -g run_tests -t halt testing/test_core_suite_selection.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_core_suite_selection, []).

:- use_module('../le_kbs').

:- begin_tests(core_suite_selection).

test(both_suites_exist, [nondet]) :-
    findall(S, le_kbs:le_suite(S), Suites),
    msort(Suites, [all, core]).

% --- core excludes the extension-dependent trees ----------------------------

test(core_excludes_symlinked_tree) :-
    \+ le_kbs:suite_includes(core, 'examples/moreExamples/insureLE2/globals.le').

% The same tree also appears with a different capitalisation; on a
% case-sensitive filesystem both are walked, so the table matches case-blind.
test(core_excludes_other_capitalisation) :-
    \+ le_kbs:suite_includes(core, 'examples/moreExamples/InsurLE2/globals.le').

test(core_excludes_nested_files) :-
    \+ le_kbs:suite_includes(core, 'examples/moreExamples/insureLE2/testing/fema/fema-gpt-5.5.le').

% The directory itself must be excluded too, so the walk prunes the whole tree
% instead of descending and rejecting file by file.
test(core_excludes_the_directory_itself) :-
    \+ le_kbs:suite_includes(core, 'examples/moreExamples/insureLE2').

% --- core keeps everything else ---------------------------------------------

test(core_includes_ordinary_example) :-
    le_kbs:suite_includes(core, 'examples/moreExamples/citizenship.le').

test(core_includes_language_tree) :-
    le_kbs:suite_includes(core, 'examples/pt/desconhecidos.le').

% The fragments name whole directories, so a file merely *about* insurance —
% of which the tax corpus has several — stays in the core suite.
test(core_does_not_overmatch_similar_names) :-
    le_kbs:suite_includes(core, 'examples/moreExamples/tax/insurance_payouts.le'),
    le_kbs:suite_includes(core, 'examples/moreExamples/insurers.le').

% --- all includes everything -------------------------------------------------

test(all_includes_extension_tree) :-
    le_kbs:suite_includes(all, 'examples/moreExamples/insureLE2/globals.le').

test(all_includes_ordinary_example) :-
    le_kbs:suite_includes(all, 'examples/moreExamples/citizenship.le').

% --- status files ------------------------------------------------------------
%
% Each suite owns its status file and neither run may touch the other's. With
% one shared file the two snapshots were indistinguishable after the fact:
% whichever variant ran last silently redefined what the repository claimed
% green was.

test(each_suite_has_its_own_status_file) :-
    le_kbs:suite_status_file(core, Core),
    le_kbs:suite_status_file(all, All),
    Core == 'testSuiteCoreStatus.txt',
    All  == 'testSuiteStatus.txt',
    Core \== All.

test(every_suite_has_a_status_file) :-
    forall(le_kbs:le_suite(S), le_kbs:suite_status_file(S, _)).

test(writing_one_status_file_leaves_the_other_alone,
     [setup(tmp_dir(Dir)), cleanup(delete_tmp(Dir)), nondet]) :-
    directory_file_path(Dir, 'a.txt', A),
    directory_file_path(Dir, 'b.txt', B),
    le_kbs:write_test_status_file(A, core, []),
    le_kbs:write_test_status_file(B, all, []),
    read_file_to_string(A, SA, []),
    read_file_to_string(B, SB, []),
    sub_string(SA, _, _, _, "Suite:      core"),
    sub_string(SB, _, _, _, "Suite:      all"),
    % each names the other, so a reader who opened the wrong one is redirected
    sub_string(SA, _, _, _, "testSuiteStatus.txt"),
    sub_string(SB, _, _, _, "testSuiteCoreStatus.txt").

tmp_dir(Dir) :-
    tmp_file_stream(text, File, S), close(S), delete_file(File),
    atom_concat(File, '.d', Dir), make_directory(Dir).

delete_tmp(Dir) :-
    forall(( directory_files(Dir, Fs), member(F, Fs), \+ memberchk(F, ['.', '..']) ),
           ( directory_file_path(Dir, F, P), catch(delete_file(P), _, true) )),
    catch(delete_directory(Dir), _, true).

% --- the entry points --------------------------------------------------------

test(unknown_suite_is_a_domain_error,
     [throws(error(domain_error(le_suite(_), bogus), _))]) :-
    le_kbs:runTests(bogus).

:- end_tests(core_suite_selection).
