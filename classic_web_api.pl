/** <module> Logical English Classic Web API
    
    This module provides a REST API for Logical English. It supports
    loading KBs, running queries, and interacting with the LE Assistant.
    It also serves the web-based editor.
*/

:- module(classic_web_api, [start_api_server/0, start_api_server/1]).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_client)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_files)).
:- use_module(library(http/http_host)).
:- use_module(library(http/html_write)).
:- use_module(le_kbs).
:- use_module(tokenizer).
:- use_module(le_grammar).
:- use_module(reasoner).
:- use_module(le_system_templates).
:- use_module(le_graph).
:- use_module(le_assistant).
:- use_module(dap_server).
:- use_module(llm/llm_client, [llm_list_models/1]).
:- use_module(llm/mcp, [handle_mcp/1, handle_rest_list_examples/1, handle_rest_query/1, handle_rest_verify/1]).

:- dynamic build_info/1.

:- http_handler(root(leapi), handle_leapi, [method(post)]).
:- http_handler(root(build_info), handle_build_info, [method(get)]).
:- http_handler(root(.), handle_landing_page, []).
:- http_handler(root(mcp), handle_mcp, []).
:- http_handler(root(list_examples), handle_rest_list_examples, [method(get)]).
:- http_handler(root(query), handle_rest_query, [method(post)]).
:- http_handler(root(verify), handle_rest_verify, [method(post)]).
:- http_handler(root(example_details), handle_rest_example_details, [method(post)]).
:- http_handler('/dap', dap_websocket_handler, []).
:- http_handler('/editor/', http_reply_from_files('editor', []), [prefix]).
:- http_handler('/editor', http_redirect(moved, '/editor/index.html'), []).

%!  start_api_server is det.
%!  start_api_server(+Port:integer) is det.
%
%   Starts the Logical English Web API server.
start_api_server :-
    start_api_server(3050).

start_api_server(Port) :-
    % assertz(le_kbs:do_log),
    load_build_info,
    http_server(http_dispatch, [port(Port), workers(10)]).

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
        ; Op == "getGameData" -> handle_get_game_data(Dict, Response)
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
        ; Op == "list_models" -> handle_list_models(Dict, Response)
        ; Op == "is_a_hierarchy" -> handle_is_a_hierarchy(Dict, Response)
        ; Op == "graph" -> handle_graph(Dict, Response)
        ; Response = _{error: "Unknown operation"}
    ).

handle_graph(Dict, Response) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
    ( (current_module(SM), current_predicate(SM:le_kb_module_fact/1), SM:le_kb_module_fact(KB)) -> true; KB = none),
    ( KB \== none ->
        le_graph:kb_graph(KB, Response)
    ; Response = _{error: "No KB loaded"}
    ).

% --- Landing Page ---

handle_landing_page(Request) :-
    http_parameters(Request, [run_tests(RunTests, [boolean, optional(true), default(false)])]),
    (   RunTests == true ->
        le_kbs:runTestsInDir('examples/moreExamples', Results),
        format_test_results(Results, TestHtml)
    ;   TestHtml = []
    ),
    landing_example_items('examples/moreExamples', ExampleItems),
    build_info(BuildInfo),
    reply_html_page(
        [title('Logical English 2.0')],
        [
            h1('Logical English 2.0'),
            p(small(['Build: ', BuildInfo])),
            ul([
                li([
                    b('Edit and Query: '),
                    a(href('/editor/index.html'), '[New Document]'),
                    ul(ExampleItems)
                ]),
                li(a(href('https://github.com/mcalejo/LogicalEnglish2'), 'GitHub Repository'))
            ]),
            h2('Test Suite'),
            form([action('/'), method('get')], [
                input([type(hidden), name(run_tests), value(true)]),
                input([type(submit), value('Run All Tests')])
            ]),
            div(TestHtml)
        ]
    ).

