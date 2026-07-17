// Shared utilities for working with LE templates and scenario blocks, used by both
// the main editor (client.ts, to find/replace a scenario block) and the Scenario
// Editor window (scenario-editor.ts, to build form rows from templates and to load
// an existing scenario's facts back into rows).

import { detectProgramLanguage, kwPhrases, languageList } from './i18n';

// --- Multilingual keywords ---------------------------------------------------
// The block/section keywords ("scenario", "the templates are", "is", …) come
// from the shared i18n keyword tables — never hardcode them (a Spanish program
// says "escenario listas es:"). Parsing accepts the program's own language
// (detected from its opener statement) plus English; generation (writing a
// block back) uses the program's language only.

// Regex alternation of a keyword's phrases in the given languages, longest
// first, each phrase's spaces matching any whitespace run.
function kwAltFor(langs: string[], key: string): string {
    const phrases = new Set<string>();
    for (const l of langs) for (const p of kwPhrases(l, key)) if (p) phrases.add(p);
    return [...phrases]
        .sort((a, b) => b.length - a.length)
        .map(p => escapeRegex(p).replace(/\s+/g, '\\s+'))
        .join('|');
}

// Program language + English fallback.
function kwAlt(source: string, key: string): string {
    return kwAltFor([detectProgramLanguage(source), 'en'], key);
}

// Every registered language — for recognisers that have no program text at
// hand (or must survive a source whose opener is still being typed).
function kwAltAll(key: string): string {
    return kwAltFor(languageList().map(l => l.code), key);
}

// A scenario "test" line in any language: "<query> expects answers [...]".
let testDirectiveReCache: RegExp | null = null;
export function testDirectiveRe(): RegExp {
    if (!testDirectiveReCache) {
        testDirectiveReCache = new RegExp(
            `(?:^|\\s)(?:${kwAltAll('expects')})\\s+(?:${kwAltAll('answers')})(?!\\p{L})`, 'iu');
    }
    return testDirectiveReCache;
}

// The "it is unknown whether " prefix of an assumable scenario fact, in any
// language (LE also accepts the "assumed"/"assumable" synonyms).
let unknownPrefixReCache: RegExp | null = null;
export function unknownPrefixRe(): RegExp {
    if (!unknownPrefixReCache) {
        unknownPrefixReCache = new RegExp(
            `^(?:${kwAltAll('it_is')})\\s+(?:${kwAltAll('unknown')})\\s+(?:${kwAltAll('whether')})\\s+`, 'iu');
    }
    return unknownPrefixReCache;
}

// The header line for writing a "<scenario|query> <name> is:" block back into
// the program, in the program's own language.
export function blockHeader(source: string, key: 'scenario' | 'query', name: string): string {
    const lang = detectProgramLanguage(source);
    const kw = kwPhrases(lang, key)[0] || key;
    const is = kwPhrases(lang, 'marker_is')[0] || 'is';
    return `${kw} ${name} ${is}:`;
}

// The "it is unknown whether " prefix for writing an assumed fact back, in the
// program's own language. kwPhrases sorts synonyms longest-first, which for
// the 'unknown' key would pick English "assumable"; the canonical English word
// is "unknown", so prefer it when present.
export function unknownWhetherPrefix(source: string): string {
    const lang = detectProgramLanguage(source);
    const first = (key: string, fallback: string) => kwPhrases(lang, key)[0] || fallback;
    const unknowns = kwPhrases(lang, 'unknown');
    const unknown = unknowns.includes('unknown') ? 'unknown' : (unknowns[0] || 'unknown');
    return `${first('it_is', 'it is')} ${unknown} ${first('whether', 'whether')} `;
}

// Header regex for a "<scenario|query> <name> <is>:" block in the program's
// own language (plus English).
function blockHeaderRe(source: string, key: 'scenario' | 'query'): RegExp {
    return new RegExp(
        `^(?:${kwAlt(source, key)})\\s+(.+?)\\s+(?:${kwAlt(source, 'marker_is')})\\s*:`, 'i');
}

export interface TemplateSegment {
    kind: 'literal' | 'field';
    // For a literal: the literal words. For a field: the placeholder name (e.g.
    // "a person"), shown as the field's hint text.
    text: string;
}

