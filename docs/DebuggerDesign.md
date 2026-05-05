# DSL Debugger — Pure SWI-Prolog Specification

This document describes the architecture for a Debug Adapter Protocol (DAP) implementation for Logical English, running entirely within the SWI-Prolog process.

## 1. Architecture

The browser connects directly to the SWI-Prolog server via WebSockets. The DAP adapter, the HTTP server, and the DSL interpreter all run in the same process.

```
Browser (Monaco + debug panel)
        ↕  WebSocket · DAP JSON
SWI-Prolog HTTP server
  ├── existing DSL web API   (current endpoints)
  └── /dap WebSocket endpoint  (new)
        ↕  in-process calls
  DAP adapter (minimal implementation)
        ↕  tracer hooks
  DSL interpreter
```

---

## 2. Transport & Endpoint

SWI-Prolog's `library(http/websocket)` handles the WebSocket upgrade natively. The DAP adapter speaks DAP JSON over that socket directly.

Add a single new route to the existing HTTP server:

```prolog
:- http_handler('/dap', dap_websocket_handler, []).

dap_websocket_handler(Request) :-
    http_upgrade_to_websocket(dap_loop, [], Request).

dap_loop(WebSocket) :-
    % receive DAP JSON frame → dispatch → send response/events
    % DAP messages are length-prefixed JSON: Content-Length: N\r\n\r\n{...}
```

---

## 3. DAP Adapter Implementation

A minimal adapter is recommended, implementing the core required request handlers directly. Prolog's pattern-matching on dicts makes this concise.

**Required DAP requests:**

| Request | Purpose |
|---|---|
| `initialize` / `launch` | session lifecycle |
| `setBreakpoints` | register source-line breakpoints |
| `stackTrace` | the live goal stack (proof tree) |
| `scopes` + `variables` | current variable bindings per frame |
| `continue` / `stepIn` | execution control |
| `evaluate` | debug REPL in the current frame |

---

## 4. Threading Model

SWI-Prolog's multi-threading enables non-blocking debug interactions:

- **HTTP thread**: Handles the WebSocket connection, reads DAP messages, and sends responses/events.
- **Interpreter thread**: Runs the DSL program and pauses at tracer hook invocations.
- **Synchronization**: Uses a pair of `message_queue` objects:
    - `dap_commands`: Commands from the HTTP thread to the interpreter (continue, step).
    - `dap_events`: Events from the interpreter back to the HTTP thread (StoppedEvent).

```prolog
% Tracer hook — runs in interpreter thread
dap_tracer_hook(Port, Frame, _Choice) :-
    port_to_dap_reason(Port, Reason),
    build_stopped_event(Reason, Frame, Event),
    thread_send_message(dap_events, Event),      % → HTTP thread sends to browser
    thread_get_message(dap_commands, Command),   % blocks until user steps/continues
    execute_command(Command).
```

---

## 5. Browser — Debug Panel

The browser side uses React and `@vscode/debugprotocol` for typed DAP interfaces.

- **Toolbar**: Continue, Step Over, Step In, Stop.
- **Call stack**: Clickable frames for variable inspection.
- **Bindings panel**: Variable name → value tree for the selected frame.
- **Monaco decorations**: Current execution line highlighting and breakpoint gutter.

---

## 6. Effort Summary

| Part | Effort | Notes |
|---|---|---|
| `/dap` WebSocket route | minimal | ~10 lines using `library(http/websocket)` |
| DAP framing & dispatch | small | JSON parsing + ~8 request handlers |
| Threading bridge | small | ~20 lines using `message_queue` |
| Interpreter tracer hook | medium | four-port hook + source position export |
| Browser panel | medium | React components + Monaco decoration API |
