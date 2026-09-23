# Logical English Web API

*Kind: reference · Audience: developers · Status: current (2026-09-16)*

The LE (Logical English) server offers an API — a way for one program to ask
another program to do something — at the web address `POST /leapi`, on port
3050 unless the server was started on a different port. A request and its reply
are both written in JSON (JavaScript Object Notation, a plain-text way of
writing data), and travel over HTTP, the protocol of the web. The Prolog file
`classic_web_api.pl` holds the server's side of that exchange. This document
describes every operation of `/leapi`, grouped by what the operation is for,
and lists the server's other web addresses at the end. The address that speaks
MCP (the Model Context Protocol), and the plain web addresses that do the same
work, are described in [mcp.md](mcp.md).

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

Send every request as an HTTP `POST /leapi` marked
`Content-Type: application/json`. The body of the request is one JSON object,
which carries `token`, `operation` and the fields that the operation asks for.
The server always answers with one JSON object.

```bash
curl -s -X POST http://localhost:3050/leapi \
  -H 'Content-Type: application/json' \
  -d '{"token":"myToken123","operation":"load","file":"citizenship"}'
```

Adding `?lang=<code>` to the address, as in `/leapi?lang=pt`, asks the server
to write its messages in that language for that one request. The language must
be one of those the folder `i18n/` registers. The language chosen does not
change how the server reads a program: each program declares its own language
in its first statement.

### The token

The body must carry `"token": "myToken123"`. The predicate `validate_token/1`
fixes that value in the code. The token only keeps stray requests out: the
token grants no rights and hides nothing, and every client in this repository
sends the same one. A request that leaves the token out is answered with status
`403` and `{"error": "Invalid token"}`.

### Errors

- An operation that cannot do what the request asked usually replies with
  status `200` and an `error` field holding a message. The section on each
  operation says which messages that operation gives.
- When an operation breaks down unexpectedly, the reply is status `500` with
  `{"error": "Operation failed or internal error"}`. The server writes the
  cause in its log, and also sends the cause to Sentry, the service that
  collects errors, when the server has been set up to report them
  ([docs/dev/telemetry.md](../../dev/telemetry.md)).
- A request naming an `operation` the server does not know is answered
  `{"error": "Unknown operation"}`.

### Sessions

The `load` operation puts a program into a *session module*, a workspace of its
own, and replies with the name of that workspace in the field `sessionModule`.
Every operation that works on a loaded program takes that name in a field of
the same name. A session holds the program, and the facts of the scenario last
set in the session. The server throws away a session that nobody has used for
30 minutes. The operations `answeringQuery`, `getGameData` and
`explanationDrill` then reply
`{"error": "Session expired", "session_expired": true}`, whereupon the editor
loads the program again and asks a second time. The other session operations
reply `{"error": "No KB loaded"}` when the session named does not exist; KB is
short for knowledge base, which is the program itself.

### Programs sent as text: `le`, `source`, `base`

Some operations take the program's text, in a field called `le`, or `document`
for `answer` and `explain`. Those operations accept two further fields, both
optional. The two fields tell the server where the program lives, so that a
file the program `include`s by a relative path is found:

| Field | Description |
|-------|-------------|
| `source` | the example name the text was opened under (for instance `"regulatory/eu261_integration"`); the server looks for included files in that example's folder |
| `base` | for a program fetched from a URL, which is an address on the web, the address that its included files hang off (`http://…` or `https://…`) |

When the request gives neither field, the server looks for included files in
the folder it was started in.

A reply often points at a place in the program with a `start` offset, which
counts characters from the beginning of the text. When such a place falls
inside an included file, the same object also carries `resource`,
`resourcePath`, `resourceExample` (which may be null), `resourceLine`,
`resourceStart` and `resourceEnd`. A client can then open the included file at
that very place.

### Example names and access

An example name is the path of the program's file under
`examples/moreExamples/`, without the `.le` at the end: `"citizenship"`, or
`"collections/kowalski-book/above_transitivity"`. A name may start instead with
the code of a language that has a folder of its own, `examples/<lang>/`, as
`"pt/cidadania"` does. A name may also start with the root name of one of the
extra folders that `le_extra_examples_dir/2` in `le_kbs.pl` lists, as
`"regulatory/…"` does. The server then looks for the program in that folder. A
name beginning `"imported/<id>/…"` belongs to a program that `importForeign`
wrote.

Some folders of examples are open only to callers who hold a given role, as
`restricted_paths.pl` records. The server learns a caller's roles from the
cookie that logging in at `/login` leaves behind, a cookie being the small note
a browser keeps and sends back with each request. A request that carries no
such cookie has no roles at all.

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
| `legalView` | `le` | the legal view of a program written in LE for LPS (Logic Production System) |
| `getScasp` | `sessionModule` | the program as s(CASP) |
| `getLps` | `le` or `sessionModule` | the program as LPS |
| `importFormats` | – | the importers |
| `importForeign` | `name`, `text`/`base64` | translate another system's file into LE |
| `exportFormats` | `le` | the exporters that can write the program |
| `exportForeign` | `le`, `exporter` | write the program for another system |
| `list_models` | – | the models of LLMs (large language models), and the providers the server holds a key for |
| `nl_to_le` | `sentence` | English into LE facts or a query, in one call to an LLM |
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

