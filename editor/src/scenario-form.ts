// Reusable scenario "fact form": a vertical sequence of editable template rows,
// shared by the Scenario Editor window and the Scenario Variations window. Each row
// renders one of the program's templates with its literal words as labels and its
// placeholders as hint-text input fields; non-template lines are preserved read-only;
// "<query> expects answers …" test directives are set aside and written back as
// comments. The host window supplies the DOM containers and an onChange callback.

import {
    splitTemplate, matchFact, fillTemplate, parseTemplateDefs, parseScenarioBlocks
} from './le-templates';

interface Row {
    templateLabel: string | null;   // null => a preserved (non-template) line
    values: string[];
    raw: string;
    assumed: boolean;               // "it is unknown whether <fact>" (Assume checkbox)
}

// "X is a / an TYPE" type assertions are valid scenario facts but aren't declared
// templates; include them so such facts load as editable rows.
const SYSTEM_TYPE = ['*a thing* is a *type*', '*a thing* is an *type*'];

// A scenario "test" line: "<query> expects answers [...] (and unknowns [...])".
export const isTestDirective = (fact: string) => /\bexpects?\s+answers?\b/i.test(fact);

// An "unknown" (assumable) scenario fact: "it is unknown whether <fact>". LE also
// accepts the "assumed"/"assumable" synonyms.
const UNKNOWN_PREFIX = /^it is (?:unknown|assumed|assumable) whether\s+/i;

export interface ScenarioFormOptions {
    source: string;                 // LE source, for templates + which templates are used
    rowsEl: HTMLElement;            // container the rows are rendered into
    addSelect: HTMLSelectElement;   // the "Add fact" template picker
    btnAdd: HTMLButtonElement;      // the "Add" button
    onChange?: () => void;          // fired on any edit (add/remove/field change)
    assumeTitle?: string;           // tooltip for the "Assume" checkbox (host-specific)
    // When set, an extra "Write it in English…" entry is added to the Add picker; the
    // host opens the NL modal and later calls addFact() with the generated facts.
    onWriteInEnglish?: () => void;
}

// Sentinel value for the "Write it in English…" entry in the Add picker.
export const WRITE_IN_ENGLISH = '__write_in_english__';

// Default tooltip for the "Assume" checkbox; hosts may override via ScenarioFormOptions.
const DEFAULT_ASSUME_TITLE = 'if checked, fact is assumed, unknown';

export class ScenarioForm {
    readonly templates: string[];        // all templates (for recognising facts)
    readonly addableTemplates: string[]; // those offered in the Add menu
    testLines: string[] = [];            // tests from the loaded scenario, kept as comments
    private rows: Row[] = [];
    private opts: ScenarioFormOptions;

    constructor(opts: ScenarioFormOptions) {
        this.opts = opts;
        const defs = parseTemplateDefs(opts.source);
        this.templates = [...defs.map(d => d.label), ...SYSTEM_TYPE];

        // Addable = templates declared "; undefined" (scenario element) or already used
        // by some scenario; plus a type assertion if one is used. Conclusions excluded.
        const used = new Set<string>();
        for (const b of parseScenarioBlocks(opts.source)) {
            for (const f of b.facts) { const m = matchFact(f, this.templates); if (m) used.add(m.label); }
        }
        const seen = new Set<string>();
        const addable: string[] = [];
        for (const d of defs) {
            if ((d.isUndefined || used.has(d.label)) && !seen.has(d.label)) { seen.add(d.label); addable.push(d.label); }
        }
        for (const t of SYSTEM_TYPE) {
            if (used.has(t) && !seen.has(t)) { seen.add(t); addable.push(t); }
        }
        this.addableTemplates = addable;

        opts.addSelect.innerHTML = '';
        for (const label of addable) {
            const o = document.createElement('option');
            o.value = label;
            o.textContent = label.replace(/\*/g, '');   // show placeholders without the markers
            opts.addSelect.appendChild(o);
        }
        if (opts.onWriteInEnglish) {
            const o = document.createElement('option');
            o.value = WRITE_IN_ENGLISH;
            o.textContent = 'Write it in English';
            opts.addSelect.appendChild(o);
        }
        opts.btnAdd.addEventListener('click', () => {
            const val = opts.addSelect.value;
            if (!val) return;
            if (val === WRITE_IN_ENGLISH) { this.opts.onWriteInEnglish?.(); return; }
            this.rows.push({ templateLabel: val, values: [], raw: '', assumed: false });
            this.changed();
            this.render();
            (opts.rowsEl.lastElementChild as HTMLElement | null)?.querySelector('input.field')?.focus();
        });
    }

