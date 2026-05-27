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
- **Prolog Tests:** `swipl -g "use_module(le_kbs), runTests, halt."`
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