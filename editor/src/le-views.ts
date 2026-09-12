// LE Views (docs/le_summary.md §17.10): a screen for one program, composed of
// generic widgets as the program's view section says — which facts the case
// states and how they are grouped, which query is the result, what is shown
// beside it. The server compiles the view (le_views.pl) into the `views` of
// the load response; this module renders one of them. Nothing here knows any
// domain: every word a widget shows beyond its own chrome comes from the
// program or its view.
//
//   mountView(root, { program, sessionModule, load, view, source })
//
// Widgets, in the view's order: facts (FactForm groups, with the case picker),
// questions (what is missing / the interview), result, stage (the section
// checklist), citations, reasons, whatif (the flip), tables (answers of a
// question), compare (another scenario), documents, cases (every scenario),
// draft (a text filled from the result).

import { t, detectProgramLanguage, kwPhrases } from './i18n';
import { ScenarioForm, isTestDirective } from './scenario-form';
import { parseScenarioBlocks, matchFact, withDefaultProvenance, ScenarioBlock } from './le-templates';
import { openSourceViewer, fetchDocumentText, findQuote, originalUrl, Provenance } from './source-viewer';

const TOKEN = 'myToken123';

export interface ViewContext {
    program: string;          // the example name (resolves documents' text addresses)
    sessionModule: string;
    load: any;                // the load response (template_defs, queries, examples, views)
    view: any;                // one compiled view
    source: string;           // the program text
    titleShown?: boolean;     // the host shows the view's title itself
}

// One request at a time: every widget asks the same reasoning session, and a
// request sets the session's scenario — two at once (the result of the case,
// the comparison with another scenario) would each see the other's.
let queue: Promise<any> = Promise.resolve();
async function leapi(body: any): Promise<any> {
    const call = () => fetch('/leapi', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token: TOKEN, ...body }),
    }).then(r => r.json());
    const p = queue.then(call, call);
    queue = p.catch(() => undefined);
    return p;
}

function el(tag: string, cls = '', text?: string): HTMLElement {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    return e;
}

const norm = (s: string) => (s || '').replace(/\s+-\s+/g, '-').replace(/\s+/g, ' ').replace(/\.\s*$/, '').trim().toLowerCase();

