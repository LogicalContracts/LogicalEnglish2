/* inject.mjs — put the runtime's script tags into the pages that need them.
 *
 * A page of LE2 is written against a server, and what makes it work without
 * one is boot.js replacing `fetch` before the page's own scripts run. That
 * means a *classic* script tag in <head>: module scripts are deferred, so a
 * plain one ahead of them has finished before they start, and nothing else
 * can take a reference to the original fetch first.
 *
 * Only the pages that talk to /leapi get it. The landing page, the
 * multilingual pages and the documentation viewer are static text; booting a
 * 4 MB engine to read them would be a cost with nothing on the other side of
 * it, and the editor they link to boots it soon enough.
 *
 * Usage: node inject.mjs <dist-dir>
 */
import { readdirSync, readFileSync, writeFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const dist = process.argv[2];
if (!dist) { console.error('usage: node inject.mjs <dist-dir>'); process.exit(2); }

const WANTED = ['editor/', 'web_extras/executive/'];
const SKIP = ['web_extras/docsview/'];
/*  No <link rel=preload> for the runtime and the payload, though they are the
 *  page's critical path and it is the obvious thing to reach for. A preload
 *  is the *document's* fetch, and these two are fetched by the worker, which
 *  is a different context: Chromium downloads them twice and then warns that
 *  the preload went unused. Starting the worker from <head> — which boot.js
 *  does, rather than waiting for DOMContentLoaded — buys the same overlap
 *  honestly. */
const TAGS = [
    '<script src="/le-wasm/config.js"></script>',
    '<script src="/le-wasm/boot.js"></script>'
].join('\n') + '\n';

function* htmlFiles(dir) {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
        const path = join(dir, entry.name);
        if (entry.isDirectory()) yield* htmlFiles(path);
        else if (entry.isFile() && entry.name.endsWith('.html')) yield path;
    }
}

let touched = 0;
for (const file of htmlFiles(dist)) {
    const rel = relative(dist, file).split('\\').join('/');
    if (!WANTED.some((w) => rel.startsWith(w))) continue;
    if (SKIP.some((s) => rel.startsWith(s))) continue;
    let html = readFileSync(file, 'utf8');
    if (html.includes('/le-wasm/boot.js')) continue;
    const head = html.search(/<head[^>]*>/i);
    if (head >= 0) {
        const at = html.indexOf('>', head) + 1;
        html = html.slice(0, at) + '\n' + TAGS + html.slice(at);
    } else {
        html = TAGS + html;
    }
    writeFileSync(file, html);
    touched++;
}
console.log(`  runtime injected into ${touched} pages`);
