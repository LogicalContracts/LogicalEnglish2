# The LE Assistant

The **LE Assistant** is an AI helper embedded in the Logical English (LE) web
editor. It lets a user type a natural-language request — *"convert this
regulation into LE"*, *"why does scenario 2 fail?"*, *"add a rule for
late payments"* — and have an LLM read, write, **verify**, and debug the LE
program currently open in the editor.

Unlike a bare chat completion, the Assistant runs a full **agentic coding loop**:
the LLM can edit the program file, call the Logical English engine to verify it
and run its tests, read the error/warning output, and iterate until the program
parses cleanly and all tests pass — before reporting back to the user.

This document explains *what it does* and, in detail, *how it works*: the
architecture of the Prolog backend spawning [`opencode`](https://opencode.ai),
opencode driving an LLM, the loopback to the Logical English MCP server, and
every prompt involved.

---

## Table of Contents

- [What it does](#what-it-does)
- [Architecture at a glance](#architecture-at-a-glance)
- [The components](#the-components)
- [Request lifecycle (end-to-end)](#request-lifecycle-end-to-end)
- [The opencode invocation](#the-opencode-invocation)
- [The MCP loopback](#the-mcp-loopback)
- [The prompts](#the-prompts)
  - [1. The system prompt (`AGENTS.md`)](#1-the-system-prompt-agentsmd)
  - [2. The user command](#2-the-user-command)
  - [3. The MCP tool descriptions](#3-the-mcp-tool-descriptions)
  - [4. The required JSON answer](#4-the-required-json-answer)
- [Model selection and resolution](#model-selection-and-resolution)
- [Sessions and working directories](#sessions-and-working-directories)
- [Parsing the assistant's output](#parsing-the-assistants-output)
- [Configuration files](#configuration-files)
- [Security considerations](#security-considerations)
- [Code reference](#code-reference)

---

## What it does

From the user's perspective (the **Assistant** panel in `/editor`):

1. The user picks an LLM model (once) under **Misc → API Keys…** and enters or
   relies on a server-side API key for the chosen provider.
2. The user types a request and presses **Send**.
3. A progress indicator shows the live tail of the agent's activity. The user
   can **Interrupt** at any time.
4. When the agent finishes, the panel shows a Markdown **explanation** of what
   was done, and — if the program changed — the editor content is replaced with
   the **new program text**.

Behind that simple UX, the Assistant:

- Writes the editor content to a temporary `.le` file in a per-conversation
  working directory.
- Spawns `opencode` as a background coding agent pointed at that file.
- Gives the agent a Logical-English-specific **system prompt** plus tools to
  `verify` and `query` LE programs through the project's own MCP server.
- Lets the agent loop (edit → verify → read issues → fix) until clean.
- Captures the agent's final JSON (`explanation` + `new_content`) and returns it
  to the editor.

---

## Architecture at a glance

The whole thing is **self-referential**: the Prolog HTTP server both *launches*
the coding agent and *serves the verification tools the agent calls back into*.

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Browser — LE editor (editor/src/client.ts)                                │
│   • model picker + API keys (localStorage)                                 │
│   • Assistant panel: send / poll / interrupt                               │
└───────────────┬────────────────────────────────────────────────────────--─┘
                │  POST /leapi   { operation: assistant_command | _status |
                │                  _interrupt, command, content, session_id, │
                │                  api_keys, model }
                ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  SWI-Prolog HTTP server  (classic_web_api.pl, default port 3050)           │
│                                                                            │
│   /leapi  ──► le_assistant.pl                                              │
│        handle_assistant_command/2   (spawn job, return job_id)             │
│        handle_assistant_status/2    (poll stdout/stderr/result)            │
│        handle_assistant_interrupt/2 (kill the process)                     │
│                                                                            │
│   /mcp    ──► llm/mcp.pl   (tools: verify, query, get_example_details …)   │
└───────┬───────────────────────────────────────────────▲──────────────────┘
        │ process_create(opencode, …)                    │ MCP over HTTP
        │ env: API keys, OPENCODE_CONFIG                  │ (npx mcp-remote
        │ cwd: /tmp/le_assistant/<session>                │  127.0.0.1:3050/mcp)
        ▼                                                 │
┌──────────────────────────────────────────────────────-─┴──────────────────┐
│  opencode  (external CLI coding agent, background OS process)              │
│   • reads AGENTS.md (system prompt) + myProgram.le (the target file)       │
│   • agent loop: read → edit → call MCP verify/query → fix → repeat         │
│   • emits final JSON { explanation, new_content } on stdout                │
└───────────────┬────────────────────────────────────────────────────────--─┘
                │  HTTPS chat-completions
                ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  LLM provider  (OpenAI / Anthropic / Google / Groq / Together)             │
└──────────────────────────────────────────────────────────────────────────┘
```

Two distinct layers call an LLM in this codebase; the Assistant uses the first:

- **opencode (agentic).** The LE Assistant spawns the `opencode` CLI, which owns
  the conversation, the tool-calling loop, and the provider HTTP calls. The
  Prolog backend never talks to the LLM directly for the Assistant.
- **`llm/llm_client.pl` (direct).** A separate, simpler path that POSTs straight
  to a provider's chat-completions endpoint. It is **not** used to fulfil
  assistant commands; the Assistant only borrows its `llm_model/3` table to
  translate a short model name into a `provider/model` string for opencode.

---

## The components

| Component | File | Role |
|-----------|------|------|
| Editor client | `editor/src/client.ts` | UI: model picker, send/poll/interrupt, applies `new_content` |
| Web API router | `classic_web_api.pl` | Maps `/leapi` operations to handlers; mounts `/mcp` |
| Assistant backend | `le_assistant.pl` | Spawns/monitors `opencode`, manages jobs & sessions |
| MCP server | `llm/mcp.pl` | Exposes `verify`, `query`, `get_example_details`, … as MCP tools |
| Model table | `llm/llm_client.pl` | `llm_model/3` short-name → provider/API-model resolution |
| System prompt template | `AGENTS_LE_template.md` | Rendered to `AGENTS.md` in the work dir; the agent's instructions |
| opencode config template | `llm/settings/opencode_config.json.template` | MCP registration + provider/permission config for opencode |
| Static opencode config | `opencode.json` | Project-root opencode config (MCP + permissions) |

---

## Request lifecycle (end-to-end)

What happens for a single **Send**, following
`handle_assistant_command/2` in `le_assistant.pl`:

1. **Parse the request.** Read `command`, `content` (the current editor text),
   `session_id`, `api_keys`, and `model` from the JSON body. The `session_id` is
   normalised to start with `ses` (opencode's session-id convention).

2. **Resolve the working directory / session.**
   - If the incoming `session_id` looks like a real opencode id (>20 chars) and
     opencode knows it, the existing session's directory is reused (the
     conversation continues).
   - Otherwise a per-conversation directory `/tmp/le_assistant/<session_id>` is
     created, and `get_most_recent_opencode_session/2` tries to discover an
     existing opencode session for that directory (`opencode session list
     --format json`).

3. **Write the target file.** The editor content is written to
   `<workdir>/myProgram.le`. This is the **only** file the agent is allowed to
   edit.

4. **Resolve the model.** The short model name (e.g. `claude`, `gemini`) is
   turned into opencode's `provider/model` form via `llm_model/3`, remapping
   provider aliases (`gemini → google`, `together → togetherai`). See
   [Model selection](#model-selection-and-resolution).

5. **Build the environment.** `get_opencode_env/3` assembles the child process
   environment:
   - Base vars: `PATH`, `HOME`, `USER`, `SHELL`.
   - API keys from the request `api_keys` dict, else from the server's own
     environment variables, per provider (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`,
     `GEMINI_API_KEY`/`GOOGLE_API_KEY`/…, `GROQ_API_KEY`, `TOGETHER_API_KEY`/…).
   - `OPENCODE_CONFIG` pointing at a rendered config that registers the MCP
     server (see [MCP loopback](#the-mcp-loopback)).
   - `TERM=dumb`, `PAGER=cat`, `NO_COLOR=1` to keep output clean.
   - A special case: a `groq/…` model with an OpenAI key present also exports
     `GROQ_API_KEY`.

6. **Render the system prompt.** `create_agent_files/2` renders
   `AGENTS_LE_template.md` into `<workdir>/AGENTS.md`, substituting the project
   root and target filename. opencode auto-loads `AGENTS.md` as its instructions.

7. **Spawn opencode.** `process_create/3` launches `opencode run …` in the work
   dir as a **background process**, capturing stdout/stderr pipes. A `job_id` is
   returned to the client immediately.

8. **Stream output.** Two detached threads (`read_to_db/3`) drain stdout/stderr
   into `assistant_job_output/3` facts so the client's polling can show live
   progress. A third thread (`wait_for_job/6`) waits for the process to exit,
   re-reads `myProgram.le` (the agent may have rewritten it), records the
   final opencode session id, and marks the job `finished`.

9. **Client polls.** The browser calls `assistant_status` ~once per second
   (`pollAssistantStatus`). While `running`, it shows the last output line.

10. **Finish.** On `finished`, `handle_assistant_status/2` extracts the final
    JSON from stdout (`explanation`, `new_content`), strips ANSI codes, and
    returns them. The editor shows the explanation and, if `new_content`
    differs, replaces the buffer. The returned `session_id` is stored client-side
    so the next message continues the same opencode conversation.

> Wire-level request/response shapes for `assistant_command`, `assistant_status`
> and `assistant_interrupt` are documented in [`docs/api.md`](api.md).

---

## The opencode invocation

The Assistant shells out to the `opencode` binary. The command assembled in
`handle_assistant_command/2` is, conceptually:

```
opencode run --dangerously-skip-permissions \
    [--session <ActualSessionID>] \
    --file myProgram.le \
    --agent build \
    --format default \
    [--model <provider/model>] \
    "<the user's command>"
```

Notes:

- **`run`** is opencode's non-interactive, single-shot agent mode.
- **`--session`** is added only when a real, existing opencode session id is
  known, so a follow-up message resumes the same conversation (with full
  history) instead of starting fresh.
- **`--file myProgram.le`** attaches the LE program as context.
- **`--agent build`** selects opencode's coding agent (the one that reads
  `AGENTS.md` and may edit files and call tools).
- **`--model`** is omitted when empty, letting opencode use its own default.
- **`cwd`** is the per-session work dir; **`env`** carries keys + `OPENCODE_CONFIG`.

The process is created with `stdin(null)` and piped stdout/stderr. It runs fully
detached from the HTTP request that started it — the request returns a `job_id`
and the work continues in background threads.

`test_opencode_prompt/3` and `test_llm_providers/0` in the same module provide a
minimal, non-MCP variant of this invocation (`--agent general`) used to smoke-test
that each provider's key works.

---

## The MCP loopback

The agent needs to *actually run* the Logical English engine to verify programs
and execute queries. It does this through the **Model Context Protocol (MCP)**,
connecting back to the very same Prolog server that launched it.

- `get_opencode_env/3` sets `OPENCODE_CONFIG` to a JSON config that registers an
  MCP server named `logical-english`. The config is rendered from
  `llm/settings/opencode_config.json.template` (with `{{PROJECT_ROOT}}`
  substituted), or falls back to the static `llm/settings/opencode_config.json`.
- That config tells opencode to launch the MCP transport:

  ```json
  "mcp": {
    "logical-english": {
      "type": "local",
      "enabled": true,
      "command": ["npx", "mcp-remote", "http://127.0.0.1:3050/mcp"]
    }
  }
  ```

  i.e. `npx mcp-remote` bridges opencode's local MCP client to the HTTP MCP
  endpoint at `http://127.0.0.1:3050/mcp`.

- `/mcp` is handled by `handle_mcp/1` in `llm/mcp.pl` — the **same** server
  process (`classic_web_api.pl` mounts `http_handler(root(mcp), handle_mcp, [])`).

So the call graph closes a loop: **Prolog server → opencode → LLM →
(tool call) → mcp-remote → Prolog server (`/mcp`) → LE engine → back to the LLM.**

### Tools the agent can call

Defined in `llm/mcp.pl` (`tools/list` / `call_tool/3`):

| MCP tool | Purpose |
|----------|---------|
| `logical-english_verify` | Parse a program (`program_text`), return all `issues` (errors/warnings) **and** run embedded tests, returning `test_results` (pass/fail/error). |
| `logical-english_query` | Execute a `query` against a program/example, optionally in a named `scenario` and with extra `facts`; returns answers + an explanation tree. |
| `get_example_details` | Fetch a built-in example's text, templates and scenarios. |
| `list_examples` | List available example programs with summaries. |

The agent is also allowed standard opencode tools (`read`, `write`, `edit`,
`glob`, `grep`, `webfetch`, `bash`), but the system prompt restricts file
writes to the single target file and mandates verification via the MCP tools.

The permission blocks in the opencode configs pre-authorise the relevant
directories (`/tmp/le_assistant/**`, the project `docs/**` and
`examples/moreExamples/**`) so the `--dangerously-skip-permissions` run does not
stall on prompts.

---

## The prompts

There are **four** distinct prompt surfaces involved in one assistant turn.

### 1. The system prompt (`AGENTS.md`)

This is the heart of the Assistant's behaviour. `create_agent_files/2` renders
`AGENTS_LE_template.md` into `<workdir>/AGENTS.md`, which opencode loads
automatically as the agent's instructions. The template uses `~w` placeholders
filled (in order) with: project root, project root, target filename ×4.

It establishes:

- **Role & resources.** "You are an expert in Logical English." Points the agent
  at `docs/le_summary.md` for syntax and `examples/moreExamples/` for examples,
  and forbids fetching syntax docs from the web.
- **Core principles.** Accuracy, clarity, mandatory verification, and **safety**
  (only ever modify the provided target file, never other repo files).
- **Tools & verification.** Enumerates the allowed tools and insists that
  verification go through the `logical-english_verify` / `logical-english_query`
  MCP tools rather than ad-hoc shell commands.
- **How-tos / debugging playbook.** A symptom→action table the agent should
  follow for each class of LE issue, e.g.:
  - *Missing template* → generate a template for the sentence.
  - *Rule without variables* → move concrete data into scenarios.
  - *Predicate not tested by any query* → ask the user for a query and expected answers.
  - *Undefined predicate* → add a defining rule or a scenario fact (mine the
    regulatory text or web search).
  - *Test failure* → edit the program to fix it.
  - *time_limit_exceeded* → look for runaway recursion.
- **Regulatory-text → LE workflow.** A three-step procedure (Analyze → Write →
  Test/Debug), including writing a `specificationSummary.txt`, the expected
  macro-structure of an LE program (`the templates are: … the knowledge base …
  includes: …`), and rules of thumb (rules use variables; scenarios hold
  concrete facts; queries target rule-head predicates; provide `expected
  answers`; comparisons use Prolog operators).
- **The mandatory loop.** "You must not finish until `verify` returns no errors
  and all tests pass."
- **The output contract.** The final response **must** be a single JSON object —
  see [section 4](#4-the-required-json-answer).

### 2. The user command

The literal text the user typed in the Assistant panel is passed as the last
positional argument to `opencode run`. It is the task for this turn (e.g.
*"add a rule that a claim is rejected if it is filed late"*). Together with the
attached `--file myProgram.le`, this is what the agent acts on.

### 3. The MCP tool descriptions

Each MCP tool advertises a `description` in `tools/list` that doubles as prompt
guidance to the model. The most prescriptive is `query`:

> *"Execute a query. MANDATORY: You MUST call get_example_details first to get
> the correct templates. Your 'facts' and 'query' strings MUST match those
> templates EXACTLY, word-for-word, or the query will fail. Do not paraphrase or
> hallucinate templates."*

`verify` is described as *"Parse and verify a Logical English program, returning
all issues found."* `llm/mcp.pl` additionally defines MCP **prompts** (e.g.
`massage_query`) that an MCP client may fetch to coach the model into rewriting a
user's natural-language question into a template-exact LE query — useful for
non-agentic MCP clients (Claude Desktop, ChatGPT Actions) using the same server.

### 4. The required JSON answer

The system prompt requires the agent's final stdout to be a single JSON object:

```json
{
  "explanation": "A brief summary of what you did, in Markdown; refer to the file only as 'your program'.",
  "new_content": "The full, updated text content of the Logical English file"
}
```

`extract_json_from_string/3` recovers this object from the agent's stdout,
tolerating a fenced ```json block or a bare `{ … }`, and separating any
surrounding prose (`Explanation`) from the JSON. `handle_assistant_status/2`
then returns `explanation` as `stdout` and `new_content` to the client. If no
JSON is found, the raw stdout is returned and the file re-read from disk is used
as the new content fallback.

---

## Model selection and resolution

- The editor offers the models advertised by the server (`list_models`
  operation, backed by `llm_list_models/1` over the `llm_model_entry/4` table in
  `llm/llm_client.pl`). The chosen short name is stored in `localStorage` under
  `le-assistant-model`.
- Before sending, the client checks that an API key exists for the model's
  provider — either a **server-side** key (reported in the page bootstrap) or a
  **local** key the user pasted (stored as `le-<provider>-key`).
- The chosen short name plus the `api_keys` dict are sent with every
  `assistant_command`.
- Server-side, `llm_model/3` maps the short name to `Provider`/`APIModel`;
  provider aliases are remapped for opencode (`gemini → google`,
  `together → togetherai`), and the result is formatted as `provider/model` for
  `--model`. Unknown names fall back to passing the string through unchanged.

---

## Sessions and working directories

- Each editor conversation has a `session_id` (initially a random `ses_…`
  string generated client-side).
- The backend maps it to a working directory under `/tmp/le_assistant/` and,
  where possible, to a **real opencode session id** discovered via
  `opencode session list --format json` and matched by normalised directory
  (`normalize_path/2` strips `/private`, collapses slashes, etc.).
- After each run, `wait_for_job/6` re-discovers the most recent opencode session
  for the directory and returns it as `session_id`. The client adopts that id,
  so subsequent messages resume the same opencode conversation (history intact)
  via `--session`.
- `myProgram.le` and `AGENTS.md` are kept in the work dir between turns to
  facilitate this discovery and continuity.

---

## Parsing the assistant's output

`handle_assistant_status/2` post-processes the captured streams:

1. Concatenate all stdout/stderr chunks; **strip ANSI** escape sequences
   (`strip_ansi/2`).
2. `extract_json_from_string/3` pulls out the final JSON object.
3. If it has an `explanation`, that becomes the user-facing message; any
   non-JSON preamble is preserved/merged (unless it merely duplicates a path).
4. `new_content` from the JSON wins; otherwise the file re-read from disk by
   `wait_for_job/6` is used.
5. The response carries `status`, `exit_status`, `stdout` (explanation),
   `stderr` (logs), `new_content`, and `session_id`.

---

## Configuration files

| File | Used by | Purpose |
|------|---------|---------|
| `AGENTS_LE_template.md` | rendered → `<workdir>/AGENTS.md` | The agent's system prompt / instructions |
| `llm/settings/opencode_config.json.template` | rendered → `<workdir>/opencode_config.json` (`OPENCODE_CONFIG`) | Registers the `logical-english` MCP server, providers, and directory permissions; `{{PROJECT_ROOT}}` substituted at runtime |
| `opencode.json` | project root | Static opencode config (MCP + permissions) for running opencode directly in the repo |
| `llm/settings/claude_desktop_config*.json` | Claude Desktop | Connect Claude Desktop to the same MCP server (local or remote) |
| `llm/settings/chatgpt_openapi.yaml` | ChatGPT Actions | OpenAPI schema for the REST endpoints (`/query`, `/verify`, …) |

---

## Security considerations

- **`--dangerously-skip-permissions`.** opencode runs without interactive
  permission prompts, so it can edit files and call tools autonomously. This is
  contained by: running in an isolated `/tmp/le_assistant/<session>` work dir, a
  system prompt that forbids touching any file other than `myProgram.le`, and
  opencode `permission` config that only pre-authorises specific directories.
- **API keys.** Keys arrive per-request (`api_keys`) or come from the server's
  environment; they are injected into the child process environment only, not
  persisted by the backend. The browser stores user-supplied keys in
  `localStorage`.
- **Loopback MCP.** The agent's tool calls hit `127.0.0.1:3050/mcp` on the same
  host; the LE engine runs the user's program for `verify`/`query`. Treat the
  verification engine as executing untrusted LE (it is sandboxed by the LE
  interpreter's own evaluation model, not by the OS).
- **Token.** `/leapi` requires the API token (`myToken123` in the default
  build); change it for any non-local deployment.

---

## Code reference

| Predicate / symbol | File | Responsibility |
|--------------------|------|----------------|
| `handle_assistant_command/2` | `le_assistant.pl` | Spawn the opencode job, return `job_id` |
| `handle_assistant_status/2` | `le_assistant.pl` | Poll job; extract JSON; return explanation + content |
| `handle_assistant_interrupt/2` | `le_assistant.pl` | Kill a running job |
| `get_opencode_env/3` | `le_assistant.pl` | Build child env: API keys + `OPENCODE_CONFIG` + base vars |
| `get_dynamic_opencode_config/1` | `le_assistant.pl` | Render the MCP config template (`{{PROJECT_ROOT}}`) |
| `create_agent_files/2` | `le_assistant.pl` | Render `AGENTS_LE_template.md` → `AGENTS.md` |
| `get_most_recent_opencode_session/2` | `le_assistant.pl` | Discover the opencode session for a directory |
| `read_to_db/3`, `wait_for_job/6` | `le_assistant.pl` | Stream output; finalise job, re-read file, capture session id |
| `extract_json_from_string/3`, `strip_ansi/2` | `le_assistant.pl` | Recover the final JSON; clean terminal output |
| `llm_model/3`, `llm_model_entry/4` | `llm/llm_client.pl` | Short-name → provider/API-model table |
| `handle_mcp/1`, `call_tool/3` | `llm/mcp.pl` | MCP endpoint; `verify` / `query` / example tools |
| `handle_operation/2` (`assistant_*`) | `classic_web_api.pl` | Route `/leapi` operations to the backend |
| `handleAssistantSend`, `pollAssistantStatus`, `handleAssistantInterrupt` | `editor/src/client.ts` | Editor-side send/poll/interrupt + apply `new_content` |

---

*See also: [`docs/api.md`](api.md) for the `/leapi` wire protocol,
[`docs/le_summary.md`](le_summary.md) for LE syntax, and
[`llm/settings/README.md`](../llm/settings/README.md) for connecting external MCP
clients.*
