# Architecture of LogicalEnglish2

*Kind: architecture reference · Audience: developers · Status: current (2026-09-16)*

LogicalEnglish2 (LE2) is one SWI-Prolog process that parses, verifies and runs
Logical English programs and serves everything a browser needs: the editor, a
JSON API, an MCP server, a debug adapter and a few smaller web apps. The
editor is TypeScript bundled with esbuild; it has no server of its own.

```
browser pages ──POST /leapi {token, operation, …}──►  classic_web_api.pl
   editor/*.html (Monaco + dist/*.js)                    │
   web_extras/{executive,contract_assistant,docsview}    ├─ le_kbs ─ le_grammar ─ tokenizer
                  ──WebSocket /dap──────────────────►     │    ├─ reasoner, le_verifier, …
LLM agents (opencode, Claude Desktop) ──/mcp──────►       ├─ llm/mcp.pl, le_tools.pl
                                                          └─ assistants → llm/llm_client.pl → LLM providers
```

## 1. The Prolog server

Start it with `swipl -g "use_module(classic_web_api), start_api_server(3050)"`
(the default port is 3050). `start_api_server/1` refuses a port that is
already in use, loads `build_info.txt`, starts the model-price fetch
(`llm/llm_prices.pl`) and the session reaper, and runs `http_server/2` with 24
workers.

### Routes (`classic_web_api.pl`)

| Route | What |
|---|---|
| `POST /leapi` | the JSON API: one request dict with `token` and `operation`, dispatched by `handle_operation/2` (42 operations; see [the web API](../user/api/web-api.md)). The token is checked against the constant `"myToken123"`. `?lang=` sets the message language of the request |
| `/mcp`, `GET /list_examples`, `POST /query`, `/verify`, `/example_details` | the MCP server and its REST equivalents (`llm/mcp.pl`) |
| `/dap` | WebSocket debug adapter (`dap_server.pl`, see [debugger.md](debugger.md)) |
| `/editor/…`, `/web_extras/…` | static files, sent with `Cache-Control: no-cache` |
| `/` | landing page: examples tree, executive view link, documentation list (from `docs/user/nav.json`), a button that runs the example test suite |
| `/multilingual`, `/executive` | a language picker, or with `?lang=` a landing page for `examples/<lang>/`; the executive view |
| `/docs/…` | the user documentation, only under `docs/user/` (`public_doc/1`); a document name answers the markdown viewer `web_extras/docsview/viewer.html`; old paths redirect (`doc_moved/2`) |
| `/source/<example>` | an example's `.le` text, only under the directories listed in `ALLOWED_LE_EXPORTS` and allowed for the user's roles |
| `/login`, `/logout`, `/whoami` | sessions for users of `le_users.db` (`le_users.pl`); roles gate example trees (`restricted_paths.pl`) |
| `/telemetry.js`, `/telemetry_test` | Sentry and Cloudflare configuration, off unless configured ([telemetry.md](telemetry.md)) |
| `POST /test_services/…` | stub services for programs that declare services (`le_services.pl`) |
| `/build_info` | the build string |

A failing operation is logged, reported to Sentry when configured, and
answered with HTTP 500.

### Modules

**Language core**

| Module | Role |
|---|---|
| `tokenizer.pl` | text to tokens: indentation, words, numbers, dates, strings, comments |
| `le_grammar.pl` | the DCG and the second pass that turns sentences into Prolog clauses, templates, scenarios, queries |
| `le_system_templates.pl` | built-in templates (comparisons, arithmetic); word forms from `i18n/system_templates.csv` |
| `le_i18n.pl` | loads `i18n/*.csv`; keywords, messages and UI strings of the active language; `localized_asset/3` picks `<file>.<lang>.md` when present |
| `le_kbs.pl` | the main interface: `load/2`, `load_text/2` (each program becomes a KB module), reasoning sessions (`createSession/2`, scenarios, a reaper for sessions idle over 30 min), `query/5`, explanations, the example test runner (`runTests/0`, `runAllTests/0`, the status files), example names and aliases, included resources. Loads `le_extensions.pl` if present |
| `reasoner.pl` | meta-interpreter: conjunction, disjunction, negation as failure, aggregates, unknowns, success and failure explanation trees; the DAP tracer hooks |
| `le_verifier.pl` | load-time checks behind the editor's diagnostics (missing templates, undefined or untested predicates, rules without variables, …) |
| `le_extensions.pl` | **optional, proprietary**: a symlink into InsurLE2. `which`, `unless` in bodies, grouped alternatives, numbered bodies, `prolog` goals, prepositional chaining ([extensions.md](../user/reference/extensions.md)) |
| `le_importers.pl` | **optional, proprietary**: a symlink to lpsPlus's `migration/le_importers.pl`, the table of importers and exporters of other systems that `le_import.pl` reads ([migration.md](migration.md)) |