// Split a template label ("*a person* is born in *a place* on *a date*") into an
// ordered list of literal/field segments.
export function splitTemplate(label: string): TemplateSegment[] {
    const segs: TemplateSegment[] = [];
    const re = /\*([^*]+)\*/g;
    let last = 0;
    let m: RegExpExecArray | null;
    while ((m = re.exec(label)) !== null) {
        const lit = label.slice(last, m.index).trim();
        if (lit) segs.push({ kind: 'literal', text: lit });
        segs.push({ kind: 'field', text: m[1].trim() });
        last = m.index + m[0].length;
    }
    const tail = label.slice(last).trim();
    if (tail) segs.push({ kind: 'literal', text: tail });
    return segs;
}

export interface TemplateDef {
    label: string;        // the template WITH its *...* markers
    // True when declared "; undefined" (or "; scenario element"): a scenario element
    // whose facts only ever appear in scenarios.
    isUndefined: boolean;
}

// Parse the program's template definitions (WITH their *...* placeholder markers)
// from the "the templates/predicates/fluents/events are:" sections of LE source.
// The backend metadata strips the markers, so we read them from source instead —
// they are what tells us which words are editable fields. A ';'-annotation suffix
// ("; assumable", "; undefined", "; opposite: <template>") is stripped from the
// label but inspected for the "undefined"/"scenario element" marker; an "opposite:"
// form is registered as its own template.
export function parseTemplateDefs(source: string): TemplateDef[] {
    const defs: TemplateDef[] = [];
    // A section header ends the templates section (the 'guard' keyword row lists
    // each language's section-opening phrases). "scenario"/"query" take NO "the"
    // (e.g. "scenario alice is:"), unlike the others — getting this wrong lets the
    // parser read scenario facts as (no-variable) templates. `(?=[\s:]|$)` rather
    // than \b: several non-English phrases end in accented letters ("a ontologia
    // é"), which JS's ASCII-only \b would refuse to bound.
    const sectionHeader = new RegExp(`^(?:${kwAlt(source, 'guard')})(?=[\\s:]|$)`, 'im');
    const templateHeader = new RegExp(
        `(?:${['predicates', 'templates', 'fluents', 'events'].map(k => kwAlt(source, k)).join('|')})\\s*:`, 'gi');
    const undefinedMarker = new RegExp(`(?:^|\\s)(?:${kwAlt(source, 'undefined')})(?!\\p{L})`, 'iu');
    const oppositeMarker = new RegExp(`(?:${kwAlt(source, 'opposite')})\\s*:\\s*([^;]+)`, 'iu');
    const synonymMarker = new RegExp(`(?:^|\\s)(?:${kwAlt(source, 'synonym')})\\s+([^;]+)`, 'giu');
    let m: RegExpExecArray | null;
    while ((m = templateHeader.exec(source)) !== null) {
        const remaining = source.substring(m.index + m[0].length);
        const next = remaining.match(sectionHeader);
        const sectionText = next ? remaining.substring(0, next.index) : remaining;
        for (const line of sectionText.split('\n')) {
            const t = line.trim();
            if (!t || t.startsWith('%')) continue;
            const semi = t.indexOf(';');
            const annotation = semi >= 0 ? t.slice(semi + 1) : '';
            const isUndefined = undefinedMarker.test(annotation);
            // Include no-variable ("propositional") templates too — they have no
            // *...* fields but are real templates. Recognising them lets a fact/query
            // that IS one match it exactly (a zero-field row) instead of being
            // mis-matched to a looser variable template that splits it on a preposition.
            const main = (semi >= 0 ? t.slice(0, semi) : t).replace(/[.,]\s*$/, '').trim();
            if (main) defs.push({ label: main, isUndefined });
            const opp = annotation.match(oppositeMarker);
            if (opp) {
                const o = opp[1].replace(/[.,;]\s*$/, '').trim();
                if (o) defs.push({ label: o, isUndefined });
            }
            // Each "; synonym <template>" registers an equivalent surface form so
            // scenario facts written either way are recognised as the same template.
            for (const sm of annotation.matchAll(synonymMarker)) {
                const s = sm[1].replace(/[.,;]\s*$/, '').trim();
                if (s) defs.push({ label: s, isUndefined });
            }
        }
    }
    return defs;
}

