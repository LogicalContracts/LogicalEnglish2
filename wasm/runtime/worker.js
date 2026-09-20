/* worker.js — LE2's server, running in a worker of the page it serves.
 *
 * The editor does not know it is here. It POSTs to /leapi as it always has;
 * boot.js catches that fetch and sends the body here instead, and what comes
 * back is the same JSON the SWI-Prolog server would have sent, because it is
 * produced by the same le_api.pl (wasm/le_wasm.pl → le_api.pl).
 *
 * Why a worker and not the page: Prolog is synchronous and a proof can take
 * seconds. On the page's own thread that is a frozen tab — no typing, no
 * scrolling, no spinner. Here it is one busy thread nobody is looking at.
 *
 * Three things this file owns, which Prolog cannot do for itself:
 *
 *   1. the file system. swipl-wasm boots with an empty one; payload.bin is
 *      unpacked into /app before anything is consulted (mkpayload.mjs).
 *   2. the network. `le_wasm_host` below is what wasm/shims/http/http_open.pl
 *      reaches the world through — a *synchronous* XMLHttpRequest, which is
 *      forbidden on a page's main thread and allowed here, and which is the
 *      only shape a blocked Prolog can use.
 *   3. staying alive across calls. Sessions, compiled programs and scenarios
 *      live in this Prolog's memory exactly as they live in the server's, so
 *      a reload of the page is what a server restart is.
 */

self.window = self;   /* library(wasm) evaluates `X := f(Y)` in a scope that
                       * names `window`; in a worker there is none, and this
                       * one line is the difference between the Prolog being
                       * able to call out and not. */

const CFG = { base: '/le-wasm/', build: 'unknown build', proxy: null, network: true };
let swipl = null;
let booting = null;

const post = (msg) => self.postMessage(msg);
const status = (text, detail) => post({ kind: 'status', text, detail });

/* ---------------------------------------------------------------- the host */

/*  What Prolog calls. One entry point, a JSON string in and a JSON string
 *  out, because that is the shape that survives the bridge unambiguously.
 *  `action` says which: "fetch" (le_wasm_fetch/2) or "open" (the www_browser
 *  shim). Anything else is answered, not thrown: a refusal Prolog can read
 *  beats an exception out of a JavaScript frame it cannot see. */
self.le_wasm_host = function (json) {
    let req;
    try { req = JSON.parse(json); } catch (e) { return JSON.stringify({ error: 'bad host request' }); }
    try {
        switch (req.action || 'fetch') {
            case 'fetch': return JSON.stringify(hostFetch(req));
            case 'open':  post({ kind: 'open', url: req.url }); return JSON.stringify({ ok: true });
            default:      return JSON.stringify({ error: 'unknown host action: ' + req.action });
        }
    } catch (e) {
        return JSON.stringify({ status: 0, headers: {}, body: '', error: String(e) });
    }
};

self.le_wasm_host_origin = function () { return self.location.origin; };

function hostFetch(req) {
    if (!CFG.network) return { status: 0, headers: {}, body: '', error: 'network disabled in this build' };
    const xhr = new XMLHttpRequest();
    xhr.open(req.method || 'GET', req.url, false);          /* false: synchronous, on purpose */
    for (const [name, value] of req.headers || []) {
        try { xhr.setRequestHeader(name, value); } catch (e) { /* forbidden header: the browser's call */ }
    }
    if (req.timeout) { try { xhr.timeout = req.timeout; } catch (e) { /* not settable here */ } }
    try {
        xhr.send(req.body === null || req.body === undefined ? null : req.body);
    } catch (e) {
        /* A cross-origin request the other server does not allow lands here,
         * with no status and no detail — the browser will not say more, and
         * the page's console is where the real message is. */
        return { status: 0, headers: {}, body: '', error: String(e && e.message || e) };
    }
    const headers = {};
    for (const line of (xhr.getAllResponseHeaders() || '').trim().split(/\r?\n/)) {
        const i = line.indexOf(':');
        if (i > 0) headers[line.slice(0, i).trim().toLowerCase()] = line.slice(i + 1).trim();
    }
    return { status: xhr.status, headers, body: xhr.responseText || '', error: null };
}

/* --------------------------------------------------------------- unpacking */

