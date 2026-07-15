// Shared "Write it in English…" modal, used by the Scenario Editor (to add facts)
// and the Query Editor (to append query conditions). The user types one or more
// English sentences; we send them — together with the program's templates — to the
// backend `nl_to_le` operation, which asks the configured LLM (the same model/keys
// as the LE Assistant) to translate them into Logical English respecting those
// templates. The generated LE is handed back via onResult; the host parses it into
// form rows. No LLM plumbing lives here beyond the one POST.

import { parseTemplateDefs } from './le-templates';
import { t, applyI18nDom, installLeApiLang } from './i18n';

const TOKEN = 'myToken123';

export interface NlInputOptions {
    kind: 'facts' | 'query';      // what to generate
    source: string;               // program source (its templates constrain the output)
    title: string;                // dialog title
    instruction: string;          // guidance shown at the top of the dialog
    placeholder?: string;         // textarea placeholder
    onResult: (leText: string) => void;   // receives the generated LE text
}

// The LLM model + API keys are shared with the LE Assistant via localStorage (same
// origin), set from the main editor's "Misc → API Keys…" dialog.
function assistantModel(): string { return localStorage.getItem('le-assistant-model') || ''; }
function assistantKeys(): Record<string, string | null> {
    return {
        openai: localStorage.getItem('le-openai-key'),
        anthropic: localStorage.getItem('le-anthropic-key'),
        google: localStorage.getItem('le-google-key'),
        groq: localStorage.getItem('le-groq-key'),
        together: localStorage.getItem('le-together-key'),
    };
}

// Inject the modal stylesheet once (uses the host page's theme CSS variables).
function ensureStyles() {
    if (document.getElementById('nl-input-styles')) return;
    const style = document.createElement('style');
    style.id = 'nl-input-styles';
    style.textContent = `
        .nl-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: flex;
            align-items: center; justify-content: center; z-index: 1000; }
        .nl-dialog { background: var(--panel-bg, #252526); color: var(--text-color, #d4d4d4);
            border: 1px solid var(--border-color, #444); border-radius: 8px; width: min(640px, 92vw);
            max-height: 90vh; overflow: auto; padding: 18px 20px; box-shadow: 0 8px 32px rgba(0,0,0,0.5); }
        .nl-dialog h2 { margin: 0 0 8px 0; font-size: 16px; cursor: move; user-select: none; }
        .nl-instruction { color: var(--muted, #888); font-size: 12px; margin: 0 0 12px 0; line-height: 1.5; }
        .nl-dialog textarea { width: 100%; min-height: 96px; resize: vertical; font-family: inherit;
            font-size: 14px; background: var(--field-bg, #2d2d30); color: var(--input-text, #d4d4d4);
            border: 1px solid var(--input-border, #555); border-radius: 4px; padding: 8px; box-sizing: border-box; }
        .nl-status { font-size: 12px; margin: 10px 0 0 0; min-height: 16px; white-space: pre-line; }
        .nl-status.error { color: #f48771; }
        .nl-status.warn { color: #e2b93d; }
        .nl-actions { display: flex; gap: 10px; align-items: center; justify-content: flex-end; margin-top: 14px; }
        .nl-actions .spacer { flex: 1; }
        .nl-model { color: var(--muted, #888); font-size: 11px; }
        .nl-dialog button { background: var(--input-bg, #3c3c3c); color: var(--input-text, #d4d4d4);
            border: 1px solid var(--input-border, #555); border-radius: 4px; padding: 6px 12px; font: inherit; cursor: pointer; }
        .nl-dialog button.primary { background: var(--accent, #0e639c); color: #fff; border-color: var(--accent, #0e639c); }
        .nl-dialog button:disabled { opacity: 0.5; cursor: default; }
    `;
    document.head.appendChild(style);
}

// Let the user drag `box` around by grabbing `handle`. The box stays flex-centred by
// the overlay; dragging applies a translate offset on top of that centre position.
function makeDraggable(box: HTMLElement, handle: HTMLElement) {
    let dx = 0, dy = 0;                    // current offset from the centred position
    let startX = 0, startY = 0, ox = 0, oy = 0, dragging = false;
    const onMove = (e: MouseEvent) => {
        if (!dragging) return;
        dx = ox + (e.clientX - startX);
        dy = oy + (e.clientY - startY);
        box.style.transform = `translate(${dx}px, ${dy}px)`;
    };
    const onUp = () => {
        dragging = false;
        document.removeEventListener('mousemove', onMove);
        document.removeEventListener('mouseup', onUp);
        document.body.style.userSelect = '';
    };
    handle.addEventListener('mousedown', (e) => {
        dragging = true;
        startX = e.clientX; startY = e.clientY; ox = dx; oy = dy;
        document.body.style.userSelect = 'none';
        document.addEventListener('mousemove', onMove);
        document.addEventListener('mouseup', onUp);
        e.preventDefault();
    });
}

