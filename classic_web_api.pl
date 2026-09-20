/** <module> Logical English Classic Web API

    This module provides a REST API for Logical English. It supports
    loading KBs, running queries, and interacting with the LE Assistant.
    It also serves the web-based editor.

    The operations themselves — everything POSTed to /leapi — live in
    le_api.pl, which knows nothing about HTTP. This module is the HTTP half:
    the server, the routes, the server-rendered pages (landing, multilingual,
    login), the documentation and source handlers, and the translation of one
    POST into one handle_operation/2 call. The WebAssembly build (le_wasm.pl)
    is the other transport over the same le_api.pl, which is why the split
    exists.
*/

:- module(classic_web_api, [start_api_server/0, start_api_server/1, port_in_use/1]).

:- use_module(library(socket)).
:- use_module(library(time)).      % call_with_time_limit/2 (autoloaded before; the WASM build has a shim)
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
:- use_module(le_api).
:- use_module(le_proof_game).
:- use_module(tokenizer).
:- use_module(le_grammar).
:- use_module(reasoner).
:- use_module(le_system_templates).
:- use_module(le_i18n).
:- use_module(le_graph).
:- use_module(le_documents).
:- use_module(le_original_text).
:- use_module(le_import).
:- use_module(le_why_not).
:- use_module(le_lps_legal).
:- use_module(le_scasp).
:- use_module(le_lps).
:- use_module(le_assistant).
:- use_module(le_contract_assistant).
:- use_module(dap_server).
:- use_module(llm/llm_client, [llm_list_models/1]).
:- use_module(llm/llm_prices, [llm_prices_start/0]).
:- use_module(nl_to_le, [english_to_le/8]).
:- use_module(llm/mcp, [handle_mcp/1, handle_rest_list_examples/1, handle_rest_query/1, handle_rest_verify/1, handle_rest_example_details/1]).
:- use_module(le_users).
:- use_module(restricted_paths).
:- use_module(le_telemetry).

:- dynamic build_info/1.

%  The handler's time limit is above those the operations themselves apply
%  (operation_time_limit/2): an operation that runs out of time replies so,
%  instead of the dispatcher killing the request (a 500, and an error report).
:- http_handler(root(leapi), handle_leapi, [method(post), time_limit(3700)]).
:- http_handler(root(build_info), handle_build_info, [method(get)]).
% Error reports and analytics, when the environment configures them
% (le_telemetry.pl, docs/dev/telemetry.md): every page loads /telemetry.js.
:- http_handler(root('telemetry.js'), handle_telemetry_js, [method(get)]).
:- http_handler(root(telemetry_test), handle_telemetry_test, [method(get)]).
% Stub services for tests of programs that declare services (le_services.pl):
% POST a service request to /test_services/matcher or /test_services/judge.
:- http_handler(root(test_services), handle_test_services, [prefix, method(post)]).
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
:- http_handler('/multilingual', handle_multilingual, []).
:- http_handler('/dap', dap_websocket_handler, []).
% The pages and scripts change with the code; `no-cache` makes the browser
% ask again each time (a 304 when unchanged), where without it Safari kept an
% old page beside a new script (the executive's views: an element the old
% page lacked).
:- http_handler('/editor/', http_reply_from_files('editor', [headers([cache_control('no-cache')])]), [prefix]).
:- http_handler('/web_extras/', http_reply_from_files('web_extras', [headers([cache_control('no-cache')])]), [prefix]).
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
    % Per-token model prices (LiteLLM's public table) for the Contract
    % Assistant's cost estimates: cached copy now, refresh in the background.
    llm_prices_start,
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

%   The pages' telemetry script: a no-op unless Sentry or Web Analytics is
%   configured; the feedback form's words in the cookie's UI language.
handle_telemetry_js(Request) :-
    set_cookie_language(Request),
    le_telemetry:telemetry_js(JS),
    format('Content-type: application/javascript; charset=UTF-8~n'),
    format('Cache-Control: no-cache~n~n'),
    write(JS).

handle_telemetry_test(_Request) :-
    le_telemetry:telemetry_test(Reply),
    reply_json_dict(Reply).

:- multifile prolog:message//1.
prolog:message(error(le_server_error(port_in_use(Port)), _)) -->
    [ 'Cannot start LE API server: port ~w is already in use.'-[Port], nl,
      'Another server is already listening there; stop it (or pick another port) first.'-[] ].

%!  static_export is semidet.
%
%   True when this server is running to be *copied*, not to be used: the
%   WebAssembly build's wasm/build.sh starts it, fetches the server-rendered
%   pages, and saves them as the static site's (there is no Prolog rendering
%   pages on a static host). It is set with LE_STATIC_EXPORT=1.
%
%   What it changes is only what a static copy cannot honour: a login link to
%   a server with no accounts, and a button that would run the test suite on a
%   server that is not there. Everything else about the page is the same page,
%   which is the point of copying it rather than writing a second one.
static_export :-
    getenv('LE_STATIC_EXPORT', V), V \== '', V \== '0'.