async function loadPayload(FS) {
    status('Fetching the Logical English payload…');
    const resp = await fetch(CFG.base + 'payload.bin', { cache: 'force-cache' });
    if (!resp.ok) throw new Error(`payload.bin: HTTP ${resp.status}`);
    let buf = new Uint8Array(await resp.arrayBuffer());
    if (buf[0] === 0x1f && buf[1] === 0x8b) {
        /* gzipped by mkpayload.mjs. A host that also applied Content-Encoding
         * has already undone it, hence the test rather than an assumption. */
        const ds = new DecompressionStream('gzip');
        const stream = new Blob([buf]).stream().pipeThrough(ds);
        buf = new Uint8Array(await new Response(stream).arrayBuffer());
    }
    const magic = String.fromCharCode(buf[0], buf[1], buf[2], buf[3]);
    if (magic !== 'LEWP') throw new Error('payload.bin is not a Logical English payload');
    const view = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
    const manifestLen = view.getUint32(4, true);
    const manifest = JSON.parse(new TextDecoder().decode(buf.subarray(8, 8 + manifestLen)));
    const blobAt = 8 + manifestLen;

    status(`Unpacking ${manifest.files.length} files…`);
    const made = new Set();
    const mkdirp = (dir) => {
        if (!dir || dir === '.' || made.has(dir)) return;
        const parent = dir.slice(0, dir.lastIndexOf('/'));
        if (parent && parent !== dir) mkdirp(parent);
        try { FS.mkdir(dir); } catch (e) { /* exists */ }
        made.add(dir);
    };
    mkdirp('/app');
    for (const [rel, off, len] of manifest.files) {
        const path = '/app/' + rel;
        const dir = path.slice(0, path.lastIndexOf('/'));
        mkdirp(dir);
        FS.writeFile(path, buf.subarray(blobAt + off, blobAt + off + len));
    }
    return manifest.files.length;
}

/* ------------------------------------------------------------------- Prolog */

async function boot(config) {
    Object.assign(CFG, config || {});
    status('Loading SWI-Prolog (WebAssembly)…');
    importScripts(CFG.base + 'swipl/swipl-web.js');
    swipl = await self.SWIPL({
        arguments: ['-q'],
        locateFile: (file) => CFG.base + 'swipl/' + file,
        print: (line) => post({ kind: 'log', line }),
        printErr: (line) => post({ kind: 'log', line, err: true })
    });
    const n = await loadPayload(swipl.FS);

    status('Starting Logical English…');
    const t0 = Date.now();
    run("working_directory(_, '/app')");
    run("use_module(library(wasm))");
    run("consult('/app/wasm/le_wasm.pl')");
    run('le_wasm:le_wasm_init(Config)', {
        Config: {
            build: CFG.build,
            proxy: CFG.proxy || '',
            network: CFG.network !== false,
            inferencesPerSecond: CFG.inferencesPerSecond || 0
        }
    });
    const ms = Date.now() - t0;
    status('ready', { files: n, ms });
    post({ kind: 'ready', files: n, ms });
}

/*  A Prolog string crosses the bridge either as a JavaScript string or as
 *  swipl-wasm's tagged form, `{$t: 's', v: '…'}`, depending on how the binding
 *  was made. Both are the same string and the difference is not ours to have
 *  an opinion about. */
function asString(value) {
    if (typeof value === 'string') return value;
    if (value && typeof value === 'object' && typeof value.v === 'string') return value.v;
    return String(value);
}

function run(goal, bindings) {
    const answer = swipl.prolog.query(goal, bindings || {}).once();
    if (answer && answer.error) throw new Error(answer.message || String(answer.error));
    if (answer && answer.success === false) throw new Error('goal failed: ' + goal);
    return answer;
}

/* One operation. Everything that can go wrong on this side is answered in the
 * shape the editor already handles — a JSON object with an `error` — because
 * a client that has to tell a server's failure from a runtime's is a client
 * with two error paths to keep working. */
function call(body) {
    try {
        const answer = run('le_wasm:le_wasm_call(Request, Reply)', { Request: body });
        return asString(answer.Reply);
    } catch (e) {
        return JSON.stringify({ error: 'Operation failed or internal error', detail: String(e && e.message || e) });
    }
}

self.onmessage = async (event) => {
    const msg = event.data || {};
    if (msg.kind === 'boot') {
        if (!booting) {
            booting = boot(msg.config).catch((e) => {
                post({ kind: 'failed', message: String(e && e.message || e) });
                throw e;
            });
        }
        return;
    }
    if (msg.kind === 'call') {
        try {
            await booting;
        } catch (e) {
            post({ kind: 'reply', id: msg.id, json: JSON.stringify({ error: 'The Logical English engine did not start in this browser.', detail: String(e && e.message || e) }) });
            return;
        }
        post({ kind: 'reply', id: msg.id, json: call(msg.body) });
    }
};
