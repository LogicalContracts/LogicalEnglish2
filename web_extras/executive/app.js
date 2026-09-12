/* Executive view: a minimalist, mobile-first way to run an existing LE program.
   No editing. Talks to the same /leapi endpoints as the editor. Vanilla JS. */

const TOKEN = 'myToken123';
const $ = (id) => document.getElementById(id);

// ---- minimal UI i18n (shared catalog; see i18n/ui.csv) ---------------------
const UI_LANG = (document.cookie.match(/(?:^|; )le_ui_lang=([a-z]{2})/) || [])[1] || 'en';
let UI_CATALOG = {};
const t = (s) => (UI_LANG !== 'en' && UI_CATALOG[s]) || s;
async function initI18n() {
    if (UI_LANG === 'en') return;
    try {
        const data = await (await fetch('/web_extras/executive/i18n-ui.json')).json();
        UI_CATALOG = (data.ui && data.ui[UI_LANG]) || {};
        // static chrome
        document.querySelectorAll('button, label span, .lead, .hint, h1, [title], [placeholder], [aria-label]')
            .forEach(el => {
                if (el.childElementCount === 0 && el.textContent && UI_CATALOG[el.textContent.trim()])
                    el.textContent = t(el.textContent.trim());
                for (const attr of ['title', 'placeholder', 'aria-label']) {
                    const v = el.getAttribute && el.getAttribute(attr);
                    if (v && UI_CATALOG[v.trim()]) el.setAttribute(attr, t(v.trim()));
                }
            });
    } catch (e) { /* stay English */ }
}

async function leapi(operation, payload) {
    const resp = await fetch(UI_LANG === 'en' ? '/leapi' : '/leapi?lang=' + UI_LANG, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(Object.assign({ token: TOKEN, operation }, payload))
    });
    if (!resp.ok) throw new Error(`server error ${resp.status}`);
    return resp.json();
}

const params = () => new URLSearchParams(location.search);
function show(which) {
    $('screen-menu').classList.toggle('hidden', which !== 'menu');
    $('screen-program').classList.toggle('hidden', which !== 'program');
}
function esc(s) {
    return String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
}

// Top-right login/logout, mirroring the landing page. The session cookie is
// shared same-origin; /whoami reports the current user.
async function renderAuth() {
    try {
        const me = await (await fetch('/whoami')).json();
        const ret = encodeURIComponent(location.pathname + location.search);
        $('auth').innerHTML = me.loggedIn
            ? `<span class="email">${esc(me.email)}</span><a href="/logout?return=${ret}">${esc(t('Logout'))}</a>`
            : `<a href="/login?return=${ret}">${esc(t('Login'))}</a>`;
    } catch { $('auth').innerHTML = ''; }
}

let session = null;      // current session module
let programName = null;  // current program's example name
let programSource = '';  // its LE source text (for the tool popups)
let programKb = null;    // its knowledge-base name
let programQueries = []; // [{name, label}] for Scenario Variations
let programTemplateDefs = []; // the templates of the program and its includes (Scenario Variations)

// ------------------------------- program menu -------------------------------

async function renderMenu() {
    show('menu');
    $('title').textContent = 'Logical English';
    $('back-link').hidden = true;
    const list = $('menu-list');
    try {
        const data = await leapi('list_examples', {});
        const names = (data.examples || []).map(e => (typeof e === 'string' ? e : e.name)).filter(Boolean).sort();
        if (!names.length) { list.innerHTML = '<li class="hint">No programs available.</li>'; return; }
        const render = (filter) => {
            const f = filter.trim().toLowerCase();
            const shown = f ? names.filter(n => n.toLowerCase().includes(f)) : names;
            list.innerHTML = shown.map(n =>
                `<li class="item"><a href="/executive?program=${encodeURIComponent(n)}">${esc(n)}</a></li>`
            ).join('') || '<li class="hint">No match.</li>';
        };
        render('');
        $('menu-filter').addEventListener('input', (e) => render(e.target.value));
    } catch (e) {
        list.innerHTML = `<li class="hint">Could not load the program list (${esc(e.message)}).</li>`;
    }
}