    private changed() { this.opts.onChange?.(); }

    // Load a scenario's facts: template instances become editable rows, "expects
    // answers" tests are kept aside, everything else is preserved read-only.
    loadFacts(facts: string[]) {
        this.rows = [];
        this.testLines = [];
        for (const fact of facts) {
            if (isTestDirective(fact)) { this.testLines.push(fact); continue; }
            // A fact the program declares unknown loads with "Assume" pre-checked.
            const assumed = UNKNOWN_PREFIX.test(fact);
            const inner = assumed ? fact.replace(UNKNOWN_PREFIX, '') : fact;
            const m = matchFact(inner, this.templates);
            if (m) this.rows.push({ templateLabel: m.label, values: m.values, raw: '', assumed });
            else this.rows.push({ templateLabel: null, values: [], raw: inner, assumed });
        }
        this.render();
    }

    clear() {
        this.rows = [];
        this.testLines = [];
        this.render();
    }

    // --- Rendering -------------------------------------------------------------
    render() {
        const rowsEl = this.opts.rowsEl;
        rowsEl.innerHTML = '';
        if (this.rows.length === 0) {
            const hint = document.createElement('div');
            hint.className = 'empty-hint';
            hint.textContent = 'No facts yet — pick a template below and click “Add”.';
            rowsEl.appendChild(hint);
            return;
        }
        this.rows.forEach((row, idx) => rowsEl.appendChild(this.renderRow(row, idx)));
    }

    private sizeField(input: HTMLInputElement) {
        const n = Math.max((input.value || input.placeholder).length + 1, 6);
        input.size = Math.min(n, 80);
    }

