import {
    createConnection,
    TextDocuments,
    Diagnostic,
    DiagnosticSeverity,
    InitializeParams,
    TextDocumentSyncKind,
    InitializeResult,
    BrowserMessageReader,
    BrowserMessageWriter,
    FoldingRange,
    FoldingRangeKind
} from 'vscode-languageserver/browser';

import { TextDocument } from 'vscode-languageserver-textdocument';
import { tokenize, TokenType, Token } from './tokenizer';

const messageReader = new BrowserMessageReader(self);
const messageWriter = new BrowserMessageWriter(self);

const connection = createConnection(messageReader, messageWriter);

const documents: TextDocuments<TextDocument> = new TextDocuments(TextDocument);

connection.onInitialize((params: InitializeParams): InitializeResult => {
    return {
        capabilities: {
            textDocumentSync: TextDocumentSyncKind.Full,
            completionProvider: {
                resolveProvider: true,
                triggerCharacters: [' ', '*']
            },
            hoverProvider: true,
            foldingRangeProvider: true,
            semanticTokensProvider: {
                legend: {
                    tokenTypes: ['keyword', 'variable', 'string', 'number', 'comment', 'type', 'templateWord'],
                    tokenModifiers: []
                },
                full: true
            }
        }
    };
});

connection.onRequest('textDocument/semanticTokens/full', (params) => {
    const document = documents.get(params.textDocument.uri);
    if (!document) return { data: [] };

    const text = document.getText();
    const templates = getTemplates(text);
    const tokens: { start: number, length: number, typeIndex: number }[] = [];

    // Pattern for what can be an argument in a template instance
    // Improved to allow multiple words (e.g. "the coloring for OBJECTID")
    const argPattern = '(?:(?:a|an|the|each|some|which|what)\\s+[a-zA-Z][a-zA-Z0-9_\\s]*?|[a-zA-Z_][a-zA-Z0-9_]*|\\*[^*]+\\*|\\d+(?:\\.\\d+)?|\\d{4}-\\d{2}-\\d{2}|"[^"]*"|\'[^\']*\')';

    // 1. Find all template instances
    const sortedTemplates = [...templates].sort((a, b) => b.label.length - a.label.length);
    
    for (const template of sortedTemplates) {
        const parts = template.label.split(/\*[^*]+\*/);
        if (parts.length < 2) continue;

        const regexParts = parts.map(p => p.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\s+/g, '\\s+'));
        
        let regexStr = '';
        for (let i = 0; i < regexParts.length; i++) {
            if (i > 0) {
                regexStr += '(' + argPattern + ')';
            }
            if (regexParts[i]) {
                regexStr += (i > 0 ? '\\s+' : '') + regexParts[i] + (i < regexParts.length - 1 ? '\\s+' : '');
            }
        }
        
        try {
            const regex = new RegExp('\\b' + regexStr.trim() + '\\b', 'gi');
            let match;
            while ((match = regex.exec(text)) !== null) {
                if (match[0].includes('*')) continue; // Skip template definitions
                
                let currentOffset = match.index;
                const fullMatch = match[0];
                
                let lastIndex = 0;
                for (let i = 0; i < parts.length; i++) {
                    const part = parts[i].trim();
                    if (part) {
                        const escapedPart = part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\s+/g, '\\s+');
                        const partRegex = new RegExp(escapedPart, 'gi');
                        const partMatch = partRegex.exec(fullMatch);
                        if (partMatch) {
                            tokens.push({ start: currentOffset + partMatch.index, length: partMatch[0].length, typeIndex: 6 }); // templateWord
                            lastIndex = partMatch.index + partMatch[0].length;
                        }
                    }
                    if (i < parts.length - 1) {
                        const varText = match[i + 1];
                        if (varText) {
                            const varIndex = fullMatch.indexOf(varText, lastIndex);
                            if (varIndex !== -1) {
                                tokens.push({ start: currentOffset + varIndex, length: varText.length, typeIndex: 1 }); // variable
                                lastIndex = varIndex + varText.length;
                            }
                        }
                    }
                }
            }
        } catch (e) {
            console.error('Regex error for template:', template.label, e);
        }
    }

    // Sort tokens by start position, then by length descending
    tokens.sort((a, b) => {
        if (a.start !== b.start) return a.start - b.start;
        return b.length - a.length;
    });

    // Remove overlapping tokens (keep the longest one starting at each position)
    const uniqueTokens: typeof tokens = [];
    let lastEnd = -1;
    for (const token of tokens) {
        if (token.start >= lastEnd) {
            uniqueTokens.push(token);
            lastEnd = token.start + token.length;
        }
    }

    const data: number[] = [];
    let lastLine = 0;
    let lastChar = 0;

    for (const token of uniqueTokens) {
        const pos = document.positionAt(token.start);
        const line = pos.line;
        const char = pos.character;

        const deltaLine = line - lastLine;
        const deltaChar = deltaLine === 0 ? char - lastChar : char;

        data.push(deltaLine, deltaChar, token.length, token.typeIndex, 0);

        lastLine = line;
        lastChar = char;
    }

    return { data };
});

