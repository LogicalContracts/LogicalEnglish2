/** <module> Logical English MCP Server
    
    This module implements the Model Context Protocol (MCP) for Logical English.
    It allows LLMs to interact with Logical English KBs through tools,
    prompts, and resources. It supports both STDIO (untested) and HTTP transports.
*/

:- module(mcp, [handle_mcp/1, handle_rest_list_examples/1, handle_rest_query/1, handle_rest_verify/1, handle_rest_example_details/1, handle_mcp_stdio/0]).

:- use_module(library(http/http_json)).
:- use_module(library(http/http_dispatch)).
:- use_module('../le_kbs').
:- use_module('../tokenizer').
:- use_module('../le_grammar').
:- use_module('../reasoner').
:- use_module('../le_system_templates').

:- dynamic mcp_only_query_verify/0.
% mcp_only_query_verify. % Uncomment to enable the flag

% --- STDIO Handler ---

handle_mcp_stdio :-
    set_stream(user_input, encoding(utf8)),
    set_stream(user_output, encoding(utf8)),
    loop_mcp_stdio.

loop_mcp_stdio :-
    catch(json_read_dict(user_input, Dict), _, Dict = end_of_file),
    (   Dict == end_of_file -> true
    ;   (   get_dict(method, Dict, Method) ->
            (   get_dict(id, Dict, ID) ->
                (   handle_method(Method, Dict, Response) ->
                    json_write_dict(user_output, Response, [width(0)]),
                    nl(user_output),
                    flush_output(user_output)
                ;   json_write_dict(user_output, _{jsonrpc: "2.0", id: ID, error: _{code: -32601, message: "Method not found"}}, [width(0)]),
                    nl(user_output),
                    flush_output(user_output)
                )
            ;   % Notification
                (handle_method(Method, Dict, _) -> true ; true)
            )
        ;   true
        ),
        loop_mcp_stdio
    ).

% --- HTTP Handler ---

handle_mcp(Request) :-
    (   member(method(post), Request) ->
        http_read_json_dict(Request, Dict),
        % Log request for debugging
        ( get_dict(method, Dict, Method) -> true ; Method = unknown ),
        ( Method \== 'tools/call' -> format(user_error, "MCP Request: ~w~n", [Method]) ; 
          get_dict(params, Dict, Params), get_dict(name, Params, ToolName0),
          (   sub_atom(ToolName0, Before, _, _, '<')
          ->  sub_atom(ToolName0, 0, Before, _, ToolName),
              format(user_error, "MCP Request: tools/call ~w (cleaned)~n", [ToolName])
          ;   ToolName = ToolName0,
              format(user_error, "MCP Request: tools/call ~w~n", [ToolName])
          )
        ),
        (   get_dict(method, Dict, Method) ->
            (   get_dict(id, Dict, ID) ->
                (   handle_method(Method, Dict, Response) ->
                    % format(user_error, "MCP Response: ~w~n", [Response]),
                    reply_json_dict(Response)
                ;   format(user_error, "MCP Method not found: ~w~n", [Method]),
                    reply_json_dict(_{jsonrpc: "2.0", id: ID, error: _{code: -32601, message: "Method not found"}}, [status(404)])
                )
            ;   % Notification
                (handle_method(Method, Dict, _) -> true ; true),
                reply_json_dict(_{result: "ok"})
            )
        ;   reply_json_dict(_{jsonrpc: "2.0", error: _{code: -32600, message: "Invalid Request"}}, [status(400)])
        )
    ;   member(method(get), Request) ->
        % mcp-remote or other clients might try GET for SSE
        reply_json_dict(_{error: "SSE not implemented, use POST JSON-RPC"}, [status(405)])
    ;   reply_json_dict(_{error: "Method not allowed"}, [status(405)])
    ).

% Helper to match method names as either strings or atoms
match_method(Target, Method) :-
    (   string(Method) -> atom_string(Target, Method)
    ;   Target == Method
    ).

handle_method(Method, Dict, Response) :-
    match_method('initialize', Method), !,
    get_dict(id, Dict, ID),
    Response = _{
        jsonrpc: "2.0",
        id: ID,
        result: _{
            protocolVersion: "2024-11-05",
            capabilities: _{
                tools: _{},
                prompts: _{},
                resources: _{}
            },
            serverInfo: _{
                name: "Logical English MCP Server",
                version: "1.0.0"
            }
        }
    }.

