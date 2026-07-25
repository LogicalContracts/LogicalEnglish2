/*
 * lps-view.ts — the LPS surface of the Logical English editor (M8e).
 *
 * A separate page, which is this editor's own idiom for a new surface:
 * bento-box.html, graph.html, proof-game.html, query-editor.html and
 * scenario-editor.html are all separate pages driven by the same backend.
 *
 * ## Two backends, and no proxy
 *
 * This page talks to BOTH servers and picks by what it is doing, exactly as
 * docs/le_lps_design.md §3 argues it should:
 *
 *     /leapi   (LE2, :3050)   parses Logical English  ->  getLps
 *     /lpsapi  (LPS 2, :3060) runs LPS                ->  compile, run, ...
 *
 * Proxying the LPS operations through /leapi would couple the two deployments
 * and put LE2 in the business of forwarding an operation set it does not
 * understand — and that set grows with every LPS feature. Two base URLs in the
 * client is the cheaper coupling, and it is visible.
 *
 * The flow for one document, which is the whole of docs/le_lps_interface.md:
 *
 *     .le  --POST /leapi  {getLps}-->  {lps, provenance, issues}
 *          --POST /lpsapi {compile, syntax:"internal", source, provenance}-->
 *          --POST /lpsapi {session_new} {run} {timeline} {automaton} ...
 *
 * A `.lps` document skips the first step: it is already LPS, and goes to
 * /lpsapi with syntax "legacy".
 */

// Monaco is loaded by the page through its AMD loader, as index.html does, and
// is a global here. Importing 'monaco-editor' as ESM would pull the whole
// editor (and a .ttf) into this bundle for no gain.
declare var monaco: any;

import { leLanguageConfiguration, buildLeMonarchTokens } from './le-language';
import { lpsLanguageConfiguration, lpsMonarchTokens } from './lps-language';

type Dict = Record<string, any>;

const $ = (id: string) => document.getElementById(id)!;

/* ---- the two backends --------------------------------------------------- */

const params = new URLSearchParams(window.location.search);

/** LE2 answers on the origin that served this page unless told otherwise. */
const LE_BASE = params.get('leapi') ?? localStorage.getItem('lps-leapi') ?? '/leapi';

/** LPS(2) is a different server; localhost:3060 is what `./lps ide` serves. */
const LPS_BASE = params.get('lpsapi') ?? localStorage.getItem('lps-lpsapi')
                 ?? 'http://localhost:3060/lpsapi';

/** LE2's own API token, the one every other page in this editor sends. */
const LE_TOKEN = params.get('letoken') ?? 'myToken123';

/** LPS(2)'s, which is a different secret on a different server (LPS_TOKEN). */
const LPS_TOKEN = params.get('token') ?? localStorage.getItem('lps-token') ?? '';

async function post(base: string, body: Dict): Promise<Dict> {
    const r = await fetch(base, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
    });
    if (!r.ok) throw new Error(`${base}: HTTP ${r.status}`);
    return await r.json();
}

const leApi = (body: Dict) => post(LE_BASE, { ...body, token: LE_TOKEN });
const lpsApi = (body: Dict) => post(LPS_BASE, LPS_TOKEN ? { ...body, token: LPS_TOKEN } : body);

/* ---- state -------------------------------------------------------------- */

const state: {
    editor: any;
    mode: 'le' | 'lps';
    program: string | null;
    session: string | null;
    cycles: number;
    provenance: any[];
} = { editor: null, mode: 'le', program: null, session: null, cycles: 0, provenance: [] };

/* ---- the editor --------------------------------------------------------- */

function setupEditor() {
    monaco.languages.register({ id: 'le' });
    monaco.languages.setLanguageConfiguration('le', leLanguageConfiguration as any);
    monaco.languages.setMonarchTokensProvider('le', buildLeMonarchTokens('en'));

    monaco.languages.register({ id: 'lps' });
    monaco.languages.setLanguageConfiguration('lps', lpsLanguageConfiguration as any);
    monaco.languages.setMonarchTokensProvider('lps', lpsMonarchTokens);

    state.editor = monaco.editor.create($('editor'), {
        value: SAMPLE_LE,
        language: 'le',
        automaticLayout: true,
        minimap: { enabled: false },
        fontSize: 13,
        scrollBeyondLastLine: false,
    });

    ($('mode') as HTMLSelectElement).addEventListener('change', (e) => {
        const mode = (e.target as HTMLSelectElement).value as 'le' | 'lps';
        state.mode = mode;
        const model = state.editor!.getModel()!;
        monaco.editor.setModelLanguage(model, mode);
        if (mode === 'lps' && model.getValue().trim() === SAMPLE_LE.trim())
            model.setValue(SAMPLE_LPS);
    });
}