**Regulatory constructs** (language reference §17), all loaded by `le_kbs`:
`le_provenance.pl` (provenance trailers), `le_tables.pl` (decision tables),
`le_sections.pl` (applicability / question / remedy), `le_services.pl`
(service-backed templates with a cache), `le_flip.pl` (flip queries),
`le_views.pl` (view sections), `le_documents.pl` (the text of a cited
document), `le_why_not.pl` (unmet conditions of a failed query).
`lib/temporal.le` + `lib/temporal.pl` and `lib/deontic.le` are LE libraries a
program includes.

**Execution targets and translations**

| Module | Role |
|---|---|
| `le_scasp.pl` | emits s(CASP) from a loaded KB and runs it with `library(scasp)` (the `scasp` pack; optional) |
| `le_lps.pl` | LE for LPS (`the target language is: lps.`) to LPS internal syntax with provenance; LPS2 runs it (`/lpsapi`, a separate server) |
| `le_lps_legal.pl`, `le_lps_write.pl` | the legal view of an LPS program; LPS internal syntax back to LE |
| `le_service.pl` | the surface LPS2 loads LE2 through, in-process |
| `le_writer.pl`, `le_migration.pl` | Migration IR to LE text; migration ledger and source tests as scenarios ([migration.md](migration.md)) |
| `le_import.pl` | File ▸ Open of other systems' files and Export; registries `importer/6`, `exporter/6`. The translators themselves are in InsurLE2 |
| `le_graph.pl` | KB graph for Cytoscape ([graph.md](graph.md)) |
| `le_proof_game.pl` | rules and facts for the Proof Game |

**LLM features** ([assistant.md](assistant.md), [contract-assistant.md](contract-assistant.md))

| Module | Role |
|---|---|
| `le_assistant.pl` | LE Assistant, deep mode: runs `opencode` as a background job; job table shared with light mode |
| `le_assistant_light.pl` | LE Assistant, light mode: in-process agent loop |
| `le_tools.pl` | `verify` and `query` tools shared by MCP and light mode |
| `le_contract_assistant.pl` | Contract Assistant: materials to a tested program, as a background job (`contract_*` operations) |
| `nl_to_le.pl` | "Write it in English…": English to facts or a query body, verified (`nl_to_le` operation) |
| `le_issue_feedback.pl` | ranks verifier issues for an LLM repair round (Contract Assistant, `nl_to_le`) |
| `llm/llm_client.pl` | OpenAI-compatible client, model registry `llm_model_entry/4`, API keys from request, flags or environment |
| `llm/le_llm.pl` | lets an embedder (LPS2) substitute its own client; used by `nl_to_le.pl` |
| `llm/llm_prices.pl` | LiteLLM price table, for cost estimates |
| `llm/mcp.pl` | MCP server (tools, prompts, resource `le://docs/syntax` = `docs/user/reference/language.md`) and REST endpoints; see [MCP](../user/api/mcp.md) |

**Server infrastructure**: `classic_web_api.pl`, `dap_server.pl`,
`le_users.pl`, `restricted_paths.pl`, `le_telemetry.pl`.

## 2. The editor (`editor/`)

Each page is an HTML file that loads one bundle from `editor/dist/`. The
editor and LPS pages load Monaco 0.45 from cdnjs through its AMD loader.