%!  set_request_language(+Request) is det.
%
%   Sets the active (message/UI) language for this API request from the ?lang=
%   query parameter, when present and registered — else back to the default:
%   HTTP worker threads are pooled, so leaving the previous request's language
%   in place would leak it into unrelated requests. The program's OWN language
%   still governs parsing (parse_le_tokens re-detects it), per decision O-6.
set_request_language(Request) :-
    (   catch(http_parameters(Request, [lang(Lang, [optional(true), default('')])]), _, Lang = ''),
        Lang \== '',
        le_i18n:known_language(Lang)
    ->  le_i18n:set_le_language(Lang)
    ;   le_i18n:set_le_language(default)
    ).

%!  set_cookie_language(+Request) is det.
%
%   Sets the active language from the le_ui_lang cookie (used by the
%   server-rendered /login page — decision O-13; the landing pages render in
%   a fixed language and SET the cookie instead).
set_cookie_language(Request) :-
    (   member(cookie(Cookies), Request),
        memberchk(le_ui_lang=Lang, Cookies),
        le_i18n:known_language(Lang)
    ->  le_i18n:set_le_language(Lang)
    ;   le_i18n:set_le_language(default)
    ).

% Shorthand used by the server-rendered pages below.
uit(Key, Text) :- le_i18n:ui_text(Key, Text).

handle_leapi(Request) :-
    set_request_language(Request),
    http_read_json_dict(Request, Dict),
    (   validate_token(Dict) ->  
            get_dict(operation, Dict, Op),
            print_message(informational, le_api_info(Op)),
            operation_time_limit(Dict, Limit),
            catch(( call_with_time_limit(Limit, handle_operation(Dict, Response0)) -> Outcome = done ; Outcome = failed ),
                  E, ( print_message(error, E), Outcome = caught(E) )),
            (   Outcome == done
            ->  print_message(informational, le_api_info(success(Op))),
                % Ranges inside included resources carry their resource.
                le_kbs:annotate_resource_ranges(Response0, Response),
                reply_json_dict(Response)
            ;   % To Sentry, when the server is configured for it (le_telemetry.pl).
                ( Outcome = caught(Ball) -> Report = Ball ; Report = failed ),
                le_telemetry:telemetry_report(Report, [operation(Op)]),
                print_message(error, le_api_error(Op, "Operation failed")),
                reply_json_dict(_{error: "Operation failed or internal error"}, [status(500)])
            )
        ; print_message(warning, le_api_info("Invalid token")),
          reply_json_dict(_{error: "Invalid token"}, [status(403)])
    ).


validate_token(Dict) :-
    get_dict(token, Dict, Token),
    Token == "myToken123".

%   Who the request is from, for le_api.pl's benefit: the HTTP session's user,
%   when one is logged in. This is the whole of what the operations know about
%   authentication, and the only thing they need to: restricted_paths.pl
%   decides what a set of roles may see.
le_api:le_api_user(Email, Roles) :-
    http_in_session(_SessionId),
    http_session_data(user(Email, Roles)).


% --- Landing Page ---