/* ---- compile, through one backend or two -------------------------------- */

async function compileAndRun() {
    const source = state.editor!.getValue();
    setStatus('compiling…');
    clearMarkers();
    try {
        let reply: Dict;
        if (state.mode === 'le') {
            const le = await leApi({ operation: 'getLps', le: source });
            if (le.error) { setStatus(le.error); return; }
            state.provenance = le.provenance ?? [];
            showIssues(le.issues ?? []);
            $('internal').textContent = le.lps ?? '';
            if ((le.issues ?? []).some((i: Dict) => i.severity === 'error')) {
                setStatus('Logical English did not compile');
                return;
            }
            reply = await lpsApi({
                operation: 'compile', syntax: 'internal',
                source: le.lps, provenance: le.provenance ?? [],
            });
        } else {
            state.provenance = [];
            reply = await lpsApi({ operation: 'compile', syntax: 'legacy', source });
        }
        showDiagnostics(reply.diagnostics ?? []);
        if (!reply.ok) { setStatus('did not compile'); return; }
        state.program = reply.program;
        if (state.mode === 'lps') {
            const d = await lpsApi({ operation: 'dump', program: state.program });
            $('internal').textContent = d.dump ?? '';
        }
        const s = await lpsApi({ operation: 'session_new', program: state.program });
        state.session = s.session;
        const r = await lpsApi({ operation: 'run', session: state.session });
        state.cycles = r.cycle ?? 0;
        setStatus(`${r.status} after ${state.cycles} cycles`);
        ($('cycle') as HTMLInputElement).max = String(state.cycles);
        await renderActivePane();
    } catch (e: any) {
        setStatus(String(e.message ?? e));
    }
}

const setStatus = (t: string) => { $('status').textContent = t; };

/* ---- diagnostics, from both sides, concatenated ------------------------- */

function clearMarkers() {
    const model = state.editor?.getModel();
    if (model) monaco.editor.setModelMarkers(model, 'lps', []);
    $('diags').replaceChildren();
}

/** LE-side issues: LE2 already reports them at .le line and column. */
function showIssues(issues: Dict[]) {
    addMarkers(issues.map((i) => ({
        severity: i.severity, message: i.message,
        line: i.line ?? 0, col: i.col ?? 0, origin: 'LE',
    })));
}

/**
 * LPS-side diagnostics. `source` is the decomposed position of
 * docs/le_lps_interface.md §4 — for an LE-sourced program it points into the
 * .le document, which is the whole reason provenance exists.
 */
function showDiagnostics(diags: Dict[]) {
    addMarkers(diags.map((d) => ({
        severity: d.severity, message: `${d.code}: ${d.message}`,
        line: d.source?.line ?? 0, col: d.source?.col ?? 0, origin: 'LPS',
    })));
}

function addMarkers(items: { severity: string; message: string; line: number; col: number; origin: string }[]) {
    const model = state.editor!.getModel()!;
    const existing = monaco.editor.getModelMarkers({ resource: model.uri })
        .filter((m: Dict) => m.owner === 'lps');
    const markers = items.filter((i) => i.line > 0).map((i) => ({
        severity: i.severity === 'error' ? monaco.MarkerSeverity.Error
                : i.severity === 'warning' ? monaco.MarkerSeverity.Warning
                : monaco.MarkerSeverity.Info,
        message: `[${i.origin}] ${i.message}`,
        startLineNumber: i.line, startColumn: i.col + 1,
        endLineNumber: i.line, endColumn: i.col + 200,
    }));
    monaco.editor.setModelMarkers(model, 'lps', [...existing, ...markers]);

    for (const i of items) {
        const div = document.createElement('div');
        div.className = 'diag ' + i.severity;
        div.textContent = `${i.origin} ${i.severity}${i.line ? ` (line ${i.line})` : ''}: ${i.message}`;
        if (i.line > 0) div.addEventListener('click', () => {
            state.editor!.revealLineInCenter(i.line);
            state.editor!.setPosition({ lineNumber: i.line, column: i.col + 1 });
            state.editor!.focus();
        });
        $('diags').appendChild(div);
    }
}

