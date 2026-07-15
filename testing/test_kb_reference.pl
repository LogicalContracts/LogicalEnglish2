/** <module> Tests for KB-module liveness references (with_kb_reference/2).

    A sessionless reader that inspects a generated KB module — e.g. the example
    listings calling kbSummary/2 on every example — used to race against
    maybe_destroy_kb/1: a concurrent request's session teardown could reclaim
    (abolish) the module mid-read, crashing the reader with
    existence_error(procedure, m...:le_dict/1). This was the recurring
    mcp.spec.ts e2e failure. with_kb_reference/2 registers the reader in the
    reclaimer's guard; kb_summary_safe/3 packages load + reference + summary
    with a retry for the load-to-reference gap.

    Run with:  swipl -q -g run_tests -t halt testing/test_kb_reference.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_kb_reference, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

% A freshly loaded generated KB module with NO session referencing it — i.e.
% reclaim-eligible. Loaded via load_text so the module is private to the test.
sessionless_kb(KB) :-
    Text = "the target language is: prolog.\nthe templates are:\n    *a person* is happy.\n\nthe knowledge base ref includes:\n\nfluffy is happy.\n",
    le_kbs:load_text(Text, KB),
    % load_text registers the module as a generated KB (le_kb_module_fact(KB)).
    assertion(le_kbs:is_generated_kb_module(KB)).

:- begin_tests(kb_reference).

% While a reference is held, maybe_destroy_kb must leave the module intact;
% once released, the same call reclaims it.
test(reference_blocks_reclaim_release_allows_it) :-
    sessionless_kb(KB),
    le_kbs:with_kb_reference(KB, (
        le_kbs:maybe_destroy_kb(KB),
        assertion(current_predicate(KB:le_dict/1))
    )),
    le_kbs:maybe_destroy_kb(KB),
    assertion(\+ current_predicate(KB:le_dict/1)).

% References count: an inner reader releasing must not strip an outer reader's
% protection (one fact per reader; retract removes one).
test(nested_references_are_counted) :-
    sessionless_kb(KB),
    le_kbs:with_kb_reference(KB, (
        le_kbs:with_kb_reference(KB, true),
        le_kbs:maybe_destroy_kb(KB),
        assertion(current_predicate(KB:le_dict/1))
    )),
    le_kbs:maybe_destroy_kb(KB),
    assertion(\+ current_predicate(KB:le_dict/1)).

% The reference is released even when the guarded goal throws.
test(reference_released_on_exception) :-
    sessionless_kb(KB),
    catch(le_kbs:with_kb_reference(KB, throw(boom)), boom, true),
    le_kbs:maybe_destroy_kb(KB),
    assertion(\+ current_predicate(KB:le_dict/1)).

% The load+reference+summarize step (kb_summary_compute, the uncached core of
% kb_summary_safe) survives a concurrent reclaimer hammering the module: no
% existence_error escapes and every round yields a real summary. (Without the
% reference this crashed with existence_error(le_dict/1) — the original e2e race.)
test(summary_survives_concurrent_reclaim, [true(Bad == [])]) :-
    tmp_file_stream(text, Path, S),
    format(S, "the target language is: prolog.~nthe templates are:~n    *a person* is happy.~n~nthe knowledge base stress includes:~n~nfluffy is happy.~n", []),
    close(S),
    le_kbs:load(Path, KB, [skip_tests]),
    message_queue_create(Q),
    thread_create(reclaim_loop(KB, Q), Reclaimer, []),
    findall(R,
        ( between(1, 300, _),
          ( le_kbs:kb_summary_compute(Path, [skip_tests], Sum), string(Sum) -> R = ok ; R = bad )
        ), Rs),
    thread_send_message(Q, stop),
    thread_join(Reclaimer, _),
    exclude(==(ok), Rs, Bad),
    delete_file(Path).

% kb_summary_safe caches by modification time: the summary is computed once,
% and editing the file (a different mtime) recomputes it.
test(summary_is_cached_by_mtime) :-
    tmp_file_stream(text, Path, S),
    format(S, "the target language is: prolog.~nthe templates are:~n    *a person* is happy.~n~nthe knowledge base cache1 includes:~n~nfluffy is happy.~n", []),
    close(S),
    le_kbs:kb_summary_safe(Path, [skip_tests], Sum1),
    assertion(sub_string(Sum1, _, _, _, "cache1")),
    le_kbs:kb_summary_safe(Path, [skip_tests], Sum2),
    assertion(Sum1 == Sum2),
    % Rewrite with a different KB name AND a different mtime.
    sleep(1.1),
    open(Path, write, S2),
    format(S2, "the target language is: prolog.~nthe templates are:~n    *a person* is happy.~n~nthe knowledge base cache2 includes:~n~nfluffy is happy.~n", []),
    close(S2),
    le_kbs:kb_summary_safe(Path, [skip_tests], Sum3),
    assertion(sub_string(Sum3, _, _, _, "cache2")),
    delete_file(Path).

% Keeps reclaiming KB until told to stop (simulates concurrent session teardowns).
reclaim_loop(KB, Q) :-
    (   thread_peek_message(Q, stop)
    ->  true
    ;   catch(le_kbs:maybe_destroy_kb(KB), _, true),
        reclaim_loop(KB, Q)
    ).

:- end_tests(kb_reference).
