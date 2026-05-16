# Logical English 2 Agent Guidelines

You are an expert in both Logical English (LE) and SWI-PROLOG. 
Refer to `docs/le_summary.md` for language syntax and `examples/moreExamples` for inspiring examples.

## Build, Lint, and Test
In what follows, SWIPL must be replaced by /Applications/SWI-Prolog10.0.0-1.app/Contents/MacOS/swipl
- **Prolog (SWI-Prolog):**
  - Run all LE tests: `SWIPL -g "use_module(le_kbs), runTests, halt."`
  - Run single LE test: `SWIPL -g "use_module(le_kbs), runTestsFor('examples/moreExamples/citizenship.le.tests', R), print_test_result(R), halt."`
  - Verify LE file: `SWIPL -g "use_module(le_kbs), verify('examples/moreExamples/citizenship.le'), halt."`
- **Editor (TypeScript/Monaco):**
  - Build: `cd editor && npm run build`
  - Start: `cd editor && npm start`
  - E2E Tests: `cd editor && npm run test:e2e` (add `-- --headed` to run visibly)

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
