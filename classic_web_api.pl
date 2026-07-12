/** <module> Logical English Classic Web API
    
    This module provides a REST API for Logical English. It supports
    loading KBs, running queries, and interacting with the LE Assistant.
    It also serves the web-based editor.
*/

:- module(classic_web_api, [start_api_server/0, start_api_server/1, port_in_use/1]).

:- use_module(library(socket)).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_client)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_files)).
:- use_module(library(http/http_host)).
:- use_module(library(http/html_write)).
:- use_module(library(http/http_session)).
:- use_module(library(assoc)).
:- use_module(le_kbs).
:- use_module(le_proof_game).
:- use_module(tokenizer).
:- use_module(le_grammar).
:- use_module(reasoner).
:- use_module(le_system_templates).
:- use_module(le_graph).
:- use_module(le_assistant).
:- use_module(le_contract_assistant).
:- use_module(dap_server).
:- use_module(llm/llm_client, [llm_list_models/1]).
:- use_module(nl_to_le, [english_to_le/8]).
:- use_module(llm/mcp, [handle_mcp/1, handle_rest_list_examples/1, handle_rest_query/1, handle_rest_verify/1, handle_rest_example_details/1]).
:- use_module(le_users).
:- use_module(restricted_paths).

:- dynamic build_info/1.

:- http_handler(root(leapi), handle_leapi, [method(post)]).
:- http_handler(root(build_info), handle_build_info, [method(get)]).
:- http_handler(root(.), handle_landing_page, []).
:- http_handler(root(login), handle_login, []).
:- http_handler(root(logout), handle_logout, []).
:- http_handler(root(whoami), handle_whoami, [method(get)]).
:- http_handler(root(mcp), handle_mcp, []).
:- http_handler(root(list_examples), handle_rest_list_examples, [method(get)]).
:- http_handler(root(query), handle_rest_query, [method(post)]).
:- http_handler(root(verify), handle_rest_verify, [method(post)]).
:- http_handler(root(example_details), handle_rest_example_details, [method(post)]).
:- http_handler(root('source/'), handle_source, [prefix]).
:- http_handler('/docs/', handle_docs, [prefix]).
:- http_handler('/executive', handle_executive, []).
:- http_handler('/dap', dap_websocket_handler, []).
:- http_handler('/editor/', http_reply_from_files('editor', []), [prefix]).
:- http_handler('/web_extras/', http_reply_from_files('web_extras', []), [prefix]).
:- http_handler('/editor', http_redirect(moved, '/editor/index.html'), []).

%!  start_api_server is det.
%!  start_api_server(+Port:integer) is det.
%
%   Starts the Logical English Web API server.
start_api_server :-
    start_api_server(3050).

start_api_server(Port) :-
    % assertz(le_kbs:do_log),
    % Fail loudly if the port is already taken. http_server/2 opens its socket
    % with SO_REUSEADDR, and on macOS/BSD that lets a second bind to a port
    % another process is already serving SUCCEED silently — our server would
    % look started while the other process keeps the connections. Probe with a
    % TCP connect first so we raise an error instead of starting a dead server.
    (   port_in_use(Port)
    ->  throw(error(le_server_error(port_in_use(Port)), start_api_server/1))
    ;   true
    ),
    load_build_info,
    % Reclaim reasoning-session modules abandoned by the editor (reload on edit,
    % tab close, ...) so they don't accumulate in memory over time.
    le_kbs:start_session_reaper,
    % A debug-trace session holds a worker for its websocket plus one for the
    % blocked traced query, so keep generous headroom on top of the bound in
    % dap_server:dap_command_timeout/1 to avoid starving normal requests.
    http_server(http_dispatch, [port(Port), workers(24)]).

%!  port_in_use(+Port:integer) is semidet.
%
%   True when something is already listening on Port (on the loopback
%   interface). A successful TCP connect means a server is there; a refused
%   connection (or any error) means the port is free for us to bind.
port_in_use(Port) :-
    catch(
        setup_call_cleanup(
            tcp_connect(localhost:Port, Stream, []),
            true,
            close(Stream)
        ),
        _,
        fail
    ).

load_build_info :-
    (   exists_file('build_info.txt')
    ->  read_file_to_string('build_info.txt', Info0, []),
        split_string(Info0, "\n", "\r", [Info|_]),
        retractall(build_info(_)),
        assertz(build_info(Info))
    ;   retractall(build_info(_)),
        assertz(build_info("unknown build"))
    ).

handle_build_info(_Request) :-
    build_info(Info),
    reply_json_dict(_{build_info: Info}).

:- multifile prolog:message//1.
prolog:message(le_api_error(Op, Msg)) -->
    [ 'LE API Operation failed: ~w - ~w' - [Op, Msg] ].
prolog:message(le_api_info(Msg)) -->
    [ 'LE API: ~w' - [Msg] ].
prolog:message(error(le_server_error(port_in_use(Port)), _)) -->
    [ 'Cannot start LE API server: port ~w is already in use.'-[Port], nl,
      'Another server is already listening there; stop it (or pick another port) first.'-[] ].

handle_leapi(Request) :-
    http_read_json_dict(Request, Dict),
    (   validate_token(Dict) ->  
            get_dict(operation, Dict, Op),
            print_message(informational, le_api_info(Op)),
            (   catch(handle_operation(Dict, Response), E, (print_message(error, E), fail)) ->  
                    print_message(informational, le_api_info(success(Op))),
                    reply_json_dict(Response)
                ; print_message(error, le_api_error(Op, "Operation failed")),
                  reply_json_dict(_{error: "Operation failed or internal error"}, [status(500)])
            )
        ; print_message(warning, le_api_info("Invalid token")),
          reply_json_dict(_{error: "Invalid token"}, [status(403)])
    ).

validate_token(Dict) :-
    get_dict(token, Dict, Token),
    Token == "myToken123".

handle_operation(Dict, Response) :-
    get_dict(operation, Dict, Op),
    (   Op == "examples" -> handle_examples(Dict, Response)
        ; Op == "list_examples" -> handle_list_examples(Dict, Response)
        ; Op == "answer" -> handle_answer(Dict, Response)
        ; Op == "explain" -> handle_explain(Dict, Response)
        ; Op == "load" -> 
            ( catch(handle_load(Dict, Response), E, (print_message(error, E), fail)) -> true; print_message(error, le_api_error(load, "handle_load failed")), fail)
        ; Op == "answeringQuery" -> handle_answering_query(Dict, Response)
        ; Op == "interruptQuery" -> handle_interrupt_query(Dict, Response)
        ; Op == "getGameData" ->
            ( catch(handle_get_game_data(Dict, Response), E_GGD,
                    ( print_message(error, le_api_error(getGameData, E_GGD)),
                      format(user_error, "getGameData failed. Dict: ~w~n", [Dict]),
                      term_string(E_GGD, EStr),
                      Response = _{error: EStr, gameDataError: true} ))
              -> true
            ; print_message(error, le_api_error(getGameData, "handle_get_game_data failed")),
              format(user_error, "getGameData failed (no exception). Dict: ~w~n", [Dict]),
              Response = _{error: "Could not build the Proof Game for this query (no rules/facts extracted, or the session was reclaimed). Please reload and try again.", gameDataError: true}
            )
        ; Op == "unifyGameNodes" -> handle_unify_game_nodes(Dict, Response)
        ; Op == "explanationDrill" -> handle_explanation_drill(Dict, Response)
        ; Op == "loadFactsAndQuery" -> handle_load_facts_and_query(Dict, Response)
        ; Op == "query" -> handle_query(Dict, Response)
        ; Op == "getProlog" -> handle_get_prolog(Dict, Response)
        ; Op == "assistant_command" -> 
            ( catch(handle_assistant_command(Dict, Response), E_Asst, (print_message(error, E_Asst), fail)) -> true ; 
              ( print_message(error, le_api_error(assistant_command, "handle_assistant_command failed")), 
                % Log the dict for debugging
                format(user_error, "Failed Dict: ~w~n", [Dict]),
                fail)
            )
        ; Op == "assistant_status" -> handle_assistant_status(Dict, Response)
        ; Op == "assistant_interrupt" -> handle_assistant_interrupt(Dict, Response)
        ; Op == "contract_start" -> handle_contract_start(Dict, Response)
        ; Op == "contract_status" -> handle_contract_status(Dict, Response)
        ; Op == "contract_result" -> handle_contract_result(Dict, Response)
        ; Op == "contract_interrupt" -> handle_contract_interrupt(Dict, Response)
        ; Op == "list_models" -> handle_list_models(Dict, Response)
        ; Op == "nl_to_le" -> handle_nl_to_le(Dict, Response)
        ; Op == "is_a_hierarchy" -> handle_is_a_hierarchy(Dict, Response)
        ; Op == "graph" -> handle_graph(Dict, Response)
        ; Response = _{error: "Unknown operation"}
    ).

handle_graph(Dict, Response) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
    le_kbs:note_session_use(SM),
    ( (current_module(SM), current_predicate(SM:le_kb_module_fact/1), SM:le_kb_module_fact(KB)) -> true; KB = none),
    ( KB \== none ->
        le_graph:kb_graph(KB, Response)
    ; Response = _{error: "No KB loaded"}
    ).

% --- Landing Page ---