handle_method(Method, Dict, Response) :-
    match_method('resources/list', Method), !,
    get_dict(id, Dict, ID),
    Response = _{
        jsonrpc: "2.0",
        id: ID,
        result: _{
            resources: [
                _{
                    uri: "le://docs/syntax",
                    name: "Logical English Syntax Summary",
                    mimeType: "text/markdown",
                    description: "A summary of the Logical English language syntax and rules"
                }
            ]
        }
    }.

handle_method(Method, Dict, Response) :-
    match_method('resources/read', Method), !,
    get_dict(id, Dict, ID),
    Params = Dict.get(params, _{}),
    URI = Params.get(uri, ""),
    (   URI == "le://docs/syntax" ->
        read_file_to_string('docs/le_syntax.md', Text, []),
        Response = _{
            jsonrpc: "2.0",
            id: ID,
            result: _{
                contents: [
                    _{
                        uri: URI,
                        mimeType: "text/markdown",
                        text: Text
                    }
                ]
            }
        }
    ;   fail
    ).

handle_method(Method, Dict, Response) :-
    match_method('prompts/list', Method), !,
    get_dict(id, Dict, ID),
    Response = _{
        jsonrpc: "2.0",
        id: ID,
        result: _{
            prompts: [
                _{
                    name: "use_logical_english",
                    description: "Set up the LLM to work with a specific Logical English program",
                    arguments: [
                        _{
                            name: "example_name",
                            description: "The name of the LE program to use (e.g., 'citizenship')",
                            required: true
                        }
                    ]
                },
                _{
                    name: "massage_query",
                    description: "Help massage a user's natural language question into a valid Logical English query based on available templates",
                    arguments: [
                        _{
                            name: "user_question",
                            description: "The question as asked by the user",
                            required: true
                        },
                        _{
                            name: "templates",
                            description: "Available Logical English templates for the program",
                            required: true
                        }
                    ]
                },
                _{
                    name: "massage_facts",
                    description: "Help massage a sequence of natural language facts into valid Logical English template instances based on available templates",
                    arguments: [
                        _{
                            name: "user_facts",
                            description: "The facts as described by the user in natural language",
                            required: true
                        },
                        _{
                            name: "templates",
                            description: "Available Logical English templates for the program",
                            required: true
                        }
                    ]
                }
            ]
        }
    }.

handle_method(Method, Dict, Response) :-
    match_method('prompts/get', Method), !,
    get_dict(id, Dict, ID),
    Params = Dict.get(params, _{}),
    PromptName = Params.get(name, ""),
    Args = Params.get(arguments, _{}),
    (   PromptName == "use_logical_english" ->
        ExampleName = Args.get(example_name, ""),
        format(string(PromptText), 
               "You are an expert in Logical English. You are working with the program '~w'. ~n~nFollow these steps for every user request:~n1. Call 'get_example_details' with example_name: \"~w\" to understand the available templates and queries.~n2. If the user provides facts in natural language, use your internal reasoning to rewrite them into valid Logical English facts that match the templates EXACTLY. Each fact must end with a period.~n3. Rewrite the user's question into a single Logical English query that matches one of the templates exactly. Do not add a period.~n4. Call the 'query' tool with the massaged facts and query.~n5. Explain the results to the user in natural language, using the provided explanation tree.~n~nRead the resource 'le://docs/syntax' if you need a refresher on Logical English syntax.", 
               [ExampleName, ExampleName]),
        Response = _{
            jsonrpc: "2.0",
            id: ID,
            result: _{
                description: "Set up LE expert persona",
                messages: [
                    _{
                        role: "user",
                        content: _{
                            type: "text",
                            text: PromptText
                        }
                    }
                ]
            }
        }
    ;   PromptName == "massage_query" ->
        UserQuestion = Args.get(user_question, ""),
        Templates = Args.get(templates, ""),
        format(string(PromptText), 
               "The user wants to ask: \"~w\"~n~nAvailable Logical English templates are:~n~w~n~nYour task is to rewrite the user's question into a single Logical English query that matches one of the templates exactly. ~n- Use variables (starting with an uppercase letter) for unknown values.~n- Do not add a period at the end.~n- Return ONLY the massaged query text.", 
               [UserQuestion, Templates]),
        Response = _{
            jsonrpc: "2.0",
            id: ID,
            result: _{
                description: "Massage user question into LE query",
                messages: [
                    _{
                        role: "user",
                        content: _{
                            type: "text",
                            text: PromptText
                        }
                    }
                ]
            }
        }
    ;   PromptName == "massage_facts" ->
        UserFacts = Args.get(user_facts, ""),
        Templates = Args.get(templates, ""),
        format(string(PromptText), 
               "The user provides these facts: \"~w\"~n~nAvailable Logical English templates are:~n~w~n~nYour task is to rewrite the user's facts into a sequence of Logical English facts, each matching one of the templates exactly. ~n- Each fact must end with a period.~n- Use specific values from the user's input.~n- Return ONLY the massaged facts text, one per line.", 
               [UserFacts, Templates]),
        Response = _{
            jsonrpc: "2.0",
            id: ID,
            result: _{
                description: "Massage user facts into LE facts",
                messages: [
                    _{
                        role: "user",
                        content: _{
                            type: "text",
                            text: PromptText
                        }
                    }
                ]
            }
        }
    ;   fail
    ).

