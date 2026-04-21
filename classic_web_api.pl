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
    http_server(http_dispatch, [port(Port)]).

handle_leapi(Request) :-
    http_read_json_dict(Request, Dict),
    (   validate_token(Dict)
    ->  get_dict(operation, Dict, Op),
        print_message(informational, 'LE API Request: ~w' - [Op]),
        (   catch(handle_operation(Dict, Response), E, (print_message(error, E), fail))
        ->  print_message(informational, 'LE API Response: Success (~w)' - [Op]),
            reply_json_dict(Response)
        ;   print_message(error, 'LE API Operation failed: ~w' - [Op]),
            reply_json_dict(_{error: "Operation failed or internal error"}, [status(500)])
        )
    ;   print_message(warning, 'LE API: Invalid token'),
        reply_json_dict(_{error: "Invalid token"}, [status(403)])
    ).

validate_token(Dict) :-
    get_dict(token, Dict, Token),
    Token == "myToken123".

handle_operation(Dict, Response) :-
    get_dict(operation, Dict, Op),
    (   Op == "examples" -> handle_examples(Dict, Response)
    ;   Op == "list_examples" -> handle_list_examples(Dict, Response)
    ;   Op == "answer" -> handle_answer(Dict, Response)
    ;   Op == "explain" -> handle_explain(Dict, Response)
    ;   Op == "load" -> handle_load(Dict, Response)
    ;   Op == "answeringQuery" -> handle_answering_query(Dict, Response)
    ;   Op == "loadFactsAndQuery" -> handle_load_facts_and_query(Dict, Response)
    ;   Op == "query" -> handle_query(Dict, Response)
    ;   Response = _{error: "Unknown operation"}
    ).

% --- Handlers ---

handle_examples(Dict, Response) :-
    get_dict(file, Dict, FileName),
    atom_concat('examples/moreExamples/', FileName, Path0),
    (   exists_file(Path0) -> Path = Path0
    ;   atom_concat(Path0, '.le', PathLE), exists_file(PathLE) -> Path = PathLE
    ;   Path = Path0 % will fail later
    ),
    (   exists_file(Path)
    ->  read_file_to_string(Path, Doc, []),
        Response = _{document: Doc}
    ;   Response = _{answer: "File not found", details: Path, document: ""}
    ).

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
    (   setScenarion(SM, Scenario)
    ->  (   query(SM, Query, _Instance, _Unknowns, Why)
        ->  convert_why(Why, KB, JSONWhy),
            Response = _{answer: JSONWhy}
        ;   Response = _{answer: "No answer found"}
        )
    ;   Response = _{error: "Scenario not found"}
    ).

handle_explain(Dict, Response) :-
    get_dict(document, Dict, Doc),
    get_dict(theQuery, Dict, Query),
    get_dict(scenario, Dict, Scenario),
    load_le_text(Doc, KB),
    createSession(KB, SM),
    (   setScenarion(SM, Scenario)
    ->  findall(JSONWhy, (query(SM, Query, _Instance, _Unknowns, Why), convert_why(Why, KB, JSONWhy)), Results),
        Response = _{results: Results}
    ;   Response = _{error: "Scenario not found"}
    ).

handle_load(Dict, Response) :-
    (   get_dict(le, Dict, Doc)
    ->  load_le_text(Doc, KB),
        Language = le
    ;   get_dict(file, Dict, File),
        atom_concat('examples/moreExamples/', File, Path0),
        (   exists_file(Path0) -> Path = Path0
        ;   atom_concat(Path0, '.le', PathLE), exists_file(PathLE) -> Path = PathLE
        ;   Path = Path0 % will fail later
        ),
        (   sub_atom(Path, _, _, 0, '.le')
        ->  le_kbs:load(Path, KB),
            Language = le
        ;   load_prolog_file(Path, KB),
            Language = prolog
        )
    ),
    createSession(KB, SM),
    get_kb_metadata(KB, Metadata),
    Response = Metadata.put(_{
        sessionModule: SM,
        language: Language,
        target: prolog
    }),
    print_message(informational, 'Loaded KB ~w into session ~w' - [KB, SM]).

