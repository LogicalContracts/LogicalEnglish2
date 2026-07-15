# Logical English 2 Agent Guidelines

You are an expert in both Logical English (LE) and SWI-PROLOG. 
Refer to `docs/le_summary.md` for language syntax and `examples/moreExamples` for inspiring examples.

## Build, Lint, and Test
In what follows, SWIPL refers to the `./myswipl.sh` wrapper at the repo root. It
selects the SWI-Prolog interpreter to use: the `$SWIPL` env var if set, otherwise
the macOS app bundle (`/Applications/SWI-Prolog10.0.0-1.app/Contents/MacOS/swipl`)
when present, otherwise `swipl` on PATH. You can also just call `swipl` directly if
it is on your PATH.

### Run everything: `testing/run_tests.sh`
The `testing/run_tests.sh` runner runs all suites and aggregates a single pass/fail
(non-zero exit if any suite that ran failed). It always runs from the repo root, so
you can call it from anywhere. Use it as the default check:
- `testing/run_tests.sh` — all suites (unit + LE examples + Playwright e2e).
- `testing/run_tests.sh --no-e2e` — fast path: Prolog unit + LE examples only.
- `testing/run_tests.sh unit | le | e2e` — run a single suite (space-separated subsets allowed).
- Set `SWIPL=...` to choose the interpreter; set `CI=1` to make a missing e2e setup
  a failure instead of a skip.

The three suites it wraps (also runnable directly):
- **Prolog unit tests (plunit):** `SWIPL -q -g run_tests -t halt testing/test_session_reaper.pl`
  — fast, no server. Lives in `testing/test_*.pl`; add new ones there with
  `:- begin_tests(Name). ... :- end_tests(Name).` and `testing/run_tests.sh unit` picks them up.
  Use `:- use_module('../le_kbs').` (the module is one level up from `testing/`).
- **Logical English example tests:** `SWIPL -g "use_module(le_kbs), runTests, halt."`
  (single LE test: `SWIPL -g "use_module(le_kbs), runTestsFor('examples/moreExamples/citizenship.le', R), print_test_result(R), halt."`
  — tests are embedded in scenarios via `expects answers`; separate `.le.tests`
  files are no longer used. Non-English example trees live under
  `examples/<lang>/` (e.g. `examples/pt/`) and are run by the same suite.)
- **Editor E2E (Playwright):** `cd editor && npm run test:e2e` (add `-- --headed` to run visibly).

Other Prolog/editor commands:
- Verify LE file: `SWIPL -g "use_module(le_kbs), verify('examples/moreExamples/citizenship.le'), halt."`
- Editor build: `cd editor && npm run build`; start: `cd editor && npm start`.

**IMPORTANT:** You MUST run `testing/run_tests.sh` (which covers the Prolog unit, LE
example, and Editor E2E Playwright suites) after completing every feature or making
any changes. Do NOT commit your changes to git.

## Code Style
- **Prolog:**
  - Indentation: 4 spaces.
  - If-Then-Else: `( Condition -> Then ; Else )` for small blocks; otherwise:
    ```prolog
    ( Condition1 ->
          Then1
        ; Condition2 ->
          Then2
        ;  
          Else
    )
    ```
  - Modules: Use `:- module(name, [exports]).` and `thread_local` for temp state.
  - Error Handling: Use `catch/3` for exceptions; return `Issues` list for parsing.
- **TypeScript:**
  - Indentation: 4 spaces. Use `vscode-languageserver/browser` for LSP.
  - Types: Use strict TypeScript types; avoid `any`.

## Naming Conventions
- Prolog: `snake_case` for predicates, `CamelCase` for variables.
- LE Functors: `snake_case` derived from template words (e.g., `is_born_in_on`).

## Multilingual LE
Every natural-language surface (grammar keywords, system templates,
diagnostics, UI strings) lives in the CSV dictionaries under `i18n/` — see
`i18n/README.md`. A program declares its language in its first statement
(`the target language is: prolog.` / `a linguagem alvo é: prolog.` / ...).
Never hardcode keyword or message strings in code: add rows/columns to the
CSVs and look them up through `le_i18n.pl` (backend) or `editor/src/i18n.ts`
(editor; tables generated at build time).
