// Query Editor window. Same look and feel as the Scenario Editor, but builds a
// "query <name> is:" block from template instances joined by the basic connectives
// (and / or) with optional "it is not the case that" negation. It deliberately does
// NOT support the full LE body-condition syntax (nested groups, aggregates, etc.) —
// it stays a simple, flat list of conditions. Results are sent back to the editor or
// the clipboard; the final LE syntax check happens on the Prolog side on reload.

import { parseTemplateDefs, parseQueryBlocks, QueryBlock, splitTemplate, matchFact } from './le-templates';
import { t, applyI18nDom, installLeApiLang } from './i18n';
import { openNlInput } from './nl-input';

// Sentinel value for the "Write it in English…" entry in the Add picker.
const WRITE_IN_ENGLISH = '__write_in_english__';

interface QueryEditorData { source?: string; }

// The editor listens on this channel and applies inserts to the Monaco document.
const CHANNEL = 'le-query-editor';

// The LE phrase for negation-as-failure that wraps a single condition.
const NEG_PREFIX = /^it is not the case that\s+/i;

type Connective = 'and' | 'or';

interface QRow {
    templateLabel: string | null;   // null => a free-text condition
    values: string[];               // field values for the template placeholders
    raw: string;                    // the text when templateLabel === null
    negated: boolean;               // "it is not the case that <condition>"
    connective: Connective;         // how this row joins to the PREVIOUS one (row 0: ignored)
    indent: number;                 // indentation level — expresses and/or scoping in LE
}