handle_answering_query(Dict, Response) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
    get_dict(query, Dict, Query),
    print_message(informational, 'Answering query: ~w in session ~w' - [Query, SM]),
    (   get_dict(scenario, Dict, ScenarioStr)
    ->  (   (atom(ScenarioStr) ; string(ScenarioStr)), \+ sub_atom(ScenarioStr, _, _, _, '(')
        ->  atom_string(ScenarioName, ScenarioStr),
            print_message(informational, 'Setting scenario by name: ~w' - [ScenarioName]),
            setScenarion(SM, ScenarioName)
        ;   term_string(Scenario, ScenarioStr),
            clearSession(SM),
            (   is_list(Scenario)
            ->  forall(member(F, Scenario), addSessionFact(SM, F))
            ;   addSessionFact(SM, Scenario)
            )
        )
    ;   true
    ),
    (   query(SM, Query, Instance, _Unknowns, _Why)
    ->  term_string(Instance, InstanceStr),
        Response = _{answer: InstanceStr, result: "ok"}
    ;   Response = _{answer: "false", result: "ok"}
    ).

handle_load_facts_and_query(Dict, Response) :-
    get_dict(sessionModule, Dict, SMStr),
    atom_string(SM, SMStr),
    get_dict(facts, Dict, FactsStrList),
    print_message(informational, 'Loading facts into session ~w' - [SM]),
    forall(member(FStr, FactsStrList), (term_string(F, FStr), addSessionFact(SM, F))),
    (   get_dict(goal, Dict, GoalStr)
    ->  print_message(informational, 'Running goal: ~w' - [GoalStr]),
        read_term_from_atom(GoalStr, Goal, [variable_names(VarNames)]),
        (SM:le_my_kb(KB) -> true ; KB = none),
        findall(Answer, (
            reasoner:i(Goal, SM, _Unknowns, Why),
            convert_why(Why, KB, JSONWhy),
            maplist(convert_binding, VarNames, Bindings),
            dict_create(BindingsDict, bindings, Bindings),
            Answer = _{bindings: BindingsDict, explanation: JSONWhy}
        ), Answers),
        (   Answers \== []
        ->  Response = _{
                facts: FactsStrList,
                goal: GoalStr,
                answers: Answers,
                result: "true"
            }
        ;   Response = _{result: "false"}
        )
    ;   Response = _{facts: FactsStrList, result: "ok"}
    ).

handle_query(Dict, Response) :-
    get_dict(theQuery, Dict, QueryStr),
    get_dict(module, Dict, ModuleStr),
    atom_string(Module, ModuleStr),
    (   get_dict(facts, Dict, FactsStrList)
    ->  maplist(term_string, Facts, FactsStrList)
    ;   Facts = []
    ),
    (   current_module(Module), current_predicate(Module:le_my_kb/1)
    ->  SM = Module, SM:le_my_kb(KB)
    ;   current_module(Module)
    ->  KB = Module, createSession(KB, SM)
    ;   KB = none, createSession(none, SM)
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
    (   Results == []
    ->  Response = _{results: [_{result: "false"}]}
    ;   Response = _{results: Results}
    ).

% --- Helpers ---

load_le_text(Text, KB) :-
    tmp_file_stream(utf8, Path, Stream),
    write(Stream, Text),
    close(Stream),
    le_kbs:load(Path, KB),
    delete_file(Path).

load_prolog_file(Path, Module) :-
    variant_sha1(Path, Hash),
    atom_concat(p, Hash, Module),
    (   current_module(Module)
    ->  true
    ;   load_files(Module:Path, [])
    ).

convert_why(success(Goal, Ref, Children), KB, JSON) :- !,
    term_string(Goal, GoalStr),
    maplist(convert_why_child(KB), Children, JSONChildren),
    get_source_info(Ref, KB, Source, Start, End),
    JSON = _{type: "success", literal: GoalStr, source: Source, start: Start, end: End, children: JSONChildren}.
convert_why(failure(Goal, Children), KB, JSON) :- !,
    term_string(Goal, GoalStr),
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "failure", literal: GoalStr, children: JSONChildren}.
convert_why(Whys, KB, JSON) :-
    is_list(Whys), !,
    maplist(convert_why_child(KB), Whys, JSON).
convert_why(Other, _, JSON) :-
    term_string(Other, JSON).

convert_why_child(KB, Child, JSON) :-
    convert_why(Child, KB, JSON).

get_source_info(Ref, KB, Source, Start, End) :-
    (   KB \== none, KB:le_source(Ref, Start, End)
    ->  term_string(Ref, Source)
    ;   term_string(Ref, Source), Start = 0, End = 0
    ).

convert_binding(Name=Val, Name-JSONVal) :-
    (   (atom(Val) ; string(Val) ; number(Val))
    ->  JSONVal = Val
    ;   term_string(Val, JSONVal)
    ).

convert_unknown(KB, Goal, _{goal: GoalStr, module: KBStr}) :-
    term_string(Goal, GoalStr),
    (   atom(KB) -> KBStr = KB
    ;   term_string(KB, KBStr)
    ).
