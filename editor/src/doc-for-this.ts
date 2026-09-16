/**
 * "Documentation for this" (the editor's context menu): the documentation
 * about what is under the cursor, found by the documentation's search
 * (web_extras/docsview/docs-extras.js, /docs/search).
 *
 * What is searched for depends on the token's *class*, not only its text: a
 * variable `X` or `a person` is looked up as "variables", a date as "dates",
 * a keyword (`if`, `it is not the case that`, `the templates are`) as that
 * phrase, a word of one of the program's own templates as "templates". The
 * token itself is offered as a search of its own on the results page.
 */
import { t } from './i18n';

declare var monaco: any;

export interface DocQuery {
    /** The search. */
    q: string;
    /** What was asked about, for the results page. */
    about: string;
    /** The token's text. */
    word: string;
}

/** The token classes of the LE grammar (le-language.ts), as searches. */
const CONCEPTS: Array<[RegExp, string, string]> = [
    // [token type, search, what it is]
    [/^comment\.todo/, 'TODO', 'a TODO comment'],
    [/^comment/, 'comments', 'a comment'],
    [/^string/, 'strings', 'a string'],
    [/^number\.date/, 'dates', 'a date'],
    [/^number/, 'numbers', 'a number'],
    [/^variable/, 'variables', 'a variable'],
    [/^templateWord/, 'templates', 'a word of a template'],
    [/^text/, 'templates', 'a word of a template'],
    [/^operator/, 'comparison', 'an operator'],
];

/**
 * The search for the token at `position` of `model` (or for the selection,
 * when there is one). `languageId` is the model's language ('le').
 */
export function docQueryAt(model: any, position: any, selection: any, languageId: string): DocQuery | null {
    const selected = selection && !selection.isEmpty() ? model.getValueInRange(selection).trim() : '';
    const lineNo = selection && !selection.isEmpty() ? selection.startLineNumber : position.lineNumber;
    const column = selection && !selection.isEmpty() ? selection.startColumn : position.column;
    // Monarch keeps state across lines (a templates section): tokenize from
    // the start, up to this line.
    const first = Math.max(1, lineNo - 400);
    const lines: string[] = [];
    for (let i = first; i <= lineNo; i++) lines.push(model.getLineContent(i));
    let tokens: any[] = [];
    try {
        tokens = monaco.editor.tokenize(lines.join('\n'), languageId)[lines.length - 1] ?? [];
    } catch { /* no tokenizer: the text alone */ }
    const text = lines[lines.length - 1];
    let token: { type: string; text: string } | null = null;
    for (let i = 0; i < tokens.length; i++) {
        const start = tokens[i].offset;
        const end = i + 1 < tokens.length ? tokens[i + 1].offset : text.length;
        // columns are 1-based; the cursor may sit just after the token
        if (column - 1 >= start && column - 1 <= end) {
            const tokText = text.slice(start, end);
            if (tokText.trim() === '') continue;
            token = { type: String(tokens[i].type).replace(/\.le$/, '').replace(new RegExp(`\\.${languageId}$`), ''), text: tokText.trim() };
            if (column - 1 < end) break;
        }
    }
    // A selection wider than its token is searched as written.
    if (selected && (!token || selected.length > token.text.length || !token.text.includes(selected))) {
        return { q: `"${selected.replace(/"/g, '')}"`, about: t('Documentation for “{w}”').replace('{w}', selected), word: selected };
    }
    if (!token || !token.text) {
        const w = model.getWordAtPosition(position)?.word;
        return w ? { q: w, about: t('Documentation for “{w}”').replace('{w}', w), word: w } : null;
    }
    if (!/^(comment|string)/i.test(token.type)) {
        // The grammar reads digits as words: a date or a number is found on the line.
        const at = (re: RegExp) => {
            for (const m of text.matchAll(re)) {
                if (column - 1 >= m.index! && column - 1 <= m.index! + m[0].length) return m[0];
            }
            return null;
        };
        const date = at(/\d{4}-\d{2}-\d{2}(?:T[\d:]+)?/g);
        if (date) return { q: 'dates', about: t('Documentation for “{w}”, {what}').replace('{w}', date).replace('{what}', t('a date')), word: date };
        const num = at(/(?<![\p{L}_])\d+(?:[.,]\d+)?(?![\p{L}_])/gu);
        if (num) return { q: 'numbers', about: t('Documentation for “{w}”, {what}').replace('{w}', num).replace('{what}', t('a number')), word: num };
    }
    const word = selected
        || (/^comment/i.test(token.type) ? token.text.replace(/^%\s*/, '').slice(0, 40)
                                         : token.text.replace(/[:.]$/, '').replace(/^\*|\*$/g, ''));
    if (/^keyword/i.test(token.type)) {
        return { q: `"${word}"`, about: t('Documentation for “{w}”, a keyword').replace('{w}', word), word };
    }
    for (const [re, q, what] of CONCEPTS) {
        if (new RegExp(re.source, 'i').test(token.type)) {
            return { q, about: t('Documentation for “{w}”, {what}').replace('{w}', word).replace('{what}', t(what)), word };
        }
    }
    return { q: word, about: t('Documentation for “{w}”').replace('{w}', word), word };
}

/** Opens the results of `query` in a new tab. */
export function openDocQuery(query: DocQuery): void {
    const p = new URLSearchParams({ q: query.q, about: query.about, word: query.word });
    window.open(`/docs/search?${p.toString()}`, '_blank', 'noopener');
}
