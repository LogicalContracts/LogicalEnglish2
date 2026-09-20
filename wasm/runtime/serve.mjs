/* serve.mjs — the built site, locally, with the host's routing applied.
 *
 * `python3 -m http.server` serves the files and nothing else, which is enough
 * to open the editor at /editor/index.html but not enough to be the
 * deployment: /editor, /executive, /docs/<name> and /multilingual?lang=xx are
 * rewrites, and they are where the links go.
 *
 * So this reads the redirects, rewrites and headers out of the build's own
 * vercel.json — one source of truth for both hosts, rather than a second list
 * here that can drift from the first — and applies them the way Vercel does:
 * the redirects first, then the file system, then the rewrites in order.
 *
 *     node wasm/runtime/serve.mjs wasm/dist 8080
 */
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { join, extname, normalize } from 'node:path';

const dir = process.argv[2] || 'wasm/dist';
const port = Number(process.argv[3] || 8080);

const config = JSON.parse(await readFile(join(dir, 'vercel.json'), 'utf8').catch(() => '{}'));
const rewrites = config.rewrites || [];
const redirects = config.redirects || [];
const headerRules = config.headers || [];

const TYPES = {
    '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
    '.mjs': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8',
    '.json': 'application/json; charset=utf-8', '.wasm': 'application/wasm',
    '.data': 'application/octet-stream', '.bin': 'application/octet-stream',
    '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml',
    '.ttf': 'font/ttf', '.woff2': 'font/woff2', '.md': 'text/markdown; charset=utf-8',
    '.le': 'text/plain; charset=utf-8', '.pl': 'text/plain; charset=utf-8',
    '.lps': 'text/plain; charset=utf-8', '.txt': 'text/plain; charset=utf-8'
};

/*  Vercel's `source` is a path pattern: `:name` for one segment, `:name*` for
 *  the rest, and a bare `(.*)` group whose match the destination refers to as
 *  `$1`. Only those three appear in the generated file, and only those three
 *  are implemented here — deliberately, since a half-right regular expression
 *  translator that silently matches the wrong thing would be worse than none.
 */
function toRegExp(source) {
    const names = [];
    const token = /\(\.\*\)|:(\w+)\*|:(\w+)|[\s\S]/g;
    let pattern = '';
    let m;
    while ((m = token.exec(source)) !== null) {
        if (m[0] === '(.*)') { names.push(null); pattern += '(.*)'; }
        else if (m[1] !== undefined) { names.push(m[1]); pattern += '(.*)'; }
        else if (m[2] !== undefined) { names.push(m[2]); pattern += '([^/]+)'; }
        else pattern += m[0].replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    }
    return { re: new RegExp('^' + pattern + '$'), names };
}

function applyRewrites(pathname, query) {
    for (const rule of rewrites) {
        const { re, names } = toRegExp(rule.source);
        const m = re.exec(pathname);
        if (!m) continue;
        if (rule.has && !rule.has.every((h) => h.type === 'query' && query.get(h.key) === h.value)) continue;
        let dest = rule.destination;
        names.forEach((name, i) => {
            const value = m[i + 1] ?? '';
            if (name) dest = dest.split(':' + name + '*').join(value).split(':' + name).join(value);
            else dest = dest.split('$' + (i + 1)).join(value);
        });
        return dest.split('?')[0];
    }
    return null;
}

function extraHeaders(pathname) {
    const out = {};
    for (const rule of headerRules) {
        const { re } = toRegExp(rule.source);
        if (re.test(pathname)) for (const h of rule.headers) out[h.key] = h.value;
    }
    return out;
}

async function fileFor(pathname) {
    const rel = normalize(decodeURIComponent(pathname)).replace(/^(\.\.[/\\])+/, '');
    let file = join(dir, rel);
    try {
        const info = await stat(file);
        if (info.isDirectory()) file = join(file, 'index.html');
        else return file;
        await stat(file);
        return file;
    } catch { return null; }
}

createServer(async (request, response) => {
    const url = new URL(request.url, 'http://localhost');

    /*  Redirects come before everything, as they do on the host: an old
     *  address is answered with its new one, not with a page. */
    for (const rule of redirects) {
        const { re, names } = toRegExp(rule.source);
        const m = re.exec(url.pathname);
        if (!m) continue;
        let dest = rule.destination;
        names.forEach((name, i) => {
            const value = m[i + 1] ?? '';
            if (name) dest = dest.split(':' + name + '*').join(value).split(':' + name).join(value);
            else dest = dest.split('$' + (i + 1)).join(value);
        });
        response.writeHead(rule.permanent === false ? 302 : 301, { Location: dest });
        response.end();
        return;
    }

    let file = await fileFor(url.pathname);
    if (!file) {
        const rewritten = applyRewrites(url.pathname, url.searchParams);
        if (rewritten) file = await fileFor(rewritten);
    }
    if (!file) { response.writeHead(404, { 'Content-Type': 'text/plain' }); response.end('not found\n'); return; }
    const body = await readFile(file);
    const headers = {
        'Content-Type': TYPES[extname(file)] || 'application/octet-stream',
        ...extraHeaders(url.pathname)
    };
    response.writeHead(200, headers);
    response.end(body);
}).listen(port, () => console.log(`serving ${dir} on http://localhost:${port}/ (vercel.json routing applied)`));