handle_method(Method, Dict, Response) :-
    match_method('tools/list', Method), !,
    get_dict(id, Dict, ID),
    AllTools = [
        _{
            name: "list_examples",
            description: "List Logical English program example names and their summaries",
            inputSchema: _{
                type: "object",
                properties: _{}
            }
        },
        _{
            name: "get_example_details",
            description: "Get the full text and metadata (predicates, queries, scenarios) of a specific example",
            inputSchema: _{
                type: "object",
                properties: _{
                    example_name: _{ type: "string", description: "Name of the example program" }
                },
                required: ["example_name"]
            }
        },
        _{
            name: "query",
            description: "Execute a query. MANDATORY: You MUST call get_example_details first to get the correct templates. Your 'facts' and 'query' strings MUST match those templates EXACTLY, word-for-word, or the query will fail. Do not paraphrase or hallucinate templates.",
            inputSchema: _{
                type: "object",
                properties: _{
                    example_name: _{ type: "string", description: "Name of the example program" },
                    program_text: _{ type: "string", description: "Logical English program text" },
                    scenario_name: _{ type: "string", description: "Name of a scenario defined in the program" },
                    facts: _{ type: "string", description: "Additional Logical English facts (MUST match templates exactly)" },
                    query: _{ type: "string", description: "The query to execute (MUST match a template exactly)" }
                },
                required: ["query"]
            }
        },
        _{
            name: "verify",
            description: "Parse and verify a Logical English program, returning all issues found",
            inputSchema: _{
                type: "object",
                properties: _{
                    program_text: _{ type: "string", description: "Logical English program text" }
                },
                required: ["program_text"]
            }
        }
    ],
    (   mcp_only_query_verify
    ->  include(mcp:is_query_or_verify, AllTools, Tools)
    ;   Tools = AllTools
    ),
    Response = _{
        jsonrpc: "2.0",
        id: ID,
        result: _{
            tools: Tools
        }
    }.

handle_method(Method, Dict, Response) :-
    match_method('tools/call', Method), !,
    get_dict(id, Dict, ID),
    Params = Dict.get(params, _{}),
    ToolName0 = Params.get(name, ""),
    % Clean tool name from potential LLM hallucinations like <|channel|>commentary
    (   sub_atom(ToolName0, Before, _, _, '<')
    ->  sub_atom(ToolName0, 0, Before, _, ToolName)
    ;   ToolName = ToolName0
    ),
    Args = Params.get(arguments, _{}),
    (   catch(call_tool(ToolName, Args, ToolResult), E, (term_string(E, ErrorMsg), ToolResult = _{error: ErrorMsg})) ->
        % Log summary of result
        log_tool_result(ToolName, ToolResult),
        (   get_dict(error, ToolResult, Error) ->
            Response = _{
                jsonrpc: "2.0",
                id: ID,
                result: _{
                    content: [_{type: "text", text: Error}],
                    isError: true
                }
            }
        ;   with_output_to(string(TextResult), json_write_dict(current_output, ToolResult, [width(0)])),
            Response = _{
                jsonrpc: "2.0",
                id: ID,
                result: _{
                    content: [_{type: "text", text: TextResult}]
                }
            }
        )
    ;   Response = _{
            jsonrpc: "2.0",
            id: ID,
            error: _{code: -32603, message: "Internal error during tool execution"}
        }
    ).

handle_method(Method, _Dict, _Response) :-
    match_method(initialized, Method), !, fail. % Notification, no response

