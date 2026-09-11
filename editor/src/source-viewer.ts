// The source of a fact or a rule: the document its provenance cites, with the
// quoted passage highlighted.
//
// A fact's provenance ("as stated in ruling NY N362700 at "a zipper garage at
// the top of the collar"") and a rule label's ("rule note_61_4 with provenance
// as stated in ... at ...") reach the explanation tree as a `provenance` dict
// (classic_web_api.pl, add_provenance_json/3): document, locator, quote (the
// text inside a quoted locator), source, rationale, `url` — where the document
// is published — and `text` — where its plain text is, as the program says
// with `the text of <document> is at <address>`. This window shows all of it,
// fetches the text through the server (documentText) and marks the quote.
// Nothing here knows any particular kind of document.

import { t } from './i18n';

const TOKEN = 'myToken123';

export interface Provenance {
    source?: string | null;
    document?: string | null;
    locator?: string | null;
    quote?: string | null;
    rationale?: string | null;
    url?: string | null;
    text?: string | null;
}

// Where the program was opened from, so the server can resolve a text address
// relative to the program's folder.
export interface DocumentContext {
    source?: string;    // the example name (?example=)
    base?: string;      // the base URL of a program fetched from a URL
}

// One line summary, for tooltips.
export function provenanceSummary(p: Provenance, rule?: string): string {
    const parts: string[] = [];
    if (rule) parts.push(`${t('rule')} ${rule}`);
    if (p.document) parts.push(p.document + (p.locator ? ` — ${p.locator}` : ''));
    if (p.source) parts.push(`${t('according to')} ${p.source}`);
    if (p.rationale) parts.push(`${t('because')} ${p.rationale}`);
    return parts.join('\n');
}

// The address to open in the browser: the published address, taken to the
// quoted passage with a text fragment when the address has no anchor of its
// own (browsers that support text fragments scroll to and highlight it on
// HTML pages; elsewhere the fragment is ignored).
export function originalUrl(p: Provenance): string | null {
    if (!p.url) return null;
    if (p.quote && !p.url.includes('#')) {
        return `${p.url}#:~:text=${encodeURIComponent(p.quote)}`;
    }
    return p.url;
}

// Find `quote` in `text`, ignoring differences in white space (and, failing
// that, in letter case). Returns [start, end) offsets into `text`, or null.
export function findQuote(text: string, quote: string): [number, number] | null {
    const norm: string[] = [];
    const map: number[] = [];          // normalized index -> original index
    let lastSpace = true;
    for (let i = 0; i < text.length; i++) {
        const c = text[i];
        if (/\s/.test(c)) {
            if (!lastSpace) { norm.push(' '); map.push(i); lastSpace = true; }
        } else {
            norm.push(c); map.push(i); lastSpace = false;
        }
    }
    const hay = norm.join('');
    const needle = quote.replace(/\s+/g, ' ').trim();
    if (!needle) return null;
    let at = hay.indexOf(needle);
    if (at < 0) at = hay.toLowerCase().indexOf(needle.toLowerCase());
    if (at < 0) return null;
    const start = map[at];
    const end = map[at + needle.length - 1] + 1;
    return [start, end];
}

function ensureStyles() {
    if (document.getElementById('source-viewer-styles')) return;
    const style = document.createElement('style');
    style.id = 'source-viewer-styles';
    style.textContent = `
        .sv-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: flex;
            align-items: center; justify-content: center; z-index: 1000; }
        .sv-dialog { background: var(--panel-bg, #252526); color: var(--text-color, #d4d4d4);
            border: 1px solid var(--border-color, #444); border-radius: 8px; width: min(820px, 94vw);
            max-height: 90vh; display: flex; flex-direction: column; padding: 16px 18px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.5); }
        .sv-dialog h2 { margin: 0 0 6px 0; font-size: 16px; }
        .sv-meta { font-size: 12px; line-height: 1.5; margin: 0 0 8px 0; }
        .sv-meta div { margin: 2px 0; }
        .sv-meta .sv-label { color: var(--muted, #888); margin-right: 6px; }
        .sv-text { flex: 1; overflow: auto; white-space: pre-wrap; font-family: inherit; font-size: 13px;
            background: var(--field-bg, #1e1e1e); border: 1px solid var(--input-border, #555);
            border-radius: 4px; padding: 10px; margin: 0; min-height: 120px; }
        .sv-text mark { background: #e2b93d; color: #000; }
        .sv-status { font-size: 12px; color: var(--muted, #888); margin: 6px 0; }
        .sv-actions { display: flex; gap: 10px; justify-content: flex-end; margin-top: 12px; }
        .sv-dialog button { background: var(--input-bg, #3c3c3c); color: var(--input-text, #d4d4d4);
            border: 1px solid var(--input-border, #555); border-radius: 4px; padding: 6px 12px; font: inherit; cursor: pointer; }
        .sv-dialog button.primary { background: var(--accent, #0e639c); color: #fff; border-color: var(--accent, #0e639c); }
    `;
    document.head.appendChild(style);
}

