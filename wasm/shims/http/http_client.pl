/** <module> library(http/http_client), the two predicates llm_client.pl uses

    llm/llm_client.pl posts to an LLM provider with http_post/4 and reads a
    JSON reply. Everything else in that library is a server's business.

    The post goes through http_open/3 above, so it obeys the same rule: the
    browser will not let a page post to another origin unless that origin
    allows it, and no LLM provider does. A deployment that wants "Write it in
    English" to work therefore puts its own proxy in front (wasm/api/proxy.js),
    and le_wasm.pl rewrites the provider's address into the proxy's.
*/

:- module(http_client, [
    http_post/4,                % +URL, +Data, -Reply, +Options
    http_get/3,                 % +URL, -Reply, +Options
    http_read_data/3            % +Request, -Data, +Options
    ]).

:- use_module(library(option)).
:- use_module(library(json)).
:- use_module(http_open).

http_post(URL, Data, Reply, Options) :-
    http_open(URL, In, [post(Data)|Options]),
    setup_call_cleanup(true, read_reply(In, Reply, Options), close(In)).

http_get(URL, Reply, Options) :-
    http_open(URL, In, Options),
    setup_call_cleanup(true, read_reply(In, Reply, Options), close(In)).

%   http_post/4 with json_object(dict) means "give me a dict"; without it,
%   give back the text, which is all the other callers want.
read_reply(In, Reply, Options) :-
    (   option(json_object(dict), Options)
    ->  catch(json_read_dict(In, Reply, [value_string_as(string)]), _, Reply = _{})
    ;   read_string(In, _, Reply)
    ).

http_read_data(_Request, _Data, _Options) :-
    throw(error(permission_error(read, http_request, http_read_data/3),
                context(http_read_data/3, 'no HTTP request in the WebAssembly build'))).
