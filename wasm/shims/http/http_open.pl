/** <module> library(http/http_open), over the browser's own fetch

    Five places in LE2 open an HTTP stream: a document fetched from a URL
    (le_documents.pl), a resource included by a program (le_kbs.pl), a
    declared service (le_services.pl), the model price table (llm_prices.pl)
    and Sentry (le_telemetry.pl). `library(http/http_open)` is a socket
    library, and a browser tab has no sockets — but it does have a network,
    reached through the page rather than through the operating system.

    So this is not a stub: it really fetches. The request goes out to the
    host's `fetch` (le_wasm.pl → the worker → XMLHttpRequest, synchronously,
    which is allowed in a worker and is what a blocked Prolog wants anyway),
    and the reply comes back as a memory-file stream that reads exactly like
    the socket stream would have.

    Two things behave differently, and both are the browser's rules rather
    than this file's:

      1. **Same-origin, or CORS.** A page may fetch its own origin freely and
         another only with that server's permission. An LLM provider gives no
         such permission, which is the reason the Vercel deployment puts a
         proxy of its own in front of them (wasm/api/proxy.js): the key stays on
         the server, and the request is same-origin. le_wasm.pl rewrites a
         request to a configured provider into a request to that proxy.
      2. **No timeouts on the wire.** `timeout(S)` is passed on to the XHR,
         which honours it in a worker; a browser that does not simply takes as
         long as it takes.
*/

:- module(http_open, [
    http_open/3                 % +URL, -Stream, +Options
    ]).

:- use_module(library(lists)).
:- use_module(library(option)).
:- use_module(library(json)).
:- use_module(library(memfile)).

%!  http_open(+URL, -Stream, +Options) is det.
%
%   Options understood: method/1, post/1 (json/1, string/2, atom/1,
%   codes/1), request_header/1 (any number), status_code/1, header/2,
%   timeout/1, size/1. Anything else is ignored, as http_open/3 ignores
%   options it does not know.
http_open(URL, Stream, Options) :-
    request_method(Options, Method),
    request_body(Options, Body, BodyType),
    request_headers(Options, BodyType, Headers),
    (   option(timeout(TimeOut), Options) -> Timeout is truncate(TimeOut*1000) ; Timeout = 0 ),
    atom_string(URL, URLS),
    Request = _{url: URLS, method: Method, headers: Headers, body: Body, timeout: Timeout},
    le_wasm:le_wasm_fetch(Request, Reply),
    (   get_dict(error, Reply, Err), Err \== null
    ->  throw(error(existence_error(url, URL), context(http_open/3, Err)))
    ;   true
    ),
    Code = Reply.status,
    (   option(status_code(Code0), Options)
    ->  Code0 = Code
    ;   Code >= 400
    ->  throw(error(existence_error(url, URL), context(http_open/3, Code)))
    ;   true
    ),
    reply_headers(Options, Reply),
    body_stream(Reply.body, Stream),
    (   option(size(Size), Options)
    ->  string_length(Reply.body, Size)
    ;   true
    ).

request_method(Options, Method) :-
    (   option(method(M), Options)
    ->  upcase_atom(M, MU), atom_string(MU, Method)
    ;   memberchk(post(_), Options)
    ->  Method = "POST"
    ;   Method = "GET"
    ).

%   The body, as a string, and the content type the option implies (`-` when
%   the caller is saying it themselves with a request_header).
request_body(Options, Body, Type) :-
    (   option(post(Data), Options)
    ->  post_body(Data, Body, Type)
    ;   Body = null, Type = (-)
    ).

post_body(json(Dict), Body, "application/json") :- !,
    with_output_to(string(Body), json_write_dict(current_output, Dict, [width(0)])).
post_body(string(Type0, Text), Body, Type) :- !,
    atom_string(Type0, Type), text_to_str(Text, Body).
post_body(string(Text), Body, "text/plain") :- !, text_to_str(Text, Body).
post_body(atom(Text), Body, "text/plain") :- !, text_to_str(Text, Body).
post_body(codes(Codes), Body, "text/plain") :- !, string_codes(Body, Codes).
post_body(Other, Body, "text/plain") :- text_to_str(Other, Body).

text_to_str(T, S) :- ( string(T) -> S = T ; atom_string(T, S) ).

%   request_header(Name=Value) may appear any number of times; the content
%   type of a post/1 is added unless the caller set one.
request_headers(Options, BodyType, Headers) :-
    findall([NameS, ValueS],
            ( member(request_header(Name=Value), Options),
              atom_string(Name, NameS), text_to_str(Value, ValueS) ),
            Given),
    (   BodyType == (-)
    ->  Headers = Given
    ;   ( member([N, _], Given), string_lower(N, "content-type") )
    ->  Headers = Given
    ;   Headers = [["Content-Type", BodyType]|Given]
    ).

%   header(Name, Value) options: bind each from the reply, '' when absent —
%   which is what http_open/3 does.
%   The reply's headers arrive from JSON, so their keys are atoms and they are
%   already lower-cased by the worker; the option's name has to be made to
%   match on both counts, or `header(content_type, CT)` quietly answers '' and
%   le_documents.pl decides a document is of no type at all.
reply_headers(Options, Reply) :-
    forall(member(header(Name, Value), Options),
           ( downcase_atom(Name, Key),
             ( get_dict(headers, Reply, HDict), get_dict(Key, HDict, V)
             -> atom_string(Value, V) ; Value = '' ) )).

body_stream(Body, Stream) :-
    new_memory_file(MF),
    setup_call_cleanup(open_memory_file(MF, write, Out, [encoding(utf8)]),
                       write(Out, Body),
                       close(Out)),
    open_memory_file(MF, read, Stream, [encoding(utf8), free_on_close(true)]).
