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
:- use_module('../le_tools').

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
        % Attribute any verify captures during this request to the calling job,
        % so concurrent assistant jobs cannot recover each other's work.
        mcp_job_token(Request, JobToken),
        setup_call_cleanup(
            set_verify_job(JobToken),
            handle_mcp_post(Dict),
            clear_verify_job
        )
    ;   member(method(get), Request) ->
        % mcp-remote or other clients might try GET for SSE
        reply_json_dict(_{error: "SSE not implemented, use POST JSON-RPC"}, [status(405)])
    ;   reply_json_dict(_{error: "Method not allowed"}, [status(405)])
    ).

%!  mcp_job_token(+Request, -Token) is det.
%
%   Extracts the LE Assistant job token threaded through the MCP URL by the
%   assistant backend (e.g. .../mcp?job=job_7), falling back to the X-LE-Job
%   header. Yields 'none' when absent (REST clients, manual calls, etc.).
mcp_job_token(Request, Token) :-
    (   member(search(Search), Request),
        member(job=Raw, Search),
        Raw \== '', Raw \== ""
    ->  to_token_atom(Raw, Token)
    ;   member(x_le_job(Raw), Request),
        Raw \== '', Raw \== ""
    ->  to_token_atom(Raw, Token)
    ;   Token = none
    ).

to_token_atom(X, A) :- ( atom(X) -> A = X ; atom_string(A, X) ).

handle_mcp_post(Dict) :-
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
    le_tools:le_tool_query(Args, Result).

call_tool("verify", Args, Result) :-
    le_tools:le_tool_verify(Args, Result).

call_tool(ToolName, _Args, Result) :-
    format(user_error, "MCP Error: Unknown tool called: ~w~n", [ToolName]),
    format(string(Msg), "Unknown tool: ~w. Available tools are: list_examples, get_example_details, query, verify.", [ToolName]),
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
