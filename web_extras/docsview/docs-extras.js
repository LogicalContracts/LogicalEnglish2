/* docs-extras.js — what the documentation viewers of LE2 and LPS2 share:
 *
 *  - links to the other IDE's documents, written in the Markdown as
 *    https://lps2.logicalcontracts.com/docs/user/… (or le2.…), rewritten to
 *    wherever the other IDE actually is: lps2.DOMAIN beside le2.DOMAIN, so the
 *    pair can move to another domain without editing a document;
 *  - Mermaid diagrams (```mermaid blocks), drawn with a local copy of Mermaid
 *    loaded only when a document has one;
 *  - the documentation's full-text search, deterministic: the documents of the
 *    table of contents (docs/user/nav.json), split into sections at their
 *    headings, ranked by where the words occur, ties broken by the table of
 *    contents' order.
 *
 *  The same file is in both repositories (LE2 web_extras/docsview/, LPS2
 *  ui/static/): keep the copies identical. A classic script: it defines
 *  window.DocsExtras.
 */
(function () {
    'use strict';

    const CANONICAL = { le2: 'le2.logicalcontracts.com', lps2: 'lps2.logicalcontracts.com' };
    const LOCAL_PORT = { le2: '3000', lps2: '3060' };
    const NAME = { le2: 'Logical English', lps2: 'LPS2' };

    /** The other IDE of the pair. */
    function peerOf(self) { return self === 'le2' ? 'lps2' : 'le2'; }

    /**
     * Where the IDE `which` ('le2' or 'lps2') is, seen from this page:
     *  - this page's own origin, for its own IDE;
     *  - an address set with ?peer=… on a documentation page (kept in this
     *    browser), or, on LE2, the LPS server Run in LPS uses (lps-lpsapi);
     *  - the host name with its first label swapped (le2.DOMAIN ↔ lps2.DOMAIN);
     *  - on a local machine, the default ports (LE2 3000, LPS2 3060);
     *  - otherwise the public installation.
     */
    function originOf(which, self) {
        if (which === self) return location.origin;
        try {
            const p = new URLSearchParams(location.search).get('peer');
            if (p && /^https?:\/\/[^/]+$/.test(p)) localStorage.setItem('docs-peer-origin:' + which, p);
            const kept = localStorage.getItem('docs-peer-origin:' + which);
            if (kept) return kept;
            if (which === 'lps2') {
                const api = localStorage.getItem('lps-lpsapi');
                if (api) return new URL(api).origin;
            }
        } catch { /* no storage */ }
        const { protocol, hostname, port } = location;
        const labels = hostname.split('.');
        if (labels.length > 1 && labels[0] === self) {
            labels[0] = which;
            return `${protocol}//${labels.join('.')}${port ? ':' + port : ''}`;
        }
        if (/^(localhost|127\.0\.0\.1|\[::1\])$/.test(hostname)) {
            return `${protocol}//${hostname}:${LOCAL_PORT[which]}`;
        }
        return 'https://' + CANONICAL[which];
    }

    /** A canonical address of either IDE, as it is from this page. */
    function localizeHref(href, self) {
        let url;
        try { url = new URL(href, location.href); } catch { return href; }
        for (const which of ['le2', 'lps2']) {
            if (url.host === CANONICAL[which]) {
                return originOf(which, self) + url.pathname + url.search + url.hash;
            }
        }
        return href;
    }

    /** Rewrites every link to either IDE under `root` (SVG links too). */
    function rewritePeerLinks(root, self) {
        for (const a of root.querySelectorAll('a')) {
            for (const attr of ['href', 'xlink:href']) {
                const v = a.getAttribute(attr);
                if (!v) continue;
                const w = localizeHref(v, self);
                if (w !== v) a.setAttribute(attr, w);
            }
        }
    }

    let mermaidLoading = null;
    function loadMermaid(src) {
        if (window.mermaid) return Promise.resolve(window.mermaid);
        if (!mermaidLoading) {
            mermaidLoading = new Promise((resolve, reject) => {
                const s = document.createElement('script');
                s.src = src;
                s.onload = () => resolve(window.mermaid);
                s.onerror = () => reject(new Error('could not load ' + src));
                document.head.appendChild(s);
            });
        }
        return mermaidLoading;
    }

    /**
     * Draws the ```mermaid blocks under `root`. A block that cannot be drawn
     * stays as its text.
     */
    async function renderMermaid(root, self, opts) {
        const blocks = [...root.querySelectorAll('pre > code.language-mermaid')];
        if (!blocks.length) return;
        let mermaid;
        try { mermaid = await loadMermaid(opts.mermaidSrc); } catch { return; }
        const dark = opts.dark ?? matchMedia('(prefers-color-scheme: dark)').matches;
        mermaid.initialize({ startOnLoad: false, securityLevel: 'loose', theme: dark ? 'dark' : 'default',
                             flowchart: { htmlLabels: true } });
        let n = 0;
        for (const code of blocks) {
            const pre = code.parentElement;
            try {
                const { svg, bindFunctions } = await mermaid.render('docs-mermaid-' + (n++), code.textContent);
                const fig = document.createElement('div');
                fig.className = 'docs-diagram';
                fig.innerHTML = svg;
                bindFunctions?.(fig);
                pre.replaceWith(fig);
                rewritePeerLinks(fig, self);
                //  A click opens the document in this tab, as a text link does.
                for (const a of fig.querySelectorAll('a')) a.removeAttribute('target');
            } catch (e) {
                pre.title = 'The diagram could not be drawn: ' + (e && e.message || e);
            }
        }
    }

    // ------------------------------------------------------------------
    // Search

    /** Lower case, without accents. */
    function fold(s) {
        return s.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase();
    }

    /** A word's stem: enough to find "variable" for "variables". */
    function stem(w) {
        if (w.length > 4 && w.endsWith('ies')) return w.slice(0, -3) + 'y';
        if (w.length > 4 && /(ches|shes|sses|xes)$/.test(w)) return w.slice(0, -2);
        if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss') && !w.endsWith('us') && !w.endsWith('is')) return w.slice(0, -1);
        return w;
    }

    function words(s) {
        return (fold(s).match(/[\p{L}\p{N}_]+/gu) || []).map(stem);
    }

    /** Markdown inline syntax out: what a reader sees. */
    function plain(md) {
        return md
            .replace(/!\[([^\]]*)\]\([^)]*\)/g, '$1')
            .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
            .replace(/<[^>]+>/g, ' ')
            .replace(/`+/g, '')
            .replace(/\*\*|__/g, '')
            .replace(/(^|\W)[*_](\S[^*_]*?)[*_](?=\W|$)/g, '$1$2')
            .replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
            .replace(/&quot;/g, '"').replace(/&#39;/g, "'");
    }

    /**
     * A document's sections: {heading, level, anchor, text}. The anchors are
     * the viewer's own (opts.slug), counted over every heading as it counts.
     */
    function sections(md, slug) {
        const out = [];
        const seen = new Map();
        let cur = { heading: '', level: 0, anchor: '', lines: [] };
        let fence = null;
        for (const line of md.split('\n')) {
            const f = /^\s*(```+|~~~+)/.exec(line);
            if (f) {
                if (!fence) fence = f[1][0];
                else if (f[1][0] === fence) fence = null;
                cur.lines.push(line.replace(/^\s*(```+|~~~+)\w*/, ''));
                continue;
            }
            const h = !fence && /^(#{1,6})\s+(.+?)\s*#*\s*$/.exec(line);
            if (h) {
                out.push(cur);
                const text = plain(h[2]);
                const base = slug(text);
                const k = seen.get(base) || 0;
                seen.set(base, k + 1);
                cur = { heading: text.trim(), level: h[1].length, anchor: k ? `${base}-${k}` : base, lines: [] };
                continue;
            }
            cur.lines.push(line);
        }
        out.push(cur);
        return out
            .map((s) => ({ heading: s.heading, level: s.level, anchor: s.anchor,
                           text: plain(s.lines.join('\n')).replace(/^\s*[|>*-]+\s*/gm, ' ').replace(/\|/g, ' ').replace(/\s+/g, ' ').trim() }))
            .filter((s) => s.heading || s.text);
    }

    let indexPromise = null;
    /**
     * The index: the documents of nav.json in their order, each with its
     * sections. opts.rawUrl(path) is where a document's Markdown is.
     */
    function buildIndex(opts) {
        if (!indexPromise) {
            indexPromise = fetch(opts.navUrl).then((r) => r.json()).then(async (nav) => {
                const items = [];
                for (const section of nav.sections) {
                    for (const item of section.items) items.push({ ...item, group: section.title });
                }
                const docs = await Promise.all(items.map(async (item, order) => {
                    try {
                        const r = await fetch(opts.rawUrl(item.path));
                        if (!r.ok) return null;
                        const md = await r.text();
                        return { path: item.path, title: item.title, group: item.group, order,
                                 sections: sections(md, opts.slug) };
                    } catch { return null; }
                }));
                return docs.filter(Boolean);
            });
        }
        return indexPromise;
    }

    /** The query: its words, and its quoted phrases (which must occur as they are). */
    function parseQuery(q) {
        const phrases = [];
        const rest = q.replace(/"([^"]+)"/g, (_, p) => { phrases.push(words(p)); return ' '; });
        const terms = [...new Set([...words(rest), ...phrases.flat()])];
        return { terms, phrases: phrases.filter((p) => p.length), whole: words(q) };
    }

    function count(hay, term) {
        let n = 0;
        for (const w of hay) if (w === term) n++;
        return n;
    }

    function hasPhrase(hay, phrase) {
        outer: for (let i = 0; i + phrase.length <= hay.length; i++) {
            for (let j = 0; j < phrase.length; j++) if (hay[i + j] !== phrase[j]) continue outer;
            return true;
        }
        return false;
    }

    function phraseCount(hay, phrase) {
        let n = 0;
        outer: for (let i = 0; i + phrase.length <= hay.length; i++) {
            for (let j = 0; j < phrase.length; j++) if (hay[i + j] !== phrase[j]) continue outer;
            n++;
        }
        return n;
    }

    /**
     * Ranked results: [{doc, section, score}], best first. Every word must
     * occur in the section (its heading, its text or its document's title)
     * and every quoted phrase too. Score: a word in a heading 10, in the
     * document's title 4, in the text 1 per occurrence up to 8; the whole
     * query as a phrase adds 25 in a heading and 3 per occurrence in the
     * text. Ties: the table of contents' order, then the section's.
     */
    async function search(q, opts) {
        const query = parseQuery(q);
        if (!query.terms.length) return [];
        const docs = await buildIndex(opts);
        const hits = [];
        for (const doc of docs) {
            const titleW = words(doc.title);
            doc.sections.forEach((sec, i) => {
                const headW = words(sec.heading);
                const textW = words(sec.text);
                const all = [...headW, ...textW, ...titleW];
                for (const p of query.phrases) {
                    if (!hasPhrase(headW, p) && !hasPhrase(textW, p)) return;
                }
                let score = 0;
                for (const t of query.terms) {
                    const h = count(headW, t), d = count(titleW, t), x = count(textW, t);
                    if (!h && !d && !x) return;
                    score += 10 * Math.min(h, 2) + 4 * Math.min(d, 1) + Math.min(x, 8);
                }
                if (query.whole.length > 1) {
                    if (hasPhrase(headW, query.whole)) score += 25;
                    score += 3 * Math.min(phraseCount(textW, query.whole), 5);
                }
                //  A section that only shares the document's title is noise.
                if (!query.terms.some((t) => headW.includes(t) || textW.includes(t))) return;
                hits.push({ doc, section: sec, index: i, score });
            });
        }
        hits.sort((a, b) => b.score - a.score || a.doc.order - b.doc.order || a.index - b.index);
        return hits;
    }

    function escapeHtml(s) {
        return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    }

    /** Some text around the first occurrence of a word of the query, the words marked. */
    function snippet(text, query) {
        const folded = fold(text);
        const re = new RegExp('[\\p{L}\\p{N}_]+', 'gu');
        let first = -1;
        const marks = [];
        let m;
        while ((m = re.exec(folded))) {
            if (query.terms.includes(stem(m[0]))) {
                marks.push([m.index, m.index + m[0].length]);
                if (first < 0) first = m.index;
            }
        }
        if (first < 0) return escapeHtml(text.slice(0, 200)) + (text.length > 200 ? '…' : '');
        const from = Math.max(0, text.lastIndexOf(' ', Math.max(0, first - 90)));
        const to = Math.min(text.length, first + 170);
        let out = from > 0 ? '…' : '';
        let at = from;
        for (const [s, e] of marks) {
            if (s < from || e > to) continue;
            out += escapeHtml(text.slice(at, s)) + '<mark>' + escapeHtml(text.slice(s, e)) + '</mark>';
            at = e;
        }
        out += escapeHtml(text.slice(at, to)) + (to < text.length ? '…' : '');
        return out;
    }

    /**
     * The search page, in `root`. opts: self, navUrl, rawUrl(path),
     * docUrl(path) (the rendered document), slug(text), searchUrl (this
     * page's path), t(text) (translation; identity by default).
     * URL parameters: q, the query; about, what "Documentation for this"
     * was asked about (shown above the results); word, the word itself, offered
     * as a search of its own.
     */
    async function renderSearchPage(root, opts) {
        const t = opts.t || ((s) => s);
        const params = new URLSearchParams(location.search);
        const q = (params.get('q') || '').trim();
        const about = params.get('about') || '';
        const word = params.get('word') || '';
        const peer = peerOf(opts.self);
        document.title = (q ? `${q} — ` : '') + t('Search the documentation');
        root.innerHTML = '';
        const h = document.createElement('h1');
        h.textContent = about ? t('Documentation for this') : t('Search the documentation');
        root.appendChild(h);
        const form = document.createElement('form');
        form.className = 'docs-search-form';
        form.action = opts.searchUrl;
        form.method = 'get';
        form.innerHTML = `<input type="search" name="q" autofocus aria-label="${escapeHtml(t('Search the documentation'))}">`
            + `<button type="submit">${escapeHtml(t('Search'))}</button>`;
        form.q.value = q;
        root.appendChild(form);
        if (about) {
            const p = document.createElement('p');
            p.className = 'docs-search-about';
            p.textContent = about;
            root.appendChild(p);
        }
        const status = document.createElement('p');
        status.className = 'docs-search-status';
        root.appendChild(status);
        if (!q) {
            status.textContent = t('Words that must all occur; "a phrase in quotes" must occur as it is.');
            return;
        }
        status.textContent = t('Searching…');
        let hits;
        try { hits = await search(q, opts); } catch (e) { status.textContent = String(e); return; }
        const query = parseQuery(q);
        const byDoc = new Map();
        for (const hit of hits) {
            if (!byDoc.has(hit.doc)) byDoc.set(hit.doc, []);
            byDoc.get(hit.doc).push(hit);
        }
        status.textContent = hits.length
            ? t('{n} sections in {d} documents').replace('{n}', hits.length).replace('{d}', byDoc.size)
            : t('Nothing found.');
        const list = document.createElement('div');
        list.className = 'docs-search-results';
        for (const [doc, docHits] of byDoc) {
            const box = document.createElement('section');
            const dh = document.createElement('h2');
            const da = document.createElement('a');
            da.href = opts.docUrl(doc.path);
            da.textContent = doc.title;
            dh.appendChild(da);
            const g = document.createElement('small');
            g.textContent = ' · ' + doc.group;
            dh.appendChild(g);
            box.appendChild(dh);
            const ul = document.createElement('ul');
            for (const hit of docHits) {
                const li = document.createElement('li');
                const a = document.createElement('a');
                a.href = opts.docUrl(doc.path) + (hit.section.anchor && hit.section.level > 1 ? '#' + hit.section.anchor : '');
                a.textContent = hit.section.heading && hit.section.level > 1 ? hit.section.heading : doc.title;
                li.appendChild(a);
                const s = document.createElement('div');
                s.className = 'docs-search-snippet';
                s.innerHTML = snippet(hit.section.text, query);
                li.appendChild(s);
                ul.appendChild(li);
            }
            box.appendChild(ul);
            list.appendChild(box);
        }
        root.appendChild(list);
        const more = document.createElement('p');
        more.className = 'docs-search-more';
        if (word && fold(word) !== fold(q)) {
            const a = document.createElement('a');
            a.href = `${opts.searchUrl}?q=${encodeURIComponent('"' + word + '"')}`;
            a.textContent = t('Search for “{w}” instead').replace('{w}', word);
            more.appendChild(a);
            more.appendChild(document.createTextNode(' · '));
        }
        const pa = document.createElement('a');
        pa.href = `${originOf(peer, opts.self)}/docs/search?q=${encodeURIComponent(q)}`;
        pa.textContent = t('Search the {name} documentation too').replace('{name}', NAME[peer]);
        more.appendChild(pa);
        root.appendChild(more);
    }

    window.DocsExtras = { originOf, peerOf, localizeHref, rewritePeerLinks, renderMermaid,
                          search, sections, renderSearchPage, words, stem };
})();