// Use connection.onRequest directly to avoid "onFoldingRange is not a function" error
// This is the most reliable way to register handlers in the browser-based server
connection.onRequest('textDocument/foldingRange', (params) => {
    const document = documents.get(params.textDocument.uri);
    if (!document) return null;

    const text = document.getText();
    const lines = text.split('\n');
    const foldingRanges: FoldingRange[] = [];

    const sectionHeaderRegex = /^\s*(the knowledge base|the contract|scenario|query|the ontology|the predicates|the templates|the fluents|the events|the target language)/i;

    let lastHeaderLine = -1;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const isHeader = sectionHeaderRegex.test(line);

        if (isHeader) {
            if (lastHeaderLine !== -1) {
                const endLine = i - 1;
                if (endLine > lastHeaderLine) {
                    foldingRanges.push({
                        startLine: lastHeaderLine,
                        endLine: endLine,
                        kind: FoldingRangeKind.Region
                    });
                }
            }
            lastHeaderLine = i;
        } else if (line.trim().length > 0 && !/^\s/.test(line)) {
            // Rule head or template (not indented)
            let j = i + 1;
            let hasIndented = false;
            let lastContentLine = i;
            while (j < lines.length) {
                const nextLine = lines[j];
                if (sectionHeaderRegex.test(nextLine)) break;
                if (nextLine.trim().length > 0) {
                    if (/^\s/.test(nextLine)) {
                        hasIndented = true;
                        lastContentLine = j;
                        j++;
                    } else {
                        break; // Next rule or something else
                    }
                } else {
                    j++; // Skip empty lines
                }
            }
            if (hasIndented && lastContentLine > i) {
                foldingRanges.push({
                    startLine: i,
                    endLine: lastContentLine,
                    kind: FoldingRangeKind.Region
                });
            }
        }
    }

    if (lastHeaderLine !== -1) {
        const endLine = lines.length - 1;
        if (endLine > lastHeaderLine) {
            foldingRanges.push({
                startLine: lastHeaderLine,
                endLine: endLine,
                kind: FoldingRangeKind.Region
            });
        }
    }

    return foldingRanges;
});

documents.onDidChangeContent(change => {
    validateTextDocument(change.document);
});

async function validateTextDocument(textDocument: TextDocument): Promise<void> {
    const text = textDocument.getText();
    const tokens = tokenize(text);
    const diagnostics: Diagnostic[] = [];

    for (const token of tokens) {
        if (token.type === TokenType.String && !text.substring(token.start, token.end).endsWith(text[token.start])) {
            diagnostics.push({
                severity: DiagnosticSeverity.Error,
                range: {
                    start: textDocument.positionAt(token.start),
                    end: textDocument.positionAt(token.end)
                },
                message: 'Unclosed string',
                source: 'LE LSP'
            });
        }
    }

    connection.sendDiagnostics({ uri: textDocument.uri, diagnostics });
}

interface Template {
    label: string;
    insertText: string;
    detail: string;
}

