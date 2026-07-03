/** <module> Integration tests for the LE debugger tracer (dap_server + reasoner).

    Drives the reasoner in debug mode with dap_server's test-capture seam, which
    records each stop (Port, Goal, Anc) instead of talking to a websocket. Verifies:
    - ALL answers are traceable, not only the first (the reasoner's debug branch uses
      a soft cut so backtracking into further solutions is preserved).
    - a "for all cases in which …" (forall) goal stays on the ancestor stack while its
      condition and consequent are solved (so it does not vanish from the debugger).

    Uses examples/moreExamples/testing/trace_sample.le. Run with:
        swipl -g run_tests -t halt testing/test_dap_trace.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_dap_trace, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../reasoner').
:- use_module('../dap_server').

% Run Query (over scenario s) in debug mode and collect the recorded stops.
run_trace(Query, Stops) :-
    le_kbs:load('examples/moreExamples/testing/trace_sample.le', KB),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, s),
    KB:query_info(Query, Goal, _),
    retractall(dap_server:dap_test_stop(_, _, _)),
    setup_call_cleanup(
        assertz(dap_server:dap_test_capture),
        setup_call_cleanup(
            assertz(SM:debug_mode),
            % Enumerate every solution so backtracking is exercised.
            ignore(forall(reasoner:i(Goal, SM, _U, _W), true)),
            retractall(SM:debug_mode)),
        retract(dap_server:dap_test_capture)),
    findall(stop(Port, G, Anc), dap_server:dap_test_stop(Port, G, Anc), Stops),
    le_kbs:destroySession(SM).

strip_le_at(le_at(G, _, _), G) :- !.
strip_le_at(G, G).

:- begin_tests(dap_trace).

% Issue: "only the first answer is traceable". Query 'happy' has two answers
% (alice, bob); both must appear as exit stops of is_happy/1.
test(all_answers_are_traced) :-
    run_trace(happy, Stops),
    findall(P,
        ( member(stop(exit, G0, _), Stops),
          strip_le_at(G0, G), functor(G, is_happy, 1), arg(1, G, P), atom(P) ),
        People0),
    sort(People0, People),
    assertion(People == [alice, bob]).

% Issue: forall calls "disappear" while their condition/consequent execute. The
% forall goal must be present in the ancestor stack recorded for some inner stop.
test(forall_stays_on_the_stack) :-
    run_trace(friendly, Stops),
    assertion((
        member(stop(_, _, Anc), Stops),
        member(A, Anc), strip_le_at(A, forall(_, _))
    )).

:- end_tests(dap_trace).