// Ask the server for the text at `address` (a URL, or a path relative to the
// program's folder).
export async function fetchDocumentText(address: string, ctx: DocumentContext = {}):
        Promise<{ text?: string; error?: string }> {
    try {
        return await fetch('/leapi', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ token: TOKEN, operation: 'documentText', address,
                                   source: ctx.source || '', base: ctx.base || '' }),
        }).then(r => r.json());
    } catch {
        return { error: t('Could not reach the server.') };
    }
}

export function openSourceViewer(p: Provenance, rule: string | undefined, ctx: DocumentContext = {}): void {
    ensureStyles();
    const overlay = document.createElement('div');
    overlay.className = 'sv-overlay';
    const dialog = document.createElement('div');
    dialog.className = 'sv-dialog';
    dialog.id = 'source-viewer';
    overlay.appendChild(dialog);

    const h = document.createElement('h2');
    h.textContent = p.document || t('Source');
    dialog.appendChild(h);

    const meta = document.createElement('div');
    meta.className = 'sv-meta';
    const addMeta = (label: string, value: string | null | undefined) => {
        if (!value) return;
        const row = document.createElement('div');
        const l = document.createElement('span');
        l.className = 'sv-label';
        l.textContent = label;
        row.appendChild(l);
        row.appendChild(document.createTextNode(value));
        meta.appendChild(row);
    };
    addMeta(t('rule'), rule);
    addMeta(t('at'), p.locator);
    addMeta(t('according to'), p.source);
    addMeta(t('because'), p.rationale);
    addMeta(t('Published at'), p.url);
    dialog.appendChild(meta);

    const status = document.createElement('div');
    status.className = 'sv-status';
    const pre = document.createElement('pre');
    pre.className = 'sv-text';
    pre.style.display = 'none';
    dialog.appendChild(status);
    dialog.appendChild(pre);

    const actions = document.createElement('div');
    actions.className = 'sv-actions';
    const open = originalUrl(p);
    if (open) {
        const btnOpen = document.createElement('button');
        btnOpen.textContent = t('Open original');
        btnOpen.addEventListener('click', () => window.open(open, '_blank'));
        actions.appendChild(btnOpen);
    }
    const close = document.createElement('button');
    close.className = 'primary';
    close.textContent = t('Close');
    actions.appendChild(close);
    dialog.appendChild(actions);
    document.body.appendChild(overlay);

    const done = () => { overlay.remove(); document.removeEventListener('keydown', onKey); };
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') done(); };
    document.addEventListener('keydown', onKey);
    close.addEventListener('click', done);
    overlay.addEventListener('click', (e) => { if (e.target === overlay) done(); });

    if (!p.text) {
        status.textContent = p.document
            ? `${t('The program does not say where the text of this document is')}: the text of ${p.document} is at "…".`
            : '';
        return;
    }
    status.textContent = t('Loading the document…');
    fetchDocumentText(p.text, ctx).then(res => {
        if (!res || res.error || typeof res.text !== 'string') {
            status.textContent = `${t('Error: ')}${(res && res.error) || ''}`;
            return;
        }
        const text = res.text;
        const span = p.quote ? findQuote(text, p.quote) : null;
        pre.textContent = '';
        if (span) {
            pre.appendChild(document.createTextNode(text.slice(0, span[0])));
            const mark = document.createElement('mark');
            mark.textContent = text.slice(span[0], span[1]);
            pre.appendChild(mark);
            pre.appendChild(document.createTextNode(text.slice(span[1])));
            status.textContent = '';
            pre.style.display = '';
            mark.scrollIntoView({ block: 'center' });
        } else {
            pre.textContent = text;
            pre.style.display = '';
            status.textContent = p.quote ? t('The quoted passage was not found in this text.') : '';
        }
    });
}
