:- module(classic_web_api, [start_api_server/0, start_api_server/1]).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_client)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_files)).
:- use_module(library(http/http_host)).
:- use_module(le_kbs).
:- use_module(tokenizer).
:- use_module(le_grammar).
:- use_module(reasoner).
:- use_module(le_system_templates).

:- http_handler(root(leapi), handle_leapi, [method(post)]).
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
    http_server(http_dispatch, [port(Port)]).

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
        ; Op == "loadFactsAndQuery" -> handle_load_facts_and_query(Dict, Response)
        ; Op == "query" -> handle_query(Dict, Response)
        ; Response = _{error: "Unknown operation"}
    ).

% --- Handlers ---

handle_examples(Dict, Response) :-
    get_dict(file, Dict, FileName),
    atom_concat('examples/moreExamples/', FileName, Path0),
    ( exists_file(Path0) -> Path = Path0; atom_concat(Path0, '.le', PathLE), exists_file(PathLE) -> Path = PathLE; Path = Path0),
    ( exists_file(Path) -> read_file_to_string(Path, Doc, []), Response = _{document: Doc}; Response = _{answer: "File not found", details: Path, document: ""}).

handle_list_examples(_Dict, Response) :-
    directory_files('examples/moreExamples/', Files),
    findall(Base, (
        member(F, Files),
        sub_atom(F, _, _, 0, '.le'),
        file_name_extension(Base, le, F)
    ), Examples),
    Response = _{examples: Examples}.

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
        findall(_{severity: Sev, type: Type, message: Msg, start: Start, end: End}, KB:le_issue(Sev, Type, Msg, Start, End), Issues),
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
    ( SM:le_my_kb(KB) -> true; KB = none),
    
    % Handle Scenario
    (   get_dict(customScenario, Dict, CustomScenario), CustomScenario \== null ->
            clearSession(SM),
            ( KB \== none -> parse_custom_facts(KB, CustomScenario, Facts), forall(member(F, Facts), addSessionFact(SM, F)); true )
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

    % Handle Query
    (   get_dict(customQuery, Dict, CustomQuery), CustomQuery \== null ->
            ( KB \== none, parse_custom_query(KB, CustomQuery, Goal) -> Query = Goal; Query = CustomQuery )
        ; get_dict(query, Dict, Query)
    ),

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
        (   catch(query_explain(SM, Query, _Instance, _Unknowns, Why), E, (print_message(error, E), fail)) -> 
                convert_why(Why, KB, JSONWhy),
                Response = _{results: [], why: JSONWhy, result: "ok"}
            ;   Response = _{results: [], error: "Explanation failed", result: "ok"}
        )
    ).

handle_load_facts_and_query(Dict, Response) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
    get_dict(facts, Dict, FactsStrList),
    print_message(informational, 'Loading facts into session ~w' - [SM]),
    forall(member(FStr, FactsStrList), (term_string(F, FStr), addSessionFact(SM, F))),
    (   get_dict(goal, Dict, GoalStr) ->  
        print_message(informational, 'Running goal: ~w' - [GoalStr]),
        read_term_from_atom(GoalStr, Goal, [variable_names(VarNames)]),
        ( SM:le_my_kb(KB) -> true; KB = none),
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
    (   (current_module(Module), current_predicate(Module:le_my_kb/1)) -> SM = Module, SM:le_my_kb(KB)
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
convert_why(success(_Goal, Ref, LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    (   KB \== none, KB:le_source(Ref, Start, End)
    ->  JSON = _{type: "success", literal: LE, start: Start, end: End, children: JSONChildren}
    ;   JSON = _{type: "success", literal: LE, children: JSONChildren}
    ).
convert_why(failure(_Goal, LE, Children), KB, JSON) :- !,
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
    ( (KB \== none, KB:le_source(Ref, Start, End)) -> term_string(Ref, Source); term_string(Ref, Source), Start = 0, End = 0).

convert_binding(Name=Val, Name-JSONVal) :-
    ( (atom(Val) ; string(Val) ; number(Val)) -> JSONVal = Val; term_string(Val, JSONVal)).

convert_unknown(KB, Goal, _{goal: GoalStr, module: KBStr}) :-
    term_string(Goal, GoalStr),
    ( atom(KB) -> KBStr = KB; term_string(KB, KBStr)).