%!  landing_example_items(+Dir:atom, -Items:list) is det.
%
%   Builds HTML list items for all examples in Dir, grouping subdirectory
%   examples under an indented header.
landing_example_items(Dir, Items) :-
    directory_files(Dir, Files),
    findall(Base, (
        member(F, Files),
        sub_atom(F, _, _, 0, '.le'),
        \+ sub_atom(F, _, _, 0, '.le.tests'),
        file_name_extension(Base, le, F)
    ), Bases0),
    sort(Bases0, Bases),
    findall(li(a([href(Url)], Base)), (
        member(Base, Bases),
        format(atom(Url), '/editor/index.html?example=~w', [Base])
    ), DirectItems),
    findall(li([b([SubDir, '/']), ul(SubItems)]), (
        member(SubDir, Files),
        \+ sub_atom(SubDir, 0, 1, _, '.'),
        directory_file_path(Dir, SubDir, SubDirPath),
        exists_directory(SubDirPath),
        directory_files(SubDirPath, SubFiles),
        findall(SubBase, (
            member(SF, SubFiles),
            sub_atom(SF, _, _, 0, '.le'),
            \+ sub_atom(SF, _, _, 0, '.le.tests'),
            file_name_extension(SubBase, le, SF)
        ), SubBases0),
        sort(SubBases0, SubBases),
        findall(li(a([href(SubUrl)], SubBase)), (
            member(SubBase, SubBases),
            atomic_list_concat([SubDir, '/', SubBase], ExPath),
            format(atom(SubUrl), '/editor/index.html?example=~w', [ExPath])
        ), SubItems)
    ), SubDirItems),
    append(DirectItems, SubDirItems, Items).

format_test_results(Results, [h3('Test Results'), table([border(1), cellpadding(5)], [
    tr([th('File'), th('Pass'), th('Fail'), th('Error'), th('Status')])
    | TableRows
])]) :-
    maplist(result_to_row, Results, TableRows).

result_to_row(test_file(File, FileResults), tr([
    td(File),
    td(PassCount),
    td(FailCount),
    td(ErrCount),
    td(style(Color), Status)
])) :-
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
    atom_concat('examples/moreExamples/', FileName, Path0),
    ( exists_file(Path0) -> Path = Path0; atom_concat(Path0, '.le', PathLE), exists_file(PathLE) -> Path = PathLE; Path = Path0),
    ( exists_file(Path) -> read_file_to_string(Path, Doc, []), Response = _{document: Doc}; Response = _{answer: "File not found", details: Path, document: ""}).

handle_list_examples(_Dict, Response) :-
    list_examples_in_dir('examples/moreExamples/', '', Examples),
    Response = _{examples: Examples}.

%!  list_examples_in_dir(+Dir:atom, +Prefix:atom, -Examples:list) is det.
%
%   Collects example base names (with Prefix prepended) from Dir and its subdirectories.
%   Subdirectory examples are returned as "subdir/name".
list_examples_in_dir(Dir, Prefix, Examples) :-
    directory_files(Dir, Files),
    findall(ExPath, (
        member(F, Files),
        sub_atom(F, _, _, 0, '.le'),
        \+ sub_atom(F, _, _, 0, '.le.tests'),
        file_name_extension(Base, le, F),
        atom_concat(Prefix, Base, ExPath)
    ), DirectExamples),
    findall(SubExamples, (
        member(F, Files),
        \+ sub_atom(F, 0, 1, _, '.'),
        directory_file_path(Dir, F, SubDir),
        exists_directory(SubDir),
        atomic_list_concat([Prefix, F, '/'], SubPrefix),
        list_examples_in_dir(SubDir, SubPrefix, SubExamples)
    ), SubExamplesLists),
    append(SubExamplesLists, SubExamplesFlat),
    append(DirectExamples, SubExamplesFlat, Examples).

handle_list_models(_Dict, Response) :-
    llm_list_models(Rows),
    maplist(row_to_dict, Rows, Models),
    findall(P, (member(P, [openai, groq, anthropic, together, gemini]), catch(llm_client:api_key(P, _), _, fail)), ServerKeys),
    Response = _{models: Models, server_keys: ServerKeys}.

handle_is_a_hierarchy(Dict, Response) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
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
    load_le_text(Doc, KB),
    createSession(KB, SM),
    (   setScenarion(SM, Scenario) ->  
        ( query(SM, Query, _Instance, _Unknowns, Why) -> convert_why(Why, KB, JSONWhy), Response = _{answer: JSONWhy}; Response = _{answer: "No answer found"})
        ;   
        Response = _{error: "Scenario not found"}
    ).

handle_explain(Dict, Response) :-
    get_dict(document, Dict, Doc),
    get_dict(theQuery, Dict, Query),
    get_dict(scenario, Dict, Scenario),
    load_le_text(Doc, KB),
    createSession(KB, SM),
    ( setScenarion(SM, Scenario) -> findall(JSONWhy, (query(SM, Query, _Instance, _Unknowns, Why), convert_why(Why, KB, JSONWhy)), Results), Response = _{results: Results}; Response = _{error: "Scenario not found"}).

