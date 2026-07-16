/*
 * i18n.ts — UI chrome internationalization runtime for the LE editor pages.
 *
 * The catalogs are generated from the shared i18n/*.csv dictionaries at build
 * time (see scripts/gen-i18n.cjs). The canonical key of a UI string is its
 * ENGLISH text: t('Save As...') returns the active language's translation or
 * the key itself, so untranslated strings degrade gracefully.
 *
 * The UI language is a user preference (localStorage + cookie, so the
 * server-rendered /login page can honor it too). It is set ONLY by the
 * /multilingual pages — ?lang=X sets X, their back-to-English link resets
 * to English; there is no in-editor selector, to avoid confusion with the
 * language of the program being edited. Per decision O-6 it governs chrome,
 * the default language of NEW programs and the Assistant; a loaded
 * program's own language always governs parsing.
 */
import { uiCatalog, languages, keywords, keywordPhrases, LanguageInfo } from './generated/i18nData';

const STORAGE_KEY = 'le-ui-lang';

export function uiLang(): string {
    try {
        const l = localStorage.getItem(STORAGE_KEY);
        if (l && languages.some(x => x.code === l)) return l;
    } catch (e) { /* no storage (tests) */ }
    return 'en';
}

export function languageList(): LanguageInfo[] {
    return languages;
}

/** Translate a UI chrome string (keyed by its English text). */
export function t(key: string): string {
    const lang = uiLang();
    if (lang === 'en') return key;
    const cat = uiCatalog[lang];
    return (cat && cat[key]) || key;
}

/**
 * Detect the language a program text declares in its first statement,
 * matching the opener phrases of the registry ("the target language is" /
 * "a linguagem alvo é" / ...). Returns 'en' when nothing matches (O-1).
 */
export function detectProgramLanguage(text: string): string {
    // Skip comments and blank lines, look at the first real statement.
    const lines = text.split('\n');
    let firstStatement = '';
    let inBlockComment = false;
    for (const line of lines) {
        let s = line.trim();
        if (inBlockComment) {
            const end = s.indexOf('*/');
            if (end === -1) continue;
            s = s.slice(end + 2).trim();
            inBlockComment = false;
        }
        if (s.startsWith('/*')) {
            const end = s.indexOf('*/');
            if (end === -1) { inBlockComment = true; continue; }
            s = s.slice(end + 2).trim();
        }
        if (!s || s.startsWith('%')) continue;
        firstStatement = s;
        break;
    }
    const norm = firstStatement.toLowerCase().replace(/\s+/g, ' ');
    for (const info of languages) {
        if (info.opener && norm.startsWith(info.opener.toLowerCase())) return info.code;
    }
    return 'en';
}

/** The opener statement for new programs in the given (or UI) language. */
export function targetLanguageStatement(lang?: string): string {
    const code = lang ?? uiLang();
    const info = languages.find(x => x.code === code) ?? languages.find(x => x.code === 'en');
    return `${info ? info.opener : 'the target language is'}: prolog.`;
}

/** Grammar keyword phrases for a language (used by the Monaco tables). */
export function kwPhrases(lang: string, key: string): string[] {
    return keywordPhrases(lang, key);
}

export function kwTable(lang: string) {
    return keywords[lang] ?? keywords['en'];
}

// ---------------------------------------------------------------------------
// DOM application
// ---------------------------------------------------------------------------

const AUTO_SELECTOR = [
    'button', 'label', 'option', 'h1', 'h2', 'h3', 'h4', 'th', 'summary',
    'legend', '.dropdown-item', '.menu-item', '[data-i18n]',
].join(',');

function translateFirstTextNode(el: Element): void {
    for (const node of Array.from(el.childNodes)) {
        if (node.nodeType === Node.TEXT_NODE) {
            const raw = node.textContent ?? '';
            const trimmed = raw.trim();
            if (trimmed) {
                const tr = t(trimmed);
                if (tr !== trimmed) node.textContent = raw.replace(trimmed, tr);
                return;
            }
        }
    }
}

/**
 * Apply the active language to the DOM: elements matching the auto selector
 * get their first text node translated (keyed by its English text — the HTML
 * stays the canonical catalog); title/placeholder attributes likewise.
 * Idempotent only from the English DOM, so pages call it once at load and
 * reload on language change.
 */
export function applyI18nDom(root: ParentNode = document): void {
    if (uiLang() === 'en') return;
    root.querySelectorAll(AUTO_SELECTOR).forEach(el => translateFirstTextNode(el));
    root.querySelectorAll('[title]').forEach(el => {
        const v = el.getAttribute('title');
        if (v) { const tr = t(v.trim()); if (tr !== v.trim()) el.setAttribute('title', tr); }
    });
    root.querySelectorAll('[placeholder]').forEach(el => {
        const v = el.getAttribute('placeholder');
        if (v) { const tr = t(v.trim()); if (tr !== v.trim()) el.setAttribute('placeholder', tr); }
    });
}

// ---------------------------------------------------------------------------
// /leapi language parameter
// ---------------------------------------------------------------------------

/**
 * Patch window.fetch so every /leapi (and REST) call carries the UI language
 * as a ?lang= query parameter — the server localizes its own messages with
 * it. One hook instead of touching every call site.
 */
export function installLeApiLang(): void {
    if (uiLang() === 'en') return;   // English is the server default — no param
    const origFetch = window.fetch.bind(window);
    window.fetch = ((input: RequestInfo | URL, init?: RequestInit) => {
        try {
            const url = typeof input === 'string' ? input : (input as Request).url ?? String(input);
            if (/^\/(leapi|query|verify|list_examples|example_details)\b/.test(url) && !/[?&]lang=/.test(url)) {
                const sep = url.includes('?') ? '&' : '?';
                const newUrl = `${url}${sep}lang=${encodeURIComponent(uiLang())}`;
                if (typeof input === 'string') return origFetch(newUrl, init);
                return origFetch(new Request(newUrl, input as Request), init);
            }
        } catch (e) { /* fall through to the original call */ }
        return origFetch(input as any, init);
    }) as typeof window.fetch;
}