    private renderRow(row: Row, idx: number): HTMLElement {
        const el = document.createElement('div');
        el.className = 'fact-row';
        if (row.assumed) el.classList.add('assumed');

        const fieldInputs: HTMLInputElement[] = [];
        if (row.templateLabel === null) {
            const span = document.createElement('span');
            span.className = 'preserved';
            span.textContent = row.raw;
            span.title = 'This line matches no template — edit it in the main editor';
            el.appendChild(span);
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
                    input.placeholder = seg.text;      // hint text = the LE variable
                    input.title = seg.text;
                    input.value = row.values[fi] ?? '';
                    input.disabled = row.assumed;      // assumed facts are not editable
                    this.sizeField(input);
                    input.addEventListener('input', () => {
                        row.values[fi] = input.value;
                        this.sizeField(input);
                        this.changed();
                    });
                    el.appendChild(input);
                    fieldInputs.push(input);
                }
            }
        }

        const tools = document.createElement('div');
        tools.className = 'row-tools';

        // "Assume" — mark the fact unknown ("it is unknown whether …"); its fields
        // then become read-only.
        const assume = document.createElement('label');
        assume.className = 'assume';
        assume.title = this.opts.assumeTitle || DEFAULT_ASSUME_TITLE;
        const check = document.createElement('input');
        check.type = 'checkbox';
        check.checked = row.assumed;
        check.addEventListener('change', () => {
            row.assumed = check.checked;
            fieldInputs.forEach(inp => inp.disabled = row.assumed);
            el.classList.toggle('assumed', row.assumed);
            this.changed();
        });
        assume.appendChild(check);
        assume.appendChild(document.createTextNode(' Assume'));
        tools.appendChild(assume);

        const del = document.createElement('button');
        del.textContent = '✕';
        del.title = 'Delete';
        del.addEventListener('click', () => { this.rows.splice(idx, 1); this.changed(); this.render(); });
        tools.appendChild(del);
        el.appendChild(tools);
        return el;
    }

    // --- Patching from an explanation node -------------------------------------
    // A fact's surface text as compared for add/remove (no "it is unknown whether"
    // prefix, no trailing period): the raw line, or the template filled with values.
    private factBase(row: Row): string {
        return row.templateLabel === null
            ? row.raw.trim().replace(/\.\s*$/, '').trim()
            : fillTemplate(row.templateLabel, row.values);
    }

    // Normalise a fact's text for add/remove comparison. Besides trimming, dropping a
    // trailing period and collapsing whitespace, it canonicalises date tokens so a
    // scenario fact written "2021-10-09" matches the explanation's rendered
    // "2021-10-9T0:0:0.0" (same calendar date, different surface form).
    private static norm(text: string): string {
        let s = text.trim().replace(/\.\s*$/, '').replace(/\s+/g, ' ').trim().toLowerCase();
        s = s.replace(/\b(\d{1,4})-(\d{1,2})-(\d{1,2})(t[\d:.]*)?/g,
            (_m, y, mo, d) => `${+y}-${+mo}-${+d}`);
        return s;
    }

    // Does a scenario fact matching `text` currently exist? (date-tolerant)
    hasFact(text: string): boolean {
        const key = ScenarioForm.norm((text || '').trim().replace(/\.\s*$/, '').trim());
        if (!key) return false;
        return this.rows.some(r => ScenarioForm.norm(this.factBase(r)) === key);
    }

    // Is `text` a sensible scenario fact to add — i.e. does it instantiate one of the
    // program's templates? (Compound/negated explanation literals do not.)
    matchesTemplate(text: string): boolean {
        const base = (text || '').trim().replace(/\.\s*$/, '').trim();
        return !!base && !!matchFact(base, this.templates);
    }

    // Add a scenario fact from an explanation node's surface text (the LE literal).
    // If the fact is already present, only its "assumed" flag is updated. `assumed`
    // adds it as "it is unknown whether …" — the equivalent of the Assume checkbox.
    // Returns false if the text was empty (nothing done).
    addFact(text: string, assumed = false): boolean {
        const base = (text || '').trim().replace(/\.\s*$/, '').trim();
        if (!base) return false;
        const key = ScenarioForm.norm(base);
        const existing = this.rows.find(r => ScenarioForm.norm(this.factBase(r)) === key);
        let idx: number;
        if (existing) {
            existing.assumed = assumed;
            idx = this.rows.indexOf(existing);
        } else {
            const m = matchFact(base, this.templates);
            if (m) this.rows.push({ templateLabel: m.label, values: m.values, raw: '', assumed });
            else this.rows.push({ templateLabel: null, values: [], raw: base, assumed });
            idx = this.rows.length - 1;
        }
        this.changed();
        this.render();
        this.selectRow(idx);
        return true;
    }

    // Highlight, reveal and focus a row (used after adding a fact from a tree node).
    private selectRow(idx: number) {
        const rowEl = this.opts.rowsEl.children[idx] as HTMLElement | undefined;
        if (!rowEl) return;
        this.opts.rowsEl.querySelectorAll('.fact-row.selected').forEach(e => e.classList.remove('selected'));
        rowEl.classList.add('selected');
        rowEl.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        (rowEl.querySelector('input.field') as HTMLInputElement | null)?.focus();
    }

    // Remove every scenario fact whose surface text matches `text` (ignoring an
    // "it is unknown whether" prefix). Returns how many rows were removed.
    removeFact(text: string): number {
        const key = ScenarioForm.norm((text || '').trim().replace(/\.\s*$/, '').trim());
        if (!key) return 0;
        const before = this.rows.length;
        this.rows = this.rows.filter(r => ScenarioForm.norm(this.factBase(r)) !== key);
        const removed = before - this.rows.length;
        if (removed > 0) { this.changed(); this.render(); }
        return removed;
    }

    // --- Producing text --------------------------------------------------------
    private factText(row: Row): string {
        const base = this.factBase(row);
        if (!base) return '';
        return row.assumed ? `it is unknown whether ${base}` : base;
    }

    // Each fact's text (no trailing period), skipping wholly-empty rows.
    factLines(): string[] {
        return this.rows.map(r => this.factText(r)).filter(t => !!t);
    }

    // The facts as runnable LE text (each terminated by "."), for use as a custom
    // scenario. Tests are NOT included (they are not facts).
    factsText(): string {
        return this.factLines().map(t => `${t}.`).join('\n');
    }

    // A full "scenario <name> is:" block; tests are appended commented-out.
    blockText(name: string): string {
        const lines = [`scenario ${name} is:`];
        for (const t of this.factLines()) lines.push(`    ${t}.`);
        if (this.testLines.length) {
            lines.push(`    % tests (review and uncomment to re-enable):`);
            for (const t of this.testLines) lines.push(`    % ${t}.`);
        }
        return lines.join('\n');
    }
}
