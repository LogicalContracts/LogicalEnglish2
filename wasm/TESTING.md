# The editor's own end-to-end suite, against the WebAssembly build

`editor/playwright.wasm.config.ts` runs the same specs as
`editor/playwright.config.ts`, with the SWI-Prolog server replaced by
`wasm/runtime/serve.mjs` over `wasm/dist`. Every request the editor makes is
then answered by the Prolog compiled into the page, so a test that passes here
is a feature that works with no server at all.

```sh
./wasm/build.sh --skip-editor
cd editor && npx playwright test -c playwright.wasm.config.ts
cd editor && npx playwright test -c playwright.wasm.config.ts editor.spec.ts   # one spec
```

It is slower than the server suite — every page boots an engine — and the
config allows for that: 120 seconds a test, 45 for an assertion, two workers.

## What the failures mean

The suite was written for a server, and some of it tests the server. The
failures fall into five kinds (plus this machine's own, which the server suite
has too), and only the third is a limitation of this deployment that anyone
using it would notice.

### 1. The test speaks HTTP to the API itself

`request.post('/leapi', …)` and `request.get('/list_examples')` are calls from
the test *runner*, not from the page. There is no HTTP API in this deployment
— the operations are reachable only from a page that has the engine in it — so
these cannot pass, and the same is true of anything else that would call the
deployment from outside: `curl`, an MCP client, another program.

`tests/api/mcp.spec.ts` — all nineteen of it — and one case in
`example-alias.spec.ts`.