handle_landing_page(Request) :-
    http_parameters(Request, [run_tests(RunTests, [boolean, optional(true), default(false)])]),
    (   http_in_session(_SessionId),
        http_session_data(user(Email, Roles))
    ->  UserEmail = Email, UserRoles = Roles
    ;   UserEmail = 'anonymous', UserRoles = []
    ),
    (   RunTests == true ->
        le_examples_dir(Dir), le_kbs:runTestsInDir(Dir, Results),
        format_test_results(Results, UserRoles, TestHtml)
    ;   TestHtml = []
    ),
    (   UserEmail == 'anonymous'
    ->  AuthLink = a(href('/login'), '[Login]')
    ;   AuthLink = a(href('/logout'), '[Logout]')
    ),
    le_examples_dir(Dir), landing_example_items(Dir, UserRoles, ExampleItems),
    build_info(BuildInfo),
    landing_folders_script(FolderScript),
    reply_html_page(
        [title('Logical English 2.0'),
         % Collapsible example folders: open/closed state per folder is remembered
         % in LocalStorage; ?expand=all opens everything (script embedded below).
         style('li.le-folder-item { list-style: none; } \c
                details.le-folder > summary { cursor: pointer; }'),
         script([type('text/javascript')], FolderScript)],
        [
            div([style('float: right; padding: 10px;')], [
                span(['Logged in as: ', b(UserEmail), ' ']),
                AuthLink
            ]),
            h1('Logical English 2.0'),
            p(small(['Build: ', BuildInfo])),
            ul([
                li([
                    b('Edit and Query: '),
                    a(href('/editor/index.html'), '[New Document]'),
                    ' ',
                    span([id('le-folder-controls'), style('display:none;')], [
                        '(',
                        a([href('#'), id('le-expand-all')], 'expand all'),
                        ' · ',
                        a([href('#'), id('le-collapse-all')], 'collapse all'),
                        ')'
                    ]),
                    ul(ExampleItems)
                ]),
                li([
                    b('Just run a program: '),
                    a(href('/executive'), '[Executive view]'),
                    br([]),
                    small('A minimalist, mobile-friendly way to pick a program, choose a scenario and question, and see the answer — no editing.')
                ]),
                li(a(href('https://github.com/mcalejo/LogicalEnglish2'), 'GitHub Repository'))
            ]),
            h2('Documentation'),
            ul([
                li([
                    a([href('/docs/tutorial0/IntroToLE2'), target('_blank')],
                      'A Gentle Introduction to Logical English 2'),
                    br([]),
                    small('Start here: a hands-on tutorial that builds three small programs — a tea party, a flying dragon, and a slice of British nationality law — teaching how to write, query and debug LE in the editor.')
                ]),
                li([
                    a([href('/docs/howToUse'), target('_blank')],
                      'How to use the LE2 web application'),
                    br([]),
                    small('The editor manual: opening and saving files, running queries, the scenario and query editors, scenario variations, and reading the explanation trees.')
                ]),
                li([
                    a([href('/docs/le_summary'), target('_blank')],
                      'Logical English syntax summary'),
                    br([]),
                    small('The language reference: every construct — templates, rules, operators, aggregates, variables and types, dates, ontology, extensions — for looking things up as you write.')
                ])
            ]),
            h2('Test Suite'),
            form([action('/'), method('get')], [
                input([type(hidden), name(run_tests), value(true)]),
                input([type(submit), value('Run All Tests')])
            ]),
            div(TestHtml)
        ]
    ).

%!  handle_whoami(+Request) is det.
%
%   Reports the current session's login state as JSON, so client-rendered
%   pages (e.g. the Executive view) can show the same "Logged in as … /
%   Login" affordance the server-rendered landing page has. The session
%   cookie is shared same-origin.
handle_whoami(_Request) :-
    (   http_in_session(_SessionId), http_session_data(user(Email, _Roles))
    ->  atom_string(Email, EmailStr),
        Response = _{loggedIn: true, email: EmailStr}
    ;   Response = _{loggedIn: false, email: null}
    ),
    reply_json_dict(Response).

% A safe post-login/logout redirect target: only a local path (leading '/',
% and not a protocol-relative '//...'), else the landing page. Prevents an
% open redirect via the 'return' parameter.
safe_return(Request, Target) :-
    (   catch(http_parameters(Request, [return(Ret, [default('')])]), _, Ret = ''),
        Ret \== '',
        sub_atom(Ret, 0, 1, _, '/'),
        \+ sub_atom(Ret, 0, 2, _, '//')
    ->  Target = Ret
    ;   Target = '/'
    ).

handle_login(Request) :-
    (   member(method(post), Request)
    ->  http_parameters(Request, [email(Email, []), password(Password, []), return(Ret, [default('/')])]),
        (   authenticate_le_user(Email, Password, Roles)
        ->  http_session_assert(user(Email, Roles)),
            ( sub_atom(Ret, 0, 1, _, '/'), \+ sub_atom(Ret, 0, 2, _, '//') -> Target = Ret ; Target = '/' ),
            http_redirect(moved, Target, Request)
        ;   reply_html_page(
                [title('Login Failed')],
                [h1('Login Failed'), p('Invalid email or password.'), a(href('/login'), 'Try again')]
            )
        )
    ;   safe_return(Request, Ret),
        reply_html_page(
            [title('Login')],
            [
                h1('Login'),
                form([action('/login'), method('post')], [
                    input([type(hidden), name(return), value(Ret)]),
                    p(['Email: ', input([type(text), name(email)])]),
                    p(['Password: ', input([type(password), name(password)])]),
                    p(input([type(submit), value('Login')]))
                ])
            ]
        )
    ).

handle_logout(Request) :-
    (   http_in_session(_)
    ->  http_session_retractall(user(_, _))
    ;   true
    ),
    safe_return(Request, Target),
    http_redirect(moved, Target, Request).

%!  landing_folders_script(-JS:atom) is det.
%
%   Client-side script (embedded inline in the landing page) that makes the
%   example <details class="le-folder"> elements remember their open/closed state
%   in LocalStorage, keyed by data-path, and supports ?expand=all plus the
%   expand-all / collapse-all controls. Kept here (not in web_extras/, which is for
%   additional apps) since it is part of a core feature. The script content of a
%   <script> element is emitted verbatim by html_write, so no escaping is needed;
%   it avoids "//" comments and any "</" sequence on purpose.
landing_folders_script('(function(){
  "use strict";
  var P = "le-folder:";
  function folders(){
    return Array.prototype.slice.call(document.querySelectorAll("details.le-folder[data-path]"));
  }
  function save(f){
    var p = f.getAttribute("data-path");
    if (!p) return;
    try { window.localStorage.setItem(P + p, f.open ? "1" : "0"); } catch (e) {}
  }
  function setAll(open){ folders().forEach(function(f){ f.open = open; save(f); }); }
  function wantAll(){
    var v = new URLSearchParams(window.location.search).get("expand");
    return v === "all" || v === "1" || v === "true" || v === "expanded";
  }
  function init(){
    var all = folders();
    var controls = document.getElementById("le-folder-controls");
    if (controls && all.length > 0) controls.style.display = "";
    var openAll = wantAll();
    all.forEach(function(f){
      if (openAll) {
        f.open = true;
      } else {
        var s = null;
        try { s = window.localStorage.getItem(P + f.getAttribute("data-path")); } catch (e) {}
        f.open = (s === "1");
      }
      f.addEventListener("toggle", function(){ save(f); });
    });
    if (openAll) all.forEach(save);
    var ex = document.getElementById("le-expand-all");
    if (ex) ex.addEventListener("click", function(e){ e.preventDefault(); setAll(true); });
    var co = document.getElementById("le-collapse-all");
    if (co) co.addEventListener("click", function(e){ e.preventDefault(); setAll(false); });
  }
  if (document.readyState === "loading") { document.addEventListener("DOMContentLoaded", init); }
  else { init(); }
})();').

%!  landing_example_items(+Dir:atom, +UserRoles:list, -Items:list) is det.
%
%   Builds HTML list items for all examples in Dir, grouping subdirectory
%   examples under an indented header. Subdirectories are recursed into to any
%   depth, so e.g. examples/.../insureLE2/testing/foo appears as
%   insureLE2/ > testing/ > foo.
landing_example_items(Dir, UserRoles, Items) :-
    landing_example_items(Dir, '', UserRoles, Items).

landing_example_items(Dir, Prefix, UserRoles, Items) :-
    directory_files(Dir, Files),
    % Examples directly in this directory.
    findall(Base, (
        member(F, Files),
        sub_atom(F, _, _, 0, '.le'),
        \+ sub_atom(F, _, _, 0, '.le.tests'),
        file_name_extension(Base, le, F),
        atomic_list_concat([Dir, '/', F], ExPath),
        is_path_allowed(ExPath, UserRoles)
    ), Bases0),
    sort(Bases0, Bases),
    findall(li(a([href(Url)], Base)), (
        member(Base, Bases),
        atomic_list_concat([Prefix, Base], ExampleName),
        format(atom(Url), '/editor/index.html?example=~w', [ExampleName])
    ), DirectItems),
    % Subdirectories, recursed into. Each is a collapsible <details> keyed by its
    % full path (data-path), so landing.js can remember its open/closed state in
    % LocalStorage and an ?expand=all query can open them all.
    findall(SubDir-li([class('le-folder-item')],
                      details(['data-path'(SubPrefix), class('le-folder')],
                              [summary(b([SubDir, '/'])), ul(SubItems)])), (
        member(SubDir, Files),
        \+ sub_atom(SubDir, 0, 1, _, '.'),
        directory_file_path(Dir, SubDir, SubDirPath),
        exists_directory(SubDirPath),
        is_path_allowed(SubDirPath, UserRoles),
        atomic_list_concat([Prefix, SubDir, '/'], SubPrefix),
        landing_example_items(SubDirPath, SubPrefix, UserRoles, SubItems),
        SubItems \= []
    ), SubDirPairs),
    keysort(SubDirPairs, SubDirSorted),
    pairs_values(SubDirSorted, SubDirItems),
    append(DirectItems, SubDirItems, Items).

format_test_results(Results, UserRoles, [h3('Test Results'), table([border(1), cellpadding(5)], [
    tr([th('File'), th('Pass'), th('Fail'), th('Error'), th('Status')])
    | TableRows
])]) :-
    maplist(result_to_row(UserRoles), Results, TableRows).

result_to_row(UserRoles, test_file(File, FileResults), tr([
    td(DisplayFile),
    td(PassCount),
    td(FailCount),
    td(ErrCount),
    td(style(Color), Status)
])) :-
    (   is_path_allowed(File, UserRoles)
    ->  DisplayFile = File
    ;   DisplayFile = '*** RESTRICTED ***'
    ),
    findall(1, member(pass(_,_), FileResults), Passes),
    findall(1, member(fail(_,_,_,_), FileResults), Fails),
    findall(1, member(error(_,_,_), FileResults), Errs),
    length(Passes, PassCount),
    length(Fails, FailCount),
    length(Errs, ErrCount),
    ( (FailCount > 0 ; ErrCount > 0) -> 
        Status = 'FAIL', Color = 'color: red; font-weight: bold;'
    ; (PassCount == 0, FailCount == 0, ErrCount == 0) ->
        Status = 'NONE', Color = 'color: orange; font-weight: bold;'
    ; Status = 'PASS', Color = 'color: green; font-weight: bold;'
    ).

% --- Handlers ---

handle_examples(Dict, Response) :-
    get_dict(file, Dict, FileName),
    le_examples_dir(Dir),
    atomic_list_concat([Dir, '/', FileName], Path0),
    (   http_in_session(_SessionId), http_session_data(user(_, Roles)) -> UserRoles = Roles ; UserRoles = [] ),
    (   is_path_allowed(Path0, UserRoles)
    ->  ( exists_file(Path0) -> Path = Path0; atom_concat(Path0, '.le', PathLE), exists_file(PathLE) -> Path = PathLE; Path = Path0),
        ( exists_file(Path) -> read_file_to_string(Path, Doc, []), Response = _{document: Doc}; Response = _{answer: "File not found", details: Path, document: ""})
    ;   Response = _{error: "Access denied"}
    ).