% --- REST Handlers for ChatGPT Actions ---

handle_rest_list_examples(_Request) :-
    call_tool("list_examples", _{}, Result),
    reply_json_dict(Result).

handle_rest_query(Request) :-
    http_read_json_dict(Request, Args),
    call_tool("query", Args, Result),
    reply_json_dict(Result).

handle_rest_verify(Request) :-
    http_read_json_dict(Request, Args),
    call_tool("verify", Args, Result),
    reply_json_dict(Result).

handle_rest_example_details(Request) :-
    http_read_json_dict(Request, Args),
    call_tool("get_example_details", Args, Result),
    reply_json_dict(Result).

% --- Tool Implementations ---

examples_dir(AbsDir) :-
    working_directory(CWD, CWD),
    % Remove trailing slash from CWD if present
    ( sub_atom(CWD, _, 1, 0, '/') -> sub_atom(CWD, 0, _, 1, CWD0) ; CWD0 = CWD ),
    le_examples_dir(ExDir),
    format(atom(AbsDir), "~w/~w/", [CWD0, ExDir]).

call_tool("list_examples", _Args, Result) :-
    examples_dir(Dir),
    list_examples_with_summaries(Dir, '', Examples),
    Result = _{examples: Examples}.

call_tool("get_example_details", Args, Result) :-
    get_dict(example_name, Args, ExampleName),
    examples_dir(Dir),
    atom_concat(Dir, ExampleName, Path0),
    (exists_file(Path0) -> Path = Path0; atom_concat(Path0, '.le', Path), exists_file(Path)),
    le_kbs:load(Path, KB),
    le_kbs:get_kb_metadata(KB, Metadata),
    ( current_predicate(KB:scenario/2) -> findall(_{name: Name}, KB:scenario(Name, _), Scenarios); Scenarios = []),
    Result = Metadata.put(_{scenarios: Scenarios}).

call_tool("query", Args, Result) :-
    get_dict(query, Args, Query),
    ( get_dict(example_name, Args, ExampleName) -> true ; ExampleName = "" ),
    ( get_dict(program_text, Args, ProgramText) -> true ; ProgramText = "" ),
    ( get_dict(scenario_name, Args, ScenarioName) -> true ; ScenarioName = "" ),
    ( get_dict(facts, Args, Facts) -> true ; Facts = "" ),
    (   ExampleName \== "" ->
        examples_dir(Dir),
        atom_concat(Dir, ExampleName, Path0),
        (exists_file(Path0) -> Path = Path0; atom_concat(Path0, '.le', Path), exists_file(Path)),
        le_kbs:load(Path, KB)
    ;   ProgramText \== "" ->
        le_kbs:load_text(ProgramText, KB)
    ;   KB = none
    ),
    le_kbs:createSession(KB, SM),
    (   (ScenarioName \== "", ScenarioName \== null) ->
        ( atom_string(ScenarioAtom, ScenarioName), le_kbs:setScenarion(SM, ScenarioAtom) -> true ; true )
    ;   true
    ),
    (   (Facts \== "", Facts \== null) ->
        catch(le_kbs:parse_custom_facts(KB, Facts, FactTerms), error(le_parse_error(Msg), _), ErrorFacts = Msg),
        ( var(ErrorFacts) -> forall(member(F, FactTerms), le_kbs:addSessionFact(SM, F)) ; true )
    ;   true
    ),
    (   nonvar(ErrorFacts) -> Result = _{error: ErrorFacts}
    ;   catch(run_query(SM, Query, KB, Result), error(le_parse_error(Msg), _), Result = _{error: Msg})
    ).

call_tool("verify", Args, Result) :-
    get_dict(program_text, Args, ProgramText),
    le_kbs:load_text(ProgramText, KB),
    findall(_{severity: Sev, type: Type, message: Msg, fix: Fix, start: Start, end: End},
            KB:le_issue(Sev, Type, Msg, Fix, Start, End),
            Issues),
    % Run embedded tests if any
    ( current_predicate(KB:le_expected/3) -> 
        findall(test(Q, S, A), KB:le_expected(Q, S, A), Tests),
        maplist(le_kbs:run_one_test(KB), Tests, TestResults),
        maplist(convert_test_result, TestResults, JSONTestResults)
    ; JSONTestResults = []
    ),
    Result = _{issues: Issues, test_results: JSONTestResults}.