export function openNlInput(opts: NlInputOptions): void {
    ensureStyles();

    const overlay = document.createElement('div');
    overlay.className = 'nl-overlay';
    const dialog = document.createElement('div');
    dialog.className = 'nl-dialog';
    overlay.appendChild(dialog);

    const h = document.createElement('h2');
    h.textContent = opts.title;
    const instr = document.createElement('p');
    instr.className = 'nl-instruction';
    instr.textContent = opts.instruction;
    const textarea = document.createElement('textarea');
    textarea.placeholder = opts.placeholder || 'Type your sentence(s) here…';
    const status = document.createElement('div');
    status.className = 'nl-status';

    const actions = document.createElement('div');
    actions.className = 'nl-actions';
    const model = assistantModel();
    const modelLabel = document.createElement('span');
    modelLabel.className = 'nl-model';
    modelLabel.textContent = model ? `Model: ${model}` : 'No model configured';
    const spacer = document.createElement('span');
    spacer.className = 'spacer';
    const cancel = document.createElement('button');
    cancel.textContent = t('Cancel');
    const regenerate = document.createElement('button');
    regenerate.textContent = t('Regenerate');
    regenerate.style.display = 'none';   // shown only after a warned result
    const generate = document.createElement('button');
    generate.className = 'primary';
    generate.textContent = t('Generate');
    actions.appendChild(modelLabel);
    actions.appendChild(spacer);
    actions.appendChild(cancel);
    actions.appendChild(regenerate);
    actions.appendChild(generate);

    dialog.appendChild(h);
    dialog.appendChild(instr);
    dialog.appendChild(textarea);
    dialog.appendChild(status);
    dialog.appendChild(actions);
    document.body.appendChild(overlay);
    makeDraggable(dialog, h);   // drag the dialog by its title bar
    setTimeout(() => textarea.focus(), 0);

    const close = () => { overlay.remove(); document.removeEventListener('keydown', onKey); };
    const onKey = (e: KeyboardEvent) => {
        if (e.key === 'Escape') close();
        // Cmd/Ctrl+Enter triggers the primary action (Generate / Insert anyway).
        if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) { e.preventDefault(); generate.click(); }
    };
    document.addEventListener('keydown', onKey);
    cancel.addEventListener('click', close);
    overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });

    if (!model) {
        status.className = 'nl-status warn';
        status.textContent = t('Configure an LLM model first: in the main editor, Misc → API Keys…');
        generate.disabled = true;
    }

    // After a result that verified with NEW issues, the primary button flips to
    // "Insert anyway" so the user can still use the fragment; editing the text or
    // regenerating returns it to "Generate".
    let primaryMode: 'generate' | 'insert' = 'generate';
    let pendingLe = '';
    function toGenerateMode() {
        primaryMode = 'generate';
        generate.textContent = t('Generate');
        regenerate.style.display = 'none';
    }
    textarea.addEventListener('input', () => { if (primaryMode === 'insert') toGenerateMode(); });

    async function run() {
        const sentence = textarea.value.trim();
        if (!sentence) { textarea.focus(); return; }
        if (!assistantModel()) return;
        generate.disabled = true; cancel.disabled = true; regenerate.disabled = true;
        status.className = 'nl-status';
        status.textContent = t('Generating and verifying…');
        const templates = [...new Set(parseTemplateDefs(opts.source).map(d => d.label))];
        try {
            const res = await fetch('/leapi', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    token: TOKEN,
                    operation: 'nl_to_le',
                    kind: opts.kind,
                    sentence,
                    templates,
                    content: opts.source,      // the program, for baseline-diff verification
                    model: assistantModel(),
                    api_keys: assistantKeys(),
                }),
            }).then(r => r.json());
            generate.disabled = false; cancel.disabled = false; regenerate.disabled = false;
            if (res && res.result === 'ok' && typeof res.le === 'string' && res.le.trim()) {
                const warnings: string[] = Array.isArray(res.warnings) ? res.warnings : [];
                if (warnings.length === 0) {
                    opts.onResult(res.le);
                    close();
                } else {
                    // Verified with new issues: warn, but let the user insert anyway.
                    pendingLe = res.le;
                    primaryMode = 'insert';
                    generate.textContent = t('Insert anyway');
                    regenerate.style.display = '';
                    status.className = 'nl-status warn';
                    status.textContent =
                        `Verification found ${warnings.length} new issue${warnings.length === 1 ? '' : 's'} vs. your program:\n`
                        + warnings.map(w => `• ${w}`).join('\n')
                        + '\nYou can insert it anyway, or rephrase and regenerate.';
                }
            } else if (res && res.result === 'ok') {
                toGenerateMode();
                status.className = 'nl-status warn';
                status.textContent = t('The model returned nothing that matches your templates. Try rephrasing.');
            } else {
                toGenerateMode();
                status.className = 'nl-status error';
                status.textContent = t('Error: ') + ((res && res.error) || 'the LLM request failed.');
            }
        } catch {
            generate.disabled = false; cancel.disabled = false; regenerate.disabled = false;
            toGenerateMode();
            status.className = 'nl-status error';
            status.textContent = t('Could not reach the server.');
        }
    }
    generate.addEventListener('click', () => {
        if (primaryMode === 'insert') { opts.onResult(pendingLe); close(); }
        else run();
    });
    regenerate.addEventListener('click', run);
}

// Split generated LE into individual fact statements (period-terminated), tolerant
// of one-per-line output. A period is a separator only at end-of-line or before
// whitespace, so decimals ("3.5") and dates are not split.
export function splitStatements(leText: string): string[] {
    return leText
        .split(/\.(?=\s|$)/)
        .map(s => s.replace(/\s+/g, ' ').trim())
        .filter(Boolean);
}
