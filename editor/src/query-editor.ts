// Query Editor window. Same look and feel as the Scenario Editor, but builds a
// "query <name> is:" block from template instances joined by the basic connectives
// (and / or) with optional "it is not the case that" negation. It deliberately does
// NOT support the full LE body-condition syntax (nested groups, aggregates, etc.) —
// it stays a simple, flat list of conditions. Results are sent back to the editor or
// the clipboard; the final LE syntax check happens on the Prolog side on reload.

import { parseTemplateDefs, parseQueryBlocks, QueryBlock, splitTemplate, matchFact } from './le-templates';

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
    const markDirty = () => { dirty = true; setStatus('Unsaved changes'); };

    // --- Template Add picker ---------------------------------------------------
    addSelect.innerHTML = '';
    for (const label of addable) {
        const o = document.createElement('option');
        o.value = label;
        o.textContent = label.replace(/\*/g, '');   // show placeholders without the markers
        addSelect.appendChild(o);
    }

    ($('btn-add') as HTMLButtonElement).addEventListener('click', () => {
        const val = addSelect.value;
        if (!val) return;
        rows.push({ templateLabel: val, values: [], raw: '', negated: false, connective: 'and' });
        markDirty();
        render();
        (rowsEl.lastElementChild?.querySelector('input.field, input.raw') as HTMLInputElement | null)?.focus();
    });

    // --- Query picker ----------------------------------------------------------
    picker.innerHTML = '';
    const newOpt = document.createElement('option');
    newOpt.value = '__new__';
    newOpt.textContent = 'New…';
    picker.appendChild(newOpt);
    blocks.forEach(b => {
        const o = document.createElement('option');
        o.value = b.name;
        o.textContent = b.name;
        picker.appendChild(o);
    });

    // --- Parsing an existing query body into rows ------------------------------
    // Best-effort: split the body on top-level " and "/" or ", strip any leading
    // "it is not the case that", and match each part to a template. If EVERY part
    // matches, use those structured rows; otherwise keep the whole body as ONE
    // free-text row so a complex query (or a value containing "and"/"or") is never
    // mangled — the user can still edit it.
    function parseBody(body: string): QRow[] {
        if (!body.trim()) return [];
        const toks = body.split(/\s+(and|or)\s+/i);   // ["a","and","b","or","c"]
        const parts: { connective: Connective; text: string }[] = [{ connective: 'and', text: toks[0] }];
        for (let i = 1; i < toks.length; i += 2) {
            parts.push({ connective: toks[i].toLowerCase() as Connective, text: toks[i + 1] ?? '' });
        }
        const parsed: QRow[] = [];
        for (const p of parts) {
            const negated = NEG_PREFIX.test(p.text);
            const inner = negated ? p.text.replace(NEG_PREFIX, '').trim() : p.text.trim();
            const m = matchFact(inner, templates);
            if (!m) return [{ templateLabel: null, values: [], raw: body.trim(), negated: false, connective: 'and' }];
            parsed.push({ templateLabel: m.label, values: m.values, raw: '', negated, connective: p.connective });
        }
        return parsed;
    }

    function loadQuery(name: string) {
        const block = blockByName.get(name);
        loadedName = block ? block.name : '';
        nameInput.value = block ? block.name : '';
        rows = block ? parseBody(block.body) : [];
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
        setStatus('New query');
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
            hint.textContent = 'No conditions yet — pick a template below and click “Add”.';
            rowsEl.appendChild(hint);
            return;
        }
        rows.forEach((row, idx) => rowsEl.appendChild(renderRow(row, idx)));
    }

    function renderRow(row: QRow, idx: number): HTMLElement {
        const el = document.createElement('div');
        el.className = 'fact-row';
        if (row.negated) el.classList.add('negated');

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
            neg.textContent = 'it is not the case that';
            el.appendChild(neg);
        }

        if (row.templateLabel === null) {
            const input = document.createElement('input');
            input.type = 'text';
            input.className = 'raw';
            input.value = row.raw;
            input.placeholder = 'condition';
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
        negLabel.title = 'Wrap this condition in "it is not the case that …"';
        const check = document.createElement('input');
        check.type = 'checkbox';
        check.checked = row.negated;
        check.addEventListener('change', () => { row.negated = check.checked; markDirty(); render(); });
        negLabel.appendChild(check);
        negLabel.appendChild(document.createTextNode(' not'));
        tools.appendChild(negLabel);

        const del = document.createElement('button');
        del.textContent = '✕';
        del.title = 'Delete condition';
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
    // The body lines (each condition, prefixed by its connective except the first),
    // skipping wholly-empty conditions.
    function bodyLines(): string[] {
        const out: string[] = [];
        rows.forEach((row) => {
            const c = condText(row);
            if (!c) return;
            out.push(out.length === 0 ? c : `${row.connective} ${c}`);
        });
        return out;
    }
    function blockText(name: string): string {
        const lines = bodyLines();
        const body = lines.length ? lines.map(l => `    ${l}`).join('\n') : '    ';
        return `query ${name} is:\n${body}.`;
    }

    // Returns the trimmed name, or null (with an alert) when it is missing/invalid.
    function requireName(): string | null {
        const name = nameInput.value.trim();
        if (!name) { alert('Please give the query a name.'); nameInput.focus(); return null; }
        if (/\s/.test(name)) { alert('A query name must be a single word or number (no spaces).'); nameInput.focus(); return null; }
        if (bodyLines().length === 0) { alert('Add at least one condition to the query.'); return null; }
        return name;
    }

    // --- Actions ---------------------------------------------------------------
    ($('btn-copy') as HTMLButtonElement).addEventListener('click', async () => {
        const name = requireName();
        if (!name) return;
        const text = blockText(name);
        try {
            await navigator.clipboard.writeText(text);
            dirty = false; setStatus('Copied to clipboard');
        } catch {
            window.prompt('Copy the query text:', text);
            dirty = false; setStatus('Copied');
        }
    });

    ($('btn-insert') as HTMLButtonElement).addEventListener('click', () => {
        const name = requireName();
        if (!name) return;
        channel.postMessage({ type: 'insert-query', name, blockText: blockText(name), replaceName: loadedName });
        dirty = false;   // suppresses the close warning
        setStatus('Inserted into editor');
        setTimeout(() => window.close(), 100);   // once the message has been dispatched
    });

    picker.addEventListener('change', () => {
        if (dirty && !confirm('Discard unsaved changes and load the selected query?')) {
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