/* ---- the panes ---------------------------------------------------------- */

const el = (tag: string, attrs: Dict = {}, kids: (Node | string)[] = []) => {
    const e = document.createElement(tag);
    for (const k in attrs) {
        if (k === 'text') e.textContent = attrs[k];
        else if (k === 'class') e.className = attrs[k];
        else e.setAttribute(k, attrs[k]);
    }
    for (const kid of kids) e.append(kid);
    return e;
};

const svgNs = 'http://www.w3.org/2000/svg';
const ns = (tag: string, attrs: Dict = {}, text?: string) => {
    const e = document.createElementNS(svgNs, tag);
    for (const k in attrs) e.setAttribute(k, String(attrs[k]));
    if (text !== undefined) e.textContent = text;
    return e;
};

async function renderTimeline() {
    const pane = $('pane-timeline');
    if (!state.session) { pane.replaceChildren(el('p', { class: 'empty', text: 'Run a program first.' })); return; }
    const r = await lpsApi({ operation: 'timeline', session: state.session });
    const max = Math.max(1, r.cycles);
    const rowH = 22, labelW = 220, cellW = 26;
    const svg = ns('svg', { width: '100%', viewBox: `0 0 ${labelW + (max + 1) * cellW + 20} ${(r.fluents.length + 3) * rowH + 20}` });
    r.fluents.forEach((lane: Dict, i: number) => {
        const y = 20 + i * rowH;
        svg.appendChild(ns('text', { x: 4, y: y + 14, 'font-size': 11, fill: 'currentColor' }, lane.fluent));
        for (const iv of lane.intervals) {
            const x = labelW + iv.from * cellW;
            const w = (iv.to - iv.from + 1) * cellW - 3;
            svg.appendChild(ns('rect', { x, y: y + 3, width: w, height: rowH - 8, rx: 4, fill: '#bfdbfe' }));
        }
    });
    const evY = 20 + r.fluents.length * rowH;
    svg.appendChild(ns('text', { x: 4, y: evY + 14, 'font-size': 11, fill: 'currentColor' }, 'events'));
    for (const cell of r.events) {
        svg.appendChild(ns('rect', { x: labelW + cell.cycle * cellW, y: evY + 3, width: cellW - 3, height: rowH - 8, rx: 4, fill: '#fde68a' }));
        svg.appendChild(ns('title', {}, cell.items.join(', ')));
    }
    pane.replaceChildren(svg);
}

async function renderChanges() {
    const pane = $('pane-changes');
    if (!state.session) { pane.replaceChildren(el('p', { class: 'empty', text: 'Run a program first.' })); return; }
    const cycle = Number(($('cycle') as HTMLInputElement).value);
    const r = await lpsApi({ operation: 'changes', session: state.session, cycle });
    const tbl = el('table');
    tbl.appendChild(el('tr', {}, [el('th', { text: '' }), el('th', { text: 'fluent' }),
                                  el('th', { text: 'by' }), el('th', { text: 'causal law' })]));
    const rows = (mark: string, list: Dict[]) => {
        for (const c of list) tbl.appendChild(el('tr', {}, [
            el('td', { text: mark }), el('td', { class: 'mono', text: c.fluent }),
            el('td', { class: 'mono', text: c.action }), el('td', { class: 'mono', text: c.source })]));
    };
    rows('+', r.initiated); rows('−', r.terminated); rows('~', r.updated);
    pane.replaceChildren(tbl, el('p', { class: 'empty', text: `persisted: ${r.persisted.join(', ') || '—'}` }));
}

/**
 * The state-transitions diagram (upstream's godfa/1): every DISTINCT state
 * once, however often the run visits it, so a program that oscillates reads as
 * a loop rather than as a strip of near-identical frames.
 */
