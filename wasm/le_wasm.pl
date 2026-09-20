/** <module> Logical English in the browser — the other transport

    LE2 answers one request: a JSON object with an `operation` field, in, a
    JSON object out. On a server that arrives over HTTP and classic_web_api.pl
    unwraps it. Here it arrives from the page above this Prolog, which is
    compiled to WebAssembly and running in a worker of that page, and this
    file unwraps it. In between, both call the same le_api.pl, which is why
    the two deployments cannot drift apart: an operation is implemented once.

    What the page gets for that:

      * no server. The program is compiled, the query is answered and the
        proof is built in the tab, out of a virtual file system holding the
        examples, the i18n dictionaries and the shared LE libraries the build
        shipped with (wasm/pack.pl). A static host — Vercel, GitHub Pages, an
        S3 bucket — is enough, and there is nothing to scale, because every
        visitor brings their own engine.
      * privacy of a kind the server build cannot offer: a document typed into
        this editor never leaves the machine.

    and what it costs:

      * one thread. A query runs to its limit: `interruptQuery` finds no
        query thread to signal and answers "No running query", which is the
        same answer the server gives when the query has already finished.
        There is no debugger either — the DAP server is a second thread
        talking a websocket to the editor;
      * no accounts, so nothing restricted: the build serves the examples it
        was built with, and le_api.pl's user is anonymous;
      * no sub-processes, so no Assistant (it runs `opencode`);
      * time limits measured in inferences rather than seconds
        (wasm/shims/time.pl);
      * no s(CASP): it is an optional pack and the payload does not carry one,
        so le_scasp:le_scasp_available/0 is false, exactly as on a server
        where the pack was never installed.

    Everything else — parsing, the reasoning, the explanations, the Proof
    Game, the views, the tests, import and export — is the same code the
    server runs.

    The entry points the worker calls are le_wasm_init/1 and le_wasm_call/2.
*/

:- module(le_wasm, [
    le_wasm_init/1,             % +ConfigDict
    le_wasm_call/2,             % +RequestJSONString, -ReplyJSONString
    le_wasm_fetch/2,            % +RequestDict, -ReplyDict
    le_wasm_host_call/2,        % +RequestDict, -ReplyDict
    le_wasm_version/1           % -Atom
    ]).

/*  The shims, before anything that needs them.

    A directive runs when it is read, so this one is in force by the time the
    use_module/1 below reads le_api.pl and, through it, every module of LE2.
    It is appended rather than prepended: a real library always wins, and the
    shims are only ever reached for the nine that are not in the image at all.
    See wasm/shims/README.md.  */
:- multifile user:file_search_path/2.
:- prolog_load_context(directory, WasmDir),
   atom_concat(WasmDir, '/shims', ShimDir),
   ( user:file_search_path(library, ShimDir) -> true
   ; assertz(user:file_search_path(library, ShimDir)) ),
   file_directory_name(WasmDir, RepoDir),
   ( user:file_search_path(le2, RepoDir) -> true
   ; assertz(user:file_search_path(le2, RepoDir)) ).

:- use_module(library(json)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(time)).        % the real one on a server, wasm/shims/time.pl here

/*  library(wasm) is how Prolog calls the page: `X := f(Y)`. It exists only in
    the WebAssembly image, and this file is also read by a plain swipl (the
    parity test of wasm/test/, and any check that it still compiles), so its
    absence has to be survivable. The operator is SWI's own and is declared
    either way, so the clauses below read; without the library they throw, and
    every caller here is inside a catch/3 that expects exactly that.  */
:- if(exists_source(library(wasm))).
:- use_module(library(wasm)).
:- endif.
:- use_module(le2(le_api)).
:- use_module(le2(le_kbs)).
:- use_module(le2(le_i18n)).

:- dynamic external_proxy/1.
:- dynamic wasm_build_info/1.

