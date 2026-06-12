/** <module> Unit tests for the idle-session reaper and its interaction with the
    shared, content-addressed KB modules (le_kbs.pl).

    These tests pin down the concurrency hardening:

      * a session that is refreshed (note_session_use/1) after the reaper has
        snapshotted it as stale must NOT be reaped — the time-of-check/time-of-use
        re-check in maybe_reap_session/3 protects it;
      * a genuinely idle session IS reaped;
      * a KB module shared by several sessions is preserved as long as ANY live
        session references it (so reaping one tab/user does not pull the KB out
        from under another), and is reclaimed once the last referencing session
        is reaped.

    Run with:  swipl -g run_tests -t halt testing/test_session_reaper.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_session_reaper, []).

:- use_module(library(plunit)).
% le_kbs.pl lives in the repo root, one level up from this testing/ file.
:- use_module('../le_kbs').

% A fresh, self-referencing (i.e. "generated") KB module holding one content
% clause, so we can observe whether the reaper has abolished it.
make_kb(KB) :-
    gensym(test_kb_, KB),
    assertz(KB:le_kb_module_fact(KB)),
    assertz(KB:content_fact(present)).

kb_alive(KB) :- catch(KB:content_fact(present), _, fail).

% Force a session's last-use timestamp to an explicit value (under the same
% mutex the production code uses).
set_last_used(SM, When) :-
    with_mutex(le_sessions, (
        retractall(le_kbs:session_last_used(SM, _)),
        assertz(le_kbs:session_last_used(SM, When))
    )).

idle_limit(MaxIdle) :- le_kbs:session_max_idle(MaxIdle).

:- begin_tests(session_reaper).

% A session idle beyond the limit is reclaimed.
test(stale_session_is_reaped) :-
    make_kb(KB),
    le_kbs:createSession(KB, SM),
    get_time(Now),
    StaleAt is Now - 3600,
    set_last_used(SM, StaleAt),
    le_kbs:reap_idle_sessions,
    assertion(\+ le_kbs:session_last_used(SM, _)).

% A session that was stale in the reaper's snapshot but refreshed before the
% actual reap survives: maybe_reap_session/3 re-checks the (now fresh) timestamp
% under the mutex and backs off. This is the core TOCTOU fix.
test(refreshed_session_survives_toctou) :-
    make_kb(KB),
    le_kbs:createSession(KB, SM),
    idle_limit(MaxIdle),
    get_time(Now),
    % SnapshotNow models the time at which the reaper listed SM as a candidate.
    SnapshotNow = Now,
    % Meanwhile a concurrent request refreshed SM, so its current timestamp is
    % fresh (now), not the stale value the snapshot was based on.
    set_last_used(SM, Now),
    le_kbs:maybe_reap_session(SM, SnapshotNow, MaxIdle),
    assertion(le_kbs:session_last_used(SM, _)).

% A KB shared by two sessions is preserved while either remains live, then
% reclaimed once the last one is reaped.
test(shared_kb_preserved_until_last_session_gone) :-
    make_kb(KB),
    le_kbs:createSession(KB, S1),
    le_kbs:createSession(KB, S2),
    get_time(Now),
    % S1 goes idle; S2 stays fresh.
    StaleAt is Now - 3600,
    set_last_used(S1, StaleAt),
    le_kbs:reap_idle_sessions,
    assertion(\+ le_kbs:session_last_used(S1, _)),   % S1 reaped
    assertion(le_kbs:session_last_used(S2, _)),       % S2 kept
    assertion(kb_alive(KB)),                          % shared KB preserved
    % Now S2 also goes idle and is reaped: the KB must be reclaimed.
    set_last_used(S2, StaleAt),
    le_kbs:reap_idle_sessions,
    assertion(\+ le_kbs:session_last_used(S2, _)),
    assertion(\+ kb_alive(KB)).

:- end_tests(session_reaper).