async function renderAutomaton() {
    const pane = $('dfa');
    if (!state.session) { pane.replaceChildren(el('p', { class: 'empty', text: 'Run a program first.' })); return; }
    const r = await lpsApi({
        operation: 'automaton', session: state.session,
        abstract_numbers: ($('absnum') as HTMLInputElement).checked,
        non_reflexive: ($('nonrefl') as HTMLInputElement).checked,
    });
    if (!r.ok || !r.states.length) {
        pane.replaceChildren(el('p', { class: 'empty', text: 'A transitions diagram needs fluents and events.' }));
        return;
    }
    const depth = new Map<string, number>(r.states.map((s: Dict) => [s.id, 0]));
    for (let pass = 0; pass < r.states.length; pass++) {
        let moved = false;
        for (const e of r.transitions) {
            if (e.from === e.to) continue;
            const d = depth.get(e.from)! + 1;
            if (d > depth.get(e.to)!) { depth.set(e.to, d); moved = true; }
        }
        if (!moved) break;
    }
    const W = 240, pos = new Map<string, Dict>();
    let y = 20;
    const byDepth: Dict[][] = [];
    for (const s of r.states) (byDepth[depth.get(s.id)!] ||= []).push(s);
    let cols = 1;
    byDepth.forEach((row) => {
        if (!row) return;
        cols = Math.max(cols, row.length);
        let h = 0;
        row.forEach((s: Dict, i: number) => {
            const boxH = 26 + 18 * Math.max(1, s.fluents.length);
            pos.set(s.id, { x: 20 + i * (W + 60), y, w: W, h: boxH });
            h = Math.max(h, boxH);
        });
        y += h + 70;
    });
    const right = 20 + cols * (W + 60);
    const svg = ns('svg', { width: '100%', viewBox: `0 0 ${right + 320} ${y}` });
    const defs = ns('defs');
    for (const [id, colour] of [['ev', '#E19735'], ['ac', 'forestgreen']]) {
        const m = ns('marker', { id: 'a-' + id, viewBox: '0 0 10 10', refX: 9, refY: 5, markerWidth: 6, markerHeight: 6, orient: 'auto-start-reverse' });
        m.appendChild(ns('path', { d: 'M 0 0 L 10 5 L 0 10 z', fill: colour }));
        defs.appendChild(m);
    }
    svg.appendChild(defs);
    let lane = 0;
    for (const e of r.transitions) {
        const a = pos.get(e.from), b = pos.get(e.to);
        if (!a || !b) continue;
        const colour = e.kind === 'event' ? '#E19735' : 'forestgreen';
        const mark = e.kind === 'event' ? 'a-ev' : 'a-ac';
        let d: string, lx: number, ly: number;
        if (e.from === e.to) {
            const yy = a.y + a.h / 2;
            d = `M ${a.x + a.w} ${yy - 8} C ${a.x + a.w + 60} ${yy - 40}, ${a.x + a.w + 60} ${yy + 40}, ${a.x + a.w} ${yy + 8}`;
            lx = a.x + a.w + 66; ly = yy;
        } else if (b.y < a.y) {
            const x = right + 20 + lane * 26; lane++;
            d = `M ${a.x + a.w} ${a.y + a.h / 2} L ${x} ${a.y + a.h / 2} L ${x} ${b.y + b.h / 2} L ${b.x + b.w} ${b.y + b.h / 2}`;
            lx = x + 6; ly = (a.y + b.y) / 2 + 6;
        } else {
            const x1 = a.x + a.w / 2, x2 = b.x + b.w / 2, mid = (a.y + a.h + b.y) / 2;
            d = `M ${x1} ${a.y + a.h} C ${x1} ${mid}, ${x2} ${mid}, ${x2} ${b.y}`;
            lx = Math.max(x1, x2) + 8; ly = mid;
        }
        svg.appendChild(ns('path', { d, fill: 'none', stroke: colour, 'stroke-width': 1.5, 'marker-end': `url(#${mark})` }));
        svg.appendChild(ns('text', { x: lx, y: ly, fill: colour, 'font-size': 11, 'font-family': 'ui-monospace, monospace' }, e.label));
    }
    for (const s of r.states) {
        const p = pos.get(s.id)!;
        const g = ns('g');
        g.appendChild(ns('rect', { x: p.x, y: p.y, width: p.w, height: p.h, rx: 14, fill: '#D7DCF5', stroke: '#111', 'stroke-width': s.initial ? 3 : 1 }));
        s.fluents.forEach((f: string, i: number) => {
            g.appendChild(ns('text', { x: p.x + p.w / 2, y: p.y + 20 + i * 18, 'text-anchor': 'middle', 'font-size': 12, fill: '#111', 'font-family': 'ui-monospace, monospace' }, f));
        });
        g.appendChild(ns('title', {}, `cycles ${s.cycles.join(', ')}`));
        svg.appendChild(g);
    }
    pane.replaceChildren(svg);
}