The reply lists the names of the `.le` programs the caller may open. The
server looks through `examples/moreExamples/` and through the extra folders,
into every folder within them, and puts each extra folder's root name in front
of the programs it holds. When the request asks with `?lang=` for a language
that has a folder of its own, that folder's programs come first, written
`<lang>/<name>`. The server leaves out copies of the libraries in `lib/`, and
everything in `sources/` folders.

### `examples` — Read an example program

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `file` | string | an example name, e.g. `"citizenship"` |

**Reply**: `{ "document": "<LE source text>" }`.

- A name that matches no file answers
  `{ "answer": "File not found", "details": "<path>", "document": "" }`.
- A restricted example answers `{ "error": "<message>", "loginRequired": true }`
  when the caller has not logged in, since logging in may give access. A caller
  who has logged in but holds no role for that example gets
  `{ "error": "<message>" }`.

### `load` — Load a program into a new session

**Request** — either the text:

| Field | Type | Description |
|-------|------|-------------|
| `le` | string | the program's text |
| `source`, `base` | string | optional, [see above](#programs-sent-as-text-le-source-base) |

or an example:

| Field | Type | Description |
|-------|------|-------------|
| `file` | string | an example name ([see above](#example-names-and-access)). The server adds `.le` when the name has no ending of its own and a file `<name>.le` exists. A file whose name ends in `.le` is read as Logical English; any other file is read as plain Prolog |

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

- `kb` is the program's name, or null when the program has none. `language` is
  `le` or `prolog`. `target` is the target language the program declares, such
  as `prolog` or `lps`.
- `examples` are the program's scenarios.
- `template_defs` lists the templates with their placeholders. Each template
  says whether it is a scenario element and whether it is judged. Each
  placeholder carries the values the rules read in that position, which are the
  choices the Scenario Editor offers.
- `views` holds the program's LE views, already compiled
  ([language.md §17.10](../reference/language.md)). `citations` holds the
  places where the program cites a document that `provenanceAt` can show.
- `issues` holds what the verifier found wrong or doubtful in the program
  ([warnings](../guide/warnings.md)).

A program that fails to load, and an example the caller may not open, both give
the `500` reply described above.

### `documentText` — The text of a cited document

**Request**: `address`, which is either a web address or a path relative to the
program's folder, together with `source` or `base` as `load` takes them.

**Reply**: `{ "text": "...", "address": "..." }`, or `{ "error": "<reason>" }`.
The reason is `"no such document file"` when no file is there, or a message
about a document that the caller's roles do not reach.

### `originals` — The original files a program was converted from

**Request**: `source`, the example name the program was opened under, or
`base`.

**Reply**: `{ "files": [ "sources/…", ... ] }` lists the text files in the
`sources/` folder beside the program, at most 500 of them, leaving out any file
that is not text. Read each one with `documentText`. A program with no such
files gets `{ "files": [] }`.

---

## Answering queries

### `answeringQuery` — Answer a query in a session

The operation behind the editor's query panel. The request must carry a
`sessionModule` that `load` gave.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `sessionModule` | string | from `load` |
| `query` | string | a query name of the program (e.g. `"one"`) |
| `customQuery` | string or null | instead of `query`: a question written in LE, the part that follows `query … is:`, which the server reads against the program's templates |
| `scenario` | string | a scenario name; `""` for none. A string containing `(` is read as a Prolog fact or list of facts |
| `customScenario` | string or null | instead of `scenario`: facts written in LE, which the server reads against the program's templates |
| `detailedFailures` | boolean | optional: when the query fails, the explanation carries one node for every rule the server tried |
| `whyNot` | boolean | optional: for a query with no answer, also reply `unmet` ([language.md §17.10](../reference/language.md), "Why not"); turns `detailedFailures` on |
| `keep` | list of strings | optional: template labels whose facts a flip query leaves as they are ([language.md §17.7](../reference/language.md)) |
| `hideRepeated` | boolean | optional, true unless set: fold away a sub-explanation that has already been shown (`false` shows every one in full) |
| `largerImportantReasons` | boolean | optional, true unless set: when the query fails, the important reason names the three deepest failures instead of one |
| `debug` | boolean | optional: run the query under the debugger that is attached to the session through `/dap` |

Each call replaces the facts in the session with the facts of the scenario, or
with the facts the request itself supplies.

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

- The reply holds one result per distinct answer. Two answers with the same
  sentence and the same unknowns are listed once.
- `goal` is the answer written as a sentence that reads back as itself.
- `unknowns` lists, as LE sentences, the goals the answer takes for granted.
  Taking a goal for granted in order to reach an answer is called abduction.
  The list is empty when the answer assumes nothing.
- `strongestReason` sums the explanation up in one line.
  `strongestReasonPath` says where the node it came from sits in `why`,
  counting from 1: `"1.2"` is the second child of the first root.
- `checklist` is filled for a program that uses the reserved sections —
  applicability, question and remedy
  ([language.md §17](../reference/language.md)). The value is then
  `[{section, status}]` in checklist order. Every other program gets `[]`.

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

The field `unmet` appears only when the request asked for `whyNot`. `unmet` is
a list of
`{literal, kind, facts, ruleStart, ruleEnd, rule?, provenance?, label?, goal?, values?}`.
`kind` is `not_stated`, for a fact the case could state and does not, or
`not_met`. `facts` holds the conditions of the rule that asked, those which did
hold. `rule` is that rule's name, and appears only when its author gave it one;
`provenance` is that rule's provenance. An item whose `kind` is `not_stated`
also carries the template's `label`, the `goal` that would have to be stated,
and, for each placeholder, the `values` the rules read there.

**Other replies**

- `{ "error": "<parse message>" }` — the server could not read the scenario or
  the query the request supplied.
- `{ "result": "interrupted", "interrupted": true }` — `interruptQuery` stopped
  the query.
- `{ "result": "timeout", "timedOut": true, "timeLimit": <seconds>, "error": "<message>" }` —
  the query ran out of time and was stopped. A query has 240 seconds, or 3600
  with `debug: true`, since that time includes however long the debugger stays
  paused. Every other operation may run for 300 seconds; past that the request
  fails with status 500.
- `{ "results": [], "error": "Explanation failed", "result": "ok" }` — the
  query has no answer and the server could not explain why.
- A reply may add `valueWarnings`, which lists values in the supplied facts
  that no rule can read where they stand, each one
  `{fact, value, kind, message, fix}`.
- `{ "error": "Session expired", "session_expired": true }`.

### `interruptQuery` — Interrupt a running query

**Request**: `sessionModule`.

**Reply**: `{ "result": "ok", "interrupted": true }` when an `answeringQuery`
was running in that session. The `answeringQuery` that was stopped then replies
`interrupted` to its own caller. When no query was running, the reply is
`{ "result": "ok", "interrupted": false, "message": "No running query" }`.

### `openQuestions` — What a case does not state

The facts a case lacks before a query can be answered. A screen that asks the
user for those facts uses this operation; in the views it is written as "the
result asks what is missing".

**Request**: `sessionModule`, and `query` or `customQuery`, and `scenario` or
`customScenario`, all as `answeringQuery` takes them.

**Reply**

```json
{ "holds": false,
  "missing": [ { "literal": "...", "label": "*a date* is after commencement",
                 "goal": "2021-10-09 is after commencement", "values": [[]] } ],
  "touched": [ ... ] }
```

`holds` says whether the query has an answer. `missing` lists the case facts
whose absence made the closest attempts fail; stating one of them may give a
result. `touched` lists every case fact the attempt looked for and did not
find. A case fact is a fact of a template marked as a scenario element or
marked as judged; in a program that marks no template either way, a case fact
is a fact of a template that no rule concludes. The errors are
`{ "error": "No KB loaded" }`, a message saying what the server could not read,
and `{ "error": "Could not set up the query" }`.

### `answer` — Load a document and explain its first answer

This operation keeps nothing between calls. The server loads the document into
a session of its own, sets the scenario named, runs the query, and then throws
the session away.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `document` | string | the program's text |
| `theQuery` | string | a query name, e.g. `"one"` |
| `scenario` | string | a scenario name, e.g. `"alice"` |
| `source`, `base` | string | optional, [see above](#programs-sent-as-text-le-source-base) |
| `hideRepeated` | boolean | optional, as for `answeringQuery` |

**Reply**: `{ "answer": [ <explanation node>, ... ] }`, or
`{ "answer": "No answer found" }`. A scenario name the program does not know
replies `{ "error": "Scenario not found" }`.

### `explain` — Load a document and explain every answer

This operation works as `answer` does, but explains every distinct answer
rather than the first.

**Request**: the fields of `answer`.

**Reply**: `{ "results": [ [ <explanation node>, ... ], ... ] }`, one
explanation per distinct answer. A scenario name the program does not know
replies `{ "error": "Scenario not found" }`.

### `query` — Run a Prolog goal

An operation close to the machinery: the server runs a goal written in Prolog
against one module, a module being one named collection of loaded rules.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `theQuery` | string | a Prolog goal, e.g. `"acquires_British_citizenship_on(P, D)"` |
| `module` | string | a session module, or the module of a loaded knowledge base, for which the server makes a session of its own |
| `facts` | list of strings | optional: facts written in Prolog, added before the goal runs |
| `hideRepeated` | boolean | optional |

**Reply**

```json
{ "results": [ { "result": "true",
                 "bindings": { "P": "John", "D": "2021-10-09" },
                 "unknowns": [ ... ],
                 "why": [ <explanation node>, ... ] } ] }
```

A goal with no solution replies `{ "results": [ { "result": "false" } ] }`.
Facts added to a session module stay in that session after the call.

### `loadFactsAndQuery` — Add Prolog facts to a session and run a goal

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `sessionModule` | string | from `load` |
| `facts` | list of strings | facts written in Prolog, such as `"is_born_in_on(bob, 'the UK', '2021-10-09')"`, which the server adds to the session |
| `goal` | string | optional: a goal written in Prolog, to run once the facts are in |
| `hideRepeated` | boolean | optional |

**Reply**

- A request without `goal` gets `{ "facts": [ ... ], "result": "ok" }`.
- A request that gives a `goal` with solutions gets `{ "facts": [ ... ], "goal": "...", "answers": [ { "bindings": { "X": ... }, "explanation": ... } ], "result": "true" }`.
- A request that gives a `goal` with no solution gets `{ "result": "false" }`.

### `scaspQuery` — Answer a query with s(CASP)

The server answers the query with the s(CASP) engine rather than with its own
reasoner ([s(CASP) reference](../reference/scasp.md)).

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `sessionModule` | string | from `load` |
| `query` or `customQuery` | string | a query name, or a question written in LE |
| `scenario` | string | optional: a scenario name |
| `timeLimit` | number | optional: how many seconds the query may run, 10 unless set |
| `le` | string | optional: the program's text, so that a refusal can name the lines it objects to |

**Reply**

```json
{ "result": "ok", "engine": "scasp", "modelCount": 2, "issues": [ ... ],
  "results": [ { "answer": "...", "why": <node>, "bindings": { "X": "..." },
                 "unknowns": [ ... ], "assumptions": [ ... ],
                 "symbolic": false, "constraints": [],
                 "modelIndex": 1, "modelCount": 2 } ] }
```

The reply holds one result per distinct possible world, a possible world being
one answer together with one set of assumptions. An answer that still speaks of
any thing that fits rather than of one particular thing is marked `symbolic`,
and its `constraints` say in LE words what that thing must satisfy. Each of the
`issues` is `{kind, ruleId, message}`. A program that s(CASP) cannot state
faithfully is refused, exactly as `getScasp` refuses it. The other errors are
`{ "error": "No KB loaded" }`, a message that the engine is not installed, and
`{ "error": "Unknown query for the s(CASP) engine" }`.

---

## Explanations and the Proof Game

### `explanationDrill` — The Explanation Drill

Drives the "suspects tree" drill over an explanation. The drill picks the node
that best divides the part of the tree still in question, and asks the reader
whether that node is understood.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `sessionModule` | string | a session, which is where the drill keeps track of how far it has got |
| `why` | explanation | the explanation tree, on the first call; later calls may leave it out |
| `answers` | list | the reader's replies so far, in order: `"yes"` when the node is understood, `"not_yet"` to go down into the node |

**Reply**

```json
{ "ok": true, "initialCount": 17, "progress": 5, "topPath": "1.2",
  "questions": [ { "path": "1.2", "text": "...", "start": 0, "end": 0, "answer": "not_yet" } ],
  "pending": { "path": "1.2.1", "text": "...", "start": 0, "end": 0 } }
```

`pending` is the next question, and is null once the drill is finished.
`initialCount` is the number of nodes in the whole tree, and `progress` the
number of nodes in the part the reader has understood. The errors are
`{ "error": "No explanation to drill" }` and the expired-session reply.

### `getGameData` — Cards for the Proof Game

**Request**: `sessionModule`, `query` or `customQuery`, and `scenario` or
`customScenario`, all as `answeringQuery` takes them. The request may also
carry `hideRepeated`, and `answerIndex`, which chooses which answer the game
proves by counting the answers from 0.

**Reply**

```json
{ "result": "ok",
  "gameData": { "rules": [ ... ], "facts": [ ... ], "query": "<LE text>",
                "queryTokens": [ ... ], "sessionModule": "...",
                "queryConditions": [ ... ], "queryConditionTokens": [ ... ],
                "queryRanges": [ ... ], "queryNaf": [ ... ], "queryForall": [ ... ],
                "queryTypeCheck": [ ... ],
                "explanation": <explanation of the chosen answer, or of the failure>,
                "answers": [ "<answer label>", ... ], "answerIndex": 0,
                "failed": false } }
```

`le_proof_game.pl` builds the rule cards and the fact cards for the Proof Game
window ([the Proof Game](../guide/proof-game.md)), and shapes them as that
window needs them. `answers` holds up to 25 answers; an answer that holds only
by assumption is labelled with the assumptions it makes. A query with no answer
at all is played as a failure: `answers` is then empty, `failed` is `true`, and
`explanation` holds the query's failure explanation, which is the spine of the
failure that the board builds. When the game cannot be built, the reply is
`{ "error": "...", "gameDataError": true }`.

### `unifyGameNodes` — Check a Proof Game board

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `sessionModule` | string | the game's session, as `getGameData` left it |
| `nodes` | list | one `{instanceId, templateId}` for each card on the board; a FAIL card has `templateId` `"fail"` |
| `edges` | list | `{child, parent, bodyIndex, subIndex?}`: the child card satisfies the parent's condition number `bodyIndex`, counting from 0; `subIndex` picks out one part of a "for all cases" condition |

**Reply**: `{ "result": "ok", "status": "ok", "nodes": [ {instanceId, head, headTokens, body, bodyTokens, bodyForall, bodyNafInner, bodyHolds}, ... ] }`
— the cards, each filled in with the values that the connections force upon it.
`status` is `"clash"` when the connections cannot be made to agree, or
`"error"`, with a message in `error`, when a card is unknown.

---

## Inspecting a loaded program

The operations in this section all work at one place in the program. Each takes
`position`, which counts characters from the start of the program's text. Each
also takes two fields that may be left out: `line`, the text of the line the
cursor is on, and `lineStart`, the position at which that line begins. Given
those two, the server can tell the head of a rule, which is its conclusion,
from the rule's conditions.

### `getProlog` — The Prolog clause at a position

**Request**: `sessionModule`, `position`.

**Reply**: `{ "prolog": "<clause, as portray_clause/1 writes it>" }`. The errors
are `{ "error": "No term found at this position" }` and
`{ "error": "No KB loaded" }`.

### `predicateAt` — The predicate at a position

The operation behind the editor's "Show definition" and its "Fold/Unfold all
rules".

**Request**: `sessionModule`, `position`, `line`, `lineStart`.

**Reply**

```json
{ "le": "*person* acquires British citizenship on *date*",
  "functor": "acquires_British_citizenship_on", "arity": 2,
  "template": { "start": 180, "end": 231 },
  "rules": [ { "start": 611, "end": 954 } ] }
```

`template` is missing when the program declares no template for the predicate.
The errors are `{ "error": "No predicate at this position" }` and
`{ "error": "No KB loaded" }`.

### `predicateOccurrences` — Every mention of the predicate at a position

The operation behind "Show occurrences".

**Request**: the fields of `predicateAt`.

**Reply**: `{ le, functor, arity, occurrences: [ {start, end, kind, context, text}, ... ] }`,
in the order the mentions appear in the text. `kind` says what the mention is:
`template`, `fact`, `head`, `condition`, `scenario` or `query`. `context` is
the name of the scenario or query the mention sits in, or `""`. `text` is the
sentence found there, in LE. A rule's `start` and `end` cover the whole rule,
so `text` is what tells the reader which line to look at. The errors are those
of `predicateAt`.

### `provenanceAt` — The document cited at a position

The citation at one place in the program. The editor's View Original Text now
calls `originalTextAt` instead, which does this and more.

**Request**: `sessionModule`, `position`, `line`, `lineStart`.

**Reply**

```json
{ "provenance": { "source": "...", "document": "...", "locator": "...", "quote": "...",
                  "rationale": "...", "url": "...", "text": "..." },
  "rule": "<rule label>" }
```

`rule` is null unless the citation belongs to a rule whose author named it.
Every field the program does not give is null. The errors are
`{ "error": "No cited document at this position" }` and
`{ "error": "No KB loaded" }`.

### `originalTextAt` — Where the original of a position is

The operation behind "View Original Text".

**Request**: `sessionModule`, `position`, `line`, `lineStart`, and either
`source` or `base`, which say where the program's folder is when the session
does not know.

**Reply**, named by its `kind`, in the order the server tries them:

- `"citation"`: `{ kind, provenance, rule }`, the same fields `provenanceAt`
  gives, when the citation at that place can be shown. When the citation points
  at a text file and its locator names an identifier, as
  `at MathVariable PremiumTaxMV` does, the reply also carries the passage that
  defines that identifier, in `quote` and `at`.
- `"passage"`: `{ kind, construct: {kind, name}, rule, via, provenance }`. The
  construct under the cursor — a `rule`, `fact`, `table`, `template`,
  `scenario` or `query` — was found in the files the program was written from.
  `provenance.text` names the file (`"sources/…"`) and `document` its name.
  `locator` is the identifier found, `quote` the passage itself, and `at` the
  `[start, end]` of that passage in the file's readable text, which
  `documentText` returns. `quote` and `at` are null when the whole file, rather
  than one passage, is the construct's original. `via` says which link found
  the passage: `label`, `ledger` or `citation`.
- `"originals"`: `{ kind, construct, files: [{document, text}], hinted }`. The
  server located no passage, and `hinted` lists the files that the ledger names
  for the construct.
- `"none"`: `{ kind, construct }`. The program keeps no original text.

The error is `{ "error": "No KB loaded" }`.

### `is_a_hierarchy` — The type hierarchy

**Request**: `sessionModule`.

**Reply**: `{ "hierarchy": [ { "type": "...", "range": { "start": 0, "end": 0 } | null, "children": [ ... ] }, ... ] }`
— the types named in the program's `is a` facts and rules, arranged as one or
more trees. Each type carries the `start` and `end` of the statement that makes
it a subtype of another. A program that states no such fact or rule gets
`{ "hierarchy": [] }`, and a session that does not exist gets
`{ "error": "No KB loaded" }`.

### `graph` — The program as a graph

**Request**: `sessionModule`.

**Reply**: `{ "nodes": [ { "data": {...} } ], "edges": [ { "data": {...} } ] }`
— the nodes and the edges between them, written as the drawing library
Cytoscape expects its elements. The `data` of a node holds `id`, `type`
(`template`, `rule`, `fact`, `scenario` or `query`), `label` and
`source: {start, end}`; a template also holds `functor` and `arity`, and a fact
inside a scenario holds `parent`. The `data` of an edge holds `id`, `source`,
`target` and `type` (`uses`, `scopes`, …). See
[docs/dev/graph.md](../../dev/graph.md). A session that does not exist gets
`{ "error": "No KB loaded" }`.

### `testReport` — Run the program's tests

The server runs every `<query> expects answers [...]` written in the program's
scenarios.

**Request**: `le`, with `source` or `base` beside it.

**Reply**

```json
{ "passed": 4, "failed": 0, "errors": 0,
  "tests": [ { "scenario": "alice", "query": "one", "status": "pass|fail|error",
               "expected": [], "actual": [], "unknowns": [], "expectedUnknowns": [],
               "message": "" } ] }
```

A test that fails fills `expected`, `actual` and the unknowns; a test that
breaks down fills `message`. A program that will not load gives
`{ "error": "The program could not be loaded" }`.

---

## Views

See [LE Views](../tutorials/views.md) and
[language.md §17.10](../reference/language.md).

### `automaticView` — The automatic view

The view the server draws from the program itself, for a program that declares
no view of its own. The executive page uses this operation.

**Request**: `sessionModule`, and optionally `name`, the program's file name,
which becomes the view's name when the program itself has none.

**Reply**: `{ "view": { ... } }` — the view, compiled, in the same shape as the
`views` field of `load`'s reply. A program from which no view can be drawn gets
`{ "error": "No view could be drawn from this program" }`.

### `draftView` — Draft a view section

The operation behind the LE Assistant's "Generate LE view". The server writes a
first view section for the program, as LE text that the author can add at the
end of the program.

**Request**: `sessionModule`, and optionally `name`, the program's name.

**Reply**: `{ "view": "the view … is:\n    …" }`, or `{ "error": "No KB loaded" }`.

### `legalView` — The legal view of an LPS program

The view of a program written in LE for LPS that a lawyer can read: who may do
what, when, and with what effect. The server writes that view as an ordinary LE
program.

**Request**: `le`, with `source` or `base` beside it.

**Reply**: `{ "document": "<LE text>", "name": "<program name>", "issues": [ {severity, code, message} ] }`.
Each of these gives `{ "error": "<message>" }`: the program does not declare
`the target language is: lps`, the program does not load, or no view could be
drawn from it.

---

## Other targets, import and export

### `getScasp` — The program as s(CASP)

**Request**: `sessionModule`, and optionally `le`, the program's text, which
lets a refusal name the lines it objects to.

**Reply**: `{ "scasp": "<s(CASP) program>", "issues": [ {kind, ruleId, message} ] }`.

A program that uses a construct s(CASP) cannot state faithfully is refused,
with
`{ "error": "<one sentence>", "exporter": "s(CASP)", "problems": [ {line, message, text} ], "issues": [...] }`.
The other errors are `{ "error": "No KB loaded" }`, and a message saying that
the s(CASP) engine is not installed on the server.

### `getLps` — The program as LPS

The translation from Logical English into LPS (in LPS2:
`docs/dev/le-lps-interface.md` §3.1).

**Request**: either `le`, with `source` or `base` beside it, or
`sessionModule`. A request that gives `le` gets provenance with line and column
numbers; a request that gives only `sessionModule` gets empty provenance.

**Reply**: `{ "lps": "<LPS text>", "provenance": [ {index, line, col, kind} ], "issues": [ {severity, type, message, line, col} ] }`,
or `{ "error": "getLps needs either the document text (le) or a loaded sessionModule" }`.

### `importFormats` — The importers

**Request**: no fields.

**Reply**: `{ "formats": [ { "id": "miniscript", "title": "...", "extensions": [ "ms", ... ] }, ... ] }`
— the translators that File ▸ Open offers (`le_import.pl`).

### `importForeign` — Translate another system's file

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | the file's name; the ending of the name picks the translator |
| `text` | string | the file's content, when the file is text |
| `base64` | string | instead of `text`: the content written as base64, a way of writing any file as plain letters and digits — use it for an archive, or any file that is not text |
| `importer` | string | optional: the `id` of a translator, to use that one whatever the file's name |

**Reply**: `{ "document": "<LE text>", "fileName": "<stem>.le", "source": "imported/<id>/<stem>", "importer": "<title>|null", "notes": [ ... ], "files": [ ... ] }`
— open the new program under the name in `source`, so that the files it
includes are found. The reply is `{ "error": "..." }` when the file sent is too
large, or when the server could read nothing from it.

### `exportFormats` — The exporters that apply

**Request**: `le`, with `source` or `base` beside it.

**Reply**: `{ "formats": [ { "id": "legalruleml", "title": "...", "extension": "lrml" }, ... ] }`
— the exporters that can write this program. The list is empty when the program
does not load.

### `exportForeign` — Write the program for another system

**Request**: `le`, with `source` or `base` beside it, and `exporter`, one of
the `id` values that `exportFormats` gave.

**Reply**: `{ "document": "...", "fileName": "...", "exporter": "<title>", "notes": [ ... ], "links": [ {title, url} ] }`.
The exporter refuses a program it cannot translate faithfully, with
`{ "error": "...", "exporter": "...", "problems": [ {line, message, text} ] }`,
where `line` is null when the exporter cannot say which line is at fault. A
program that does not load gives
`{ "error": "The program could not be loaded" }`.

---

## LLM features

The operations in this section call an LLM. Each takes the model's short name,
which `list_models` gives, and may take an `api_keys` object. In that object,
each provider — `openai`, `anthropic`, `groq`, `together`, and `google` for
Gemini — names the key to use with it. When the request gives no key for a
provider, the server uses the key it was started with, if it has one.

### `list_models` — The LLM models

**Request**: no fields.

**Reply**: `{ "models": [ { "short": "gpt-4o", "provider": "openai", "api_model": "gpt-4o" }, ... ], "server_keys": [ "openai", ... ] }`
— `server_keys` lists the providers the server itself holds a key for.

### `nl_to_le` — Write it in English

The server asks the LLM once, and answers only when the LLM has replied. The
LLM turns English into LE facts, or into the body of a query, using the
program's templates. The server then checks the result against the program
(`nl_to_le.pl`).

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `sentence` | string | the English text |
| `kind` | string | `"facts"` (default) or `"query"` |
| `templates` | list of strings | the template labels, with their `*…*` placeholders, that the new text may use |
| `content` | string | the program, against which the server checks the new text |
| `model` | string | optional, `"openai/gpt-oss-120b"` unless set |
| `api_keys` | object | optional |
| `document` | string | optional: the name of the document the facts are taken from; each new fact then cites that document |
| `address` | string | optional, alongside `document`: where the document's text is to be found |
| `source`, `base` | string | optional: where the program lives, so that the templates it includes are found |

**Reply**: `{ "result": "ok", "le": "<LE text>", "warnings": [ "[warning] line 2: …", ... ], "document_facts": [ ... ] }`.
`warnings` lists the issues that the new text adds to the program, the most
important first, at most six of them followed by a "… and N more".
`document_facts` holds the statements that tell the program where `document`
is, and is empty when the request gives no `address`. When the conversion
fails, the reply is `{ "result": "error", "error": "<message>" }`.

### `assistant_command` — Start an LE Assistant job

The server starts the LE Assistant on the program
([docs/dev/assistant.md](../../dev/assistant.md)). The job then runs on its
own, and the client asks `assistant_status` from time to time how the job is
getting on.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `command` | string | the user's request |
| `content` | string | the program's current text |
| `mode` | string | `"light"`, an agent running inside the server itself (`le_assistant_light.pl`), or `"deep"` (the choice made when the request says nothing), an `opencode` agent working in a folder of its own |
| `model` | string | a model's short name |
| `api_keys` | object | optional |
| `max_steps` | number | light mode: how many steps the agent may take, 10 unless set |
| `session_id` | string | deep mode: the conversation to carry on, as a previous `assistant_status` reported it |

**Reply**: `{ "result": "ok", "job_id": "job_7" }`.

### `assistant_status` — Poll an LE Assistant job

**Request**: `job_id`.

**Reply while running**: `{ "result": "ok", "status": "running", "stdout": "...", "stderr": "..." }`
— what the job has written so far, as it goes.

**Reply when finished**

```json
{ "result": "ok", "status": "finished", "exit_status": "exit(0)",
  "stdout": "<the assistant's answer>", "stderr": "...",
  "new_content": "<the program after the job>", "session_id": "<conversation id>" }
```

A job the server does not know answers
`{ "result": "error", "error": "Job not found" }`.

### `assistant_interrupt` — Interrupt an LE Assistant job

**Request**: `job_id`.

**Reply**: `{ "result": "ok", "message": "Job interrupted" }`, or the same
reply with the message `"Job already finished"`. A job the server does not know
answers `{ "result": "error", "error": "Job not found" }`.

### `contract_start` — Start a Contract Assistant job

The Contract Assistant turns the materials it is given into an LE program that
has been tested. The work happens in a job that runs on its own
(`le_contract_assistant.pl`; the pages the user sees are at
`/web_extras/contract_assistant/`). The server keeps a job's files in
`contract_jobs/<job>/`, or in the folder named by `$LE_CONTRACT_JOBS_DIR`.
Because those files stay on disk, the server can still report a job's state and
hand over its result after the server has been restarted.

**Request**

| Field | Type | Description |
|-------|------|-------------|
| `mode` | string | `"contract"` (the choice made when the request says nothing: materials in, a whole program out), `"scenario"` or `"query"` (one new block for a program that exists already), or `"residue"` |
| `wording` | upload | the contract wording; a request in `contract` mode must carry it |
| `schedule`, `cases` | upload or list of uploads | optional, in `contract` mode |
| `existing_code` | string | optional: LE that the program must take in |
| `program` | string | in `scenario` and `query` modes: the program the new block is for; when the request gives none, `existing_code` is used |
| `text` | string or upload | in `scenario` and `query` modes: the English to convert; in `residue` mode, optional background |
| `name` | string | optional: the name of the new block |
| `instructions` | string | optional: anything else to tell the assistant, in free text |
| `model`, `judge_model` | string | `"claude-sonnet"` unless set; the judge uses the same model as the work itself unless it is given its own |
| `api_keys` | object | optional |
| `target` | string | optional |
| `budget` | object | `{preset, k?, w?, repairs?, minutes?}`, where `preset` is `"draft"`, `"standard"` or `"thorough"`; `draft` unless set |
| `features` | object | optional: settings to change one by one — `probes`, `interrogation_repair`, `holdout`, `paraphrase`, `clausewise`, `diff_repairs`, `max_rewrite_errors`, `polish` |
| `max_tokens` | number | optional; the server works out a figure when the request gives none |
| `reasoning` | string | `"default"` or `"minimal"` |

An upload is `{ "name": "wording.md", "text": "..." }` for a text file, or
`{ "name": "wording.pdf", "data": "<base64>" }` for any other file.

**Reply**: `{ "job": "caj_<uuid>" }`, or `{ "error": "<message>" }`.

### `contract_status` — Poll a Contract Assistant job

**Request**: `job`, and optionally `since`, the number of the first log line
wanted, which is the `next_seq` of the previous reply.

**Reply**

```json
{ "status": "running|interrupted|finished|error", "stage": 3, "stage_label": "...",
  "branches": [ { "branch": 1, ... } ], "log": [ "...", ... ], "next_seq": 42,
  "config": { "mode": "contract", "model": "...", ... }, "elapsed": 120.5,
  "error": "<when status is error>" }
```

A job that is neither running nor on disk answers
`{ "error": "Unknown job" }`.

### `contract_result` — The result of a Contract Assistant job

**Request**: `job`.

**Reply**: `{ "le": "<program>", "filename": "contract.le", "mode": "...", "winner": 1, "scores": [ ... ], "final_score": ..., "ledger": "<markdown>", "interrogation": {...}, "paraphrase": {...}, "existing_code": {...} }`
The reply adds `recovered: true` when the server read the result back from disk
after a restart. The errors are `{ "error": "Job has no result (yet)" }` and
`{ "error": "Unknown job" }`.

### `contract_interrupt` — Stop a Contract Assistant job

**Request**: `job`.

**Reply**: `{ "ok": true }`, and the job stops the next time it looks whether
it should. A job that is not running answers
`{ "ok": false, "error": "Job is not running" }`.

### `contract_cost_estimate` — Price a Contract Assistant job

**Request**: the settings that `contract_start` takes — `mode`, `model`,
`judge_model`, `budget` and `features` — together with `input_chars`, the size
of the materials chosen.

**Reply**

```json
{ "calls": 13, "input_tokens_per_call": 32117, "output_tokens_per_call": 5000,
  "priced": true, "cost_usd": 4.12, "currency": "USD", "note": "" }
```

`priced` is false and `cost_usd` is null when the model has no price in the
table, and also when the table of prices did not load. `note` says which of the
two happened.

---

## Explanation tree nodes

The fields `why`, `answer` and `explanation` each hold a list of nodes, and a
node looks like this:

```json
{
  "type": "success | failure | unknown",
  "literal": "<LE sentence>",
  "start": 611,
  "end": 954,
  "children": [ <node>, ... ]
}
```

`start` and `end` count characters in the program's text, and are missing when
the node comes from no place in the program. A node may carry these further
fields:

| Field | On | Meaning |
|---|---|---|
| `naf` | success | the literal is a negation (`it is not the case that …`) |
| `ruleAttempt`, `met`, `conditions` | failure | with `detailedFailures`: one rule the server tried; of that rule's `conditions`, the first `met` of them held |
| `typeCheck` | failure | a guard that checks the kind of thing named, rather than a condition the program states |
| `repeated`, `repeatedCount` | any | this one node stands for `repeatedCount` sub-explanations that are alike and sit side by side |
| `repeated`, `repeatedOf` | any | the node repeats the sub-explanation at the tree path `repeatedOf`, which is where it is shown in full |
| `provenance`, `rule`, `plain` | any | the fact or rule that proved the node cites a document: its provenance (the fields `provenanceAt` gives), the rule's name, and the sentence without the citation |
| `resource`, … | any | the node's place falls inside an included file ([see above](#programs-sent-as-text-le-source-base)) |

A tree path — `strongestReasonPath`, `repeatedOf`, and the drill's `path` —
numbers the nodes from 1, so `"2.1"` is the first child of the second root.

---

## Other HTTP endpoints

| Endpoint | Description |
|---|---|
| `GET /` | the landing page, with the examples, the links, and the test runner (`?run_tests=true`) |
| `GET /editor/` | the Logical English editor |
| `GET /executive` | the executive page: pick a program, a scenario and a query, and run it |
| `GET /multilingual` | the language picker; adding `?lang=<code>` gives a landing page for that language's examples |
| `GET /docs/user/…` | the user documentation: a path ending in `.md` gives the file itself, and the same path without `.md` gives the viewer |
| `GET /source/<path>` | an example's `.le` text. The server serves a path only when it lies under one of the folders named in the setting `ALLOWED_LE_EXPORTS`, which the server is started with and which lists folders separated by commas, such as `examples/moreExamples`, and only when the caller's roles allow it |
| `GET /build_info` | `{ "build_info": "<first line of build_info.txt>" }`, or `"unknown build"` |
| `GET,POST /login`, `GET /logout` | log in, with the form fields `email`, `password` and `return`, and log out again; the cookie left behind carries the user's roles |
| `GET /whoami` | `{ "loggedIn": true, "email": "…" }` or `{ "loggedIn": false, "email": null }` |
| `WS /dap` | the lasting connection over which the debugger speaks the Debug Adapter Protocol ([docs/dev/debugger.md](../../dev/debugger.md)) |
| `POST /mcp` | the address that speaks the Model Context Protocol ([mcp.md](mcp.md)) |
| `GET /list_examples`, `POST /query`, `POST /verify`, `POST /example_details` | the same four MCP tools as plain web addresses ([mcp.md](mcp.md#rest-endpoints)) |
| `GET /telemetry.js`, `GET /telemetry_test` | the script that reports how the pages are used, and a page that checks the script works ([docs/dev/telemetry.md](../../dev/telemetry.md)) |
| `POST /test_services/<name>` | stand-ins for outside services that always answer the same way, so that tests can rely on them (`le_services.pl`) |
| `/web_extras/…` | the further web applications: the Contract Assistant, the executive page and the documentation viewer |

---

## Starting the server

From the repository root:

```bash
swipl -g "use_module(classic_web_api), start_api_server(3050)" -t "repeat, sleep(1000), fail"
```

Calling `start_api_server/0` with no number uses port 3050. The server does its
work in threads of its own, so the goal after `-t` is there only to stop the
program from exiting, which is what the `Dockerfile` does too. In an
interactive `swipl` session, `?- start_api_server(3050).` is enough on its own.
The server refuses to start when another program already holds the port.
