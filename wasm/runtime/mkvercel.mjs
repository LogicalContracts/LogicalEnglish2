/* mkvercel.mjs — the host's half of the routing.
 *
 * Almost nothing: a static site is mostly files at the paths they are already
 * at. What is left is the handful of addresses the SWI-Prolog server answered
 * with something other than a file of the same name, and they are here so that
 * a link into one deployment still lands in the other:
 *
 *   /editor, /executive      pages the server redirected to
 *   /docs/<name>             a document by name, without the .md — the server
 *                            served the viewer shell and let it fetch the
 *                            Markdown; the rewrite does the same, and only
 *                            when no actual file matches (Vercel checks the
 *                            file system first)
 *   /multilingual?lang=xx    one page per language, chosen by query string
 *   /source/<example>        the example's text, which has no extension and so
 *                            needs to be told what it is
 *
 * Caching: everything under /le-wasm/ is content that changes only when the
 * build does, and it is 4 MB of it, so it is immutable for a year — with the
 * payload and the pages deliberately NOT, since a redeploy has to be able to
 * change them.
 *
 * Usage: node mkvercel.mjs <dist-dir> <repo-root>
 */
import { writeFileSync, readdirSync, readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const [, , dist, root] = process.argv;
if (!dist) { console.error('usage: node mkvercel.mjs <dist-dir> <repo-root>'); process.exit(2); }

const langs = readdirSync(dist)
    .map((f) => /^multilingual\.([a-z]{2})\.html$/.exec(f))
    .filter(Boolean).map((m) => m[1]);

/*  A document's old address. The server answers those with a 301
 *  (`doc_moved/2`), and a link in a two-year-old paper is exactly the kind of
 *  thing that has to keep working; build.sh asks the Prolog for the list, so
 *  this file does not carry a second copy of it that could go stale. */
let redirects = [];
try {
    redirects = readFileSync(join(dist, '.doc-redirects'), 'utf8').split('\n')
        .map((line) => line.trim().split(/\s+/))
        .filter((pair) => pair.length === 2 && pair[0])
        .flatMap(([from, to]) => [
            { source: `/docs/${from}`, destination: `/docs/${to}`, permanent: true },
            { source: `/docs/${from}.md`, destination: `/docs/${to}.md`, permanent: true }
        ]);
} catch { /* no list: the build was made without one */ }

const config = {
    $schema: 'https://openapi.vercel.sh/vercel.json',
    cleanUrls: false,
    trailingSlash: false,
    headers: [
        {
            source: '/le-wasm/swipl/(.*)',
            headers: [{ key: 'Cache-Control', value: 'public, max-age=31536000, immutable' }]
        },
        {
            source: '/le-wasm/payload.bin',
            headers: [
                { key: 'Cache-Control', value: 'public, max-age=300, must-revalidate' },
                { key: 'Content-Type', value: 'application/octet-stream' }
            ]
        },
        {
            source: '/source/(.*)',
            headers: [{ key: 'Content-Type', value: 'text/plain; charset=utf-8' }]
        }
    ],
    redirects,
    rewrites: [
        ...langs.map((lang) => ({
            source: '/multilingual',
            has: [{ type: 'query', key: 'lang', value: lang }],
            destination: `/multilingual.${lang}.html`
        })),
        { source: '/multilingual', destination: '/multilingual.html' },
        { source: '/editor', destination: '/editor/index.html' },
        { source: '/executive', destination: '/web_extras/executive/index.html' },
        { source: '/docs/search', destination: '/web_extras/docsview/viewer.html' },
        //  `/docs/user/…` and not `/docs/…`: the server publishes docs/user
        //  and nothing else (public_doc/1), and a rewrite that caught the
        //  whole tree would answer /docs/project/plans/… with a viewer shell
        //  — a 200 where the deployment being copied says 404.
        { source: '/docs/user/(.*)', destination: '/web_extras/docsview/viewer.html' }
    ]
};

writeFileSync(join(dist, 'vercel.json'), JSON.stringify(config, null, 4) + '\n');
console.log(`  vercel.json: ${config.rewrites.length} rewrites, ${config.redirects.length} redirects, ${langs.length} languages`);

/*  The same routing, for a host that is not Vercel. `python3 -m http.server`
 *  serves files and nothing else, which is enough to try the build out: the
 *  editor is at /editor/index.html and the documentation at its .md paths. */
writeFileSync(join(dist, 'STATIC-HOSTS.md'), `# Serving this directory somewhere other than Vercel

Everything here is a file, and the addresses that are not files are listed in
\`vercel.json\`. On another host, do the same:

| Address | Serve |
|---------|-------|
| \`/editor\` | \`/editor/index.html\` |
| \`/executive\` | \`/web_extras/executive/index.html\` |
| \`/docs/user/<anything not a file>\` | \`/web_extras/docsview/viewer.html\` |
| \`/multilingual?lang=xx\` | \`/multilingual.xx.html\` |
| \`/source/*\` | as \`text/plain\` |

\`redirects\` are the old addresses of documents that have moved: a 301 each,
generated from the server's own \`doc_moved/2\`.

Without any of them the site still works — the editor at
\`/editor/index.html\`, the documentation at its \`.md\` paths — so a plain
\`python3 -m http.server\` in this directory is a fair way to try it.

The one thing a host must not do is strip or re-encode \`/le-wasm/payload.bin\`:
it is gzip, and the worker un-gzips it itself when the host has not.
`);
