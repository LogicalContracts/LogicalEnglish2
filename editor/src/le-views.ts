// LE Views (docs/user/reference/language.md §17.10): a screen for one program, composed of
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
import { openSourceViewer, fetchDocumentText, findQuote, originalUrl, locatorLines, lineSpan, Provenance } from './source-viewer';

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

// What each part of a view is, said when the pointer rests on it (the view's
// own words say what the case is about; these say what the widget does).
const WIDGET_TIPS: Record<string, string> = {
    facts: 'The facts of the case. Change a value, add or remove a fact, or pick another case; then Re-evaluate',
    questions: 'The facts the result still depends on: answer them to complete the case',
    result: "The answer to the view's question for this case, worked out from the rules and the facts on the left",
    stage: 'The sections of the rules in order: which the case passes, and where it stops',
    citations: 'Every step of the result that cites a source, in the order of the reasoning; § opens the passage',
    reasons: 'The facts the result rests on; when it fails, the conditions it did not meet and why',
    whatif: 'The smallest changes to the facts of the case that would change the result',
    tables: 'Further answers about this case, one row per answer',
    compare: 'The same question asked of other scenarios of the program',
    documents: 'The documents the result cites, with the cited passages marked',
    cases: "Every scenario of the program run through the view's question, beside the answer the scenario expects",
    draft: 'A text filled in from the result, to copy into a letter or a note',
};

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
    .lv-who { align-self: center; font-size: 11px; border: 1px solid var(--lv-accent); color: var(--lv-accent); border-radius: 10px; padding: 0 7px; margin-left: 6px; white-space: nowrap; }
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
    .lv-answer-field { display: block; width: 100%; box-sizing: border-box; font-size: 17px; padding: 10px; border-radius: 10px; border: 2px solid var(--lv-border); margin: 6px 0; background: var(--lv-bg); color: var(--lv-ink); }
    .lv-bigbtn { display: block; width: 100%; text-align: center; border: 2px solid var(--lv-accent); color: var(--lv-accent); background: var(--lv-bg); border-radius: 12px; padding: 11px; font-size: 16px; font-weight: 600; margin: 8px 0; cursor: pointer; }
    .lv-res { border-radius: 12px; padding: 12px 14px; font-size: 18px; font-weight: 600; }
    .lv-res.yes { background: #e9f6ee; color: #155e2e; } .lv-res.no { background: #fbeceb; color: #8c1d18; }
    .lv-status { color: var(--lv-muted); font-size: 12.5px; }
    .lv-progress { margin-left: 10px; }
    .lv-busy, .lv-busy table { cursor: progress; }
    .lv-kind { display: inline-block; font-size: 11px; border-radius: 10px; padding: 0 7px; margin-left: 6px; border: 1px solid; }
    .lv-kind.silent { color: var(--lv-unknown); border-color: var(--lv-unknown); }
    .lv-kind.met { color: var(--lv-fail); border-color: var(--lv-fail); }
    .lv-evalbar { display: flex; flex-wrap: wrap; align-items: center; gap: 10px; margin: 0 0 12px; padding: 6px 10px; border: 1px solid var(--lv-border); border-radius: 10px; background: var(--lv-bg); position: sticky; top: 0; z-index: 5; }
    .lv-evalbar.stale { background: #fff6d6; border-color: #e9c46a; }
    .lv-evalbar .lv-status { flex: 1 1 auto; }
    .lv-evalbar label { font-size: 12.5px; color: var(--lv-muted); display: flex; align-items: center; gap: 4px; cursor: pointer; }
    .lv-evalbar .lv-btn[disabled] { opacity: .5; cursor: default; }
    .lv-stale [data-widget] .lv-body { opacity: .45; transition: opacity .2s; }
    .lv-changed { background: #fff3bf; border-radius: 4px; transition: background 2s; }
    .lv-flags:empty, .lv-warnings:empty { display: none; }
    .lv-flag { background: #fbeceb; color: #8c1d18; border: 2px solid #d9534f; border-radius: 10px; padding: 10px 14px; margin: 0 0 12px; font-size: 17px; display: flex; flex-wrap: wrap; gap: 12px; align-items: baseline; }
    .lv-flag-why { font-size: 13px; color: #8c1d18; opacity: .85; }
    .lv-warnings { background: #fff6d6; border: 1px solid #e9c46a; border-radius: 10px; padding: 8px 12px; margin: 0 0 12px; }
    .lv-warn-h { font-weight: 600; margin-bottom: 4px; }
    .lv-warn { font-size: 13px; margin: 3px 0; }
    .lv-types { margin-top: 8px; }
    .lv-was { color: var(--lv-muted); font-size: 12.5px; text-decoration: line-through; margin-top: 2px; }
    [title] { text-underline-offset: 3px; }
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

// a passage as a letter cites it: the document and its words (the rule's
// name is the program's, not the letter's)
function draftCitation(n: any): string {
    const p = n.provenance || {};
    const parts: string[] = [];
    if (p.document) parts.push(p.document);
    if (p.quote) parts.push(`“${p.quote}”`); else if (p.locator) parts.push(p.locator);
    return parts.join(', ');
}

// the leaves of an explanation: the facts it rests on (or failed on). A
// negation that holds is one reason, "it is not the case that …" what it
// denies, ticked — not the crosses of the alternatives it rules out; the
// denials of one statement with different values are said once ("… is 1, 2
// or 3"); an equality of a thing with itself says nothing and is left out.
function leaves(why: any): { literal: string; ok: boolean }[] {
    const out: { literal: string; ok: boolean }[] = [];
    const seen = new Set<string>();
    const notWords = kwPhrases(detectProgramLanguageSafe(), 'not_the_case')[0] || 'it is not the case that';
    const push = (lit: string, ok: boolean) => {
        if (!lit || seen.has(lit)) return;
        if (/^\s*(\S+)\s*(?:=|is equal to)\s*\1\s*$/.test(lit)) return;
        seen.add(lit);
        out.push({ literal: lit, ok });
    };
    const failedLeaves = (n: any, acc: string[]) => {
        if (!n || typeof n !== 'object') return;
        if (Array.isArray(n)) { n.forEach(c => failedLeaves(c, acc)); return; }
        const kids = n.children || [];
        if (kids.length === 0) { if (n.type !== 'success') acc.push(String(n.plain || n.literal || '')); }
        else kids.forEach((c: any) => failedLeaves(c, acc));
    };
    const walk = (n: any) => {
        if (!n || typeof n !== 'object') return;
        if (Array.isArray(n)) { n.forEach(walk); return; }
        const kids = n.children || [];
        if (n.naf && n.type === 'success') {
            const denied: string[] = [];
            failedLeaves(kids, denied);
            if (!denied.length) push(String(n.plain || n.literal || ''), true);
            denied.forEach(d => push(`${notWords} ${d}`, true));
            return;
        }
        if (kids.length === 0) {
            const lit = String(n.plain || n.literal || '');
            if (lit && !/\d\s+is\s+(greater|less|equal)/.test(lit)) push(lit, n.type === 'success');
        } else kids.forEach(walk);
    };
    walk(why);
    return mergeAlternatives(out);
}

// consecutive reasons that differ only in their last word: said once
function mergeAlternatives(ls: { literal: string; ok: boolean }[]): { literal: string; ok: boolean }[] {
    const out: { literal: string; ok: boolean }[] = [];
    const or = ` ${kwPhrases(detectProgramLanguageSafe(), 'or')[0] || 'or'} `;
    let i = 0;
    while (i < ls.length) {
        const words = ls[i].literal.split(' ');
        const stem = words.slice(0, -1).join(' ');
        const tails = [words[words.length - 1]];
        let j = i + 1;
        while (j < ls.length && ls[j].ok === ls[i].ok && stem.length > 12) {
            const m = ls[j].literal.startsWith(stem + ' ') ? ls[j].literal.slice(stem.length + 1) : null;
            if (m === null || /\s/.test(m) && !/^[A-Z]/.test(m)) break;
            tails.push(m); j++;
        }
        if (tails.length > 1) out.push({ literal: `${stem} ${tails.slice(0, -1).join(', ')}${or}${tails[tails.length - 1]}`, ok: ls[i].ok });
        else out.push(ls[i]);
        i = j;
    }
    return out;
}

// Numbers as people read them. Floating point leaves noise in computed
// amounts (0.49650299999999997, 698.4000000000001): shown to twelve
// significant digits it goes away. A view that says "the numbers are shown
// with 2 decimals" gets exactly that (codes such as 6214.30 are written by
// the program as text and are not touched).
function tidyNumbers(text: string, decimals: number | null): string {
    // a value on its own (a heading, a table cell) is a number to format, whole
    // or not; inside a sentence only decimals are ("vehicle 1" stays)
    if (decimals !== null && decimals !== undefined && /^\s*-?\d+(?:\.\d+)?\s*$/.test(String(text))) {
        return Number(text).toFixed(decimals);
    }
    return String(text).replace(/(^|[^\w.\-\/])(-?\d+\.\d+)(?![\w.\-\/])/g, (m, pre, num) => {
        const x = Number(num);
        if (!isFinite(x)) return m;
        if (decimals !== null && decimals !== undefined) return pre + x.toFixed(decimals);
        const digits = num.replace(/^-/, '').replace('.', '').replace(/^0+/, '');
        if (digits.length < 13) return m;
        return pre + String(parseFloat(x.toPrecision(12)));
    });
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
    const decimals: number | null = typeof V.decimals === 'number' ? V.decimals : null;
    // answers and amounts in the view's format; reasons and citations (where
    // numbers are also a formula's constants) only without the float noise
    const num = (x: string) => tidyNumbers(x, decimals);
    const tidy = (x: string) => tidyNumbers(x, null);

    root.innerHTML = '';
    root.classList.add('lv');
    if (V.title && !ctx.titleShown) { const h = el('h2', '', V.title); h.style.cssText = 'margin:0 0 12px;font-size:20px;'; root.appendChild(h); }
    const status = el('div', 'lv-status');

    // --- the case: groups of facts, each a ScenarioForm ---------------------
    const groupDefs: { title: string | null; labels: string[]; judged: boolean }[] =
        (V.groups || []).map((g: any) => ({ title: g.title, labels: g.facts.map((f: any) => f.label), judged: g.judged }));
    // a fact as the view writes it, in the program's language (the label's
    // placeholders carry English articles)
    const wordsOf = new Map<string, string>();
    for (const g of V.groups || []) for (const f of g.facts) if (f.words) wordsOf.set(f.label, f.words);
    const grouped = new Set<string>(groupDefs.flatMap(g => g.labels));
    const allLabels = templateDefs.map(d => d.label);
    const otherLabels = allLabels.filter(l => !grouped.has(l) && templateDefs.find(d => d.label === l && (d.scenario_element || d.judged)));
    let caseProvenance = '';
    let caseName = '';
    const forms: { form: ScenarioForm; labels: string[]; box: HTMLElement; absent: HTMLElement; named: boolean }[] = [];
    let dirty = false;

    const factsCard = el('div', 'lv-card');
    // "policy 1 is a policy": what kind of thing each thing of the case is.
    // Kept in the case, shown in one line rather than as rows to edit.
    let typeFacts: string[] = [];
    const typeLine = el('div', 'lv-status lv-types');
    typeLine.title = t('What kind of thing each thing of the case is. They stay in the case as they are.');
    const TYPE_LABELS = ['*a thing* is a *type*', '*a thing* is an *type*'];
    const declaredLabels = templateDefs.map(d => d.label);
    const isTypeFact = (fact: string) => {
        const core = fact.split(/,\s*(?=(?:according|as stated|because|confer))/i)[0];
        return !!matchFact(core, TYPE_LABELS) && !matchFact(core, declaredLabels);
    };
    const showTypes = () => {
        typeLine.textContent = typeFacts.length ? `${t('Also stated')}: ${typeFacts.join(' · ')}` : '';
        typeLine.hidden = !typeFacts.length;
    };
    const casePicker = document.createElement('select');
    casePicker.style.cssText = 'width:100%;padding:5px;border-radius:8px;border:1px solid var(--lv-border);background:var(--lv-bg);color:var(--lv-ink);';
    casePicker.appendChild(new Option(t('New case'), ''));
    for (const n of scenarioNames) casePicker.appendChild(new Option(n, n));
    const factsHead = el('div', 'lv-h', t('The case'));
    factsHead.title = t(WIDGET_TIPS.facts);
    casePicker.title = t("One of the program's scenarios as the case, or a new case to fill in");
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
        sel.title = t('The kinds of fact this group can state');
        btn.title = t('Add a fact of the kind chosen');
        head.title = t('A group of facts, as the view names it');
        box.appendChild(rows); box.appendChild(absent); box.appendChild(add);
        const form = new ScenarioForm({
            source: ctx.source, rowsEl: rows, addSelect: sel, btnAdd: btn,
            extraTemplates: templateDefs, onlyTemplates: all ? undefined : labels,
            onChange: () => { dirty = true; caseChanged(); },
        });
        if (form.addableTemplates.length === 0) add.style.display = 'none';
        forms.push({ form, labels, box, absent, named: !all && title !== null || judged });
        return box;
    };
    for (const g of groupDefs) factsCard.appendChild(makeGroup(g.title, g.labels, g.judged, false));
    if (V.otherFacts !== false && otherLabels.length) factsCard.appendChild(makeGroup(groupDefs.length ? null : t('Facts'), otherLabels, false, groupDefs.length === 0));
    factsCard.appendChild(typeLine);

    // "every fact shows who states it": the `according to` of a fact's
    // trailers, as a badge on its row
    const agentOf = (trailers: string): string => {
        const kws = [...kwPhrases(programLang, 'according_to'), ...kwPhrases('en', 'according_to')].filter(Boolean);
        for (const part of trailers.split(/,(?=(?:[^"]*"[^"]*")*[^"]*$)/)) {
            const p = part.trim();
            const k = kws.find(k => p.toLowerCase().startsWith(k.toLowerCase() + ' '));
            if (k) return p.slice(k.length).trim();
        }
        return '';
    };
    const markSources = () => {
        if (!V.sources) return;
        for (const f of forms) f.box.querySelectorAll('.fact-row').forEach(row => {
            row.querySelector('.lv-who')?.remove();
            const cite = row.querySelector('.cite-field') as HTMLInputElement | null;
            const who = cite ? agentOf(cite.value) : '';
            if (!cite || !who) return;
            const badge = el('span', 'lv-who', who);
            badge.title = `${phrase('according_to')} ${who}`;
            row.insertBefore(badge, cite);
        });
    };

    // a group's templates the case does not state: shown, one click to state
    const showAbsent = () => {
        markSources();
        for (const f of forms) {
            f.absent.innerHTML = '';
            if (!f.named) continue;          // the other facts: offered by the Add menu only
            const present = new Set(f.form.factLines().map(l => { const m = matchFact(l.split(/,\s*(?=\S)/)[0], f.labels); return m ? m.label : ''; }));
            for (const label of f.labels) {
                if (present.has(label)) continue;
                const a = el('div', 'lv-absent', `${wordsOf.get(label) || label.replace(/\*/g, '')} — ${t('not stated')}`);
                a.title = t('The case does not state this fact: click to state it');
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
        typeFacts = [];
        for (const fact of facts) {
            if (isTestDirective(fact)) continue;     // "… expects answers …": a test, not a fact
            if (isTypeFact(fact)) { typeFacts.push(fact); continue; }
            let placed = false;
            for (let i = 0; i < forms.length && !placed; i++) {
                const m = matchFact(fact.split(/,\s*(?=(?:according|as stated|because|confer))/i)[0], forms[i].labels);
                if (m) { byForm[i].push(fact); placed = true; }
            }
            if (!placed && forms.length) byForm[forms.length - 1].push(fact);
        }
        forms.forEach((f, i) => { f.form.loadFacts(byForm[i]); f.form.provenance = caseProvenance; });
        dirty = false;
        showTypes();
        showAbsent();
    };

    const caseFactsText = (): string => {
        const lines: string[] = [];
        for (const l of typeFacts) lines.push(withDefaultProvenance(l, caseProvenance, ctx.source));
        for (const f of forms) for (const l of f.form.completeFactLines()) lines.push(withDefaultProvenance(l, caseProvenance, ctx.source));
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
    // the result itself: a failed one also says which conditions it did not meet
    const runRequest = (): any => ({ ...resultRequest(), whyNot: true });
    // a section as the view words it ("the section remedy reads …")
    const sectionWords = (name: string): string => {
        const w = (V.sections || []).find((x: any) => String(x.section) === String(name));
        return w ? String(w.text) : String(name);
    };
    const keep: string[] = V.keep || [];

    // widget containers
    const cards: Record<string, HTMLElement> = {};
    const card = (key: string, title: string) => {
        const c = el('div', 'lv-card'); c.dataset.widget = key;
        const h = el('div', 'lv-h'); h.appendChild(el('span', '', title)); h.appendChild(el('span', 'lv-tools')); c.appendChild(h);
        if (WIDGET_TIPS[key]) h.title = t(WIDGET_TIPS[key]);
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
            if (failed) b.appendChild(el('div', 'lv-sub', `${t('fails at')} ${sectionWords(failed.section)}`));
            else if (!(res.unmet || []).length && res.strongestReason) b.appendChild(el('div', 'lv-sub', res.strongestReason));
            return;
        }
        const FIRST = 5;
        results.forEach((r: any, i: number) => {
            const slots = answerSlots(queryText(R.query), r.answer);
            const head = R.headedBy ? slots[String(R.headedBy).split(/\s+/).pop()!.toLowerCase()] : null;
            const box = el('div', 'lv-answer');
            if (i >= FIRST) box.hidden = true;
            if (head) {
                const big = el('div', 'lv-big', num(head));
                if (R.unit) big.appendChild(el('span', 'lv-unit', R.unit));
                box.appendChild(big);
            }
            const conditional = r.unknowns && r.unknowns.length;
            const line = el('div', head ? 'lv-sub' : 'lv-big', num(r.answer));
            line.dataset.answer = r.answer;
            if (conditional && !head) line.classList.add('cond');
            box.appendChild(line);
            if (conditional) box.appendChild(el('div', 'lv-sub', `${t('provided that')}: ${r.unknowns.join('; ')}`));
            b.appendChild(box);
        });
        if (results.length > FIRST) {
            const more = el('button', 'lv-btn', `${t('Show all')} (${results.length})`);
            more.title = t('The result has more answers than are shown');
            more.addEventListener('click', () => { b.querySelectorAll('.lv-answer').forEach(x => (x as HTMLElement).hidden = false); more.remove(); });
            b.appendChild(more);
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
            row.appendChild(el('b', '', sectionWords(c.section)));
            row.title = c.status === 'passed' ? t('The case meets this section') : c.status === 'failed' ? t('The case stops here: this section is not met') : t('Not reached: an earlier section stopped the case');
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
        const steps = resultSteps(res);
        if (!steps.length) { b.appendChild(el('div', 'lv-status', t('No cited steps.'))); return; }
        const ol = el('ol');
        const FIRST = 10;
        steps.forEach((n, i) => {
            const li = el('li');
            if (i >= FIRST) li.hidden = true;
            li.appendChild(el('span', '', tidy(n.plain || n.literal)));
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
        copy.title = t('Copy to the clipboard');
        copy.addEventListener('click', () => navigator.clipboard?.writeText(
            steps.map((n, i) => `${i + 1}. ${n.plain || n.literal}\n   ${citationLine(n)}`).join('\n')).catch(() => { }));
        headOf('citations')?.appendChild(copy);
    };

    const questionFor = (literal: string) => (V.questions || []).find((q: any) => norm(q.instance) === norm(literal));

    // The conditions a failed result did not meet (le_why_not.pl): each with
    // whether the case is silent on it or states otherwise, the rule that asks
    // for it and its passage, and the facts that rule compared.
    const renderUnmet = (b: HTMLElement, unmet: any[]) => {
        const FIRST = 8;
        unmet.forEach((u, i) => {
            const box = el('div', 'lv-ck lv-unmet');
            if (i >= FIRST) box.hidden = true;
            box.appendChild(el('span', 'lv-fail', '✗'));
            const main = el('div');
            const q = questionFor(u.goal || u.literal);
            const line = el('span', '', q ? q.text : (u.plain || u.literal));
            main.appendChild(line);
            const kind = el('span', `lv-kind ${u.kind === 'not_stated' ? 'silent' : 'met'}`,
                u.kind === 'not_stated' ? t('not stated') : t('not met'));
            kind.title = u.kind === 'not_stated' ? t('The case says nothing about this') : t('The case states something else');
            main.appendChild(kind);
            if (u.provenance && (u.provenance.text || u.provenance.url)) main.appendChild(sourceButton(u));
            if (u.rule || u.provenance) main.appendChild(el('span', 'lv-cite', citationLine(u)));
            if ((u.facts || []).length) main.appendChild(el('span', 'lv-cite', `${t('given')}: ${u.facts.join('; ')}`));
            box.appendChild(main);
            b.appendChild(box);
        });
        if (unmet.length > FIRST) {
            const more = el('button', 'lv-btn', `${t('Show all')} (${unmet.length})`);
            more.addEventListener('click', () => { b.querySelectorAll('.lv-unmet').forEach(x => (x as HTMLElement).hidden = false); more.remove(); });
            b.appendChild(more);
        }
    };

    // the cited steps of a result — for a failed one, the rules whose
    // conditions it did not meet, each once
    const resultSteps = (res: any): any[] => {
        if ((res.results || []).length || !(res.unmet || []).length) return citedSteps(whyOf(res));
        const out: any[] = [], seen = new Set<string>();
        for (const u of res.unmet) {
            if (!u.provenance || !(u.provenance.document || u.provenance.url)) continue;
            const key = `${u.rule || ''}|${u.provenance.document || ''}|${u.provenance.quote || ''}`;
            if (seen.has(key)) continue;
            seen.add(key);
            out.push({ ...u, plain: `${u.kind === 'not_stated' ? t('not stated') : t('not met')}: ${u.literal}` });
        }
        return out;
    };

    const renderReasons = (res: any) => {
        const b = bodyOf('reasons'); if (!b) return;
        b.innerHTML = '';
        const head = cards.reasons?.querySelector('.lv-h > span');
        const unmet: any[] = (res.results || []).length ? [] : (res.unmet || []);
        if (head) head.textContent = unmet.length ? t('Why not') : t('Reasons');
        if (unmet.length) { renderUnmet(b, unmet); return; }
        const ls = leaves(whyOf(res)).slice(0, 14);
        for (const l of ls) {
            const q = questionFor(l.literal);
            const row = el('div', 'lv-ck');
            row.appendChild(el('span', l.ok ? 'lv-ok' : 'lv-fail', l.ok ? '✓' : '✗'));
            row.appendChild(el('span', '', q ? `${q.text} — ${l.ok ? t('yes') : t('no')}` : tidy(l.literal)));
            b.appendChild(row);
        }
        if (!ls.length) b.appendChild(el('div', 'lv-status', t('No reasons to show.')));
    };

    const renderDocuments = (res: any) => {
        const b = bodyOf('documents'); if (!b) return;
        b.innerHTML = '';
        const docs = new Map<string, { p: Provenance; quotes: string[]; locators: string[] }>();
        for (const n of resultSteps(res)) {
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
            const lineSpans = d.locators.map(l => locatorLines(l)).filter((x): x is [number, number] => !!x).map(ls => lineSpan(text, ls));
            const spans = [...d.quotes.map(q => findQuote(text, q)), ...lineSpans]
                .filter((x): x is [number, number] => !!x).sort((a, b) => a[0] - b[0]);
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
        go.title = t('Search for the fewest facts (up to three) to add or remove that would change the result');
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
            if (keep.length) req.keep = keep;
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
                if (cols.length) cols.forEach(c => tr.appendChild(el('td', '', num(sl[c] || '')))); else tr.appendChild(el('td', '', num(r.answer)));
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
            if (results.length) results.slice(0, 3).forEach(r => b.appendChild(el('div', 'lv-ok', R.whether && R.holds ? R.holds : num(r.answer))));
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
        go.title = t("Run every scenario of the program through the view's question and compare with what it expects");
        const progress = el('span', 'lv-status lv-progress');
        const out = el('div');
        b.appendChild(go); b.appendChild(progress); b.appendChild(out);
        // one run at a time; while it runs the button stops it (after the case
        // being answered: the next one is not asked)
        let running = false;
        let stop = false;
        const say = (key: string, i: number, n: number) =>
            t(key).replace('{i}', String(i)).replace('{n}', String(n));
        go.addEventListener('click', async () => {
            if (running) { stop = true; go.textContent = t('Stopping…'); (go as HTMLButtonElement).disabled = true; return; }
            running = true; stop = false;
            go.textContent = t('Stop running cases');
            cards.cases?.classList.add('lv-busy');
            out.innerHTML = '';
            const table = el('table');
            const hr = el('tr');
            [t('Case'), t('Result'), t('Expected'), ''].forEach(c => hr.appendChild(el('th', '', c)));
            table.appendChild(hr);
            out.appendChild(table);
            const total = scenarioNames.length;
            let done = 0;
            try {
                for (const sc of scenarioNames) {
                    if (stop) break;
                    progress.textContent = say('Running case {i} of {n}…', done + 1, total);
                    const req: any = { sessionModule: ctx.sessionModule, scenario: sc };
                    if (R.whether) req.customQuery = R.whether; else req.query = R.query;
                    const res = await leapi({ operation: 'answeringQuery', ...req });
                    const answers: string[] = (res.results || []).map((r: any) => String(r.answer));
                    const block = blocks.find(x => x.name === sc);
                    const expected = R.query ? expectedAnswers(block, R.query) : null;
                    const tr = el('tr');
                    const a = el('a', '', sc); a.setAttribute('href', '#'); a.addEventListener('click', (e) => { e.preventDefault(); casePicker.value = sc; loadCase(sc); run(); });
                    const td0 = el('td'); td0.appendChild(a); tr.appendChild(td0);
                    const failedAt = (res.checklist || []).find((c: any) => c.status === 'failed');
                    tr.appendChild(el('td', '', answers.length ? answers.map(num).join('; ')
                        : `${R.not || t('No answer')}${failedAt ? ` · ${t('fails at')} ${sectionWords(failedAt.section)}` : ''}`));
                    tr.appendChild(el('td', '', expected === null ? '—' : expected.length ? expected.map(num).join('; ') : (R.not || t('No answer'))));
                    const agree = expected === null ? '' : sameSet(answers, expected) ? '✓' : '✗';
                    tr.appendChild(el('td', agree === '✓' ? 'lv-ok' : agree === '✗' ? 'lv-fail' : '', agree));
                    table.appendChild(tr);
                    done++;
                }
            } finally {
                progress.textContent = done < total ? say('Stopped after {i} of {n} cases.', done, total)
                                                    : say('{n} cases run.', done, total);
                running = false;
                go.textContent = t('Run all cases');
                (go as HTMLButtonElement).disabled = false;
                cards.cases?.classList.remove('lv-busy');
            }
        });
    };

    const renderDraft = (res: any) => {
        const results: any[] = res.results || [];
        // the draft for a result that holds, or for one that does not
        const template = (results.length ? V.draftHolds : V.draftNot) || V.draft;
        const b = bodyOf('draft'); if (!b) return;
        b.innerHTML = ''; clearTools('draft');
        if (!template) return;
        const slots = results.length && R.query ? answerSlots(queryText(R.query), results[0].answer) : {};
        const head = R.headedBy ? slots[String(R.headedBy).split(/\s+/).pop()!.toLowerCase()] : null;
        // the lists a draft names: one item per line where the placeholder stands
        // on a line of its own, else joined in the sentence
        const lists: Record<string, string[]> = {
            // the legal basis: the passages a labelled rule or table row cites
            // (of a failed result: the passages it does not meet)
            'the citations': resultSteps(res).filter(n => n.rule || /^row /.test(String(n.literal)))
                .map(n => draftCitation(n)).filter((x, i, a) => x && a.indexOf(x) === i),
            'the facts': forms.flatMap(f => f.form.completeFactLines()),
            // every answer of the result, one per line
            'the answers': results.map((r: any) => num(String(r.answer))),
            // what a failed result did not meet, each with its passage
            'the reasons': (results.length ? [] : (res.unmet || [])).map((u: any) =>
                `${u.literal} (${u.kind === 'not_stated' ? t('not stated') : t('not met')})${draftCitation(u) ? ` — ${draftCitation(u)}` : ''}`),
            // of those, the facts the case is silent on: what to ask for
            'the missing': (results.length ? [] : (res.unmet || [])).filter((u: any) => u.kind === 'not_stated').map((u: any) => {
                // the values the rules would read there, when the fact has an open place
                const open = /\b(a|an)\s+\w+/.test(String(u.goal || '').replace(/^\S+\s/, ''));
                const vals: string[] = open ? (u.values || []).flat().slice(0, 10) : [];
                return `${u.goal || u.literal}${vals.length ? ` (${t('one of')}: ${vals.join(', ')})` : ''}${draftCitation(u) ? ` — ${draftCitation(u)}` : ''}`;
            }),
        };
        const fill: Record<string, string> = {
            'the result': num(head || (results[0]?.answer ?? (R.not || t('No answer')))),
            'the answer': num(results[0]?.answer ?? (R.not || t('No answer'))),
            'the case': caseName,
        };
        const text = String(template).replace(/\\n/g, '\n').split('\n').map(line => {
            const alone = /^\s*\{([^}]+)\}\s*$/.exec(line);
            if (alone && alone[1].trim() in lists) {
                const items = lists[alone[1].trim()];
                return items.length ? items.map(x => `- ${x}`).join('\n') : '- —';
            }
            return line.replace(/\{([^}]+)\}/g, (m, k) => {
                const key = k.trim();
                if (key in lists) return lists[key].join('; ');
                return key in fill ? fill[key] : m;
            });
        }).join('\n');
        b.appendChild(el('div', 'lv-draft', text));
        const copy = el('button', '', t('Copy'));
        copy.title = t('Copy to the clipboard');
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
                y.title = t('State this fact in the case');
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
                y.title = t('State this fact in the case');
                y.addEventListener('click', () => addFact(m.goal));
                box.appendChild(y);
            } else {
                const vals: string[] = (m.values || []).flat();
                for (const v of vals.slice(0, 10)) {
                    const c = el('span', 'lv-chip', v);
                    c.title = t('State the fact with this value (one the rules read)');
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
                s.title = t('State the fact, then fill in its value');
                s.addEventListener('click', () => addFact(m.goal));
                box.appendChild(s);
            }
            b.appendChild(box);
        }
    };

    // --- run ------------------------------------------------------------------
    // A change to the case marks the results out of date and lights the
    // Re-evaluate button; they are worked out again when it is pressed (or
    // Enter is pressed in a field), or at once with "automatically" ticked.
    // Answers that differ from the last evaluation are marked, and the ones
    // that went away are shown struck through.
    let runTimer: any = null;
    let stale = false;
    let autoEval = false;
    try { autoEval = localStorage.getItem('le-view-auto-eval') === '1'; } catch { /* no storage */ }
    let previousAnswers: string[] | null = null;
    const evalBar = el('div', 'lv-evalbar');
    const evalBtn = el('button', 'lv-btn', t('Re-evaluate')) as HTMLButtonElement;
    evalBtn.title = t('Work out the result again from the facts of the case as they are now');
    const autoBox = document.createElement('input'); autoBox.type = 'checkbox'; autoBox.checked = autoEval;
    const autoLabel = el('label'); autoLabel.appendChild(autoBox); autoLabel.appendChild(document.createTextNode(t('automatically')));
    autoLabel.title = t('Re-evaluate on every change, without pressing the button');
    evalBar.appendChild(status); evalBar.appendChild(evalBtn); evalBar.appendChild(autoLabel);
    // what the view flags (a decision that stops the case), and the facts of
    // the case no rule can read as written: above everything else
    const flagsBox = el('div', 'lv-flags');
    const warnBox = el('div', 'lv-warnings');
    const renderWarnings = (res: any) => {
        warnBox.innerHTML = '';
        const ws: any[] = res.valueWarnings || [];
        if (!ws.length) return;
        const h = el('div', 'lv-warn-h', t('Some facts of the case cannot be read by the rules as written: the result may be wrong.'));
        h.title = t('A value is written in a form the rules never read at that place (a number in quotes, a near miss of a value they read). Correct it and Re-evaluate.');
        warnBox.appendChild(h);
        for (const w of ws) {
            const row = el('div', 'lv-warn', `⚠ ${w.message} ${w.fix || ''}`);
            warnBox.appendChild(row);
        }
    };
    const renderFlags = async () => {
        flagsBox.innerHTML = '';
        for (const f of V.flags || []) {
            const req = resultRequest();
            delete req.query; delete req.customQuery;
            if (f.query) req.query = f.query; else req.customQuery = f.question;
            const res = await leapi({ operation: 'answeringQuery', ...req });
            const results: any[] = res.results || [];
            if (!results.length) continue;
            const banner = el('div', 'lv-flag');
            banner.appendChild(el('b', '', `⚑ ${f.label}`));
            banner.appendChild(el('span', 'lv-flag-why', results.map((r: any) => num(String(r.answer))).slice(0, 3).join('; ')));
            banner.title = `${t('The view flags the case when')}: ${f.question || queryText(f.query)}`;
            flagsBox.appendChild(banner);
        }
    };
    const setStale = (v: boolean) => {
        stale = v;
        evalBar.classList.toggle('stale', v);
        root.classList.toggle('lv-stale', v);
        evalBtn.classList.toggle('primary', v);
        if (v) status.textContent = t('The case has changed: the results below are those of the case before the change.');
    };
    const caseChanged = () => {
        setStale(true);
        if (autoEval) scheduleRun();
    };
    autoBox.addEventListener('change', () => {
        autoEval = autoBox.checked;
        try { localStorage.setItem('le-view-auto-eval', autoEval ? '1' : '0'); } catch { /* no storage */ }
        if (autoEval && stale) scheduleRun();
    });
    evalBtn.addEventListener('click', () => { if (runTimer) clearTimeout(runTimer); showAbsent(); run(); });
    factsCard.addEventListener('keydown', (e: KeyboardEvent) => {
        if (e.key === 'Enter' && (e.target as HTMLElement).tagName === 'INPUT') { e.preventDefault(); evalBtn.click(); }
    });
    const scheduleRun = () => { if (runTimer) clearTimeout(runTimer); runTimer = setTimeout(() => { showAbsent(); run(); }, 700); };
    const markChanges = (res: any) => {
        const now: string[] = (res.results || []).map((r: any) => String(r.answer));
        const b = bodyOf('result');
        if (b && previousAnswers) {
            const before = new Set(previousAnswers);
            const after = new Set(now);
            b.querySelectorAll('.lv-big, .lv-sub, .lv-res').forEach(x => {
                const txt = ((x as HTMLElement).dataset.answer || x.textContent || '').trim();
                if (now.includes(txt) && !before.has(txt)) {
                    x.classList.add('lv-changed');
                    (x as HTMLElement).title = t('Changed by the last evaluation');
                    setTimeout(() => x.classList.remove('lv-changed'), 4000);
                }
            });
            const gone = previousAnswers.filter(a => !after.has(a));
            if (gone.length && (now.length || previousAnswers.length)) {
                const was = el('div', 'lv-was', `${t('before the change')}: ${gone.slice(0, 5).map(num).join('; ')}`);
                was.title = t('What the result said before the case was changed');
                b.appendChild(was);
            }
        }
        previousAnswers = now;
    };
    const run = async () => {
        status.textContent = t('Evaluating…');
        evalBtn.disabled = true;
        root.classList.add('lv-busy');
        let res: any;
        try {
            res = await leapi({ operation: 'answeringQuery', ...runRequest() });
        } finally {
            evalBtn.disabled = false;
            root.classList.remove('lv-busy');
        }
        lastResult = res;
        setStale(false);
        status.textContent = res.error ? String(res.error)
            : `${t('Evaluated at')} ${new Date().toLocaleTimeString()}${caseName && !dirty ? ` — ${caseName}` : dirty ? ` — ${t('the case as edited')}` : ''}`;
        renderWarnings(res);
        renderResult(res);
        markChanges(res);
        renderStage(res);
        renderCitations(res);
        renderReasons(res);
        renderDocuments(res);
        renderDraft(res);
        renderWhatIf();
        if (cards.questions && V.missing) renderMissing();
        await renderFlags();
        renderTables();
    };

    // --- interview: one question at a time ----------------------------------------
    // The questions: the view's own (`the question for … is "…"`), then the
    // facts of its groups — a fact with an open value ("the nationality of
    // the child is a nationality") asked with a field for the value, one
    // without ("the child is adopted") asked yes / no. Only a question the
    // result can still depend on is asked (openQuestions: the facts the
    // closest failed routes lack, or touched).
    if (V.interview) {
        const box = el('div', 'lv-interview');
        root.appendChild(box);
        type Q = { instance: string; text: string; label: string; open: string | null; values: string[]; own?: boolean };
        // the values the rules read in one place of a template (not in its other places)
        const valuesOf = (label: string, place: number): string[] => {
            const d = templateDefs.find(x => x.label === label);
            const v = d && Array.isArray(d.values) ? d.values[place] : null;
            return Array.isArray(v) ? v.map(String) : [];
        };
        // the open value of an instance: an indefinite phrase where its label has a placeholder
        const openAt = (label: string, instance: string): { open: string; place: number } | null => {
            const m = matchFact(instance, [label]);
            if (!m) return null;
            const segs = label.match(/\*[^*]+\*/g) || [];
            for (let i = segs.length - 1; i >= 0; i--) {
                const v = String(m.values[i] || '').trim();
                if (/^(a|an)\s+\S/i.test(v) && v.toLowerCase() === segs[i].replace(/\*/g, '').toLowerCase()) return { open: v, place: i };
            }
            return null;
        };
        const qs: Q[] = [];
        for (const q of V.questions || []) {
            const said = String(q.words || q.instance);
            const at = openAt(q.label, said);
            qs.push({ instance: said, text: q.text, label: q.label, open: at ? at.open : null, values: at ? valuesOf(q.label, at.place) : [], own: true });
        }
        for (const g of V.groups || []) for (const f of g.facts || []) {
            // the fact as the view writes it: its definite phrases stay ("the
            // Father", a role of the case), its indefinite ones are the values
            // to ask for
            const said = String(f.words || f.instance);
            if (qs.some(q => norm(q.instance) === norm(said) || norm(q.instance) === norm(f.instance))) continue;
            const at = openAt(f.label, said);
            qs.push({ instance: said, text: at ? said : `${said}?`,
                      label: f.label, open: at ? at.open : null, values: at ? valuesOf(f.label, at.place) : [] });
        }
        type A = { kind: 'yes' | 'no' | 'unsure' | 'value'; value?: string };
        const answers = new Map<string, A>();
        const factOf = (q: Q, a: A): string | null => {
            if (a.kind === 'yes') return q.instance;
            if (a.kind !== 'value' || !q.open || !a.value) return null;
            let v = a.value.trim();
            // a value the rules read as text is written as text
            if (!/^".*"$/.test(v) && q.values.some(x => /^".*"$/.test(x) && x.slice(1, -1) === v)) v = `"${v}"`;
            const at = q.instance.toLowerCase().lastIndexOf(q.open.toLowerCase());
            return at < 0 ? null : q.instance.slice(0, at) + v + q.instance.slice(at + q.open.length);
        };
        const facts = () => qs.map(q => answers.has(q.instance) ? factOf(q, answers.get(q.instance)!) : null)
            .filter((x): x is string => !!x).map(x => `${x}.`).join('\n');
        const req = () => {
            const r: any = { sessionModule: ctx.sessionModule, customScenario: facts() };
            if (R.whether) r.customQuery = R.whether; else r.query = R.query;
            return r;
        };
        const answer = (q: Q, a: A) => { answers.set(q.instance, a); step(); };
        const step = async () => {
            box.innerHTML = '';
            box.appendChild(el('div', 'lv-status', t('Thinking…')));
            const oq = await leapi({ operation: 'openQuestions', ...req() });
            box.innerHTML = '';
            const touched = new Set<string>((oq.touched || []).map((x: any) => norm(x.literal)));
            const wanted = new Set<string>([...(oq.missing || []), ...(oq.touched || [])].map((x: any) => String(x.label)));
            const next = oq.holds ? null : qs.find(q => !answers.has(q.instance) && (touched.has(norm(q.instance)) || wanted.has(q.label)));
            if (next) {
                const counter = el('div', 'lv-status', `${t('Question')} ${answers.size + 1} ${t('of at most')} ${qs.length}`);
                counter.title = t('Only the questions the result can still depend on are asked');
                box.appendChild(counter);
                box.appendChild(el('div', 'lv-ask', next.text));
                if (next.open) {
                    const input = document.createElement('input');
                    input.className = 'lv-answer-field';
                    input.placeholder = next.open;
                    input.title = t('The value, as the rules read it');
                    if (/\bdate\b/i.test(next.open)) input.type = 'date';
                    else if (/\b(number|amount|count)\b/i.test(next.open)) input.type = 'number';
                    if (next.values.length) {
                        const dl = document.createElement('datalist');
                        dl.id = `lv-dl-${Math.random().toString(36).slice(2)}`;
                        for (const v of next.values) { const o = document.createElement('option'); o.value = v.replace(/^"(.*)"$/, '$1'); dl.appendChild(o); }
                        box.appendChild(dl);
                        input.setAttribute('list', dl.id);
                    }
                    box.appendChild(input);
                    const ok = el('button', 'lv-bigbtn', t('Next'));
                    ok.title = t('State this value in the case and go on');
                    ok.addEventListener('click', () => { if (input.value.trim()) answer(next, { kind: 'value', value: input.value }); else input.focus(); });
                    input.addEventListener('keydown', (e) => { if ((e as KeyboardEvent).key === 'Enter') ok.click(); });
                    box.appendChild(ok);
                    const skip = el('button', 'lv-bigbtn', t('Not known'));
                    skip.title = t('Leave this fact unstated');
                    skip.addEventListener('click', () => answer(next, { kind: 'unsure' }));
                    box.appendChild(skip);
                    setTimeout(() => input.focus(), 0);
                } else {
                    for (const [k, label] of [['yes', t('Yes')], ['no', t('No')], ['unsure', t('Not sure')]] as const) {
                        const bb = el('button', 'lv-bigbtn', label);
                        bb.addEventListener('click', () => answer(next, { kind: k }));
                        box.appendChild(bb);
                    }
                }
                if (answers.size) {
                    const back = el('button', 'lv-btn', `← ${t('Back')}`);
                    back.title = t('Take back the last answer');
                    back.addEventListener('click', () => { const keys = [...answers.keys()]; answers.delete(keys[keys.length - 1]); step(); });
                    box.appendChild(back);
                }
                return;
            }
            const res = await leapi({ operation: 'answeringQuery', ...req() });
            lastResult = res;
            const holds = (res.results || []).length > 0;
            box.appendChild(el('div', `lv-res ${holds ? 'yes' : 'no'}`, holds ? (R.holds || num(res.results[0].answer)) : (R.not || t('No'))));
            if (V.reasons) {
                box.appendChild(el('div', 'lv-grp', t('Why')));
                for (const q of qs) {
                    if (!answers.has(q.instance)) continue;
                    const a = answers.get(q.instance)!;
                    const row = el('div', 'lv-ck');
                    const ok = a.kind === 'yes' || a.kind === 'value';
                    row.appendChild(el('span', ok ? 'lv-ok' : a.kind === 'no' ? 'lv-fail' : 'lv-na', ok ? '✓' : a.kind === 'no' ? '✗' : '?'));
                    const said = a.kind === 'value' ? (factOf(q, a) || q.text)
                        : `${q.own || q.open ? q.text : q.instance} — ${a.kind === 'yes' ? t('yes') : a.kind === 'no' ? t('no') : t('not sure')}`;
                    row.appendChild(el('span', '', said));
                    box.appendChild(row);
                }
            }
            if (V.flip) {
                box.appendChild(el('div', 'lv-grp', V.flip.label || t('What would change this?')));
                const goal = holds ? (res.results[0].goal || res.results[0].answer) : (R.whether || queryText(R.query));
                const r2 = req(); delete r2.query; r2.customQuery = flipText(goal, holds);
                if (keep.length) r2.keep = keep;
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
    root.appendChild(evalBar);
    root.appendChild(flagsBox);
    root.appendChild(warnBox);
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

    casePicker.addEventListener('change', () => { previousAnswers = null; loadCase(casePicker.value); run(); });
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