// -------------------------------- a program ---------------------------------

async function loadProgram(name) {
    show('program');
    $('title').textContent = name;
    $('back-link').hidden = false;
    programName = name;
    $('tool-variations').hidden = true;

    $('answers').innerHTML = '<div class="status">Loading…</div>';
    $('program-issues').hidden = true;
    $('tool-variations').hidden = true;

    // Fetch the source text in the background — the tool popups need it.
    leapi('examples', { file: name }).then(d => { programSource = d.document || ''; }).catch(() => {});

    let data;
    try {
        data = await leapi('load', { file: name, source: name });
    } catch (e) {
        $('answers').innerHTML = `<div class="status">Could not load “${esc(name)}” (${esc(e.message)}).</div>`;
        return;
    }
    if (data.error) {
        $('answers').innerHTML = `<div class="status">${esc(data.error)}</div>`;
        return;
    }
    session = data.sessionModule;
    programKb = data.kb || '';
    programQueries = (data.queries || []).map(q => ({ name: q.name, label: q.le || q.template || q.name }));
    programTemplateDefs = data.template_defs || [];

    // Load-time errors (missing templates, etc.) are worth surfacing, briefly.
    const errs = (data.issues || []).filter(i => i.severity === 'error');
    if (errs.length) {
        $('program-issues').hidden = false;
        $('program-issues').innerHTML =
            `<b>${errs.length} issue${errs.length > 1 ? 's' : ''} in this program:</b>` +
            `<ul>${errs.slice(0, 6).map(i => `<li>${esc(i.message)}</li>`).join('')}</ul>`;
    }

    // Scenarios: "(no scenario)" plus the named ones.
    const scenarios = (data.examples || []).map(s => s.name);
    const scSel = $('scenario-select');
    scSel.innerHTML = '<option value="">(no scenario)</option>' +
        scenarios.map(n => `<option value="${esc(n)}">${esc(n)}</option>`).join('');

    // Queries: the option value is the query's name (stable, used in the URL),
    // but what the user sees is the query text itself.
    const queries = programQueries.map(q => q.name);
    const qSel = $('query-select');
    if (!queries.length) {
        qSel.innerHTML = '<option value="">(this program defines no queries)</option>';
        $('answers').innerHTML = '';
        return;
    }
    qSel.innerHTML = programQueries.map(q =>
        `<option value="${esc(q.name)}">${esc(q.label)}</option>`).join('');
    $('tool-variations').hidden = false;

    // Preselect: the URL param wins; otherwise default to the FIRST named
    // scenario (rather than "(no scenario)") so the program opens on a concrete,
    // meaningful example. Setting .value programmatically fires no 'change'
    // event, so the explicit runQuery() below is what runs it.
    const p = params();
    if (p.get('scenario') && scenarios.includes(p.get('scenario'))) scSel.value = p.get('scenario');
    else if (scenarios.length) scSel.value = scenarios[0];
    if (p.get('query') && queries.includes(p.get('query'))) qSel.value = p.get('query');

    // No Run button: run for the current selection now, and on every change.
    runQuery();
}

// Reflect scenario/query in the URL so a result is shareable (no reload).
function syncUrl() {
    const p = params();
    p.set('scenario', $('scenario-select').value);
    p.set('query', $('query-select').value);
    if (!$('scenario-select').value) p.delete('scenario');
    history.replaceState({}, '', location.pathname + '?' + p.toString());
}

async function runQuery() {
    const query = $('query-select').value;
    if (!session || !query) return;
    syncUrl();
    const box = $('answers');
    box.innerHTML = '<div class="status">Running…</div>';
    try {
        const data = await leapi('answeringQuery', {
            sessionModule: session,
            scenario: $('scenario-select').value,
            query
        });
        renderAnswers(data);
    } catch (e) {
        box.innerHTML = `<div class="status">Query failed (${esc(e.message)}).</div>`;
    }
}