handle_list_examples(_Dict, Response) :-
    le_examples_dir(Dir),
    atomic_list_concat([Dir, '/'], DirSlash),
    (   http_in_session(_SessionId), http_session_data(user(_, Roles)) -> UserRoles = Roles ; UserRoles = [] ),
    list_examples_in_dir(DirSlash, '', UserRoles, Examples),
    Response = _{examples: Examples}.

%!  list_examples_in_dir(+Dir:atom, +Prefix:atom, +UserRoles:list, -Examples:list) is det.
%
%   Collects example base names (with Prefix prepended) from Dir and its subdirectories.
%   Subdirectory examples are returned as "subdir/name".
list_examples_in_dir(Dir, Prefix, UserRoles, Examples) :-
    directory_files(Dir, Files),
    findall(ExPath, (
        member(F, Files),
        sub_atom(F, _, _, 0, '.le'),
        \+ sub_atom(F, _, _, 0, '.le.tests'),
        file_name_extension(Base, le, F),
        atomic_list_concat([Dir, F], FullPath),
        is_path_allowed(FullPath, UserRoles),
        atom_concat(Prefix, Base, ExPath)
    ), DirectExamples),
    findall(SubExamples, (
        member(F, Files),
        \+ sub_atom(F, 0, 1, _, '.'),
        directory_file_path(Dir, F, SubDir),
        exists_directory(SubDir),
        is_path_allowed(SubDir, UserRoles),
        atomic_list_concat([Prefix, F, '/'], SubPrefix),
        atomic_list_concat([SubDir, '/'], SubDirSlash),
        list_examples_in_dir(SubDirSlash, SubPrefix, UserRoles, SubExamples)
    ), SubExamplesLists),
    append(SubExamplesLists, SubExamplesFlat),
    append(DirectExamples, SubExamplesFlat, Examples).

handle_list_models(_Dict, Response) :-
    llm_list_models(Rows),
    maplist(row_to_dict, Rows, Models),
    findall(P, (member(P, [openai, groq, anthropic, together, gemini]), catch(llm_client:api_key(P, _), _, fail)), ServerKeys),
    Response = _{models: Models, server_keys: ServerKeys}.

%!  handle_nl_to_le(+Dict, -Response) is det.
%
%   The "Write it in English…" endpoint: a one-shot, synchronous LLM conversion of
%   an English sentence into Logical English facts (kind "facts") or a query body
%   (kind "query"), respecting the program's templates. The heavy lifting is the
%   documented predicate nl_to_le:english_to_le/8, which also VERIFIES the fragment
%   against the program and reports any NEW issues it introduces (baseline-diffed).
%   This handler only unpacks the request, resolves the API key (client-supplied
%   api_keys first, then the provider env var) and shapes the JSON. Request fields:
%   sentence, kind, templates (list of label strings), content (the program source,
%   for verification), model, api_keys. Response: {result:"ok", le:"<LE text>",
%   warnings:[<message>...]} (warnings empty when it verified clean) or
%   {result:"error", error:"<message>"}.
handle_nl_to_le(Dict, Response) :-
    ( get_dict(sentence, Dict, Sentence) -> true ; Sentence = "" ),
    ( get_dict(kind, Dict, "query") -> Kind = query ; Kind = facts ),
    ( get_dict(templates, Dict, Templates) -> true ; Templates = [] ),
    ( get_dict(content, Dict, Program) -> true ; Program = "" ),
    ( get_dict(model, Dict, Model), Model \== "", Model \== null -> true ; Model = "openai/gpt-oss-120b" ),
    ( get_dict(api_keys, Dict, Keys) -> true ; Keys = _{} ),
    nl_le_api_key(Model, Keys, Key),
    ( Key == "" -> Options = [] ; Options = [api_key(Key)] ),
    % Recover with `true` (not `fail`) so a thrown error leaves Err bound and the
    % catch still succeeds; then distinguish success (Err unbound) from an error.
    (   catch(english_to_le(Kind, Sentence, Templates, Program, Model, Options, LEText, NewIssues), Err, true)
    ->  (   nonvar(Err)
        ->  message_to_string(Err, EMsg), Response = _{result: "error", error: EMsg}
        ;   maplist(nl_issue_message, NewIssues, Warnings),
            Response = _{result: "ok", le: LEText, warnings: Warnings}
        )
    ;   Response = _{result: "error", error: "LLM request failed"}
    ).

% nl_issue_message(+Issue, -Msg): a "[severity] message" string for a verification
% issue, for the client's warning list.
nl_issue_message(Issue, Msg) :-
    ( get_dict(severity, Issue, Sev) -> true ; Sev = "warning" ),
    ( get_dict(message, Issue, M) -> true ; M = "issue" ),
    format(string(Msg), "[~w] ~w", [Sev, M]).

% nl_le_api_key(+Model, +Keys, -Key): the API key for Model — a client-supplied key
% for the model's provider if present, else the provider's env var (via llm_client),
% else "" (english_to_le then falls back to the provider env var itself).
nl_le_api_key(Model, Keys, Key) :-
    ( llm_client:llm_model(Model, Provider0, _) -> true ; Provider0 = openai ),
    ( Provider0 == gemini -> KeyProv = google ; KeyProv = Provider0 ),
    (   get_dict(KeyProv, Keys, K), K \== null, K \== ""
    ->  Key = K
    ;   catch(llm_client:api_key(Provider0, Key), _, Key = "")
    ).

handle_is_a_hierarchy(Dict, Response) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
    le_kbs:note_session_use(SM),
    ( SM:le_kb_module_fact(KB) -> true; KB = none),
    ( KB \== none ->
        is_a_hierarchy(KB, Hierarchy),
        Response = _{hierarchy: Hierarchy}
    ; Response = _{error: "No KB loaded"}
    ).

row_to_dict(row(Short, Provider, APIModel), _{short: Short, provider: Provider, api_model: APIModel}).

handle_answer(Dict, Response) :-
    get_dict(document, Dict, Doc),
    get_dict(theQuery, Dict, Query),
    get_dict(scenario, Dict, Scenario),
    ( get_dict(hideRepeated, Dict, false) -> set_show_repeated_explanations(true) ; set_show_repeated_explanations(false) ),
    load_le_text(Doc, KB),
    setup_call_cleanup(
        createSession(KB, SM),
        (   setScenarion(SM, Scenario) ->
            ( query(SM, Query, _Instance, _Unknowns, Why) -> convert_why_deduped(Why, KB, JSONWhy), Response = _{answer: JSONWhy}; Response = _{answer: "No answer found"})
            ;   Response = _{error: "Scenario not found"}
        ),
        destroySession(SM)
    ).

handle_explain(Dict, Response) :-
    get_dict(document, Dict, Doc),
    get_dict(theQuery, Dict, Query),
    get_dict(scenario, Dict, Scenario),
    ( get_dict(hideRepeated, Dict, false) -> set_show_repeated_explanations(true) ; set_show_repeated_explanations(false) ),
    load_le_text(Doc, KB),
    setup_call_cleanup(
        createSession(KB, SM),
        ( setScenarion(SM, Scenario) ->
            % Keep one explanation per distinct answer (answer string + unknowns),
            % so repeated proofs of the same answer aren't listed multiple times.
            findall((AnswerStr-UnknownsKey)-JSONWhy, (
                    query(SM, Query, Instance, Us, Why),
                    canonical_string(Instance, AnswerStr),
                    convert_why_deduped(Why, KB, JSONWhy),
                    ( copy_term(Us, UsC, _), numbervars(UsC, 0, _), term_to_atom(UsC, UnknownsKey) -> true ; UnknownsKey = '?' )
                ), Keyed),
            dedup_keep_first(Keyed, Results),
            Response = _{results: Results}
        ; Response = _{error: "Scenario not found"} ),
        destroySession(SM)
    ).

% The include base for editor text: the directory of the example it came from
% (field 'source', a name relative to the examples dir, possibly with a
% subpath), so relative include resources resolve against the example's own
% location. Absent/unknown source keeps the default (cwd) base.
load_base_of(Dict, Base) :-
    (   get_dict(base, Dict, B), B \== "", B \== null,
        atom_string(BA, B),
        ( sub_atom(BA, 0, _, _, 'http://') ; sub_atom(BA, 0, _, _, 'https://') )
    ->  Base = BA                       % document fetched from a URL: its base URL
    ;   get_dict(source, Dict, Src), Src \== "", Src \== null,
        atom_string(SrcA, Src),
        le_examples_dir(Dir),
        atomic_list_concat([Dir, '/', SrcA], Full),
        file_directory_name(Full, BaseDir),
        exists_directory(BaseDir)
    ->  Base = BaseDir
    ;   Base = (-)
    ).

handle_load(Dict, Response) :-
    (   get_dict(le, Dict, Doc) ->  
        load_base_of(Dict, Base),
        ( catch(le_kbs:load_text(Doc, Base, KB), E1, (print_message(error, E1), fail)) -> Language = le; print_message(error, le_api_error(load, "le_kbs:load_text failed")), fail)
        ;   
        get_dict(file, Dict, File),
        le_examples_dir(Dir),
        atomic_list_concat([Dir, '/', File], Path0),
        (   http_in_session(_SessionId), http_session_data(user(_, Roles)) -> UserRoles = Roles ; UserRoles = [] ),
        (   is_path_allowed(Path0, UserRoles)
        ->  ( exists_file(Path0) -> Path = Path0; atom_concat(Path0, '.le', PathLE), exists_file(PathLE) -> Path = PathLE; Path = Path0),
            (   sub_atom(Path, _, _, 0, '.le') ->  
                    ( catch(le_kbs:load(Path, KB), E2, (print_message(error, E2), fail)) -> Language = le; print_message(error, le_api_error(load, "le_kbs:load failed")), fail)
                ; ( catch(load_prolog_file(Path, KB), E3, (print_message(error, E3), fail)) -> Language = prolog; print_message(error, le_api_error(load, "load_prolog_file failed")), fail)
            )
        ;   print_message(error, le_api_error(load, "Access denied")), fail
        )
    ),
    ( catch(createSession(KB, SM), E4, (print_message(error, E4), fail)) -> true; print_message(error, le_api_error(load, "createSession failed")), fail),
    (   catch(get_kb_metadata(KB, Metadata), E5, (print_message(error, E5), fail)) ->  
        findall(_{severity: Sev, type: Type, message: Msg, fix: Fix, start: Start, end: End}, KB:le_issue(Sev, Type, Msg, Fix, Start, End), Issues),
        Response = Metadata.put(_{
            sessionModule: SM,
            language: Language,
            target: prolog,
            issues: Issues
        }),
        print_message(informational, le_api_info(loaded(KB, SM)))
        ;   
        print_message(error, le_api_error(load, "get_kb_metadata failed")),
        fail
    ).