async function renderInternal() { /* already filled at compile time */ }

const PANES: Record<string, () => Promise<void>> = {
    timeline: renderTimeline,
    changes: renderChanges,
    automaton: renderAutomaton,
    internal: renderInternal,
};

const activePane = () => (document.querySelector('.tabs button.on') as HTMLElement).dataset.pane!;
const renderActivePane = () => PANES[activePane()]();

/* ---- wiring ------------------------------------------------------------- */

const SAMPLE_LE = `the target language is: lps.

the maximum time is 10.

the actions are:
    *a payer* transfers *an amount* to *a payee*; known as transfer.

the fluents are:
    the balance of *a person* is *an amount*; known as balance.

the knowledge base bank transfer includes:

initially the balance of bob is 0
    and the balance of fariba is 100.

if fariba transfers an amount to bob from a first time to a second time
    and the balance of bob is a second amount at the second time
    and the second amount >= 10
then bob transfers 10 to fariba from the second time to a third time.

if bob transfers an amount to fariba from a first time to a second time
    and the balance of fariba is a second amount at the second time
    and the second amount >= 20
then fariba transfers 20 to bob from the second time to a third time.

when a payer transfers an amount to a payee
then the balance of the payee that is a number becomes number + amount
    and the balance of the payer that is a second number becomes second number - amount.

it must not be true that
    a payer transfers an amount to a payee from a first time to a second time
    and the balance of the payer is a second amount at the first time
    and the second amount < the amount.

scenario one is:
    fariba transfers 10 to bob from 1 to 2.
`;

const SAMPLE_LPS = `maxTime(10).
actions   transfer(From, To, Amount).
fluents   balance(Person, Amount).

initially balance(bob, 0), balance(fariba, 100).
observe   transfer(fariba, bob, 10) from 1 to 2.

if   transfer(fariba, bob, X) from T1 to T2, balance(bob, A) at T2, A >= 10
then transfer(bob, fariba, 10) from T2 to T3.

if   transfer(bob, fariba, X) from T1 to T2, balance(fariba, A) at T2, A >= 20
then transfer(fariba, bob, 20) from T2 to T3.

transfer(F,T,A) updates Old to New in balance(T, Old) if New is Old + A.
transfer(F,T,A) updates Old to New in balance(F, Old) if New is Old - A.

false transfer(From, To, Amount), balance(From, Old), Old < Amount.
`;

export function boot() {
    setupEditor();
    $('run').addEventListener('click', compileAndRun);
    $('cycle').addEventListener('input', () => {
        $('cyclab').textContent = `cycle ${($('cycle') as HTMLInputElement).value}`;
        if (activePane() === 'changes') renderChanges();
    });
    $('absnum').addEventListener('change', renderAutomaton);
    $('nonrefl').addEventListener('change', renderAutomaton);
    document.querySelectorAll('.tabs button').forEach((b) => b.addEventListener('click', () => {
        document.querySelectorAll('.tabs button').forEach((x) => x.classList.toggle('on', x === b));
        document.querySelectorAll('.pane').forEach((p) =>
            p.classList.toggle('on', p.id === 'pane-' + (b as HTMLElement).dataset.pane));
        renderActivePane();
    }));
    $('endpoints').textContent = `LE ${LE_BASE} · LPS ${LPS_BASE}`;
}

// The page calls this once Monaco's AMD loader has resolved.
(window as any).startLpsView = boot;
