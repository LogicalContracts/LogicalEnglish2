:- module(mcp, [handle_mcp/1, handle_rest_list_examples/1, handle_rest_query/1, handle_rest_verify/1, handle_mcp_stdio/0]).

:- use_module(library(http/http_json)).
:- use_module(library(http/http_dispatch)).
:- use_module('../le_kbs').
:- use_module('../tokenizer').
:- use_module('../le_grammar').
:- use_module('../reasoner').
:- use_module('../le_system_templates').

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
        format(user_error, "MCP Request: ~w~n", [Dict]),
        (   get_dict(method, Dict, Method) ->
            (   get_dict(id, Dict, ID) ->
                (   handle_method(Method, Dict, Response) ->
                    format(user_error, "MCP Response: ~w~n", [Response]),
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
    Response = _{
        jsonrpc: "2.0",
        id: ID,
        result: _{
            tools: [
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
            ]
        }
    }.

handle_method(Method, Dict, Response) :-
    match_method('tools/call', Method), !,
    get_dict(id, Dict, ID),
    Params = Dict.get(params, _{}),
    ToolName = Params.get(name, ""),
    Args = Params.get(arguments, _{}),
    (   catch(call_tool(ToolName, Args, ToolResult), E, (term_string(E, ErrorMsg), ToolResult = _{error: ErrorMsg})) ->
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

call_tool("list_examples", _Args, Result) :-
    directory_files('examples/moreExamples/', Files),
    findall(_{name: Base, summary: Summary}, (
        member(F, Files),
        sub_atom(F, _, _, 0, '.le'),
        file_name_extension(Base, le, F),
        directory_file_path('examples/moreExamples/', F, Path),
        ( catch(le_kbs:load(Path, KB), _, fail) ->
            le_kbs:kbSummary(KB, Summary)
        ; Summary = "Failed to load summary"
        )
    ), Examples),
    Result = _{examples: Examples}.

call_tool("get_example_details", Args, Result) :-
    ExampleName = Args.get(example_name, ""),
    atom_concat('examples/moreExamples/', ExampleName, Path0),
    (exists_file(Path0) -> Path = Path0; atom_concat(Path0, '.le', Path), exists_file(Path)),
    le_kbs:load(Path, KB),
    le_kbs:get_kb_metadata(KB, Metadata),
    ( current_predicate(KB:scenario/2) -> findall(_{name: Name}, KB:scenario(Name, _), Scenarios); Scenarios = []),
    Result = Metadata.put(_{examples: Scenarios}).

call_tool("query", Args, Result) :-
    Query = Args.get(query, ""),
    ExampleName = Args.get(example_name, ""),
    ProgramText = Args.get(program_text, ""),
    ScenarioName = Args.get(scenario_name, ""),
    Facts = Args.get(facts, ""),
    (   ExampleName \== "" ->
        atom_concat('examples/moreExamples/', ExampleName, Path0),
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
    print_message(informational,"VERIFYING...."-[]),
    ProgramText = Args.get(program_text, ""),
    le_kbs:load_text(ProgramText, KB),
    findall(_{severity: Sev, type: Type, message: Msg, start: Start, end: End},
            KB:le_issue(Sev, Type, Msg, Start, End),
            Issues),
    % Run embedded tests if any
    ( current_predicate(KB:le_expected/3) -> 
        findall(test(Q, S, A), KB:le_expected(Q, S, A), Tests),
        maplist(le_kbs:run_one_test(KB), Tests, TestResults),
        maplist(convert_test_result, TestResults, JSONTestResults)
    ; JSONTestResults = []
    ),
    Result = _{issues: Issues, test_results: JSONTestResults}.

run_query(SM, Query, KB, Result) :-
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

convert_test_result(pass(Q, S), _{status: "pass", query: Q, scenario: S}).
convert_test_result(fail(Q, S, E, A), _{status: "fail", query: Q, scenario: S, expected: E, actual: A}).
convert_test_result(error(Q, S, Msg), _{status: "error", query: Q, scenario: S, message: Msg}).