%!  valid_session(+SM:atom) is semidet.
%
%   True if SM is still a live reasoning session (it may have been reclaimed by
%   the idle-session reaper after a long period of inactivity).
valid_session(SM) :-
    atom(SM),
    current_module(SM),
    current_predicate(SM:le_kb_module_fact/1),
    SM:le_kb_module_fact(_).

% If the session has been reclaimed, tell the client so it can transparently
% reload and retry, rather than returning a confusing empty/error result.
handle_answering_query(Dict, _{error: "Session expired", session_expired: true}) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
    \+ valid_session(SM), !.
handle_answering_query(Dict, Response) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
    le_kbs:note_session_use(SM),
    ( SM:le_kb_module_fact(KB) -> true; KB = none),
    
    % Handle Scenario
    (   get_dict(customScenario, Dict, CustomScenario), CustomScenario \== null ->
            clearSession(SM),
            ( KB \== none -> 
                catch(parse_custom_facts(KB, CustomScenario, Facts), error(le_parse_error(Msg), _), ErrorFacts = Msg),
                ( var(ErrorFacts) -> forall(member(F, Facts), addSessionFact(SM, F)) ; true )
            ; true )
        ; get_dict(scenario, Dict, ScenarioStr) ->  
            (   ((atom(ScenarioStr) ; string(ScenarioStr)), \+ sub_atom(ScenarioStr, _, _, _, '(')) ->  
                    atom_string(ScenarioName, ScenarioStr),
                    ( ScenarioName \== '' -> print_message(informational, 'Setting scenario by name: ~w' - [ScenarioName]), clearSession(SM), setScenarion(SM, ScenarioName); clearSession(SM))
                ; term_string(Scenario, ScenarioStr),
                  clearSession(SM),
                  ( is_list(Scenario) -> forall(member(F, Scenario), addSessionFact(SM, F)); addSessionFact(SM, Scenario) )
            )
        ; true
    ),

    (   get_dict(debug, Dict, true) -> assertz(SM:debug_mode); true),

    % Detailed (per-rule) failure explanations: off unless requested. Set/cleared
    % per query so it tracks the client's current preference.
    dynamic(SM:detailed_failures/0),
    retractall(SM:detailed_failures),
    (   get_dict(detailedFailures, Dict, true) -> assertz(SM:detailed_failures); true),

    % Repeated sub-explanations are collapsed by default; the client can ask to
    % see them in full (hideRepeated:false). Set per query on this worker thread.
    ( get_dict(hideRepeated, Dict, false) -> set_show_repeated_explanations(true) ; set_show_repeated_explanations(false) ),

    (   nonvar(ErrorFacts) -> Response = _{error: ErrorFacts}
    ;   % Handle Query
        (   get_dict(customQuery, Dict, CustomQuery), CustomQuery \== null ->
                ( KB \== none ->
                    catch(parse_custom_query(KB, CustomQuery, Goal), error(le_parse_error(Msg), _), ErrorQuery = Msg),
                    ( var(ErrorQuery) -> Query = Goal ; true )
                ; Query = CustomQuery )
            ; get_dict(query, Dict, Query)
        ),
        (   nonvar(ErrorQuery) -> Response = _{error: ErrorQuery}
        ;   catch(run_interruptible_query(SM, Query, KB, Response), error(le_parse_error(Msg), _), Response = _{error: Msg})
        )
    ).

% A long-running query (e.g. a failure with a big negative explanation) can be
% interrupted by the user via a separate 'interruptQuery' request, which signals
% this worker thread. We register the thread for the session for the duration of
% the query, and turn the injected exception into an 'interrupted' response.
:- dynamic query_thread/2.   % query_thread(SessionModule, ThreadId)

run_interruptible_query(SM, Query, KB, Response) :-
    setup_call_cleanup(
        register_query_thread(SM),
        catch(
            run_answering_query(SM, Query, KB, Response),
            query_interrupted,
            Response = _{result: "interrupted", interrupted: true}
        ),
        unregister_query_thread(SM)
    ).

register_query_thread(SM) :-
    thread_self(Tid),
    retractall(query_thread(SM, _)),
    assertz(query_thread(SM, Tid)).

unregister_query_thread(SM) :-
    retractall(query_thread(SM, _)).

handle_interrupt_query(Dict, Response) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
    (   query_thread(SM, Tid)
    ->  catch(thread_signal(Tid, throw(query_interrupted)), _, true),
        Response = _{result: ok, interrupted: true}
    ;   Response = _{result: ok, interrupted: false, message: "No running query"}
    ).

run_answering_query(SM, Query, KB, Response) :-
    print_message(informational, 'Answering query: ~w in session ~w' - [Query, SM]),
    % A query can have several proofs of the SAME answer (e.g. an 'or' whose
    % branches both hold). Collect them keyed by (answer string + unknowns) and
    % keep only the first of each, so the same answer is not listed repeatedly.
    findall((AnswerStr-UnknownsKey)-_{answer: AnswerStr, unknowns: JSONUnknowns, why: JSONWhy, strongestReason: Reason, strongestReasonPath: ReasonPath}, (
            query(SM, Query, Instance, Us, Why),
            canonical_string(Instance, AnswerStr),
            convert_why_deduped(Why, KB, JSONWhy),
            strongest_reason(JSONWhy, KB, Reason, ReasonPath),
            convert_unknowns_to_le(KB, Us, JSONUnknowns),
            ( copy_term(Us, UsC, _), numbervars(UsC, 0, _), term_to_atom(UsC, UnknownsKey) -> true ; UnknownsKey = '?' ),
            print_message(informational, 'Found answer: ~w' - [AnswerStr])
        ), KeyedResults),
    dedup_keep_first(KeyedResults, Results),
    (   Results \== [] ->  
        length(Results, Count),
        print_message(informational, 'Total answers found: ~w' - [Count]),
        Response = _{results: Results, result: "ok"}
        ;   
        % No answers, get negative explanation
        print_message(informational, 'No answers found, generating negative explanation'),
        (   query_explain(SM, Query, _Instance, _Unknowns, Why) ->
                convert_why_deduped(Why, KB, JSONWhy),
                strongest_reason(JSONWhy, KB, Reason, ReasonPath),
                Response = _{results: [], why: JSONWhy, strongestReason: Reason, strongestReasonPath: ReasonPath, result: "ok"}
            ;   Response = _{results: [], error: "Explanation failed", result: "ok"}
        )
    ).

%!  strongest_reason(+JSONWhy, +KB, -Reason:string) is det.
%
%   A terse "strongest reason" summarising an explanation: the literal of the node
%   whose subtree weight — its descendant-node count (1 + sum of children weights) —
%   is closest to half the whole tree's weight W. On a tie the larger subtree wins.
%   Reason is "" when there is no explanation. JSONWhy is exactly what was sent to
%   the client (already collapsed when the user hides repeated sub-explanations), so
%   the summary matches what is displayed.
%
%   A node proven by a rule carries intrinsic weight (and is itself a candidate) ONLY
%   when the rule has an explicit name; a node from an auto-named rule is
%   "transparent" — it contributes no weight of its own and cannot be the strongest
%   reason — so anonymous derivation steps do not dominate the summary.
%   Path is the winning node's tree path ("1.2.3", 1-based) — computed exactly like
%   the client renders the tree — so the client can reveal and highlight that node.
strongest_reason(JSONWhy, KB, Reason, Path) :-
    ( is_list(JSONWhy) -> Roots = JSONWhy ; Roots = [JSONWhy] ),
    reason_roots(KB, Roots, 1, [], 0, W, [], Candidates),
    (   Candidates == [] -> Reason = "", Path = ""
    ;   maplist(reason_score(W), Candidates, Scored),
        sort(0, @=<, Scored, [_-(Best-Path)|_]),
        ( string(Best) -> Reason = Best ; term_string(Best, Reason) )
    ).

% reason_roots(+KB, +Roots, +Index, +Understood, +W0, -W, +Cand0, -Cand): process each
% root, giving it its 1-based path, and summing subtree weights into the total W.
% Nodes whose path is in Understood (and their subtrees) are treated as removed.
reason_roots(_, [], _, _, W, W, C, C).
reason_roots(KB, [R|Rs], I, Und, W0, W, C0, C) :-
    number_string(I, IS),
    reason_collect(KB, R, IS, Und, WR, C0, C1),
    W1 is W0 + WR,
    I1 is I + 1,
    reason_roots(KB, Rs, I1, Und, W1, W, C1, C).

% reason_collect(+KB, +Node, +Path, +Understood, -SubtreeWeight, +Cand0, -Cand): the
% subtree's weight, accumulating a Weight-(Text-Path) candidate for Node and every
% descendant. A transparent (failed clause-attempt) node adds no intrinsic weight and no
% candidate; an Understood node's subtree is skipped entirely (weight 0, no candidates).
reason_collect(KB, Node, Path, Und, W, Cand0, Cand) :-
    (   memberchk(Path, Und) ->
            W = 0, Cand = Cand0
    ;   is_dict(Node) ->
            ( get_dict(children, Node, Children), is_list(Children) -> true ; Children = [] ),
            reason_children(KB, Children, Path, 1, Und, 0, SumC, Cand0, Cand1),
            (   transparent_rule_node(KB, Node, Children) ->
                    W = SumC, Cand = Cand1
            ;   W is SumC + 1,
                node_reason_text(Node, Text),
                Cand = [W-(Text-Path)|Cand1]
            )
    ;   W = 1, Cand = [1-(""-Path)|Cand0]
    ).

% node_reason_text(+Node, -Text): the node's literal, negated when the node is a
% failure, so a chosen failed condition reads naturally as a reason. Negating toggles
% the LE negation phrase: a plain "X" gains "it is not the case that "; a NAF literal
% "it is not the case that X" drops it back to "X" (rather than double-prefixing).
node_reason_text(Node, Text) :-
    ( get_dict(literal, Node, Lit) -> true ; Lit = "" ),
    ( get_dict(type, Node, "failure") -> negate_literal(Lit, Text) ; Text = Lit ).

% negate_literal(+Lit, -Negated): the LE negation of a literal, reusing the single
% negation phrase (le_kbs:negation_words/1).
negate_literal(Lit, Negated) :-
    negation_words(Ws),
    atomic_list_concat(Ws, ' ', Phrase),
    string_concat(Phrase, " ", PrefixS),            % "it is not the case that "
    atom_string(Lit, LitS),
    (   string_concat(PrefixS, Rest, LitS)          % already NAF -> strip the prefix
    ->  Negated = Rest
    ;   string_concat(PrefixS, LitS, Negated)       % plain -> add the prefix
    ).
