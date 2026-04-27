# Logical English Web API (Preliminary DRAFT)

The LE API is a JSON-over-HTTP REST endpoint served at `/leapi` (default port 3050).

## Authentication

Every request must include `"token": "myToken123"` in the JSON body.

## Request / Response format

All requests are HTTP POST with `Content-Type: application/json`.  
All responses are JSON objects. On failure the response contains an `error` key.

---

## Operations

### `examples` — Retrieve a built-in example document

Returns the source text of a named LE example file.

**Request**

```json
{
  "token": "myToken123",
  "operation": "examples",
  "file": "<example_name>"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `file` | string | Name of the example (without extension), e.g. `"1_net_asset_value_test_3"` |

**Response**

```json
{ "document": "<LE source text>" }
```

On error: `{ "answer": "...", "details": "...", "document": "" }`

---

### `list_examples` — List all available LE examples

Returns a list of all `.le` files in the `examples/moreExamples/` directory.

**Request**

```json
{
  "token": "myToken123",
  "operation": "list_examples"
}
```

**Response**

```json
{ "examples": [ "1_cgt_assets_and_exemptions_3", "1_net_asset_value_test_3", ... ] }
```

---

### `answer` — Parse a document and answer one query/scenario pair

Loads the LE document, applies the named scenario, and returns an explanation for a single query.

**Request**

```json
{
  "token": "myToken123",
  "operation": "answer",
  "document": "<LE source text>",
  "theQuery": "<query sentence>",
  "scenario": "<scenario name>"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `document` | string | Full LE source text |
| `theQuery` | string | Name of the query to run, e.g. `"one"` |
| `scenario` | string | Name of the scenario to use, e.g. `"alice"` |

**Response**

```json
{ "answer": <explanation term> }
```

**curl example**

```bash
curl -s -X POST http://localhost:3050/leapi \
  -H 'Content-Type: application/json' \
  -d '{"token":"myToken123","operation":"answer",
       "document":"...","theQuery":"one","scenario":"alice"}'
```

---

### `explain` — Parse a document and return all answers for a query/scenario

Like `answer` but collects every answer, not just the first.

**Request**

```json
{
  "token": "myToken123",
  "operation": "explain",
  "document": "<LE source text>",
  "theQuery": "<query sentence>",
  "scenario": "<scenario name>"
}
```

Same fields as `answer`.

**Response**

```json
{ "results": [ <explanation>, ... ] }
```

---

### `load` — Load a LE or Prolog program into a fresh session module

Parses and asserts a LE (or plain Prolog) program, returning its metadata.

**Request — inline LE source**

```json
{
  "token": "myToken123",
  "operation": "load",
  "le": "<LE source text>"
}
```

**Request — load from file**

```json
{
  "token": "myToken123",
  "operation": "load",
  "file": "<path under /moreExamples/>"
}
```

The `file` path must reside under `/moreExamples/`. Files ending in `.le` are parsed as Logical English; all others are loaded as plain Prolog.

**Response**

```json
{
  "sessionModule": "<generated module name>",
  "kb": "<kb name or null>",
  "predicates": [ "<predicate/arity>", ... ],
  "examples": [ { "name": "...", "scenarios": [ "<fact string>", ... ] } ],
  "queries": [ { "name": "...", "template": "...", "le": "..." }, ... ],
  "language": "le | prolog",
  "target": "prolog",
  "issues": [ { "severity": "...", "type": "...", "message": "...", "start": 0, "end": 0 }, ... ]
}
```

The `sessionModule` value must be passed to subsequent `answeringQuery` and `loadFactsAndQuery` calls.

---

### `answeringQuery` — Run an English query against a loaded session module

Requires a prior `load` call to obtain `sessionModule`.

**Request**

```json
{
  "token": "myToken123",
  "operation": "answeringQuery",
  "sessionModule": "<module name from load>",
  "query": "<English query string>",
  "scenario": "<Scenario name or Prolog scenario term string>",
  "customScenario": "<Logical English facts string>",
  "customQuery": "<Logical English query string>"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `sessionModule` | string | Module name from `load` |
| `query` | string | English query string or named query |
| `scenario` | string | Named scenario or Prolog term string |
| `customScenario` | string | (Optional) LE facts to add to session |
| `customQuery` | string | (Optional) LE query string to parse and run |

**Response**

```json
{ 
  "results": [ { "answer": "<answer string>", "why": <explanation> }, ... ],
  "result": "ok" 
}
```

If no answers are found, a negative explanation is returned in the `why` field of the top-level object.

---

### `loadFactsAndQuery` — Assert facts into a session module and run a goal

Asserts a list of ground facts into an existing session module, then optionally evaluates a goal against them.

**Request**

```json
{
  "token": "myToken123",
  "operation": "loadFactsAndQuery",
  "sessionModule": "<module name>",
  "facts": [ "<fact term string>", ... ],
  "goal": "<Prolog goal string>",
  "vars": [ "<var name>", ... ]
}
```

`goal` and `vars` are optional. Only ground facts (no `:-` heads) are accepted.

**Response**

```json
{
  "facts": [ ... ],
  "goal": "<goal>",
  "answers": [ { "bindings": { "<var>": <value> }, "explanation": <tree> } ],
  "result": "true | false"
}
```

---

### `query` — Low-level Prolog query

Evaluates a Prolog term against a named module's knowledge base, optionally with hypothetical facts.

**Request**

```json
{
  "token": "myToken123",
  "operation": "query",
  "theQuery": "<Prolog term string>",
  "module": "<module name>",
  "facts": [ "<fact term string>", ... ]
}
```

`facts` is optional.

**Response**

```json
{
  "results": [
    {
      "result": "true | false",
      "bindings": { "<VarName>": <value>, ... },
      "unknowns": [ { "goal": "<term>", "module": "<module>" }, ... ],
      "why": <explanation tree>
    }
  ]
}
```

---

## Model Context Protocol (MCP) & REST Tools

The server also exposes endpoints for the Model Context Protocol and direct REST access to LLM-friendly tools.

### Endpoints

- `POST /mcp` — JSON-RPC endpoint for MCP clients (Claude Desktop, etc.)
- `GET /list_examples` — REST list examples
- `POST /query` — REST query with support for `example_name`, `program_text`, `scenario_name`, `facts`, and `query`.
- `POST /verify` — REST verify program text
- `POST /example_details` — REST get full example text and metadata

See `llm/settings/README.md` for MCP configuration.

---

## Explanation tree nodes

The `why` / explanation fields are JSON objects:

```json
{
  "type": "success | failure",
  "literal": "<LE or Prolog string>",
  "start": <offset>,
  "end": <offset>,
  "children": [ <node>, ... ]
}
```

---

## Starting the server

```bash
swipl -g "use_module(classic_web_api), start_api_server(3050), thread_get_message(_)." classic_web_api.pl
```
