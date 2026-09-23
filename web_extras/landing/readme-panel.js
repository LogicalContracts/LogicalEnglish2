/*  readme-panel.js: a folder's README, read beside the list of examples.

    The same file is in LogicalEnglish2 (web_extras/landing/readme-panel.js)
    and LPS2 (src/edges/readme_panel.js); keep the two identical. The landing
    page inlines it after a configuration object:

        window.EXAMPLE_README = {
            folders:  "details.le-folder[data-path]",   the folders of the list
            editor:   "/editor/index.html?example=",   opens a program by name
            viewer:   "/executive?program=",           (optional) a program with a view
            programs: ["le"],                          extensions of programs, dropped from a name
            keepExt:  ["pddl", "drl"],                 extensions of programs a name keeps
            source:   "https://github.com/…/blob/main/", where other files are read
            about:    "About this folder",  close: "Close",
            copy:     "Copy the web address of this README",  copied: "Copied"
        };

    The server puts each folder's README.md, as text, in a hidden element
    <div class="readme-src" data-for="<the folder's data-path>"
    data-name="<its example-name prefix>" data-repo="<its path in the
    repository>">. This script adds a button to that folder's heading that
    opens the README in a side panel, rendered by the small Markdown reader
    below (headings, paragraphs, lists, tables, quotes, code, links, bold and
    italic: what a README needs).

    Links in a README are written as they work on GitHub, relative to the
    README, and are read here as:
      - `tariff.le`, `sub/x.le?scenario=a&query=b`: open the program in the
        editor, on that scenario and question (`view=` opens the view);
      - `customs/` or `customs/README.md`: that folder's README, in the panel,
        when the page lists the folder, else on GitHub;
      - any other relative file: on GitHub; an absolute address: as it is.
    `?readme=<folder>` in the page's address opens that folder's README, and
    the link symbol at the top of the panel copies that address (the symbol
    is a real link, so the browser's own "Copy link" works too).

    It writes a closing tag as "<\/…", never with a bare slash, since the page
    inlines it.  */