function ensureStyles() {
    if (document.getElementById('le-views-styles')) return;
    const style = document.createElement('style');
    style.id = 'le-views-styles';
    style.textContent = `
    .lv { --lv-card: var(--card, #f7f9fb); --lv-ink: var(--ink, #17202a); --lv-muted: var(--muted, #5b6674);
          --lv-border: var(--border, #e2e6ea); --lv-accent: var(--accent, #0e639c); --lv-bg: var(--bg, #fff);
          --lv-ok: var(--ok, #1c7d3c); --lv-fail: var(--fail, #b3261e); --lv-unknown: var(--unknown, #9a6a00);
          color: var(--lv-ink); font-size: 14px; }
    .lv-grid { display: grid; gap: 16px; grid-template-columns: minmax(0, 1.15fr) minmax(0, 1fr) minmax(0, .85fr); align-items: start; }
    .lv-grid.two { grid-template-columns: minmax(0, 1.1fr) minmax(0, 1fr); }
    @media (max-width: 1000px) { .lv-grid, .lv-grid.two { grid-template-columns: minmax(0, 1fr); } }
    .lv-col { display: grid; gap: 16px; align-content: start; min-width: 0; }
    .lv .fact-row input.field { max-width: 100%; field-sizing: content; min-width: 5ch; }
    .lv .empty-hint { display: none; }
    .lv-wide { margin-top: 16px; display: grid; gap: 16px; }
    .lv-card { background: var(--lv-bg); border: 1px solid var(--lv-border); border-radius: 12px; padding: 12px 14px; }
    .lv-h { font-size: 11px; text-transform: uppercase; letter-spacing: .05em; color: var(--lv-muted); margin: 0 0 8px; display: flex; justify-content: space-between; align-items: center; gap: 8px; }
    .lv-h button, .lv-btn { border: 1px solid var(--lv-accent); background: var(--lv-bg); color: var(--lv-accent); border-radius: 8px; padding: 3px 10px; font-size: 12.5px; cursor: pointer; text-transform: none; letter-spacing: 0; }
    .lv-btn.primary { background: var(--lv-accent); color: #fff; }
    .lv-grp { font-size: 11px; text-transform: uppercase; letter-spacing: .05em; color: var(--lv-muted); margin: 12px 0 6px; }
    .lv .fact-row { display: flex; flex-wrap: wrap; align-items: center; gap: 5px; background: var(--lv-card); border: 1px solid var(--lv-border); border-radius: 8px; padding: 6px 8px; margin-bottom: 6px; }
    .lv .fact-row input.field { background: var(--lv-bg); color: var(--lv-ink); border: 1px solid var(--lv-border); border-radius: 5px; padding: 2px 6px; font: inherit; }
    .lv .fact-row input.cite-field { background: transparent; color: var(--lv-muted); border: 1px dashed var(--lv-border); border-radius: 5px; padding: 2px 6px; font: inherit; font-size: 12px; font-style: italic; flex: 1 1 100%; }
    .lv .fact-row .row-tools { margin-left: auto; display: flex; gap: 4px; align-items: center; font-size: 11px; color: var(--lv-muted); }
    .lv .fact-row .row-tools button { border: 1px solid var(--lv-border); background: var(--lv-bg); border-radius: 5px; cursor: pointer; color: var(--lv-muted); }
    .lv .fact-row .preserved { color: var(--lv-muted); font-style: italic; }
    .lv .empty-hint { color: var(--lv-muted); font-size: 12px; font-style: italic; }
    .lv-add { display: flex; gap: 6px; align-items: center; margin-top: 4px; }
    .lv-add select { max-width: 100%; flex: 1; padding: 3px; border-radius: 6px; border: 1px solid var(--lv-border); background: var(--lv-bg); color: var(--lv-ink); font-size: 12.5px; }
    .lv-absent { color: var(--lv-muted); font-style: italic; font-size: 13px; margin: 2px 0 6px; cursor: pointer; }
    .lv-absent:hover { color: var(--lv-accent); }
    .lv-badge { display: inline-block; font-size: 11px; border-radius: 10px; padding: 0 8px; background: #fbf3e2; color: #7a5200; border: 1px solid #e9d29a; }
    .lv-big { font-size: 34px; font-weight: 700; color: var(--lv-ok); line-height: 1.15; word-break: break-word; }
    .lv-big.no { color: var(--lv-fail); font-size: 24px; }
    .lv-big.cond { color: var(--lv-unknown); }
    .lv-unit { font-size: 18px; font-weight: 500; color: var(--lv-muted); margin-left: 6px; }
    .lv-sub { color: var(--lv-muted); font-size: 13px; margin-top: 4px; }
    .lv-ck { display: flex; gap: 10px; padding: 5px 0; border-bottom: 1px solid var(--lv-border); }
    .lv-ck:last-child { border: 0; }
    .lv-ok { color: var(--lv-ok); font-weight: 600; } .lv-fail { color: var(--lv-fail); font-weight: 600; } .lv-na { color: var(--lv-muted); }
    .lv ol { margin: 0; padding-left: 22px; } .lv ol li { margin: 0 0 8px; }
    .lv-cite { display: block; color: var(--lv-muted); font-size: 12px; font-style: italic; }
    .lv-src { border: 1px solid var(--lv-border); background: var(--lv-bg); color: var(--lv-accent); border-radius: 6px; padding: 0 6px; margin-left: 4px; font-family: Georgia, serif; cursor: pointer; }
    .lv-q { background: var(--lv-card); border: 1px solid var(--lv-border); border-radius: 8px; padding: 8px 10px; margin-bottom: 8px; }
    .lv-chip { display: inline-block; border: 1px solid var(--lv-accent); color: var(--lv-accent); border-radius: 14px; padding: 1px 11px; margin: 6px 5px 0 0; font-size: 12.5px; cursor: pointer; background: var(--lv-bg); }
    .lv table { border-collapse: collapse; width: 100%; font-size: 13px; }
    .lv th { text-align: left; font-size: 11px; text-transform: uppercase; letter-spacing: .04em; color: var(--lv-muted); border-bottom: 1px solid var(--lv-border); padding: 5px 6px; }
    .lv td { border-bottom: 1px solid var(--lv-border); padding: 6px; vertical-align: top; }
    .lv-doc { font-family: Georgia, serif; font-size: 13px; line-height: 1.55; white-space: pre-wrap; max-height: 460px; overflow: auto; background: var(--lv-card); border: 1px solid var(--lv-border); border-radius: 8px; padding: 10px; }
    .lv-doc mark { background: #fbe7a1; color: inherit; }
    .lv-draft { font-family: Georgia, serif; font-size: 13.5px; line-height: 1.55; white-space: pre-wrap; }
    .lv-interview { max-width: 460px; margin: 0 auto; }
    .lv-ask { font-size: 21px; font-weight: 600; margin: 18px 0 14px; }
    .lv-bigbtn { display: block; width: 100%; text-align: center; border: 2px solid var(--lv-accent); color: var(--lv-accent); background: var(--lv-bg); border-radius: 12px; padding: 11px; font-size: 16px; font-weight: 600; margin: 8px 0; cursor: pointer; }
    .lv-res { border-radius: 12px; padding: 12px 14px; font-size: 18px; font-weight: 600; }
    .lv-res.yes { background: #e9f6ee; color: #155e2e; } .lv-res.no { background: #fbeceb; color: #8c1d18; }
    .lv-status { color: var(--lv-muted); font-size: 12.5px; }
    `;
    document.head.appendChild(style);
}

// ---------------------------------------------------------------------------
// Reading answers
// ---------------------------------------------------------------------------

// The values of a query's "which …" places in an answer: the query's words
// are the pattern ("which passenger is entitled to compensation of which
// amount …"), each "which <noun>" a group. Keys are the nouns.
function answerSlots(queryText: string, answer: string): Record<string, string> {
    const whs = new Set([...kwPhrases(detectProgramLanguageSafe(), 'wh_var'), ...kwPhrases('en', 'wh_var')].map(w => w.toLowerCase()));
    const words = queryText.trim().split(/\s+/);
    const nouns: string[] = [];
    let pattern = '';
    for (let i = 0; i < words.length; i++) {
        if (whs.has(words[i].toLowerCase()) && i + 1 < words.length) {
            nouns.push(words[i + 1].toLowerCase());
            pattern += (pattern ? '\\s+' : '') + '(.+?)';
            i++;
        } else {
            pattern += (pattern ? '\\s+' : '') + words[i].replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        }
    }
    const m = new RegExp(`^${pattern}$`, 'i').exec(answer.trim());
    const out: Record<string, string> = {};
    if (m) nouns.forEach((n, i) => { out[n] = m[i + 1]; });
    return out;
}
let programLang = 'en';
const detectProgramLanguageSafe = () => programLang;

function citedSteps(why: any): any[] {
    const out: any[] = [], seen = new Set<string>();
    const walk = (n: any) => {
        if (!n || typeof n !== 'object') return;
        if (Array.isArray(n)) { n.forEach(walk); return; }
        if (n.type === 'success' && n.provenance && (n.provenance.document || n.provenance.url)) {
            const key = `${n.plain || n.literal}|${n.rule || ''}|${n.provenance.document || ''}|${n.provenance.quote || ''}`;
            if (!seen.has(key)) { seen.add(key); out.push(n); }
        }
        (n.children || []).forEach(walk);
    };
    walk(why);
    return out;
}

