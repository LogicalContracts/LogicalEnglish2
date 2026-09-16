# Logical English over MCP

*Kind: reference · Audience: developers · Status: current (2026-09-16)*

The LE server speaks the [Model Context Protocol](https://modelcontextprotocol.io)
(`llm/mcp.pl`), so an LLM client — Claude Desktop, Claude Code, opencode — can
list the example programs, read their templates and queries, run queries and
verify programs. The same tools are also offered as plain REST endpoints, for
clients without MCP (e.g. ChatGPT actions). The LE Assistant's deep mode uses
this server itself. For the rest of the server's API see
[web-api.md](web-api.md).

## Table of Contents
- [Transports](#transports)
- [Client setup](#client-setup)
  - [Claude Desktop](#claude-desktop)
  - [Claude Code](#claude-code)
  - [opencode (the LE Assistant)](#opencode-the-le-assistant)
  - [ChatGPT actions](#chatgpt-actions)
- [Tools](#tools)
- [Resources](#resources)
- [Prompts](#prompts)
- [REST endpoints](#rest-endpoints)
- [Protocol details](#protocol-details)

## Transports

- **HTTP**: `POST /mcp` on the LE server (default port 3050), one JSON-RPC 2.0
  message per request, answered with one JSON reply. Server-sent events are not
  implemented: a `GET /mcp` replies `405`. Start the server as in
  [web-api.md](web-api.md#starting-the-server).
- **STDIO**: a process reading JSON-RPC messages, one per line, from standard
  input and writing the replies to standard output:

  ```bash
  swipl -g "use_module(llm/mcp), mcp:handle_mcp_stdio." -t halt llm/mcp.pl
  ```

  It must run with the repository root as its working directory: the examples
  and the documentation are read by relative paths.

## Client setup

Example configuration files are in `llm/settings/`.

### Claude Desktop

In `claude_desktop_config.json`, either a local STDIO server (adjust the
`swipl` path and give the repository as working directory, e.g. by launching
through a shell that `cd`s there):

```json
{
  "mcpServers": {
    "logical-english": {
      "command": "swipl",
      "args": ["-g", "use_module(llm/mcp), mcp:handle_mcp_stdio.", "-t", "halt", "llm/mcp.pl"]
    }
  }
}
```

or a running server, through the `mcp-remote` bridge
(`llm/settings/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "logical-english": {
      "command": "npx",
      "args": ["mcp-remote", "http://localhost:3050/mcp"]
    }
  }
}
```

`llm/settings/claude_desktop_config_remote.json` points the bridge at the
hosted server instead, `https://le2.logicalcontracts.com/mcp`.

### Claude Code

From the repository root, either transport:

```bash
claude mcp add logical-english -- swipl -g "use_module(llm/mcp), mcp:handle_mcp_stdio." -t halt llm/mcp.pl
claude mcp add logical-english -- npx mcp-remote http://localhost:3050/mcp
```

### opencode (the LE Assistant)

The LE Assistant's deep mode runs `opencode` with a configuration generated
from `llm/settings/opencode_config.json.template`: a local MCP server
`npx mcp-remote http://127.0.0.1:3050/mcp?job=<job id>`. The `job` parameter
(or an `X-LE-Job` header) attributes the programs the agent verifies to its
job, so that the assistant can deliver the last verified program even when the
agent's own file edits did not land ([docs/dev/assistant.md](../../dev/assistant.md)).

### ChatGPT actions

1. Create a Custom GPT; under Configure, create a new action.
2. Paste `llm/settings/chatgpt_openapi.yaml` into the Schema field; it describes
   the [REST endpoints](#rest-endpoints).
3. Set the server URL to a publicly reachable address of the LE server (e.g.
   through a tunnel such as `ngrok` for a local one).

## Tools

`tools/list` returns four tools; `tools/call` runs one. A tool's result is its
JSON reply, serialised as the text of one `text` content item; a reply with an
`error` field is returned as that message with `isError: true`.

| Tool | Arguments | Reply |
|---|---|---|
| `list_examples` | – | `{examples: [{name, summary}]}` |
| `get_example_details` | `example_name` (required) | the program's text and metadata |
| `query` | `query` (required), `example_name`, `program_text`, `scenario_name`, `facts` | `{results: [{answer, explanation}]}` |
| `verify` | `program_text` (required) | `{issues, test_results}` |

**`list_examples`** lists the programs of `examples/moreExamples/`, of the
extra trees (`regulatory/…`, `migration/…`, …) and of the language trees
(`pt/…`), each with a one-line summary. Role-restricted trees are left out: an
MCP client has no login. A listing loads each program once for its summary and
caches it; past a 20-second budget, programs not yet summarised are described
by their opening comment.

**`get_example_details`** loads the example named (an example name as in
[web-api.md](web-api.md#example-names-and-access)) and replies its metadata:
`kb`, `templates`, `template_defs`, `queries` (`{name, template, le}`),
`scenarios` and `examples` (`{name}`), `included_resources`, `views`, and the
image lists — the fields of `load`'s reply in [web-api.md](web-api.md#load--load-a-program-into-a-new-session)
without the session, and `program_text`, the program itself. An example of a
role-restricted tree answers `{error: "Example '…' requires login"}`: an MCP
client has no login.

**`query`** loads the program named by `example_name`, or `program_text`, into
a single-use session (a role-restricted example answers `error`, as above);
sets the scenario `scenario_name` if given; adds `facts`
(LE sentences, each ending with a period, parsed against the program's
templates); and runs `query`, a query name of the program or an LE query that
matches its templates. Each answer is `{answer, explanation}` (explanation
nodes as in [web-api.md](web-api.md#explanation-tree-nodes)). With no answer
the reply is `{results: [], explanation}` (the failure explanation), or
`{results: [], error: "No answer and no explanation found"}`; facts or a query
that do not parse reply `error`.

**`verify`** loads `program_text` and replies `issues`, the verifier's
diagnostics (`{severity, type, message, fix, start, end}`, see
[the warnings guide](../guide/warnings.md)), and `test_results`: the program's
embedded tests (`expects answers` and `expects changes`), each
`{status: "pass"|"fail"|"error", query, scenario}`, with `expected` and
`actual` (and the unknowns) for a failure, or `message` for an error.

A server with the flag `mcp:mcp_only_query_verify` asserted lists only `query`
and `verify`.

## Resources

| URI | Content |
|---|---|
| `le://docs/syntax` | `text/markdown`: the Logical English language reference, [docs/user/reference/language.md](../reference/language.md) |

## Prompts

| Prompt | Arguments | What it sets up |
|---|---|---|
| `use_logical_english` | `example_name` | work with one program: read its details, rewrite the user's facts and question to match its templates, call `query`, explain the result |
| `massage_query` | `user_question`, `templates` | rewrite a question into one LE query matching the templates |
| `massage_facts` | `user_facts`, `templates` | rewrite facts into LE facts matching the templates, one per line |

## REST endpoints

The tools without JSON-RPC, on the LE server. Arguments are the tool's, as a
JSON body; the reply is the tool's JSON reply (a tool error is an `error`
field, status `200`).

| Endpoint | Tool |
|---|---|
| `GET /list_examples` | `list_examples` |
| `POST /example_details` | `get_example_details` |
| `POST /query` | `query` |
| `POST /verify` | `verify` |

```bash
curl -s -X POST http://localhost:3050/query -H 'Content-Type: application/json' \
  -d '{"example_name":"citizenship","scenario_name":"alice","query":"one"}'
```

These endpoints take no token.

## Protocol details

- `initialize` replies protocol version `2024-11-05`, capabilities `tools`,
  `prompts` and `resources`, and server name `Logical English MCP Server`.
- Notifications (messages without `id`) are accepted; over HTTP they are
  answered `{"result": "ok"}`.
- An unknown method replies JSON-RPC error `-32601` (over HTTP with status
  `404`); a message without `method`, `-32600` (status `400`); a tool that
  fails outright, `-32603`.
- A tool name with trailing junk from an LLM (`query<|channel|>…`) is cut at
  the `<`.