| Page | Bundle (source) | What |
|---|---|---|
| `index.html` | `client.ts` | the editor: documents and tabs, load and diagnostics, queries and explanations, LE Assistant panel, debug panel, menus |
| — (Web Worker) | `server.ts` | language server: semantic tokens, completions, hover, folding, diagnostics. `client.ts` talks JSON-RPC to it over `postMessage` and registers the Monaco providers itself |
| `scenario-editor.html`, `query-editor.html`, `scenario-variations.html` | same names | form-based scenario and query building; share `scenario-form.ts`, `nl-input.ts`, `le-templates.ts`, `explanation-view.ts` |
| `explanation-drill.html`, `bento-box.html` | same names | other readings of an explanation |
| `proof-game.html` | `proof-game.ts` | the Proof Game (Rete with its React renderer) |
| `graph.html` | `graph-client.ts` | the KB graph (Cytoscape) |
| `lps.html` | `lps-view.ts` | LE for LPS: `getLps` on LE2, then compile and run on LPS2 |
| `hierarchy.html` | inline script | type hierarchy |
| — | `le-views.ts`, `source-viewer.ts` | bundled separately, imported by the executive view |

Smaller modules: `le-language.ts` and `lps-language.ts` (Monarch),
`tokenizer.ts` (for the worker), `i18n.ts` (UI string lookup), `editor-tabs.ts`,
`resource-nav.ts`, `share-url.ts`, `mermaid-export.ts`.

**Build.** `cd editor && npm install && npm run build`. The `build` script
first runs `scripts/gen-i18n.cjs`, which writes `src/generated/i18nData.ts`
from `i18n/*.csv`, then runs esbuild once per entry point (ESM). The bundles
in `editor/dist/` are committed, so a checkout runs without Node. The Docker
build ignores them (`.dockerignore`) and rebuilds. Build and launch steps are
in [editor/README.md](../../editor/README.md).

## 3. `web_extras/`

| Directory | What |
|---|---|
| `executive/` | the executive view (`/executive`): runs an example without editing, renders a program's views with `editor/dist/le-views.js`. Plain JS |
| `contract_assistant/` | the Contract Assistant web app, at `/web_extras/contract_assistant/index.html`. Plain JS |
| `docsview/` | the markdown viewer for `/docs/…` (`marked.min.js`, the `nav.json` sidebar) |
| `telemetry/` | the page-side telemetry script behind `/telemetry.js` |

## 4. Around the code

- **`i18n/`**: CSV dictionaries (keywords, system templates, messages, UI
  strings, languages, writer words); the only place for natural-language
  strings. See [i18n/README.md](../../i18n/README.md).
- **`examples/`**: example programs by purpose, see
  [examples/README.md](../../examples/README.md). Trees that need
  `le_extensions.pl` are excluded from the core test suite by
  `extension_dependent_path_fragment/1` in `le_kbs.pl`.
- **`docs/`**: `user/` (published), `dev/`, `project/`; see
  [docs/README.md](../README.md). The LLM features read
  `docs/user/reference/language.md` and `AGENTS_LE_template*.md` by path.
- **`testing/`**: `run_tests.sh` runs the plunit files `testing/test_*.pl`,
  the LE example suite (`runTests`) and the Playwright suite in `editor/tests/`,
  which starts its own server on port 3000. `testing/fixtures/` holds the
  programs the tests load.
- **Deployment**: `Dockerfile` (base `swipl:latest`, plus Node 20, `opencode-ai`
  and `mcp-remote`, the `scasp` pack, and an editor build),
  `buildPush.sh` (builds from a dereferenced copy of the tree, then
  `fly deploy --local-only`), `fly.toml`.
- **Sibling repositories**: InsurLE2 (`le_extensions.pl` and the examples of
  those constructs), lpsPlus (`le_importers.pl` and the translators behind it,
  the domain models and the twins whose sources may not be published) and lps2
  (runs LE-for-LPS programs; loads
  LE2 as a library through `le_service.pl`; the interface is lps2's
  `docs/dev/le-lps-interface.md`).