%!  le_wasm_version(-Info) is det.
le_wasm_version(Info) :-
    ( wasm_build_info(Info) -> true ; Info = 'unknown build' ).

		 /*******************************
		 *           STARTING           *
		 *******************************/

%!  le_wasm_init(+Config) is det.
%
%   Called once by the worker, after it has unpacked the payload into the
%   virtual file system. Config is a dict; every key is optional:
%
%     - `build`        what to answer `/build_info` with
%     - `proxy`        where to send a request this page may not make itself
%                      (wasm/api/proxy.js); without one, an outbound fetch
%                      fails the way a blocked cross-origin fetch fails
%     - `network`      `false` to refuse URL-valued resources outright
%     - `inferencesPerSecond`  what a second is worth here (wasm/shims/time.pl)
le_wasm_init(Config) :-
    ( get_dict(build, Config, B) -> retractall(wasm_build_info(_)), assertz(wasm_build_info(B)) ; true ),
    ( get_dict(proxy, Config, P), P \== null, P \== ""
    ->  retractall(external_proxy(_)), assertz(external_proxy(P)) ; true ),
    ( get_dict(network, Config, false)
    ->  le_kbs:set_le_network_allowed(false) ; true ),
    ( get_dict(inferencesPerSecond, Config, IPS), integer(IPS)
    ->  set_prolog_flag(le_wasm_inferences_per_second, IPS) ; true ),
    %  Nothing reports home from a page that has no server of its own.
    le_kbs:set_le_issue_reporting(false),
    le_i18n:set_le_language(default).

		 /*******************************
		 *         THE ONE CALL         *
		 *******************************/

%!  le_wasm_call(+RequestJSON:string, -ReplyJSON:string) is det.
%
%   One operation, in and out as JSON text. Text rather than a dict across the
%   bridge on purpose: the request comes from `JSON.stringify` in the page and
%   the reply goes back to `JSON.parse`, so the editor's own fetch hook can
%   hand the reply to code that cannot tell it from a server's.
%
%   It answers in every case. The three outcomes are the three
%   classic_web_api.pl has — the reply, "operation failed" when it fails or
%   throws, "unknown operation" when there is no such thing — because the
%   editor already knows what to do with each of them.
le_wasm_call(RequestJSON, ReplyJSON) :-
    (   catch(atom_json_dict(RequestJSON, Dict, []), Error, true)
    ->  (   var(Error)
        ->  call_operation(Dict, Reply)
        ;   message_to_text(Error, Msg), Reply = _{error: Msg}
        )
    ;   Reply = _{error: "the request was not JSON"}
    ),
    with_output_to(string(ReplyJSON), json_write_dict(current_output, Reply, [width(0)])).

call_operation(Dict, Reply) :-
    ( get_dict(operation, Dict, Op) -> true ; Op = none ),
    request_language(Dict),
    le_api:operation_time_limit(Dict, Limit),
    (   catch(call_with_time_limit(Limit, le_api:handle_operation(Dict, Reply0)),
              E, Caught = E)
    ->  (   var(Caught)
        ->  le_kbs:annotate_resource_ranges(Reply0, Reply)
        ;   operation_error(Op, Caught, Reply)
        )
    ;   operation_error(Op, failed, Reply)
    ).