handle_landing_page(Request) :-
    % The standard landing page IS the English page: it always renders in
    % English. It does NOT touch the UI-language preference — only the
    % /multilingual pages set it (their back-to-English link resets it).
    le_i18n:set_le_language(default),
    http_parameters(Request, [run_tests(RunTests, [boolean, optional(true), default(false)]),
                              dir(DirParam0, [optional(true), default('')])]),
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
    %  The login corner, as a *term computed here* rather than a conditional
    %  written into the page below: everything inside reply_html_page/2 is
    %  read as HTML, so an `( … -> … ; … )` there is an element named `;` and
    %  the corner silently disappears.
    (   static_export
    ->  AuthCorner = ''     % no accounts in a static copy of this page
    ;   (   UserEmail == 'anonymous'
        ->  uit('Login', LoginTxt), format(atom(LoginLbl), '[~w]', [LoginTxt]),
            AuthLink = a(href('/login'), LoginLbl)
        ;   uit('Logout', LogoutTxt), format(atom(LogoutLbl), '[~w]', [LogoutTxt]),
            AuthLink = a(href('/logout'), LogoutLbl)
        ),
        uit('Logged in as: ', LoggedInAs0),
        AuthCorner = div([style('float: right; padding: 10px;')], [
                         span([LoggedInAs0, b(UserEmail), ' ']),
                         AuthLink
                     ])
    ),
    le_examples_dir(Dir),
    % ?dir=<subdir> focuses the example list on one example subdirectory (e.g.
    % /?dir=abduction, /?dir=insureLE2/testing) — for sharable links into a
    % group of examples. An unknown (or access-restricted) directory falls back
    % to the full list with a note; restricted directories are reported exactly
    % like missing ones, so the parameter cannot probe their existence.
    normalize_dir_param(DirParam0, DirParam1),
    example_current_dir(DirParam1, DirParam),
    (   DirParam == '' ->
        landing_example_items(Dir, UserRoles, ExampleItems),
        FocusNote = ''
    ;   safe_example_subdir(DirParam, Dir, SubDirPath, UserRoles) ->
        atom_concat(DirParam, '/', Prefix),
        landing_example_items(SubDirPath, Prefix, UserRoles, ExampleItems),
        FocusNote = span([' showing ', b([DirParam, '/']), ' ', a(href('/'), '[show all]')])
    ;   landing_example_items(Dir, UserRoles, ExampleItems),
        format(atom(NotFoundMsg), ' Example directory \'~w\' not found.', [DirParam]),
        FocusNote = span(style('color: red;'), NotFoundMsg)
    ),
    build_info(BuildInfo),
    landing_folders_script(FolderScript),
    uit('Edit and Query: ', EditAndQuery),
    uit('[New Document]', NewDocument),
    uit('expand all', ExpandAll),
    uit('collapse all', CollapseAll),
    uit('Just run a program: ', JustRun),
    uit('[Executive view]', ExecutiveView),
    uit('A minimalist, mobile-friendly way to pick a program, choose a scenario and question, and see the answer — no editing.', ExecBlurb),
    uit('GitHub Repository', GitHubRepo),
    uit('Documentation', DocumentationTxt),
    uit('Search the documentation', SearchDocsTxt),
    uit('Search', SearchTxt),
    landing_doc_items(DocItems),
    uit('Test Suite', TestSuiteTxt),
    uit('Run All Tests', RunAllTests),
    %  Running the whole suite is a server's job, and a static copy has none.
    (   static_export
    ->  TestSuiteSection = ''
    ;   TestSuiteSection = div([
            h2(TestSuiteTxt),
            form([action('/'), method('get')], [
                input([type(hidden), name(run_tests), value(true)]),
                input([type(submit), value(RunAllTests)])
            ])])
    ),
    reply_html_page(
        [title('Logical English 2.0'),
         script([src('/telemetry.js')], []),
         % Collapsible example folders: open/closed state per folder is remembered
         % in LocalStorage; ?expand=all opens everything (script embedded below).
         style('li.le-folder-item { list-style: none; } \c
                details.le-folder > summary { cursor: pointer; } \c
                .le-folder-blurb { color: #666; font-weight: normal; }'),
         script([type('text/javascript')], FolderScript)],
        [
            AuthCorner,
            h1('Logical English 2.0'),
            p(small(['Build: ', BuildInfo])),
            ul([
                li([
                    b(EditAndQuery),
                    a(href('/editor/index.html'), NewDocument),
                    ' ',
                    span([id('le-folder-controls'), style('display:none;')], [
                        '(',
                        a([href('#'), id('le-expand-all')], ExpandAll),
                        ' · ',
                        a([href('#'), id('le-collapse-all')], CollapseAll),
                        ')'
                    ]),
                    FocusNote,
                    ul(ExampleItems)
                ]),
                li([
                    b(JustRun),
                    a(href('/executive'), ExecutiveView),
                    br([]),
                    small(ExecBlurb)
                ]),
                li(a(href('https://github.com/LogicalContracts/LogicalEnglish2'), GitHubRepo))
            ]),
            h2(DocumentationTxt),
            form([action('/docs/search'), method(get), role(search)], [
                input([type(search), name(q), placeholder(SearchDocsTxt), 'aria-label'(SearchDocsTxt), size(32)]),
                ' ',
                input([type(submit), value(SearchTxt)])
            ]),
            ul(DocItems),
            TestSuiteSection,
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
    set_cookie_language(Request),
    (   member(method(post), Request)
    ->  http_parameters(Request, [email(Email, []), password(Password, []), return(Ret, [default('/')])]),
        (   authenticate_le_user(Email, Password, Roles)
        ->  http_session_assert(user(Email, Roles)),
            ( sub_atom(Ret, 0, 1, _, '/'), \+ sub_atom(Ret, 0, 2, _, '//') -> Target = Ret ; Target = '/' ),
            http_redirect(moved, Target, Request)
        ;   uit('Login Failed', LoginFailed),
            uit('Invalid email or password.', InvalidCreds),
            uit('Try again', TryAgain),
            reply_html_page(
                [title(LoginFailed), script([src('/telemetry.js')], [])],
                [h1(LoginFailed), p(InvalidCreds), a(href('/login'), TryAgain)]
            )
        )
    ;   safe_return(Request, Ret),
        uit('Login', LoginTxt),
        uit('Email: ', EmailLbl),
        uit('Password: ', PasswordLbl),
        reply_html_page(
            [title(LoginTxt), script([src('/telemetry.js')], [])],
            [
                h1(LoginTxt),
                form([action('/login'), method('post')], [
                    input([type(hidden), name(return), value(Ret)]),
                    p([EmailLbl, input([type(text), name(email)])]),
                    p([PasswordLbl, input([type(password), name(password)])]),
                    p(input([type(submit), value(LoginTxt)]))
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

%!  normalize_dir_param(+DirParam0:atom, -DirParam:atom) is det.
%
%   Strips any trailing '/'s from the landing page's ?dir= value, so
%   ?dir=abduction/ and ?dir=abduction are equivalent.
normalize_dir_param(D0, D) :-
    (   sub_atom(D0, Prefix, 1, 0, '/'), Prefix > 0
    ->  sub_atom(D0, 0, Prefix, 1, D1),
        normalize_dir_param(D1, D)
    ;   D0 == '/' -> D = ''
    ;   D = D0
    ).

%!  example_current_dir(+Dir0:atom, -Dir:atom) is det.
%
%   A ?dir= value as the directory is named now (le_kbs:example_dir_alias/2):
%   /?dir=abduction keeps working after abduction/ moved.
example_current_dir(Dir0, Dir) :-
    (   Dir0 == '' -> Dir = ''
    ;   le_kbs:example_dir_alias(Dir0, Dir1) -> Dir = Dir1
    ;   le_kbs:example_current_name(Dir0, Dir)
    ).

%!  safe_example_subdir(+DirParam:atom, +BaseDir:atom, -SubDirPath:atom, +UserRoles:list) is semidet.
%
%   DirParam names an existing, access-allowed subdirectory of the examples
%   BaseDir. Only plain relative paths are accepted: every '/'-separated
%   component must be non-empty and not start with '.' — which rejects
%   absolute paths and the '.'/'..' components that could escape BaseDir, and
%   keeps hidden directories unaddressable.
safe_example_subdir(DirParam, BaseDir, SubDirPath, UserRoles) :-
    atomic_list_concat(Parts, '/', DirParam),
    Parts \== [],
    forall(member(P, Parts), (P \== '', \+ sub_atom(P, 0, 1, _, '.'))),
    directory_file_path(BaseDir, DirParam, SubDirPath),
    exists_directory(SubDirPath),
    is_path_allowed(SubDirPath, UserRoles).

%!  landing_example_items(+Dir:atom, +UserRoles:list, -Items:list) is det.
%
%   Builds HTML list items for all examples in Dir, grouping subdirectory
%   examples under an indented header. Subdirectories are recursed into to any
%   depth, so e.g. examples/.../insureLE2/testing/foo appears as
%   insureLE2/ > testing/ > foo.
landing_example_items(Dir, UserRoles, Items) :-
    landing_example_items(Dir, '', UserRoles, Items0),
    % The extra example trees beside the main one (le_kbs:le_extra_examples_dir/2),
    % each as one more collapsible folder named after its directory.
    findall(li([class('le-folder-item')],
               details(['data-path'(Prefix), class('le-folder')],
                       [summary([b(Prefix)|Blurb]), ul(SubItems)])),
            ( le_kbs:le_extra_examples_dir(Root, ExtraDir),
              exists_directory(ExtraDir),
              is_path_allowed(ExtraDir, UserRoles),
              atom_concat(Root, '/', Prefix),
              landing_example_items(ExtraDir, Prefix, UserRoles, SubItems),
              SubItems \== [],
              folder_blurb(ExtraDir, Blurb) ),
            ExtraItems),
    append(Items0, ExtraItems, Items).


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
                              [summary([b([SubDir, '/'])|Blurb]), ul(SubItems)])), (
        member(SubDir, Files),
        \+ sub_atom(SubDir, 0, 1, _, '.'),
        directory_file_path(Dir, SubDir, SubDirPath),
        exists_directory(SubDirPath),
        is_path_allowed(SubDirPath, UserRoles),
        atomic_list_concat([Prefix, SubDir, '/'], SubPrefix),
        landing_example_items(SubDirPath, SubPrefix, UserRoles, SubItems),
        SubItems \= [],
        folder_blurb(SubDirPath, Blurb)
    ), SubDirPairs),
    keysort(SubDirPairs, SubDirSorted),
    pairs_values(SubDirSorted, SubDirItems),
    append(DirectItems, SubDirItems, Items).

% --- Multilingual entry point (/multilingual) ---

%!  handle_multilingual(+Request) is det.
%
%   The multilingual entry point. With ?lang=<code> naming a registered
%   non-English language that has an examples/<lang>/ tree, serves a landing
%   page circumscribed to that language (examples from its tree only, chrome
%   strings in that language). Without a usable lang parameter it serves a
%   language picker; ?lang=en goes back to the standard (English) landing page.
handle_multilingual(Request) :-
    catch(http_parameters(Request, [lang(Lang, [optional(true), default('')])]), _, Lang = ''),
    (   Lang == en
    ->  http_redirect(moved_temporary, '/', Request)
    ;   language_examples_dir(Lang, LangDir)
    ->  multilingual_landing_page(Lang, LangDir)
    ;   multilingual_picker_page
    ).

%!  multilingual_picker_page is det.
%
%   Language chooser: one link per registered non-English language with an
%   examples/<lang>/ tree, each shown by its autonym. Rendered neutrally in
%   English; it sets no language preference on load, but its back-to-English
%   link resets the preference like the per-language pages' one.
multilingual_picker_page :-
    le_i18n:set_le_language(default),
    findall(li(a(href(Url), Autonym)), (
        language_examples_dir(Lang, _),
        le_i18n:language_autonym(Lang, Autonym),
        format(atom(Url), '/multilingual?lang=~w', [Lang])
    ), LangItems),
    ui_lang_pref_script('', PrefScript),
    reply_html_page(
        [title('Logical English — Multilingual'),
         script([src('/telemetry.js')], []),
         script([type('text/javascript')], PrefScript)],
        [
            h1('Logical English — Multilingual'),
            p(b('Choose a language: ')),
            ul(LangItems),
            p(a([href('/'), id('le-back-english')], 'Logical English (in English)'))
        ]
    ).

%!  multilingual_landing_page(+Lang:atom, +LangDir:atom) is det.
%
%   The landing page circumscribed to one language: only the examples of the
%   examples/<Lang>/ tree, all chrome strings in Lang. Visiting it also makes
%   Lang the UI-language preference (localStorage + cookie, decision O-13),
%   so the editor pages linked from here render in Lang too; clicking the
%   back link to the standard (English) landing page resets the preference
%   to English (the standard page itself never touches it).
multilingual_landing_page(Lang, LangDir) :-
    le_i18n:set_le_language(Lang),
    (   http_in_session(_SessionId),
        http_session_data(user(Email, Roles))
    ->  UserEmail = Email, UserRoles = Roles
    ;   UserEmail = 'anonymous', UserRoles = []
    ),
    %  As on the standard landing page: the corner is a term computed here,
    %  never a conditional inside the page.
    (   static_export
    ->  AuthCorner = ''
    ;   (   UserEmail == 'anonymous'
        ->  uit('Login', LoginTxt), format(atom(LoginLbl), '[~w]', [LoginTxt]),
            AuthLink = a(href('/login'), LoginLbl)
        ;   uit('Logout', LogoutTxt), format(atom(LogoutLbl), '[~w]', [LogoutTxt]),
            AuthLink = a(href('/logout'), LogoutLbl)
        ),
        uit('Logged in as: ', LoggedInAs0),
        AuthCorner = div([style('float: right; padding: 10px;')], [
                         span([LoggedInAs0, b(UserEmail), ' ']),
                         AuthLink
                     ])
    ),
    le_i18n:language_autonym(Lang, Autonym),
    format(atom(Title), '~w 2.0', [Autonym]),
    atom_concat(Lang, '/', Prefix),
    landing_example_items(LangDir, Prefix, UserRoles, ExampleItems),
    build_info(BuildInfo),
    landing_folders_script(FolderScript),
    ui_lang_pref_script(Lang, PrefScript),
    % The syntax summary, when a translation exists (docs/user/reference/language.<lang>.md).
    (   atomic_list_concat(['docs/user/reference/language.', Lang, '.md'], SummaryFile),
        exists_file(SummaryFile)
    ->  uit('Documentation', DocumentationTxt),
        uit('Logical English syntax summary', SyntaxTxt),
        uit('The language reference: every construct — templates, rules, operators, aggregates, variables and types, dates, ontology, extensions — for looking things up as you write.', SyntaxBlurb),
        format(atom(SummaryUrl), '/docs/user/reference/language.~w', [Lang]),
        DocsSection = [h2(DocumentationTxt),
                       ul([li([a([href(SummaryUrl), target('_blank')], SyntaxTxt),
                               br([]),
                               small(SyntaxBlurb)])])]
    ;   DocsSection = []
    ),
    % Links to the other per-language landing pages.
    findall([' ', a(href(Url), OtherAutonym)], (
        language_examples_dir(L, _),
        L \== Lang,
        le_i18n:language_autonym(L, OtherAutonym),
        format(atom(Url), '/multilingual?lang=~w', [L])
    ), OtherLinkParts),
    append(OtherLinkParts, OtherLangLinks),
    uit('Edit and Query: ', EditAndQuery),
    uit('[New Document]', NewDocument),
    uit('expand all', ExpandAll),
    uit('collapse all', CollapseAll),
    uit('Other languages: ', OtherLangsTxt),
    uit('Logical English (in English)', BackTxt),
    append([
        [
            AuthCorner,
            h1(Title),
            p(small(['Build: ', BuildInfo])),
            ul([
                li([
                    b(EditAndQuery),
                    a(href('/editor/index.html'), NewDocument),
                    ' ',
                    span([id('le-folder-controls'), style('display:none;')], [
                        '(',
                        a([href('#'), id('le-expand-all')], ExpandAll),
                        ' · ',
                        a([href('#'), id('le-collapse-all')], CollapseAll),
                        ')'
                    ]),
                    ul(ExampleItems)
                ])
            ])
        ],
        DocsSection,
        [
            p([b(OtherLangsTxt) | OtherLangLinks]),
            p(a([href('/'), id('le-back-english')], BackTxt))
        ]
    ], Body),
    reply_html_page(
        [title(Title),
         script([src('/telemetry.js')], []),
         style('li.le-folder-item { list-style: none; } \c
                details.le-folder > summary { cursor: pointer; } \c
                .le-folder-blurb { color: #666; font-weight: normal; }'),
         script([type('text/javascript')], FolderScript),
         script([type('text/javascript')], PrefScript)],
        Body
    ).

%!  ui_lang_pref_script(+Lang:atom, -JS:atom) is det.
%
%   Client-side script for the /multilingual pages — the ONLY places that set
%   the UI-language preference (the editor's localStorage key plus the
%   le_ui_lang cookie the server-rendered /login page reads). When Lang is
%   non-empty (a per-language landing page) it stores Lang on load; in every
%   case it wires the back-to-English link to reset the preference to English
%   (the standard landing page itself never touches the preference). Same
%   conventions as landing_folders_script (verbatim script content: no "//"
%   comments, no "</" sequence).
ui_lang_pref_script(Lang, JS) :-
    (   Lang == ''
    ->  SetNow = ''
    ;   format(atom(SetNow), '  setLang("~w");~n', [Lang])
    ),
    format(atom(JS), '(function(){
  "use strict";
  function setLang(l){
    try { window.localStorage.setItem("le-ui-lang", l); } catch (e) {}
    document.cookie = "le_ui_lang=" + l + ";path=/;max-age=31536000;SameSite=Lax";
  }
~wfunction init(){
    var back = document.getElementById("le-back-english");
    if (back) back.addEventListener("click", function(){ setLang("en"); });
  }
  if (document.readyState === "loading") { document.addEventListener("DOMContentLoaded", init); }
  else { init(); }
})();', [SetNow]).

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

handle_test_services(Request) :-
    memberchk(path(Path), Request),
    atomic_list_concat(Parts, '/', Path),
    last(Parts, Name),
    http_read_json_dict(Request, ServiceRequest),
    le_services:stub_service(Name, ServiceRequest, Reply),
    reply_json_dict(Reply).

%!  handle_docs(+Request) is det.
%
%   Serves the repository's own user documentation, rendered cleanly (no repo
%   chrome), from the docs/ tree:
%   - a request for an EXISTING file under docs/ (an image, or a raw .md that
%     the viewer fetches) is served directly;
%   - a request for a doc NAME (e.g. /docs/user/tutorials/intro-to-le/intro-to-le, where
%     docs/user/tutorials/intro-to-le/intro-to-le.md exists) returns the Markdown viewer shell,
%     which fetches that same path + ".md" and renders it client-side.
%   The rendered page sits at the same path depth as its .md source, so the
%   document's relative image references resolve to the right files under docs/.
%   Path traversal outside docs/ is refused.
handle_docs(Request) :-
    member(path(Path), Request),
    atom_concat('/docs/', Rel0, Path),
    ( sub_atom(Rel0, _, _, 0, '/') -> atom_concat(Rel, '/', Rel0 ) ; Rel = Rel0 ),
    docs_dir(DocsDir),
    (   ( file_name_extension(Old, md, Rel) -> Ext = '.md' ; Old = Rel, Ext = '' ),
        doc_moved(Old, New)
    ->  format(atom(To), '/docs/~w~w', [New, Ext]),
        http_redirect(moved, To, Request)
    ;   Rel == search                % the documentation's search (docs-extras.js)
    ->  http_reply_file('web_extras/docsview/viewer.html', [mime_type(text/html)], Request)
    ;   \+ public_doc(Rel)
    ->  throw(http_reply(not_found(Path)))
    ;   safe_docs_path(DocsDir, Rel, AbsFile), exists_file(AbsFile)
    ->  http_reply_file(AbsFile, [unsafe(true)], Request)   % image, or raw .md; safe_docs_path already vetted it
    ;   atom_concat(Rel, '.md', RelMd),
        safe_docs_path(DocsDir, RelMd, AbsMd), exists_file(AbsMd)
    ->  http_reply_file('web_extras/docsview/viewer.html', [mime_type(text/html)], Request)
    ;   throw(http_reply(not_found(Path)))
    ).

docs_dir(Dir) :- absolute_file_name('docs', Dir, [file_type(directory), access(read)]).

%!  public_doc(+Rel:atom) is semidet.
%
%   Rel (a path under docs/) is a document the server publishes: everything
%   under docs/user/, the user documentation. docs/dev and docs/project (and
%   the private notes) are in the repository, not on the web.
public_doc(Rel) :-
    sub_atom(Rel, 0, _, _, 'user/').

%!  doc_moved(?Old:atom, ?New:atom) is nondet.
%
%   The documents' addresses before docs/ was reorganised
%   (docs/project/plans/NewDocumentationStructure.md): links to them redirect.
doc_moved(le_summary, 'user/reference/language').
doc_moved('le_summary.pt', 'user/reference/language.pt').
doc_moved(howToUse, 'user/guide/editor').
doc_moved('tutorial0/IntroToLE2', 'user/tutorials/intro-to-le/intro-to-le').
doc_moved('IntroducingLEViews', 'user/tutorials/views').
doc_moved('ProofGame', 'user/guide/proof-game').
doc_moved(warningsSummary, 'user/guide/warnings').
doc_moved('sCASP_on_LE', 'user/reference/scasp').
doc_moved(api, 'user/api/web-api').
doc_moved('user/guide/import-export', 'user/integrations/index').

%!  landing_doc_items(-Items:list) is det.
%
%   The landing page's Documentation list: the documents nav.json marks
%   `landing`, each with its blurb, in the UI language.
landing_doc_items(Items) :-
    (   doc_nav(Nav)
    ->  findall(li([a([href(Url), target('_blank')], Title), br([]), small(Blurb)]),
                ( member(Section, Nav.sections), member(Item, Section.items),
                  get_dict(landing, Item, true),
                  atom_string(Path, Item.path),
                  atom_concat('/docs/user/', Path, Url),
                  atom_string(T0, Item.title), uit(T0, Title),
                  atom_string(B0, Item.blurb), uit(B0, Blurb) ),
                Items)
    ;   Items = []
    ).

%!  doc_nav(-Nav:dict) is semidet.
%
%   docs/user/nav.json: the table of contents the Help menu, the landing page
%   and the documentation viewer are built from.
doc_nav(Nav) :-
    catch(( setup_call_cleanup(open('docs/user/nav.json', read, In, [encoding(utf8)]),
                               json_read_dict(In, Nav),
                               close(In)) ), _, fail).

%!  handle_executive(+Request) is det.
%
%   The minimalist, mobile-first "executive" entry point: pick an example
%   program, choose a scenario and query, and run it — no editing. Query
%   parameters (program, scenario, query) are read client-side from the URL.
handle_executive(Request) :-
    http_reply_file('web_extras/executive/index.html',
                    [mime_type(text/html), headers([cache_control('no-cache')])], Request).

% The requested relative path resolves to a file strictly inside DocsDir
% (rejects '..' escapes).
safe_docs_path(DocsDir, Rel, Abs) :-
    Rel \== '',
    catch(absolute_file_name(Rel, Abs, [relative_to(DocsDir)]), _, fail),
    atom_concat(DocsDir, '/', DocsPrefix),
    sub_atom(Abs, 0, _, _, DocsPrefix).

handle_source(Request) :-
    member(path(Path), Request),
    atom_concat('/source/', ExamplePath0, Path),
    %  An example of the main tree under a name it had before (example_alias/2).
    le_examples_dir(MainDir), atom_concat(MainDir, '/', MainPrefix),
    (   atom_concat(MainPrefix, Name0, ExamplePath0)
    ->  le_kbs:example_current_name(Name0, Name),
        atom_concat(MainPrefix, Name, ExamplePath)
    ;   ExamplePath = ExamplePath0
    ),
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