// Just the template labels (for matching fact text).
export function parseTemplates(source: string): string[] {
    return parseTemplateDefs(source).map(d => d.label);
}

function escapeRegex(s: string): string {
    return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// A full-match regex for a template; each capture group is one field value. The
// literals anchor the (non-greedy) field captures, and ^...$ bound the whole fact,
// so "John is born in the UK on 2021-10-09" yields ["John","the UK","2021-10-09"].
function templateRegex(label: string): RegExp | null {
    const segs = splitTemplate(label);
    if (!segs.some(s => s.kind === 'field') ) return null;
    const pieces = segs.map(s => {
        if (s.kind === 'field') return '(.+?)';
        // Word-boundary the literal so a literal word ("is", "for") matches a WHOLE
        // word, not a substring inside a field value ("th-is", "terror-is-m"). \b is
        // anchored to the first/last word character of the literal.
        // A literal comma must match a GRAMMATICAL comma, never a thousands
        // separator: in "is 10,000,000, in the aggregate" the template's comma
        // must take the LAST comma (followed by a space), not the number's
        // (followed by a digit) — otherwise the lazy fields split the number
        // (amount "10", qualifier "000,000, in the aggregate").
        const lit = escapeRegex(s.text).replace(/\s+/g, '\\s+').replace(/,/g, ',(?!\\d)');
        const lb = /^\w/.test(s.text) ? '\\b' : '';
        const rb = /\w$/.test(s.text) ? '\\b' : '';
        return lb + lit + rb;
    });
    try {
        return new RegExp('^\\s*' + pieces.join('\\s*') + '\\s*$', 'i');
    } catch {
        return null;
    }
}

function literalLength(label: string): number {
    return splitTemplate(label)
        .filter(s => s.kind === 'literal')
        .reduce((n, s) => n + s.text.length, 0);
}

export interface FactMatch {
    label: string;
    values: string[];
}

// Best-effort match of a fact string to one of the templates, returning the field
// values. The MOST SPECIFIC template (most literal characters) wins, so a user
// template ("*a creature* is a dragon") beats a looser one. Returns null when no
// template matches — the caller then keeps the fact as free text. Final validation
// always happens on the Prolog side.
export function matchFact(fact: string, templates: string[]): FactMatch | null {
    const f = fact.trim().replace(/\.\s*$/, '');
    const norm = (s: string) => s.replace(/\s+/g, ' ').trim().toLowerCase();
    const fNorm = norm(f);
    // Most specific (most literal characters) first, so a no-variable template — all
    // literal, hence the longest — is tried before any looser variable template that
    // might otherwise split it on a preposition.
    const sorted = [...templates].sort((a, b) => literalLength(b) - literalLength(a));
    for (const label of sorted) {
        const segs = splitTemplate(label);
        if (!segs.some(s => s.kind === 'field')) {
            // A no-variable template: it matches only a fact equal to its literal
            // (whitespace/case-insensitive), yielding a zero-field row.
            const lit = segs.map(s => s.text).join(' ');
            if (norm(lit) === fNorm) return { label, values: [] };
            continue;
        }
        const re = templateRegex(label);
        if (!re) continue;
        const m = re.exec(f);
        if (m) return { label, values: m.slice(1).map(v => (v || '').trim()) };
    }
    return null;
}

// Instantiate a template with field values, producing the fact text (no trailing
// period). Empty fields are left blank (the Prolog side flags the resulting error).
export function fillTemplate(label: string, values: string[]): string {
    const segs = splitTemplate(label);
    let fi = 0;
    const out = segs
        .map(s => (s.kind === 'field' ? (values[fi++] ?? '') : s.text))
        .join(' ');
    // Attach grammatical commas to the preceding word ("10,000,000, in the
    // aggregate", not "10,000,000 , in the aggregate").
    return out.replace(/\s+/g, ' ').replace(/\s+,/g, ',').trim();
}

export interface ScenarioBlock {
    name: string;
    start: number;   // char offset of the "scenario ..." header
    end: number;     // char offset just past the block's last non-blank line
    facts: string[]; // each fact's text, without its trailing period
}

interface RawBlock {
    name: string;
    start: number;
    end: number;
    bodyLines: string[];
}

// Scan "<keyword> <name> is:" blocks (e.g. "scenario ..." or "query ...") from LE
// source. A block's body is the run of indented (or blank) lines following the
// header, up to the next non-indented line. Shared by parseScenarioBlocks and
// parseQueryBlocks so both delimit blocks identically.
function scanBlocks(source: string, headerRe: RegExp): RawBlock[] {
    const blocks: RawBlock[] = [];
    const lines = source.split('\n');
    const offsets: number[] = [];
    let off = 0;
    for (const ln of lines) { offsets.push(off); off += ln.length + 1; }

    for (let i = 0; i < lines.length; i++) {
        const m = lines[i].match(headerRe);
        if (!m) continue;
        const name = m[1].trim();
        const start = offsets[i];
        const bodyLines: string[] = [];
        let j = i + 1;
        let lastContent = i;
        while (j < lines.length) {
            const ln = lines[j];
            const t = ln.trim();
            // A "%" comment is part of the block regardless of its indentation (LE
            // comments may sit at column 0); only a non-indented, non-comment,
            // non-blank line begins the next section and ends the block.
            if (t === '') { bodyLines.push(ln); j++; continue; }
            if (t.startsWith('%')) { bodyLines.push(ln); lastContent = j; j++; continue; }
            if (/^\s/.test(ln)) { bodyLines.push(ln); lastContent = j; j++; continue; }
            break;
        }
        const end = offsets[lastContent] + lines[lastContent].length;
        blocks.push({ name, start, end, bodyLines });
    }
    return blocks;
}

// Parse all "scenario <name> is:" blocks from LE source (in the program's own
// language — "escenario listas es:" works too). Facts are the body's
// "."-terminated statements (a fact may span lines).
export function parseScenarioBlocks(source: string): ScenarioBlock[] {
    return scanBlocks(source, blockHeaderRe(source, 'scenario'))
        .map(b => ({ name: b.name, start: b.start, end: b.end, facts: splitFacts(b.bodyLines) }));
}

export interface QueryBlock {
    name: string;
    start: number;      // char offset of the "query ..." header
    end: number;        // char offset just past the block's last non-blank line
    body: string;       // the query body statement, comments stripped, no trailing period
    bodyLines: string[]; // the body's lines, comments stripped, LEADING indentation kept
                         // (so and/or scoping can be recovered), blank lines removed
}

// Parse all "query <name> is:" blocks from LE source. A query's body is a single
// statement (conditions joined by and/or). `body` is the whole thing on one line;
// `bodyLines` keeps each line with its indentation so the Query Editor can recover
// the and/or scoping the indentation expresses.
export function parseQueryBlocks(source: string): QueryBlock[] {
    return scanBlocks(source, blockHeaderRe(source, 'query')).map(b => {
        const bodyLines = b.bodyLines
            .map(l => stripInlineComment(l).replace(/\s+$/, ''))   // keep leading indent, drop trailing
            .filter(l => l.trim() !== '');
        const body = bodyLines.map(l => l.trim()).join(' ').replace(/\.\s*$/, '').trim();
        return { name: b.name, start: b.start, end: b.end, body, bodyLines };
    });
}

// Drop a Logical English line comment (`%` to end of line). A `%` inside a
// double-quoted string is literal, not a comment. Single quotes are NOT tracked,
// since apostrophes ("John's") are common in plain text.
function stripInlineComment(line: string): string {
    let inStr = false;
    for (let i = 0; i < line.length; i++) {
        const c = line[i];
        if (c === '"') inStr = !inStr;
        else if (c === '%' && !inStr) return line.slice(0, i);
    }
    return line;
}

function splitFacts(bodyLines: string[]): string[] {
    const facts: string[] = [];
    let cur = '';
    for (const raw of bodyLines) {
        // Strip any trailing "% comment" first — a full-line comment then becomes
        // empty, and an inline comment no longer leaks into the last field.
        const t = stripInlineComment(raw).trim();
        if (t === '') continue;
        cur = cur ? cur + ' ' + t : t;
        if (t.endsWith('.')) {
            facts.push(cur.replace(/\.\s*$/, '').trim());
            cur = '';
        }
    }
    if (cur.trim()) facts.push(cur.replace(/\.\s*$/, '').trim());
    return facts;
}
