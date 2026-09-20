/** <module> library(http/http_json), minus the HTTP

    Two modules import this for one predicate each and neither of them is
    serving a request: le_services.pl posts JSON to a service, and
    le_assistant.pl reads a JSON reply. The predicates that *write* a reply
    (reply_json/1, reply_json_dict/2) belong to a server, and this build is
    not one — they refuse rather than write to a stream nobody is reading.
*/

:- module(http_json, [
    http_read_json_dict/2,      % +Stream, -Dict
    http_read_json_dict/3,      % +Stream, -Dict, +Options
    http_read_json/2,           % +Stream, -JSON
    reply_json/1,               % +Dict
    reply_json/2,               % +Dict, +Options
    reply_json_dict/1,          % +Dict
    reply_json_dict/2           % +Dict, +Options
    ]).

:- use_module(library(json)).

http_read_json_dict(Stream, Dict) :-
    http_read_json_dict(Stream, Dict, []).
http_read_json_dict(Stream, Dict, Options) :-
    json_read_dict(Stream, Dict, Options).

http_read_json(Stream, JSON) :-
    json_read(Stream, JSON).

reply_json(Dict) :- reply_json(Dict, []).
reply_json(_Dict, _Options) :- no_reply(reply_json/2).
reply_json_dict(Dict) :- reply_json_dict(Dict, []).
reply_json_dict(_Dict, _Options) :- no_reply(reply_json_dict/2).

no_reply(PI) :-
    throw(error(permission_error(reply, http_request, PI),
                context(PI, 'there is no HTTP request to reply to in the WebAssembly build'))).