function renderAnswers(data) {
    const box = $('answers');
    sourceNodes = [];
    if (data.error) { box.innerHTML = `<div class="status">${esc(data.error)}</div>`; return; }
    const results = data.results || [];
    if (!results.length) {
        box.innerHTML = '<div class="answer none"><div class="answer-head">No — no answers for this query.</div></div>';
        return;
    }
    box.innerHTML = results.map((r, i) => {
        const unknowns = (r.unknowns && r.unknowns.length)
            ? `<span class="unknowns">(assuming: ${esc(r.unknowns.join('; '))})</span>` : '';
        return `<div class="answer" data-i="${i}">
            <div class="answer-head"><span class="chev">▶</span>
                <span class="answer-text">${esc(r.answer)}</span>${unknowns}</div>
            <div class="answer-why">${r.why ? renderWhy(r.why, i) : ''}</div>
        </div>`;
    }).join('');
    // Tap a header to expand its explanation.
    box.querySelectorAll('.answer-head').forEach(h =>
        h.addEventListener('click', () => h.parentElement.classList.toggle('open')));
    // § buttons open the cited passage; Copy puts the citations on the clipboard.
    box.querySelectorAll('button.src').forEach(b => b.addEventListener('click', (e) => {
        e.stopPropagation();
        const node = sourceNodes[Number(b.dataset.k)];
        if (node) openSource(node.provenance, node.rule);
    }));
    box.querySelectorAll('button.copy-cites').forEach(b => b.addEventListener('click', async (e) => {
        e.stopPropagation();
        const steps = citedSteps(results[Number(b.dataset.i)].why);
        try { await navigator.clipboard.writeText(citationsText(steps)); b.textContent = t('Copied'); }
        catch { /* no clipboard: nothing to do */ }
    }));
}

// ---------------------------- citations ------------------------------------
// Where the program cites its sources (a rule's `with provenance`, a fact's
// "as stated in …, confer "…"", a table row's passage — docs/le_summary.md
// §15.5, §17.1), every explanation node proved by it carries a `provenance`.
// An answer opens on those steps alone, in the order of the proof — the chain
// a reviewer reads, each step with its passage, one tap from the document —
// with the whole explanation folded below. Nothing here knows any domain.

let sourceNodes = [];    // the nodes § buttons refer to (by index)

function citedSteps(why) {
    const out = [], seen = new Set();
    const walk = (n) => {
        if (!n || typeof n !== 'object') return;
        if (n.type === 'success' && n.provenance && (n.provenance.document || n.provenance.url)) {
            const key = `${n.literal || ''}|${n.rule || ''}|${n.provenance.document || ''}|${n.provenance.quote || ''}`;
            if (!seen.has(key)) { seen.add(key); out.push(n); }
        }
        (n.children || []).forEach(walk);
    };
    (Array.isArray(why) ? why : [why]).forEach(walk);
    return out;
}

// Where a step comes from, as one line: the rule, the document, the passage.
function citationLine(n) {
    const p = n.provenance || {};
    const parts = [];
    if (n.rule) parts.push(`${t('rule')} ${n.rule}`);
    if (p.document) parts.push(p.document);
    if (p.quote) parts.push(`“${p.quote}”`);
    else if (p.locator) parts.push(p.locator);
    return parts.join(' · ');
}

function citationsText(steps) {
    return steps.map((n, i) => `${i + 1}. ${n.plain || n.literal || ''}\n   ${citationLine(n)}`).join('\n');
}

function sourceButton(n) {
    const p = n.provenance || {};
    if (!p.text && !p.url) return '';
    sourceNodes.push(n);
    return ` <button class="src" data-k="${sourceNodes.length - 1}" title="${esc(t('Show original text'))}">§</button>`;
}

function renderWhy(why, i) {
    const steps = citedSteps(why);
    if (!steps.length) return renderTree(why);
    const items = steps.map(n =>
        `<li><span class="lit">${esc(n.plain || n.literal || '')}</span>${sourceButton(n)}
             <div class="cite">${esc(citationLine(n))}</div></li>`).join('');
    return `<div class="cites">
            <div class="cites-head"><span>${esc(t('Citations'))}</span>
                <button class="copy-cites" data-i="${i}">${esc(t('Copy'))}</button></div>
            <ol class="cite-list">${items}</ol>
        </div>
        <details class="full"><summary>${esc(t('Full explanation'))}</summary>${renderTree(why)}</details>`;
}

