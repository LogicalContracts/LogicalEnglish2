# Logical English Editor

A cute, simple browser-based editor for Logical English (LE) programs, featuring syntax highlighting, autocompletion, and an LSP server.

## Features

- **Syntax Highlighting**: Custom Monarch tokens for LE syntax.
- **LSP Server**: Browser-based Language Server Protocol implementation providing:
  - **Autocompletion**: Templates (user-defined and system), section headers, and keywords.
  - **Diagnostics**: Basic error checking (e.g., unclosed strings).
  - **Hover**: Information about token types.
  - **Folding**: Syntax-aware folding for rules, scenarios, and sections.
- **Theme Support**: Persistent theme selection (Dark, Light, High Contrast).
- **Prolog Integration**: Can be launched directly from SWI-Prolog to edit local files.

## Prerequisites

- [Node.js](https://nodejs.org/) (for building the assets)
- [SWI-Prolog](https://www.swi-prolog.org/) (for running the backend and serving the editor)

## Building the Editor

To compile the TypeScript client and server assets:

```bash
cd editor
npm install
npm run build
```

This will generate the bundled files in the `editor/dist/` directory.

## Launching the Editor

The editor is designed to be served by the Logical English Prolog backend.

1. Start the Prolog API server:
   ```prolog
   ?- use_module(classic_web_api).
   ?- start_api_server(3050).
   ```

2. Open an LE file for editing from the Prolog console:
   ```prolog
   ?- use_module(le_kbs).
   ?- edit('path/to/your/file.le').
   ```

This will automatically open your default browser at `http://localhost:3050/editor/index.html` with the file content loaded.

## Development

- `src/client.ts`: Monaco editor initialization and LSP client bridge.
- `src/server.ts`: LSP server implementation (runs in a Web Worker).
- `src/tokenizer.ts`: LE tokenizer for the LSP server.
- `src/le-language.ts`: Monaco language definition (Monarch tokens and configuration).
