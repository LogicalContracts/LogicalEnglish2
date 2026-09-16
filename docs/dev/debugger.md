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
6. **Step** sends `stepIn`, **Step over** `next`, **Continue** `continue`,
   **Stop** `disconnect` (also F11, F10, F5). The socket's receive loop puts
   the command in the queue; the hook sets the session's run mode from it
   (`run_mode/2`) and returns, and the query runs to the next port the mode
   stops at (§4).
7. When the HTTP request returns, the panel shows "Query finished".

## 3. Requests implemented (`handle_command/4`)

| Request | Behaviour |
|---|---|
| `initialize` | capabilities `supportsConfigurationDoneRequest: true`, `supportsStepBack: false` |
| `launch` | sets the run mode to `step` |
| `setBreakpoints` | replaces the session's breakpoints (`breakpoint/4`). Besides DAP's `line`, each carries `startOffset`/`endOffset`, the character range of the line (goals know their source by offsets); one without them is answered unverified |
| `stackTrace` | frames `[Goal \| Ancestors]`, innermost first; a frame's name is the goal in LE words (`item_to_instance/3`), its `offset`/`endOffset` the call site (`le_at/3`) or the proving clause's range |
| `scopes` | one "Local" scope whose reference is the frame index |
| `variables` | the frame goal's arguments, named by template type ("a payment") and valued by their current binding in LE words, or `(unbound)` |
| `continue`, `stepIn`, `next` | put the command in the queue |
| `disconnect` | puts `disconnect` in the queue: the query is ended |

## 4. Behaviour worth knowing

- **Where a trace stops** (`should_stop/7`, by the last command):
  - `stepIn` (and the start of a trace): every port;
  - `next` (step over): a port no deeper than the goal it was given at, so
    the goals that one calls run without stopping;
  - `continue`: the `call` of a goal whose source offset lies on a breakpoint's
    line; the query's own goal exiting (an answer, reason `entry`) or failing;
  - always: an exception (but `query_interrupted`, below).
- **Stop ends the query.** On `disconnect` the hook (outside its own `catch`)
  retracts `SM:debug_mode` and throws `query_interrupted`, which
  `classic_web_api:run_interruptible_query/4` turns into the `interrupted`
  reply the Interrupt button gets; the panel says "Trace stopped".
- **Abandoned traces.** The traced query holds an HTTP worker while it waits.
  `dap_command_timeout/1` (300 s) treats a silent client as a disconnect, and
  closing the socket sends `disconnect` to the queue at once. The server runs
  24 workers for this reason.
- `:- debug(dap)` is on, so the adapter logs to the server console.

## 5. Browser side

The panel is plain DOM in `editor/index.html` (`#debug-panel`: Step, Step
over, Continue, Stop, call stack, variables, status line; draggable), driven by
`client.ts`, which builds the DAP messages by hand (`sendDapRequest`). No UI
framework and no DAP client library are involved. Source highlighting uses
Monaco decorations (`debug-line-highlight`, `debug-range-highlight`).
Breakpoints are set by a click in the editor's glyph margin (red dots,
`debug-breakpoint-glyph`), kept per document, and sent with `setBreakpoints`
when a trace starts and whenever they change.

## 6. Tests

`testing/test_dap_trace.pl` drives the reasoner with the test seam
`dap_test_capture/0`: the hook records each stop as `dap_test_stop/3` and goes
on with the next `dap_test_command/1` (Step when there is none), without a
socket. It checks that every answer can be traced, that a `for all cases in
which` goal stays on the ancestor stack, that Continue stops only at answers
and at a breakpoint, that Step over does not go deeper, and that Stop ends the
query. `editor/tests/editor.spec.ts` sets a breakpoint in the margin, continues
to it and stops.
