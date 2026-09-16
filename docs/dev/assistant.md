# The LE Assistant

*Kind: design, as built · Audience: developers · Status: current (2026-09-16)*

The LE Assistant is the chat panel of the editor (tab **LE Assistant**). The
user types a request ("add a rule for late payments", "why does scenario 2
fail?"); an LLM reads the program open in the editor, changes it, verifies it
with the Logical English engine, and returns an explanation and the new
program text.

It runs in one of two modes, chosen with the **Light Mode** checkbox in the
panel header (default: light):

- **Light** (`le_assistant_light.pl`): a Prolog loop in the server calls the
  LLM directly and runs `verify` and `query` in-process. No external process,
  no files.
- **Deep** (`le_assistant.pl`): the server starts the `opencode` coding agent
  on a copy of the program; opencode calls back into the server's MCP endpoint
  to verify and query.

Both modes share the web operations, the job table, the model registry and the
key handling. Other LLM features are described elsewhere: the Contract
Assistant in [contract-assistant.md](contract-assistant.md); "Write it in
English…" in `nl_to_le.pl`.

## 1. Shared parts

### Operations

| `/leapi` operation | Handler | Does |
|---|---|---|
| `list_models` | `handle_list_models/2` (`classic_web_api.pl`) | `models` from `llm_list_models/1`; `server_keys`: the providers for which the server has a key |
| `assistant_command` | `handle_assistant_command/2` | starts a job, answers `{result: ok, job_id}` at once |
| `assistant_status` | `handle_assistant_status/2` | `running` with the output so far, or `finished` with `stdout` (the explanation), `stderr`, `new_content`, `exit_status`, `session_id` |
| `assistant_interrupt` | `handle_assistant_interrupt/2` | kills the opencode process (deep) or signals the thread (light) |

`assistant_command` fields: `command`, `content` (the editor text), `mode`
(`"light"` or `"deep"`; absent means deep), `model` (a short name),
`api_keys` (a dict by provider), `session_id` (deep), `max_steps` (light,
default 10). Wire details are in [the web API](../user/api/web-api.md).

### Jobs

`le_assistant.pl` keeps the job table as dynamic facts:
`assistant_job(JobID, PIDorThread)`, `assistant_job_status/2`
(`running` or `finished(Status)`), `assistant_job_output(JobID, Stream, Text)`
and `assistant_job_content/2`. Job ids are `job_<n>`. The client polls
`assistant_status` about once a second, shows the last output line as
progress, and on `finished` shows the explanation and replaces the document
text with `new_content` when it differs. A request belongs to the document tab
it was sent from, whichever tab is in front when it returns.

`handle_assistant_status/2` concatenates the output, strips ANSI escapes and
looks for the final JSON object with `extract_json_from_string/3` (a fenced
```` ```json ```` block, else the last parseable `{…}`). Its `explanation`
becomes `stdout` (with any non-JSON text before it) and its `new_content`
wins over the stored content.

### Models and keys

- **Registry**: `llm_model_entry(Short, Provider, APIModel, BaseURL)` in
  `llm/llm_client.pl`; providers `openai`, `anthropic`, `gemini`, `groq`,
  `together`. `llm_model/3` resolves a short name.
- **Client**: **Misc ▸ API Keys & Assistant Settings…** picks the model
  (`localStorage` `le-assistant-model`), the light-mode step limit
  (`le-assistant-max-steps`) and the user's own keys (`le-<provider>-key`,
  with `google` for Gemini). Before sending, the client refuses a model whose
  provider has neither a server key nor a local key. It sends all local keys
  with each command.
- **Server**: a key in the request wins; otherwise the environment
  (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY` / `GOOGLE_API_KEY` /
  `GOOGLE_GENERATIVE_AI_API_KEY`, `GROQ_API_KEY`, `TOGETHER_API_KEY` /
  `TOGETHERAI_API_KEY`) or a Prolog flag `llm_<provider>_key`.

### The instructions: `AGENTS_LE_template.md`

The system instructions of both modes. A YAML front matter names the
resources (`le_syntax_doc: docs/user/reference/language.md`,
`le_examples_dir`, `target_file`, `project_root`). The body gives the role,
the resources (the language reference, the extensions reference where the
server has the extensions, the examples), principles, how to react to verifier
issues (pointing at `docs/user/guide/warnings.md`), the
regulatory-text-to-LE workflow, the rule "do not finish until verify is clean
and all tests pass", and the output contract:

```json
{ "explanation": "Markdown; refer to the file as 'your program'",
  "new_content": "the full, updated program" }
```

Opencode-specific text (its tools, file handling) sits between
`<!-- DEEP_MODE_ONLY_START -->` and `<!-- DEEP_MODE_ONLY_END -->`. The body has
six `~w` placeholders (project root twice, target file four times).
`AGENTS_LE_template.pt.md` is the Portuguese version.

## 2. Light mode

`handle_assistant_command/2` with `mode: "light"` creates a detached thread
running `run_light_assistant_thread/7` in the request's UI language, and
records the thread as the job's target.

### The prompt (`assemble_system_prompt/3`)

The language is the program's (from its first statement), else the request's
UI language. The system message is, in order:

1. the template body (`localized_asset/3` picks the `.pt` file for
   Portuguese), front matter parsed and dropped, deep-only block removed,
   placeholders filled with `.` and "your program";
2. for a non-English language, an output-language directive;
3. the whole language reference, `docs/user/reference/language[.<lang>].md`,
   followed, when `le_extensions` is loaded and the reference is the English
   one, by `docs/user/reference/extensions.md` (`with_extensions_reference/3`);
4. examples: for English, a list of every example the user may open, with its
   `kbSummary` (`list_examples_with_summaries/4`, filtered by
   `restricted_paths`), plus the full text of six fixed files
   (`citizenship.le`, `language/unknowns/unknowns.le`,
   `domains/tax/1_net_asset_value_test_3.le`, `domains/tax/payg.le`,
   `dates.le`, `insureLE2/big_conclusions.le`, each if present and allowed);
   for another language, the full text of every `.le` in `examples/<lang>/`;
5. the action protocol (`tool_specification/1`);
6. the current program.

The user message is the command. There is no token budget: the prompt is
sent as assembled.

### The loop (`agent_loop/10`)

Each step checks the job is still `running`, calls
`llm_client:llm_request/4` with `api_key(Key)` and `max_tokens(4096)`, and
parses the reply's JSON with `extract_json_from_string/3`. There is no native
function calling; the model answers with one JSON action:

| Action | Effect |
|---|---|
| `{"action": "verify"}` | `le_tools:le_tool_verify/2` on the current program; the issues and test results go back as the next user message. With no issues and no test results, the message tells the model to finish |
| `{"action": "query", "query", "scenario", "facts"}` | `le_tools:le_tool_query/2` on the current program (an `example_name` the model adds is dropped); the answers go back. The scenario is read from `scenario` (or `scenario_name`) |
| `{"action": "edit", "new_content"}` | replaces the in-memory program; the reply asks the model to verify |
| `{"action": "finish", "explanation", "new_content"}` | ends the job |

A reply without JSON, or with an unknown action, gets a one-line correction
and costs a step. After a clean verification, a further `verify` or `query`
ends the job as a success with the program as it is. At `max_steps` the job
ends with "Reached step limit before completion." and the current program.

Progress lines (localized through `i18n/messages.csv`) go to
`assistant_job_output/3`. On success the thread writes the final
`{explanation, new_content}` JSON to stdout, so the status handler treats both
modes alike. An exception or an interrupt (`thread_signal(…, throw(interrupt))`)
finishes the job with the original program.

Light mode keeps no conversation between commands: each command starts from
the editor's current text, and `session_id` is ignored.

## 3. Deep mode

### A command

1. **Work directory.** `session_id` is normalised to start with `ses`. A long
   id that `opencode session list` knows reuses that session's directory;
   otherwise the directory is `/tmp/le_assistant/<session_id>`, and the most
   recent opencode session for it, if any, is used.
2. The editor text is written to `<dir>/myProgram.le`, the only file the
   instructions allow the agent to change.
3. `AGENTS_LE_template.md` (always the English one) is written to
   `<dir>/AGENTS.md` with the deep-only markers removed and the placeholders
   filled with the server's working directory and `myProgram.le`.
4. **Model.** The short name becomes `provider/model` for opencode, with
   `gemini` → `google` and `together` → `togetherai`; an unknown name passes
   through; no model means opencode's default.
5. **Environment** (`get_opencode_env/4`): `PATH`, `HOME`, `USER`, `SHELL`;
   the provider keys as environment variables; `TERM=dumb`, `PAGER=cat`,
   `NO_COLOR=1`; and `OPENCODE_CONFIG`, a per-job file
   `/tmp/le_assistant/opencode_config_<job>.json` rendered from
   `llm/settings/opencode_config.json.template`.
6. **Process.**

   ```
   opencode run --dangerously-skip-permissions [--session <id>]
       --file myProgram.le --agent build --format default [--model <p/m>] "<command>"
   ```

   Two threads copy stdout and stderr into `assistant_job_output/3`; a third
   (`wait_for_job/7`) waits for the exit, re-reads `myProgram.le`, discovers
   the opencode session id of the directory and marks the job finished.
7. **Recovering the work.** If the file is unchanged but the agent verified
   a different program during this job, that program becomes the result
   (`le_tools:get_last_verified_program/3`). The MCP URL in the rendered config
   carries `?job=<JobID>`, so `/mcp` records verified programs under that job.

The returned `session_id` is stored on the client's document, so the next
command continues the same opencode conversation.

### The MCP loopback

The rendered config registers an MCP server `logical-english` whose command is
`npx mcp-remote http://127.0.0.1:3050/mcp?job=<JobID>`: opencode's MCP
client reaches the same Prolog server (`llm/mcp.pl`, `handle_mcp/1`). The
template also sets a base URL for Together and allows the external directories
`/tmp/le_assistant/**`, `/app/**`, `<root>/docs/**` and
`<root>/examples/moreExamples/**`. The port 3050 is fixed in the template.

`llm/mcp.pl` offers:

| Kind | Items |
|---|---|
| tools | `verify` (`program_text` → issues and test results), `query` (`query` plus `example_name` or `program_text`, optional `scenario_name`, `facts` → answers with explanations), `get_example_details`, `list_examples`. The flag `mcp_only_query_verify` hides the last two. opencode shows them as `logical-english_verify`, … |
| prompts | `use_logical_english`, `massage_query`, `massage_facts`: for chat clients that rewrite a user's question or facts into template-exact LE |
| resource | `le://docs/syntax`: `docs/user/reference/language.md` |

`verify` and `query` are `le_tools:le_tool_verify/2` and `le_tool_query/2`,
the same predicates light mode calls. The REST endpoints `/verify`, `/query`,
`/list_examples` and `/example_details` expose them too. Configuration for
other MCP clients is in [Logical English over MCP](../user/api/mcp.md).

## 4. Comparison

| | Light | Deep |
|---|---|---|
| Runs | a thread in the server | an `opencode` process per command |
| Needs | nothing beyond the server | `opencode`, `node`/`npx`, `mcp-remote` (installed in the Docker image) |
| LLM call | `llm/llm_client.pl` | opencode |
| Tools | `verify`, `query`, `edit`, `finish` as JSON actions | opencode's file, search, web and shell tools, plus MCP `verify` and `query` |
| Context | language reference and examples inlined | files read on demand |
| Program | a string in memory | `myProgram.le` in a work directory |
| Memory across commands | none | the opencode session |
| Language | the program's (localized template, reference, examples) | English instructions |
| Stops at | `finish`, a repeated check after a clean verify, or `max_steps` | the agent's own end |

## 5. Security

- **The API token** of `/leapi` is the constant `myToken123`, checked by
  `validate_token/1` and sent by every page. It separates nothing.
- **Deep mode** runs opencode with `--dangerously-skip-permissions` (and the
  image sets `OPENCODE_DANGEROUSLY_SKIP_PERMISSIONS=true`). It can run shell
  commands as the server's user. What limits it is the work directory, the
  instructions ("only modify the provided file") and opencode's
  `external_directory` permissions — not an OS sandbox.
- **Keys** from the request go into the child's environment (deep) or into the
  HTTP call (light), and are not stored by the server. The browser keeps
  user-supplied keys in `localStorage`.
- **Examples**: light mode lists and inlines only examples allowed for the
  user's roles. The MCP and REST example listing leaves out the role-gated
  trees; `get_example_details` and `query` with `example_name` do not check
  `is_path_allowed/2`, so they open any example whose name is known.
- **Running programs**: `verify` and `query` run the submitted program with
  the LE reasoner; `prolog` goals inside programs are sandboxed
  (`reasoner.pl` uses `library(sandbox)`).

## 6. Code reference

| Symbol | File |
|---|---|
| `handle_assistant_command/2`, `handle_assistant_status/2`, `handle_assistant_interrupt/2` | `le_assistant.pl` |
| `get_opencode_env/4`, `get_dynamic_opencode_config/2`, `create_agent_files/2`, `get_most_recent_opencode_session/2`, `wait_for_job/7`, `extract_json_from_string/3` | `le_assistant.pl` |
| `run_light_assistant_thread/7`, `agent_loop/10`, `assemble_system_prompt/3`, `load_agent_template/2`, `load_curated_examples/2`, `tool_specification/1` | `le_assistant_light.pl` |
| `le_tool_verify/2`, `le_tool_query/2`, `get_last_verified_program/3`, `set_verify_job/1` | `le_tools.pl` |
| `handle_mcp/1`, REST handlers | `llm/mcp.pl` |
| `llm_request/4`, `llm_model/3`, `llm_list_models/1`, `api_key/2` | `llm/llm_client.pl` |
| `handleAssistantSend`, the mode toggle, the model and key dialog | `editor/src/client.ts` |
| `test_llm_providers/0` (smoke test of each provider through opencode) | `le_assistant.pl` |
