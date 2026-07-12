/* Executive view: a minimalist, mobile-first way to run an existing LE program.
   No editing. Talks to the same /leapi endpoints as the editor. Vanilla JS. */

const TOKEN = 'myToken123';
const $ = (id) => document.getElementById(id);

async function leapi(operation, payload) {
    const resp = await fetch('/leapi', {
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

let session = null;      // current session module
let programName = null;  // current program's example name
let programSource = '';  // its LE source text (for the tool popups)
let programKb = null;    // its knowledge-base name
let programQueries = []; // [{name, label}] for Scenario Variations

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

    // Queries.
    const queries = (data.queries || []).map(q => q.name);
    const qSel = $('query-select');
    if (!queries.length) {
        qSel.innerHTML = '<option value="">(this program defines no questions)</option>';
        $('answers').innerHTML = '';
        return;
    }
    qSel.innerHTML = queries.map(n => `<option value="${esc(n)}">${esc(n)}</option>`).join('');
    $('tool-variations').hidden = false;

    // Preselect from URL params (deep links).
    const p = params();
    if (p.get('scenario') && scenarios.includes(p.get('scenario'))) scSel.value = p.get('scenario');
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
    if (data.error) { box.innerHTML = `<div class="status">${esc(data.error)}</div>`; return; }
    const results = data.results || [];
    if (!results.length) {
        box.innerHTML = '<div class="answer none"><div class="answer-head">No — no answers for this question.</div></div>';
        return;
    }
    box.innerHTML = results.map((r, i) => {
        const unknowns = (r.unknowns && r.unknowns.length)
            ? `<span class="unknowns">(assuming: ${esc(r.unknowns.join('; '))})</span>` : '';
        return `<div class="answer" data-i="${i}">
            <div class="answer-head"><span class="chev">▶</span>
                <span class="answer-text">${esc(r.answer)}</span>${unknowns}</div>
            <div class="answer-why">${r.why ? renderTree(r.why) : ''}</div>
        </div>`;
    }).join('');
    // Tap a header to expand its explanation.
    box.querySelectorAll('.answer-head').forEach(h =>
        h.addEventListener('click', () => h.parentElement.classList.toggle('open')));
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
    const kids = (node.children || []).map(renderNode).join('');
    return `<li class="${type}"><span class="lit">${lit}</span>${rep}` +
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

document.addEventListener('DOMContentLoaded', () => {
    $('tool-variations').addEventListener('click', openScenarioVariations);
    // No Run button: a change of scenario or question re-runs the query.
    $('scenario-select').addEventListener('change', runQuery);
    $('query-select').addEventListener('change', runQuery);
    // Back/forward navigation between menu and programs.
    window.addEventListener('popstate', route);
    route();
});