function citationLine(n: any): string {
    const p = n.provenance || {};
    const parts: string[] = [];
    if (n.rule) parts.push(`${t('rule')} ${n.rule}`);
    if (p.source && p.source !== p.document) parts.push(`${t('according to')} ${p.source}`);
    if (p.document) parts.push(p.document);
    if (p.quote) parts.push(`“${p.quote}”`); else if (p.locator) parts.push(p.locator);
    if (p.rationale) parts.push(`${t('because')} “${p.rationale}”`);
    return parts.join(' · ');
}

// the leaves of an explanation: the facts it rests on (or failed on)
function leaves(why: any): { literal: string; ok: boolean }[] {
    const out: { literal: string; ok: boolean }[] = [];
    const seen = new Set<string>();
    const walk = (n: any, negated: boolean) => {
        if (!n || typeof n !== 'object') return;
        if (Array.isArray(n)) { n.forEach(c => walk(c, negated)); return; }
        const kids = n.children || [];
        if (kids.length === 0) {
            const lit = String(n.plain || n.literal || '');
            if (lit && !/\d\s+is\s+(greater|less|equal)/.test(lit) && !seen.has(lit)) {
                seen.add(lit);
                out.push({ literal: lit, ok: n.type === 'success' });
            }
        } else kids.forEach((c: any) => walk(c, negated || !!n.naf));
    };
    walk(why, false);
    return out;
}

// ---------------------------------------------------------------------------
// The view
// ---------------------------------------------------------------------------