% reason_children(+KB, +Children, +ParentPath, +Index, +Understood, +Sum0, -Sum, +Cand0, -Cand):
% each child gets path "ParentPath.Index" (1-based), matching the client's rendering.
reason_children(_, [], _, _, _, S, S, C, C).
reason_children(KB, [Ch|Chs], PP, I, Und, S0, S, C0, C) :-
    format(string(ChildPath), "~w.~w", [PP, I]),
    reason_collect(KB, Ch, ChildPath, Und, WC, C0, C1),
    S1 is S0 + WC,
    I1 is I + 1,
    reason_children(KB, Chs, PP, I1, Und, S1, S, C1, C).

% transparent_rule_node(+KB, +Node, +Children): a "failed clause attempt" node — the
% extra structural node under a failed goal, one per clause whose head matched (marked
% `ruleAttempt` in convert_why/3). These are pass-throughs for the important-reason
% heuristic: no intrinsic weight and never chosen themselves.
transparent_rule_node(_KB, Node, _Children) :-
    get_dict(ruleAttempt, Node, true).

% Integer sort key: minimise |2*NodeWeight - TotalWeight| (i.e. |NodeWeight - W/2|),
% then prefer the larger subtree (NegW ascending = Weight descending). NegW must be
% the *evaluated* integer -W, not the term -(W), for numeric ordering.
reason_score(Wtotal, W-Value, (D - NegW) - Value) :-
    D is abs(2 * W - Wtotal),
    NegW is -W.

% ==== Explanation Drill ===================================================
% The "suspects tree" drill: repeatedly find the strongest reason S within the current
% TOP subtree (ignoring UNDERSTOOD subtrees), ask "Understood?", and either mark S
% understood (Yes) or descend into it (Not yet). TOP is a tree path; "" means the whole
% forest.

% strongest_within(+Why, +KB, +TopPath, +Understood, -SPath, -SText, -TopWeight)
% The strongest reason within the TopPath subtree, ignoring Understood subtrees.
% TopWeight is that subtree's (Understood-reduced) weight. Fails if there is no
% candidate (everything understood).
strongest_within(Why, KB, "", Und, SPath, SText, SWeight, W) :- !,
    ( is_list(Why) -> Roots = Why ; Roots = [Why] ),
    reason_roots(KB, Roots, 1, Und, 0, W, [], Candidates0),
    % The tree root(s) — the goal(s) being explained — are never offered as a question
    % (that is what the drill is explaining); only their descendants are candidates.
    exclude(candidate_is_root, Candidates0, Candidates),
    best_reason_candidate(Candidates, W, SPath, SText, SWeight).
strongest_within(Why, KB, TopPath, Und, SPath, SText, SWeight, W) :-
    node_at_path(Why, TopPath, TopNode),
    reason_collect(KB, TopNode, TopPath, Und, W, [], Candidates0),
    % The TOP node already has an implicit "Not yet" (we drilled into it), so it is not
    % offered again — only its descendants are candidates. W still spans the whole region.
    exclude(candidate_at_path(TopPath), Candidates0, Candidates),
    best_reason_candidate(Candidates, W, SPath, SText, SWeight).

candidate_at_path(Path, _-(_-P)) :- P == Path.
% A top-level root path has no "." (e.g. "1", "2"), unlike a descendant ("1.2").
candidate_is_root(_-(_-P)) :- \+ sub_string(P, _, _, _, ".").

best_reason_candidate(Candidates, W, SPath, SText, SWeight) :-
    Candidates \== [],
    maplist(reason_score(W), Candidates, Scored),
    sort(0, @=<, Scored, [_-(Best-SPath)|_]),
    ( string(Best) -> SText = Best ; term_string(Best, SText) ),
    once(member(SWeight-(_-SPath), Candidates)).

% drill_next(+Why, +KB, +Top, +Und, -SPath, -SText): the next question node — the
% strongest reason S within Top, but only when S is a PROPER sub-region (its weight is
% less than the whole region's), so the drill can actually descend. Fails at the
% terminal step (S is the whole remaining region, or nothing is left).
drill_next(Why, KB, Top, Und, SPath, SText) :-
    strongest_within(Why, KB, Top, Und, SPath, SText, SWeight, W),
    SWeight < W.

% subtree_weight(+KB, +Why, +Path, +Understood, -W): the (Understood-reduced) weight of
% the subtree at Path ("" = whole forest).
subtree_weight(KB, Why, "", Und, W) :- !,
    ( is_list(Why) -> Roots = Why ; Roots = [Why] ),
    reason_roots(KB, Roots, 1, Und, 0, W, [], _).
subtree_weight(KB, Why, Path, Und, W) :-
    node_at_path(Why, Path, Node),
    reason_collect(KB, Node, Path, Und, W, [], _).

% node_at_path(+Why, +Path, -Node): the JSON node at tree path "1.2.3".
node_at_path(Why, Path, Node) :-
    split_string(Path, ".", "", Parts),
    maplist(number_string, [I0|Is], Parts),
    ( is_list(Why) -> Roots = Why ; Roots = [Why] ),
    nth1(I0, Roots, Root),
    node_at_path_(Is, Root, Node).
node_at_path_([], Node, Node).
node_at_path_([I|Is], Node, Out) :-
    get_dict(children, Node, Children),
    nth1(I, Children, Child),
    node_at_path_(Is, Child, Out).

node_range(Node, S, E) :- ( get_dict(start, Node, S), get_dict(end, Node, E) -> true ; S = -1, E = -1 ).

% question_dict(+Why, +Path, +Text, +Answer, -Q): a question card for the client.
question_dict(Why, Path, Text, Answer, _{path: Path, text: Text, start: S, end: E, answer: Answer}) :-
    node_at_path(Why, Path, Node), node_range(Node, S, E).

% drill_loop(+KB, +Why, +Answers, +Top, +Und, +QAcc, -Questions, -TopF, -UndF, -Pending)
% Replays the answers from Top/Und, accumulating question cards and finally computing
% the pending (next unanswered) question, or null when the drill is complete.
drill_loop(KB, Why, [], Top, Und, QAcc, Questions, Top, Und, Pending) :- !,
    reverse(QAcc, Questions),
    (   drill_next(Why, KB, Top, Und, SPath, SText)
    ->  node_at_path(Why, SPath, SNode), node_range(SNode, St, En),
        Pending = _{path: SPath, text: SText, start: St, end: En}
    ;   Pending = null
    ).
drill_loop(KB, Why, [A|As], Top, Und, QAcc, Questions, TopF, UndF, Pending) :-
    (   drill_next(Why, KB, Top, Und, SPath, SText)
    ->  question_dict(Why, SPath, SText, A, Q),
        ( A == "yes"     -> Top1 = Top,   Und1 = [SPath|Und]
        ; A == "not_yet" -> Top1 = SPath, Und1 = Und
        ;                   Top1 = Top,   Und1 = Und ),
        drill_loop(KB, Why, As, Top1, Und1, [Q|QAcc], Questions, TopF, UndF, Pending)
    ;   % A terminal step was reached but stale answers remain — ignore them.
        reverse(QAcc, Questions), TopF = Top, UndF = Und, Pending = null
    ).

% handle_explanation_drill(+Dict, -Response): drive the Explanation Drill. The tree is
% sent (as `why`) on the first call and kept in the session; `answers` is the ordered
% list of the user's "yes"/"not_yet" replies. TOP and UNDERSTOOD are recomputed by
% replay and kept in the session (drill_state/2).
handle_explanation_drill(Dict, _{error: "Session expired", session_expired: true}) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
    \+ valid_session(SM), !.
handle_explanation_drill(Dict, Response) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
    le_kbs:note_session_use(SM),
    ( SM:le_kb_module_fact(KB) -> true ; KB = none ),
    dynamic(SM:drill_why/1), dynamic(SM:drill_state/2),
    ( get_dict(why, Dict, Why0), Why0 \== null ->
        retractall(SM:drill_why(_)), assertz(SM:drill_why(Why0)), Why = Why0
    ; ( SM:drill_why(Why) -> true ; Why = null )
    ),
    ( get_dict(answers, Dict, As), is_list(As) -> Answers = As ; Answers = [] ),
    (   Why == null -> Response = _{error: "No explanation to drill"}
    ;   drill_loop(KB, Why, Answers, "", [], [], Questions, TopF, UndF, Pending),
        subtree_weight(KB, Why, "", [], Initial),
        foldl(drill_progress(KB, Why), UndF, 0, Progress),
        retractall(SM:drill_state(_, _)),
        assertz(SM:drill_state(TopF, UndF)),
        Response = _{ok: true, initialCount: Initial, progress: Progress,
                     questions: Questions, pending: Pending, topPath: TopF}
    ).

% Sum of the weights of the understood subtrees (disjoint, so no double counting).
drill_progress(KB, Why, Path, A, B) :- subtree_weight(KB, Why, Path, [], W), B is A + W.

% dedup_keep_first(+KeyedPairs, -Values): the first Value for each distinct Key,
% preserving order.
dedup_keep_first(Pairs, Values) :- dedup_keep_first(Pairs, [], Values).
dedup_keep_first([], _, []).
dedup_keep_first([K-V|Rest], Seen, Out) :-
    ( memberchk(K, Seen) -> Out = Out1, Seen1 = Seen
    ; Out = [V|Out1], Seen1 = [K|Seen] ),
    dedup_keep_first(Rest, Seen1, Out1).

handle_get_game_data(Dict, _{error: "Session expired", session_expired: true}) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
    \+ valid_session(SM), !.
handle_get_game_data(Dict, Response) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
    le_kbs:note_session_use(SM),
    ( SM:le_kb_module_fact(KB) -> true; KB = none),
    ( get_dict(hideRepeated, Dict, false) -> set_show_repeated_explanations(true) ; set_show_repeated_explanations(false) ),
    
    % Handle Scenario
    (   get_dict(customScenario, Dict, CustomScenario), CustomScenario \== null ->
            clearSession(SM),
            ( KB \== none -> 
                catch(parse_custom_facts(KB, CustomScenario, Facts), error(le_parse_error(Msg), _), ErrorFacts = Msg),
                ( var(ErrorFacts) -> forall(member(F, Facts), addSessionFact(SM, F)) ; true )
            ; true )
        ; get_dict(scenario, Dict, ScenarioStr) ->  
            (   ((atom(ScenarioStr) ; string(ScenarioStr)), \+ sub_atom(ScenarioStr, _, _, _, '(')) ->  
                    atom_string(ScenarioName, ScenarioStr),
                    ( ScenarioName \== '' -> clearSession(SM), setScenarion(SM, ScenarioName); clearSession(SM))
                ; term_string(Scenario, ScenarioStr),
                  clearSession(SM),
                  ( is_list(Scenario) -> forall(member(F, Scenario), addSessionFact(SM, F)); addSessionFact(SM, Scenario) )
            )
        ; true
    ),

    (   nonvar(ErrorFacts) -> Response = _{error: ErrorFacts}
    ;   % Handle Query
        (   get_dict(customQuery, Dict, CustomQuery), CustomQuery \== null ->
                ( KB \== none ->
                    catch(parse_custom_query(KB, CustomQuery, Goal), error(le_parse_error(Msg), _), ErrorQuery = Msg),
                    ( var(ErrorQuery) -> Query = Goal ; true )
                ; Query = CustomQuery )
            ; get_dict(query, Dict, QueryStr),
              atom_string(QueryName, QueryStr),
              ( KB \== none,
                ( KB:query_info(QueryName, Goal, Content) -> true
                ; atom_number(QueryName, Num), KB:query_info(Num, Goal, Content) )
              -> Query = Goal,
                 % Prefer the original LE surface text of the named query (e.g.
                 % "we will cover which cost") over the goal-derived rendering.
                 ( query_surface_text(Content, QueryLE) -> true ; true )
              ; Query = QueryName )
        ),
        (   nonvar(ErrorQuery) -> Response = _{error: ErrorQuery}
            % A query with no answer cannot be proven, so there is nothing to
            % play. Gate on having a successful explanation before building the
            % game (we try both the original Query term and the named query).
        ;   \+ ( catch(query(SM, Query, _, _, _), _, fail)
               ; ( get_dict(query, Dict, QNameStr0), atom_string(QName0, QNameStr0),
                   catch(query(SM, QName0, _, _, _), _, fail) )
               ) ->
            print_message(warning, 'Proof Game: No answer for query'),
            Response = _{error: "You need a query with an answer to play"}
        ;   le_proof_game:extract_rules_and_facts(KB, SM, Query, Rules, ExtractedFacts, QueryTokens),
            ( nonvar(QueryLE) -> true
            ; KB \== none, le_kbs:item_to_instance(KB, Query, QueryTokens0) -> le_kbs:canonical_string(QueryTokens0, QueryLE)
            ; term_string(Query, QueryLE) ),
            % Enumerate the query's answers (capped), each with its explanation, so
            % the user can choose which one to prove — a query like "which dragon is
            % happy" has several, with very different proofs (some need a failure
            % subtree). The selected answer's explanation is the game's spine.
            game_answer_query(SM, Dict, Query, AnswerQuery),
            % Up to 25 answers (findnsols's first batch; avoids enumerating a
            % pathologically large or non-terminating answer set).
            ( findnsols(25, ALE-AWhy,
                  ( query(SM, AnswerQuery, TI, _, AWhy), le_kbs:canonical_string(TI, ALE) ),
                  Pairs0)
              -> true ; Pairs0 = [] ),
            answers_dedup(Pairs0, Answers),
            ( get_dict(answerIndex, Dict, Idx0), integer(Idx0) -> Idx = Idx0 ; Idx = 0 ),
            ( nth0(Idx, Answers, _-SelWhy) -> SelIdx = Idx
            ; Answers = [_-SelWhy|_] -> SelIdx = 0
            ; SelWhy = (-), SelIdx = 0 ),
            ( SelWhy == (-) ->
                JSONWhy = null,
                print_message(warning, 'Proof Game: No explanation found for query')
            ;   convert_why(SelWhy, KB, JSONWhy),
                print_message(informational, 'Proof Game: Found explanation for query')
            ),
            findall(AL, member(AL-_, Answers), AnswerLabels),
            Response = _{gameData: _{rules: Rules, facts: ExtractedFacts, query: QueryLE,
                                     queryTokens: QueryTokens, sessionModule: SMStr,
                                     explanation: JSONWhy, answers: AnswerLabels,
                                     answerIndex: SelIdx}, result: "ok"}
        )
    ).