(function () {
    "use strict";
    var C = window.EXAMPLE_README || {};
    var srcs = {}, byRepo = {};

    function esc(s) {
        return String(s).replace(/&/g, "&amp;").replace(/[<]/g, "&lt;")
            .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
    }

    /* ---- the Markdown reader ---- */
    function inline(s, ctx) {
        var codes = [];
        s = s.replace(/`([^`]+)`/g, function (m, c) { codes.push(c); return "\u0000" + (codes.length - 1) + "\u0000"; });
        s = esc(s);
        s = s.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, function (m, text, url) {
            var h = href(url.replace(/&amp;/g, "&"), ctx);
            var ext = /^https?:/.test(h) ? ' target="_blank" rel="noopener"' : "";
            return '<a href="' + esc(h) + '"' + ext + (h.charAt(0) === "#" ? ' data-readme="' + esc(h.slice(1)) + '"' : "") + ">" + text + "<\/a>";
        });
        s = s.replace(/\*\*([^*]+)\*\*/g, "<strong>$1<\/strong>");
        s = s.replace(/(^|[^\w*])\*([^*\s][^*]*)\*/g, "$1<em>$2<\/em>");
        s = s.replace(/(^|[^\w])_([^_\s][^_]*)_(?=[^\w]|$)/g, "$1<em>$2<\/em>");
        s = s.replace(/\u0000(\d+)\u0000/g, function (m, i) { return "<code>" + esc(codes[+i]) + "<\/code>"; });
        return s;
    }

    function cells(line) {
        return line.trim().replace(/^\|/, "").replace(/\|$/, "").split("|").map(function (c) { return c.trim(); });
    }

    function render(md, ctx) {
        var lines = md.replace(/\r/g, "").split("\n"), out = [], i = 0, para = [];
        function flush() { if (para.length) { out.push("<p>" + inline(para.join(" "), ctx) + "<\/p>"); para = []; } }
        while (i < lines.length) {
            var l = lines[i], m;
            if (/^```/.test(l)) {
                flush();
                var code = [];
                for (i++; i < lines.length && !/^```/.test(lines[i]); i++) code.push(lines[i]);
                out.push("<pre><code>" + esc(code.join("\n")) + "<\/code><\/pre>");
                i++; continue;
            }
            if ((m = /^(#{1,4})\s+(.*)$/.exec(l))) {
                flush();
                var n = m[1].length + 1;
                out.push("<h" + n + ">" + inline(m[2], ctx) + "<\/h" + n + ">");
                i++; continue;
            }
            if (/^\s*$/.test(l)) { flush(); i++; continue; }
            if (/^(-{3,}|\*{3,})\s*$/.test(l)) { flush(); out.push("<hr>"); i++; continue; }
            if (/^\s*\|/.test(l) && i + 1 < lines.length && /^\s*\|?\s*:?-{2,}/.test(lines[i + 1])) {
                flush();
                var head = cells(l), rows = [];
                for (i += 2; i < lines.length && /^\s*\|/.test(lines[i]); i++) rows.push(cells(lines[i]));
                out.push("<table><thead><tr>" + head.map(function (c) { return "<th>" + inline(c, ctx) + "<\/th>"; }).join("") +
                    "<\/tr><\/thead><tbody>" + rows.map(function (r) {
                        return "<tr>" + r.map(function (c) { return "<td>" + inline(c, ctx) + "<\/td>"; }).join("") + "<\/tr>";
                    }).join("") + "<\/tbody><\/table>");
                continue;
            }
            if (/^>\s?/.test(l)) {
                flush();
                var q = [];
                for (; i < lines.length && /^>\s?/.test(lines[i]); i++) q.push(lines[i].replace(/^>\s?/, ""));
                out.push("<blockquote>" + render(q.join("\n"), ctx) + "<\/blockquote>");
                continue;
            }
            if (/^\s*([-*]|\d+[.)])\s+/.test(l)) {
                flush();
                var block = [];
                for (; i < lines.length; i++) {
                    var li = lines[i];
                    if (/^\s*$/.test(li)) {
                        if (i + 1 < lines.length && /^\s+\S|^\s*([-*]|\d+[.)])\s+/.test(lines[i + 1])) { block.push(""); continue; }
                        break;
                    }
                    if (!/^\s*([-*]|\d+[.)])\s+/.test(li) && !/^\s+/.test(li)) break;
                    block.push(li);
                }
                out.push(list(block, ctx));
                continue;
            }
            para.push(l.trim());
            i++;
        }
        flush();
        return out.join("\n");
    }

    /* A list, its items' continuation lines and the lists nested in them. */
    function list(block, ctx) {
        var indent = /^(\s*)/.exec(block[0])[1].length;
        var ordered = /^\s*\d+[.)]\s+/.test(block[0]);
        var items = [], cur = null;
        block.forEach(function (l) {
            var m = /^(\s*)([-*]|\d+[.)])\s+(.*)$/.exec(l);
            if (m && m[1].length <= indent) { cur = [m[3]]; items.push(cur); }
            else if (cur) cur.push(l.length > indent + 2 ? l.slice(Math.min(indent + 2, /^(\s*)/.exec(l)[1].length)) : l.trim());
        });
        var tag = ordered ? "ol" : "ul";
        return "<" + tag + ">" + items.map(function (it) {
            var first = [], j = 0;
            while (j < it.length && it[j] !== "" && !/^\s*([-*]|\d+[.)])\s+/.test(it[j])) { first.push(it[j].trim()); j++; }
            var rest = it.slice(j).join("\n");
            return "<li>" + inline(first.join(" "), ctx) + (rest.trim() ? render(rest, ctx) : "") + "<\/li>";
        }).join("") + "<\/" + tag + ">";
    }

    /* ---- where a link goes ---- */
    function normalise(path) {
        var out = [];
        path.split("/").forEach(function (p) {
            if (p === "..") out.pop(); else if (p !== "." && p !== "") out.push(p);
        });
        return out.join("/");
    }

    function href(url, ctx) {
        if (/^([a-z]+:|\/|#)/i.test(url)) return url;
        var hash = "", q = "";
        var h = url.indexOf("#"); if (h >= 0) { hash = url.slice(h); url = url.slice(0, h); }
        var k = url.indexOf("?"); if (k >= 0) { q = url.slice(k + 1); url = url.slice(0, k); }
        var dir = /\/$/.test(url) || url === "" || /(^|\/)README\.md$/.test(url);
        var rel = normalise(ctx.name + url.replace(/(^|\/)README\.md$/, "$1"));
        var repo = normalise(ctx.repo + "/" + url);
        if (dir) {
            var folder = normalise(ctx.repo + "/" + url.replace(/(^|\/)README\.md$/, "$1"));
            if (byRepo[folder] !== undefined) return "#" + byRepo[folder];
            return (C.source || "").replace(/\/blob\//, "/tree/") + folder;
        }
        var m = /^(.*)\.([A-Za-z0-9]+)$/.exec(rel), ext = m ? m[2] : "";
        var keep = (C.keepExt || []).indexOf(ext) >= 0, drop = (C.programs || ["le"]).indexOf(ext) >= 0;
        if (m && (keep || drop) && !/(^|\/)sources\//.test(rel)) {
            var name = keep ? rel : m[1];
            var params = new URLSearchParams(q);
            if (params.has("view") && C.viewer) {
                return C.viewer + encodeURI(name) + "&" + params.toString() + hash;
            }
            return C.editor + encodeURI(name) + (q ? "&" + params.toString() : "") + hash;
        }
        return (C.source || "") + repo + hash;
    }

    /* ---- the panel ---- */
    var panel, body, copy;

    function copyText(text, done) {
        function fallback() {
            var ta = document.createElement("textarea");
            ta.value = text; ta.setAttribute("readonly", "");
            ta.style.position = "fixed"; ta.style.opacity = "0";
            document.body.appendChild(ta); ta.select();
            try { if (document.execCommand("copy")) done(); } catch (e) {}
            document.body.removeChild(ta);
        }
        if (navigator.clipboard && window.isSecureContext) {
            navigator.clipboard.writeText(text).then(done, fallback);
        } else { fallback(); }
    }

    /* The page's address, opening on the README of the folder Key. */
    function readmeUrl(key) {
        var u = new URL(window.location.href);
        u.hash = "";
        u.searchParams.delete("expand");
        u.searchParams.delete("dir");
        u.searchParams.set("readme", key.replace(/\/+$/, ""));
        return u.toString().replace(/%2F/gi, "/");
    }
    function build() {
        if (panel) return;
        var st = document.createElement("style");
        st.textContent =
            ".readme-panel{position:fixed;top:0;right:0;bottom:0;width:min(560px,100%);z-index:50;" +
            "background:var(--readme-bg,#fff);color:inherit;border-left:1px solid rgba(128,128,128,.35);" +
            "box-shadow:-6px 0 24px rgba(0,0,0,.18);overflow-y:auto;padding:14px 22px 40px;" +
            "font:15px/1.55 -apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;display:none}" +
            ".readme-panel.open{display:block}" +
            ".readme-panel .readme-bar{position:sticky;top:0;float:right;display:flex;gap:10px;align-items:center;background:var(--readme-bg,#fff);padding:2px 0 2px 8px}" +
            ".readme-panel .readme-close{font-size:14px;cursor:pointer;" +
            "background:inherit;border:1px solid rgba(128,128,128,.4);border-radius:4px;padding:2px 8px;color:inherit}" +
            ".readme-panel a.readme-copy{font-size:13px;text-decoration:none;opacity:.7;color:inherit}" +
            ".readme-panel a.readme-copy:hover,.readme-panel a.readme-copy.copied{opacity:1}" +
            ".readme-panel h2,.readme-panel h3,.readme-panel h4,.readme-panel h5{text-transform:none;letter-spacing:normal;opacity:1}" +
            ".readme-panel h2{font-size:21px;margin:6px 0 10px}.readme-panel h3{font-size:17px;margin:18px 0 6px}" +
            ".readme-panel h4{font-size:15px;margin:14px 0 4px}" +
            ".readme-panel code{font:13px ui-monospace,SFMono-Regular,Menlo,monospace;background:rgba(128,128,128,.14);padding:1px 4px;border-radius:3px}" +
            ".readme-panel pre{background:rgba(128,128,128,.12);padding:10px 12px;border-radius:6px;overflow-x:auto}" +
            ".readme-panel pre code{background:none;padding:0}" +
            ".readme-panel table{border-collapse:collapse;font-size:14px}.readme-panel td,.readme-panel th{border:1px solid rgba(128,128,128,.35);padding:3px 7px;vertical-align:top}" +
            ".readme-panel blockquote{margin:8px 0;padding:2px 12px;border-left:3px solid rgba(128,128,128,.5)}" +
            ".readme-panel a{color:#0e639c}" +
            ".readme-button{margin-left:6px;font-size:12px;cursor:pointer;opacity:.75;border:none;background:none;padding:0 2px;color:inherit}" +
            ".readme-button:hover{opacity:1;text-decoration:underline}" +
            "@media (prefers-color-scheme: dark){.readme-panel{--readme-bg:#1e1e1e}.readme-panel a{color:#6db3ff}}";
        document.head.appendChild(st);
        panel = document.createElement("aside");
        panel.className = "readme-panel";
        panel.setAttribute("role", "dialog");
        var close = document.createElement("button");
        close.className = "readme-close";
        close.textContent = "✕ " + (C.close || "Close");
        close.addEventListener("click", hide);
        var label = "\uD83D\uDD17 " + (C.copy || "Copy the web address of this README");
        copy = document.createElement("a");
        copy.className = "readme-copy";
        copy.textContent = label;
        copy.title = C.copy || "Copy the web address of this README";
        copy.addEventListener("click", function (e) {
            e.preventDefault();
            copyText(copy.href, function () {
                copy.textContent = C.copied || "Copied"; copy.classList.add("copied");
                setTimeout(function () { copy.textContent = label; copy.classList.remove("copied"); }, 1500);
            });
        });
        var bar = document.createElement("div");
        bar.className = "readme-bar";
        bar.appendChild(copy);
        bar.appendChild(close);
        body = document.createElement("div");
        panel.appendChild(bar);
        panel.appendChild(body);
        document.body.appendChild(panel);
        panel.addEventListener("click", function (e) {
            var a = e.target.closest ? e.target.closest("a[data-readme]") : null;
            if (a) { e.preventDefault(); show(a.getAttribute("data-readme")); }
        });
        document.addEventListener("keydown", function (e) { if (e.key === "Escape") hide(); });
    }

    function show(key) {
        var s = srcs[key];
        if (!s) return;
        build();
        body.innerHTML = render(s.textContent, { name: s.getAttribute("data-name") || "", repo: s.getAttribute("data-repo") || "" });
        panel.classList.add("open");
        panel.scrollTop = 0;
        try {
            copy.href = readmeUrl(key);
            var u = new URL(window.location.href);
            u.searchParams.set("readme", key.replace(/\/+$/, ""));
            window.history.replaceState(null, "", u.toString().replace(/%2F/gi, "/"));
        } catch (e) {}
    }

    function hide() {
        if (panel) panel.classList.remove("open");
        try {
            var u = new URL(window.location.href);
            u.searchParams.delete("readme");
            window.history.replaceState(null, "", u.toString());
        } catch (e) {}
    }

    function init() {
        Array.prototype.forEach.call(document.querySelectorAll(".readme-src[data-for]"), function (s) {
            srcs[s.getAttribute("data-for")] = s;
            byRepo[normalise(s.getAttribute("data-repo") || "")] = s.getAttribute("data-for");
        });
        Array.prototype.forEach.call(document.querySelectorAll(C.folders || "details[data-path]"), function (f) {
            var key = f.getAttribute("data-path"), sum = f.querySelector("summary");
            if (!srcs[key] || !sum) return;
            var b = document.createElement("button");
            b.type = "button";
            b.className = "readme-button";
            b.textContent = "📖 " + (C.about || "About this folder");
            b.title = C.about || "About this folder";
            b.addEventListener("click", function (e) { e.preventDefault(); e.stopPropagation(); show(key); });
            var title = sum.querySelector("b");
            if (title && title.nextSibling) sum.insertBefore(b, title.nextSibling); else sum.appendChild(b);
        });
        var want = new URLSearchParams(window.location.search).get("readme");
        if (want) show(srcs[want + "/"] ? want + "/" : want);
    }

    window.exampleReadme = { render: render, show: show };
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
})();
