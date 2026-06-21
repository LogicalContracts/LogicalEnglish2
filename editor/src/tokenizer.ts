export enum TokenType {
    Indent,
    Word,
    Number,
    Punctuation,
    Date,
    String,
    Comment
}

export interface Token {
    type: TokenType;
    value: string | number;
    start: number;
    end: number;
}

// The index of the end of the line containing position `from` (the next newline,
// or the text length if there is none).
function lineEndFrom(text: string, from: number): number {
    const nl = text.indexOf('\n', from);
    return nl === -1 ? text.length : nl;
}

export function tokenize(text: string): Token[] {
    const tokens: Token[] = [];
    let i = 0;
    let lineStart = true;

    while (i < text.length) {
        const char = text[i];

        // Handle Newlines
        if (char === '\n') {
            i++;
            lineStart = true;
            continue;
        }

        // Handle Indent
        if (lineStart) {
            let indent = 0;
            const start = i;
            while (i < text.length && (text[i] === ' ' || text[i] === '\t')) {
                if (text[i] === '\t') indent += 8;
                else indent += 1;
                i++;
            }
            if (indent > 0) {
                tokens.push({ type: TokenType.Indent, value: indent, start, end: i });
            }
            lineStart = false;
            continue;
        }

        // Skip whitespace
        if (/\s/.test(char)) {
            i++;
            continue;
        }

        const start = i;

        // Multi-character Punctuation
        const multiPunct = text.substring(i, i + 2);
        if (['>=', '<=', '=<', '==', '!='].includes(multiPunct)) {
            tokens.push({ type: TokenType.Punctuation, value: multiPunct, start, end: i + 2 });
            i += 2;
            continue;
        }

        // Multi-line Comment
        if (text.startsWith('/*', i)) {
            const endIdx = text.indexOf('*/', i + 2);
            if (endIdx !== -1) {
                const content = text.substring(i + 2, endIdx);
                tokens.push({ type: TokenType.Comment, value: content, start, end: endIdx + 2 });
                i = endIdx + 2;
            } else {
                tokens.push({ type: TokenType.Comment, value: text.substring(i + 2), start, end: text.length });
                i = text.length;
            }
            continue;
        }

        // Single-line Comment
        if (char === '%') {
            const endIdx = text.indexOf('\n', i + 1);
            const actualEnd = endIdx === -1 ? text.length : endIdx;
            const content = text.substring(i + 1, actualEnd);
            tokens.push({ type: TokenType.Comment, value: content, start, end: actualEnd });
            i = actualEnd;
            continue;
        }

        // Date: YYYY-MM-DD
        const dateMatch = text.substring(i).match(/^\d{4}-\d{2}-\d{2}/);
        if (dateMatch) {
            tokens.push({ type: TokenType.Date, value: dateMatch[0], start, end: i + dateMatch[0].length });
            i += dateMatch[0].length;
            continue;
        }

        // Double-quoted String
        if (char === '"') {
            const endIdx = text.indexOf('"', i + 1);
            if (endIdx !== -1) {
                const content = text.substring(i + 1, endIdx);
                tokens.push({ type: TokenType.String, value: content, start, end: endIdx + 1 });
                i = endIdx + 1;
            } else {
                tokens.push({ type: TokenType.String, value: text.substring(i + 1), start, end: text.length });
                i = text.length;
            }
            continue;
        }

        // Single-quoted String. A single quote opens a string only when it has a
        // matching quote later on the SAME line; otherwise it is a lone apostrophe
        // (e.g. "employers'", "don't") and we fall through so the word rule can
        // absorb it. Mirrors the Prolog tokenizer.
        if (char === "'") {
            const endIdx = text.indexOf("'", i + 1);
            if (endIdx !== -1 && endIdx < lineEndFrom(text, i)) {
                const content = text.substring(i + 1, endIdx);
                tokens.push({ type: TokenType.String, value: content, start, end: endIdx + 1 });
                i = endIdx + 1;
                continue;
            }
            // else: lone apostrophe — fall through
        }

        // Number, with optional thousands separators (e.g. 10,000,000).
        // A ",ddd" group only counts when those 3 digits are not followed by a
        // 4th digit, so "1,2345" stays as 1 followed by a comma, never 1234.
        const numMatch = text.substring(i).match(/^\d+(?:,\d{3}(?!\d))*(?:\.\d+)?/);
        if (numMatch) {
            const value = parseFloat(numMatch[0].replace(/,/g, ''));
            tokens.push({ type: TokenType.Number, value, start, end: i + numMatch[0].length });
            i += numMatch[0].length;
            continue;
        }

        // Word. May contain a single apostrophe (e.g. "employers'", "don't") when
        // that apostrophe is lone — no matching quote before the end of the line —
        // so it does not start a string. Mirrors the Prolog tokenizer.
        const wordMatch = text.substring(i).match(/^[a-zA-Z][a-zA-Z0-9_]*/);
        if (wordMatch) {
            let end = i + wordMatch[0].length;
            if (text[end] === "'") {
                const nextQuote = text.indexOf("'", end + 1);
                const lineEnd = lineEndFrom(text, end);
                if (nextQuote === -1 || nextQuote >= lineEnd) {
                    end++; // absorb the lone apostrophe
                    const tail = text.substring(end).match(/^[a-zA-Z0-9_]*/);
                    if (tail) end += tail[0].length;
                }
            }
            tokens.push({ type: TokenType.Word, value: text.substring(i, end), start, end });
            i = end;
            continue;
        }

        // Fallback: Single Punctuation
        if (/[!@#$%^&*()\-+={}\[\]:;"'<>,.?\/|\\~]/.test(char)) {
            tokens.push({ type: TokenType.Punctuation, value: char, start, end: i + 1 });
            i++;
            continue;
        }

        i++;
    }

    return tokens;
}