% game_answer_query(+SM, +Dict, +Query, -AnswerQuery): the term to enumerate the
% query's answers over — the resolved goal if available, otherwise the named query.
game_answer_query(SM, Dict, Query, AnswerQuery) :-
    % \+ \+ : test satisfiability WITHOUT binding Query's variables — otherwise the
    % query goal would be committed to its first answer and the enumeration below
    % would only ever see that one answer.
    (   \+ \+ catch(query(SM, Query, _, _, _), _, fail)
    ->  AnswerQuery = Query
    ;   get_dict(query, Dict, QNameStr), atom_string(QName, QNameStr),
        AnswerQuery = QName
    ).

% answers_dedup(+LabelWhyPairs, -Unique): the first explanation for each distinct
% answer label, preserving order.
answers_dedup(Pairs, Out) :- answers_dedup(Pairs, [], Out).
answers_dedup([], _, []).
answers_dedup([L-W|Rest], Seen, Out) :-
    ( memberchk(L, Seen) -> Out = Out1, Seen1 = Seen
    ; Out = [L-W|Out1], Seen1 = [L|Seen] ),
    answers_dedup(Rest, Seen1, Out1).

%!  query_surface_text(+Content:list, -Text:string) is semidet.
%
%   Reconstructs the original LE surface text of a named query from the
%   query_clause tokens stored in query_info/3 (third argument). This preserves
%   the query's interrogative variables (e.g. "which cost") instead of the
%   goal-derived rendering ("a cost").
query_surface_text(Content, Text) :-
    is_list(Content),
    findall(S, (
        member(QC, Content),
        (   QC =.. [query_clause, _, Toks | _]
        ;   QC = query_body(_, Toks, _, _)     % multi-condition query: its raw body tokens
        ),
        le_grammar:reconstruct_name(Toks, S)
    ), Parts),
    Parts \== [],
    atomic_list_concat(Parts, ' and ', Atom),
    atom_string(Atom, Text).

term_to_le(KB, Term, LE) :-
    ( KB \== none, le_kbs:item_to_instance(KB, Term, Tokens) -> le_kbs:canonical_string(Tokens, LE)
    ; term_string(Term, LE)
    ).

handle_unify_game_nodes(Dict, Response) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
    le_kbs:note_session_use(SM),
    ( SM:le_kb_module_fact(KB) -> true ; KB = none ),
    get_dict(nodes, Dict, NodeSpecs),
    ( get_dict(edges, Dict, Edges) -> true ; Edges = [] ),
    le_proof_game:unify_game_nodes(KB, SM, NodeSpecs, Edges, Res),
    put_dict(Res, _{result: "ok"}, Response).

handle_load_facts_and_query(Dict, Response) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
    ( get_dict(hideRepeated, Dict, false) -> set_show_repeated_explanations(true) ; set_show_repeated_explanations(false) ),
    le_kbs:note_session_use(SM),
    get_dict(facts, Dict, FactsStrList),
    print_message(informational, 'Loading facts into session ~w' - [SM]),
    forall(member(FStr, FactsStrList), (term_string(F, FStr), addSessionFact(SM, F))),
    (   get_dict(goal, Dict, GoalStr) ->  
        print_message(informational, 'Running goal: ~w' - [GoalStr]),
        read_term_from_atom(GoalStr, Goal, [variable_names(VarNames)]),
        ( SM:le_kb_module_fact(KB) -> true; KB = none),
        findall(Answer, (
            reasoner:i(Goal, SM, _Unknowns, Why),
            convert_why_deduped(Why, KB, JSONWhy),
            maplist(convert_binding, VarNames, Bindings),
            dict_create(BindingsDict, bindings, Bindings),
            Answer = _{bindings: BindingsDict, explanation: JSONWhy}
        ), Answers),
        (   Answers \== [] ->  
            Response = _{
                facts: FactsStrList,
                goal: GoalStr,
                answers: Answers,
                result: "true"
            }
            ;   
            Response = _{result: "false"}
        )
        ;   
        Response = _{facts: FactsStrList, result: "ok"}
    ).

handle_query(Dict, Response) :-
    get_dict(theQuery, Dict, QueryStr),
    get_dict(module, Dict, ModuleStr),
    atom_string(Module, ModuleStr),
    ( get_dict(hideRepeated, Dict, false) -> set_show_repeated_explanations(true) ; set_show_repeated_explanations(false) ),
    ( get_dict(facts, Dict, FactsStrList) -> maplist(term_string, Facts, FactsStrList); Facts = []),
    (   (current_module(Module), current_predicate(Module:le_my_kb/1)) -> SM = Module, SM:le_kb_module_fact(KB), Owned = false
        ; current_module(Module) -> KB = Module, createSession(KB, SM), Owned = true
        ; KB = none, createSession(none, SM), Owned = true
    ),
    setup_call_cleanup(
        true,
        ( forall(member(F, Facts), addSessionFact(SM, F)),
          read_term_from_atom(QueryStr, Goal, [variable_names(VarNames)]),
          findall(Result, (
              reasoner:i(Goal, SM, Unknowns, Why),
              convert_why_deduped(Why, KB, JSONWhy),
              maplist(convert_binding, VarNames, Bindings),
              dict_create(BindingsDict, bindings, Bindings),
              maplist(convert_unknown(KB), Unknowns, JSONUnknowns),
              Result = _{
                  result: "true",
                  bindings: BindingsDict,
                  unknowns: JSONUnknowns,
                  why: JSONWhy
              }
          ), Results),
          ( Results == [] -> Response = _{results: [_{result: "false"}]}; Response = _{results: Results}) ),
        % Free the session if we created it here; otherwise keep the caller's
        % session alive and mark it as recently used.
        ( Owned == true -> destroySession(SM) ; note_session_use(SM) )
    ).

% --- Helpers ---

load_prolog_file(Path, Module) :-
    variant_sha1(Path, Hash),
    atom_concat(p, Hash, Module),
    ( current_module(Module) -> true; load_files(Module:Path, [])).

%!  convert_why_deduped(+Why, +KB, -JSON) is det.
%
%   Like convert_why/3, but first collapses repeated sub-explanations: when the
%   same explanation (a subtree that is a variant of another, modulo variable
%   renaming) occurs N>1 times under the same parent, only one occurrence is
%   kept and tagged with its count N. Used for the explanation panel / answers,
%   where negative explanations can otherwise contain thousands of identical
%   subtrees. NOT used for the proof game, which needs the full tree to wire up
%   its nodes.
%
%   Failure trees already arrive partly grouped from the reasoner
%   (group_variant_whys/2 in build_failure_tree/2, which wraps groups as
%   repeated_group(N, Why)); this pass also groups sibling success branches and
%   folds any reasoner-supplied counts in, so positive and negative explanations
%   are handled uniformly.
%   Whether repeated sub-explanations are collapsed is the client's preference
%   (reasoner:hide_repeated_explanations, set per query); when the user opts to
%   show them, the full tree is converted as-is.
convert_why_deduped(Why, KB, JSON) :-
    (   hide_repeated_explanations
    ->  group_repeated_whys(Why, Grouped),
        mark_cross_tree_repeats(Grouped, Marked),
        convert_why(Marked, KB, JSON)
    ;   convert_why(Why, KB, JSON)
    ).

