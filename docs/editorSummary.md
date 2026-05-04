# Logical English 2 Editor — Technical Summary

## Architecture

The editor is a Monaco-based web IDE (`editor/src/`) with:
- **`client.ts`** — Monaco UI, file management, query panel, LSP client
- **`server.ts`** — LSP server running in a Web Worker (browser-side)
- **`le-language.ts`** — Monarch syntax-highlighting rules
- **`tokenizer.ts`** — Lexical analyser for LE syntax

The back-end is a SWI-Prolog HTTP server (`classic_web_api.pl`) exposing a single POST endpoint `/leapi` that dispatches by `operation` field.

---

## Editing

Monaco is initialised with the `le` language definition, providing:


- **Syntax highlighting** (`le-language.ts` and `server.ts`):
    - **Template-Aware Highlighting (Semantic Tokens)**: The LSP server extracts templates from the document and applies context-aware coloring to template instances. Template words are styled as plain text, while arguments (e.g., `an entity`, `ET`) are styled as variables. This ensures that template words (like `for`) are not incorrectly highlighted as logical keywords (like `or`).
    - **Section Headers**: `the knowledge base`, `scenario`, `query`, `the ontology`, `the predicates`, `the templates`, `the fluents`, `the events`, `the target language` (styled as `keyword.header`)
    - **Logical Keywords**: `includes`, `if`, `and`, `or`, `either`, `any of`, `all of`, `unless`, `which`, `for all cases in which`, `it is the case that`, `it is not the case that`, `not the case that`, `sum`, `count`, `average`, `min`, `max`, `is a`, `is an`, `such that` (styled as `keyword`)
    - **Test Keywords**: `expects answers` (styled as `keyword.expects`)
    - **Variables**: `*variable*` patterns, standalone capitalized IDs (e.g., `ET`, `ATR`), and arguments starting with `a`, `an`, `the`, `each`, or `some` (styled as `variable`)
    - **Strings**: Double-quoted `"..."` and single-quoted `'...'` strings with escape character support (styled as `string`)
    - **Numbers**: Integers and decimals (styled as `number`)
    - **Dates**: `YYYY-MM-DD` format (styled as `number.date`)
    - **Comments**: Single-line `%` and multi-line `/* ... */` (styled as `comment`)
    - **Operators**: Comparison operators like `<`, `>`, `<=`, `>=`, `==`, `!=`, `!`, `=` (styled as `operator`)
    - **Punctuation**: Brackets `[]`, `()`, `{}` and delimiters `.`, `,`, `:`

### Theme Colors

| Language Item | Dark Theme (`le-theme`) | Light Theme (`le-theme-light`) | High Contrast (`hc-black`) |
| :--- | :--- | :--- | :--- |
| **Section Headers** | `#569cd6` (Blue, Bold) | `#0000ff` (Blue, Bold) | White (Bold) |
| **Logical Keywords** | `#c586c0` (Purple) | `#af00db` (Purple) | `#c586c0` (Purple) |
| **Test Keywords** | `#c586c0` (Purple, Italic) | `#af00db` (Purple, Italic) | White (Italic) |
| **Variables / Arguments** | `#9cdcfe` (Light Blue) | `#001080` (Dark Blue) | `#9cdcfe` (Cyan) |
| **Template Words** | `#d4d4d4` (Light Gray) | `#000000` (Black) | White |
| **Strings** | `#ce9178` (Orange) | `#a31515` (Red) | `#ce9178` (Orange) |
| **Numbers / Dates** | `#b5cea8` (Light Green) | `#098658` (Green) | `#b5cea8` (Green) |
| **Comments** | `#6a9955` (Green) | `#008000` (Green) | `#7ca668` (Green) |
| **Operators / Punctuation** | `#d4d4d4` (Light Gray) | `#000000` (Black) | White |

