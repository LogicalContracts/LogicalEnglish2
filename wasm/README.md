# `wasm/` — Logical English as a static site

This directory builds LE2 into a directory of files that a static host serves
as it is: no server, no container, no SWI-Prolog at the far end. The Prolog is
compiled to WebAssembly and runs in the visitor's own tab.

**The instructions are [`docs/dev/deploy-vercel.md`](../docs/dev/deploy-vercel.md)** —
how to build it, how to deploy it to Vercel, what it can and cannot do, and
how it works. This file is the map of the directory.

```sh
./wasm/build.sh                                # → wasm/dist/
node wasm/runtime/serve.mjs wasm/dist 8080     # → http://localhost:8080/
cd wasm/dist && vercel deploy --prod
```

| Path | What |
|---|---|
| `build.sh` | the whole build, in eight steps it names as it goes |
| `le_wasm.pl` | the browser transport: a JSON request in, a JSON reply out, over `le_api.pl` — the same operations the server runs |
| `pack.pl` | what goes into the payload, and (more to the point) what must not: the rule is `restricted_paths.pl`'s own, for a visitor with no roles. It also carries `docs/user/**.md`, which is what the Light Assistant searches and cites |
| `shims/` | the libraries SWI-Prolog's WebAssembly image does not have, each stood in for; `shims/README.md` is the list |
| `runtime/boot.js` | replaces `window.fetch` before the page's own scripts run, so that `/leapi` is answered by the worker |
| `runtime/worker.js` | the worker: SWI-Prolog, the payload unpacked into its file system, and the one call |
| `runtime/mkpayload.mjs` | four hundred files into one gzipped payload |
| `runtime/inject.mjs` | the script tags, into the pages that need them |
| `runtime/mkvercel.mjs` | `vercel.json`, and the same routing in English for other hosts |
| `runtime/serve.mjs` | the built site locally, with that routing applied |
| `api/proxy.js` | the Vercel Function that forwards what a page may not fetch itself, with the key kept on the server |
| `TESTING.md` | the editor's own end-to-end suite, run against this build: what passes, what does not, and why |
| `dist/` | the build (git-ignored) |

Nothing here is in the fly.io image, and nothing here changes it: `Dockerfile`,
`fly.toml` and `buildPush.sh` are as they were. The one file both deployments
share is `le_api.pl` in the repository root — the operations, with no transport
in them — which is the point of the whole arrangement.
