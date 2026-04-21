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
            foldingRangeProvider: true
        }
    };
});

// Use connection.onRequest directly to avoid "onFoldingRange is not a function" error
// This is the most reliable way to register handlers in the browser-based server
connection.onRequest('textDocument/foldingRange', (params) => {
    const document = documents.get(params.textDocument.uri);
    if (!document) return null;

    const text = document.getText();
    const lines = text.split('\n');
    const foldingRanges: FoldingRange[] = [];

    const sectionHeaderRegex = /^\s*(the knowledge base|scenario|query|the ontology|the predicates|the templates|the fluents|the events|the target language)/i;

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
    const templateSections = text.match(/(?:the predicates|the templates|the fluents|the events) are:([\s\S]*?)(?=\n\w|$)/g);
    if (templateSections) {
        for (const section of templateSections) {
            const lines = section.split('\n');
            for (const line of lines) {
                const trimmed = line.trim();
                if (trimmed && !trimmed.startsWith('%') && !trimmed.includes('are:')) {
                    const clean = trimmed.replace(/[.,;]$/, '');
                    templates.push({
                        label: clean,
                        insertText: clean.replace(/\*/g, ''),
                        detail: 'User Template'
                    });
                }
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
        { label: '*V1* is *V2*', insertText: 'V1 = V2', detail: 'System Template' },
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
        return {
            contents: {
                kind: 'markdown',
                value: `**Token Type**: ${TokenType[token.type]}\n\n**Value**: \`${token.value}\``
            }
        };
    }
    return null;
});

documents.listen(connection);
connection.listen();
