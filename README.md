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

[Learn more about LE Syntax](./docs/le_syntax.md) | [Cheat sheet](./docs/le_summary.md) | [View Examples](./examples/moreExamples/)

---

## 🛠 The Editor
The LE 2.0 environment provides a powerful, web-based IDE for developing and testing logic:

- **Real-time Feedback:** Instant syntax highlighting and error reporting as you type.
- **Integrated Debugger:** Step through logic and visualize explanation trees.
- **Scenario Testing:** Define "Scenarios" (facts) and "Queries" within the same file to verify behavior.
- **LSP Support:** Modern editor features including autocompletion and hover information.

[Editor Summary](./docs/editorSummary.md) | [Debugger Design](./docs/DebuggerDesign.md)

---

## 🐳 Deployment

### Environment Variables
You can configure the deployment using the following environment variables:
- `NO_RESTRICTIONS`: Set to `true` to disable example path restrictions.
- `ALLOWED_LE_EXPORTS`: Comma-separated list of allowed /source web endpoint export paths.
- `OPENAI_API_KEY`: API key for OpenAI models.
- `ANTHROPIC_API_KEY`: API key for Anthropic models.
- `GEMINI_API_KEY`, `GOOGLE_API_KEY`, `GOOGLE_GENERATIVE_AI_API_KEY`: API key for Google Gemini models.
- `GROQ_API_KEY`: API key for Groq models.
- `TOGETHER_API_KEY`, `TOGETHERAI_API_KEY`: API key for Together AI models.

### Local Installation (SWI-Prolog)
To run Logical English 2.0 on your local machine:

1. **Install SWI-Prolog:** Download and install [SWI-Prolog](https://www.swi-prolog.org/download/stable) (version 9.0 or later recommended).
2. **Clone the Repository:**
   ```bash
   git clone https://github.com/mcalejo/LogicalEnglish2.git
   cd LogicalEnglish2
   ```
3. **Start the Server:**
   ```bash
   swipl -g "use_module(classic_web_api), start_api_server(3050)" classic_web_api.pl
   ```
   The editor will be available at `http://localhost:3050/editor/`.

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
`le_kbs.pl` (currently the `insureLE2/` and `InsurLE2/` example trees). Add a row
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

- **Prolog unit tests (plunit):** `swipl -q -g run_tests -t halt testing/test_session_reaper.pl`
  (covers `testing/test_*.pl`).
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
Logical English 2.0 is also available as a pre-configured Docker image.

#### Quick Start
```bash
docker run -p 3050:3050 logicalcontracts/le2
```
The editor will be available at `http://localhost:3050/editor/`.

---

## 🏗 Architecture & API
LE 2.0 is built on **SWI-Prolog** for the reasoning engine and **TypeScript/Monaco** for the frontend.

- **Web API:** A JSON-RPC and REST API for loading KBs and running queries.
- **MCP Server:** Built-in support for the [Model Context Protocol](https://modelcontextprotocol.io), allowing LLMs (like Claude) to interact directly with your logic.

[API Documentation](./docs/api.md) | [MCP Setup](./llm/settings/README.md)

---

## 📝 Roadmap & To-Do
We are actively expanding LE 2.0. Under consideration:

### Features & Integration
- [ ] **LLM assistant:** Generate programs and scenario facts from free-form text or URLs.
- [ ] **Inter-module Calling:** Importing and calling logic across different LE files.
- [ ] **Prolog Bridge:** Calling arbitrary Prolog predicates with explanations.
- [ ] **Time & Durations:** Time expressions and intervals.
- [ ] **Debug Adapter Protocol (DAP):** Implement DAP for deeper integration with VS Code and other IDEs.
- [ ] **Generators:** Standalone Prolog and s(CASP) target generation.

### Language Evolution
- [ ] **Globals:** Support for global entities (e.g., `*The TaxPayer*`).
- [ ] **Proprietary Extensions:** Allow additions to the LE grammar and reasoner.

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