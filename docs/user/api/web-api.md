# Logical English Web API

*Kind: reference · Audience: developers · Status: current (2026-09-16)*

The LE server (`classic_web_api.pl`) answers a JSON-over-HTTP API at
`POST /leapi` (default port 3050). Every operation of that endpoint is
documented here, grouped by what it is for; the other HTTP endpoints of the
server are listed at the end. The MCP endpoint and its REST twins are
documented in [mcp.md](mcp.md).

## Table of Contents
- [Conventions](#conventions)
  - [Request and reply](#request-and-reply)
  - [The token](#the-token)
  - [Errors](#errors)
  - [Sessions](#sessions)
  - [Programs sent as text: `le`, `source`, `base`](#programs-sent-as-text-le-source-base)
  - [Example names and access](#example-names-and-access)
- [Operations at a glance](#operations-at-a-glance)
- [Programs and examples](#programs-and-examples)
  - [`list_examples`](#list_examples--list-the-example-programs)
  - [`examples`](#examples--read-an-example-program)
  - [`load`](#load--load-a-program-into-a-new-session)
  - [`documentText`](#documenttext--the-text-of-a-cited-document)
  - [`originals`](#originals--the-original-files-a-program-was-converted-from)
- [Answering queries](#answering-queries)
  - [`answeringQuery`](#answeringquery--answer-a-query-in-a-session)
  - [`interruptQuery`](#interruptquery--interrupt-a-running-query)
  - [`openQuestions`](#openquestions--what-a-case-does-not-state)
  - [`answer`](#answer--load-a-document-and-explain-its-first-answer)
  - [`explain`](#explain--load-a-document-and-explain-every-answer)
  - [`query`](#query--run-a-prolog-goal)
  - [`loadFactsAndQuery`](#loadfactsandquery--add-prolog-facts-to-a-session-and-run-a-goal)
  - [`scaspQuery`](#scaspquery--answer-a-query-with-scasp)
- [Explanations and the Proof Game](#explanations-and-the-proof-game)
  - [`explanationDrill`](#explanationdrill--the-explanation-drill)
  - [`getGameData`](#getgamedata--cards-for-the-proof-game)
  - [`unifyGameNodes`](#unifygamenodes--check-a-proof-game-board)
- [Inspecting a loaded program](#inspecting-a-loaded-program)
  - [`getProlog`](#getprolog--the-prolog-clause-at-a-position)
  - [`predicateAt`](#predicateat--the-predicate-at-a-position)
  - [`predicateOccurrences`](#predicateoccurrences--every-mention-of-the-predicate-at-a-position)
  - [`provenanceAt`](#provenanceat--the-document-cited-at-a-position)
  - [`is_a_hierarchy`](#is_a_hierarchy--the-type-hierarchy)
  - [`graph`](#graph--the-program-as-a-graph)
  - [`testReport`](#testreport--run-the-programs-tests)
- [Views](#views)
  - [`automaticView`](#automaticview--the-automatic-view)
  - [`draftView`](#draftview--draft-a-view-section)
  - [`legalView`](#legalview--the-legal-view-of-an-lps-program)
- [Other targets, import and export](#other-targets-import-and-export)
  - [`getScasp`](#getscasp--the-program-as-scasp)
  - [`getLps`](#getlps--the-program-as-lps)
  - [`importFormats`](#importformats--the-importers)
  - [`importForeign`](#importforeign--translate-another-systems-file)
  - [`exportFormats`](#exportformats--the-exporters-that-apply)
  - [`exportForeign`](#exportforeign--write-the-program-for-another-system)
- [LLM features](#llm-features)
  - [`list_models`](#list_models--the-llm-models)
  - [`nl_to_le`](#nl_to_le--write-it-in-english)
  - [`assistant_command`](#assistant_command--start-an-le-assistant-job)
  - [`assistant_status`](#assistant_status--poll-an-le-assistant-job)
  - [`assistant_interrupt`](#assistant_interrupt--interrupt-an-le-assistant-job)
  - [`contract_start`](#contract_start--start-a-contract-assistant-job)
  - [`contract_status`](#contract_status--poll-a-contract-assistant-job)
  - [`contract_result`](#contract_result--the-result-of-a-contract-assistant-job)
  - [`contract_interrupt`](#contract_interrupt--stop-a-contract-assistant-job)
  - [`contract_cost_estimate`](#contract_cost_estimate--price-a-contract-assistant-job)
- [Explanation tree nodes](#explanation-tree-nodes)
- [Other HTTP endpoints](#other-http-endpoints)
- [Starting the server](#starting-the-server)

---

## Conventions

### Request and reply

Every request is an HTTP `POST /leapi` with `Content-Type: application/json`
and a JSON object body carrying `token`, `operation` and the operation's
fields. Every reply is a JSON object.

```bash
curl -s -X POST http://localhost:3050/leapi \
  -H 'Content-Type: application/json' \
  -d '{"token":"myToken123","operation":"load","file":"citizenship"}'
```

An optional query parameter `?lang=<code>` (e.g. `/leapi?lang=pt`) sets the
language of the server's messages for that request, when the language is
registered (`i18n/`). It does not change how a program is parsed: a program's
language is its own (its first statement).

### The token

The body must carry `"token": "myToken123"`. The value is fixed in the code
(`validate_token/1`); it is a guard against stray requests, not an access
control, and every client in the repository sends it. A request without it
is answered `403` with `{"error": "Invalid token"}`.

### Errors

- An operation that cannot do what was asked usually replies `200` with an
  `error` field (a message), as described per operation.
- When an operation fails or throws unexpectedly, the reply is `500` with
  `{"error": "Operation failed or internal error"}`; the server logs the cause
  (and reports it to Sentry when telemetry is configured,
  [docs/dev/telemetry.md](../../dev/telemetry.md)).
- An unknown `operation` replies `{"error": "Unknown operation"}`.

### Sessions

`load` creates a *session module* for a program and replies its name,
`sessionModule`, which the session operations take as a field. A session holds
the program and the facts of the scenario last set in it. The server reclaims
sessions left idle for 30 minutes; the operations `answeringQuery`,
`getGameData` and `explanationDrill` then reply
`{"error": "Session expired", "session_expired": true}`, and the editor loads
the program again and retries. Other session operations reply
`{"error": "No KB loaded"}` for a session that does not exist.

### Programs sent as text: `le`, `source`, `base`

Operations that take the program's text (`le`, or `document` for `answer` and
`explain`) also accept two optional fields, so that the program's relative
`include`s resolve where the program lives:

| Field | Description |
|-------|-------------|
| `source` | the example name the text was opened as (e.g. `"regulatory/eu261_integration"`): includes resolve against that example's folder |
| `base` | for a program fetched from a URL, its base URL (`http://…` or `https://…`) |

Without either, includes resolve against the server's working directory.

In any reply, a dict whose `start` offset falls inside an included resource
also carries `resource`, `resourcePath`, `resourceExample` (or null),
`resourceLine`, `resourceStart` and `resourceEnd`, so a client can open the
resource at that place.

### Example names and access

An example name is a path relative to `examples/moreExamples/` without the
`.le` extension (`"citizenship"`, `"collections/kowalski-book/above_transitivity"`).
A first component that is a language code with an `examples/<lang>/` tree
(`"pt/cidadania"`), or the root of an extra tree (`le_extra_examples_dir/2` in
`le_kbs.pl`, e.g. `"regulatory/…"`), resolves into that tree;
`"imported/<id>/…"` names a program written by `importForeign`.

Some example trees are restricted to roles (`restricted_paths.pl`). The
server reads the roles from the login session cookie (`/login`); a request
without one has no roles.

---

## Operations at a glance

| Operation | Takes | Purpose |
|---|---|---|
| `list_examples` | – | example names |
| `examples` | `file` | an example's text |
| `load` | `le` or `file` | load a program, create a session |
| `documentText` | `address` | the text of a cited document |
| `originals` | `source` | the files a program was converted from |
| `answeringQuery` | `sessionModule` | answer a query, with explanations |
| `interruptQuery` | `sessionModule` | interrupt a running `answeringQuery` |
| `openQuestions` | `sessionModule` | the facts a case lacks for a query |
| `answer` | `document` | first answer of a named query in a named scenario |
| `explain` | `document` | every answer of a named query in a named scenario |
| `query` | `module` | a Prolog goal against a module |
| `loadFactsAndQuery` | `sessionModule` | Prolog facts into a session, then a goal |
| `scaspQuery` | `sessionModule` | answer a query with s(CASP) |
| `explanationDrill` | `sessionModule` | the Explanation Drill |
| `getGameData` | `sessionModule` | the Proof Game's cards |
| `unifyGameNodes` | `sessionModule` | check a Proof Game board |
| `getProlog` | `sessionModule` | the Prolog clause at an offset |
| `predicateAt` | `sessionModule` | the predicate at an offset, its template and rules |
| `predicateOccurrences` | `sessionModule` | every mention of that predicate |
| `provenanceAt` | `sessionModule` | the document cited at an offset |
| `is_a_hierarchy` | `sessionModule` | the `is a` type hierarchy |
| `graph` | `sessionModule` | templates, rules, facts, scenarios, queries as a graph |
| `testReport` | `le` | run the program's `expects answers` tests |
| `automaticView` | `sessionModule` | the automatic LE view |
| `draftView` | `sessionModule` | a first view section, as LE text |
| `legalView` | `le` | the legal view of an LE-for-LPS program |
| `getScasp` | `sessionModule` | the program as s(CASP) |
| `getLps` | `le` or `sessionModule` | the program as LPS |
| `importFormats` | – | the importers |
| `importForeign` | `name`, `text`/`base64` | translate another system's file into LE |
| `exportFormats` | `le` | the exporters that can write the program |
| `exportForeign` | `le`, `exporter` | write the program for another system |
| `list_models` | – | LLM models, providers with a server key |
| `nl_to_le` | `sentence` | English to LE facts or query (one LLM call) |
| `assistant_command` | `command`, `content` | start an LE Assistant job |
| `assistant_status` | `job_id` | poll it |
| `assistant_interrupt` | `job_id` | interrupt it |
| `contract_start` | materials | start a Contract Assistant job |
| `contract_status` | `job` | poll it |
| `contract_result` | `job` | its result |
| `contract_interrupt` | `job` | stop it |
| `contract_cost_estimate` | configuration | its price, before it runs |

---

## Programs and examples

### `list_examples` — List the example programs

**Request**: no fields.

**Reply**

```json
{ "examples": [ "alice", "citizenship", "collections/kowalski-book/above_transitivity", ... ] }
```

The names of the `.le` programs the caller may open, recursively, from
`examples/moreExamples/` and the extra trees (each under its root name). When
the request's `?lang=` is a language with its own tree, that tree's programs
come first, as `<lang>/<name>`. Copies of `lib/` libraries and `sources/`
folders are not listed.

### `examples` — Read an example program

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `file` | string | an example name, e.g. `"citizenship"` |

**Reply**: `{ "document": "<LE source text>" }`.

- A name that resolves to no file: `{ "answer": "File not found", "details": "<path>", "document": "" }`.
- A restricted example: `{ "error": "<message>", "loginRequired": true }` when
  the caller is not logged in (logging in may grant access), or
  `{ "error": "<message>" }` when the logged-in user lacks the role.

### `load` — Load a program into a new session

**Request** — either the text:

| Field | Type | Description |
|-------|------|-------------|
| `le` | string | the program's text |
| `source`, `base` | string | optional, [see above](#programs-sent-as-text-le-source-base) |

or an example:

| Field | Type | Description |
|-------|------|-------------|
| `file` | string | an example name ([see above](#example-names-and-access)). A file ending in `.le` (the extension is added when the name has none and `<name>.le` exists) is loaded as Logical English; any other file as plain Prolog |

**Reply**

```json
{
  "sessionModule": "s536aee7e-…",
  "kb": "citizenship",
  "language": "le",
  "target": "prolog",
  "templates": [ "a person acquires British citizenship on a date", ... ],
  "template_defs": [ { "label": "*a person* acquires British citizenship on *a date*",
                       "scenario_element": false, "judged": false, "values": [[], []] }, ... ],
  "queries": [ { "name": "one", "template": "acquires_British_citizenship_on(_A,_B)",
                 "le": "which person acquires British citizenship on which date" } ],
  "examples": [ { "name": "alice" }, { "name": "harry" } ],
  "included_resources": [ { "resource": "...", "start": 0, "end": 0, "rules": 3, "templates": 2 } ],
  "fact_images": [ { "start": 0, "end": 0, "url": "..." } ],
  "template_images": [ { "literal": "...", "url": "..." } ],
  "views": [ ... ],
  "citations": [ ... ],
  "issues": [ { "severity": "error|warning|…", "type": "...", "message": "...", "fix": "...", "start": 0, "end": 0 } ]
}
```

- `kb` is the program's name (null when it has none); `language` is `le` or
  `prolog`; `target` is the declared target language (`prolog`, `lps`, …).
- `examples` are the program's scenarios.
- `template_defs` are the templates with their placeholders, whether each is
  a scenario element or judged, and per placeholder the values the rules read
  there (the Scenario Editor's pick lists).
- `views` are the program's LE views, compiled
  ([language.md §17.10](../reference/language.md)); `citations` the places
  where it cites a document that `provenanceAt` can show.
- `issues` are the verifier's diagnostics ([warnings](../guide/warnings.md)).

A program that does not load, or an example the caller may not open, gives the
`500` reply.

### `documentText` — The text of a cited document

**Request**: `address` (a URL, or a path relative to the program's folder),
with `source`/`base` as for a load.

**Reply**: `{ "text": "...", "address": "..." }`, or `{ "error": "<reason>" }`
(e.g. `"no such document file"`, or a document the caller's roles do not
reach).

### `originals` — The original files a program was converted from

**Request**: `source` (the example the program was opened as), or `base`.

**Reply**: `{ "files": [ "sources/…", ... ] }` — the text files under the
`sources/` folder beside the program (at most 500; binary files left out),
each readable with `documentText`. `{ "files": [] }` when there is none.

---

## Answering queries

### `answeringQuery` — Answer a query in a session

The editor's query panel. Requires a `sessionModule` from `load`.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `sessionModule` | string | from `load` |
| `query` | string | a query name of the program (e.g. `"one"`) |
| `customQuery` | string or null | instead of `query`: an LE query (the body of a `query … is:`) to parse against the program's templates |
| `scenario` | string | a scenario name; `""` for none. A string containing `(` is read as a Prolog fact or list of facts |
| `customScenario` | string or null | instead of `scenario`: LE facts to parse against the program's templates |
| `detailedFailures` | boolean | optional: one explanation node per rule attempted in a failure explanation |
| `whyNot` | boolean | optional: for a query with no answer, also reply `unmet` ([language.md §17.10](../reference/language.md), "Why not"); turns `detailedFailures` on |
| `keep` | list of strings | optional: template labels whose facts a flip query leaves as they are ([language.md §17.7](../reference/language.md)) |
| `hideRepeated` | boolean | optional, default true: collapse repeated sub-explanations (`false` shows them in full) |
| `largerImportantReasons` | boolean | optional, default true: for a failed query, the important reason lists up to three deepest failures instead of one |
| `debug` | boolean | optional: run the query under the debugger attached to the session over `/dap` |

The session's facts are replaced by the scenario or the custom facts on each
call.

**Reply — the query has answers**

```json
{
  "result": "ok",
  "results": [
    { "answer": "John acquires British citizenship on 2021-10-09",
      "goal": "John acquires British citizenship on 2021-10-09",
      "unknowns": [ "<LE sentence>", ... ],
      "why": [ <explanation node>, ... ],
      "strongestReason": "2021-10-09 is after commencement",
      "strongestReasonPath": "1.2" }
  ],
  "checklist": []
}
```

- One result per distinct answer (same answer and same unknowns are listed once).
- `goal` is the answer as a sentence that reads back as itself.
- `unknowns` are the goals the answer assumes (abduction), as LE sentences;
  empty when there are none.
- `strongestReason` is a one-line summary of the explanation, and
  `strongestReasonPath` the 1-based path of its node in `why` (`"1.2"` is the
  second child of the first root).
- `checklist`, for a program with the reserved sections (applicability,
  question, remedy — [language.md §17](../reference/language.md)), is
  `[{section, status}]` in checklist order; `[]` otherwise.

**Reply — no answer**

```json
{
  "result": "ok",
  "results": [],
  "why": [ <failure explanation node>, ... ],
  "strongestReason": "it is not the case that 2021-10-09 is after commencement",
  "strongestReasonPath": "1.1.2",
  "checklist": [],
  "unmet": [ ... ]
}
```

`unmet` is present only with `whyNot`: a list of
`{literal, kind, facts, ruleStart, ruleEnd, rule?, provenance?, label?, goal?, values?}`.
`kind` is `not_stated` (a fact the case could state and does not) or `not_met`;
`facts` are the conditions of the asking rule that held; `rule` is that
rule's name, only when its author named it, and `provenance` its provenance;
a `not_stated` item also has its template `label`, the `goal` to state and,
per placeholder, the `values` the rules read there.

**Other replies**

- `{ "error": "<parse message>" }` — the custom scenario or query does not parse.
- `{ "result": "interrupted", "interrupted": true }` — stopped by `interruptQuery`.
- `{ "results": [], "error": "Explanation failed", "result": "ok" }` — no answer and no explanation.
- A reply may add `valueWarnings`: values of the custom facts that no rule can
  read where they stand, each `{fact, value, kind, message, fix}`.
- `{ "error": "Session expired", "session_expired": true }`.

### `interruptQuery` — Interrupt a running query

**Request**: `sessionModule`.

**Reply**: `{ "result": "ok", "interrupted": true }` when an `answeringQuery`
was running in that session (it then replies `interrupted`), or
`{ "result": "ok", "interrupted": false, "message": "No running query" }`.

### `openQuestions` — What a case does not state

What a case lacks for a query, for a screen that asks for it (the views'
"the result asks what is missing").

**Request**: `sessionModule`, and `query`/`customQuery`,
`scenario`/`customScenario` as for `answeringQuery`.

**Reply**

```json
{ "holds": false,
  "missing": [ { "literal": "...", "label": "*a date* is after commencement",
                 "goal": "2021-10-09 is after commencement", "values": [[]] } ],
  "touched": [ ... ] }
```

`holds` says whether the query has an answer. `missing` are the case facts
whose absence made the closest attempts fail (stating one may give the
result); `touched` every case fact the attempt looked for and did not find.
A case fact is a fact of a scenario-element or judged template (in a program
that marks none, of a template no rule concludes). Errors:
`{ "error": "No KB loaded" }`, a parse message, or
`{ "error": "Could not set up the query" }`.

### `answer` — Load a document and explain its first answer

A stateless operation: loads the document into a temporary session, sets a
named scenario, runs a query and discards the session.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `document` | string | the program's text |
| `theQuery` | string | a query name, e.g. `"one"` |
| `scenario` | string | a scenario name, e.g. `"alice"` |
| `source`, `base` | string | optional, [see above](#programs-sent-as-text-le-source-base) |
| `hideRepeated` | boolean | optional, as for `answeringQuery` |

**Reply**: `{ "answer": [ <explanation node>, ... ] }`, or
`{ "answer": "No answer found" }`. An unknown scenario replies
`{ "error": "Scenario not found" }`.

### `explain` — Load a document and explain every answer

Like `answer`, with every distinct answer.

**Request**: the fields of `answer`.

**Reply**: `{ "results": [ [ <explanation node>, ... ], ... ] }` — one
explanation per distinct answer; `{ "error": "Scenario not found" }`.

### `query` — Run a Prolog goal

A low-level operation: a Prolog goal against a module.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `theQuery` | string | a Prolog goal, e.g. `"acquires_British_citizenship_on(P, D)"` |
| `module` | string | a session module, or a loaded knowledge-base module (a temporary session is made for it) |
| `facts` | list of strings | optional: Prolog facts added before the goal runs |
| `hideRepeated` | boolean | optional |

**Reply**

```json
{ "results": [ { "result": "true",
                 "bindings": { "P": "John", "D": "2021-10-09" },
                 "unknowns": [ ... ],
                 "why": [ <explanation node>, ... ] } ] }
```

With no solution: `{ "results": [ { "result": "false" } ] }`. Facts added to
a session module stay in it.

### `loadFactsAndQuery` — Add Prolog facts to a session and run a goal

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `sessionModule` | string | from `load` |
| `facts` | list of strings | Prolog facts, e.g. `"is_born_in_on(bob, 'the UK', '2021-10-09')"`, added to the session |
| `goal` | string | optional: a Prolog goal to run afterwards |
| `hideRepeated` | boolean | optional |

**Reply**

- Without `goal`: `{ "facts": [ ... ], "result": "ok" }`.
- With `goal` and solutions: `{ "facts": [ ... ], "goal": "...", "answers": [ { "bindings": { "X": ... }, "explanation": ... } ], "result": "true" }`.
- With `goal` and none: `{ "result": "false" }`.

### `scaspQuery` — Answer a query with s(CASP)

Runs a query under the s(CASP) engine
([s(CASP) reference](../reference/scasp.md)).

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `sessionModule` | string | from `load` |
| `query` or `customQuery` | string | a query name, or an LE query |
| `scenario` | string | optional: a scenario name |
| `timeLimit` | number | optional: seconds, default 10 |
| `le` | string | optional: the program's text, so that a refusal can give line numbers |

**Reply**

```json
{ "result": "ok", "engine": "scasp", "modelCount": 2, "issues": [ ... ],
  "results": [ { "answer": "...", "why": <node>, "bindings": { "X": "..." },
                 "unknowns": [ ... ], "assumptions": [ ... ],
                 "symbolic": false, "constraints": [],
                 "modelIndex": 1, "modelCount": 2 } ] }
```

One result per distinct possible world (answer and assumption set); an answer
that is not ground is `symbolic`, its `constraints` in LE words. `issues` are
`{kind, ruleId, message}`. A program s(CASP) cannot state faithfully is refused
as `getScasp` refuses it. Other errors: `{ "error": "No KB loaded" }`, the
engine not installed, `{ "error": "Unknown query for the s(CASP) engine" }`.

---

## Explanations and the Proof Game

### `explanationDrill` — The Explanation Drill

Drives the "suspects tree" drill over an explanation: it proposes the node that
best splits the remaining tree and asks whether it is understood.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `sessionModule` | string | a session (the drill's state is kept in it) |
| `why` | explanation | the explanation tree, on the first call; later calls may omit it |
| `answers` | list | the user's replies so far, in order: `"yes"` (understood) or `"not_yet"` (descend into it) |

**Reply**

```json
{ "ok": true, "initialCount": 17, "progress": 5, "topPath": "1.2",
  "questions": [ { "path": "1.2", "text": "...", "start": 0, "end": 0, "answer": "not_yet" } ],
  "pending": { "path": "1.2.1", "text": "...", "start": 0, "end": 0 } }
```

`pending` is the next question, or null when the drill is complete;
`initialCount` the tree's size and `progress` the size of the understood part.
Errors: `{ "error": "No explanation to drill" }`, session expired.

### `getGameData` — Cards for the Proof Game

**Request**: `sessionModule`, `query`/`customQuery`, `scenario`/`customScenario`
as for `answeringQuery`; optional `hideRepeated`; optional `answerIndex`
(0-based) to choose which answer the game proves.

**Reply**

```json
{ "result": "ok",
  "gameData": { "rules": [ ... ], "facts": [ ... ], "query": "<LE text>",
                "queryTokens": [ ... ], "sessionModule": "...",
                "queryConditions": [ ... ], "queryConditionTokens": [ ... ],
                "queryRanges": [ ... ], "queryNaf": [ ... ], "queryForall": [ ... ],
                "queryTypeCheck": [ ... ],
                "explanation": <explanation of the chosen answer>,
                "answers": [ "<answer label>", ... ], "answerIndex": 0 } }
```

The rule and fact cards are built by `le_proof_game.pl` for the Proof Game
window ([the Proof Game](../guide/proof-game.md)); their shape is that
window's. `answers` holds up to 25 answers, an answer that holds by
assumption labelled with its assumptions. A query without an answer replies
`{ "error": "You need a query with an answer to play" }`; a failure to build
the game replies `{ "error": "...", "gameDataError": true }`.

### `unifyGameNodes` — Check a Proof Game board

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `sessionModule` | string | the game's session (after `getGameData`) |
| `nodes` | list | `{instanceId, templateId}` per card on the board (`templateId` `"fail"` for a FAIL card) |
| `edges` | list | `{child, parent, bodyIndex, subIndex?}`: the child card satisfies condition `bodyIndex` (0-based) of the parent; `subIndex` addresses the part of a "for all cases" condition |

**Reply**: `{ "result": "ok", "status": "ok", "nodes": [ {instanceId, head, headTokens, body, bodyTokens, bodyForall, bodyNafInner, bodyHolds}, ... ] }`
— the cards with the bindings the connections make; `status` `"clash"` when
they do not unify, or `"error"` with `error` for an unknown card.

---

## Inspecting a loaded program

The position operations take `position`, a character offset in the program's
text, and optionally `line` (the text of the cursor's line) and `lineStart`
(that line's offset), which let the server tell a rule's head from its
conditions.

### `getProlog` — The Prolog clause at a position

**Request**: `sessionModule`, `position`.

**Reply**: `{ "prolog": "<clause, as portray_clause/1 writes it>" }`, or
`{ "error": "No term found at this position" }`, `{ "error": "No KB loaded" }`.

### `predicateAt` — The predicate at a position

For the editor's "Show definition" and "Fold/Unfold all rules".

**Request**: `sessionModule`, `position`, `line`, `lineStart`.

**Reply**

```json
{ "le": "*person* acquires British citizenship on *date*",
  "functor": "acquires_British_citizenship_on", "arity": 2,
  "template": { "start": 180, "end": 231 },
  "rules": [ { "start": 611, "end": 954 } ] }
```

`template` is absent when the predicate has no declaration in the program.
Errors: `{ "error": "No predicate at this position" }`, `{ "error": "No KB loaded" }`.

### `predicateOccurrences` — Every mention of the predicate at a position

For "Show occurrences".

**Request**: as `predicateAt`.

**Reply**: `{ le, functor, arity, occurrences: [ {start, end, kind, context, text}, ... ] }`,
sorted by offset. `kind` is `template`, `fact`, `head`, `condition`,
`scenario` or `query`; `context` the scenario's or query's name (or `""`);
`text` the literal there in LE. A rule's range covers the whole rule, so
`text` is what locates the line. Errors as `predicateAt`.

### `provenanceAt` — The document cited at a position

For "Show original text".

**Request**: `sessionModule`, `position`, `line`, `lineStart`.

**Reply**

```json
{ "provenance": { "source": "...", "document": "...", "locator": "...", "quote": "...",
                  "rationale": "...", "url": "...", "text": "..." },
  "rule": "<rule label>" }
```

`rule` is null unless the citation is a named rule's. Fields that the program
does not give are null. Errors: `{ "error": "No cited document at this position" }`,
`{ "error": "No KB loaded" }`.

### `is_a_hierarchy` — The type hierarchy

**Request**: `sessionModule`.

**Reply**: `{ "hierarchy": [ { "type": "...", "range": { "start": 0, "end": 0 } | null, "children": [ ... ] }, ... ] }`
— a forest of the types in the program's `is a` facts and rules, each with the
range of the statement that makes it a subtype. `{ "hierarchy": [] }` when the
program states none; `{ "error": "No KB loaded" }`.

### `graph` — The program as a graph

**Request**: `sessionModule`.

**Reply**: `{ "nodes": [ { "data": {...} } ], "edges": [ { "data": {...} } ] }`
in Cytoscape's element format. A node's `data` has `id`, `type` (`template`,
`rule`, `fact`, `scenario`, `query`), `label` and `source: {start, end}`
(templates also `functor` and `arity`; facts in a scenario `parent`). An edge's
`data` has `id`, `source`, `target` and `type` (`uses`, `scopes`, …). See
[docs/dev/graph.md](../../dev/graph.md). `{ "error": "No KB loaded" }`.

### `testReport` — Run the program's tests

Runs every `<query> expects answers [...]` of the program's scenarios.

**Request**: `le`, with `source`/`base`.

**Reply**

```json
{ "passed": 4, "failed": 0, "errors": 0,
  "tests": [ { "scenario": "alice", "query": "one", "status": "pass|fail|error",
               "expected": [], "actual": [], "unknowns": [], "expectedUnknowns": [],
               "message": "" } ] }
```

`expected`/`actual` and the unknowns are filled for a failed test, `message`
for an error. `{ "error": "The program could not be loaded" }`.

---

## Views

See [LE Views](../tutorials/views.md) and
[language.md §17.10](../reference/language.md).

### `automaticView` — The automatic view

The view drawn from the program itself when it declares none (used by the
executive page).

**Request**: `sessionModule`; optional `name`, the program's file, which names
the view when the program has no name.

**Reply**: `{ "view": { ... } }` — the compiled view, as in `load`'s `views`.
`{ "error": "No view could be drawn from this program" }`.

### `draftView` — Draft a view section

The LE Assistant's "Generate LE view": a first view section for the program,
as LE text to append to it.

**Request**: `sessionModule`; optional `name` (the program's name).

**Reply**: `{ "view": "the view … is:\n    …" }`, or `{ "error": "No KB loaded" }`.

### `legalView` — The legal view of an LPS program

The legal-readable view of an LE-for-LPS program (who may do what, when, with
which effect), as an ordinary LE program.

**Request**: `le`, with `source`/`base`.

**Reply**: `{ "document": "<LE text>", "name": "<program name>", "issues": [ {severity, code, message} ] }`.
Errors: the program does not declare `the target language is: lps` (or does not
load), or the view could not be drawn — each `{ "error": "<message>" }`.

---

## Other targets, import and export

### `getScasp` — The program as s(CASP)

**Request**: `sessionModule`; optional `le` (the program's text, for the line
numbers of a refusal).

**Reply**: `{ "scasp": "<s(CASP) program>", "issues": [ {kind, ruleId, message} ] }`.

A program with a construct s(CASP) cannot state faithfully is refused:
`{ "error": "<one sentence>", "exporter": "s(CASP)", "problems": [ {line, message, text} ], "issues": [...] }`.
Other errors: `{ "error": "No KB loaded" }`; the s(CASP) engine not installed
on the server.

### `getLps` — The program as LPS

The Logical English to LPS translation (in LPS2: `docs/dev/le-lps-interface.md` §3.1).

**Request**: `le` (with `source`/`base`), or `sessionModule`. With `le`, the
provenance carries line and column numbers; with only `sessionModule` it is
empty.

**Reply**: `{ "lps": "<LPS text>", "provenance": [ {index, line, col, kind} ], "issues": [ {severity, type, message, line, col} ] }`,
or `{ "error": "getLps needs either the document text (le) or a loaded sessionModule" }`.

### `importFormats` — The importers

**Request**: no fields.

**Reply**: `{ "formats": [ { "id": "miniscript", "title": "...", "extensions": [ "ms", ... ] }, ... ] }`
— the translators File ▸ Open offers (`le_import.pl`).

### `importForeign` — Translate another system's file

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | the file's name (its extension selects the translator) |
| `text` | string | the file's content, for a text file |
| `base64` | string | instead of `text`: the content base64-encoded (an archive, a binary file) |
| `importer` | string | optional: a translator `id`, forcing it |

**Reply**: `{ "document": "<LE text>", "fileName": "<stem>.le", "source": "imported/<id>/<stem>", "importer": "<title>|null", "notes": [ ... ], "files": [ ... ] }`
— open the program as `source` so that its includes resolve. Errors:
`{ "error": "..." }` when the upload is too large or nothing could be read.

### `exportFormats` — The exporters that apply

**Request**: `le`, with `source`/`base`.

**Reply**: `{ "formats": [ { "id": "legalruleml", "title": "...", "extension": "lrml" }, ... ] }`
— the exporters that can write this program; empty when it does not load.

### `exportForeign` — Write the program for another system

**Request**: `le` (with `source`/`base`), `exporter` (an `id` from `exportFormats`).

**Reply**: `{ "document": "...", "fileName": "...", "exporter": "<title>", "notes": [ ... ], "links": [ {title, url} ] }`.
A program the exporter cannot translate faithfully is refused:
`{ "error": "...", "exporter": "...", "problems": [ {line, message, text} ] }`
(`line` null when unknown). `{ "error": "The program could not be loaded" }`.

---

## LLM features

The operations that call an LLM take the model's short name (from
`list_models`) and an optional `api_keys` object keyed by provider (`openai`,
`anthropic`, `groq`, `together`, `google` for Gemini). A provider without a
key in the request uses the server's key from its environment, when it has one.

### `list_models` — The LLM models

**Request**: no fields.

**Reply**: `{ "models": [ { "short": "gpt-4o", "provider": "openai", "api_model": "gpt-4o" }, ... ], "server_keys": [ "openai", ... ] }`
— `server_keys` are the providers for which the server has a key.

### `nl_to_le` — Write it in English

One synchronous LLM conversion of English into LE facts or a query body that
use the program's templates, verified against the program
(`nl_to_le.pl`).

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `sentence` | string | the English text |
| `kind` | string | `"facts"` (default) or `"query"` |
| `templates` | list of strings | the template labels, with their `*…*` placeholders, the output may use |
| `content` | string | the program, for verification |
| `model` | string | optional, default `"openai/gpt-oss-120b"` |
| `api_keys` | object | optional |
| `document` | string | optional: the name of the document the facts are extracted from (each fact then cites it) |
| `address` | string | optional, with `document`: where the document's text is |
| `source`, `base` | string | optional: where the program lives, for its included templates |

**Reply**: `{ "result": "ok", "le": "<LE text>", "warnings": [ "[warning] line 2: …", ... ], "document_facts": [ ... ] }`
— `warnings` are the issues the fragment adds to the program, most important
first, at most six and a "… and N more"; `document_facts` are the statements
that tell the program where `document` is (empty without `address`). On
failure: `{ "result": "error", "error": "<message>" }`.

### `assistant_command` — Start an LE Assistant job

Starts the LE Assistant on the program ([docs/dev/assistant.md](../../dev/assistant.md)).
The job runs in the background; poll it with `assistant_status`.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `command` | string | the user's request |
| `content` | string | the program's current text |
| `mode` | string | `"light"` (in-process agent, `le_assistant_light.pl`) or `"deep"` (default: an `opencode` agent in a work directory) |
| `model` | string | a model's short name |
| `api_keys` | object | optional |
| `max_steps` | number | light mode: the agent's step bound, default 10 |
| `session_id` | string | deep mode: the conversation to continue (from a previous `assistant_status`) |

**Reply**: `{ "result": "ok", "job_id": "job_7" }`.

### `assistant_status` — Poll an LE Assistant job

**Request**: `job_id`.

**Reply while running**: `{ "result": "ok", "status": "running", "stdout": "...", "stderr": "..." }`
— the job's progress so far.

**Reply when finished**

```json
{ "result": "ok", "status": "finished", "exit_status": "exit(0)",
  "stdout": "<the assistant's answer>", "stderr": "...",
  "new_content": "<the program after the job>", "session_id": "<conversation id>" }
```

Unknown job: `{ "result": "error", "error": "Job not found" }`.

### `assistant_interrupt` — Interrupt an LE Assistant job

**Request**: `job_id`.

**Reply**: `{ "result": "ok", "message": "Job interrupted" }`, or
`"Job already finished"`; `{ "result": "error", "error": "Job not found" }`.

### `contract_start` — Start a Contract Assistant job

The Contract Assistant (`le_contract_assistant.pl`, UI at
`/web_extras/contract_assistant/`) turns materials into a tested LE program in
a background job. Its files are kept under `contract_jobs/<job>/` (or
`$LE_CONTRACT_JOBS_DIR`), which also lets a job's status and result be served
after a server restart.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `mode` | string | `"contract"` (default: materials in, a whole program out), `"scenario"` or `"query"` (one new block for an existing program), `"residue"` |
| `wording` | upload | the contract wording; required in `contract` mode |
| `schedule`, `cases` | upload or list of uploads | optional, `contract` mode |
| `existing_code` | string | optional: LE the program must incorporate |
| `program` | string | `scenario`/`query` modes: the program the block is for (falls back to `existing_code`) |
| `text` | string or upload | `scenario`/`query` modes: the English to convert (optional background in `residue`) |
| `name` | string | optional: the new block's name |
| `instructions` | string | optional free text |
| `model`, `judge_model` | string | default `"claude-sonnet"`; the judge defaults to the model |
| `api_keys` | object | optional |
| `target` | string | optional |
| `budget` | object | `{preset, k?, w?, repairs?, minutes?}`, `preset` one of `"draft"`, `"standard"`, `"thorough"`; default `draft` |
| `features` | object | optional overrides: `probes`, `interrogation_repair`, `holdout`, `paraphrase`, `clausewise`, `diff_repairs`, `max_rewrite_errors`, `polish` |
| `max_tokens` | number | optional; calibrated automatically when absent |
| `reasoning` | string | `"default"` or `"minimal"` |

An upload is `{ "name": "wording.md", "text": "..." }` for text, or
`{ "name": "wording.pdf", "data": "<base64>" }`.

**Reply**: `{ "job": "caj_<uuid>" }`, or `{ "error": "<message>" }`.

### `contract_status` — Poll a Contract Assistant job

**Request**: `job`; optional `since`, the first log line wanted (the previous
reply's `next_seq`).

**Reply**

```json
{ "status": "running|interrupted|finished|error", "stage": 3, "stage_label": "...",
  "branches": [ { "branch": 1, ... } ], "log": [ "...", ... ], "next_seq": 42,
  "config": { "mode": "contract", "model": "...", ... }, "elapsed": 120.5,
  "error": "<when status is error>" }
```

`{ "error": "Unknown job" }` for a job neither running nor on disk.

### `contract_result` — The result of a Contract Assistant job

**Request**: `job`.

**Reply**: `{ "le": "<program>", "filename": "contract.le", "mode": "...", "winner": 1, "scores": [ ... ], "final_score": ..., "ledger": "<markdown>", "interrogation": {...}, "paraphrase": {...}, "existing_code": {...} }`
(`recovered: true` when read back from disk after a restart). Errors:
`{ "error": "Job has no result (yet)" }`, `{ "error": "Unknown job" }`.

### `contract_interrupt` — Stop a Contract Assistant job

**Request**: `job`.

**Reply**: `{ "ok": true }` (the job stops at its next check), or
`{ "ok": false, "error": "Job is not running" }`.

### `contract_cost_estimate` — Price a Contract Assistant job

**Request**: the configuration fields of `contract_start` (`mode`, `model`,
`judge_model`, `budget`, `features`) and `input_chars`, the size of the
selected materials.

**Reply**

```json
{ "calls": 13, "input_tokens_per_call": 32117, "output_tokens_per_call": 5000,
  "priced": true, "cost_usd": 4.12, "currency": "USD", "note": "" }
```

`priced` is false, and `cost_usd` null, when the model has no listed price or
the price table has not loaded; `note` says which.

---

## Explanation tree nodes

The `why`, `answer` and `explanation` fields are lists of nodes:

```json
{
  "type": "success | failure | unknown",
  "literal": "<LE sentence>",
  "start": 611,
  "end": 954,
  "children": [ <node>, ... ]
}
```

`start`/`end` (offsets of the program's text) are absent when the node has no
source. Optional fields:

| Field | On | Meaning |
|---|---|---|
| `naf` | success | the literal is a negation (`it is not the case that …`) |
| `ruleAttempt`, `met`, `conditions` | failure | with `detailedFailures`: one attempted rule, of whose `conditions` the first `met` held |
| `typeCheck` | failure | a type-restriction guard, not a condition of the program |
| `repeated`, `repeatedCount` | any | the node stands for `repeatedCount` identical sibling sub-explanations |
| `repeated`, `repeatedOf` | any | the node repeats the sub-explanation at tree path `repeatedOf`, shown in full there |
| `provenance`, `rule`, `plain` | any | proved by a fact or rule with provenance: its provenance (as in `provenanceAt`), the rule's name, and the sentence without its citation |
| `resource`, … | any | the node's range is in an included resource ([see above](#programs-sent-as-text-le-source-base)) |

Tree paths (`strongestReasonPath`, `repeatedOf`, the drill's `path`) number
nodes from 1: `"2.1"` is the first child of the second root.

---

## Other HTTP endpoints

| Endpoint | Description |
|---|---|
| `GET /` | the landing page: examples, links, test runner (`?run_tests=true`) |
| `GET /editor/` | the Logical English editor |
| `GET /executive` | the executive page: pick a program, a scenario and a query, and run it |
| `GET /multilingual` | the language picker; `?lang=<code>` a landing page for that language's examples |
| `GET /docs/user/…` | the user documentation (a `.md` path serves the file; the path without `.md` the viewer) |
| `GET /source/<path>` | an example's `.le` text, for paths under the directories listed in the `ALLOWED_LE_EXPORTS` environment variable (comma-separated, e.g. `examples/moreExamples`) and the caller's roles |
| `GET /build_info` | `{ "build_info": "<first line of build_info.txt>" }`, or `"unknown build"` |
| `GET,POST /login`, `GET /logout` | log in (form fields `email`, `password`, `return`) and out; the session cookie carries the user's roles |
| `GET /whoami` | `{ "loggedIn": true, "email": "…" }` or `{ "loggedIn": false, "email": null }` |
| `WS /dap` | the Debug Adapter Protocol websocket ([docs/dev/debugger.md](../../dev/debugger.md)) |
| `POST /mcp` | the MCP endpoint ([mcp.md](mcp.md)) |
| `GET /list_examples`, `POST /query`, `POST /verify`, `POST /example_details` | REST versions of the MCP tools ([mcp.md](mcp.md#rest-endpoints)) |
| `GET /telemetry.js`, `GET /telemetry_test` | the pages' telemetry script and its self-test ([docs/dev/telemetry.md](../../dev/telemetry.md)) |
| `POST /test_services/<name>` | deterministic stand-ins for external services, for tests (`le_services.pl`) |
| `/web_extras/…` | additional web apps (the Contract Assistant, the executive page, the documentation viewer) |

---

## Starting the server

From the repository root:

```bash
swipl -g "use_module(classic_web_api), start_api_server(3050)" -t "repeat, sleep(1000), fail"
```

(`start_api_server/0` uses port 3050.) The `-t` goal keeps the process alive
after the server has started in its own threads, as the `Dockerfile` does; in
an interactive `swipl` session, `?- start_api_server(3050).` is enough. The
server refuses to start when the port is already in use.
