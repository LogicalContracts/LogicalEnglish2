%   Any operation on a session the server no longer has — reclaimed by the
%   idle-session reaper, or lost when the server restarted after the editor
%   loaded the program — replies {session_expired: true} so the editor reloads
%   and retries, instead of throwing an existence error from the missing
%   session module (Sentry, operation predicateAt: "Unknown procedure:
%   '<session>':le_kb_module_fact/1").

:- use_module(library(plunit)).
:- use_module('../le_api').

:- begin_tests(session_expired_ops).

gone('sbe9a5a39-b20c-11f1-ae01-dead737d1823').

test(predicate_at_on_a_gone_session) :-
    gone(SM),
    le_api:handle_operation(_{operation: "predicateAt", sessionModule: SM,
                                       position: 10, line: "a person is happy", lineStart: 0}, R),
    assertion(get_dict(session_expired, R, true)).

test(every_session_operation) :-
    gone(SM),
    forall(member(Op, ["predicateOccurrences", "provenanceAt", "originalTextAt", "getProlog",
                       "getScasp", "openQuestions", "testReport", "graph"]),
           ( le_api:handle_operation(_{operation: Op, sessionModule: SM, position: 0, line: ""}, R),
             assertion(get_dict(session_expired, R, true)) )).

test(no_session_is_not_expired) :-
    le_api:handle_operation(_{operation: "importFormats"}, R),
    assertion(\+ get_dict(session_expired, R, _)).

:- end_tests(session_expired_ops).
