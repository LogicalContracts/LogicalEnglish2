# Logical English over MCP

*Kind: reference · Audience: developers · Status: current (2026-09-16)*

The LE (Logical English) server speaks MCP, the
[Model Context Protocol](https://modelcontextprotocol.io), which is a common
language in which one program asks another for information on behalf of an LLM
(large language model). The Prolog file `llm/mcp.pl` holds the LE server's side
of that conversation. A program that drives a large language model — Claude
Desktop, Claude Code, opencode — can therefore list the example programs, read
the templates and queries of one program, run queries and check programs for
mistakes. The same four jobs are also offered without the Model Context
Protocol, each at its own web address, for clients that do not speak the
protocol: a ChatGPT action is one such client. The LE Assistant's deep mode
talks to this server itself. For everything else the server can do, see
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

- **HTTP**: send each message over HTTP, the protocol of the web, to
  `POST /mcp` on the LE server, which listens on port 3050 unless it was
  started on another port. One request carries one
  message written in JSON-RPC 2.0, a plain way of naming what you want and
  passing the arguments for it in JSON (JavaScript Object Notation, a text
  format for data). The server answers each request with one JSON reply. The
  server never opens a channel of its own to push messages at the client, so a
  `GET /mcp` is refused with status `405`. Start the server as
  [web-api.md](web-api.md#starting-the-server) describes.
- **STDIO**: run the server as a program that reads JSON-RPC messages, one per
  line, from its standard input, and writes each reply to its standard output:

  ```bash
  swipl -g "use_module(llm/mcp), mcp:handle_mcp_stdio." -t halt llm/mcp.pl
  ```

  Start that program in the top folder of this repository, the folder that
  holds the whole project. The server reads the examples and the documentation
  by paths written relative to that folder, and finds neither from anywhere
  else.

## Client setup

The folder `llm/settings/` holds an example settings file for each client
below.

### Claude Desktop

Add one of two entries to `claude_desktop_config.json`. The first entry starts
a server of your own on the same machine, which talks through its standard
input and output. Correct the path to `swipl` for your machine, and make the
program start in the top folder of the repository — for instance by launching
it through a shell that `cd`s there first:

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

The second entry talks to a server that is already running, through
`mcp-remote`, a small relay that carries the messages over the web
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

A third settings file, `llm/settings/claude_desktop_config_remote.json`, points
the relay at the hosted server instead, `https://le2.logicalcontracts.com/mcp`.

### Claude Code

Run either of these two lines in the top folder of the repository. The first
line starts a server that talks through standard input and output; the second
line reaches a server that is already running:

```bash
claude mcp add logical-english -- swipl -g "use_module(llm/mcp), mcp:handle_mcp_stdio." -t halt llm/mcp.pl
claude mcp add logical-english -- npx mcp-remote http://localhost:3050/mcp
```

### opencode (the LE Assistant)

The LE Assistant's deep mode runs `opencode` with settings written out from
`llm/settings/opencode_config.json.template`. Those settings name one server on
the same machine, reached through
`npx mcp-remote http://127.0.0.1:3050/mcp?job=<job id>`. The `job` part of that
address — a line `X-LE-Job` in the request does the same — tells the server
which job each checked program belongs to. The assistant can then hand back the
last program that passed the check, even when the agent's own edits to the
files never arrived ([docs/dev/assistant.md](../../dev/assistant.md)).

### ChatGPT actions

1. Create a Custom GPT; under Configure, create a new action.
2. Paste `llm/settings/chatgpt_openapi.yaml` into the Schema field. That file
   describes [the four web addresses listed below](#rest-endpoints).
3. Set the server URL — the address of the server on the web — to an address of
   the LE server that the outside world can reach. A server running on your own
   machine has no such address until you open a tunnel to it, with a tool such
   as `ngrok`.

## Tools

A call to `tools/list` returns four tools, and a call to `tools/call` runs one
of the four. The server sends a tool's result as a single item of content of
type `text`, whose text is the tool's JSON reply written out. When that reply
carries an `error` field, the server sends the error message instead and marks
the result `isError: true`.

| Tool | Arguments | Reply |
|---|---|---|
| `list_examples` | – | `{examples: [{name, summary}]}` |
| `get_example_details` | `example_name` (required) | the program's text and metadata |
| `query` | `query` (required), `example_name`, `program_text`, `scenario_name`, `facts` | `{results: [{answer, explanation}]}` |
| `verify` | `program_text` (required) | `{issues, test_results}` |

**`list_examples`** lists the programs of `examples/moreExamples/`, of the
extra folders (`regulatory/…`, `migration/…`, …) and of the folders of the
other languages (`pt/…`), each with a one-line summary. Folders that only
readers with certain roles may open are left out, because a client speaking
MCP never logs in. To write a summary the server loads the program once, and
keeps the summary for the next listing. The server gives the whole listing 20
seconds; when that time is up, each program still without a summary is
described by the comment at the top of the program instead.

**`get_example_details`** loads the example the call names, names being written
as [web-api.md](web-api.md#example-names-and-access) explains. The tool then
replies with what the server knows about that program: `kb`, `templates`,
`template_defs`, `queries` (`{name, template, le}`), `scenarios` and `examples`
(`{name}`), `included_resources`, `views`, and the lists of images. Those are
the fields that the web API — the other way one program asks this server for
something — sends back from
[its `load` operation](web-api.md#load--load-a-program-into-a-new-session),
minus the session, plus `program_text`, which is the program's own text. An
example in a folder reserved for certain roles answers
`{error: "Example '…' requires login"}`, because a client speaking MCP never
logs in.

**`query`** works in four steps. First the tool loads a program — the example
named by `example_name`, or the text given as `program_text` — into a session
that lasts for this one call; an example reserved for certain roles answers
`error`, as above. Second, the tool sets the scenario `scenario_name`, when the
call gives one. Third, the tool adds the sentences of `facts`, each of them an
LE sentence ending in a full stop, read against the program's templates.
Fourth, the tool runs `query`, which is either the name of a query in the
program or a question written in LE that fits the program's templates. Each
answer comes back as `{answer, explanation}`, the explanation built from the
nodes [web-api.md](web-api.md#explanation-tree-nodes) describes. When the query
has no answer, the reply is `{results: [], explanation}`, holding the
explanation of the failure, or else
`{results: [], error: "No answer and no explanation found"}`. Facts or a query
that the server cannot read against the templates make the tool reply `error`.

**`verify`** loads `program_text` and replies with two lists. `issues` holds
what the verifier found wrong or doubtful in the program, each one
`{severity, type, message, fix, start, end}` and explained in
[the warnings guide](../guide/warnings.md). `test_results` holds the tests
written inside the program itself (`expects answers` and `expects changes`),
each one `{status: "pass"|"fail"|"error", query, scenario}`. A test that fails
also carries `expected`, `actual` and the unknowns; a test that breaks down
carries `message`.

A server started with the flag `mcp:mcp_only_query_verify` set lists only two
of the four tools, `query` and `verify`.

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

The same four tools are also reachable on the LE server without JSON-RPC, each
at its own web address. Send the tool's arguments as a JSON object in the body
of the request. The server answers with the tool's JSON reply; when the tool
itself fails, that reply carries an `error` field and the status is still
`200`.

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

These four addresses ask for no token.

## Protocol details

- The server answers an `initialize` message with protocol version
  `2024-11-05`, with `tools`, `prompts` and `resources` as the three things it
  can offer, and with `Logical English MCP Server` as its name.
- The server accepts notifications, which are messages carrying no `id`
  because they expect no answer. Over HTTP the server still replies
  `{"result": "ok"}` to one.
- A message naming a method the server does not know is answered with the
  JSON-RPC error `-32601`, and over HTTP with status `404`. A message with no
  `method` at all is answered with `-32600`, and with status `400`. A tool
  that breaks down is answered with `-32603`.
- A large language model sometimes adds stray characters to the end of a
  tool's name, as in `query<|channel|>…`. The server cuts such a name at the
  first `<`.