// The source viewer of the editor (the explanation's § badge), loaded on first
// use; the program's name lets the server find a text beside it.
let viewerModule = null;
async function openSource(provenance, rule) {
    try {
        viewerModule = viewerModule || await import('/editor/dist/source-viewer.js');
        const p = provenance || {};
        if (!p.text && p.url) { window.open(viewerModule.originalUrl(p) || p.url, '_blank'); return; }
        viewerModule.openSourceViewer(p, rule || undefined, { source: programName || '' });
    } catch (e) {
        if (provenance && provenance.url) window.open(provenance.url, '_blank');
    }
}

// The `why` explanation -> a nested <ul>. The server returns it as a list of
// top-level nodes (the answer's supporting conditions). No external component.
function renderTree(why) {
    const nodes = Array.isArray(why) ? why : [why];
    return '<ul class="tree">' + nodes.map(renderNode).join('') + '</ul>';
}
function renderNode(node) {
    if (!node || typeof node !== 'object') return '';
    const type = node.type === 'success' ? 't-success'
        : node.type === 'unknown' ? 't-unknown'
        : node.type === 'failure' ? 't-failure' : '';
    const lit = esc(node.literal || node.text || '');
    let rep = '';
    if (node.repeated) rep = node.repeatedCount
        ? ` <span class="repeated">(×${node.repeatedCount})</span>`
        : ' <span class="repeated">(shown above)</span>';
    const src = (node.type === 'success' && node.provenance) ? sourceButton(node) : '';
    const children = node.children || [];
    const kids = children.map(renderNode).join('');
    // A step proved only by what failed under it — "it is not the case that …",
    // "for all …" — shows those failures on demand: they are the search, not
    // the reasons.
    if (node.type === 'success' && children.length && children.every(c => c && c.type === 'failure')) {
        return `<li class="${type}"><details class="negation"><summary><span class="lit">${lit}</span>${rep}${src}</summary>` +
            `<ul>${kids}</ul></details></li>`;
    }
    return `<li class="${type}"><span class="lit">${lit}</span>${rep}${src}` +
        (kids ? `<ul>${kids}</ul>` : '') + '</li>';
}

// ------------------------- Scenario Variations / Query Editor ----------------
// These editor tools live under /editor/ and take their input from localStorage
// (same origin), then open in a new tab. We populate the same keys the editor
// uses and open the same pages.

function popupTheme() {
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches ? 'light-theme' : '';
}

async function getSource() {
    if (!programSource && programName) {
        try { programSource = (await leapi('examples', { file: programName })).document || ''; }
        catch { /* leave empty; popups also accept an empty source */ }
    }
    return programSource;
}

async function openScenarioVariations() {
    await getSource();
    localStorage.setItem('le_scenario_variations_data', JSON.stringify({
        source: programSource,
        kbName: programKb,
        templateDefs: programTemplateDefs,
        example: programName || '',
        queries: programQueries,
        selectedScenario: $('scenario-select').value,
        selectedQuery: $('query-select').value
    }));
    window.open(`/editor/scenario-variations.html?theme=${popupTheme()}&v=${Date.now()}`, '_blank');
}

// --------------------------------- routing ----------------------------------

function route() {
    const program = params().get('program');
    if (program) loadProgram(program);
    else renderMenu();
}

document.addEventListener('DOMContentLoaded', async () => {
    await initI18n();
    $('tool-variations').addEventListener('click', openScenarioVariations);
    // No Run button: a change of scenario or question re-runs the query.
    $('scenario-select').addEventListener('change', runQuery);
    $('query-select').addEventListener('change', runQuery);
    // Back/forward navigation between menu and programs.
    window.addEventListener('popstate', route);
    renderAuth();
    route();
});
