# Logical English editor

The browser editor of LogicalEnglish2: TypeScript sources in `src/`, one
esbuild bundle per page in `dist/`, served by the Prolog server. How it is
built inside, and how it fits with the server, is in
[docs/dev/architecture.md](../docs/dev/architecture.md).

## Build

Requires Node.js (the Docker image uses Node 20).

```bash
cd editor
npm install
npm run build
```

`npm run build` regenerates `src/generated/i18nData.ts` from `../i18n/*.csv`
(`npm run gen-i18n` does only that step) and writes the bundles to `dist/`.
The bundles are committed: rebuild and commit them together with any change
to `src/` or to the i18n CSVs.

## Launch

The editor is served by the Prolog server, from the repository root:

```bash
swipl -g "use_module(classic_web_api), start_api_server(3050)"
```

then open `http://localhost:3050/editor/`. From a Prolog session,
`use_module(le_kbs), edit('path/to/file.le')` opens a file in the editor of
the server on port 3050.

## Test

```bash
npm run test:e2e              # Playwright; add -- --headed to watch
```

The suite starts its own server on port 3000 (`playwright.config.ts`) and
keeps its browsers in `node_modules` (`PLAYWRIGHT_BROWSERS_PATH=0`); always run
it through `npm run test:e2e`. `testing/run_tests.sh` at the repository root
runs it together with the Prolog suites.
