/** <module> A query that runs out of time replies so (classic_web_api)

    A query that does not finish within its limit is stopped and answers
    `timedOut` (with the limit), instead of the HTTP dispatcher killing the
    request with a 500 and an error report — as a looping rule did in
    production (Sentry: `throw: time_limit_exceeded`, operation answeringQuery).

    Run with:  swipl -q -g run_tests -t halt testing/test_query_time_limit.pl
*/

:- module(test_query_time_limit, []).

:- use_module(library(plunit)).
:- use_module('../classic_web_api').
:- use_module('../le_kbs').

%   Exponentially many proofs of "40 is reachable", each then failing on
%   "is excluded": a search that does not end in any reasonable time (the
%   reasoner catches a plain loop, so the test needs a genuinely long one).
loop_program("the target language is: prolog.

the templates are:
    *a number* is reachable.
    *a number* is excluded.
    *a number* is wanted.

the knowledge base loop includes:

0 is reachable.

a number N is reachable if
    N > 0
    and M is N - 1
    and M is reachable.

a number N is reachable if
    N > 1
    and M is N - 2
    and M is reachable.

a number N is wanted if
    N is reachable
    and N is excluded.

scenario s is:
    1 is excluded.

query loop is:
    40 is wanted.
").

:- begin_tests(query_time_limit).

test(a_looping_query_times_out_with_a_reply) :-
    loop_program(Text),
    le_kbs:load_text(Text, KB),
    le_kbs:createSession(KB, SM),
    le_kbs:setScenarion(SM, s),
    get_time(T0),
    classic_web_api:run_interruptible_query(SM, "loop", KB, 2, Response),
    get_time(T1),
    le_kbs:destroySession(SM),
    assertion(get_dict(timedOut, Response, true)),
    assertion(Response.timeLimit == 2),
    assertion(T1 - T0 < 30).

test(the_operation_limits) :-
    classic_web_api:operation_time_limit(_{operation: "answeringQuery"}, L1),
    classic_web_api:operation_time_limit(_{operation: "answeringQuery", debug: true}, L2),
    classic_web_api:operation_time_limit(_{operation: "load"}, L3),
    assertion(L1 == 300), assertion(L2 == 3660), assertion(L3 == 300).

:- end_tests(query_time_limit).