handle_load(Dict, Response) :-
    (   get_dict(le, Dict, Doc) ->  
        ( catch(le_kbs:load_text(Doc, KB), E1, (print_message(error, E1), fail)) -> Language = le; print_message(error, le_api_error(load, "le_kbs:load_text failed")), fail)
        ;   
        get_dict(file, Dict, File),
        atom_concat('examples/moreExamples/', File, Path0),
        ( exists_file(Path0) -> Path = Path0; atom_concat(Path0, '.le', PathLE), exists_file(PathLE) -> Path = PathLE; Path = Path0),
        (   sub_atom(Path, _, _, 0, '.le') ->  
                ( catch(le_kbs:load(Path, KB), E2, (print_message(error, E2), fail)) -> Language = le; print_message(error, le_api_error(load, "le_kbs:load failed")), fail)
            ; ( catch(load_prolog_file(Path, KB), E3, (print_message(error, E3), fail)) -> Language = prolog; print_message(error, le_api_error(load, "load_prolog_file failed")), fail)
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

handle_answering_query(Dict, Response) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
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
        ;   catch(run_answering_query(SM, Query, KB, Response), error(le_parse_error(Msg), _), Response = _{error: Msg})
        )
    ).

run_answering_query(SM, Query, KB, Response) :-
    print_message(informational, 'Answering query: ~w in session ~w' - [Query, SM]),
    findall(_{answer: AnswerStr, why: JSONWhy}, (
            query(SM, Query, Instance, _Us, Why),
            canonical_string(Instance, AnswerStr),
            convert_why(Why, KB, JSONWhy),
            print_message(informational, 'Found answer: ~w' - [AnswerStr])
        ), Results),
    (   Results \== [] ->  
        length(Results, Count),
        print_message(informational, 'Total answers found: ~w' - [Count]),
        Response = _{results: Results, result: "ok"}
        ;   
        % No answers, get negative explanation
        print_message(informational, 'No answers found, generating negative explanation'),
        (   query_explain(SM, Query, _Instance, _Unknowns, Why) -> 
                convert_why(Why, KB, JSONWhy),
                Response = _{results: [], why: JSONWhy, result: "ok"}
            ;   Response = _{results: [], error: "Explanation failed", result: "ok"}
        )
    ).

handle_get_game_data(Dict, Response) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
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
              ( KB \== none, KB:query_info(QueryName, Goal, _) -> Query = Goal ; Query = QueryName )
        ),
        (   nonvar(ErrorQuery) -> Response = _{error: ErrorQuery}
        ;   extract_rules_and_facts(KB, SM, Rules, ExtractedFacts),
            ( KB \== none, le_kbs:item_to_instance(KB, Query, QueryTokens) -> le_kbs:canonical_string(QueryTokens, QueryLE) ; term_string(Query, QueryLE) ),
            Response = _{gameData: _{rules: Rules, facts: ExtractedFacts, query: QueryLE}, result: "ok"}
        )
    ).

term_to_le(KB, Term, LE) :-
    ( KB \== none, le_kbs:item_to_instance(KB, Term, Tokens) -> le_kbs:canonical_string(Tokens, LE)
    ; term_string(Term, LE)
    ).

extract_rules_and_facts(KB, SM, Rules, Facts) :-
    findall(_{head: HeadLE, body: BodyLEs, start: Start, end: End}, (
        current_predicate(KB:F/N),
        \+ le_kbs:is_system_predicate(F/N),
        functor(Head, F, N),
        clause(KB:Head, Body, Ref),
        KB:le_source_info(Ref, Start, End, ID),
        \+ member(ID, [template, template_unknown, ontology, session_fact]),
        Body \== true,
        term_to_le(KB, Head, HeadLE),
        comma_list(Body, BodyList), 
        maplist(strip_le_at, BodyList, StrippedBodyList),
        flatten_and(StrippedBodyList, FlatBodyList),
        maplist(term_to_le(KB), FlatBodyList, BodyLEs)
    ), Rules),
    findall(_{fact: FactLE, start: Start, end: End}, (
        (   current_predicate(KB:F/N),
            \+ le_kbs:is_system_predicate(F/N),
            functor(Head, F, N),
            clause(KB:Head, true, Ref),
            KB:le_source_info(Ref, Start, End, ID),
            \+ member(ID, [template, template_unknown, ontology, session_fact])
        ;   SM \== none,
            current_predicate(SM:F/N),
            \+ le_kbs:is_system_predicate(F/N),
            functor(Head, F, N),
            clause(SM:Head, true, Ref),
            SM:le_source_info(Ref, Start, End, session_fact)
        ),
        term_to_le(KB, Head, FactLE)
    ), Facts).

