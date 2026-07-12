% Tests for load/3 with the skip_tests option: example listings load every KB
% for its summary, and running each KB's embedded expected-answer tests there
% made the listing endpoints take tens of seconds. skip_tests loads must not
% run the tests, and must not be reused as a cache hit by a later full load
% (which would silently lose the failed_test diagnostics).

:- use_module('../le_kbs').

% An LE program whose expected answer is wrong, so a full load reports a
% failed_test issue.
failing_le_text("the target language is: prolog.

the templates are:
    *a person* is happy.
    *a person* is healthy.

the knowledge base skiptests includes:

a person is happy if the person is healthy.

scenario one is:
    bob is healthy.
    one expects answers [\"alice is happy\"].

query one is:
    which person is happy.
").

% Each test writes its own copy of the file: load/3 keys its module cache on
% the file path and modification time, so distinct paths keep tests independent.
setup_le_file(Name, Path) :-
    tmp_file_stream(text, Path0, Stream),
    close(Stream),
    atomic_list_concat([Path0, '_', Name, '.le'], Path),
    failing_le_text(Text),
    setup_call_cleanup(open(Path, write, Out), write(Out, Text), close(Out)).

:- begin_tests(skip_tests_load).

test(full_load_reports_failed_test, [setup(setup_le_file(full, Path)), cleanup(delete_file(Path))]) :-
    le_kbs:load(Path, M),
    assertion(M:le_issue(warning, failed_test, _, _, _, _)).

test(skip_tests_load_runs_no_tests, [setup(setup_le_file(light, Path)), cleanup(delete_file(Path))]) :-
    le_kbs:load(Path, M, [skip_tests]),
    assertion(\+ M:le_issue(_, failed_test, _, _, _, _)),
    % Other checks still run: 'healthy' has no rule and no scenario fact for it
    % beyond bob's, so the module keeps its non-test diagnostics machinery.
    assertion(current_predicate(M:le_issue/6)).

% A module cached by a skip_tests load must not satisfy a full load: the full
% load rebuilds it and the failed_test issue appears.
test(full_load_after_light_load_rebuilds, [setup(setup_le_file(upgrade, Path)), cleanup(delete_file(Path))]) :-
    le_kbs:load(Path, M, [skip_tests]),
    assertion(\+ M:le_issue(_, failed_test, _, _, _, _)),
    le_kbs:load(Path, M2),
    assertion(M == M2),
    assertion(M2:le_issue(warning, failed_test, _, _, _, _)).

% The reverse is fine: a fully verified module is a superset, so a skip_tests
% load reuses it, failed_test issue included.
test(light_load_after_full_load_reuses, [setup(setup_le_file(reuse, Path)), cleanup(delete_file(Path))]) :-
    le_kbs:load(Path, M),
    assertion(M:le_issue(warning, failed_test, _, _, _, _)),
    le_kbs:load(Path, M2, [skip_tests]),
    assertion(M == M2),
    assertion(M2:le_issue(warning, failed_test, _, _, _, _)).

:- end_tests(skip_tests_load).
