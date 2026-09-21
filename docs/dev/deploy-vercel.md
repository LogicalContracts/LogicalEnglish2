# Deploying Logical English as a static site (WebAssembly, Vercel)

*Kind: operations · Audience: developers, operators · Status: current (2026-09-20)*

There are two ways to deploy LE2, and they are not versions of each other.

|  | **The server** (`Dockerfile`, `fly.toml`) | **The browser** (`wasm/build.sh`) |
|---|---|---|
| What runs the Prolog | one SWI-Prolog process on fly.io | SWI-Prolog compiled to WebAssembly, in each visitor's tab |
| What the host does | runs a container | serves files |
| Sessions live | in the server's memory, for everyone | in the tab, for its own user |
| Scaling | vertically: a session is a module inside one process, so it does not spread across machines | nothing to scale: every visitor brings an engine |
| Accounts, restricted examples | yes (`le_users.pl`, `restricted_paths.pl`) | no, and therefore nothing restricted is shipped |
| The assistants, the debugger | yes | no (§ What is not there) |
| Cost when nobody is using it | a machine that stops and starts | a static file bill |
| Privacy | the program is POSTed to the server | the program never leaves the machine |

Both run the same operations, because since this change they *are* the same
code: `le_api.pl` is the half of the old `classic_web_api.pl` with no transport
in it, and both deployments call its `handle_operation/2`. The server reads a
POST and writes a reply; the browser build (`wasm/le_wasm.pl`) reads a message
from the page and answers it. An operation is implemented once.

**Nothing here changes the fly.io deployment.** The `Dockerfile`, `fly.toml`
and `buildPush.sh` are untouched, and `wasm/` is not in the image.

---

## Build it