comma_list((A, B), [A|T]) :- !, comma_list(B, T).
comma_list(A, [A]).

strip_le_at(le_at(Term, _, _), Stripped) :- !, strip_le_at(Term, Stripped).
strip_le_at(Term, Term).

flatten_and([], []).
flatten_and([and(A, B)|T], Flat) :- !, flatten_and([A, B|T], Flat).
flatten_and([H|T], [H|FlatT]) :- flatten_and(T, FlatT).

handle_load_facts_and_query(Dict, Response) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
    get_dict(facts, Dict, FactsStrList),
    print_message(informational, 'Loading facts into session ~w' - [SM]),
    forall(member(FStr, FactsStrList), (term_string(F, FStr), addSessionFact(SM, F))),
    (   get_dict(goal, Dict, GoalStr) ->  
        print_message(informational, 'Running goal: ~w' - [GoalStr]),
        read_term_from_atom(GoalStr, Goal, [variable_names(VarNames)]),
        ( SM:le_kb_module_fact(KB) -> true; KB = none),
        findall(Answer, (
            reasoner:i(Goal, SM, _Unknowns, Why),
            convert_why(Why, KB, JSONWhy),
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
    ( get_dict(facts, Dict, FactsStrList) -> maplist(term_string, Facts, FactsStrList); Facts = []),
    (   (current_module(Module), current_predicate(Module:le_my_kb/1)) -> SM = Module, SM:le_kb_module_fact(KB)
        ; current_module(Module) -> KB = Module, createSession(KB, SM)
        ; KB = none, createSession(none, SM)
    ),
    forall(member(F, Facts), addSessionFact(SM, F)),
    read_term_from_atom(QueryStr, Goal, [variable_names(VarNames)]),
    findall(Result, (
        reasoner:i(Goal, SM, Unknowns, Why),
        convert_why(Why, KB, JSONWhy),
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
    ( Results == [] -> Response = _{results: [_{result: "false"}]}; Response = _{results: Results}).

% --- Helpers ---

load_prolog_file(Path, Module) :-
    variant_sha1(Path, Hash),
    atom_concat(p, Hash, Module),
    ( current_module(Module) -> true; load_files(Module:Path, [])).

convert_why(success(_Goal, range(Start, End), LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "success", literal: LE, start: Start, end: End, children: JSONChildren}.
convert_why(success(_Goal, unknown(Start, End), LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "unknown", literal: LE, start: Start, end: End, children: JSONChildren}.
convert_why(success(_Goal, unknown, LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "unknown", literal: LE, children: JSONChildren}.


convert_why(success(_Goal, Ref, LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    (   KB \== none, KB:le_source_info(Ref, Start, End, _)
    ->  JSON = _{type: "success", literal: LE, start: Start, end: End, children: JSONChildren}
    ;   JSON = _{type: "success", literal: LE, children: JSONChildren}
    ).
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

get_source_info(Ref, KB, Source, Start, End) :-
    ( (KB \== none, KB:le_source_info(Ref, Start, End, _)) -> term_string(Ref, Source); term_string(Ref, Source), Start = 0, End = 0).

convert_binding(Name=Val, Name-JSONVal) :-
    ( (atom(Val) ; string(Val) ; number(Val)) -> JSONVal = Val; term_string(Val, JSONVal)).

convert_unknown(KB, Goal, _{goal: GoalStr, module: KBStr}) :-
    term_string(Goal, GoalStr),
    ( atom(KB) -> KBStr = KB; term_string(KB, KBStr)).

handle_get_prolog(Dict, Response) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
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
    (   is_interesting_term(Head)
    ->  ( Body == true -> Clause = Head; Clause = (Head :- Body)),
        !
    ).

is_interesting_term(Head) :-
    functor(Head, F, N),
    (   \+ le_kbs:is_system_predicate(F/N)
    ;   member(F/N, [le_kb/1, le_dict/1, ontology/1, scenario/2, query_info/3, le_expected/3])
    ).
