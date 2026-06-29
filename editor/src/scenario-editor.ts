// Scenario Editor window. Window chrome (picker, name, Copy, Insert, close warning)
// around the shared ScenarioForm. Results are sent back to the editor or the
// clipboard; the final LE syntax check happens on the Prolog side when the editor
// reloads.

import { parseScenarioBlocks, ScenarioBlock } from './le-templates';
import { ScenarioForm } from './scenario-form';

interface ScenarioEditorData { source?: string; }

// The editor listens on this channel and applies inserts to the Monaco document.
const CHANNEL = 'le-scenario-editor';

export function initScenarioEditor(data: ScenarioEditorData) {
    const source = data.source || '';
    const blocks: ScenarioBlock[] = parseScenarioBlocks(source);
    const blockByName = new Map<string, ScenarioBlock>();
    blocks.forEach(b => blockByName.set(b.name, b));

    const channel = new BroadcastChannel(CHANNEL);

    const $ = (id: string) => document.getElementById(id)!;
    const picker = $('scenario-picker') as HTMLSelectElement;
    const nameInput = $('scenario-name') as HTMLInputElement;
    const statusEl = $('status');

    let loadedName = '';    // the existing scenario currently loaded (for replace), '' for New
    let dirty = false;      // edited since the last Copy / Insert (drives the close warning)

    function setStatus(text: string) { statusEl.textContent = text; }
    function markDirty() { dirty = true; setStatus('Unsaved changes'); }

    const form = new ScenarioForm({
        source,
        rowsEl: $('rows'),
        addSelect: $('add-template') as HTMLSelectElement,
        btnAdd: $('btn-add') as HTMLButtonElement,
        onChange: markDirty,
    });

    // --- Scenario picker -------------------------------------------------------
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

    function loadScenario(name: string) {
        const block = blockByName.get(name);
        loadedName = block ? block.name : '';
        nameInput.value = block ? block.name : '';
        form.loadFacts(block ? block.facts : []);
        dirty = false;
        const n = form.testLines.length;
        setStatus(block ? `Loaded scenario "${name}"${n ? ` (${n} test line${n > 1 ? 's' : ''} kept as comments)` : ''}` : '');
    }
    function newScenario() {
        loadedName = '';
        nameInput.value = '';
        form.clear();
        dirty = false;
        setStatus('New scenario');
    }

    // Returns the trimmed name, or null (with an alert) when it is missing/invalid.
    function requireName(): string | null {
        const name = nameInput.value.trim();
        if (!name) { alert('Please give the scenario a name.'); nameInput.focus(); return null; }
        if (/\s/.test(name)) { alert('A scenario name must be a single word (no spaces).'); nameInput.focus(); return null; }
        return name;
    }

    // --- Actions ---------------------------------------------------------------
    (document.getElementById('btn-copy') as HTMLButtonElement).addEventListener('click', async () => {
        const name = requireName();
        if (!name) return;
        const text = form.blockText(name);
        try {
            await navigator.clipboard.writeText(text);
            dirty = false; setStatus('Copied to clipboard');
        } catch {
            window.prompt('Copy the scenario text:', text);
            dirty = false; setStatus('Copied');
        }
    });

    (document.getElementById('btn-insert') as HTMLButtonElement).addEventListener('click', () => {
        const name = requireName();
        if (!name) return;
        channel.postMessage({ type: 'insert-scenario', name, blockText: form.blockText(name), replaceName: loadedName });
        dirty = false;   // suppresses the close warning
        setStatus('Inserted into editor');
        setTimeout(() => window.close(), 100);   // once the message has been dispatched
    });

    picker.addEventListener('change', () => {
        if (dirty && !confirm('Discard unsaved changes and load the selected scenario?')) {
            picker.value = loadedName || '__new__';
            return;
        }
        if (picker.value === '__new__') newScenario();
        else loadScenario(picker.value);
    });

    nameInput.addEventListener('input', markDirty);

    window.addEventListener('beforeunload', (e) => {
        if (dirty) { e.preventDefault(); e.returnValue = ''; return ''; }
    });

    // --- Boot ------------------------------------------------------------------
    picker.value = '__new__';
    newScenario();
}