Prerequisites: SWI-Prolog (`./myswipl.sh` finds it), Node 18 or later, `curl`,
and — for the deploy — the [Vercel CLI](https://vercel.com/docs/cli)
(`npm i -g vercel`).

```sh
./wasm/build.sh                    # → wasm/dist/
node wasm/runtime/serve.mjs wasm/dist 8080     # → http://localhost:8080/
```

`wasm/dist/` is the whole site — with one exception worth knowing about
before anyone promises an offline demonstration: **Monaco comes from a CDN**.
`editor/index.html` loads the editor component from `cdnjs.cloudflare.com` (and
`marked` from jsdelivr), as it does on the server, so the site needs the open
internet for its text editor even though it needs nothing for its reasoning.
Bundling Monaco is a change to the editor's build, not to this one; LPS2's IDE
already bundles its own.

What the site does carry is about 30 MB on disk, of which the visitor
downloads **about 3.2 MB compressed** before the first question can be answered —
the SWI-Prolog runtime (0.8 MB of WebAssembly and 1.2 MB of its library) and
one payload file of 1.3 MB carrying LE2's Prolog, the i18n dictionaries, the
shared LE libraries, the examples, the originals the migrated ones were
converted from, and the user documentation as text (which the Light Assistant
searches). The rest — the editor's own bundle,
Monaco from a CDN, the documentation and its images — arrives as it is needed,
and the browser caches all of it.

Options:

| | |
|---|---|
| `--skip-editor` | reuse `editor/dist` as it stands, instead of `npm run build` |
| `--out DIR` | build somewhere other than `wasm/dist` |
| `--private` | include the linked private trees. **Not for a public deployment** — see *What is in the payload* |
| `--port N` | the port the build's own export server uses (default 3099) |

The build does eight things, and says so as it goes: builds the editor;
fetches the SWI-Prolog WebAssembly runtime (or takes a vendored copy from
`wasm/vendor/swipl/`); packs the payload; **starts the real LE2 server** with
`LE_STATIC_EXPORT=1` and saves the pages it renders (the landing page and the
multilingual ones) as static HTML; copies the editor, `web_extras/` and
`docs/user/` — following no symbolic link out of any of them; writes the
example sources under `/source/`; installs the browser runtime and
`config.js`; and writes `vercel.json`.

The fourth step is worth a sentence: the landing page is Prolog, and rather
than write it a second time in HTML the build asks the server for it.
`LE_STATIC_EXPORT=1` (`classic_web_api.pl`) leaves out the two things a static
copy cannot honour — the login link and the button that runs the test suite on
the server — and changes nothing else.

Two more things the build asks the Prolog for rather than keeping a second
list of: the **redirects** a document's old address needs (`doc_moved/2`),
which become one `redirects` entry each in `vercel.json`; and the **old names
of examples** (`example_alias/2`), so that `/source/<old name>` still answers
— which is what those aliases are for.

## Deploy it

```sh
cd wasm/dist
vercel deploy            # a preview URL
vercel deploy --prod     # the production domain
```

There is no build step and there must not be one: Vercel has no SWI-Prolog,
and `wasm/dist` is already the finished site. Deploying the directory itself
is Vercel's zero-configuration case — static files, plus `api/` as Serverless
Functions, plus the `vercel.json` the build wrote. (`--prebuilt` is a
different thing: it deploys a `.vercel/output` tree produced by `vercel build`,
which we have no use for.)

The first `vercel deploy` asks which project to attach to and writes
`.vercel/` into `wasm/dist` — which is rebuilt each time, so either answer the
two questions again, or link the project once and keep the answers:

```sh
cd wasm/dist && vercel link        # writes wasm/dist/.vercel/project.json
cp -r .vercel ../vercel-project    # keep it across builds
# next time:
cp -r ../vercel-project wasm/dist/.vercel
```

### Or from Git

A repository connected to Vercel can deploy on push, but the build has to
happen somewhere with SWI-Prolog, so the repository would have to carry
`wasm/dist/` (it is `.gitignore`d, deliberately: it is a build artefact, and
30 MB of it). The supported route is the CLI above, from a machine or a CI job
that has SWI-Prolog. A GitHub Action doing exactly that is four lines:

```yaml
- run: sudo apt-get install -y swi-prolog-nox
- run: ./wasm/build.sh
- run: npx vercel deploy --prod --token=${{ secrets.VERCEL_TOKEN }}
  working-directory: wasm/dist
```

### Other hosts

Nothing here is Vercel-specific except `vercel.json`, whose four rewrites and
two header rules the build also writes out in English as
`wasm/dist/STATIC-HOSTS.md`. GitHub Pages, Netlify, Cloudflare Pages, S3 with
CloudFront, or a directory served by nginx will all do — and with no rewrites
at all the site still works, just with `/editor/index.html` in the address bar
rather than `/editor`.

One requirement, wherever it is: `payload.bin` must arrive with its bytes
intact. It is gzip, and the worker decompresses it itself when the host has
not.

## The environment: the proxy, and keys

A page may not fetch another origin unless that origin allows it, and no LLM
provider does. Anything in LE2 that reaches outside — *Write it in English*,
a service-backed template, a document at a URL — therefore goes through a
same-origin proxy, which the build ships as a Vercel Function at
`/api/proxy` (`wasm/api/proxy.js`).

It forwards only to hostnames on a list, adds the key from the environment,
does not follow redirects, and caps the body and the time. Set the keys in the
Vercel project (Settings ▸ Environment Variables) or with the CLI:

```sh
vercel env add GROQ_API_KEY production      # or OPENAI_API_KEY, ANTHROPIC_API_KEY, …
vercel env add LE_PROXY_ALLOW production    # optional: the hostnames, comma-separated
```

| Variable | Effect |
|---|---|
| `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GROQ_API_KEY`, `OPENROUTER_API_KEY`, `MISTRAL_API_KEY`, `DEEPSEEK_API_KEY`, `GEMINI_API_KEY` | the key added to a request to that provider. A provider with no key configured is still forwarded to, without one |
| `LE_PROXY_ALLOW` | the hostnames that may be reached, comma-separated. Unset means the default list (the providers `llm/llm_client.pl` knows, plus `raw.githubusercontent.com`); **empty means none**, which turns the outbound half off |
| `LE_PROXY_KEYS_ONLY` | `1` to refuse a request for a host the deployment has no key of its own for. Without it, the proxy forwards the **caller's** key when it has none — which is what makes bring-your-own-key work in a browser, and what the Light Assistant uses when a visitor types their own key into the editor |

To deploy with no proxy at all, set `proxy: ''` in
`wasm/dist/le-wasm/config.js` (it is a plain file, editable after the build)
and delete `wasm/dist/api/`. Everything that does not need the outside goes on
working.

## What is in the payload, and what must not be

`wasm/pack.pl` decides, and the rule it applies is not its own: a file ships
only if `restricted_paths.pl` would let an **anonymous** visitor of the server
read it — `is_path_allowed(Path, [])`, the same call the operations make for a
request with no session. A static site has no accounts and cannot have any, so
anything a server would have asked someone to log in for cannot be published
by this build.

On top of that: no symbolic links (`le_extensions.pl`, `le_importers.pl` and
the `insureLE2`/`lpsPlus` example trees are links into private repositories,
and a link resolves perfectly well on the machine that builds — which is
exactly what makes it dangerous), and no `le_users.db`. The second rule is
the one that keeps `restricted_paths:open_to_everyone/1` out of the payload:
the files it names (the Medicare power mobility policy) pass the first rule,
but they sit in a linked tree and need `le_extensions.pl`, so the static site
neither ships nor could run them — the pages that link to them name the
server.

`--private` turns both off, for a deployment that is not public. The build
says so, loudly, when it does.

The example sources served at `/source/` are the same files: an example that
is in the payload is one anybody can already open in the editor, so writing it
out again under its own address adds no exposure — it is there because the
server has that address and links use it.

Check what a build contains at any time:

```sh
./myswipl.sh -q -g "use_module('wasm/pack'), print_payload_files, halt." | less
```

## What is not there

| | Why | What the user sees |
|---|---|---|
| The **HTTP API itself** — `POST /leapi`, `/list_examples`, `/query`, `/verify`, and **MCP** at `/mcp` | they are addresses *other programs* call, and this deployment is a page, not a service: the operations run inside the tab, and nothing listens on the outside | `curl` gets a 404; an MCP client cannot use this deployment at all |
| The **Deep** LE Assistant and the **Contract Assistant** | they run `opencode` as a sub-process, in a working directory; a tab has neither | Deep mode answers "choose Light mode, which runs here"; the Contract Assistant reports its job failed |
| The **debugger** (*Trace*) | it is a second thread talking a websocket to the editor, and there is one thread | tracing is not offered |
| **Interrupting** a running query | the interrupt arrives on another thread, and there is one | a query runs to its limit |
| **Accounts**, restricted examples | no server, nothing private shipped | no login link (the page is built without one) |
| **s(CASP)** | an optional pack, not in the payload | "the s(CASP) engine is not installed on this server" |
| Running the **test suite** from the landing page | it is a server's job | the button is not there |
| A landing page **focused on one folder** (`/?dir=…`) | the page is rendered once, at build time, and a static host cannot render a different one per query | the full list; the folders still collapse and expand, which is client-side |
| **Sentry**, web analytics | no server to report to | `/telemetry.js` is an empty file |

**The Light Assistant does work**, and is the exception worth stating
separately. It is a Prolog-native agentic loop — the model, then in-process
tools (verify, query, search the documentation) — with no sub-process anywhere
in it, so the only thing it needed was somewhere to run without a thread: it
runs *in* the request instead (`le_assistant.pl`, guarded by
`current_prolog_flag(threads, true)`). Three consequences, all of them the
single thread's:

* the call does not return until the loop is done, so the progress lines
  arrive together at the end rather than streaming, and no other operation is
  answered while it runs (the page stays responsive — the engine is in a
  worker);
* `assistant_interrupt` has nothing to interrupt, and says the job is
  finished, which by then it is;
* the model is reached through the proxy, so a deployment that wants the
  assistant needs `/api/proxy` — with a key of its own, or with the user's own
  key forwarded (§ *The environment*).

The build carries `docs/user/**.md` in the payload for it, so the assistant
searches and cites the documentation exactly as the server's does.

The first row is the one to keep in mind when choosing between the two
deployments: **the WebAssembly build is an application, not a service.** A
person opens it and everything works; a program cannot call it. Agent-facing
work (the MCP surface, `docs/user/api/mcp.md`) is a reason to keep the server,
and a page that declares a service-backed template
(`docs/user/reference/language.md` §services) needs one it can reach.

Two more differences that are not absences:

* **A time limit is counted in inferences, not seconds** (`wasm/shims/time.pl`).
  There is no clock to interrupt a goal with, so the budget is
  `seconds × le_wasm_inferences_per_second` (default 6 million). A query that
  runs away still stops; a slow, legitimate proof may stop early, and
  `inferencesPerSecond` in `config.js` is the dial.
* **Every window boots its own engine.** The Proof Game, the Source Graph,
  the Explanation Drill and Scenario Variations open in windows of their own,
  and each gets its own worker, its own copy of the payload and its own two or
  three seconds — where on the server they share the one Prolog. Nothing is
  wrong when that happens (their sessions are distinct in both deployments,
  which is what `proof-game.spec.ts` checks), but it is the clearest thing
  left to improve: a **SharedWorker** would give every window of the origin
  the same engine, which is both faster and closer to the server. It is not
  done.
* **The first request waits for the engine.** Measured on a two-core
  container over localhost: **about 3 seconds** from opening the page to an
  engine that answers, of which roughly 1.2 s is SWI-Prolog consulting LE2's
  own sources (the banner at the bottom of the page reports that part). Warm —
  the browser cache holding the runtime and the payload — about 2.5 s. A real
  laptop is faster and a real network slower; the shape is the same. The page
  is up long before then, but its first `/leapi` call is what its scripts are
  waiting on, so *the editor is not interactive until the engine is*.

## How it works

```
  the page (editor, Proof Game, executive view, …)
      │  fetch('/leapi', {…})          ← unchanged: the editor was never told
      ▼
  le-wasm/boot.js                      ← replaces window.fetch, in <head>
      │  postMessage
      ▼
  le-wasm/worker.js                    ← a Web Worker: SWI-Prolog + the payload
      │  le_wasm:le_wasm_call(JSON, Reply)
      ▼
  wasm/le_wasm.pl  →  le_api.pl  →  le_kbs.pl, le_grammar.pl, reasoner.pl, …
```

Five pieces, each with one job:

* **`le_api.pl`** — the operations, with no transport in them. Extracted from
  `classic_web_api.pl`, which keeps the HTTP half and delegates. Who the user
  is arrives through one multifile hook, `le_api_user/2`; the server defines it
  over the HTTP session, and this build leaves it undefined, which is the
  anonymous case the operations already handle.
* **`wasm/le_wasm.pl`** — the browser transport: JSON string in, JSON string
  out, plus the way back out to the page (`le_wasm_fetch/2`).
* **`wasm/shims/`** — the nine libraries the WebAssembly image does not have
  (`time`, `process`, `www_browser`, and the `http/` family), each standing in
  for one, and each refusing in the shape the real one would when it cannot do
  the job. `wasm/shims/README.md` is the list.
* **`wasm/pack.pl` + `wasm/runtime/mkpayload.mjs`** — what ships, and as one
  gzipped file rather than four hundred requests.
* **`wasm/runtime/boot.js` + `worker.js`** — the interception and the engine.

`boot.js` answers three addresses: `/leapi` (the one that matters), plus
`/build_info` and `/telemetry_test`, which pages ask about a server in
passing. `/whoami` it deliberately does not answer — the executive view's own
`catch` then leaves its login corner empty, which is the truth here, where
answering "not logged in" would draw a Login link to a page that does not
exist. Everything else — Monaco, the documentation, an example's text — is a
file, and goes through the real `fetch` untouched.

## Testing it

The editor's own end-to-end suite runs against the static build:

```sh
./wasm/build.sh --skip-editor
cd editor && npx playwright test -c playwright.wasm.config.ts
```

`playwright.wasm.config.ts` is `playwright.config.ts` with the SWI-Prolog
server replaced by `wasm/runtime/serve.mjs` over `wasm/dist`. What passes and
what does not — and which of the failures are features that need a server, and
which are tests that watch the network for a reply this deployment never puts
on it — is in [`wasm/TESTING.md`](../../wasm/TESTING.md).

## Troubleshooting

**"The Logical English engine could not start"** at the bottom of the page.
The worker says why in the browser console. The usual causes are a
`payload.bin` that was re-encoded in transit (see *Other hosts*) and a host
that will not serve `.wasm` as `application/wasm`.

**Everything works except one operation, which answers "Operation failed".**
The reply carries a `detail` field naming the exception; the console has it.
An `existence_error(procedure, …)` there means a predicate the payload does
not carry — add its file to `wasm/pack.pl`.

**A query that used to finish now says it ran out of time.** The inference
budget, not the clock: raise `inferencesPerSecond` in `config.js`.

**The page is blank and the console says a module failed to load.** The editor
build is stale or missing: `cd editor && npm run build`, then rebuild.

**An outbound request fails with "this deployment does not forward requests
to …"**. The proxy's allowlist: add the host to `LE_PROXY_ALLOW`.
