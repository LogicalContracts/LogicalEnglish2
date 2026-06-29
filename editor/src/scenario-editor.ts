// Scenario Editor window. A pure client-side form UI for building and editing a
// scenario's facts as a vertical sequence of "editable templates": each row renders
// one of the program's templates with its literal words as labels and its
// placeholders as hint-text input fields. Results are sent back to the editor (or
// the clipboard); the final LE syntax check happens on the Prolog side when the
// editor reloads.

import {
    splitTemplate, matchFact, fillTemplate, parseScenarioBlocks, parseTemplateDefs, ScenarioBlock
} from './le-templates';

interface Row {
    // A template instance: editable placeholder fields. `templateLabel` null marks a
    // PRESERVED line — an existing fact that matched no template (e.g. "... expects
    // answers ...") — shown read-only so loading a scenario round-trips, but never
    // created here (the editor is strictly template-driven).
    templateLabel: string | null;
    values: string[];
    raw: string;
}

interface ScenarioEditorData {
    source?: string;
}

// The editor listens on this channel and applies inserts to the Monaco document.
const CHANNEL = 'le-scenario-editor';

export function initScenarioEditor(data: ScenarioEditorData) {
    const source = data.source || '';
    // Template definitions read from source (WITH *...* markers) — the backend strips
    // them. ALL templates are used to recognise existing facts on load; only some are
    // offered in the "Add fact" menu (see addableTemplates).
    const defs = parseTemplateDefs(source);
    // "X is a / an TYPE" type assertions are valid scenario facts but aren't declared
    // templates; include them in the matching set so such facts load as editable rows.
    const SYSTEM_TYPE = ['*a thing* is a *type*', '*a thing* is an *type*'];
    const templates: string[] = [...defs.map(d => d.label), ...SYSTEM_TYPE];
    const blocks: ScenarioBlock[] = parseScenarioBlocks(source);
    const blockByName = new Map<string, ScenarioBlock>();
    blocks.forEach(b => blockByName.set(b.name, b));

    // The "Add fact" menu lists only templates that make sense as scenario facts:
    // those declared "; undefined" (a.k.a. "scenario element"), plus any already used
    // by some scenario in the program. Conclusion/derived templates are excluded.
    const usedLabels = new Set<string>();
    for (const block of blocks) {
        for (const fact of block.facts) {
            const mm = matchFact(fact, templates);
            if (mm) usedLabels.add(mm.label);
        }
    }
    const seen = new Set<string>();
    const addableTemplates: string[] = [];
    for (const d of defs) {
        if ((d.isUndefined || usedLabels.has(d.label)) && !seen.has(d.label)) {
            seen.add(d.label);
            addableTemplates.push(d.label);
        }
    }
    for (const t of SYSTEM_TYPE) {   // a type assertion is offered only if already used
        if (usedLabels.has(t) && !seen.has(t)) { seen.add(t); addableTemplates.push(t); }
    }

    const channel = new BroadcastChannel(CHANNEL);

    const $ = (id: string) => document.getElementById(id)!;
    const picker = $('scenario-picker') as HTMLSelectElement;
    const nameInput = $('scenario-name') as HTMLInputElement;
    const rowsEl = $('rows');
    const addSelect = $('add-template') as HTMLSelectElement;
    const btnAdd = $('btn-add') as HTMLButtonElement;
    const btnCopy = $('btn-copy') as HTMLButtonElement;
    const btnInsert = $('btn-insert') as HTMLButtonElement;
    const statusEl = $('status');

    let rows: Row[] = [];
    let loadedName = '';    // the existing scenario currently loaded (for replace), '' for New
    let dirty = false;      // edited since the last Copy / Insert (drives the close warning)

    // --- Pickers ---------------------------------------------------------------
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

    addSelect.innerHTML = '';
    addableTemplates.forEach(label => {
        const o = document.createElement('option');
        o.value = label;
        // Show the template with its placeholders so the user can pick.
        o.textContent = label.replace(/\*/g, '');
        addSelect.appendChild(o);
    });

    // --- Dirty / status --------------------------------------------------------
    function markDirty() {
        dirty = true;
        setStatus('Unsaved changes');
    }
    function setStatus(text: string) { statusEl.textContent = text; }

    // Grow a field to fit its value (or the hint when empty) so long arguments — e.g.
    // "court attendance of directors and officers" — are not truncated.
    function sizeField(input: HTMLInputElement) {
        const n = Math.max((input.value || input.placeholder).length + 1, 6);
        input.size = Math.min(n, 80);
    }

    // --- Loading a scenario ----------------------------------------------------
    function loadScenario(name: string) {
        const block = blockByName.get(name);
        loadedName = block ? block.name : '';
        nameInput.value = block ? block.name : '';
        rows = [];
        if (block) {
            for (const fact of block.facts) {
                const m = matchFact(fact, templates);
                if (m) rows.push({ templateLabel: m.label, values: m.values, raw: '' });
                else rows.push({ templateLabel: null, values: [], raw: fact });
            }
        }
        render();
        dirty = false;
        setStatus(block ? `Loaded scenario "${name}"` : '');
    }

    function newScenario() {
        loadedName = '';
        nameInput.value = '';
        rows = [];
        render();
        dirty = false;
        setStatus('New scenario');
    }

    // --- Rendering -------------------------------------------------------------
    function render() {
        rowsEl.innerHTML = '';
        if (rows.length === 0) {
            const hint = document.createElement('div');
            hint.className = 'empty-hint';
            hint.textContent = 'No facts yet — pick a template below and click “Add”.';
            rowsEl.appendChild(hint);
            return;
        }
        rows.forEach((row, idx) => rowsEl.appendChild(renderRow(row, idx)));
    }

    function renderRow(row: Row, idx: number): HTMLElement {
        const el = document.createElement('div');
        el.className = 'fact-row';

        if (row.templateLabel === null) {
            // A preserved (non-template) line: shown read-only so the scenario
            // round-trips; edit it in the main editor instead.
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
                    input.placeholder = seg.text;          // hint text = the LE variable
                    input.title = seg.text;
                    input.value = row.values[fi] ?? '';
                    sizeField(input);                       // fit the value, not just the hint
                    input.addEventListener('input', () => {
                        row.values[fi] = input.value;
                        sizeField(input);
                        markDirty();
                    });
                    el.appendChild(input);
                }
            }
        }

        const tools = document.createElement('div');
        tools.className = 'row-tools';
        const del = document.createElement('button');
        del.textContent = '✕';
        del.title = 'Delete';
        del.addEventListener('click', () => { rows.splice(idx, 1); markDirty(); render(); });
        tools.appendChild(del);
        el.appendChild(tools);
        return el;
    }

    // --- Building the scenario text -------------------------------------------
    function factText(row: Row): string {
        if (row.templateLabel === null) return row.raw.trim().replace(/\.\s*$/, '').trim();
        return fillTemplate(row.templateLabel, row.values);
    }

    function buildBlockText(name: string): string {
        const lines = [`scenario ${name} is:`];
        for (const row of rows) {
            const text = factText(row);
            if (!text) continue;          // skip wholly-empty rows
            lines.push(`    ${text}.`);
        }
        return lines.join('\n');
    }

    // Returns the trimmed name, or null (with an alert) when it is missing.
    function requireName(): string | null {
        const name = nameInput.value.trim();
        if (!name) {
            alert('Please give the scenario a name.');
            nameInput.focus();
            return null;
        }
        if (/\s/.test(name)) {
            alert('A scenario name must be a single word (no spaces).');
            nameInput.focus();
            return null;
        }
        return name;
    }

    // --- Actions ---------------------------------------------------------------
    btnAdd.addEventListener('click', () => {
        const val = addSelect.value;
        if (!val) return;
        rows.push({ templateLabel: val, values: [], raw: '' });
        markDirty();
        render();
        // Focus the first field of the new row.
        const last = rowsEl.lastElementChild as HTMLElement | null;
        last?.querySelector('input')?.focus();
    });

    btnCopy.addEventListener('click', async () => {
        const name = requireName();
        if (!name) return;
        const text = buildBlockText(name);
        try {
            await navigator.clipboard.writeText(text);
            dirty = false;
            setStatus('Copied to clipboard');
        } catch {
            // Fallback for browsers/contexts without async clipboard access.
            window.prompt('Copy the scenario text:', text);
            dirty = false;
            setStatus('Copied');
        }
    });

    btnInsert.addEventListener('click', () => {
        const name = requireName();
        if (!name) return;
        const blockText = buildBlockText(name);
        channel.postMessage({ type: 'insert-scenario', name, blockText, replaceName: loadedName });
        dirty = false;   // suppresses the close warning
        setStatus('Inserted into editor');
        // Close once the message has been dispatched to the editor window.
        setTimeout(() => window.close(), 100);
    });

    picker.addEventListener('change', () => {
        if (dirty && !confirm('Discard unsaved changes and load the selected scenario?')) {
            // Revert the picker to the current scenario.
            picker.value = loadedName || '__new__';
            return;
        }
        if (picker.value === '__new__') newScenario();
        else loadScenario(picker.value);
    });

    nameInput.addEventListener('input', markDirty);

    // --- Close warning ---------------------------------------------------------
    // Warn before closing while there are edits not yet copied or inserted.
    window.addEventListener('beforeunload', (e) => {
        if (dirty) {
            e.preventDefault();
            e.returnValue = '';   // triggers the browser's native "leave site?" confirm
            return '';
        }
    });

    // --- Boot ------------------------------------------------------------------
    picker.value = '__new__';
    newScenario();
}