**This is the deployment's real boundary**, and it is worth saying in one
sentence: *the WebAssembly build is an application, not a service.* An agent
that needs LE2 over MCP (the hosted service's `/mcp`) needs the server.

### 2. The test watches the network for a reply that never crosses it

`page.on('response', …)`, `page.waitForResponse(…)` and
`page.route('**/leapi*', …)` all work at the network layer. In this deployment
`fetch('/leapi')` is answered inside the page, by the worker, without a request
ever being made — so a test that reads the reply off the wire sees nothing, a
test that *waits* for one waits for ever, and a test that *mocks* the wire does
not get its mock used.

The feature under test works; the observation does not. Three groups fail this
way:

* `editor.spec.ts`'s "citizenship example integration test" and the two
  "Show … reason" cases, which read `strongestReasonPath` out of the response
  body. The first of them fails *after* asserting that the explanation title
  carries the reason as its tooltip — which is the same computation, arriving
  by the way the page actually uses it;
* `explanation-drill.spec.ts`, whose `answerLast` helper awaits
  `waitForResponse('/leapi')` after every click. The drill itself was driven
  by hand against this build — the popup boots an engine of its own, asks its
  first question about the right goal, and accepts the answer;
* `document-facts.spec.ts`, which mocks `nl_to_le` with `page.route`.

**For a test that has to work against both deployments, read the result from
the page rather than from the wire** — the DOM, or `window.LE_WASM`. Every
reply is also announced as a DOM event for exactly this reason:

```js
window.addEventListener('le-api-reply', (e) => {
    e.detail.operation;   // 'answeringQuery'
    e.detail.reply;       // the JSON text
});
```

### 3. The feature needs a server, and this build says so

The absences documented in
[`docs/dev/deploy-vercel.md`](../docs/dev/deploy-vercel.md#what-is-not-there),
each failing here exactly as a user of this deployment would find it:

| Spec | Needs |
|---|---|
| `contract-assistant.spec.ts`, the *Write it in English…* cases of `query-editor.spec.ts` and `scenario-editor.spec.ts` | a sub-process (`opencode`) or a model, and a key |
| `editor.spec.ts` "LE Debugger: …" (2) | a second thread and a websocket |
| `editor.spec.ts` "non-terminating query can be interrupted" | a second thread |
| `e2e/auth.spec.ts` (3), and the `/login` half of `i18n-ui.spec.ts` (2) — whose assertions about the *editor's* own Portuguese pass first | accounts |
| `e2e/landing-dir.spec.ts` (4) | the landing page rendered per request (`/?dir=…`) |
| `import-foreign.spec.ts` (3 of its 6) | the translators of other systems, which live in a private repository and are not shipped by a public build (§2.1 of the marketing plan: they run where we run them). The three cases that need no translator pass |
| `document-facts.spec.ts`, `flip-button.spec.ts` (3), `form-support.spec.ts` (3), `include-navigation.spec.ts`, `source-viewer.spec.ts` (3) | an example from the private `lpsPlus` tree, which a public build does not carry. All of them pass against a server started with `NO_RESTRICTIONS=true`, and against a `--private` build |

### 4. The test interacts faster than the engine starts

A page of this deployment is not interactive until its engine is — two to
three seconds, and the editor's own initialisation is waiting on its first
`/leapi` call inside that. A spec that clicks 800 ms after `page.goto` is
clicking at a page whose listeners are not attached yet, and nothing retries.

Worse for the ones that open a **second window**: the Proof Game, the Source
Graph, the Explanation Drill and Scenario Variations each get a worker and an
engine of their own, so a popup costs another boot. Under two workers on a
two-core machine, their 30-second budgets are not always enough
(`source-graph.spec.ts`, two of `proof-game.spec.ts`).

Nothing is broken — each of these works when driven by hand — but two things
would make it stop mattering: a **SharedWorker**, so that every window of the
origin uses one engine as it does on the server, and a wait for
`window.LE_WASM.isReady()` where a spec now waits 800 ms.

### 5. Something is actually wrong

Everything else. Four were, and were fixed rather than explained (the first of
them is a defect of the *server* too, and was fixed there):

* the tokenizer read a word's continuation with `code_type(C, csym)`, which
  the WebAssembly C library does not classify for non-ASCII letters — so
  Portuguese, Spanish, French and Italian programs tokenized as nonsense.
  `tokenizer:word_char/1` now falls back to `alnum`, which SWI-Prolog
  classifies from its own Unicode tables, and which is right on a server under
  `LANG=C` too;
* `/docs/(.*)` was rewritten to the viewer for the *whole* docs tree, so
  `/docs/project/plans/…` answered 200 where the server answers 404. The
  rewrite is `/docs/user/(.*)` now, and the build copies `docs/user` only,
  which is what `public_doc/1` publishes;
* a document's old address (`doc_moved/2`) 404'd instead of redirecting, and
  an example's old name (`example_alias/2`) was not served under `/source/`.
  The build now asks the Prolog for both lists — one `redirects` entry per
  moved document, one extra copy per renamed example;
* the executive view drew a **Login** link into a build with no login page,
  because `boot.js` was answering `/whoami` with "not logged in". It does not
  answer it at all now: the page's own `catch` leaves the corner empty, which
  is the truth here.

Which is the useful thing about running a suite written for something else.
The first of those four was a defect of the **server** as well — under
`LANG=C` it mis-tokenized every non-English program, quietly — and it had been
there for as long as the tokenizer has.

## The run of 2026-09-20

Build: `./wasm/build.sh --skip-editor`, served by `wasm/runtime/serve.mjs`,
Chromium, two workers, on a two-core container.

|  | against the server | against this build |
|---|---|---|
| passed | 163 | **101** |
| failed | 22 | **84** |
| skipped | 4 | 4 |
| wall clock | 11 min | 25 min |

The server's own 22 are this machine's rather than the deployment's, and they
are worth knowing before reading the rest: no s(CASP) pack (4), no
`libGLESv2` for the second browser `executive.spec.ts` launches (6), no access
to the private example trees (11 — all of which pass against a server started
with `NO_RESTRICTIONS=true`, checked), and one clipboard race between parallel
tests.

The 84 here, by the kinds above:

| Kind | Tests | Where |
|---|---|---|
| 1 — speaks HTTP to the API | 20 | `api/mcp.spec.ts` 19, `example-alias.spec.ts` 1 |
| 2 — watches or mocks the network | 11 | `explanation-drill.spec.ts` 5, `editor.spec.ts` 3, `proof-game.spec.ts` 1, `document-facts.spec.ts` 1, `views.spec.ts` 1 |
| 3 — needs a server, or something a public build does not carry | 37 | a model 8 (`contract-assistant` 3, `scenario-editor` 4, `query-editor` 1); a private example 10 (`flip-button` 3, `form-support` 3, `source-viewer` 3, `include-navigation` 1); accounts 5 (`e2e/auth` 3, `i18n-ui` 2); `/?dir=` 4; s(CASP) 4; the foreign importers 3; a second thread 3 (`editor.spec.ts`, the debugger twice and the interrupt) |
| 4 — interacts before the engine is ready, or before a popup's is | 8 | `source-graph` 2, `proof-game` 3, `multilingual` 1, `scenario-variations` 1, `mermaid-export` 1 |
| 5 — actually wrong, and fixed | 2 | `view-original-text` 2: the `sources/` originals of a migrated twin were not in the payload, so *View ▸ The original this was converted from* found nothing. `wasm/pack.pl` now ships them (`.lrml`, `.policy`, `.yaml`, …), and all three cases of that spec pass |
| 6 — this container, not the deployment | 6 | `executive.spec.ts`: `browserType.launch` fails for want of `libGLESv2`, as it does against the server here |

Read the other way: **76 of the 84 say one of four true things about this
deployment** — its API is not on the network (20), its replies never cross the
network (11), what needs a server needs a server (37), and an engine takes a
moment to start (8). Two were defects and are fixed. Six are this container's
missing graphics library, and fail against the server here too.
