/** <module> Integrity check for the LE program files the test suites depend on.

    Several suites load specific .le example files by a fixed path or name:

      * testing/test_proof_game.pl          loads alice.le
      * testing/test_grammar_dangling_that.pl loads testing/tea_party2.le
      * editor/tests/editor.spec.ts         opens citizenship.le, payg.le,
                                            nonterminating.le from the server
      * editor/tests/api/mcp.spec.ts        uses citizenship (example_name/file)

    If one of these files is moved or renamed, the dependent tests fail with a
    less obvious error (file-not-found, or a missing example in the UI). This
    test makes the dependency explicit: it fails loudly, naming the offending
    file, the moment a fixture is no longer where the suites expect it.

    If you intentionally relocate a fixture, update both the dependent test(s)
    AND the list below.

    Paths are relative to the repo root, which is where testing/run_tests.sh runs
    every suite from.

    Run with:  swipl -q -g run_tests -t halt testing/test_fixtures_integrity.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_fixtures_integrity, []).

:- use_module(library(plunit)).

% test_suite_fixture(Path, UsedBy)
test_suite_fixture('examples/moreExamples/alice.le',
                   'testing/test_proof_game.pl').
test_suite_fixture('examples/moreExamples/testing/tea_party2.le',
                   'testing/test_grammar_dangling_that.pl').
test_suite_fixture('examples/moreExamples/citizenship.le',
                   'editor/tests/editor.spec.ts, editor/tests/api/mcp.spec.ts').
test_suite_fixture('examples/moreExamples/tax/payg.le',
                   'editor/tests/editor.spec.ts').
test_suite_fixture('examples/moreExamples/testing/nonterminating.le',
                   'editor/tests/editor.spec.ts').

:- begin_tests(fixtures_integrity).

% Every LE program a test suite depends on must still exist at its expected
% path. A missing one is reported with the suite that relies on it.
test(all_test_fixture_files_present) :-
    findall(Path-UsedBy,
            ( test_suite_fixture(Path, UsedBy), \+ exists_file(Path) ),
            Missing),
    (   Missing \== []
    ->  format(user_error,
               "~nMissing LE test-fixture file(s) (expected by the test suites):~n", []),
        forall(member(P-U, Missing),
               format(user_error, "  - ~w   (needed by ~w)~n", [P, U]))
    ;   true
    ),
    assertion(Missing == []).

:- end_tests(fixtures_integrity).