- **Auto-closing pairs** — `[]`, `()`, `{}`, `""`, `''`, `**`
- **Code folding** (`textDocument/foldingRange`) — sections delimited by headers (e.g. `the knowledge base`, `scenario`, `query`) and individual rule bodies (head + indented lines)
- **Completions** (`textDocument/completion`, triggers: space, `*`) — templates extracted from the `the predicates/templates/fluents/events are:` sections, plus system comparison templates, section-header snippets, and logical keywords; the client applies smart overlap detection to avoid duplicate prefix insertion
- **Hover** (`textDocument/hover`) — returns the token type and value at the cursor
- **Quick Fixes** — missing template warnings provide a lightbulb action to automatically insert a template hypothesis into the `the templates are:` section.

Content changes are debounced (1 500 ms) before auto-triggering a module reload on the server.

### File Management

The editor supports local and server-side file operations:
- **New / Open / Save / Save As**: Standard file operations using the File System Access API (with fallback to traditional downloads).
- **Open from Server**: Browse and load built-in examples from the `examples/moreExamples/` directory.
- **Build Info**: Hovering over the editor title shows the current server build version.

---

## LE Assistant

A built-in chat interface allows users to interact with an LLM-powered agent. The assistant can:
- Explain Logical English code.
- Refactor rules or templates.
- Generate new LE code from natural language descriptions.
- Update the editor content directly with its suggestions.

Users can configure API keys and select models (OpenAI, Anthropic, Google, etc.) in the **Misc > API Keys...** menu.

---

## Navigation

| Feature | Status |
|---|---|
| Code folding by section / rule body | Implemented (LSP) |
| Hover token inspection | Implemented (LSP) |
| Go-to-definition / document outline | Not implemented |
| **Click node in explanation tree → highlight source range** | Implemented (client.ts) |
| **See PROLOG** | Implemented (Context Menu) — shows the Prolog translation of the term at cursor |
| **Copy URL** | Implemented (Context Menu) — copies a link to the current example and line |

The explanation-tree click handler uses `start`/`end` character offsets stored in each tree node (populated by `le_source/3` facts written during KB loading) to call `editor.setSelection()` and `editor.revealRange()`.

---

## Querying

### Load (`operation: "load"`)
Posts the current editor text to `/leapi`. The server parses the LE, creates a session module, runs the verifier, and returns:
- `sessionModule` — opaque session identifier
- `kb` — knowledge-base name
- `examples` — available scenario names → populates the Scenario dropdown
- `queries` — list of `{name, le, template}` → populates the Query dropdown
- `issues` — verifier diagnostics (see above)

### Answer query (`operation: "answeringQuery"`)
Posts `{sessionModule, query, scenario, customQuery?, customScenario?}`.  
The server:
1. Clears the session and loads the chosen scenario facts (or parses `customScenario` text).
2. Resolves the query (by name or by parsing `customQuery` text).
3. Calls `query/5` for each answer, returns `{answer, why}` pairs.
4. On no answers calls `query_explain` for a failure tree.

Results are rendered as a selectable list; clicking an answer shows the full **explanation tree** with collapsible nodes (green = success, red = failure, first two levels expanded by default).

### Other endpoints

| Operation | Purpose |
|---|---|
| `list_examples` | Lists `.le` files in `examples/moreExamples/` |
| `examples` | Returns content of a named example file |
| `loadFactsAndQuery` | Low-level: injects Prolog facts then calls `reasoner:i/4` directly |
| `query` | Direct Prolog goal against an arbitrary module |
| `answer`, `explain` | Legacy single-document load-and-query operations |

---

## Front-end / Back-end Communication Flow

```
User edits document
  → (1500 ms debounce) POST /leapi {operation:"load", le:"..."}
  ← {sessionModule, kb, examples, queries, issues}
  → Monaco markers set; dropdowns populated

User selects scenario + query → clicks Run Query
  → POST /leapi {operation:"answeringQuery", sessionModule, query, scenario, ...}
  ← {results:[{answer, why}, ...]}
  → Results list rendered; click answer → explanation tree rendered
  → Click tree node → editor.setSelection(start, end)
```

LSP features (completions, hover, folding) run entirely in the browser via a Web Worker and never hit the server.
