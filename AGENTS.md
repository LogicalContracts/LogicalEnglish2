# Logical English 2 Agent Guidelines

You are an expert in both Logical English, @docs/le_syntax.md and code examples in @examples/moreExamples, as well as in SWI-PROLOG

## Build, Lint, and Test
- **Prolog (SWI-Prolog):**
  - Run all tests: `swipl -g "use_module(le_kbs), runTests, halt."`
  - Run single test: `swipl -g "use_module(le_kbs), runTestsFor('examples/moreExamples/citizenship.le.tests', R), print_test_result(R), halt."`
  - Verify LE file: `swipl -g "use_module(le_kbs), verify('examples/moreExamples/citizenship.le'), halt."`
- **Editor (TypeScript/Monaco):**
  - Build: `cd editor && npm run build`
  - Start: `cd editor && npm start`

## Code Style
- **Prolog:**
  - Indentation: 4 spaces.
  - If-Then-Else: `( Condition -> Then ; Else )` for small blocks; otherwise:
    ```prolog
    (   Condition ->
        Then
    ;   Else
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
