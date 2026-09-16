/** <module> Error reports and analytics (le_telemetry.pl)

    Off unless configured: no variable, no script beyond a no-op, no report.
    Configured: the DSN read right, the envelope Sentry expects (checked by
    a mock Sentry on a local port, which receives what the server sends),
    the same error sent once, and nothing of the request but its operation.

    Run with:  swipl -q -g run_tests -t halt testing/test_telemetry.pl
*/

:- module(test_telemetry, []).

:- use_module(library(plunit)).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_client)).
:- use_module(library(http/json)).
:- use_module(library(readutil)).
:- use_module('../le_telemetry').
:- use_module('../le_i18n').

:- dynamic received/2.          % Headers, Body

vars(['LE_SENTRY_DSN', 'LE_SENTRY_ENVIRONMENT', 'LE_SENTRY_RELEASE',
      'LE_CLOUDFLARE_ANALYTICS_TOKEN']).

clear_vars :-
    vars(Vs), forall(member(V, Vs), unsetenv(V)),
    retractall(le_telemetry:sent(_, _)),
    retractall(le_telemetry:hour(_, _)).

%   A Sentry that keeps what it is sent.
mock_sentry(Request) :-
    memberchk(x_sentry_auth(Auth), Request),
    http_read_data(Request, Body, [to(string)]),
    assertz(received(Auth, Body)),
    format('Content-type: application/json~n~n{"id":"x"}').

start_mock(Port) :-
    retractall(received(_, _)),
    http_server(mock_sentry, [port(localhost:Port)]).

stop_mock(Port) :-
    http_stop_server(localhost:Port, []).

wait_received(Auth, Body) :-
    between(1, 50, _),
    (   received(Auth, Body) -> true ; sleep(0.1), fail ), !.

:- begin_tests(telemetry, [setup(clear_vars), cleanup(clear_vars)]).

test(dsn_plain) :-
    sentry_dsn('https://abc123@o42.ingest.de.sentry.io/4507', D),
    assertion(D == dsn(https, abc123, 'o42.ingest.de.sentry.io', '', '4507')).

test(dsn_with_path_and_secret) :-
    sentry_dsn("http://key:secret@localhost:9000/sentry/12", D),
    assertion(D == dsn(http, key, 'localhost:9000', '/sentry', '12')).

test(dsn_refused, [fail]) :-
    sentry_dsn('not a dsn', _).

test(dsn_without_project, [fail]) :-
    sentry_dsn('https://abc@o1.ingest.sentry.io/', _).

test(off_by_default) :-
    telemetry_status(S),
    assertion(S.sentry == false),
    assertion(S.web_analytics == false),
    telemetry_js(JS),
    assertion(\+ sub_string(JS, _, _, _, "sentry-cdn")),
    assertion(\+ sub_string(JS, _, _, _, "cloudflareinsights")),
    telemetry_report(error(type_error(integer, a), _), [operation(answeringQuery)]),
    assertion(\+ le_telemetry:sent(_, _)).

test(envelope) :-
    sentry_envelope('https://pub@o1.ingest.sentry.io/77',
                    error(existence_error(procedure, foo/0), foo/0),
                    [operation(answeringQuery), environment(staging), release('le2@abc')],
                    envelope(Url, Auth, Body)), !,
    assertion(Url == 'https://o1.ingest.sentry.io/api/77/envelope/'),
    assertion(sub_atom(Auth, _, _, _, 'sentry_key=pub')),
    split_string(Body, "\n", "", [H, I, E, ""]),
    maplist([S, D]>>atom_json_dict(S, D, []), [H, I, E], [Header, Item, Event]),
    assertion(Header.event_id == Event.event_id),
    assertion(Item.type == "event"),
    assertion(Event.tags.operation == "answeringQuery"),
    assertion(Event.environment == "staging"),
    assertion(Event.release == "le2@abc"),
    [X] = Event.exception.values,
    assertion(X.type == "existence_error"),
    assertion(sub_string(X.value, _, _, _, "foo/0")).

test(configured_script) :-
    setenv('LE_SENTRY_DSN', 'https://pub@o1.ingest.sentry.io/77'),
    setenv('LE_CLOUDFLARE_ANALYTICS_TOKEN', '1b82e2b050984555b84cbcbd02983d7a'),
    le_i18n:set_le_language(pt),
    telemetry_js(JS),
    le_i18n:set_le_language(default),
    clear_vars,
    split_string(JS, "\n", "", [Line|_]),
    string_concat("var TELEMETRY = ", Json0, Line),
    string_concat(Json, ";", Json0),
    atom_json_dict(Json, C, []),
    assertion(C.sentry.dsn == "https://pub@o1.ingest.sentry.io/77"),
    assertion(sub_string(C.sentry.bundle, 0, _, _, "https://browser.sentry-cdn.com/")),
    assertion(C.sentry.labels.trigger == "Comentários"),
    assertion(C.webAnalytics.token == "1b82e2b050984555b84cbcbd02983d7a"),
    assertion(C.webAnalytics.beacon == "https://static.cloudflareinsights.com/beacon.min.js"),
    assertion(sub_string(JS, _, _, _, "data-cf-beacon")),
    assertion(\+ sub_string(JS, _, _, _, "posthog")).

test(web_analytics_alone) :-
    setenv('LE_CLOUDFLARE_ANALYTICS_TOKEN', 'tok'),
    telemetry_status(S),
    telemetry_js(JS),
    clear_vars,
    assertion(S.sentry == false),
    assertion(S.web_analytics == true),
    split_string(JS, "\n", "", [Line|_]),
    string_concat("var TELEMETRY = ", Json0, Line),
    string_concat(Json, ";", Json0),
    atom_json_dict(Json, C, []),
    assertion(C.sentry == null),
    assertion(C.webAnalytics.token == "tok").

test(report_reaches_sentry_once, [setup(start_mock(Port)), cleanup((stop_mock(Port), clear_vars))]) :-
    format(atom(DSN), 'http://pubkey@localhost:~w/5', [Port]),
    setenv('LE_SENTRY_DSN', DSN),
    E = error(type_error(integer, abc), context(foo/1, _)),
    telemetry_report(E, [operation(answeringQuery)]),
    telemetry_report(E, [operation(answeringQuery)]),       % the same: not sent again
    wait_received(Auth, Body),
    sleep(0.5),
    aggregate_all(count, received(_, _), N),
    assertion(N == 1),
    assertion(sub_atom(Auth, _, _, _, 'sentry_key=pubkey')),
    split_string(Body, "\n", "", [_, _, EventJson, ""]),
    atom_json_dict(EventJson, Event, []),
    assertion(Event.tags.operation == "answeringQuery"),
    assertion(Event.environment == "production"),
    telemetry_report(failed, [operation(load)]),              % another error: sent
    between(1, 50, _), ( aggregate_all(count, received(_, _), 2) -> true ; sleep(0.1), fail ), !.

test(unreachable_sentry_does_not_wait) :-
    setenv('LE_SENTRY_DSN', 'http://k@localhost:1/5'),
    get_time(T0),
    telemetry_report(error(foo, _), [operation(x)]),
    get_time(T1),
    clear_vars,
    assertion(T1 - T0 < 0.5).

test(test_endpoint_unconfigured) :-
    telemetry_test(R),
    assertion(R.sentry_test == 'not configured').

:- end_tests(telemetry).
