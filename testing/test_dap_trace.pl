/** <module> Integration tests for the LE debugger tracer (dap_server + reasoner).

    Drives the reasoner in debug mode with dap_server's test-capture seam, which
    records each stop (Port, Goal, Anc) instead of talking to a websocket. Verifies:
    - ALL answers are traceable, not only the first (the reasoner's debug branch uses
      a soft cut so backtracking into further solutions is preserved).
    - a "for all cases in which …" (forall) goal stays on the ancestor stack while its
      condition and consequent are solved (so it does not vanish from the debugger).

    Uses testing/fixtures/le/trace_sample.le. Run with:
        swipl -g run_tests -t halt testing/test_dap_trace.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_dap_trace, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../reasoner').
:- use_module('../dap_server').

% Run Query (over scenario s) in debug mode and collect the recorded stops.
% Commands are given at the stops in order (stepIn after they run out);
% Setup(SM, Text) runs first, with the program's text (to place breakpoints).
% Outcome is `done`, or the exception that ended the query.
run_trace(Query, Stops) :-
    run_trace(Query, [], [_, _]>>true, Stops, _).

run_trace(Query, Commands, Setup, Stops, Outcome) :-
    File = 'testing/fixtures/le/trace_sample.le',
    le_kbs:load(File, KB),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, s),
    KB:query_info(Query, Goal, _),
    retractall(dap_server:dap_test_stop(_, _, _)),
    retractall(dap_server:dap_test_command(_)),
    retractall(dap_server:run_mode(SM, _)),
    forall(member(C, Commands), assertz(dap_server:dap_test_command(C))),
    read_file_to_string(File, Text, []),
    call(Setup, SM, Text),
    setup_call_cleanup(
        assertz(dap_server:dap_test_capture),
        setup_call_cleanup(
            assertz(SM:debug_mode),
            % Enumerate every solution so backtracking is exercised.
            catch(( ignore(forall(reasoner:i(Goal, SM, _U, _W), true)), Outcome = done ),
                  E, Outcome = E),
            retractall(SM:debug_mode)),
        retract(dap_server:dap_test_capture)),
    findall(stop(Port, G, Anc), dap_server:dap_test_stop(Port, G, Anc), Stops),
    retractall(dap_server:dap_test_command(_)),
    retractall(dap_server:breakpoint(SM, _, _, _)),
    le_kbs:destroySession(SM).

% A breakpoint on the line of Text holding Phrase, as the editor sets one.
breakpoint_on(Phrase, SM, Text) :-
    sub_string(Text, At, _, _, Phrase), !,
    sub_string(Text, 0, At, _, Before),
    (   sub_string(Before, LS, 1, _, "\n"), \+ ( sub_string(Before, L2, 1, _, "\n"), L2 > LS )
    ->  Start is LS + 1
    ;   Start = 0
    ),
    (   sub_string(Text, NL, 1, _, "\n"), NL > At -> End = NL ; string_length(Text, End) ),
    split_string(Before, "\n", "", Lines), length(Lines, Line),
    assertz(dap_server:breakpoint(SM, Line, Start, End)).

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

% Continue runs to the next answer: after the first stop, the only stops are
% the query's own goal exiting (an answer) or failing (no more).
test(continue_stops_only_at_answers) :-
    run_trace(happy, [continue, continue, continue, continue], [_, _]>>true, Stops, done),
    Stops = [_First|Rest],
    assertion(Rest \== []),
    assertion(forall(member(stop(_, _, Anc), Rest), Anc == [])).

% A breakpoint on "if the person is rich" stops a Continue at that call.
test(continue_stops_at_a_breakpoint) :-
    run_trace(happy, [continue, continue, continue, continue, continue, continue],
              breakpoint_on("if the person is rich"), Stops, done),
    Stops = [_|Rest],
    assertion(( member(stop(call, G0, _), Rest), strip_le_at(G0, G), functor(G, is_rich, 1) )).

% Step over (next) does not stop deeper than where it was given.
test(next_steps_over) :-
    run_trace(friendly, [stepIn, next], [_, _]>>true, Stops, done),
    Stops = [_, stop(_, _, Anc2), stop(_, _, Anc3)|_],
    length(Anc2, D2), length(Anc3, D3),
    assertion(D3 =< D2).

% Stop ends the query, as the Interrupt button does, instead of leaving it
% running undebugged.
test(stop_ends_the_query) :-
    run_trace(happy, [stepIn, disconnect], [_, _]>>true, Stops, Outcome),
    assertion(Outcome == query_interrupted),
    length(Stops, 2).

:- end_tests(dap_trace).