function getTemplates(text: string): Template[] {
    const templates: Template[] = [];
    const sectionHeaderRegex = /^the (knowledge base|scenario|query|ontology|predicates|templates|fluents|events|target language)/im;
    const templateHeaderRegex = /the (predicates|templates|fluents|events) are:/gi;
    
    let match;
    while ((match = templateHeaderRegex.exec(text)) !== null) {
        const start = match.index + match[0].length;
        const remaining = text.substring(start);
        const nextSectionMatch = remaining.match(sectionHeaderRegex);
        const sectionText = nextSectionMatch ? remaining.substring(0, nextSectionMatch.index) : remaining;
        
        const lines = sectionText.split('\n');
        for (const line of lines) {
            const trimmed = line.trim();
            if (trimmed && !trimmed.startsWith('%')) {
                const clean = trimmed.replace(/[.,;]$/, '');
                templates.push({
                    label: clean,
                    insertText: clean.replace(/\*/g, ''),
                    detail: 'User Template'
                });
            }
        }
    }

    const systemTemplates = [
        { label: '*V1* is equal to *V2*', insertText: 'V1 is equal to V2', detail: 'System Template' },
        { label: '*V1* is greater than or equal to *V2*', insertText: 'V1 is greater than or equal to V2', detail: 'System Template' },
        { label: '*V1* is less than or equal to *V2*', insertText: 'V1 is less than or equal to V2', detail: 'System Template' },
        { label: '*V1* is greater than *V2*', insertText: 'V1 is greater than *V2', detail: 'System Template' },
        { label: '*V1* is less than *V2*', insertText: 'V1 is less than *V2', detail: 'System Template' },
        { label: '*V1* is after or equal to *V2*', insertText: 'V1 is after or equal to V2', detail: 'System Template' },
        { label: '*V1* is before or equal to *V2*', insertText: 'V1 is before or equal to V2', detail: 'System Template' },
        { label: '*V1* is after *V2*', insertText: 'V1 is after *V2', detail: 'System Template' },
        { label: '*V1* is before *V2*', insertText: 'V1 is before *V2', detail: 'System Template' },
        { label: '*V1* is known', insertText: 'V1 is known', detail: 'System Template' },
        { label: '*V1* = *V2*', insertText: 'V1 = V2', detail: 'System Template' },
        { label: '*V1* is a *V2*', insertText: 'V1 is a V2', detail: 'System Template' },
        { label: '*V1* is an *V2*', insertText: 'V1 is an V2', detail: 'System Template' },
        { label: '*V1* is *V2*', insertText: 'V1 = V2', detail: 'System Template' },
        { label: '*V1* are *V2*', insertText: 'V1 are V2', detail: 'System Template' },
        { label: '*V1* is in *V2*', insertText: 'V1 is in V2', detail: 'System Template' }
    ];
    
    return [...templates, ...systemTemplates];
}

connection.onCompletion((params) => {
    const document = documents.get(params.textDocument.uri);
    const text = document ? document.getText() : '';
    const templates = getTemplates(text);
    
    const sectionCompletions = [
        { label: 'the knowledge base includes:', kind: 14 },
        { label: 'the contract states that:', kind: 14 },
        { label: 'scenario is:', kind: 14 },
        { label: 'query is:', kind: 14 },
        { label: 'the predicates are:', kind: 14 },
        { label: 'the templates are:', kind: 14 },
        { label: 'the ontology is:', kind: 14 },
        { label: 'the target language is: prolog.', kind: 14 }
    ];

    const templateCompletions = templates.map(t => ({
        label: t.label,
        kind: 7,
        insertText: t.insertText,
        detail: t.detail
    }));

    const keywords = [
        { label: 'if', kind: 14 },
        { label: 'and', kind: 14 },
        { label: 'or', kind: 14 },
        { label: 'either', kind: 14 },
        { label: 'any of', kind: 14 },
        { label: 'all of', kind: 14 },
        { label: 'unless', kind: 14 },
        { label: 'for all cases in which', kind: 14 },
        { label: 'it is the case that', kind: 14 },
        { label: 'it is not the case that', kind: 14 },
        { label: 'sum', kind: 14 },
        { label: 'count', kind: 14 }
    ];

    return [...sectionCompletions, ...templateCompletions, ...keywords];
});

