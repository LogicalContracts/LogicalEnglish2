/* test_restricted_paths.pl — what is closed stays closed, and the public
   models open to everyone.

   The customs and Medicare models, and the OIPA twins, used to live in the
   restricted lpsPlus tree (with three Medicare programs let out of it for
   LPS2's /insurance page). Since 23 September 2026 they are public examples:
   these tests check that they open without a role, and that the trees that
   are still restricted are not.
*/

:- use_module(library(plunit)).
:- use_module('../restricted_paths').

:- begin_tests(restricted_paths, [setup(unsetenv('NO_RESTRICTIONS'))]).

test(medicare_is_public) :-
    is_path_allowed('examples/regulatory/medicare/pmd_cases.le', []),
    is_path_allowed('examples/regulatory/medicare/oxygen_cases.le', []),
    is_path_allowed('examples/regulatory/medicare/sources/lcd/L33797.txt', []).
test(customs_is_public) :-
    is_path_allowed('examples/regulatory/customs/tariff.le', []).
test(oipa_twins_are_public) :-
    is_path_allowed('examples/migration/oipa/termlife_issue/termlife_issue.le', []).
test(public_example_untouched) :-
    is_path_allowed('examples/moreExamples/citizenship.le', []).

test(lpsplus_tree_closed, [fail]) :-
    is_path_allowed('examples/moreExamples/lpsPlus/migration/socotra/term_life/term_life.le', []).
test(lpsplus_tree_closed_whatever_the_case, [fail]) :-
    is_path_allowed('/app/examples/moreExamples/LPSPLUS/migration/oia/dctad/dctad.le', []).
test(insurle_tree_closed, [fail]) :-
    is_path_allowed('examples/moreExamples/insureLE2/testing/policy.le', []).
test(fixtures_closed, [fail]) :-
    is_path_allowed('testing/fixtures/le/nonterminating.le', []).

test(role_opens_the_lpsplus_tree) :-
    is_path_allowed('examples/moreExamples/lpsPlus/migration/oia/dctad/dctad.le', [insurLE2]).
test(developer_opens_fixtures) :-
    is_path_allowed('testing/fixtures/le/nonterminating.le', [developer]).

:- end_tests(restricted_paths).