export function initQueryEditor(data: QueryEditorData) {
    const source = data.source || '';
    const templates = parseTemplateDefs(source).map(d => d.label);
    // Offer every declared template in the Add picker (a query may ask about any of
    // them — conclusions and scenario elements alike), de-duplicated, longest first
    // so the more specific ones are easy to find.
    const addable = [...new Set(templates)];
    const blocks: QueryBlock[] = parseQueryBlocks(source);
    const blockByName = new Map<string, QueryBlock>();
    blocks.forEach(b => blockByName.set(b.name, b));

    const channel = new BroadcastChannel(CHANNEL);

    const $ = (id: string) => document.getElementById(id)!;
    const picker = $('query-picker') as HTMLSelectElement;
    const nameInput = $('query-name') as HTMLInputElement;
    const rowsEl = $('rows');
    const addSelect = $('add-template') as HTMLSelectElement;
    const statusEl = $('status');

    let loadedName = '';    // the existing query currently loaded (for replace), '' for New
    let dirty = false;      // edited since the last Copy / Insert (drives the close warning)
    let rows: QRow[] = [];

    const setStatus = (text: string) => { statusEl.textContent = text; };
    const markDirty = () => { dirty = true; setStatus(t('Unsaved changes')); };

    // --- Template Add picker ---------------------------------------------------
    addSelect.innerHTML = '';
    for (const label of addable) {
        const o = document.createElement('option');
        o.value = label;
        o.textContent = label.replace(/\*/g, '');   // show placeholders without the markers
        addSelect.appendChild(o);
    }
    const nlOpt = document.createElement('option');
    nlOpt.value = WRITE_IN_ENGLISH;
    nlOpt.textContent = t('Write it in English');
    addSelect.appendChild(nlOpt);

    ($('btn-add') as HTMLButtonElement).addEventListener('click', () => {
        const val = addSelect.value;
        if (!val) return;
        if (val === WRITE_IN_ENGLISH) { writeInEnglish(); return; }
        // A new condition continues at the indentation of the one above it.
        const indent = rows.length ? rows[rows.length - 1].indent : 0;
        rows.push({ templateLabel: val, values: [], raw: '', negated: false, connective: 'and', indent });
        markDirty();
        render();
        (rowsEl.lastElementChild?.querySelector('input.field, input.raw') as HTMLInputElement | null)?.focus();
    });

    // Open the NL modal and APPEND the generated conditions to the query being built.
    function writeInEnglish() {
        openNlInput({
            kind: 'query',
            source,
            title: 'Add conditions — write it in English',
            instruction: 'Type one or more sentences describing the query to build (a question, and its conditions). '
                + 'The query must respect the predicates (templates) already in your program; if you need to expand '
                + 'these first, use the editor or the LE Assistant.',
            placeholder: 'e.g. which person is happy and is not the brother of Bob',
            onResult: (leText) => {
                const lines = leText.split(/\r?\n/).filter(l => l.trim() !== '');
                const added = parseBody(lines);
                rows.push(...added);
                normalizeIndents();
                markDirty();
                render();
                setStatus(`Added ${added.length} condition${added.length === 1 ? '' : 's'} from English`);
            },
        });
    }

    // --- Query picker ----------------------------------------------------------
    picker.innerHTML = '';
    const newOpt = document.createElement('option');
    newOpt.value = '__new__';
    newOpt.textContent = t('New…');
    picker.appendChild(newOpt);
    blocks.forEach(b => {
        const o = document.createElement('option');
        o.value = b.name;
        o.textContent = b.name;
        picker.appendChild(o);
    });

    // --- Indentation (and/or scoping) ------------------------------------------
    // Width of a line's leading whitespace, tabs counted as 4 columns.
    function leadWidth(s: string): number {
        let w = 0;
        for (const ch of s) { if (ch === ' ') w++; else if (ch === '\t') w += 4; else break; }
        return w;
    }
    // Keep the indent levels well-formed: row 0 at level 0, and no row deeper than one
    // level below the row above it (so the outline never skips a level).
    function normalizeIndents() {
        let prev = -1;
        for (const r of rows) { r.indent = Math.max(0, Math.min(r.indent, prev + 1)); prev = r.indent; }
    }

    // --- Parsing an existing query body into rows ------------------------------
    // Best-effort. Group the body's lines into conditions (a new condition begins on
    // the first line or on a line starting with a connective; other lines continue the
    // current condition), read the connective and the indentation level of each, and
    // match each to a template. If EVERY condition matches, use those structured rows;
    // otherwise keep the whole body as ONE free-text row so a complex query (or a value
    // containing "and"/"or") is never mangled — the user can still edit it.
    function parseBody(bodyLines: string[]): QRow[] {
        if (bodyLines.length === 0) return [];
        interface Cond { width: number; connective: Connective; text: string; }
        const conds: Cond[] = [];
        for (const raw of bodyLines) {
            const trimmed = raw.trim();
            const cm = trimmed.match(/^(and|or)\b\s*/i);
            if (conds.length === 0) {
                conds.push({ width: leadWidth(raw), connective: 'and', text: trimmed });
            } else if (cm) {
                conds.push({ width: leadWidth(raw), connective: cm[1].toLowerCase() as Connective, text: trimmed.slice(cm[0].length) });
            } else {
                conds[conds.length - 1].text += ' ' + trimmed;   // continuation
            }
        }
        conds[conds.length - 1].text = conds[conds.length - 1].text.replace(/\.\s*$/, '').trim();
        // Map the distinct indentation widths to levels 0,1,2,…
        const widths = [...new Set(conds.map(c => c.width))].sort((a, b) => a - b);
        const wholeBody = bodyLines.map(l => l.trim()).join(' ').replace(/\.\s*$/, '').trim();
        const parsed: QRow[] = [];
        for (const c of conds) {
            const negated = NEG_PREFIX.test(c.text);
            const inner = negated ? c.text.replace(NEG_PREFIX, '').trim() : c.text.trim();
            const m = matchFact(inner, templates);
            if (!m) return [{ templateLabel: null, values: [], raw: wholeBody, negated: false, connective: 'and', indent: 0 }];
            parsed.push({ templateLabel: m.label, values: m.values, raw: '', negated, connective: c.connective, indent: widths.indexOf(c.width) });
        }
        return parsed;
    }

    function loadQuery(name: string) {
        const block = blockByName.get(name);
        loadedName = block ? block.name : '';
        nameInput.value = block ? block.name : '';
        rows = block ? parseBody(block.bodyLines) : [];
        normalizeIndents();
        dirty = false;
        render();
        setStatus(block ? `Loaded query "${name}"` : '');
    }
    function newQuery() {
        loadedName = '';
        nameInput.value = '';
        rows = [];
        dirty = false;
        render();
        setStatus(t('New query'));
    }

    // --- Rendering -------------------------------------------------------------
    function sizeField(input: HTMLInputElement) {
        const n = Math.max((input.value || input.placeholder).length + 1, 6);
        input.size = Math.min(n, 80);
    }

    function render() {
        rowsEl.innerHTML = '';
        if (rows.length === 0) {
            const hint = document.createElement('div');
            hint.className = 'empty-hint';
            hint.textContent = t('No conditions yet — pick a template below and click “Add”.');
            rowsEl.appendChild(hint);
            return;
        }
        rows.forEach((row, idx) => rowsEl.appendChild(renderRow(row, idx)));
    }

    function indentRow(idx: number, delta: number) {
        rows[idx].indent = Math.max(0, rows[idx].indent + delta);
        normalizeIndents();
        markDirty();
        render();
    }

    function renderRow(row: QRow, idx: number): HTMLElement {
        const el = document.createElement('div');
        el.className = 'fact-row';
        if (row.negated) el.classList.add('negated');
        // Visual feedback for the and/or scoping: shift the row right by its level.
        el.style.marginLeft = `${row.indent * 28}px`;
        if (row.indent > 0) el.classList.add('indented');

        // Indent / unindent controls (immediate). Can only go one level deeper than
        // the row above, and not below level 0.
        const maxIndent = idx > 0 ? rows[idx - 1].indent + 1 : 0;
        const indentTools = document.createElement('div');
        indentTools.className = 'indent-tools';
        const outdent = document.createElement('button');
        outdent.className = 'indent-btn';
        outdent.textContent = t('⇤');
        outdent.title = t('Unindent (widen this condition’s scope)');
        outdent.disabled = row.indent === 0;
        outdent.addEventListener('click', () => indentRow(idx, -1));
        const indent = document.createElement('button');
        indent.className = 'indent-btn';
        indent.textContent = t('⇥');
        indent.title = t('Indent (nest this condition to bind tighter)');
        indent.disabled = row.indent >= maxIndent;
        indent.addEventListener('click', () => indentRow(idx, +1));
        indentTools.appendChild(outdent);
        indentTools.appendChild(indent);
        el.appendChild(indentTools);

        // Connective linking this row to the previous one (not on the first row).
        if (idx > 0) {
            const conn = document.createElement('select');
            conn.className = 'connective';
            for (const c of ['and', 'or'] as Connective[]) {
                const o = document.createElement('option');
                o.value = c; o.textContent = c;
                conn.appendChild(o);
            }
            conn.value = row.connective;
            conn.addEventListener('change', () => { row.connective = conn.value as Connective; markDirty(); });
            el.appendChild(conn);
        } else {
            const spacer = document.createElement('span');
            spacer.className = 'connective-spacer';
            el.appendChild(spacer);
        }

        // "it is not the case that" — a leading negation phrase, shown when checked.
        if (row.negated) {
            const neg = document.createElement('span');
            neg.className = 'neg-phrase';
            neg.textContent = t('it is not the case that');
            el.appendChild(neg);
        }

        if (row.templateLabel === null) {
            const input = document.createElement('input');
            input.type = 'text';
            input.className = 'raw';
            input.value = row.raw;
            input.placeholder = t('condition');
            input.size = Math.min(Math.max(row.raw.length + 1, 20), 80);
            input.addEventListener('input', () => { row.raw = input.value; input.size = Math.min(Math.max(input.value.length + 1, 20), 80); markDirty(); });
            el.appendChild(input);
        } else {
            const segs = splitTemplate(row.templateLabel);
            let fieldIdx = 0;
            for (const seg of segs) {
                if (seg.kind === 'literal') {
                    const span = document.createElement('span');
                    span.className = 'word';
                    span.textContent = seg.text;
                    el.appendChild(span);
                } else {
                    const fi = fieldIdx++;
                    const input = document.createElement('input');
                    input.type = 'text';
                    input.className = 'field';
                    input.placeholder = seg.text;      // hint = the LE variable (e.g. "a person")
                    input.title = `${seg.text} — a value, or a query variable like "which ${seg.text.replace(/^(a|an|the)\s+/i, '')}"`;
                    input.value = row.values[fi] ?? '';
                    sizeField(input);
                    input.addEventListener('input', () => { row.values[fi] = input.value; sizeField(input); markDirty(); });
                    el.appendChild(input);
                }
            }
        }

        const tools = document.createElement('div');
        tools.className = 'row-tools';

        // "not" — wrap this condition in "it is not the case that …".
        const negLabel = document.createElement('label');
        negLabel.className = 'negate';
        negLabel.title = t('Wrap this condition in "it is not the case that …"');
        const check = document.createElement('input');
        check.type = 'checkbox';
        check.checked = row.negated;
        check.addEventListener('change', () => { row.negated = check.checked; markDirty(); render(); });
        negLabel.appendChild(check);
        negLabel.appendChild(document.createTextNode(' not'));
        tools.appendChild(negLabel);

        const del = document.createElement('button');
        del.textContent = t('✕');
        del.title = t('Delete condition');
        del.addEventListener('click', () => { rows.splice(idx, 1); markDirty(); render(); });
        tools.appendChild(del);

        el.appendChild(tools);
        return el;
    }

    // --- Producing text --------------------------------------------------------
    // Fill a template, but for any field the user left empty fall back to its
    // placeholder — the LE variable name (e.g. "a person"). An untouched template
    // then reads as a valid query ("a person is the father of a person") rather than
    // collapsing to just its literals ("is the father of").
    function condBase(row: QRow): string {
        if (row.templateLabel === null) return row.raw.trim().replace(/\.\s*$/, '').trim();
        const segs = splitTemplate(row.templateLabel);
        let fi = 0;
        const out = segs.map(s => {
            if (s.kind === 'literal') return s.text;
            const v = (row.values[fi++] ?? '').trim();
            return v || s.text;
        }).join(' ');
        return out.replace(/\s+/g, ' ').trim();
    }
    function condText(row: QRow): string {
        const base = condBase(row);
        if (!base) return '';
        return row.negated ? `it is not the case that ${base}` : base;
    }
    // The body lines: each non-empty condition, indented per its level (4 spaces base
    // + 4 per level) and prefixed by its connective (except the first). The trailing
    // period terminates the whole statement.
    function bodyLines(): string[] {
        const out: string[] = [];
        rows.forEach((row) => {
            const c = condText(row);
            if (!c) return;
            const conn = out.length === 0 ? '' : `${row.connective} `;
            out.push(`${' '.repeat(4 + row.indent * 4)}${conn}${c}`);
        });
        return out;
    }
    function blockText(name: string): string {
        const lines = bodyLines();
        const body = lines.length ? lines.join('\n') : '    ';
        return `query ${name} is:\n${body}.`;
    }

    // Returns the trimmed name, or null (with an alert) when it is missing/invalid.
    function requireName(): string | null {
        const name = nameInput.value.trim();
        if (!name) { alert(t('Please give the query a name.')); nameInput.focus(); return null; }
        if (/\s/.test(name)) { alert(t('A query name must be a single word or number (no spaces).')); nameInput.focus(); return null; }
        if (bodyLines().length === 0) { alert(t('Add at least one condition to the query.')); return null; }
        return name;
    }

    // --- Actions ---------------------------------------------------------------
    ($('btn-copy') as HTMLButtonElement).addEventListener('click', async () => {
        const name = requireName();
        if (!name) return;
        const text = blockText(name);
        try {
            await navigator.clipboard.writeText(text);
            dirty = false; setStatus(t('Copied to clipboard'));
        } catch {
            window.prompt(t('Copy the query text:'), text);
            dirty = false; setStatus(t('Copied'));
        }
    });

    ($('btn-insert') as HTMLButtonElement).addEventListener('click', () => {
        const name = requireName();
        if (!name) return;
        channel.postMessage({ type: 'insert-query', name, blockText: blockText(name), replaceName: loadedName });
        dirty = false;   // suppresses the close warning
        setStatus(t('Inserted into editor'));
        setTimeout(() => window.close(), 100);   // once the message has been dispatched
    });

    picker.addEventListener('change', () => {
        if (dirty && !confirm(t('Discard unsaved changes and load the selected query?'))) {
            picker.value = loadedName || '__new__';
            return;
        }
        if (picker.value === '__new__') newQuery();
        else loadQuery(picker.value);
    });

    nameInput.addEventListener('input', markDirty);

    window.addEventListener('beforeunload', (e) => {
        if (dirty) { e.preventDefault(); e.returnValue = ''; return ''; }
    });

    // --- Boot ------------------------------------------------------------------
    picker.value = '__new__';
    newQuery();
}


// UI chrome i18n: translate this page's static chrome and carry the UI
// language on /leapi calls (see src/i18n.ts).
installLeApiLang();
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => applyI18nDom());
} else {
    applyI18nDom();
}
