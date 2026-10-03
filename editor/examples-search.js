/*  examples-search.js: the examples' search panel, on the landing page and in
    the editor's "Open example from server".

    The same file is in LogicalEnglish2 (editor/examples-search.js) and LPS2
    (ui/static/examples-search.js); keep the two identical. The landing page
    inlines it after a configuration object; the editor loads it and mounts
    it itself (client.ts, main.js). It writes no closing tag with a bare
    slash, since the page inlines it.

    The panel is a search box, a choice of where to look, a list, a preview
    of the selected program, and an Open button. Typing filters whatever the
    caller lists (the editor's tree of folders), and, a moment later, asks
    the server for the programs that match (operation search_examples) and
    lists those instead, best first, each with the line it matched. A click
    selects a program and previews its first lines; a double click, Enter or
    the Open button opens it; the arrows walk the list.

        window.ExamplesSearch.mount({
            root:      the element to fill,
            t:         function (text) -> text, the translation (optional),
            search:    function (query, scope) -> Promise of [{name, title, field, snippet}],
            preview:   function (name) -> Promise of the program's text,
            open:      function (name),
            idle:      function (query) -> rows to list when no search is on
                       (optional; the editor's tree): {kind: "item", name,
                       label, depth} or {kind: "folder", label, count, blurb,
                       depth, open, toggle: function},
            hint:      what the empty list says (optional),
            scopes:    [{value, label}] (optional; the four below),
            query, scope: what to start with (optional),
            onQuery, onScope: function (value), to remember them (optional),
            previewLines: 30 (optional)
        }) -> { setQuery(q), setScope(s), refresh(), focus(), element }

    On a page served without a server (the WebAssembly build), a request
    fails until the engine is booted in the page; `window.EXAMPLES_SEARCH.boot`
    names the scripts that boot it, loaded on the first failure and the
    request tried again. The landing page's configuration:

        window.EXAMPLES_SEARCH = {
            root: "#examples-search",  api: "/leapi",  token: "…" (optional),
            preview: {operation: "examples", param: "file", field: "document"},
            open: "/editor/index.html?example=",
            boot: ["/le-wasm/config.js", "/le-wasm/boot.js"] (optional),
            labels: {…}, scopes: [{value, label}], query, scope
        };
*/
(function () {
    "use strict";

    var CSS = [
        ".exs { display: flex; flex-direction: column; min-height: 0; flex: 1 1 auto; gap: 6px; font: inherit; }",
        ".exs-bar { display: flex; gap: 6px; align-items: center; }",
        ".exs-bar input { flex: 1 1 auto; min-width: 0; font: inherit; padding: 6px 8px; box-sizing: border-box; }",
        ".exs-bar select { font: inherit; padding: 5px 6px; }",
        ".exs-list { flex: 1 1 auto; min-height: 120px; max-height: 50vh; overflow-y: auto; border: 1px solid rgba(127,127,127,.3); border-radius: 4px; padding: 4px 0; }",
        ".exs-list[hidden], .exs-foot[hidden] { display: none; }",
        ".exs.exs-results-only .exs-list { min-height: 0; }",
        ".exs-row { display: flex; flex-direction: column; gap: 2px; padding: 5px 10px; cursor: pointer; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 13px; line-height: 1.35; }",
        ".exs-row:hover { background: rgba(127,127,127,.15); }",
        ".exs-row.selected { background: var(--exs-selected, #0e639c); color: #fff; }",
        ".exs-row .exs-snippet { font-family: inherit; font-size: 12px; opacity: .75; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }",
        ".exs-row .exs-field { font-size: 11px; opacity: .65; margin-right: 6px; }",
        ".exs-folder { display: flex; gap: 8px; align-items: baseline; padding: 5px 10px; cursor: pointer; font-weight: 600; opacity: .9; }",
        ".exs-folder::before { content: '\\25B8'; width: 1em; flex: none; }",
        ".exs-folder.open::before { content: '\\25BE'; }",
        ".exs-folder .exs-blurb { font-weight: 400; font-size: 12px; opacity: .75; }",
        ".exs-empty { padding: 20px; text-align: center; opacity: .6; }",
        ".exs-preview { margin: 0; max-height: 32vh; overflow: auto; font-size: 12px; line-height: 1.4; padding: 8px 10px; border: 1px solid rgba(127,127,127,.3); border-radius: 4px; white-space: pre; }",
        ".exs-preview:empty { display: none; }",
        ".exs-foot { display: flex; gap: 10px; align-items: center; justify-content: flex-end; }",
        ".exs-status { flex: 1 1 auto; font-size: 12px; opacity: .7; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }",
        ".exs-open { font: inherit; padding: 5px 14px; cursor: pointer; }",
        ".exs-open:disabled { opacity: .5; cursor: default; }"
    ].join("\n");

    function styles() {
        if (document.getElementById("exs-style")) return;
        var s = document.createElement("style");
        s.id = "exs-style";
        s.textContent = CSS;
        document.head.appendChild(s);
    }

    function el(tag, cls, text) {
        var e = document.createElement(tag);
        if (cls) e.className = cls;
        if (text != null) e.textContent = text;
        return e;
    }

    var DEFAULT_SCOPES = [
        { value: "all", label: "everywhere" },
        { value: "name", label: "in names" },
        { value: "templates", label: "in templates" },
        { value: "text", label: "in the text" }
    ];

    function mount(opts) {
        styles();
        var t = opts.t || function (x) { return x; };
        var root = typeof opts.root === "string" ? document.querySelector(opts.root) : opts.root;
        if (!root) return null;
        var minChars = opts.minChars || 2;
        var previewLines = opts.previewLines || 30;
        var scopes = opts.scopes || DEFAULT_SCOPES;

        var panel = el("div", "exs" + (opts.idle ? "" : " exs-results-only"));
        var bar = el("div", "exs-bar");
        var input = el("input");
        input.type = "text";
        input.id = opts.inputId || "example-filter";
        input.placeholder = t(opts.placeholder || "search — a few words, or a phrase in quotes");
        input.autocomplete = "off";
        input.spellcheck = false;
        input.value = opts.query || "";
        var select = el("select");
        select.id = opts.scopeId || "example-scope";
        select.title = t("Where to search: the names of the programs, their templates (the declaration sections), the whole text, or all three");
        scopes.forEach(function (s) {
            var o = el("option", null, t(s.label));
            o.value = s.value;
            select.appendChild(o);
        });
        if (opts.scope && scopes.some(function (s) { return s.value === opts.scope; })) select.value = opts.scope;
        bar.appendChild(input);
        bar.appendChild(select);
        var list = el("div", "exs-list");
        list.id = opts.listId || "example-list";
        var preview = el("pre", "exs-preview");
        preview.id = opts.previewId || "example-preview";
        var foot = el("div", "exs-foot");
        var status = el("span", "exs-status");
        var openBtn = el("button", "exs-open", t("Open"));
        openBtn.type = "button";
        openBtn.disabled = true;
        foot.appendChild(status);
        foot.appendChild(openBtn);
        panel.appendChild(bar);
        panel.appendChild(list);
        panel.appendChild(preview);
        panel.appendChild(foot);
        root.replaceChildren(panel);

        var rows = [];          // [{el, name}] the selectable rows, in order
        var sel = -1;
        var hits = null;        // the server's answer to the current query, or null
        var seq = 0;
        var searchTimer = null, previewTimer = null;

        function query() { return input.value.trim(); }

        function setStatus(text) { status.textContent = text || ""; }

        function showPreview(name) {
            clearTimeout(previewTimer);
            if (!opts.preview) return;
            previewTimer = setTimeout(function () {
                preview.textContent = t("loading…");
                Promise.resolve(opts.preview(name)).then(function (text) {
                    if (rows[sel] && rows[sel].name !== name) return;
                    preview.textContent = typeof text === "string"
                        ? text.split("\n").slice(0, previewLines).join("\n") : "";
                }, function () { preview.textContent = ""; });
            }, 150);
        }

        function select_(i) {
            if (rows.length === 0) { sel = -1; openBtn.disabled = true; return; }
            sel = Math.max(0, Math.min(rows.length - 1, i));
            rows.forEach(function (r, j) { r.el.classList.toggle("selected", j === sel); });
            rows[sel].el.scrollIntoView({ block: "nearest" });
            openBtn.disabled = false;
            showPreview(rows[sel].name);
        }

        function openSelected() {
            if (rows[sel] && opts.open) opts.open(rows[sel].name);
        }

        function itemRow(name, label, depth, snippet, field) {
            var row = el("div", "dropdown-item example-row exs-row");
            row.title = name;
            if (depth) row.style.paddingLeft = (10 + 18 * depth) + "px";
            row.appendChild(el("span", null, label));
            if (snippet) {
                var snip = el("span", "exs-snippet");
                if (field === "templates") snip.appendChild(el("span", "exs-field", t("in templates")));
                else if (field === "text") snip.appendChild(el("span", "exs-field", t("in the text")));
                snip.appendChild(document.createTextNode(snippet));
                row.appendChild(snip);
            }
            row.addEventListener("click", function () { select_(rows.findIndex(function (r) { return r.el === row; })); });
            row.addEventListener("dblclick", function () { select_(rows.findIndex(function (r) { return r.el === row; })); openSelected(); });
            rows.push({ el: row, name: name });
            return row;
        }

        function folderRow(r) {
            var head = el("div", "example-folder exs-folder" + (r.open ? " open" : ""));
            if (r.depth) head.style.paddingLeft = (10 + 18 * r.depth) + "px";
            head.appendChild(el("span", "example-folder-label", r.label + (r.count != null ? "  (" + r.count + ")" : "")));
            if (r.blurb) head.appendChild(el("span", "exs-blurb", r.blurb));
            head.addEventListener("click", function () { if (r.toggle) r.toggle(); draw(); });
            return head;
        }

        function draw() {
            rows = [];
            sel = -1;
            openBtn.disabled = true;
            var out = [];
            var q = query();
            /*  With nothing to list until a search is typed (the landing page:
                no tree), the panel is the box and the scope, and nothing
                else, until the search starts. The editor's picker lists its
                tree meanwhile, so it keeps the whole panel. */
            var compact = !opts.idle && q.length < minChars;
            list.hidden = compact;
            foot.hidden = compact;
            if (compact) { preview.textContent = ""; list.replaceChildren(); return; }
            if (hits && q.length >= minChars) {
                hits.forEach(function (h) { out.push(itemRow(h.name, h.name, 0, h.snippet || h.title || "", h.field)); });
                if (out.length === 0) out.push(el("div", "exs-empty", t("No example matches the search.")));
            } else {
                var idle = opts.idle ? (opts.idle(q) || []) : [];
                idle.forEach(function (r) {
                    if (r.kind === "folder") out.push(folderRow(r));
                    else out.push(itemRow(r.name, r.label || r.name, r.depth || 0, r.snippet, r.field));
                });
                if (out.length === 0) {
                    out.push(el("div", "exs-empty", q.length >= minChars ? t("Searching…")
                        : t(opts.hint || "Type a few words to search the examples.")));
                }
            }
            list.replaceChildren.apply(list, out);
            if (rows.length > 0 && (q || hits)) select_(0);
        }

        /*  A request that fails on a page with no server behind it: boot the
            engine the configuration names, once, and ask again. */
        var booted = false;
        function boot() {
            if (booted || !opts.boot || !opts.boot.length) return Promise.reject(new Error("no server"));
            booted = true;
            return opts.boot.reduce(function (p, src) {
                return p.then(function () {
                    return new Promise(function (resolve, reject) {
                        var s = document.createElement("script");
                        s.src = src;
                        s.onload = resolve;
                        s.onerror = function () { reject(new Error("could not load " + src)); };
                        document.head.appendChild(s);
                    });
                });
            }, Promise.resolve());
        }

        function askServer(q, scope) {
            return Promise.resolve(opts.search(q, scope)).catch(function (e) {
                return boot().then(function () { return opts.search(q, scope); }, function () { throw e; });
            });
        }

        function search() {
            clearTimeout(searchTimer);
            var q = query();
            if (q.length < minChars) { hits = null; setStatus(""); draw(); return; }
            setStatus(t("Searching…"));
            searchTimer = setTimeout(function () {
                var mine = ++seq;
                askServer(q, select.value).then(function (found) {
                    if (mine !== seq) return;
                    hits = Array.isArray(found) ? found : [];
                    setStatus(hits.length ? "" : "");
                    draw();
                }, function (e) {
                    if (mine !== seq) return;
                    hits = null;
                    setStatus((e && e.message) || t("The search failed."));
                    draw();
                });
            }, 200);
        }

        input.addEventListener("input", function () {
            if (opts.onQuery) opts.onQuery(input.value);
            draw();
            search();
        });
        select.addEventListener("change", function () {
            if (opts.onScope) opts.onScope(select.value);
            search();
        });
        input.addEventListener("keydown", function (e) {
            if (e.key === "ArrowDown") { select_(sel + 1); e.preventDefault(); }
            else if (e.key === "ArrowUp") { select_(sel - 1); e.preventDefault(); }
            else if (e.key === "Enter") { e.preventDefault(); if (rows[sel]) openSelected(); }
        });
        list.addEventListener("keydown", function (e) {
            if (e.key === "Enter") { e.preventDefault(); openSelected(); }
        });
        openBtn.addEventListener("click", openSelected);

        draw();
        if (query().length >= minChars) search();

        return {
            element: panel,
            setQuery: function (q) { input.value = q || ""; draw(); search(); },
            setScope: function (s) { select.value = s; search(); },
            refresh: draw,
            focus: function () { input.focus(); input.select(); }
        };
    }

    /*  The landing page: mounted from its configuration, against the server's
        one endpoint, opening a program by address. */
    function mountFromConfig(cfg) {
        var labels = cfg.labels || {};
        function t(s) { return labels[s] || s; }
        function post(body) {
            if (cfg.token) body.token = cfg.token;
            return fetch(cfg.api, {
                method: "POST", headers: { "Content-Type": "application/json" },
                body: JSON.stringify(body)
            }).then(function (r) {
                if (!r.ok) throw new Error("no server (" + r.status + ")");
                return r.json();
            });
        }
        return mount({
            root: cfg.root,
            t: t,
            scopes: cfg.scopes,
            query: cfg.query,
            scope: cfg.scope,
            hint: cfg.hint,
            boot: cfg.boot,
            search: function (q, scope) {
                return post({ operation: "search_examples", query: q, scope: scope }).then(function (d) {
                    if (!Array.isArray(d.hits)) throw new Error(d.error || "no server");
                    return d.hits;
                });
            },
            preview: function (name) {
                var p = cfg.preview || { operation: "examples", param: "file", field: "document" };
                var body = { operation: p.operation };
                body[p.param] = name;
                return post(body).then(function (d) { return d[p.field] || d.error || ""; });
            },
            open: function (name) {
                window.location.href = cfg.open + encodeURIComponent(name);
            }
        });
    }

    window.ExamplesSearch = { mount: mount, mountFromConfig: mountFromConfig };
    if (window.EXAMPLES_SEARCH && window.EXAMPLES_SEARCH.api) {
        var go = function () { mountFromConfig(window.EXAMPLES_SEARCH); };
        if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", go); else go();
    }
})();