connection.onHover((params) => {
    const document = documents.get(params.textDocument.uri);
    if (!document) return null;

    const text = document.getText();
    const offset = document.offsetAt(params.position);
    const tokens = tokenize(text);
    const token = tokens.find(t => t.start <= offset && t.end >= offset);

    if (token) {
        let leType = 'Unknown';
        let description = '';

        // 1. Check if it's part of a template instance first
        const templates = getTemplates(text);
        let templateMatch = null;
        
        // Sort templates by length descending to find the most specific match
        const sortedTemplates = [...templates].sort((a, b) => b.label.length - a.label.length);
        
        for (const template of sortedTemplates) {
            const parts = template.label.split(/\*[^*]+\*/);
            if (parts.length < 2) continue;

            const regexParts = parts.map(p => p.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\s+/g, '\\s+'));
            const regexStr = '\\b' + regexParts.join('\\s+(' + argPattern + ')\\s*') + '\\b';
            try {
                const regex = new RegExp(regexStr, 'gi');
                let match;
                while ((match = regex.exec(text)) !== null) {
                    const matchStart = match.index;
                    const matchEnd = match.index + match[0].length;
                    
                    if (offset >= matchStart && offset < matchEnd) {
                        // We are inside a template instance. Now check if we are on a template word or a variable.
                        let isVariable = false;
                        for (let i = 1; i < match.length; i++) {
                            const varText = match[i];
                            if (varText) {
                                const varStart = text.indexOf(varText, matchStart); // Approximation
                                if (offset >= varStart && offset < varStart + varText.length) {
                                    isVariable = true;
                                    break;
                                }
                            }
                        }
                        
                        if (isVariable) {
                            leType = 'Variable / Argument';
                            description = 'A variable placeholder within a template instance.';
                        } else {
                            leType = 'Template Word';
                            description = `Part of the template: \`${template.label}\``;
                        }
                        templateMatch = template;
                        break;
                    }
                }
                if (templateMatch) break;
            } catch (e) {}
        }

        if (!templateMatch) {
            // Map internal token types to LE concepts if not part of a template
            switch (token.type) {
                case TokenType.Word:
                    const word = String(token.value);
                    const keywords = ['includes', 'if', 'and', 'or', 'either', 'any of', 'all of', 'unless', 'which', 'sum', 'count', 'average', 'min', 'max', 'is', 'are', 'a', 'an', 'the', 'such that'];
                    const headers = ['knowledge', 'base', 'scenario', 'query', 'ontology', 'predicates', 'templates', 'fluents', 'events', 'target', 'language'];
                    
                    if (keywords.includes(word.toLowerCase())) {
                        leType = 'Logical Keyword';
                        description = `The keyword \`${word}\` is used to define the logical structure of rules.`;
                    } else if (headers.includes(word.toLowerCase())) {
                        leType = 'Section Header';
                        description = 'Part of a section declaration (e.g., `the knowledge base includes:`).';
                    } else {
                        leType = 'Word';
                        description = 'A natural language word or constant.';
                    }
                    break;
                case TokenType.Number:
                    leType = 'Number';
                    description = 'A numeric constant.';
                    break;
                case TokenType.Date:
                    leType = 'Date';
                    description = 'A date constant in `YYYY-MM-DD` format.';
                    break;
                case TokenType.String:
                    leType = 'String';
                    description = 'A quoted string constant.';
                    break;
                case TokenType.Comment:
                    leType = 'Comment';
                    description = 'Text ignored by the Logical English reasoner.';
                    break;
                case TokenType.Punctuation:
                    leType = 'Punctuation';
                    description = 'Structural punctuation used for grouping or delimiting.';
                    break;
                case TokenType.Indent:
                    leType = 'Indentation';
                    description = 'Used to define the hierarchy and scope of rule conditions.';
                    break;
            }

            // Check if it's a variable (starts with article or is in *...*)
            const textAtToken = text.substring(token.start, token.end);
            if (textAtToken.startsWith('*') && textAtToken.endsWith('*')) {
                leType = 'Variable';
                description = 'A named variable placeholder.';
            }
        }

        return {
            contents: {
                kind: 'markdown',
                value: `### LE ${leType}\n\n${description}\n\n**Value**: \`${token.value}\``
            }
        };
    }
    return null;
});

documents.listen(connection);
connection.listen();
