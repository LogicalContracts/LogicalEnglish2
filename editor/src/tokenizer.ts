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

        // Quoted String
        if (char === '"' || char === "'") {
            const quote = char;
            let endIdx = text.indexOf(quote, i + 1);
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

        // Number
        const numMatch = text.substring(i).match(/^\d+(\.\d+)?/);
        if (numMatch) {
            tokens.push({ type: TokenType.Number, value: parseFloat(numMatch[0]), start, end: i + numMatch[0].length });
            i += numMatch[0].length;
            continue;
        }

        // Word
        const wordMatch = text.substring(i).match(/^[a-zA-Z][a-zA-Z0-9_]*/);
        if (wordMatch) {
            tokens.push({ type: TokenType.Word, value: wordMatch[0], start, end: i + wordMatch[0].length });
            i += wordMatch[0].length;
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