call_tool(ToolName, _Args, Result) :-
    format(user_error, "MCP Error: Unknown tool called: ~w~n", [ToolName]),
    format(string(Msg), "Unknown tool: ~w. Available tools are: query, verify.", [ToolName]),
    Result = _{error: Msg}.

%!  list_examples_with_summaries(+Dir:atom, +Prefix:atom, -Examples:list) is det.
%
%   Collects example dicts (name, summary) from Dir and its subdirectories.
%   Subdirectory examples have names of the form "subdir/name".
list_examples_with_summaries(Dir, Prefix, Examples) :-
    directory_files(Dir, Files),
    findall(_{name: ExPath, summary: Summary}, (
        member(F, Files),
        sub_atom(F, _, _, 0, '.le'),
        \+ sub_atom(F, _, _, 0, '.le.tests'),
        file_name_extension(Base, le, F),
        atom_concat(Prefix, Base, ExPath),
        directory_file_path(Dir, F, Path),
        ( catch(le_kbs:load(Path, KB), _, fail) ->
            le_kbs:kbSummary(KB, Summary)
        ; Summary = "Failed to load summary"
        )
    ), DirectExamples),
    findall(SubExamples, (
        member(F, Files),
        \+ sub_atom(F, 0, 1, _, '.'),
        directory_file_path(Dir, F, SubDir),
        exists_directory(SubDir),
        atomic_list_concat([Prefix, F, '/'], SubPrefix),
        list_examples_with_summaries(SubDir, SubPrefix, SubExamples)
    ), SubExamplesLists),
    append(SubExamplesLists, SubExamplesFlat),
    append(DirectExamples, SubExamplesFlat, Examples).

run_query(SM, QueryStr, KB, Result) :-
    ( atom_string(QueryAtom, QueryStr), KB \== none, KB:query_info(QueryAtom, Goal, _) -> Query = Goal ; Query = QueryStr ),
    findall(_{answer: AnswerStr, explanation: JSONWhy}, (
        le_kbs:query(SM, Query, Instance, _, Why),
        le_kbs:canonical_string(Instance, AnswerStr),
        convert_why(Why, KB, JSONWhy)
    ), Results),
    (   Results \== [] ->
        Result = _{results: Results}
    ;   % Try to get negative explanation
        (   le_kbs:query_explain(SM, Query, _, _, Why) ->
            convert_why(Why, KB, JSONWhy),
            Result = _{results: [], explanation: JSONWhy}
        ;   Result = _{results: [], error: "No answer and no explanation found"}
        )
    ).

% --- Helpers ---

convert_why(success(_Goal, range(Start, End), LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "success", literal: LE, start: Start, end: End, children: JSONChildren}.
convert_why(success(_Goal, _Ref, LE, Children), KB, JSON) :- !,
    maplist(convert_why_child(KB), Children, JSONChildren),
    JSON = _{type: "success", literal: LE, children: JSONChildren}.
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

convert_test_result(pass(Q, S), _{status: "pass", query: Q, scenario: S}).
convert_test_result(fail(Q, S, E, A), _{status: "fail", query: Q, scenario: S, expected: E, actual: A}).
convert_test_result(error(Q, S, Msg), _{status: "error", query: Q, scenario: S, message: Msg}).

% --- MCP Helpers ---

is_query_or_verify(Tool) :-
    member(Tool.name, ["query", "verify"]).

log_tool_result("verify", Result) :- !,
    Issues = Result.get(issues, []),
    Tests = Result.get(test_results, []),
    length(Issues, NI),
    length(Tests, NT),
    include(mcp:is_error, Issues, Errors),
    length(Errors, NE),
    include(mcp:is_fail, Tests, Fails),
    length(Fails, NF),
    format(user_error, "MCP Result: verify -> ~w issues (~w errors), ~w tests (~w failed)~n", [NI, NE, NT, NF]).
log_tool_result("query", Result) :- !,
    (   get_dict(results, Result, Answers)
    ->  length(Answers, N),
        format(user_error, "MCP Result: query -> ~w answers~n", [N])
    ;   get_dict(error, Result, Msg)
    ->  format(user_error, "MCP Result: query -> Error: ~w~n", [Msg])
    ;   format(user_error, "MCP Result: query -> No answers~n", [])
    ).
log_tool_result(Tool, _) :-
    format(user_error, "MCP Result: ~w completed~n", [Tool]).

is_error(Issue) :- Issue.get(severity) == "error".
is_fail(Test) :- Test.get(status) == "fail".
