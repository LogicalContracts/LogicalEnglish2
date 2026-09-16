# The LE debugger (DAP over WebSocket)

*Kind: design, as built · Audience: developers · Status: current (2026-09-16)*

The editor's **Trace** button steps through the proof of a query. It speaks
the Debug Adapter Protocol (DAP) over a WebSocket to an adapter that runs
inside the SWI-Prolog server, beside the web API and the reasoner.

## 1. Architecture

```
Browser: editor/src/client.ts (debug panel, native WebSocket)
   │  WebSocket /dap?sessionModule=<SM> · DAP JSON, one message per text frame
   │  POST /leapi {operation: answeringQuery, debug: true}   (the traced query)
   ▼
SWI-Prolog HTTP server (classic_web_api.pl)
   ├─ dap_server.pl: dap_websocket_handler/1, dap_loop/2
   │       ▲ ws_send (events)          │ message queue dap_commands_<SM>
   │       │                           ▼
   └─ reasoner.pl solve/8 ──► dap_server:dap_tracer_hook/6  (HTTP worker running the query)
```

There is no `Content-Length` framing: each WebSocket text frame is one JSON
request, response or event.

## 2. A trace, step by step

1. **Trace** (`btn-trace`) loads the program if needed, shows the floating
   debug panel and opens `/dap?sessionModule=<SM>`.
2. On open the client sends `initialize` and `launch`, then posts the selected
   query as `answeringQuery` with `debug: true`. The server asserts
   `SM:debug_mode` for the session.
3. In `reasoner:solve/8`, for every non-trivial goal of a session in debug
   mode, the reasoner calls `dap_tracer_hook/6` at the `call`, `exit` (once per
   solution, since a soft cut keeps backtracking), `fail` and `exception`
   ports.
4. The hook records `stopped_state/5` (goal, ancestors, depth), sends a
   `stopped` event through the session's socket, and blocks on the queue
   `dap_commands_<SM>`.
5. The client answers a `stopped` event with `stackTrace`, renders the frames
   root first, selects the innermost frame, highlights its source range in
   Monaco and requests `scopes` and `variables`.
6. **Step** sends `stepIn`, **Continue** `continue`, **Stop** `disconnect`.
   The socket's receive loop puts the command in the queue, the hook returns,
   and the query runs to the next port.
7. When the HTTP request returns, the panel shows "Query finished".

## 3. Requests implemented (`handle_command/4`)

| Request | Behaviour |
|---|---|
| `initialize` | capabilities `supportsConfigurationDoneRequest: true`, `supportsStepBack: false` |
| `launch` | no-op |
| `setBreakpoints` | answers every breakpoint as verified; breakpoints are **not** used by the tracer (the editor sends none) |
| `stackTrace` | frames `[Goal \| Ancestors]`, innermost first; a frame's name is the goal in LE words (`item_to_instance/3`), its `offset`/`endOffset` the call site (`le_at/3`) or the proving clause's range |
| `scopes` | one "Local" scope whose reference is the frame index |
| `variables` | the frame goal's arguments, named by template type ("a payment") and valued by their current binding in LE words, or `(unbound)` |
| `continue`, `stepIn`, `next` | put the command in the queue |
| `disconnect` | puts `disconnect` in the queue |

## 4. Behaviour worth knowing

- **Every port stops.** `should_stop/6` is true for all four ports, and
  `continue`, `stepIn` and `next` all resume to the next port. So Continue
  currently behaves as Step, although its tooltip says it runs to the next
  answer.
- **Stop detaches, it does not abort.** On `disconnect` the hook retracts
  `SM:debug_mode`; the exception it throws is caught inside the hook, so the
  query runs on to completion without further stops.
- **Abandoned traces.** The traced query holds an HTTP worker while it waits.
  `dap_command_timeout/1` (300 s) treats a silent client as a disconnect, and
  closing the socket sends `disconnect` to the queue at once. The server runs
  24 workers for this reason.
- `:- debug(dap)` is on, so the adapter logs to the server console.

## 5. Browser side

The panel is plain DOM in `editor/index.html` (`#debug-panel`: Step,
Continue, Stop, call stack, variables, status line; draggable), driven by
`client.ts`, which builds the DAP messages by hand (`sendDapRequest`). No UI
framework and no DAP client library are involved. Source highlighting uses
Monaco decorations (`debug-line-highlight`, `debug-range-highlight`).

## 6. Tests

`testing/test_dap_trace.pl` drives the reasoner with the test seam
`dap_test_capture/0`: the hook records each stop as `dap_test_stop/3` and
continues without a socket. It checks that every answer can be traced and
that a `for all cases in which` goal stays on the ancestor stack.
