# Logical English 2.0

**Logical English (LE)** is a controlled natural language for legal and business logic. It allows experts to write executable rules that look like plain English, which are then automatically translated into formal logic (Prolog) for reasoning and explanation.

LE 2.0 is a modernized, high-performance implementation of the original [Logical English](https://github.com/LogicalContracts/LogicalEnglish) project.

🚀 **[Try the Live Demo](https://le2.logicalcontracts.com)**

---

## 📖 The Language
Logical English is designed to be readable by non-programmers while remaining mathematically precise.

- **Template-based:** Define your own natural language patterns (e.g., `*a person* acquires British citizenship on *a date*`).
- **Rule-oriented:** Write logic using `if`, `and`, `or`.
- **Explainable:** Every answer comes with a justification tree in natural language.
- **Typed:** Built-in support for types, dates, and arithmetic.

[Language reference](./docs/user/reference/language.md) | [Tutorial](./docs/user/tutorials/intro-to-le/intro-to-le.md) | [All documentation](./docs/README.md) | [Examples](./examples/README.md)

---

## 🛠 The Editor
The LE 2.0 environment provides a powerful, web-based IDE for developing and testing logic:

- **Real-time Feedback:** Instant syntax highlighting and error reporting as you type.
- **Explanations:** Every answer, and every failure, with a navigable explanation tree; a step-by-step tracer.
- **Scenario Testing:** Define "Scenarios" (facts) and "Queries" within the same file, with expected answers.
- **Language server:** Autocompletion, hover, folding and quick fixes, running in the browser.
- **Assistants:** The LE Assistant edits and repairs the open program with an LLM; the Contract Assistant turns a contract into a tested program.

[Using the editor](./docs/user/guide/editor.md) | [Architecture](./docs/dev/architecture.md) | [Debugger](./docs/dev/debugger.md) | [LE Assistant](./docs/dev/assistant.md)

---

## 🐳 Deployment

### Environment Variables
You can configure the deployment using the following environment variables:
- `NO_RESTRICTIONS`: Set to `true` to disable the role restrictions on example trees (`restricted_paths.pl`).
- `ALLOWED_LE_EXPORTS`: Comma-separated directories whose examples the `/source/` endpoint may serve (fly.toml sets `examples/moreExamples`).
- `OPENAI_API_KEY`: API key for OpenAI models.
- `ANTHROPIC_API_KEY`: API key for Anthropic models.
- `GEMINI_API_KEY`, `GOOGLE_API_KEY`, `GOOGLE_GENERATIVE_AI_API_KEY`: API key for Google Gemini models.
- `GROQ_API_KEY`: API key for Groq models.
- `TOGETHER_API_KEY`, `TOGETHERAI_API_KEY`: API key for Together AI models.
- `LE_CONTRACT_JOBS_DIR`: where the Contract Assistant keeps its jobs (default `contract_jobs/`).
- `LE_MODEL_PRICES_URL`, `LE_MODEL_PRICES_FILE`, `LE_MODEL_PRICES_CACHE`: where the LLM price table for cost estimates comes from (default: LiteLLM's table on GitHub, cached in `tmp/model_prices.json`).
- `LE_SENTRY_DSN`, `LE_CLOUDFLARE_ANALYTICS_TOKEN` (and `LE_SENTRY_ENVIRONMENT`, `LE_SENTRY_RELEASE`): error reports to Sentry, with a feedback form, and Cloudflare Web Analytics; off unless set, and set (as fly secrets) only on the deployed server. See [docs/dev/telemetry.md](./docs/dev/telemetry.md).

### Local Installation (SWI-Prolog)
To run Logical English 2.0 on your local machine:

1. **Install SWI-Prolog:** Download and install a recent [SWI-Prolog](https://www.swi-prolog.org/download/stable) (the Docker image uses `swipl:latest`).
2. **Clone the Repository:**
   ```bash
   git clone https://github.com/LogicalContracts/LogicalEnglish2.git
   cd LogicalEnglish2
   ```
3. **Start the Server** (from the repository root):
   ```bash
   swipl -g "use_module(classic_web_api), start_api_server(3050)"
   ```
   The landing page is at `http://localhost:3050/` and the editor at `http://localhost:3050/editor/`.
   The editor's bundles (`editor/dist/`) are committed, so Node.js is only needed to rebuild them ([editor/README.md](./editor/README.md)).

Optional components:
- **s(CASP):** `swipl -g "pack_install(scasp)"` enables the s(CASP) engine (`le_scasp.pl`).
- **Deep mode of the LE Assistant:** `npm install -g opencode-ai mcp-remote` ([docs/dev/assistant.md](./docs/dev/assistant.md)).
- **LPS:** programs with `the target language is: lps.` run on an LPS2 server beside this one.
- **Proprietary extensions:** `le_extensions.pl`, when present next to `le_kbs.pl`, adds the constructs of [docs/user/reference/extensions.md](./docs/user/reference/extensions.md); `le_importers.pl`, likewise a link into the private lpsPlus repository, adds the importers and exporters of other systems.

### Testing

The quickest way to run everything is the aggregate runner in `testing/`
(it always runs from the repo root, regardless of your current directory):

```bash
testing/run_tests.sh            # run all suites and report a combined pass/fail
testing/run_tests.sh --no-e2e   # skip the browser tests (fast: unit + LE examples)
testing/run_tests.sh unit       # only the Prolog plunit suite
testing/run_tests.sh le         # only the Logical English example tests (core)
testing/run_tests.sh e2e        # only the Playwright browser tests

testing/run_tests.sh --with-extensions       # LE examples incl. extension-dependent trees
testing/run_tests.sh le --with-extensions    # ... just that suite
```

It exits non-zero if any suite that ran failed. The Playwright suite is skipped
(not failed) when its prerequisites are missing, unless `CI` is set. Override the
interpreter with `SWIPL=/path/to/swipl testing/run_tests.sh`.

#### LE example suite: core vs core + extensions

The Logical English example suite comes in two variants:

| suite | what it runs | when |
|---|---|---|
| **core** (default) | Every example that runs on this repository alone. | **Gate CI on this.** It is the suite a clean checkout can make green. |
| **all** (`--with-extensions`) | core, plus the example trees that need the proprietary `le_extensions.pl` — a symlink into a sibling repository. | Only when those extensions are installed. |

The extension-dependent programs use constructs the core grammar does not
implement, so without `le_extensions.pl` they do not merely fail — they cannot be
parsed, and their failures say nothing about core LE. That is why they are not in
the default suite.

The exclusion is a hardwired table, `extension_dependent_path_fragment/1` in
`le_kbs.pl` (currently the `insureLE2/`, `InsurLE2/` and `lpsPlus/` example trees). Add a row
there when a new extension-dependent tree appears; nothing else changes.

Each variant writes its **own** status snapshot, and neither run touches the
other's:

| suite | status file | |
|---|---|---|
| core | `testSuiteCoreStatus.txt` | reproducible from a clean checkout |
| all | `testSuiteStatus.txt` | needs `le_extensions.pl` to mean anything |

Both are tracked here. A repository that does not have the extensions should
**ignore `testSuiteStatus.txt`** — it cannot reproduce it — and read
`testSuiteCoreStatus.txt` instead. Each file's header names the suite it ran, when,
and the sibling file, so opening the wrong one tells you where the other is. Both
are snapshots of a single run, not curated baselines: to gate CI, use the exit
status of `testing/run_tests.sh`.

#### Running the suites directly

- **Prolog unit tests (plunit):** `testing/run_tests.sh unit` loads every `testing/test_*.pl` and runs
  them together; one file alone runs with `swipl -q -g run_tests -t halt testing/test_session_reaper.pl`.
- **Logical English example tests:** `swipl -g "use_module(le_kbs), runTests, halt."`
  runs the **core** suite; `runAllTests` (equivalently `runTests(all)`) adds the
  extension-dependent trees. Each refreshes its own status file. Expectations live
  inside each scenario as `<query> expects answers [...] and unknowns [...]`;
  sibling `.le.tests` files are deprecated — still read if present, but none remain
  in the corpus and new examples must not add them.
- **E2E Tests (Playwright):**
  ```bash
  cd editor
  npm install
  npm run build
  npm run test:e2e
  ```
  To run tests visibly, use `npm run test:e2e -- --headed` or `npx playwright test --ui`.

### Docker Deployment
The `Dockerfile` builds an image with SWI-Prolog, the s(CASP) pack, Node.js, `opencode` and `mcp-remote`, and builds the editor:

```bash
docker build -t le2 .
docker run -p 3050:3050 le2
```
The editor will be available at `http://localhost:3050/editor/`.

The public deployment runs on fly.io (`fly.toml`): `buildPush.sh` builds the image from a copy of the tree with symlinks dereferenced (so the proprietary extensions and examples are included) and runs `fly deploy --local-only`. API keys are set as fly secrets.

---

## 🏗 Architecture & API
LE 2.0 is built on **SWI-Prolog** for the reasoning engine and **TypeScript/Monaco** for the frontend.

- **Web API:** `POST /leapi`, a JSON API (one `operation` per request) for loading programs, running queries and using every feature of the editor.
- **MCP Server:** `/mcp`, for the [Model Context Protocol](https://modelcontextprotocol.io), with REST equivalents, so LLM clients can verify and query programs.
- **Debug Adapter Protocol:** `/dap`, over a WebSocket.

[Architecture](./docs/dev/architecture.md) | [Web API](./docs/user/api/web-api.md) | [MCP](./docs/user/api/mcp.md) | [Developer documentation](./docs/README.md)

---

## 📝 Roadmap

**Done** (formerly on this list): the LLM assistants (LE Assistant, light and deep; Contract Assistant; "Write it in English…"); calling across LE files (included resources, `lib/` libraries); Prolog resources and embedded `prolog` goals; dates and durations (`lib/temporal.le`); the step-by-step debugger over DAP; s(CASP) and LPS execution targets; global constants (definite descriptions, `defines global`); the proprietary extension hook (`le_extensions.pl`); contextual help in the editor (a **?** on each panel, diagnostics linking to where they are explained).

**Open:**
- [ ] **Debugger:** a DAP transport that desktop IDEs such as VS Code can attach to (the editor's debugger has breakpoints, step, step over, continue and stop: [docs/dev/debugger.md](./docs/dev/debugger.md)).
- [ ] **Contract Assistant:** the faithfulness audit (every proof step supported by a quotation) and coverage as a fitness term, both designed but not built ([docs/dev/contract-assistant.md](./docs/dev/contract-assistant.md) §9).

---

## ⚖️ Licensing and Copyright

All software in this repository is licensed under the **Apache License 2.0** except where noted.

**Copyright holders by country:**
- LodgeIT (AU)
- AORA Law, Axiome (UK)
- AINexus (USA)
- Bob Kowalski (UK)
- Miguel Calejo (PT)
- Jacinto Dávila (VE)

**Special thanks to:** Andrew Noble, John Cummins, Chris and Bruce Mennell, Galileo Sartor and Faramarz Farhoodi.

For the legacy implementation and historical context, visit the [original Logical English repository](https://github.com/LogicalContracts/LogicalEnglish).

---