export async function mountView(root: HTMLElement, ctx: ViewContext): Promise<void> {
    ensureStyles();
    programLang = detectProgramLanguage(ctx.source || '');
    const V = ctx.view;
    const phrase = (key: string) => kwPhrases(programLang, key)[0] || kwPhrases('en', key)[0] || '';
    const queries: any[] = ctx.load.queries || [];
    const queryText = (name: string) => { const q = queries.find(x => String(x.name) === String(name)); return q ? String(q.le || '') : ''; };
    const blocks: ScenarioBlock[] = parseScenarioBlocks(ctx.source || '');
    const scenarioNames: string[] = (ctx.load.examples || []).map((e: any) => e.name);
    const templateDefs: any[] = ctx.load.template_defs || [];
    const documentCtx = { source: ctx.program };

    root.innerHTML = '';
    root.classList.add('lv');
    if (V.title && !ctx.titleShown) { const h = el('h2', '', V.title); h.style.cssText = 'margin:0 0 12px;font-size:20px;'; root.appendChild(h); }
    const status = el('div', 'lv-status');

    // --- the case: groups of facts, each a ScenarioForm ---------------------
    const groupDefs: { title: string | null; labels: string[]; judged: boolean }[] =
        (V.groups || []).map((g: any) => ({ title: g.title, labels: g.facts.map((f: any) => f.label), judged: g.judged }));
    const grouped = new Set<string>(groupDefs.flatMap(g => g.labels));
    const allLabels = templateDefs.map(d => d.label);
    const otherLabels = allLabels.filter(l => !grouped.has(l) && templateDefs.find(d => d.label === l && (d.scenario_element || d.judged)));
    let caseProvenance = '';
    let caseName = '';
    const forms: { form: ScenarioForm; labels: string[]; box: HTMLElement; absent: HTMLElement; named: boolean }[] = [];
    let dirty = false;

    const factsCard = el('div', 'lv-card');
    const casePicker = document.createElement('select');
    casePicker.style.cssText = 'width:100%;padding:5px;border-radius:8px;border:1px solid var(--lv-border);background:var(--lv-bg);color:var(--lv-ink);';
    casePicker.appendChild(new Option(t('New case'), ''));
    for (const n of scenarioNames) casePicker.appendChild(new Option(n, n));
    const factsHead = el('div', 'lv-h', t('The case'));
    factsCard.appendChild(factsHead);
    if (V.case && V.case.kind !== 'subject') factsCard.appendChild(casePicker);

    const makeGroup = (title: string | null, labels: string[], judged: boolean, all: boolean) => {
        const box = el('div');
        const head = el('div', 'lv-grp', title ?? (judged ? t('Judgments') : t('Other facts')));
        box.appendChild(head);
        const rows = el('div');
        const absent = el('div');
        const add = el('div', 'lv-add');
        const sel = document.createElement('select');
        const btn = el('button', 'lv-btn', t('+ Add')) as HTMLButtonElement;
        add.appendChild(sel); add.appendChild(btn);
        box.appendChild(rows); box.appendChild(absent); box.appendChild(add);
        const form = new ScenarioForm({
            source: ctx.source, rowsEl: rows, addSelect: sel, btnAdd: btn,
            extraTemplates: templateDefs, onlyTemplates: all ? undefined : labels,
            onChange: () => { dirty = true; scheduleRun(); },
        });
        if (form.addableTemplates.length === 0) add.style.display = 'none';
        forms.push({ form, labels, box, absent, named: !all && title !== null || judged });
        return box;
    };
    for (const g of groupDefs) factsCard.appendChild(makeGroup(g.title, g.labels, g.judged, false));
    if (V.otherFacts !== false && otherLabels.length) factsCard.appendChild(makeGroup(groupDefs.length ? null : t('Facts'), otherLabels, false, groupDefs.length === 0));

    // a group's templates the case does not state: shown, one click to state
    const showAbsent = () => {
        for (const f of forms) {
            f.absent.innerHTML = '';
            if (!f.named) continue;          // the other facts: offered by the Add menu only
            const present = new Set(f.form.factLines().map(l => { const m = matchFact(l.split(/,\s*(?=\S)/)[0], f.labels); return m ? m.label : ''; }));
            for (const label of f.labels) {
                if (present.has(label)) continue;
                const a = el('div', 'lv-absent', `${label.replace(/\*/g, '')} — ${t('not stated')}`);
                a.title = t('State it');
                a.addEventListener('click', () => { f.form.addFact(label.replace(/\*/g, ''), false); });
                f.absent.appendChild(a);
            }
        }
    };

    const loadCase = (name: string) => {
        caseName = name;
        const block = blocks.find(b => b.name === name);
        caseProvenance = block?.provenance || '';
        const facts = block ? block.facts : [];
        const byForm = forms.map(() => [] as string[]);
        for (const fact of facts) {
            if (isTestDirective(fact)) continue;     // "… expects answers …": a test, not a fact
            let placed = false;
            for (let i = 0; i < forms.length && !placed; i++) {
                const m = matchFact(fact.split(/,\s*(?=(?:according|as stated|because|confer))/i)[0], forms[i].labels);
                if (m) { byForm[i].push(fact); placed = true; }
            }
            if (!placed && forms.length) byForm[forms.length - 1].push(fact);
        }
        forms.forEach((f, i) => { f.form.loadFacts(byForm[i]); f.form.provenance = caseProvenance; });
        dirty = false;
        showAbsent();
    };

    const caseFactsText = (): string => {
        const lines: string[] = [];
        for (const f of forms) for (const l of f.form.factLines()) lines.push(withDefaultProvenance(l, caseProvenance, ctx.source));
        return lines.map(l => `${l}.`).join('\n');
    };

    // --- running the result ----------------------------------------------------
    const R = V.result || {};
    const resultRequest = (): any => {
        const req: any = { sessionModule: ctx.sessionModule };
        if (!dirty && caseName) req.scenario = caseName; else req.customScenario = caseFactsText();
        if (R.whether) req.customQuery = R.whether; else if (R.query) req.query = R.query;
        return req;
    };

    // widget containers
    const cards: Record<string, HTMLElement> = {};
    const card = (key: string, title: string) => {
        const c = el('div', 'lv-card'); c.dataset.widget = key;
        const h = el('div', 'lv-h'); h.appendChild(el('span', '', title)); h.appendChild(el('span', 'lv-tools')); c.appendChild(h);
        const body = el('div'); body.className = 'lv-body'; c.appendChild(body);
        cards[key] = c;
        return c;
    };
    const bodyOf = (key: string) => cards[key]?.querySelector('.lv-body') as HTMLElement | null;
    // the header's buttons, emptied at each render
    const headOf = (key: string) => { const x = cards[key]?.querySelector('.lv-tools') as HTMLElement | null; return x; };
    const clearTools = (key: string) => { const x = headOf(key); if (x) x.innerHTML = ''; };

    let lastResult: any = null;

    const renderResult = (res: any) => {
        const b = bodyOf('result'); if (!b) return;
        b.innerHTML = '';
        const results: any[] = res.results || [];
        const holds = results.length > 0;
        if (R.whether) {
            const d = el('div', `lv-res ${holds ? 'yes' : 'no'}`, holds ? (R.holds || results[0].answer) : (R.not || t('No')));
            b.appendChild(d);
            return;
        }
        if (!holds) {
            b.appendChild(el('div', 'lv-big no', R.not || t('No answer')));
            const failed = (res.checklist || []).find((c: any) => c.status === 'failed');
            if (failed) b.appendChild(el('div', 'lv-sub', `${t('fails at')} ${failed.section}`));
            else if (res.strongestReason) b.appendChild(el('div', 'lv-sub', res.strongestReason));
            return;
        }
        for (const r of results.slice(0, 5)) {
            const slots = answerSlots(queryText(R.query), r.answer);
            const head = R.headedBy ? slots[String(R.headedBy).split(/\s+/).pop()!.toLowerCase()] : null;
            if (head) {
                const big = el('div', 'lv-big', head);
                if (R.unit) big.appendChild(el('span', 'lv-unit', R.unit));
                b.appendChild(big);
            }
            const conditional = r.unknowns && r.unknowns.length;
            const line = el('div', head ? 'lv-sub' : 'lv-big', r.answer);
            if (conditional && !head) line.classList.add('cond');
            b.appendChild(line);
            if (conditional) b.appendChild(el('div', 'lv-sub', `${t('provided that')}: ${r.unknowns.join('; ')}`));
        }
        if (R.holds) b.appendChild(el('div', 'lv-sub', R.holds));
    };

    const renderStage = (res: any) => {
        const b = bodyOf('stage'); if (!b) return;
        b.innerHTML = '';
        const cl: any[] = res.checklist || [];
        if (!cl.length) { b.appendChild(el('div', 'lv-status', t('No sections to check.'))); return; }
        for (const c of cl) {
            const row = el('div', 'lv-ck');
            const mark = c.status === 'passed' ? ['lv-ok', '✓'] : c.status === 'failed' ? ['lv-fail', '✗'] : ['lv-na', '–'];
            row.appendChild(el('span', mark[0], mark[1]));
            row.appendChild(el('b', '', String(c.section)));
            row.appendChild(el('span', 'lv-na', t(c.status === 'passed' ? 'passed' : c.status === 'failed' ? 'failed' : 'not reached')));
            b.appendChild(row);
        }
    };

    const sourceButton = (n: any) => {
        const p: Provenance = n.provenance || {};
        const btn = el('button', 'lv-src', '§') as HTMLButtonElement;
        btn.title = t('Show original text');
        btn.addEventListener('click', () => {
            if (!p.text && p.url) { window.open(originalUrl(p) || p.url, '_blank'); return; }
            openSourceViewer(p, n.rule || undefined, documentCtx);
        });
        return btn;
    };

    // the explanation of the result (a failed query's leads with its section
    // checklist, which the stage widget shows)
    const whyOf = (res: any) => {
        if (res.results && res.results.length) return res.results[0].why;
        const w = res.why;
        if (Array.isArray(w) && (res.checklist || []).length && w.length > 1 && !(w[0].children || []).length) return w.slice(1);
        return w;
    };

    const renderCitations = (res: any) => {
        const b = bodyOf('citations'); if (!b) return;
        b.innerHTML = ''; clearTools('citations');
        const steps = citedSteps(whyOf(res));
        if (!steps.length) { b.appendChild(el('div', 'lv-status', t('No cited steps.'))); return; }
        const ol = el('ol');
        const FIRST = 10;
        steps.forEach((n, i) => {
            const li = el('li');
            if (i >= FIRST) li.hidden = true;
            li.appendChild(el('span', '', n.plain || n.literal));
            if (n.provenance && (n.provenance.text || n.provenance.url)) li.appendChild(sourceButton(n));
            li.appendChild(el('span', 'lv-cite', citationLine(n)));
            ol.appendChild(li);
        });
        b.appendChild(ol);
        if (steps.length > FIRST) {
            const more = el('button', 'lv-btn', `${t('Show all')} (${steps.length})`);
            more.addEventListener('click', () => { ol.querySelectorAll('li').forEach(li => (li as HTMLElement).hidden = false); more.remove(); });
            b.appendChild(more);
        }
        const copy = el('button', '', t('Copy'));
        copy.addEventListener('click', () => navigator.clipboard?.writeText(
            steps.map((n, i) => `${i + 1}. ${n.plain || n.literal}\n   ${citationLine(n)}`).join('\n')).catch(() => { }));
        headOf('citations')?.appendChild(copy);
    };

    const questionFor = (literal: string) => (V.questions || []).find((q: any) => norm(q.instance) === norm(literal));

    const renderReasons = (res: any) => {
        const b = bodyOf('reasons'); if (!b) return;
        b.innerHTML = '';
        const ls = leaves(whyOf(res)).slice(0, 14);
        for (const l of ls) {
            const q = questionFor(l.literal);
            const row = el('div', 'lv-ck');
            row.appendChild(el('span', l.ok ? 'lv-ok' : 'lv-fail', l.ok ? '✓' : '✗'));
            row.appendChild(el('span', '', q ? `${q.text} — ${l.ok ? t('yes') : t('no')}` : l.literal));
            b.appendChild(row);
        }
        if (!ls.length) b.appendChild(el('div', 'lv-status', t('No reasons to show.')));
    };

    const renderDocuments = (res: any) => {
        const b = bodyOf('documents'); if (!b) return;
        b.innerHTML = '';
        const docs = new Map<string, { p: Provenance; quotes: string[]; locators: string[] }>();
        for (const n of citedSteps(whyOf(res))) {
            const p: Provenance = n.provenance || {};
            if (!p.document) continue;
            const d = docs.get(p.document) || { p, quotes: [], locators: [] };
            if (p.quote) { if (!d.quotes.includes(p.quote)) d.quotes.push(p.quote); }
            else if (p.locator && !d.locators.includes(p.locator)) d.locators.push(p.locator);
            docs.set(p.document, d);
        }
        if (!docs.size) { b.appendChild(el('div', 'lv-status', t('No documents cited.'))); return; }
        const list = el('div');
        const pane = el('div');
        b.appendChild(list); b.appendChild(pane);
        const show = async (name: string) => {
            const d = docs.get(name)!;
            pane.innerHTML = '';
            if (!d.p.text) {
                pane.appendChild(el('div', 'lv-status', t('The program does not say where the text of this document is')));
                return;
            }
            const res2 = await fetchDocumentText(d.p.text, documentCtx);
            if (!res2 || typeof res2.text !== 'string') { pane.appendChild(el('div', 'lv-status', (res2 && res2.error) || '')); return; }
            const text = res2.text;
            const spans = d.quotes.map(q => findQuote(text, q)).filter((x): x is [number, number] => !!x).sort((a, b) => a[0] - b[0]);
            const box = el('div', 'lv-doc');
            let at = 0;
            for (const [s, e] of spans) {
                if (s < at) continue;
                box.appendChild(document.createTextNode(text.slice(at, s)));
                box.appendChild(el('mark', '', text.slice(s, e)));
                at = e;
            }
            box.appendChild(document.createTextNode(text.slice(at)));
            pane.appendChild(box);
            box.querySelector('mark')?.scrollIntoView({ block: 'center' });
        };
        let first = '';
        for (const [name, d] of docs) if (d.p.text && caseProvenance.includes(name)) { first = name; break; }
        for (const [name, d] of docs) {
            const row = el('div', 'lv-ck');
            const a = el('b', '', name); a.style.cursor = d.p.text ? 'pointer' : 'default';
            a.addEventListener('click', () => show(name));
            row.appendChild(a);
            const what = [...d.locators.slice(0, 4)];
            if (d.quotes.length) what.push(`${d.quotes.length} ${d.quotes.length === 1 ? t('passage') : t('passages')}`);
            row.appendChild(el('span', 'lv-na', what.join(' · ')));
            list.appendChild(row);
            if (!first && d.p.text) first = name;
        }
        if (first) show(first);
        else pane.appendChild(el('div', 'lv-status', t('No text attached to these documents: the program says where each is cited, not where its text is.')));
    };

    const flipText = (goal: string, negate: boolean) =>
        `${phrase('flip_query')} ${negate ? phrase('not_the_case') + ' ' : ''}${goal}`;

    const renderWhatIf = () => {
        const b = bodyOf('whatif'); if (!b) return;
        b.innerHTML = '';
        const go = el('button', 'lv-btn', t('Find the smallest changes'));
        const out = el('div');
        b.appendChild(go); b.appendChild(out);
        go.addEventListener('click', async () => {
            if (!lastResult) return;
            const results: any[] = lastResult.results || [];
            let goal: string;
            let negate: boolean;
            if (results.length) { goal = results[0].goal || results[0].answer; negate = true; }
            else if (R.whether) { goal = R.whether; negate = false; }
            else { goal = queryText(R.query); negate = false; }
            out.innerHTML = '';
            out.appendChild(el('div', 'lv-status', t('Searching…')));
            const req = resultRequest();
            delete req.query;
            req.customQuery = flipText(goal, negate);
            const res = await leapi({ operation: 'answeringQuery', ...req });
            out.innerHTML = '';
            const sets: string[] = (res.results || []).map((r: any) => String(r.answer));
            if (!sets.length) { out.appendChild(el('div', 'lv-status', t('No change of up to three facts would change it.'))); return; }
            for (const s of sets.slice(0, 8)) out.appendChild(el('div', 'lv-ck', sayChange(s)));
            if (sets.length > 8) out.appendChild(el('div', 'lv-status', `… ${sets.length} ${t('change sets')}`));
        });
    };

    // "add: X" / "remove: X", said with the view's question when it has one
    const sayChange = (s: string): string => {
        return s.split(/\s+and\s+(?=(?:add|remove):)/).map(part => {
            const m = /^(add|remove):\s*(.*)$/.exec(part.trim());
            if (!m) return part;
            const q = questionFor(m[2]);
            if (q) return `${t('Answering')} ${m[1] === 'add' ? t('yes') : t('no')} ${t('to')} “${q.text}”`;
            return part;
        }).join(' — ');
    };

    const renderTables = async () => {
        const b0 = bodyOf('tables'); if (!b0) return;
        const b = el('div');         // built apart, put in place once complete
        for (const tb of V.tables || []) {
            if ((V.tables || []).length > 1) b.appendChild(el('div', 'lv-grp', tb.title));
            const req = resultRequest();
            delete req.query;
            req.customQuery = tb.question;
            const res = await leapi({ operation: 'answeringQuery', ...req });
            const results: any[] = res.results || [];
            if (!results.length) { b.appendChild(el('div', 'lv-status', t('None.'))); continue; }
            const slots0 = answerSlots(tb.question, results[0].answer);
            const cols = Object.keys(slots0);
            const table = el('table');
            const hr = el('tr');
            (cols.length ? cols : [t('Answer')]).forEach(c => hr.appendChild(el('th', '', c)));
            table.appendChild(hr);
            for (const r of results) {
                const tr = el('tr');
                const sl = answerSlots(tb.question, r.answer);
                if (cols.length) cols.forEach(c => tr.appendChild(el('td', '', sl[c] || ''))); else tr.appendChild(el('td', '', r.answer));
                table.appendChild(tr);
            }
            b.appendChild(table);
        }
        b0.innerHTML = '';
        b0.appendChild(b);
    };

    const renderCompare = async () => {
        const b = bodyOf('compare'); if (!b) return;
        b.innerHTML = '';
        for (const sc of V.compare || []) {
            b.appendChild(el('div', 'lv-grp', sc));
            const req: any = { sessionModule: ctx.sessionModule, scenario: sc };
            if (R.whether) req.customQuery = R.whether; else req.query = R.query;
            const res = await leapi({ operation: 'answeringQuery', ...req });
            const results: any[] = res.results || [];
            if (results.length) results.slice(0, 3).forEach(r => b.appendChild(el('div', 'lv-ok', R.whether && R.holds ? R.holds : r.answer)));
            else {
                b.appendChild(el('div', 'lv-fail', R.whether && R.not ? R.not : t('No answer')));
                const failed = (res.checklist || []).find((c: any) => c.status === 'failed');
                if (failed) b.appendChild(el('div', 'lv-sub', `${t('fails at')} ${failed.section}`));
                if (res.strongestReason) b.appendChild(el('div', 'lv-sub', res.strongestReason));
            }
        }
    };

    const renderCases = () => {
        const b = bodyOf('cases'); if (!b) return;
        b.innerHTML = '';
        const go = el('button', 'lv-btn', t('Run all cases'));
        const out = el('div');
        b.appendChild(go); b.appendChild(out);
        go.addEventListener('click', async () => {
            out.innerHTML = '';
            const table = el('table');
            const hr = el('tr');
            [t('Case'), t('Result'), t('Expected'), ''].forEach(c => hr.appendChild(el('th', '', c)));
            table.appendChild(hr);
            out.appendChild(table);
            for (const sc of scenarioNames) {
                const req: any = { sessionModule: ctx.sessionModule, scenario: sc };
                if (R.whether) req.customQuery = R.whether; else req.query = R.query;
                const res = await leapi({ operation: 'answeringQuery', ...req });
                const answers: string[] = (res.results || []).map((r: any) => String(r.answer));
                const block = blocks.find(x => x.name === sc);
                const expected = R.query ? expectedAnswers(block, R.query) : null;
                const tr = el('tr');
                const a = el('a', '', sc); a.setAttribute('href', '#'); a.addEventListener('click', (e) => { e.preventDefault(); casePicker.value = sc; loadCase(sc); run(); });
                const td0 = el('td'); td0.appendChild(a); tr.appendChild(td0);
                tr.appendChild(el('td', '', answers.length ? answers.join('; ') : t('No answer')));
                tr.appendChild(el('td', '', expected === null ? '—' : expected.length ? expected.join('; ') : t('No answer')));
                const agree = expected === null ? '' : sameSet(answers, expected) ? '✓' : '✗';
                tr.appendChild(el('td', agree === '✓' ? 'lv-ok' : agree === '✗' ? 'lv-fail' : '', agree));
                table.appendChild(tr);
            }
        });
    };

    const renderDraft = (res: any) => {
        const b = bodyOf('draft'); if (!b || !V.draft) return;
        b.innerHTML = ''; clearTools('draft');
        const results: any[] = res.results || [];
        const slots = results.length && R.query ? answerSlots(queryText(R.query), results[0].answer) : {};
        const head = R.headedBy ? slots[String(R.headedBy).split(/\s+/).pop()!.toLowerCase()] : null;
        const fill: Record<string, string> = {
            'the result': head || (results[0]?.answer ?? (R.not || t('No answer'))),
            'the answer': results[0]?.answer ?? (R.not || t('No answer')),
            // the legal basis: the steps a labelled rule or table row cites
            'the citations': citedSteps(whyOf(res)).filter(n => n.rule || /^row /.test(String(n.literal))).map(n => citationLine(n)).filter((x, i, a) => a.indexOf(x) === i).join('; '),
            'the facts': forms.flatMap(f => f.form.factLines()).join('; '),
            'the case': caseName,
        };
        const text = String(V.draft).replace(/\{([^}]+)\}/g, (m, k) => (k.trim() in fill ? fill[k.trim()] : m));
        b.appendChild(el('div', 'lv-draft', text));
        const copy = el('button', '', t('Copy'));
        copy.addEventListener('click', () => navigator.clipboard?.writeText(text).catch(() => { }));
        headOf('draft')?.appendChild(copy);
    };

    // --- what is missing ----------------------------------------------------
    const renderMissing = async () => {
        const b = bodyOf('questions'); if (!b) return;
        const req = resultRequest();
        const oq = await leapi({ operation: 'openQuestions', ...req });
        b.innerHTML = '';            // after the answer: a later run may have rendered meanwhile
        // a result that holds only provided that some facts hold: those are missing
        const assumed: string[] = !oq.holds && lastResult && (lastResult.results || []).length
            ? [...new Set<string>((lastResult.results || []).flatMap((r: any) => r.unknowns || []))] : [];
        if (assumed.length) {
            for (const u of assumed) {
                const box = el('div', 'lv-q');
                const q = questionFor(u);
                box.appendChild(el('div', '', q ? q.text : `${u}?`));
                box.appendChild(el('div', 'lv-sub', t('The result holds provided that it does.')));
                const y = el('span', 'lv-chip', t('Yes, state it'));
                y.addEventListener('click', () => {
                    const f = forms.find(x => matchFact(u, x.labels)) || forms[forms.length - 1];
                    if (f) f.form.addFact(u, false);
                });
                box.appendChild(y);
                b.appendChild(box);
            }
            return;
        }
        if (oq.holds || !(oq.missing || []).length) { b.appendChild(el('div', 'lv-status', oq.holds ? t('Nothing is missing.') : t('No fact of the case would give a result on its own.'))); return; }
        for (const m of oq.missing) {
            const q = questionFor(m.literal);
            const box = el('div', 'lv-q');
            box.appendChild(el('div', '', q ? q.text : `${m.literal}?`));
            const ground = !/\b(a|an)\s+\w+/.test(m.goal.replace(/^[^ ]+ /, '')) || !(m.values || []).some((v: string[]) => v && v.length);
            const addFact = (text: string) => {
                const f = forms.find(x => x.labels.includes(m.label)) || forms[forms.length - 1];
                if (f) f.form.addFact(text, false);
            };
            if (ground) {
                const y = el('span', 'lv-chip', t('Yes, state it'));
                y.addEventListener('click', () => addFact(m.goal));
                box.appendChild(y);
            } else {
                const vals: string[] = (m.values || []).flat();
                for (const v of vals.slice(0, 10)) {
                    const c = el('span', 'lv-chip', v);
                    c.addEventListener('click', () => {
                        const mm = matchFact(m.goal, [m.label]);
                        if (!mm) { addFact(m.goal); return; }
                        const segs = m.label.match(/\*[^*]+\*/g) || [];
                        const values = mm.values.map((x: string, i: number) => (segs[i] && x === segs[i].replace(/\*/g, '') && m.values[i] && m.values[i].length ? v : x));
                        addFact(fillLabel(m.label, values));
                    });
                    box.appendChild(c);
                }
                const s = el('span', 'lv-chip', t('State it'));
                s.addEventListener('click', () => addFact(m.goal));
                box.appendChild(s);
            }
            b.appendChild(box);
        }
    };

    // --- run ------------------------------------------------------------------
    let runTimer: any = null;
    const scheduleRun = () => { if (runTimer) clearTimeout(runTimer); runTimer = setTimeout(() => { showAbsent(); run(); }, 700); };
    const run = async () => {
        status.textContent = t('Running…');
        const res = await leapi({ operation: 'answeringQuery', ...resultRequest() });
        lastResult = res;
        status.textContent = res.error ? String(res.error) : '';
        renderResult(res);
        renderStage(res);
        renderCitations(res);
        renderReasons(res);
        renderDocuments(res);
        renderDraft(res);
        renderWhatIf();
        if (cards.questions && V.missing) renderMissing();
        renderTables();
    };

    // --- interview: one question at a time ----------------------------------------
    if (V.interview) {
        const box = el('div', 'lv-interview');
        root.appendChild(box);
        const answers = new Map<string, 'yes' | 'no' | 'unsure'>();
        const facts = () => (V.questions || []).filter((q: any) => answers.get(q.instance) === 'yes').map((q: any) => `${q.instance}.`).join('\n');
        const req = () => {
            const r: any = { sessionModule: ctx.sessionModule, customScenario: facts() };
            if (R.whether) r.customQuery = R.whether; else r.query = R.query;
            return r;
        };
        const step = async () => {
            box.innerHTML = '';
            const oq = await leapi({ operation: 'openQuestions', ...req() });
            const touched = new Set<string>((oq.touched || []).map((x: any) => norm(x.literal)));
            const next = oq.holds ? null : (V.questions || []).find((q: any) => !answers.has(q.instance) && touched.has(norm(q.instance)));
            const total = (V.questions || []).length;
            if (next) {
                box.appendChild(el('div', 'lv-status', `${t('Question')} ${answers.size + 1} ${t('of at most')} ${total}`));
                box.appendChild(el('div', 'lv-ask', next.text));
                for (const [k, label] of [['yes', t('Yes')], ['no', t('No')], ['unsure', t('Not sure')]] as const) {
                    const bb = el('button', 'lv-bigbtn', label);
                    bb.addEventListener('click', () => { answers.set(next.instance, k); step(); });
                    box.appendChild(bb);
                }
                if (answers.size) {
                    const back = el('button', 'lv-btn', `← ${t('Back')}`);
                    back.addEventListener('click', () => { const keys = [...answers.keys()]; answers.delete(keys[keys.length - 1]); step(); });
                    box.appendChild(back);
                }
                return;
            }
            const res = await leapi({ operation: 'answeringQuery', ...req() });
            lastResult = res;
            const holds = (res.results || []).length > 0;
            box.appendChild(el('div', `lv-res ${holds ? 'yes' : 'no'}`, holds ? (R.holds || res.results[0].answer) : (R.not || t('No'))));
            if (V.reasons) {
                box.appendChild(el('div', 'lv-grp', t('Why')));
                for (const q of V.questions || []) {
                    if (!answers.has(q.instance)) continue;
                    const a = answers.get(q.instance)!;
                    const row = el('div', 'lv-ck');
                    row.appendChild(el('span', a === 'yes' ? 'lv-ok' : 'lv-fail', a === 'yes' ? '✓' : a === 'no' ? '✗' : '?'));
                    row.appendChild(el('span', '', `${q.text} — ${a === 'yes' ? t('yes') : a === 'no' ? t('no') : t('not sure')}`));
                    box.appendChild(row);
                }
            }
            if (V.flip) {
                box.appendChild(el('div', 'lv-grp', V.flip.label || t('What would change this?')));
                const goal = holds ? (res.results[0].goal || res.results[0].answer) : (R.whether || queryText(R.query));
                const r2 = req(); delete r2.query; r2.customQuery = flipText(goal, holds);
                const fl = await leapi({ operation: 'answeringQuery', ...r2 });
                const sets: string[] = (fl.results || []).map((r: any) => String(r.answer));
                if (!sets.length) box.appendChild(el('div', 'lv-status', t('No change of up to three facts would change it.')));
                sets.slice(0, 6).forEach((s, i) => box.appendChild(el('div', 'lv-ck', (i ? `${t('or')} ` : '') + sayChange(s))));
            }
            const again = el('button', 'lv-bigbtn', t('Change an answer'));
            again.addEventListener('click', () => { const keys = [...answers.keys()]; answers.delete(keys[keys.length - 1]); step(); });
            box.appendChild(again);
        };
        await step();
        return;
    }

    // --- layout: the view's order, in three columns ---------------------------------
    const left = el('div', 'lv-col'), mid = el('div', 'lv-col'), right = el('div', 'lv-col'), wide = el('div', 'lv-wide');
    const grid = el('div', 'lv-grid');
    grid.appendChild(left); grid.appendChild(mid); grid.appendChild(right);
    root.appendChild(status);
    root.appendChild(grid);
    root.appendChild(wide);
    left.appendChild(factsCard);
    const titles: Record<string, string> = {
        questions: t('What is missing'), result: t('Result'), stage: t('Stage'), citations: t('Citations'),
        reasons: t('Reasons'), whatif: (V.flip && V.flip.label) || t('What would change this?'), tables: t('Answers'),
        compare: t('Compare'), documents: t('Documents'), cases: t('Cases'), draft: t('Draft'),
    };
    const column: Record<string, HTMLElement> = {
        questions: left, result: mid, stage: mid, citations: mid, reasons: mid, whatif: mid,
        tables: right, compare: right, documents: right, cases: wide, draft: wide,
    };
    const order: string[] = (V.order || []).filter((w: string) => w !== 'facts');
    if (!order.includes('result') && (R.query || R.whether)) order.unshift('result');
    for (const w of order) {
        if (!column[w] || cards[w]) continue;
        if (w === 'tables' && titles.tables && (V.tables || []).length === 1) titles.tables = V.tables[0].title;
        column[w].appendChild(card(w, titles[w] || w));
    }
    if (!right.children.length) grid.classList.add('two');
    renderCompare();
    renderCases();
    // a small program's cases run straight away
    if (cards.cases && scenarioNames.length <= 12) (cards.cases.querySelector('button') as HTMLButtonElement | null)?.click();

    casePicker.addEventListener('change', () => { loadCase(casePicker.value); run(); });
    const initial = new URLSearchParams(location.search).get('scenario');
    const start = initial && scenarioNames.includes(initial) ? initial : (scenarioNames[0] || '');
    casePicker.value = start;
    loadCase(start);
    await run();
}

function expectedAnswers(block: ScenarioBlock | undefined, query: string): string[] | null {
    if (!block) return null;
    for (const f of block.facts) {
        const m = new RegExp(`^${String(query).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s+\\S+(?:\\s+\\S+)?\\s*\\[([^\\]]*)\\]`, 'i').exec(f.trim());
        if (m && /\[/.test(f)) {
            return (m[1].match(/"([^"]*)"/g) || []).map(s => s.slice(1, -1));
        }
    }
    return null;
}

function sameSet(a: string[], b: string[]): boolean {
    const n = (x: string) => x.replace(/\s+/g, ' ').trim().toLowerCase();
    const A = new Set(a.map(n)), B = new Set(b.map(n));
    return A.size === B.size && [...A].every(x => B.has(x));
}

function fillLabel(label: string, values: string[]): string {
    let i = 0;
    return label.replace(/\*[^*]+\*/g, () => values[i++] ?? '');
}