%   The server's wording, deliberately: the editor matches on it, and a user
%   who has seen one deployment should recognise the other.
operation_error(Op, time_limit_exceeded, _{error: Msg, timedOut: true}) :- !,
    format(atom(Msg), "The operation '~w' ran out of time in this browser. \c
                       The WebAssembly build measures a time limit in inferences \c
                       rather than seconds; a long proof may need a larger budget.", [Op]).
operation_error(Op, Error, _{error: "Operation failed or internal error", detail: Detail}) :-
    message_to_text(Error, Msg),
    format(atom(Detail), "~w: ~w", [Op, Msg]),
    print_message(error, le_api_error(Op, Msg)).

%!  message_to_text(+Error, -Text) is det.
%
%   An exception as one line of English for the reply's `detail` field. The
%   printed form of the term is what a server's log would have shown, and
%   this build has no log: the page is the log.
message_to_text(failed, "the operation failed") :- !.
message_to_text(Error, Text) :-
    catch(error_text(Error, Text), _, term_string(Error, Text)).

error_text(error(existence_error(procedure, PI), _), Text) :- !,
    format(atom(A), "no such predicate: ~w (a part of LE2 that the \c
                     WebAssembly build does not carry?)", [PI]), atom_string(A, Text).
error_text(error(resource_error(no_host), _), Text) :- !,
    Text = "this build tried to reach the page it is running in, and there was none".
error_text(Error, Text) :- term_string(Error, Text).

%!  request_language(+Dict) is det.
%
%   The language of the *messages* for this one operation, from a `lang` field
%   the page puts there (boot.js lifts it out of the `?lang=` the editor adds
%   to its URL, which is where classic_web_api.pl's set_request_language/1
%   reads it). It is reset for every request, exactly as it is on the server,
%   where the worker threads are pooled and a language left behind would leak
%   into the next request. The program's own language still governs parsing.
request_language(Dict) :-
    (   get_dict(lang, Dict, Lang0), Lang0 \== "", Lang0 \== null,
        atom_string(Lang, Lang0),
        le_i18n:known_language(Lang)
    ->  le_i18n:set_le_language(Lang)
    ;   le_i18n:set_le_language(default)
    ).

		 /*******************************
		 *          THE OUTSIDE         *
		 *******************************/

%!  le_wasm_fetch(+Request, -Reply) is det.
%
%   The one way out of this Prolog, used by wasm/shims/http/http_open.pl.
%   Request is `_{url, method, headers, body, timeout}`; Reply is
%   `_{status, headers, body, error}`.
%
%   A request to another origin is sent to the configured proxy instead, as a
%   POST whose body is the request itself. Not for politeness: a browser will
%   not let this page reach `api.openai.com` at all, and a key that would make
%   the request worth sending has no business being in a page. What the proxy
%   does with it — which hosts it will forward to, which key it adds — is the
%   deployment's to decide (wasm/api/proxy.js).
le_wasm_fetch(Request, Reply) :-
    (   external(Request.url), external_proxy(Proxy)
    ->  with_output_to(string(Body), json_write_dict(current_output, Request, [width(0)])),
        Out = _{action: "fetch", url: Proxy, method: "POST",
                headers: [["Content-Type", "application/json"]],
                body: Body, timeout: Request.timeout}
    ;   Out = Request.put(action, "fetch")
    ),
    host_json(Out, Reply).

external(URL) :-
    ( sub_string(URL, 0, _, _, "http://") ; sub_string(URL, 0, _, _, "https://") ),
    \+ same_origin(URL).

%   The page's own origin, which the page itself answers for; without one (no
%   host, as under a plain swipl) nothing is same-origin and everything
%   external goes to the proxy, which is the safe way round.
same_origin(URL) :-
    catch(Origin := le_wasm_host_origin(), _, fail),
    string(Origin), Origin \== "",
    sub_string(URL, 0, _, _, Origin).

%!  le_wasm_host_call(+Request, -Reply) is det.
%
%   Anything else the page can do and this Prolog cannot: opening a tab, for
%   one (wasm/shims/www_browser.pl). Fails, rather than throwing, when there is
%   no host — a build running under a plain swipl for the tests, say.
le_wasm_host_call(Request, Reply) :-
    host_json(Request, Reply).

host_json(Request, Reply) :-
    with_output_to(string(JSON), json_write_dict(current_output, Request, [width(0)])),
    catch(ReplyJSON := le_wasm_host(JSON), E,
          throw(error(resource_error(no_host), context(le_wasm_host_call/2, E)))),
    atom_json_dict(ReplyJSON, Reply, []).