% A repeated sub-explanation grouped from sibling duplicates: render the single
% kept occurrence in full, tagged with its count ("N repeated sub-explanations").
convert_why(repeated_group(N, Node), KB, JSON) :- !,
    convert_why(Node, KB, JSON0),
    put_dict(_{repeated: true, repeatedCount: N}, JSON0, JSON).
% A subtree that is a variant of one already shown elsewhere in the tree: render
% only its root, tagged repeated (no count) and carrying repeatedOf — the tree-path
% of the full original it stands in for, so the client can navigate to it. Node
% already has empty children.
convert_why(repeated_ref(Node, OrigPath), KB, JSON) :- !,
    convert_why(Node, KB, JSON0),
    put_dict(_{repeated: true, repeatedOf: OrigPath}, JSON0, JSON).
convert_why(success(Goal, range(Start, End), LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    is_naf_goal(Goal, Naf),
    JSON = _{type: "success", literal: LE, start: Start, end: End, naf: Naf, children: JSONChildren}.
convert_why(success(_Goal, unknown(Start, End), LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "unknown", literal: LE, start: Start, end: End, children: JSONChildren}.
convert_why(success(_Goal, unknown, LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "unknown", literal: LE, children: JSONChildren}.


convert_why(success(Goal, Ref, LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    is_naf_goal(Goal, Naf),
    (   KB \== none, KB:le_source_info(Ref, Start, End, _)
    ->  JSON = _{type: "success", literal: LE, start: Start, end: End, naf: Naf, children: JSONChildren}
    ;   JSON = _{type: "success", literal: LE, naf: Naf, children: JSONChildren}
    ).
% A "failed clause attempt" node (rule_attempt): one per clause whose head matched the
% failed goal (detailed failure explanations). Marked `ruleAttempt` so the important
% reason treats these extra structural nodes as transparent.
convert_why(failure(rule_attempt(_), range(Start, End), LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "failure", literal: LE, start: Start, end: End, children: JSONChildren, ruleAttempt: true}.
convert_why(failure(rule_attempt(_), _Ref, LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "failure", literal: LE, children: JSONChildren, ruleAttempt: true}.
convert_why(failure(_Goal, range(Start, End), LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "failure", literal: LE, start: Start, end: End, children: JSONChildren}.
convert_why(failure(_Goal, _Ref, LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "failure", literal: LE, children: JSONChildren}.
convert_why(Whys, KB, JSON) :-
    is_list(Whys), !,
    maplist(convert_why_child(KB), Whys, JSON).
convert_why(Other, _, JSON) :-
    term_string(Other, JSON).

convert_why_child(KB, Child, JSON) :-
    convert_why(Child, KB, JSON).

%!  group_repeated_whys(+Why, -Grouped) is det.
%
%   Collapses, within each sibling list, sub-explanations that are variants of
%   one another into a single representative wrapped as repeated_group(N, Node),
%   where N is how many times that explanation occurred under the same parent.
%   Reasoner-supplied repeated_group/2 wrappers (from build_failure_tree/2) are
%   unwrapped and their counts folded in, so a subtree pre-grouped M times that
%   also appears K more times here is reported as M+K. The single kept
%   occurrence is itself recursively grouped, so the whole tree shrinks.
%
%   "Variant" detection uses a renaming-invariant hash of the goal structure
%   (ignoring source ranges and the rendered LE text, which embed variable
%   numbers), so explanations differing only in internal variables — e.g.
%   le_type_check(_14156,payment) vs le_type_check(_14460,payment) — group too.
group_repeated_whys(Whys, Grouped) :-
    is_list(Whys), !,
    group_sibling_whys(Whys, Grouped).
group_repeated_whys(Why, Grouped) :-
    group_one_why(1, Why, Grouped).

% Group a list of siblings, summing multiplicities; keep first-occurrence order.
% Siblings are clustered by subsumption of their goal-structure signatures: two
% are merged when either is a variant of, or a generalisation of, the other
% (e.g. in_respect_of(A,B) with B unbound generalises in_respect_of(A,'this
% claim')). The MOST SPECIFIC node is kept as the representative so the displayed
% sub-explanation is the most informative one.
group_sibling_whys(Whys, Grouped) :-
    maplist(unwrap_repeated, Whys, Mults, Bares),
    maplist(why_struct_sig, Bares, Sigs),
    combine_sibling_groups(Sigs, Mults, Bares, Grouped).

combine_sibling_groups([], [], [], []).
combine_sibling_groups([Sig|Sigs], [M|Ms], [B|Bs], [G|Gs]) :-
    collect_related(Sigs, Ms, Bs, Sig, M, B, Total, RepBare, SigsRest, MsRest, BsRest),
    group_one_why(Total, RepBare, G),
    combine_sibling_groups(SigsRest, MsRest, BsRest, Gs).

% Pull out (and sum the multiplicities of) all later siblings whose signature is
% subsumption-related to the running representative, keeping the most specific.
collect_related([], [], [], _RepSig, Acc, RepBare, Acc, RepBare, [], [], []).
collect_related([Sig|Sigs], [M|Ms], [B|Bs], RepSig, Acc, RepBare, Total, OutBare, SigsOut, MsOut, BsOut) :-
    (   sigs_related(RepSig, Sig)
    ->  Acc1 is Acc + M,
        more_specific_sig(RepSig, RepBare, Sig, B, RepSig1, RepBare1),
        collect_related(Sigs, Ms, Bs, RepSig1, Acc1, RepBare1, Total, OutBare, SigsOut, MsOut, BsOut)
    ;   SigsOut = [Sig|SigsOut1], MsOut = [M|MsOut1], BsOut = [B|BsOut1],
        collect_related(Sigs, Ms, Bs, RepSig, Acc, RepBare, Total, OutBare, SigsOut1, MsOut1, BsOut1)
    ).

% Two signatures are related if either subsumes the other (variant included).
% Compared on independent copies so shared variables don't skew the test;
% subsumes_term/2 itself binds nothing.
sigs_related(S1, S2) :-
    copy_term(S1, C1), copy_term(S2, C2),
    ( subsumes_term(C1, C2) -> true ; subsumes_term(C2, C1) ).

% Keep the more specific of two related signatures (the one the other subsumes).
more_specific_sig(S1, B1, S2, B2, OutSig, OutBare) :-
    copy_term(S1, C1), copy_term(S2, C2),
    ( subsumes_term(C2, C1) -> OutSig = S1, OutBare = B1 ; OutSig = S2, OutBare = B2 ).

% Recurse into a kept representative's children, then re-wrap with its count.
group_one_why(Count, Node, Out) :-
    why_node(Node, Type, Goal, Range, LE, Children), !,
    group_sibling_whys(Children, GroupedChildren),
    rebuild_why_node(Type, Goal, Range, LE, GroupedChildren, Node1),
    ( Count > 1 -> Out = repeated_group(Count, Node1) ; Out = Node1 ).
group_one_why(Count, Other, Out) :-
    ( Count > 1 -> Out = repeated_group(Count, Other) ; Out = Other ).

unwrap_repeated(repeated_group(N, Node), N, Node) :- !.
unwrap_repeated(Node, 1, Node).

why_node(success(Goal, Range, LE, Children), "success", Goal, Range, LE, Children).
why_node(failure(Goal, Range, LE, Children), "failure", Goal, Range, LE, Children).

rebuild_why_node("success", Goal, Range, LE, Children, success(Goal, Range, LE, Children)).
rebuild_why_node("failure", Goal, Range, LE, Children, failure(Goal, Range, LE, Children)).

% A node's goal-structure signature (goals only, recursively), used to decide
% whether two sibling sub-explanations are the same (via variant/subsumption).
why_struct_sig(repeated_group(_, Node), Sig) :- !, why_struct_sig(Node, Sig).
why_struct_sig(Node, node_sig(Type, GoalStripped, ChildSigs)) :-
    why_node(Node, Type, Goal, _Range, _LE, Children), !,
    % Strip le_at/3 wrappers recursively so that source positions (which differ
    % between identical explanations from different rule locations) don't make
    % otherwise-identical sibling sub-explanations look distinct.
    strip_le_at_deep(Goal, GoalStripped),
    maplist(why_struct_sig, Children, ChildSigs).
why_struct_sig(Other, other_sig(Other)).

%!  mark_cross_tree_repeats(+Grouped, -Marked) is det.
%
%   Collapses subtrees that repeat ACROSS the explanation (not just among
%   siblings): walking pre-order, the first occurrence of a (non-leaf) subtree is
%   kept in full and each later occurrence — anywhere else in the forest — becomes
%   a root-only repeated_ref/2 marker (rendered repeated, WITHOUT a count, but
%   carrying the original's tree-path for "go to" navigation). Two
%   subtrees count as the same when their goal-structure signatures are variants.
%   Leaves are never collapsed (a one-line node is not worth a marker).
mark_cross_tree_repeats(Grouped, Marked) :-
    % Thread each node's CLIENT tree-path ("1.2.3") so a proxy can name the path of
    % the original it stands in for; the client mirrors this numbering when it
    % renders, so the path resolves directly to the original node's element.
    (   is_list(Grouped)
    ->  mctr_list(Grouped, '', 1, [], _Seen, Marked)
    ;   mctr(Grouped, '1', [], _Seen, Marked)
    ).

% mctr(+Node, +Path, +SeenIn, -SeenOut, -Marked): Seen maps each kept subtree's
% repeat-key to the Path of its first (full) occurrence.
mctr(Whys, Path, SeenIn, SeenOut, Marked) :-
    is_list(Whys), !,
    mctr_list(Whys, Path, 1, SeenIn, SeenOut, Marked).
mctr(repeated_group(N, Node), Path, SeenIn, SeenOut, Out) :- !,
    node_repeat_key(Node, Key),
    (   memberchk(Key-OrigPath, SeenIn)
    ->  root_only_marker(Node, OrigPath, Out), SeenOut = SeenIn
    ;   mctr_keep_children(Node, Path, [Key-Path|SeenIn], SeenOut, Node1),
        Out = repeated_group(N, Node1)
    ).
mctr(Node, Path, SeenIn, SeenOut, Out) :-
    why_node(Node, _, _, _, _, Children), !,
    (   Children == []
    ->  Out = Node, SeenOut = SeenIn                 % leaf: keep as-is, do not register
    ;   node_repeat_key(Node, Key),
        (   memberchk(Key-OrigPath, SeenIn)
        ->  root_only_marker(Node, OrigPath, Out), SeenOut = SeenIn
        ;   mctr_keep_children(Node, Path, [Key-Path|SeenIn], SeenOut, Out)
        )
    ).
mctr(Other, _Path, Seen, Seen, Other).

mctr_list([], _Path, _I, Seen, Seen, []).
mctr_list([W|Ws], Path, I, SeenIn, SeenOut, [M|Ms]) :-
    child_path(Path, I, CPath),
    mctr(W, CPath, SeenIn, Seen1, M),
    I1 is I + 1,
    mctr_list(Ws, Path, I1, Seen1, SeenOut, Ms).

% Keep a node (its first occurrence): recurse into its children, threading Seen.
mctr_keep_children(Node, Path, SeenIn, SeenOut, Out) :-
    why_node(Node, Type, Goal, Range, LE, Children),
    mctr_list(Children, Path, 1, SeenIn, SeenOut, MarkedChildren),
    rebuild_why_node(Type, Goal, Range, LE, MarkedChildren, Out).

% child_path(+ParentPath, +Index1, -ChildPath): the client's 1-indexed tree path.
child_path('', I, P) :- !, atom_number(P, I).
child_path(Parent, I, P) :- format(atom(P), '~w.~w', [Parent, I]).

% A variant-insensitive key for a subtree (numbervars-canonicalised signature).
node_repeat_key(Node, Key) :-
    why_struct_sig(Node, Sig),
    % copy_term/3 strips attributes (custom-scenario facts can carry attributed
    % variables, on which numbervars/4 would throw a type error).
    copy_term(Sig, C, _), numbervars(C, 0, _), term_to_atom(C, Key).

% A root-only copy of Node (children removed), wrapped as a repeated_ref/2 marker
% that also carries OrigPath — the client tree-path of the full original it stands
% in for, so the UI can offer "go to" navigation.
root_only_marker(Node, OrigPath, repeated_ref(RootOnly, OrigPath)) :-
    why_node(Node, Type, Goal, Range, LE, _),
    rebuild_why_node(Type, Goal, Range, LE, [], RootOnly).

% strip_le_at_deep(+Term, -Stripped): recursively replace every le_at(G,_,_)
% subterm with G, dropping all embedded source positions.
strip_le_at_deep(T, T) :- var(T), !.
strip_le_at_deep(le_at(G, _, _), Out) :- !, strip_le_at_deep(G, Out).
strip_le_at_deep(T, Out) :-
    compound(T), !,
    T =.. [F|Args],
    maplist(strip_le_at_deep, Args, Args1),
    Out =.. [F|Args1].
strip_le_at_deep(T, T).

%!  is_naf_goal(+Goal, -Naf) is det.
%
%   Naf is the JSON boolean true if Goal is a negation-as-failure goal
%   ("it is not the case that ..."), otherwise false.
is_naf_goal(Goal, Naf) :-
    ( nonvar(Goal), strip_le_at_goal(Goal, not(_)) -> Naf = true ; Naf = false ).

strip_le_at_goal(le_at(G, _, _), Stripped) :- !, strip_le_at_goal(G, Stripped).
strip_le_at_goal(G, G).

get_source_info(Ref, KB, Source, Start, End) :-
    ( (KB \== none, KB:le_source_info(Ref, Start, End, _)) -> term_string(Ref, Source); term_string(Ref, Source), Start = 0, End = 0).

convert_binding(Name=Val, Name-JSONVal) :-
    ( (atom(Val) ; string(Val) ; number(Val)) -> JSONVal = Val; term_string(Val, JSONVal)).

convert_unknown(KB, Goal, _{goal: GoalStr, module: KBStr}) :-
    term_string(Goal, GoalStr),
    ( atom(KB) -> KBStr = KB; term_string(KB, KBStr)).

%!  convert_unknowns_to_le(+KB, +Unknowns:list, -LEStrings:list(string)) is det.
%
%   Render each unknown goal (from the third argument of i/4 or explain/4) as a
%   Logical English template instance string, so the client can show it in a
%   tooltip on the corresponding answer. Falls back to the raw Prolog term when
%   no KB/template is available or rendering fails.
convert_unknowns_to_le(KB, Unknowns, LEStrings) :-
    maplist(convert_unknown_to_le(KB), Unknowns, LEStrings).

convert_unknown_to_le(KB, U, LEString) :-
    (   KB \== none,
        catch(item_to_instance(KB, U, Tokens), _, fail),
        flatten(Tokens, FlatTokens),
        catch(canonical_string(FlatTokens, Atom), _, fail)
    ->  atom_string(Atom, LEString)
    ;   term_string(U, LEString)
    ).

handle_get_prolog(Dict, Response) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
    le_kbs:note_session_use(SM),
    ( SM:le_kb_module_fact(KB) -> true; KB = none),
    ( KB == none -> Response = _{error: "No KB loaded"}
    ; get_dict(position, Dict, Pos),
      ( find_clause_at_pos(KB, Pos, Clause) ->
          with_output_to(string(PrologStr), portray_clause(Clause)),
          Response = _{prolog: PrologStr}
      ; Response = _{error: "No term found at this position"}
      )
    ).

find_clause_at_pos(KB, Pos, Clause) :-
    findall(range(Len, Ref), (
        KB:le_source_info(Ref, Start, End, _),
        Pos >= Start, Pos =< End,
        Len is End - Start
    ), Ranges),
    sort(Ranges, SortedRanges),
    member(range(_, Ref), SortedRanges),
    clause(KB:Head, Body, Ref),
    (   Head = scenario(Name, Facts)
    ->  % Show just the scenario fact under the cursor rather than dumping the
        % whole fact list. Fall back to the whole (source-stripped) scenario when
        % the cursor is on the header/expectation, not on a specific fact.
        (   scenario_fact_at_pos(Facts, Pos, Clause)
        ;   strip_fact_sources(Facts, PlainFacts), Clause = scenario(Name, PlainFacts)
        ),
        !
    ;   is_interesting_term(Head)
    ->  ( Body == true -> Clause = Head; Clause = (Head :- Body)),
        !
    ).

% scenario_fact_at_pos(+Facts, +Pos, -Fact): the single scenario fact whose source
% range encloses Pos (the smallest one, should ranges ever overlap).
scenario_fact_at_pos(Facts, Pos, Fact) :-
    findall(Len-F,
            ( member(fact_with_source(F, S, E), Facts), S =< Pos, Pos =< E, Len is E - S ),
            Pairs),
    Pairs \== [],
    keysort(Pairs, [_-Fact|_]).

% strip_fact_sources(+Facts, -PlainFacts): drop the fact_with_source/3 wrappers so
% a scenario renders as a clean list of fact terms.
strip_fact_sources([], []).
strip_fact_sources([fact_with_source(F, _, _)|T], [F|T2]) :- !, strip_fact_sources(T, T2).
strip_fact_sources([F|T], [F|T2]) :- strip_fact_sources(T, T2).

is_interesting_term(Head) :-
    functor(Head, F, N),
    (   \+ le_kbs:is_system_predicate(F/N)
    %   is_a/2 is a system predicate, but is-a facts and rules (ontology
    %   statements, and rule heads that the generic "*X* is a *Y*" template
    %   produced) are genuine user clauses: show them rather than falling through
    %   to the enclosing le_kb/1 fact, whose range spans the whole knowledge base.
    ;   member(F/N, [is_a/2, le_kb/1, le_dict/1, ontology/1, scenario/2, query_info/3, le_expected/3])
    ).
%!  handle_docs(+Request) is det.
%
%   Serves the repository's own user documentation, rendered cleanly (no repo
%   chrome), from the docs/ tree:
%   - a request for an EXISTING file under docs/ (an image, or a raw .md that
%     the viewer fetches) is served directly;
%   - a request for a doc NAME (e.g. /docs/tutorial0/IntroToLE2, where
%     docs/tutorial0/IntroToLE2.md exists) returns the Markdown viewer shell,
%     which fetches that same path + ".md" and renders it client-side.
%   The rendered page sits at the same path depth as its .md source, so the
%   document's relative image references resolve to the right files under docs/.
%   Path traversal outside docs/ is refused.
handle_docs(Request) :-
    member(path(Path), Request),
    atom_concat('/docs/', Rel0, Path),
    ( sub_atom(Rel0, _, _, 0, '/') -> atom_concat(Rel, '/', Rel0 ) ; Rel = Rel0 ),
    docs_dir(DocsDir),
    (   safe_docs_path(DocsDir, Rel, AbsFile), exists_file(AbsFile)
    ->  http_reply_file(AbsFile, [unsafe(true)], Request)   % image, or raw .md; safe_docs_path already vetted it
    ;   atom_concat(Rel, '.md', RelMd),
        safe_docs_path(DocsDir, RelMd, AbsMd), exists_file(AbsMd)
    ->  http_reply_file('web_extras/docsview/viewer.html', [mime_type(text/html)], Request)
    ;   throw(http_reply(not_found(Path)))
    ).

docs_dir(Dir) :- absolute_file_name('docs', Dir, [file_type(directory), access(read)]).

%!  handle_executive(+Request) is det.
%
%   The minimalist, mobile-first "executive" entry point: pick an example
%   program, choose a scenario and query, and run it — no editing. Query
%   parameters (program, scenario, query) are read client-side from the URL.
handle_executive(Request) :-
    http_reply_file('web_extras/executive/index.html', [mime_type(text/html)], Request).

% The requested relative path resolves to a file strictly inside DocsDir
% (rejects '..' escapes).
safe_docs_path(DocsDir, Rel, Abs) :-
    Rel \== '',
    catch(absolute_file_name(Rel, Abs, [relative_to(DocsDir)]), _, fail),
    atom_concat(DocsDir, '/', DocsPrefix),
    sub_atom(Abs, 0, _, _, DocsPrefix).

handle_source(Request) :-
    member(path(Path), Request),
    atom_concat('/source/', ExamplePath, Path),
    atom_concat(ExamplePath, '.le', FilePath),
    (   http_in_session(_SessionId), http_session_data(user(_, Roles)) -> UserRoles = Roles ; UserRoles = [] ),
    (   is_allowed_export(FilePath), is_path_allowed(FilePath, UserRoles)
    ->  (   exists_file(FilePath)
        ->  http_reply_file(FilePath, [mime_type(text/plain)], Request)
        ;   http_reply(not_found(FilePath))
        )
    ;   http_reply(forbidden(FilePath))
    ).

% installations usually define ALLOWED_LE_EXPORTS=examples/moreExamples
is_allowed_export(FilePath) :- getenv('ALLOWED_LE_EXPORTS', AllowedStr),
    split_string(AllowedStr, ",", " ", AllowedDirs),
    member(DirStr, AllowedDirs),
    atom_string(Dir, DirStr),
    sub_atom(FilePath, 0, _, _, Dir).
