/*  A load that cannot give a session answers why, instead of failing: a
    failed operation was a 500 and a Sentry report "the operation failed
    without an exception" that said nothing of what had happened.
*/
:- use_module('../classic_web_api').
:- use_module('../le_telemetry').

:- begin_tests(load_refusals).

%   An example that does not exist (an old link, a mistyped ?example=).
test(missing_example_is_not_found) :-
    classic_web_api:handle_load(_{file: "no/such/example_zzz"}, R),
    assertion(get_dict(notFound, R, true)),
    assertion(( get_dict(error, R, E), sub_string(E, _, _, _, "no/such/example_zzz") )).

%   A program that loads still gets its session.
test(loadable_text_gets_a_session) :-
    classic_web_api:handle_load(_{le: "the target language is: prolog.\n\nthe templates are:\n    *a thing* is fine.\n\nthe knowledge base t includes:\n    a thing is fine if the thing is fine.\n"}, R),
    assertion(get_dict(sessionModule, R, _)).

%   A failure inside the server names its stage in the report.
test(failure_report_names_the_stage) :-
    le_telemetry:error_type_value(failed(load_text), Type, Value, Level, _),
    assertion(Type == failure), assertion(Level == error),
    assertion(sub_string(Value, _, _, _, "at load_text")).

:- end_tests(load_refusals).
