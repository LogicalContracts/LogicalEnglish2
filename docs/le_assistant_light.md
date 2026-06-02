# The LE Assistant — "Light" mode

> **Status: Implemented.**
> This document describes the lighter implementation of the
> [LE Assistant](le_assistant.md). It shares the same chat UI and the
> same building blocks (the `AGENTS_LE_template.md` instructions, the LLM API
> keys, the model registry, the `verify`/`query` engine), while replacing the
> external `opencode` process and the MCP loopback with a small **Prolog-native
> agentic loop**.

The user chooses between the two with a single **Light / Deep** toggle in the
Assistant panel:

- **Deep** — the existing assistant (`le_assistant.pl`): spawns `opencode`, full
  tool ecosystem (file system, web, grep, MCP), heavier, slower to start, depends
  on `opencode` + `node`/`npx`.
- **Light** — this design (`le_assistant_light.pl`): Prolog drives the LLM
  directly via `llm/llm_client.pl`, with two **in-process tools** (`verify`,
  `query`) that make direct Prolog calls. No external process, no MCP, no
  temporary directory, no Node. The program being edited is an **in-memory
  string** that the loop evolves turn by turn.

---

## Table of Contents

- [Why a Light mode](#why-a-light-mode)
- [What stays the same](#what-stays-the-same)
- [What changes](#what-changes)
- [Architecture at a glance](#architecture-at-a-glance)
- [The Prolog agentic loop](#the-prolog-agentic-loop)
- [In-process tools: `verify` and `query`](#in-process-tools-verify-and-query)
- [The prompt assembly](#the-prompt-assembly)
- [The tool-call protocol (no native function-calling)](#the-tool-call-protocol-no-native-function-calling)
- [Recommended changes to `AGENTS_LE_template.md`](#recommended-changes-to-agents_le_templatemd)
- [API keys and model resolution](#api-keys-and-model-resolution)
- [The evolving program (no temp dir)](#the-evolving-program-no-temp-dir)
- [UI changes: the Light/Deep toggle](#ui-changes-the-lightdeep-toggle)
- [Wire protocol](#wire-protocol)
- [Reuse and refactoring plan](#reuse-and-refactoring-plan)
- [Comparison: Light vs Deep](#comparison-light-vs-deep)
- [Limitations and risks](#limitations-and-risks)
- [Proposed code reference](#proposed-code-reference)

---

## Why a Light mode

The Deep assistant is powerful but heavy:

- It requires the `opencode` binary plus `node`/`npx` (`mcp-remote`) on the host.
- Every tool call is an HTTP round-trip through `mcp-remote` to `/mcp` and back
  into the same Prolog process — a loop that is operationally fragile and adds
  latency.
- It needs a per-session temporary directory and a rendered `AGENTS.md`, and it
  discovers/threads opencode session ids.
- Startup cost is significant for what is often a small edit.

For many requests — *"add a rule"*, *"fix this warning"*, *"why does scenario 2
fail?"* — a far simpler loop suffices: ask the model, run `verify`/`query` in
the same Prolog VM, feed results back, repeat. That is the Light mode.

---

## What stays the same

The Light mode deliberately **reuses** the Deep mode's ingredients:

| Ingredient | Reused for Light? | Notes |
|------------|-------------------|-------|
| Chat UI (Assistant panel) | ✅ same panel | adds a Light/Deep checkbox only |
| `/leapi` operations (`assistant_command` / `_status` / `_interrupt`) | ✅ same | a new `mode` field selects the backend |
| Job model (`assistant_job*` facts, polling, interrupt) | ✅ same shape | Light asserts progress lines for the same poll loop |
| `AGENTS_LE_template.md` | ✅ (adapted) | parsed for resources + inlined as system prompt |
| LLM API keys (request `api_keys` or server env) | ✅ same resolution | fed to `llm_client` instead of to a child env |
| Model registry `llm_model/3` / `llm_list_models/1` | ✅ same | same model picker |
| `verify` / `query` semantics | ✅ same engine | called directly, not via MCP/HTTP |
| Output contract `{ explanation, new_content }` | ✅ same | same editor handling |
| `extract_json_from_string/3` | ✅ reused | parse tool calls and the final answer |

---

## What changes

Three substantive differences from Deep:

1. **No `opencode`.** A small Prolog loop (`le_assistant_light.pl`) owns the
   conversation and the tool-calling cycle.
2. **No MCP / HTTP loopback.** `verify` and `query` are *custom tools* that call
   the `le_kbs` predicates **directly, in-process**. No `mcp-remote`, no `/mcp`,
   no JSON-over-HTTP for tools.
3. **Prolog calls the LLM directly** via `llm/llm_client.pl`, assembling a single
   larger prompt that **inlines** the LE syntax summary and a curated set of LE
   examples (because, unlike opencode, this agent has no file-reading tools).
4. **No temp dir, no `myProgram.le` on disk.** The program is an in-memory string
   threaded through the loop and updated each turn.

---

## Architecture at a glance

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Browser — LE editor (editor/src/client.ts)                                │
│   • model picker + API keys (localStorage)                                 │
│   • Assistant panel: send / poll / interrupt   • NEW: Light/Deep checkbox  │
└───────────────┬────────────────────────────────────────────────────────--─┘
                │  POST /leapi  { operation: assistant_command, mode:"light",
                │                 command, content, session_id, api_keys, model }
                ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  SWI-Prolog HTTP server (classic_web_api.pl)                               │
│   /leapi ─► dispatch on mode:                                              │
│      mode=deep  ─► le_assistant.pl        (spawn opencode — existing)      │
│      mode=light ─► le_assistant_light.pl  (Prolog agentic loop — NEW)      │
└───────────────┬────────────────────────────────────────────────────────--─┘
                │ (all in one Prolog process — no child process, no MCP)
                ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  le_assistant_light.pl — agentic loop                                      │
│                                                                            │
│   ┌─ assemble prompt (system = AGENTS rules + LE syntax + examples +       │
│   │                    tool spec + current program)                        │
│   ▼                                                                        │
│   llm_client:llm_request(Model, Messages, Reply, Options)  ───────────────┐│
│   │                                                                       ││
│   ├─ parse Reply:                                                         ││
│   │    • {action:"verify"}        ─► le_kbs:load_text + le_issue + tests  ││
│   │    • {action:"query", …}      ─► le_kbs:createSession + run_query     ││
│   │    • {action:"finish", …}     ─► return {explanation, new_content}    ││
│   │                                                                       ││
│   └─ append tool result to Messages, loop (≤ MaxSteps)  ◄─────────────────┘│
└───────────────┬────────────────────────────────────────────────▲─────────┘
                │ HTTPS chat-completions (llm_client)              │ direct Prolog
                ▼                                                  │ calls (le_kbs)
┌────────────────────────────────────────────────┐   ┌────────────┴───────────┐
│ LLM provider (OpenAI/Anthropic/Gemini/Groq/…)   │   │ Logical English engine │
└────────────────────────────────────────────────┘   │ (le_kbs / reasoner)    │
                                                       └────────────────────────┘
```

Contrast with Deep, where the LLM is reached *through* `opencode` and the tools
are reached *through* `mcp-remote → /mcp`. In Light, both arrows are short: a
direct HTTPS call for the model, and a direct predicate call for the tools.

---

## The Prolog agentic loop

A sketch of the intended control flow (illustrative, not final code):

```prolog
% le_assistant_light.pl
run_light_assistant(JobID, Command, Program0, Model, Keys, FinalExplanation, FinalProgram) :-
    assemble_system_prompt(Program0, SystemPrompt),         % inlines syntax+examples+rules
    Messages0 = [ role(system, SystemPrompt),
                  role(user,   Command) ],
    agent_loop(JobID, Model, Keys, Messages0, Program0, 0,
               FinalExplanation, FinalProgram).

agent_loop(JobID, _, _, _, Program, Step, Expl, Program) :-
    Step >= max_steps, !,                                   % budget exhausted
    Expl = "Reached step limit before completion.".
agent_loop(JobID, Model, Keys, Messages, Program, Step, Expl, FinalProgram) :-
    job_not_interrupted(JobID),                             % cooperative interrupt check
    with_keys(Keys, llm_client:llm_request(Model, Messages, Reply, [max_tokens(4096)])),
    progress(JobID, "model replied (step ~w)"-[Step]),
    ( parse_action(Reply, Action) ->
        handle_action(JobID, Action, Program, Messages, Program1, Messages1, Done, Expl0),
        ( Done == true ->
            Expl = Expl0, FinalProgram = Program1
        ; Step1 is Step + 1,
          agent_loop(JobID, Model, Keys, Messages1, Program1, Step1, Expl, FinalProgram)
        )
    ; % no recognizable action: nudge the model and retry
      append(Messages, [role(assistant, Reply),
                        role(user, "Please respond with a single JSON action object.")], Messages1),
      Step1 is Step + 1,
      agent_loop(JobID, Model, Keys, Messages1, Program, Step1, Expl, FinalProgram)
    ).
```

Key properties:

- **Bounded.** A `max_steps` budget prevents runaway loops (e.g. 6–12 steps).
- **Cooperative interrupt.** `assistant_interrupt` flips a flag the loop checks
  before each model call (see [Wire protocol](#wire-protocol)).
- **Streaming progress.** Each step asserts a short line via the same
  `assistant_job_output/3` channel the existing poll UI reads.
- **In-memory program.** `Program` is a string threaded through the loop; a
  `verify`/`query` tool runs against whatever the model last produced.
- **Stateless transport.** No session files; conversation state is the in-memory
  `Messages` list for the duration of the job. (Cross-turn continuity options
  are discussed in [The evolving program](#the-evolving-program-no-temp-dir).)

---

## In-process tools: `verify` and `query`

The two tools mirror the MCP tools in `llm/mcp.pl` but skip the HTTP/JSON
transport, calling `le_kbs` directly. They should be **factored into shared
predicates** (see [Reuse plan](#reuse-and-refactoring-plan)) so MCP and Light use
one implementation.

**`verify(ProgramText) -> Issues + TestResults`** (same as
`call_tool("verify", …)`):

```prolog
le_tool_verify(ProgramText, _{issues: Issues, test_results: Tests}) :-
    le_kbs:load_text(ProgramText, KB),
    findall(_{severity:Sev, type:Type, message:Msg, fix:Fix, start:S, end:E},
            KB:le_issue(Sev, Type, Msg, Fix, S, E), Issues),
    ( current_predicate(KB:le_expected/3) ->
        findall(test(Q,Sc,A), KB:le_expected(Q,Sc,A), TS),
        maplist(le_kbs:run_one_test(KB), TS, R),
        maplist(convert_test_result, R, Tests)
    ; Tests = [] ).
```

**`query(ProgramText, Query, Scenario, Facts) -> Answers + Why`** (same as
`call_tool("query", …)`): `load_text` → `createSession` → optional
`setScenarion` → optional `parse_custom_facts`/`addSessionFact` → `run_query`.

Because these run in the same VM, the model's `verify`/`query` results are exactly
what the editor's own Verify button would show — there is a single source of truth
for LE semantics.

> The tool *outputs* are serialised to compact JSON/text and appended to the
> conversation as the next `user` message, so the model can read and react to
> them (the same information the Deep agent would get from an MCP tool result).

---

## The prompt assembly

The Deep agent reads files from disk on demand (`read`, `glob`, `docs/le_summary.md`,
the `examples/` tree). The Light agent has **no file tools**, so the relevant
material must be **inlined** into the system prompt. `assemble_system_prompt/2`
concatenates, in order:

1. **The instruction body** — the prose from `AGENTS_LE_template.md`
   (role, principles, the debugging playbook, the regulatory-text→LE workflow,
   the mandatory "iterate until clean" rule, and the JSON output contract), with
   opencode-specific bits adapted (see
   [recommended changes](#recommended-changes-to-agents_le_templatemd)).
2. **LE syntax** — the full text of `docs/le_summary.md` (~10 KB; small enough
   to inline verbatim).
3. **Curated examples** — a selected subset of `examples/moreExamples/*.le`
   (the tree totals ~236 KB across 31 files — too large to inline wholesale).
   Selection strategies (configurable):
   - a fixed small set of representative/teaching examples (e.g. `citizenship.le`,
     a scenario/expected-answers example, a numbered-rules example);
   - and/or examples whose `kbSummary/2` or templates are most relevant to the
     user's request (lightweight keyword match).
4. **Tool specification** — the JSON action protocol the model must use
   (see next section), including the exact field names for `verify`/`query`.
5. **The current program** — the editor content (`content`) delimited clearly,
   labelled as "your program".

A **token budget** governs how many examples are inlined; the assembler trims to
fit the chosen model's context window. This is the main cost difference from Deep
(which pays per-tool-call retrieval instead of one big prompt).

---

## The tool-call protocol (no native function-calling)

`llm/llm_client.pl`'s `build_body/5` emits a **plain chat-completions** body —
it does not send an OpenAI/Anthropic `tools`/`functions` schema, and
`extract_answer/3` only reads the text `content`. Therefore the Light agent uses
a **text-based action protocol** rather than provider-native function calling:

The model is instructed to reply with **exactly one JSON object** per turn, one of:

```json
{ "action": "verify" }
```
```json
{ "action": "query", "query": "…", "scenario": "…", "facts": "…" }
```
```json
{ "action": "edit", "new_content": "…the full updated program…" }
```
```json
{ "action": "finish",
  "explanation": "Markdown summary; refer to the file as 'your program'.",
  "new_content": "…the full, verified program…" }
```

The loop:

- `verify` / `query` → run the in-process tool, append its result as a `user`
  message, continue.
- `edit` → replace the in-memory program (the model rewrote it); typically the
  model then asks to `verify` it.
- `finish` → terminate; return `explanation` + `new_content` to the client.

Parsing reuses `extract_json_from_string/3` (already tolerant of fenced ```json
blocks and bare `{…}`). If the reply contains no parseable action, the loop nudges
the model once and retries, counting against the step budget.

> *Optional future enhancement:* extend `llm_client.pl` with real function-calling
> (`tools` field + `tool_calls` parsing) for providers that support it, and fall
> back to the text protocol otherwise. The text protocol is the portable baseline.

---

## Recommended changes to `AGENTS_LE_template.md`

Today the template is rendered for opencode only, using **positional `~w`
placeholders** (project root ×2, target filename ×4) filled by
`create_agent_files/2`. That is opaque: a second consumer (the Light loop) cannot
easily learn *which files to inline* or *what the target is*.

Recommendation: make the resource paths and target **machine-extractable and
shared** so both consumers can parse them:

1. **Add a structured, stable header** (YAML frontmatter or a fenced
   `resources` block) with named keys, e.g.:

   ```yaml
   ---
   le_syntax_doc: docs/le_summary.md
   le_examples_dir: examples/moreExamples/
   target_file: myProgram.le        # Deep mode only; Light edits in memory
   project_root: .
   ---
   ```

   - **Deep mode** keeps rendering the prose (opencode reads the whole file as
     `AGENTS.md`); paths can be absolutised at render time as today.
   - **Light mode** parses these keys to know which syntax doc and examples
     directory to inline, and ignores `target_file` (it edits in memory).

2. **Factor the instructions into mode-neutral vs mode-specific sections.** Keep
   the role, principles, debugging playbook, regulatory-text workflow and JSON
   contract **shared**. Move the opencode-only bits (the list of opencode tools,
   "only edit `myProgram.le`", `webfetch`, `bash`) into a clearly marked block
   that the Light assembler can **drop or replace** with the Light tool spec.

3. **Make the tool references abstract.** Instead of naming
   `logical-english_verify`, say "the `verify` tool" / "the `query` tool" so the
   same wording fits both the MCP tool names (Deep) and the JSON-action protocol
   (Light). Each mode appends its concrete tool-calling syntax.

4. **Keep the JSON output contract identical** in both modes
   (`{ explanation, new_content }`) so the editor handling is unchanged.

This makes `AGENTS_LE_template.md` the single source of LE-authoring guidance,
consumed by *both* a generic agent (opencode, which reads it as a file) and the
Prolog loop (which parses the header and inlines the body).

---

## API keys and model resolution

- The model picker and key plumbing are unchanged: the client sends `model` plus
  the `api_keys` dict, exactly as for Deep.
- **Key delivery differs.** Deep injects keys into the child process *environment*
  (`get_api_env/2`). Light must hand keys to `llm/llm_client.pl`, whose
  `api_key/2` reads from **Prolog flags or environment variables**. Two clean
  options:
  - **(a)** Before each job, set the per-provider Prolog flags
    (`llm_openai_key`, `llm_anthropic_key`, `llm_groq_key`, `llm_gemini_key`,
    `llm_together_key`) from the request `api_keys` (reusing the same
    provider→key mapping as `get_api_env/2`), within a `setup_call_cleanup/3`
    that restores them afterwards.
  - **(b)** Extend `llm_request/4` with an `api_key(Key)` option so keys are
    passed explicitly and never stored in global flags. *(Preferred — avoids
    global state and is concurrency-safe.)*
- **Model resolution** uses `llm_model/3` to get `Provider`/`APIModel`, which is
  exactly what `llm_client` expects natively — note that Light needs **no**
  `provider/model` string remapping (that remap exists only to feed opencode's
  `--model`).

---

## The evolving program (no temp dir)

- There is **no** `/tmp/le_assistant/<session>` directory and **no**
  `myProgram.le` file. The program starts as the `content` field from the request
  and lives as a Prolog string threaded through `agent_loop/8`.
- `verify`/`query` operate on that string via `le_kbs:load_text/2` (which already
  loads from text, not a path).
- The final `new_content` is whatever the loop holds at `finish`.
- **Cross-turn continuity.** Since there is no persisted session, a follow-up
  message naturally restarts the loop with the *editor's current content* (which
  already reflects the previous turn's accepted `new_content`). If richer
  multi-turn memory is wanted, options are: (a) keep the prior `Messages` list in
  a `dynamic` fact keyed by `session_id`, or (b) rely on the program text itself
  as the carried state (simplest, and usually sufficient).

---

## UI changes: the Light/Deep toggle

Minimal, additive changes in `editor/src/client.ts` and the Assistant panel
markup:

- Add a **checkbox / segmented toggle** "Light" vs "Deep" near the model picker.
  Persist the choice in `localStorage` (e.g. `le-assistant-mode`), defaulting to
  Light for speed (or Deep — a product decision).
- In `handleAssistantSend`, include `mode: <"light"|"deep">` in the
  `assistant_command` body. **No other UI logic changes**: `pollAssistantStatus`,
  the progress tail, the interrupt button, the explanation rendering, and the
  `new_content` application all work unchanged because both backends speak the
  same job/status/finish protocol.
- Progress text for Light shows the loop's step lines (e.g. *"verify → 2 issues",
  "querying scenario 1", "fixing…"*) just like the Deep tail.

---

## Wire protocol

Identical to the existing endpoints (see [`docs/api.md`](api.md)) with one new
field:

- `assistant_command` request gains **`mode: "light" | "deep"`** (default to a
  configured value if absent). `handle_assistant_command/2` (or a thin dispatcher
  in `classic_web_api.pl`) routes to `le_assistant_light.pl` when `mode == "light"`.
- `assistant_status` / `assistant_interrupt` are unchanged. Light reuses the same
  `assistant_job/2`, `assistant_job_status/2`, `assistant_job_output/3`,
  `assistant_job_content/2` facts, so polling and interrupt "just work".
- The `finished` response keeps the same shape: `stdout` (the explanation),
  `stderr` (optional log/trace), `new_content`, and `session_id` (Light may echo
  the incoming id unchanged, since it has no opencode session to discover).

---

## Reuse and refactoring plan

To avoid duplicating LE semantics, factor the tool bodies out of `llm/mcp.pl`:

1. **Extract** the engine logic from `call_tool("verify", …)` and
   `call_tool("query", …)` into shared predicates (e.g. `le_tool_verify/2` and
   `le_tool_query/5`) in a small new module `le_tools.pl` (or in `le_kbs`).
2. **`llm/mcp.pl`** becomes a thin adapter: parse MCP args → call `le_tools` →
   wrap as MCP JSON.
3. **`le_assistant_light.pl`** calls the same `le_tools` predicates directly and
   serialises results into the conversation.
4. **Share** the prompt-source utilities with `le_assistant.pl`: API-key
   resolution (today `get_api_env/2`), `extract_json_from_string/3`, and the
   `assistant_job*` job/streaming machinery — consider lifting these into a shared
   helper used by both modes.
5. **Adapt `AGENTS_LE_template.md`** as in
   [recommended changes](#recommended-changes-to-agents_le_templatemd); add a
   loader that returns `(ResourceMap, InstructionBody)` for the Light assembler
   and still renders `AGENTS.md` for Deep.

---

## Comparison: Light vs Deep

| Aspect | Light (this design) | Deep (`opencode`) |
|--------|---------------------|-------------------|
| LLM transport | Direct, `llm/llm_client.pl` | Via `opencode` |
| Tool transport | Direct Prolog calls (`le_kbs`) | MCP over HTTP (`mcp-remote` → `/mcp`) |
| External deps | None (pure Prolog + HTTPS) | `opencode`, `node`/`npx`, `mcp-remote` |
| Tools available | `verify`, `query` (+ `edit`/`finish` actions) | Full: read/write/edit/glob/grep/webfetch/bash + MCP |
| Files on disk | None (in-memory program) | Temp dir + `myProgram.le` + `AGENTS.md` |
| Context strategy | Inline syntax + curated examples up front | Retrieve files on demand via tools |
| Function calling | Text JSON-action protocol | opencode-native tool calling |
| Startup latency | Low | Higher (process spawn + MCP bootstrap) |
| Capability ceiling | Lower (single file, no web/shell) | Higher (multi-file, web, shell) |
| Best for | Quick edits, fixes, explanations | Large tasks, regulation→program from scratch, web research |

---

## Limitations and risks

- **Context window.** Inlining the syntax doc + examples + program consumes
  tokens; very large programs or many examples may not fit. Mitigate with example
  curation and a token budget; surface a clear message if the program is too big.
- **Protocol adherence.** Weaker models may not reliably emit a single JSON
  action. Mitigations: strict instructions, a nudge-and-retry step (counted),
  and reusing the tolerant `extract_json_from_string/3`.
- **No file/web tools.** Light cannot fetch regulatory text from a URL or browse
  the repo. Requests needing those should use Deep (the toggle makes this a user
  choice; the assembled prompt can also suggest switching to Deep when web
  research is required).
- **Concurrency / keys.** Prefer the explicit `api_key(Key)` option over setting
  global Prolog flags, so concurrent Light jobs don't clobber each other's keys.
- **Loop cost.** Each step is a full prompt; keep `max_steps` modest and prefer
  having the model batch edits before verifying.

---

## Proposed code reference

*(All new/changed symbols — none implemented yet.)*

| Predicate / symbol | File | Responsibility |
|--------------------|------|----------------|
| `handle_assistant_command/2` (dispatch on `mode`) | `classic_web_api.pl` / `le_assistant*.pl` | Route Light vs Deep |
| `run_light_assistant/7` | `le_assistant_light.pl` (new) | Entry point for a Light job |
| `agent_loop/8` | `le_assistant_light.pl` (new) | Bounded model↔tool loop with interrupt checks |
| `assemble_system_prompt/2` | `le_assistant_light.pl` (new) | Inline instructions + syntax + examples + tool spec + program |
| `parse_action/2` | `le_assistant_light.pl` (new) | Parse the model's JSON action (reuses `extract_json_from_string/3`) |
| `le_tool_verify/2`, `le_tool_query/5` | `le_tools.pl` (new) | Shared in-process `verify`/`query` (also used by `llm/mcp.pl`) |
| `with_keys/2` or `llm_request/4` `api_key/1` option | `le_assistant_light.pl` / `llm/llm_client.pl` | Feed per-request keys to `llm_client` |
| `load_agent_template/2` | `le_assistant_light.pl` (new) | Parse `AGENTS_LE_template.md` header (resources) + body |
| `assistant_job*` facts, `read`/progress helpers | shared with `le_assistant.pl` | Job tracking, streaming, interrupt — reused unchanged |
| Light/Deep toggle + `mode` field | `editor/src/client.ts` | UI selection, persisted in `localStorage` |

---

*See also: [`docs/le_assistant.md`](le_assistant.md) for the Deep mode,
[`docs/api.md`](api.md) for the `/leapi` wire protocol, and
[`docs/le_summary.md`](le_summary.md) for the LE syntax the Light prompt inlines.*
