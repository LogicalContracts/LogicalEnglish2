import { leLanguageConfiguration, leMonarchTokens, buildLeMonarchTokens } from './le-language';
import { t, applyI18nDom, installLeApiLang, detectProgramLanguage, detectTargetLanguage, targetLanguageStatement, uiLang } from './i18n';
import { buildShareUrl, decompressFromParam, fragmentParam } from './share-url';
import qrcode from 'qrcode-generator';
import { parseScenarioBlocks, parseQueryBlocks } from './le-templates';
import { kwPhrases } from './i18n';
import { ExplanationView } from './explanation-view';
import { isForeignOffset, openIncludedResource, describeResourceRange } from './resource-nav';
import { openSourceViewer, originalUrl, Provenance } from './source-viewer';
import { TabBar } from './editor-tabs';

declare var monaco: any;

// Communication with Graph Window
const graphChannel = new BroadcastChannel('le-graph-sync');
// Communication with the Scenario Editor window.
const scenarioChannel = new BroadcastChannel('le-scenario-editor');
// Communication with the Query Editor window.
const queryChannel = new BroadcastChannel('le-query-editor');

    async function start() {
        if (typeof monaco === 'undefined') {
            console.error('Monaco not loaded');
            return;
        }

        monaco.languages.register({ id: 'le' });
        monaco.languages.setLanguageConfiguration('le', leLanguageConfiguration);
        // The Monarch keyword tables are per program language (generated from
        // the shared lexicon); re-registered whenever the open program's first
        // statement declares a different language (O-6: the program's own
        // declaration governs, the UI selector only sets the default).
        let monarchLang = 'en';
        monaco.languages.setMonarchTokensProvider('le', buildLeMonarchTokens(monarchLang));
        const syncEditorLanguage = (text: string) => {
            const lang = detectProgramLanguage(text);
            if (lang !== monarchLang) {
                monarchLang = lang;
                monaco.languages.setMonarchTokensProvider('le', buildLeMonarchTokens(lang));
            }
        };
        // UI chrome language: API language parameter and DOM pass. The
        // preference itself is set only by the /multilingual pages (?lang=X
        // sets X, their back-to-English link resets it) — there is no
        // in-editor selector, to avoid confusion with the language of the
        // program being edited. The Home link accordingly returns to the
        // landing page that matches the active UI language.
        installLeApiLang();
        applyI18nDom();
        const homeLink = document.querySelector('a.home-link');
        if (homeLink && uiLang() !== 'en') {
            homeLink.setAttribute('href', `/multilingual?lang=${encodeURIComponent(uiLang())}`);
        }

        const issueFixes = new Map<string, string>();
        const getMarkerKey = (marker: any) => {
            return `${marker.startLineNumber}:${marker.startColumn}:${marker.message}`;
        };

        monaco.languages.registerCodeActionProvider('le', {
            provideCodeActions: (model: any, range: any, context: any, token: any) => {
                const actions = context.markers
                    .filter((m: any) => m.source === 'LE Verifier')
                    .map((m: any) => {
                        const fix = issueFixes.get(getMarkerKey(m));
                        if (!fix) return null;
                        
                        const text = model.getValue();
                        const match = text.match(/the[ \t]+(predicates|templates|fluents|events)[ \t]+are:/i);
                        let insertRange;
                        if (match) {
                            const offset = match.index + match[0].length;
                            const pos = model.getPositionAt(offset);
                            insertRange = new monaco.Range(pos.lineNumber + 1, 1, pos.lineNumber + 1, 1);
                        } else {
                            insertRange = new monaco.Range(1, 1, 1, 1);
                        }

                        return {
                            title: `Add template: ${fix}`,
                            diagnostics: [m],
                            kind: "quickfix",
                            edit: {
                                edits: [
                                    {
                                        resource: model.uri,
                                        textEdit: {
                                            range: insertRange,
                                            text: `    ${fix}\n`
                                        }
                                    }
                                ]
                            },
                            isPreferred: true
                        };
                    })
                    .filter((a: any) => a !== null);
                return {
                    actions: actions,
                    dispose: () => {}
                };
            }
        });

        monaco.editor.defineTheme('le-theme', {
            base: 'vs-dark',
            inherit: true,
            rules: [
                { token: 'keyword', foreground: 'c586c0' },
                { token: 'keyword.header', foreground: '569cd6', fontStyle: 'bold' },
                { token: 'keyword.expects', foreground: 'c586c0', fontStyle: 'italic' },
                { token: 'keyword.addition', foreground: 'c586c0', fontStyle: 'italic' },
                { token: 'variable', foreground: '9cdcfe' },
                { token: 'number.date', foreground: 'b5cea8' },
                { token: 'templateWord', foreground: 'dcdcaa' }
            ],
            colors: {
                'editor.background': '#1e1e1e'
            }
        });

        monaco.editor.defineTheme('le-theme-light', {
            base: 'vs',
            inherit: true,
            rules: [
                { token: 'keyword', foreground: 'af00db' },
                { token: 'keyword.header', foreground: '0000ff', fontStyle: 'bold' },
                { token: 'keyword.expects', foreground: 'af00db', fontStyle: 'italic' },
                { token: 'keyword.addition', foreground: 'af00db', fontStyle: 'italic' },
                { token: 'variable', foreground: '001080' },
                { token: 'number.date', foreground: '098658' },
                { token: 'templateWord', foreground: '795e26' }
            ],
            colors: {}
        });

        const params = new URLSearchParams(window.location.search);
        let initialValue = '';
        let initialFilename = 'document.le';

        const textParam = params.get('text');
        const exampleParam = params.get('example');
        const filenameParam = params.get('filename');
        const lineParam = params.get('line');

        // A failed example fetch (restricted or missing) must not silently leave
        // an empty editor: surface the server's message and, when the server says
        // login is required (a restricted example, no user logged in), send the
        // user to the login page — returning to this URL after they log in.
        function reportExampleLoadError(data: any) {
            alert(data?.error || data?.answer || 'Failed to load example from server.');
            if (data?.loginRequired) {
                window.location.href = '/login?return='
                    + encodeURIComponent(window.location.pathname + window.location.search);
            }
        }

        // A #lzp= fragment carries a compressed program (see share-url.ts, the
        // QR-code feature); it takes precedence over a ?text= parameter.
        const lzpParam = fragmentParam();
        if (lzpParam) {
            try {
                initialValue = await decompressFromParam(lzpParam);
            } catch (err) {
                console.error('Failed to decompress #lzp URL fragment', err);
            }
        }
        if (initialValue) {
            // already set from the fragment
        } else if (textParam) {
            initialValue = textParam;
        } else if (exampleParam) {
            try {
                const response = await fetch('/leapi', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        token: 'myToken123',
                        operation: 'examples',
                        file: exampleParam
                    })
                });
                const data = await response.json();
                if (data.error || data.answer) {
                    reportExampleLoadError(data);
                } else if (data.document) {
                    initialValue = data.document;
                    initialFilename = exampleParam + '.le';
                }
            } catch (err) {
                console.error('Failed to load example', err);
            }
        }

        if (filenameParam) {
            initialFilename = filenameParam;
        }

        // The document's name, handle and origin live with each open document
        // (EditorDoc below). A document fetched from a URL keeps that URL's
        // directory (baseUrl), sent to the server so the program's relative
        // `includes these resources:` resolve against the URL's location.
        const filenameDisplay = document.getElementById('filename-display');
        if (filenameDisplay) {
            filenameDisplay.textContent = initialFilename;
        }

        const savedTheme = localStorage.getItem('le-editor-theme') || 'le-theme';
        const savedFontSize = parseInt(localStorage.getItem('le-editor-font-size') || '16');
        let showHierarchicalNumbering = localStorage.getItem('le-hierarchical-numbering') === 'true';
        let failedNodePrefix = localStorage.getItem('le-failed-node-prefix') ?? 'x ';
        let detailedFailures = localStorage.getItem('le-detailed-failures') === 'true';
        let hideRepeatedExplanations = (localStorage.getItem('le-hide-repeated-explanations') ?? 'true') === 'true';
        let largerImportantReasons = (localStorage.getItem('le-larger-important-reasons') ?? 'true') === 'true';
        
        const numberingCheck = document.getElementById('hierarchical-numbering-check');
        if (numberingCheck) {
            numberingCheck.style.visibility = showHierarchicalNumbering ? 'visible' : 'hidden';
        }

        let isLoaded = false;
        let isLoading = false;
        let lastIssues: any[] = [];
        let lastLoadError = '';
        // Set (0-based) when an `answer` URL parameter asks the next query run to
        // auto-select a specific answer instead of the first.
        let pendingAnswerIndex: number | null = null;
        let sessionModule: string | null = null;
        let includedResources: any[] = [];
        let lastTemplateDefs: any[] = [];
        let lastKb = '';
        // Per-fact images ("<fact>; image \"URL\".") from the last load's
        // metadata: [{start, end, url}], keyed by the fact's source range.
        // Handed to the Bento Box window, which renders them in the leaves.
        let lastFactImages: any[] = [];
        // Template image additions ("; image \"URL\"" on a no-variable
        // template): [{literal, url}] — the Bento Box's fallback when a fact
        // carries no image of its own.
        let lastTemplateImages: any[] = [];
        let lastQueries: any[] = [];
        let loadTimeout: any = null;
        let availableModels: any[] = [];
        let serverKeys: string[] = [];

        // Fetch build info and set tooltip
        fetch('/build_info')
            .then(res => res.json())
            .then(data => {
                if (data.build_info) {
                    const titleEl = document.getElementById('editor-title');
                    if (titleEl) titleEl.title = `Build: ${data.build_info}`;
                }
            })
            .catch(err => console.error('Failed to fetch build info', err));

        const container = document.getElementById('container')!;

        // ---- open documents (the editor's file tabs) --------------------------
        // Each tab is one document: its own Monaco model, file name, where it
        // came from, unsaved state, and — kept aside while another program is
        // in the panels — the state of the Query and Assistant panels for it
        // (see switchPanel below). `activeDoc` is the one in the editor;
        // `panelDoc` the program the panels (queries, assistant, graph) are
        // about. They differ only while a click in an explanation shows a rule
        // of an included resource: its tab comes forward, the explanation stays.
        interface EditorDoc {
            id: number;
            model: any;
            viewState: any;
            fileName: string;
            fileHandle: any;
            baseUrl: string | null;     // directory of the URL it was fetched from
            example: string | null;     // the server example it was opened as
            dirty: boolean;
            textInUrl: boolean;         // the URL carries its text (edited, or given as ?text=)
            hash: string;               // its #lzp fragment, if it came in one
            assistantSessionId: string;
            panel: any;                 // saved panel state while not in the panels
        }
        let nextDocId = 1;
        const docs: EditorDoc[] = [];
        function createDoc(text: string, fileName: string, props: Partial<EditorDoc> = {}): EditorDoc {
            const id = nextDocId++;
            const uri = monaco.Uri.parse(id === 1 ? 'file:///main.le' : `file:///tab${id}.le`);
            const doc: EditorDoc = {
                id, model: monaco.editor.createModel(text, 'le', uri), viewState: null,
                fileName, fileHandle: null, baseUrl: null, example: null,
                dirty: false, textInUrl: false, hash: '',
                assistantSessionId: 'ses_' + Math.random().toString(36).substring(7),
                panel: null, ...props,
            };
            docs.push(doc);
            doc.model.onDidChangeContent(() => docChanged(doc));
            return doc;
        }
        const firstDoc = createDoc(initialValue, initialFilename, {
            example: exampleParam || null,
            textInUrl: !lzpParam && !!textParam,
            hash: lzpParam ? window.location.hash : '',
        });
        let activeDoc = firstDoc;
        let panelDoc = firstDoc;
        // the language server's view of the documents (set up with the server)
        let lspOpen = (_doc: EditorDoc) => {};
        let lspChange = (_doc: EditorDoc) => {};
        let lspClose = (_doc: EditorDoc) => {};
        const programModel = () => panelDoc.model;
        const programText = (): string => panelDoc.model.getValue();

        const editor = monaco.editor.create(container, {
            model: firstDoc.model,
            theme: savedTheme,
            automaticLayout: true,
            fontSize: savedFontSize,
            minimap: { enabled: false },
            folding: true,
            showFoldingControls: 'always',
            // Drive coloring from the template-aware semantic tokenizer (server.ts),
            // not just the Monarch grammar. Monarch cannot see template definitions,
            // so it mis-colours multi-word argument values ("the tea party" -> only
            // "the tea") and dates ("2021-10-09" -> "2021" + fragments). The default
            // is 'configuredByTheme', and these custom themes don't opt in, so
            // without this the registered semantic provider would be ignored.
            'semanticHighlighting.enabled': true
        });

        (window as any).selectRange = (start: number, end: number, info?: any) => {
            // A range in an included resource: open the resource, never read
            // its offsets as this document's (resource-nav.ts).
            if (isForeignOffset(start)) {
                if (info && info.resource) openIncludedResource(info);
                return;
            }
            // Offsets of the program in the panels: bring its tab forward.
            showProgramInEditor();
            const model = editor.getModel();
            // A jump from an explanation node, the graph or the proof game:
            // where we were is worth remembering, so Go back returns there.
            rememberJumpOrigin(editor);
            const startPos = model.getPositionAt(start);
            const endPos = model.getPositionAt(end);
            editor.setSelection(new monaco.Range(
                startPos.lineNumber, startPos.column,
                endPos.lineNumber, endPos.column
            ));
            editor.revealRangeInCenter(new monaco.Range(
                startPos.lineNumber, startPos.column,
                endPos.lineNumber, endPos.column
            ));
            editor.focus();
            window.focus();
        };

        if (lineParam) {
            const lineNumber = parseInt(lineParam);
            if (!isNaN(lineNumber)) {
                setTimeout(() => {
                    editor.revealLineInCenter(lineNumber);
                    editor.setPosition({ lineNumber: lineNumber, column: 1 });
                    editor.focus();
                }, 500);
            }
        }

        editor.addAction({
            id: 'copy-url',
            label: 'Copy URL',
            contextMenuGroupId: 'navigation',
            contextMenuOrder: 1.6,
            precondition: 'editorTextFocus',
            run: (ed: any) => {
                const example = activeDoc.example;
                if (!example) {
                    alert(t('Copy URL is only available for existing examples.'));
                    return;
                }

                const position = ed.getPosition();
                const url = new URL(window.location.href);
                url.searchParams.set('example', example);
                url.searchParams.delete('text'); // Remove text param if present to keep URL clean
                url.searchParams.set('line', position.lineNumber.toString());

                navigator.clipboard.writeText(url.toString()).then(() => {
                    // Optional: show a brief notification or change cursor
                    console.log('URL copied to clipboard:', url.toString());
                }).catch(err => {
                    console.error('Failed to copy URL:', err);
                });
            }
        });

        editor.addAction({
            id: 'see-prolog',
            label: 'See PROLOG',
            contextMenuGroupId: 'navigation',
            contextMenuOrder: 1.5,
            run: async (ed: any) => {
                const position = ed.getPosition();
                const model = ed.getModel();
                const offset = model.getOffsetAt(position);

                adoptActiveAsProgram();   // the cursor is in the tab shown: its program
                if (!isLoaded) {
                    await loadModule();
                }

                if (!sessionModule) {
                    alert(t('Please wait for the module to load.'));
                    return;
                }

                try {
                    const response = await fetch('/leapi', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            token: 'myToken123',
                            operation: 'getProlog',
                            sessionModule: sessionModule,
                            position: offset
                        })
                    });
                    const data = await response.json();
                    if (data.prolog) {
                        showPrologPanel(data.prolog);
                    } else if (data.error) {
                        console.log('Prolog conversion error:', data.error);
                    }
                } catch (err) {
                    console.error('Failed to get PROLOG:', err);
                }
            }
        });

        editor.addAction({
            id: 'see-scasp',
            label: 'See s(CASP)',
            contextMenuGroupId: 'navigation',
            contextMenuOrder: 1.6,
            run: async (ed: any) => {
                adoptActiveAsProgram();   // the cursor is in the tab shown: its program
                if (!isLoaded) {
                    await loadModule();
                }
                if (!sessionModule) {
                    alert(t('Please wait for the module to load.'));
                    return;
                }
                try {
                    const response = await fetch('/leapi', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            token: 'myToken123',
                            operation: 'getScasp',
                            sessionModule: sessionModule
                        })
                    });
                    const data = await response.json();
                    if (data.scasp !== undefined) {
                        // s(CASP) is a whole-program transformation; show the full
                        // generated program plus any compile-time issues.
                        let content = data.scasp;
                        if (Array.isArray(data.issues) && data.issues.length > 0) {
                            const lines = data.issues.map((i: any) => `% [${i.kind}] ${i.message}`);
                            content += '\n\n% ---- s(CASP) compile-time issues ----\n' + lines.join('\n');
                        }
                        showPrologPanel(content);
                    } else if (data.error) {
                        alert(data.error);
                    }
                } catch (err) {
                    console.error('Failed to get s(CASP):', err);
                }
            }
        });

        editor.addAction({
            id: 'le-toggle-line-comment',
            label: 'Toggle Line Comment',
            keybindings: [monaco.KeyMod.CtrlCmd | monaco.KeyCode.Slash],
            contextMenuGroupId: '9_cutcopypaste',
            contextMenuOrder: 1.0,
            run: (ed: any) => {
                ed.getAction('editor.action.commentLine')?.run();
            }
        });

        editor.addAction({
            id: 'le-toggle-block-comment',
            label: 'Toggle Block Comment',
            keybindings: [monaco.KeyMod.Shift | monaco.KeyMod.Alt | monaco.KeyCode.KeyA],
            contextMenuGroupId: '9_cutcopypaste',
            contextMenuOrder: 1.1,
            run: (ed: any) => {
                ed.getAction('editor.action.blockComment')?.run();
            }
        });

        editor.addAction({
            id: 'see-hierarchy',
            label: 'See Types Hierarchy',
            contextMenuGroupId: 'navigation',
            contextMenuOrder: 1.7,
            run: async (ed: any) => {
                adoptActiveAsProgram();   // the cursor is in the tab shown: its program
                if (!isLoaded) {
                    await loadModule();
                }

                if (!sessionModule) {
                    alert(t('Please wait for the module to load.'));
                    return;
                }

                const url = `hierarchy.html?sessionModule=${sessionModule}`;
                window.open(url, '_blank', 'width=800,height=600');
            }
        });

        // ---- predicate-aware navigation and folding ------------------------
        // Both actions need to know which predicate the cursor is on. The
        // server knows: it has the parsed KB with a source range per rule and
        // per template. The cursor's line goes along with the offset because a
        // rule's range covers the whole rule — the line is what distinguishes
        // the head from a condition.
        async function predicateAtCursor(ed: any, operation = 'predicateAt'): Promise<any | null> {
            adoptActiveAsProgram();   // the cursor is in the tab shown: its program
            if (!isLoaded) {
                await loadModule();
            }
            if (!sessionModule) {
                alert(t('Please wait for the module to load.'));
                return null;
            }
            const model = ed.getModel();
            const position = ed.getPosition();
            try {
                const response = await fetch('/leapi', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        token: 'myToken123',
                        operation: operation,
                        sessionModule: sessionModule,
                        position: model.getOffsetAt(position),
                        line: model.getLineContent(position.lineNumber),
                        // Where that line starts: a rule whose source range
                        // begins on this line is a rule the cursor is on the
                        // HEAD of, whatever words the conditions below share
                        // with it (see on_head_line/3 in classic_web_api.pl).
                        lineStart: model.getOffsetAt({ lineNumber: position.lineNumber, column: 1 })
                    })
                });
                const data = await response.json();
                if (data.error) {
                    console.log(operation + ':', data.error);
                    return null;
                }
                return data;
            } catch (err) {
                console.error(operation + ' failed:', err);
                return null;
            }
        }

        // Rule head lines (1-based) for a predicate, in document order.
        function ruleHeadLines(ed: any, data: any): number[] {
            const model = ed.getModel();
            const lines = (data.rules || [])
                .filter((r: any) => !isForeignOffset(r.start))
                .map((r: any) => model.getPositionAt(r.start).lineNumber);
            return [...new Set<number>(lines)].sort((a, b) => a - b);
        }

        async function foldPredicateRules(ed: any, fold: boolean) {
            const data = await predicateAtCursor(ed);
            if (!data) return;
            const lines = ruleHeadLines(ed, data);
            if (lines.length === 0) {
                alert(t('No rules for') + ` "${data.le}"`);
                return;
            }
            // Drive the folding model rather than the fold/unfold actions:
            // those act on the cursor's own region and ignore a list of lines,
            // and toggling per region is idempotent (folding an already folded
            // rule leaves it folded).
            const contrib: any = ed.getContribution('editor.contrib.folding');
            const foldingModel: any = contrib && await contrib.getFoldingModel();
            if (!foldingModel) {
                ed.trigger('le', fold ? 'editor.fold' : 'editor.unfold', { selectionLines: lines });
                return;
            }
            const toToggle: any[] = [];
            for (const line of lines) {
                const region = foldingModel.getRegionAtLine(line);
                if (region && region.isCollapsed !== fold) toToggle.push(region);
            }
            if (toToggle.length > 0) foldingModel.toggleCollapseState(toToggle);
        }

        editor.addAction({
            id: 'le-fold-predicate-rules',
            label: t('Fold all rules for this predicate'),
            contextMenuGroupId: 'navigation',
            contextMenuOrder: 1.9,
            run: (ed: any) => { foldPredicateRules(ed, true); }
        });

        editor.addAction({
            id: 'le-unfold-predicate-rules',
            label: t('Unfold all rules for this predicate'),
            contextMenuGroupId: 'navigation',
            contextMenuOrder: 2.0,
            run: (ed: any) => { foldPredicateRules(ed, false); }
        });

        // ---- navigation history --------------------------------------------
        // Where the cursor was before each programmatic jump (Show definition,
        // Show occurrences, a click in the explanation tree...), newest last —
        // so "Go back" returns the way VS Code's Go Back does. Ordinary typing
        // and cursor moves are NOT recorded: only jumps that moved the user
        // somewhere they did not navigate to themselves.
        // Each entry remembers its document too: a jump may have changed tabs.
        const jumpHistory: { lineNumber: number, column: number, doc: EditorDoc }[] = [];
        const JUMP_HISTORY_MAX = 50;

        function rememberJumpOrigin(ed: any) {
            const position = ed.getPosition();
            if (!position) return;
            const last = jumpHistory[jumpHistory.length - 1];
            if (last && last.doc === activeDoc && last.lineNumber === position.lineNumber && last.column === position.column) return;
            jumpHistory.push({ lineNumber: position.lineNumber, column: position.column, doc: activeDoc });
            if (jumpHistory.length > JUMP_HISTORY_MAX) jumpHistory.shift();
        }

        // Jump to a line, flashing it so the move is visible even when the
        // target was already on screen. The origin goes on the history stack,
        // so Ctrl+- comes back here.
        function jumpToLine(ed: any, lineNumber: number, column: number = 1) {
            rememberJumpOrigin(ed);
            ed.revealLineInCenter(lineNumber);
            ed.setPosition({ lineNumber: lineNumber, column: column });
            ed.focus();
            const decorations = ed.deltaDecorations([], [{
                range: new monaco.Range(lineNumber, 1, lineNumber, 1),
                options: { isWholeLine: true, className: 'le-definition-flash' }
            }]);
            setTimeout(() => ed.deltaDecorations(decorations, []), 1200);
        }

        editor.addAction({
            id: 'le-show-definition',
            label: t('Show definition'),
            keybindings: [monaco.KeyCode.F12],
            contextMenuGroupId: 'navigation',
            contextMenuOrder: 2.1,
            run: async (ed: any) => {
                const data = await predicateAtCursor(ed);
                if (!data) return;
                const model = ed.getModel();
                // the first rule that defines it; failing that, its template —
                // a predicate with no rules is defined by its declaration
                // Rules and templates of an included resource are opened there.
                const local = (data.rules || []).filter((r: any) => !isForeignOffset(r.start));
                const first = local.length > 0 ? local[0]
                    : (data.template && !isForeignOffset(data.template.start)) ? data.template
                    : (data.rules && data.rules.length > 0) ? data.rules[0]
                    : data.template;
                if (first && isForeignOffset(first.start)) {
                    openIncludedResource(first);
                    return;
                }
                const target = first ? first.start : null;
                if (target === null) {
                    alert(t('No definition found for') + ` "${data.le}"`);
                    return;
                }
                const pos = model.getPositionAt(target);
                jumpToLine(ed, pos.lineNumber, pos.column);
            }
        });

        // ---- Show occurrences ----------------------------------------------
        // Every place the predicate under the cursor is mentioned — its
        // declaration, the rules and facts that define it, the conditions that
        // use it, the scenario facts and the queries — listed in document order
        // and navigable. The server (operation predicateOccurrences) finds them;
        // the client turns each into a line.

        const occurrencesModal = document.getElementById('occurrences-modal');
        const occurrencesList = document.getElementById('occurrences-list');
        const occurrencesSubtitle = document.getElementById('occurrences-subtitle');
        const closeOccurrences = () => {
            if (occurrencesModal) occurrencesModal.style.display = 'none';
        };
        document.getElementById('occurrences-close')?.addEventListener('click', closeOccurrences);
        document.getElementById('occurrences-cancel')?.addEventListener('click', closeOccurrences);
        occurrencesModal?.addEventListener('click', (e) => {
            if (e.target === occurrencesModal) closeOccurrences();
        });

        // The words of a Logical English phrase, for comparing a rendered
        // literal against a source line.
        function leWords(text: string): string[] {
            return text.toLowerCase().split(/[^0-9a-zà-öø-ÿA-ZÀ-ÖØ-Þ_]+/).filter(w => w.length > 0);
        }

        // A rule's source range covers the WHOLE rule (and a query's its whole
        // section), so an occurrence inside one still has to be placed on the
        // right line: the one whose words overlap the literal's rendering most.
        // The head — or the `query ... is:` header — owns the first line, so the
        // search starts below it. Everything else (a declaration, a rule head, a
        // fact, a scenario fact) starts where its range starts.
        function occurrenceLine(model: any, occ: any): number {
            const first = model.getPositionAt(occ.start).lineNumber;
            const last = Math.min(model.getPositionAt(occ.end).lineNumber, model.getLineCount());
            const searches = (occ.kind === 'condition' || occ.kind === 'query');
            if (!searches || last <= first) return first;
            const words = leWords(occ.text || '');
            if (words.length === 0) return first;
            let best = first, bestScore = 0;
            for (let line = first + 1; line <= last; line++) {
                const lineWords = new Set(leWords(model.getLineContent(line)));
                const score = words.filter(w => lineWords.has(w)).length;
                if (score > bestScore) { bestScore = score; best = line; }
            }
            return best;
        }

        const OCCURRENCE_KIND_LABELS: { [kind: string]: string } = {
            template: 'declaration',
            fact: 'fact',
            head: 'rule head',
            condition: 'condition',
            scenario: 'scenario fact',
            query: 'query'
        };

        function showOccurrences(ed: any, data: any) {
            if (!occurrencesModal || !occurrencesList) return;
            const model = ed.getModel();
            const rows: any[] = [];
            const seen = new Set<string>();
            for (const occ of (data.occurrences || [])) {
                if (isForeignOffset(occ.start)) continue;   // in an included resource
                const line = occurrenceLine(model, occ);
                // Two literals of one rule can land on the same line (`... if the
                // person is rich and the person is rich`); one row is enough.
                const key = `${line}|${occ.kind}|${occ.text}`;
                if (seen.has(key)) continue;
                seen.add(key);
                rows.push({ occ, line });
            }
            rows.sort((a, b) => a.line - b.line);

            if (occurrencesSubtitle) {
                occurrencesSubtitle.textContent =
                    `${data.le} — ` +
                    t('{n} occurrence(s); click one to go to it').replace('{n}', String(rows.length));
            }
            occurrencesList.innerHTML = '';
            rows.forEach((row, index) => {
                const item = document.createElement('div');
                item.className = 'occurrence-row';

                const kind = document.createElement('span');
                kind.className = 'occurrence-kind';
                kind.textContent = t(OCCURRENCE_KIND_LABELS[row.occ.kind] || row.occ.kind);
                item.appendChild(kind);

                const lineNo = document.createElement('span');
                lineNo.className = 'occurrence-line';
                lineNo.textContent = String(row.line);
                item.appendChild(lineNo);

                // The source line as written, rather than the canonical
                // rendering: that is what the user is looking for on screen.
                const text = document.createElement('span');
                text.className = 'occurrence-text';
                text.textContent = model.getLineContent(row.line).trim() || row.occ.text || '';
                item.appendChild(text);

                if (row.occ.context) {
                    const context = document.createElement('span');
                    context.className = 'occurrence-context';
                    context.textContent = row.occ.context;
                    item.appendChild(context);
                }

                item.addEventListener('click', () => {
                    closeOccurrences();
                    jumpToLine(ed, row.line);
                });
                occurrencesList.appendChild(item);
            });
            occurrencesModal.style.display = 'flex';
        }

        // Escape closes it; the arrows walk the list and Enter goes there, so
        // the whole thing is usable without the mouse.
        document.addEventListener('keydown', (e) => {
            // display is only ever 'flex' while the modal is up ('' means the
            // stylesheet's display:none is still in force).
            if (!occurrencesModal || occurrencesModal.style.display !== 'flex') return;
            if (e.key === 'Escape') { closeOccurrences(); return; }
            if (!occurrencesList) return;
            const items = Array.from(occurrencesList.querySelectorAll('.occurrence-row')) as HTMLElement[];
            if (items.length === 0) return;
            const current = items.findIndex(i => i.classList.contains('selected'));
            if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
                e.preventDefault();
                const next = e.key === 'ArrowDown'
                    ? Math.min(current + 1, items.length - 1)
                    : Math.max(current - 1, 0);
                items.forEach(i => i.classList.remove('selected'));
                items[next < 0 ? 0 : next].classList.add('selected');
                items[next < 0 ? 0 : next].scrollIntoView({ block: 'nearest' });
            } else if (e.key === 'Enter' && current >= 0) {
                e.preventDefault();
                items[current].click();
            }
        });

        // VS Code's Go Back. Its Windows/Linux chord is Ctrl+Alt+-, its macOS
        // one Ctrl+-; both are registered, because a browser may keep Ctrl+-
        // for zooming out and never hand it to the page.
        editor.addAction({
            id: 'le-go-back',
            label: t('Go back (to where you jumped from)'),
            keybindings: [
                monaco.KeyMod.CtrlCmd | monaco.KeyCode.Minus,
                monaco.KeyMod.CtrlCmd | monaco.KeyMod.Alt | monaco.KeyCode.Minus
            ],
            contextMenuGroupId: 'navigation',
            contextMenuOrder: 2.3,
            run: (ed: any) => {
                let target = jumpHistory.pop();
                while (target && !docs.includes(target.doc)) target = jumpHistory.pop();   // its tab was closed
                if (!target) return;
                if (target.doc !== activeDoc) activateDoc(target.doc, false);
                const model = ed.getModel();
                // The document may have shrunk since (an edit, or another file
                // loaded): clamp rather than throw the position away.
                const lineNumber = Math.min(target.lineNumber, model.getLineCount());
                ed.revealLineInCenter(lineNumber);
                ed.setPosition({ lineNumber: lineNumber, column: target.column });
                ed.focus();
            }
        });

        editor.addAction({
            id: 'le-show-occurrences',
            label: t('Show occurrences'),
            keybindings: [monaco.KeyMod.Shift | monaco.KeyCode.F12],
            contextMenuGroupId: 'navigation',
            contextMenuOrder: 2.2,
            run: async (ed: any) => {
                const data = await predicateAtCursor(ed, 'predicateOccurrences');
                if (!data) return;
                if (!data.occurrences || data.occurrences.length === 0) {
                    alert(t('No occurrences found for') + ` "${data.le}"`);
                    return;
                }
                showOccurrences(ed, data);
            }
        });

        // ---- Show original text --------------------------------------------
        // Where the program cites a document it says how to reach — a fact
        // with provenance, a rule or table labelled with provenance, a scenario
        // "as stated in" a document, "the text of <document> is at ..." — the
        // context menu offers the document itself, the cited passage
        // highlighted (the source viewer of the explanation's § badge).
        // Each load sends those ranges (`citations`); they are kept as
        // invisible decorations of the program's model, so they follow edits
        // until the next load, and a context key says whether the cursor's
        // line meets one — the menu shows the entry only then. Which document
        // is asked for when the entry is chosen (operation provenanceAt).
        // A program not loaded since it was opened has no known citations yet:
        // the entry is offered anywhere and loads it (and so does opening the
        // menu, so that the next menu knows).
        const CITATION = 'le-citation';
        const citationKey = editor.createContextKey('leCitationAtCursor', false);
        const citationDecorations = new WeakMap<any, string[]>();

        function updateCitationKey() {
            const model = editor.getModel();
            const position = editor.getPosition();
            if (!model || !position || model.getLanguageId() !== 'le') {
                citationKey.set(false);
            } else if (!citationDecorations.has(model)) {
                citationKey.set(true);
            } else {
                citationKey.set(model.getLineDecorations(position.lineNumber)
                    .some((d: any) => d.options.description === CITATION));
            }
        }
        editor.onContextMenu(() => {
            if (activeDoc === panelDoc && !isLoaded && !isLoading) loadModule();
        });

        const setCitations = (model: any, spans: number[][]) => {
            const decorations = spans.map(([start, end]) => {
                const a = model.getPositionAt(start);
                const b = model.getPositionAt(end);
                return {
                    range: new monaco.Range(a.lineNumber, a.column, b.lineNumber, b.column),
                    options: {
                        description: CITATION,
                        stickiness: monaco.editor.TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges
                    }
                };
            });
            citationDecorations.set(model, model.deltaDecorations(citationDecorations.get(model) || [], decorations));
            updateCitationKey();
        };
        editor.onDidChangeCursorPosition(updateCitationKey);
        editor.onDidChangeModel(updateCitationKey);

        editor.addAction({
            id: 'le-show-original-text',
            label: t('Show original text'),
            contextMenuGroupId: 'navigation',
            contextMenuOrder: 2.25,
            precondition: 'leCitationAtCursor',
            run: async (ed: any) => {
                const data = await predicateAtCursor(ed, 'provenanceAt');
                if (!data || !data.provenance) {
                    alert(t('No cited document here.'));
                    return;
                }
                const p: Provenance = data.provenance;
                // Only a published address: that is the original to open.
                const published = originalUrl(p);
                if (!p.text && published) {
                    window.open(published, '_blank');
                    return;
                }
                openSourceViewer(p, data.rule || undefined,
                                 { source: panelDoc.example || '', base: panelDoc.baseUrl || '' });
            }
        });

        const prologPanel = document.getElementById('prolog-panel')!;
        const prologContent = document.getElementById('prolog-content')!;
        const prologClose = document.getElementById('prolog-panel-close')!;
        const prologHeader = document.getElementById('prolog-panel-header')!;
        const prologCopy = document.getElementById('prolog-copy')!;

        const showPrologPanel = (content: string) => {
            prologContent.textContent = content;
            prologPanel.style.display = 'flex';
        };

        prologClose.onclick = () => {
            prologPanel.style.display = 'none';
        };

        prologCopy.onclick = () => {
            navigator.clipboard.writeText(prologContent.textContent || '');
            const originalText = prologCopy.textContent;
            prologCopy.textContent = t('Copied!');
            setTimeout(() => {
                prologCopy.textContent = originalText;
            }, 2000);
        };

        // Draggable logic for Prolog Panel
        let isDraggingProlog = false;
        let prologStartX: number, prologStartY: number;
        let prologStartLeft: number, prologStartTop: number;

        prologHeader.onmousedown = (e) => {
            isDraggingProlog = true;
            prologStartX = e.clientX;
            prologStartY = e.clientY;
            prologStartLeft = prologPanel.offsetLeft;
            prologStartTop = prologPanel.offsetTop;
            document.body.style.userSelect = 'none';
        };

        document.addEventListener('mousemove', (e) => {
            if (!isDraggingProlog) return;
            const dx = e.clientX - prologStartX;
            const dy = e.clientY - prologStartY;
            prologPanel.style.left = `${prologStartLeft + dx}px`;
            prologPanel.style.top = `${prologStartTop + dy}px`;
            prologPanel.style.right = 'auto'; // Disable right alignment once dragged
        });

        document.addEventListener('mouseup', () => {
            isDraggingProlog = false;
            document.body.style.userSelect = 'auto';
        });

    const menuSave = document.getElementById('menu-save');
    const menuSaveAs = document.getElementById('menu-save-as');

    // Update Save As label for browsers without File System Access API
    if (!('showSaveFilePicker' in window) && menuSaveAs) {
        menuSaveAs.textContent = t('Download');
    }

    const updateSaveMenu = () => {
        if (menuSave) {
            menuSave.style.display = activeDoc.fileHandle ? 'block' : 'none';
        }
    };

    // The text a new document starts with.
    const newDocumentText = () => uiLang() === 'en' ? '' : targetLanguageStatement() + '\n\n';

    // Menu Actions — New and the Open operations put the document in a tab of
    // its own (openDocument); Save and Save As act on the tab in front.
    document.getElementById('menu-new')?.addEventListener('click', () => { newTab(); });

    // New from URL: fetch an LE program from a URL and load it into the editor.
    const urlModal = document.getElementById('new-from-url-modal');
    const urlInput = document.getElementById('new-from-url-input') as HTMLInputElement;
    const urlError = document.getElementById('new-from-url-error');
    const urlLoadBtn = document.getElementById('new-from-url-load') as HTMLButtonElement;

    const closeUrlModal = () => { if (urlModal) urlModal.style.display = 'none'; };
    const showUrlError = (msg: string) => {
        if (urlError) { urlError.textContent = msg; urlError.style.display = 'block'; }
    };

    document.getElementById('menu-new-from-url')?.addEventListener('click', () => {
        if (urlError) urlError.style.display = 'none';
        if (urlModal) urlModal.style.display = 'flex';
        urlInput?.focus();
        urlInput?.select();
    });
    document.getElementById('new-from-url-close')?.addEventListener('click', closeUrlModal);
    document.getElementById('new-from-url-cancel')?.addEventListener('click', closeUrlModal);

    // "QR code…": the current document as a scannable URL. A server example
    // keeps its plain parameterized URL; an edited document travels compressed
    // in the #lzp fragment (share-url.ts). A URL past QR_URL_MAX is refused
    // with an explanation: QR codes top out at 2953 bytes, and long before
    // that they become too dense to scan reliably from a screen.
    const QR_URL_MAX = 1500;
    const qrModal = document.getElementById('qr-modal');
    const closeQrModal = () => { if (qrModal) qrModal.style.display = 'none'; };
    document.getElementById('qr-modal-close')?.addEventListener('click', closeQrModal);
    qrModal?.addEventListener('click', (e) => { if (e.target === qrModal) closeQrModal(); });
    document.getElementById('qr-copy-url')?.addEventListener('click', () => {
        const u = document.getElementById('qr-url')?.textContent || '';
        if (u) navigator.clipboard.writeText(u);
    });
    document.getElementById('menu-qr-code')?.addEventListener('click', async () => {
        const url = await buildShareUrl(programText());
        if (url.length > QR_URL_MAX) {
            showModal(
                t('The URL is too long for a QR code ({n} characters; the limit is {max}). Shorten the program, or save it as a server example and share its example URL instead.')
                    .replace('{n}', String(url.length)).replace('{max}', String(QR_URL_MAX)),
                t('QR code'));
            return;
        }
        const qr = qrcode(0, 'M');
        qr.addData(url);
        qr.make();
        (document.getElementById('qr-image') as HTMLImageElement).src = qr.createDataURL(4, 8);
        const urlEl = document.getElementById('qr-url');
        if (urlEl) urlEl.textContent = url;
        if (qrModal) qrModal.style.display = 'flex';
    });

    const loadFromUrl = async () => {
        const raw = (urlInput?.value || '').trim();
        if (!raw) { showUrlError('Please enter a URL.'); return; }
        let url: URL;
        try { url = new URL(raw); }
        catch { showUrlError('That is not a valid URL.'); return; }

        const prevLabel = urlLoadBtn.textContent;
        urlLoadBtn.disabled = true;
        urlLoadBtn.textContent = t('Loading…');
        if (urlError) urlError.style.display = 'none';
        try {
            const resp = await fetch(raw, { redirect: 'follow' });
            if (!resp.ok) throw new Error(`server returned ${resp.status} ${resp.statusText}`);
            const content = await resp.text();

            // Filename from the URL's last path segment (default document.le).
            const seg = url.pathname.split('/').filter(Boolean).pop() || 'document.le';
            await openDocument(content, {
                fileName: /\.[A-Za-z0-9]+$/.test(seg) ? seg : seg + '.le',
                // remote: no local write-back handle. Base = the URL up to its
                // last '/', so relative includes resolve.
                baseUrl: raw.slice(0, raw.length - url.pathname.split('/').pop()!.length),
            });
            closeUrlModal();
        } catch (err: any) {
            showUrlError(
                `Could not fetch the URL: ${err.message}. ` +
                `If it is on another site, that site must allow cross-origin requests (CORS).`);
        } finally {
            urlLoadBtn.disabled = false;
            urlLoadBtn.textContent = prevLabel;
        }
    };
    urlLoadBtn?.addEventListener('click', loadFromUrl);
    urlInput?.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') { e.preventDefault(); loadFromUrl(); }
    });

    const fileInput = document.getElementById('file-input') as HTMLInputElement;
    document.getElementById('menu-open')?.addEventListener('click', async () => {
        if ('showOpenFilePicker' in window) {
            try {
                const [handle] = await (window as any).showOpenFilePicker({
                    types: [{
                        description: 'Logical English File',
                        accept: { 'text/plain': ['.le'] },
                    }],
                    multiple: false
                });
                const file = await handle.getFile();
                const content = await file.text();
                await openDocument(content, { fileName: file.name, fileHandle: handle });
                return;
            } catch (err: any) {
                if (err.name === 'AbortError') return;
                console.error('File System Access API failed, falling back to input', err);
            }
        }
        
        fileInput?.click();
    });

    fileInput?.addEventListener('change', (e) => {
        const file = (e.target as HTMLInputElement).files?.[0];
        if (!file) return;
        const reader = new FileReader();
        reader.onload = (e) => {
            const content = e.target?.result as string;
            if (content !== undefined) {
                // Traditional input doesn't give us a handle we can write back to
                openDocument(content, { fileName: file.name });
            }
        };
        reader.readAsText(file);
        fileInput.value = '';
    });

    const saveToFile = async (handle: any, doc: EditorDoc = activeDoc) => {
        const content = doc.model.getValue();
        const writable = await handle.createWritable();
        await writable.write(content);
        await writable.close();
        setDirty(doc, false);
    };

    const saveAction = async () => {
        if (activeDoc.fileHandle) {
            try {
                await saveToFile(activeDoc.fileHandle);
                return;
            } catch (err) {
                console.error('Direct save failed, falling back to Save As', err);
            }
        }
        await saveAsAction();
    };

    const saveAsAction = async () => {
        const doc = activeDoc;
        const content = doc.model.getValue();
        
        // Try to use the File System Access API for "Save As"
        if ('showSaveFilePicker' in window) {
            try {
                const handle = await (window as any).showSaveFilePicker({
                    suggestedName: doc.fileName.split('/').pop(),
                    types: [{
                        description: 'Logical English File',
                        accept: { 'text/plain': ['.le'] },
                    }],
                });
                await saveToFile(handle, doc);
                
                doc.fileHandle = handle;
                doc.fileName = handle.name;
                refreshTabs();
                return;
            } catch (err: any) {
                if (err.name === 'AbortError') return;
                console.error('File System Access API failed, falling back to download', err);
            }
        }

        // Fallback to traditional download
        const blob = new Blob([content], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = doc.fileName.split('/').pop() || 'document.le';
        a.click();
        URL.revokeObjectURL(url);
        setDirty(doc, false);
    };

    menuSave?.addEventListener('click', saveAction);
    menuSaveAs?.addEventListener('click', saveAsAction);

    // Server Examples Modal
    const modalOverlay = document.getElementById('modal-overlay');
    const exampleList = document.getElementById('example-list');
    const modalClose = document.getElementById('modal-close');
    const modalCancel = document.getElementById('modal-cancel');

    const closeModal = () => {
        if (modalOverlay) modalOverlay.style.display = 'none';
    };

    modalClose?.addEventListener('click', closeModal);
    modalCancel?.addEventListener('click', closeModal);
    modalOverlay?.addEventListener('click', (e) => {
        if (e.target === modalOverlay) closeModal();
    });
    // Escape closes the modal — without this, a user (or an e2e retry loop)
    // whose example fetch failed had no keyboard way out, and the overlay
    // blocked reopening the File menu to retry.
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && modalOverlay && modalOverlay.style.display !== 'none') closeModal();
    });

    document.getElementById('menu-open-server')?.addEventListener('click', async () => {

        if (modalOverlay) modalOverlay.style.display = 'flex';
        if (exampleList) exampleList.innerHTML = '<div style="padding: 20px; text-align: center; color: #888;">Loading examples...</div>';

        try {
            const response = await fetch('/leapi', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    token: 'myToken123',
                    operation: 'list_examples'
                })
            });
            const data = await response.json();
            
            if (data.examples && exampleList) {
                exampleList.innerHTML = '';
                const examples: string[] = [...data.examples].sort();

                // Separate root-level examples from subdirectory ones
                const rootExamples: string[] = [];
                const subDirGroups = new Map<string, string[]>();
                examples.forEach((ex: string) => {
                    const slashIdx = ex.indexOf('/');
                    if (slashIdx >= 0) {
                        const subdir = ex.substring(0, slashIdx);
                        if (!subDirGroups.has(subdir)) subDirGroups.set(subdir, []);
                        subDirGroups.get(subdir)!.push(ex);
                    } else {
                        rootExamples.push(ex);
                    }
                });

                const makeItem = (ex: string, label: string, indent: boolean) => {
                    const item = document.createElement('div');
                    item.className = 'dropdown-item';
                    item.style.padding = indent ? '8px 15px 8px 30px' : '10px 15px';
                    item.style.borderBottom = '1px solid #333';
                    item.textContent = label;
                    item.addEventListener('click', async () => {
                        closeModal();
                        await loadExampleFromServer(ex);
                    });
                    return item;
                };

                rootExamples.forEach((ex: string) => {
                    exampleList.appendChild(makeItem(ex, ex, false));
                });

                subDirGroups.forEach((items, subdir) => {
                    const header = document.createElement('div');
                    header.style.cssText = 'padding: 8px 15px 4px; font-weight: bold; color: #aaa; border-bottom: 1px solid #555; font-size: 0.85em; letter-spacing: 0.03em;';
                    header.textContent = subdir + '/';
                    exampleList.appendChild(header);
                    items.forEach((ex: string) => {
                        const name = ex.substring(ex.indexOf('/') + 1);
                        exampleList.appendChild(makeItem(ex, name, true));
                    });
                });
            } else if (exampleList) {
                // An error reply (no `examples`) used to leave "Loading
                // examples..." up forever; show the failure instead.
                exampleList.innerHTML = '<div style="padding: 20px; text-align: center; color: #f44;">Failed to load examples.</div>';
                console.error('list_examples returned no examples', data);
            }
        } catch (err) {
            if (exampleList) exampleList.innerHTML = '<div style="padding: 20px; text-align: center; color: #f44;">Failed to load examples.</div>';
            console.error('Failed to list examples', err);
        }
    });

    async function loadExampleFromServer(name: string) {
        try {
            const response = await fetch('/leapi', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    token: 'myToken123',
                    operation: 'examples',
                    file: name
                })
            });
            const data = await response.json();
            if (data.error || data.answer) {
                // Restricted (or missing) example: report it — and redirect to
                // login when that could grant access — instead of doing nothing.
                reportExampleLoadError(data);
                return;
            }
            if (data.document !== undefined) {
                // the example's name goes with it: the server resolves its
                // relative includes against the example's folder
                openDocument(data.document, { fileName: name + '.le', example: name });
            }
        } catch (err) {
            alert(t('Failed to load example from server.'));
            console.error('Failed to load example', err);
        }
    }

    // Edit Actions
    document.getElementById('menu-cut')?.addEventListener('click', () => editor.focus() || editor.trigger('keyboard', 'editor.action.clipboardCutAction', null));
    document.getElementById('menu-copy')?.addEventListener('click', () => editor.focus() || editor.trigger('keyboard', 'editor.action.clipboardCopyAction', null));
    document.getElementById('menu-paste')?.addEventListener('click', () => editor.focus() || editor.trigger('keyboard', 'editor.action.clipboardPasteAction', null));
    document.getElementById('menu-find')?.addEventListener('click', () => editor.trigger('keyboard', 'actions.find', null));
    document.getElementById('menu-replace')?.addEventListener('click', () => editor.trigger('keyboard', 'editor.action.startFindReplaceAction', null));

    // Misc Actions
    const setTheme = (theme: string) => {
        monaco.editor.setTheme(theme);
        localStorage.setItem('le-editor-theme', theme);
        
        document.body.classList.remove('light-theme', 'hc-theme');
        if (theme === 'le-theme-light') {
            document.body.classList.add('light-theme');
        } else if (theme === 'hc-black') {
            document.body.classList.add('hc-theme');
        }

        graphChannel.postMessage({
            type: 'theme-change',
            data: { theme }
        });
    };
    // Apply initial theme to body
    setTheme(savedTheme);

    document.getElementById('theme-dark')?.addEventListener('click', () => setTheme('le-theme'));
    document.getElementById('theme-light')?.addEventListener('click', () => setTheme('le-theme-light'));
    document.getElementById('theme-hc')?.addEventListener('click', () => setTheme('hc-black'));

    document.getElementById('menu-hierarchical-numbering')?.addEventListener('click', () => {
        showHierarchicalNumbering = !showHierarchicalNumbering;
        localStorage.setItem('le-hierarchical-numbering', showHierarchicalNumbering.toString());
        if (numberingCheck) {
            numberingCheck.style.visibility = showHierarchicalNumbering ? 'visible' : 'hidden';
        }
        // Re-render current explanation if any
        explView.rerender();
    });

    const setFontSize = (size: number) => {
        editor.updateOptions({ fontSize: size });
        localStorage.setItem('le-editor-font-size', size.toString());
    };
    document.getElementById('font-small')?.addEventListener('click', () => setFontSize(12));
    document.getElementById('font-medium')?.addEventListener('click', () => setFontSize(16));
    document.getElementById('font-large')?.addEventListener('click', () => setFontSize(20));

    // API Keys Modal
    const apiKeysModal = document.getElementById('api-keys-modal');
    const apiKeysClose = document.getElementById('api-keys-close');
    const apiKeysCancel = document.getElementById('api-keys-cancel');
    const apiKeysSave = document.getElementById('api-keys-save');
    const openaiKeyInput = document.getElementById('openai-key') as HTMLInputElement;
    const anthropicKeyInput = document.getElementById('anthropic-key') as HTMLInputElement;
    const googleKeyInput = document.getElementById('google-key') as HTMLInputElement;
    const groqKeyInput = document.getElementById('groq-key') as HTMLInputElement;
    const togetherKeyInput = document.getElementById('together-key') as HTMLInputElement;
    const modelSelect = document.getElementById('assistant-model-select') as HTMLSelectElement;
    const assistantMaxStepsInput = document.getElementById('assistant-max-steps') as HTMLInputElement;

    const loadModels = async () => {
        try {
            const response = await fetch('/leapi', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    token: 'myToken123',
                    operation: 'list_models'
                })
            });
            const data = await response.json();
            if (data.models) {
                availableModels = data.models;
                modelSelect.innerHTML = '';
                data.models.forEach((m: any) => {
                    const opt = document.createElement('option');
                    opt.value = m.short;
                    opt.textContent = `${m.short} (${m.provider})`;
                    modelSelect.appendChild(opt);
                });
                
                let savedModel = localStorage.getItem('le-assistant-model');
                if (savedModel) {
                    modelSelect.value = savedModel;
                } else {
                    // Pick a default model that has a key
                    const hasKey = (provider: string) => {
                        const serverP = provider === 'google' ? 'gemini' : provider;
                        const localP = provider === 'gemini' ? 'google' : provider;
                        return (data.server_keys && data.server_keys.includes(serverP)) || 
                               localStorage.getItem(`le-${localP}-key`);
                    };
                    const bestModel = data.models.find((m: any) => hasKey(m.provider)) || data.models[0];
                    if (bestModel) {
                        modelSelect.value = bestModel.short;
                        localStorage.setItem('le-assistant-model', bestModel.short);
                    }
                }
            }
            if (data.server_keys) {
                serverKeys = data.server_keys;
                const keys = ['openai', 'anthropic', 'google', 'groq', 'together'];
                keys.forEach(k => {
                    const input = document.getElementById(`${k}-key`) as HTMLInputElement;
                    const serverKey = data.server_keys.includes(k === 'google' ? 'gemini' : k);
                    if (serverKey && input) {
                        input.disabled = true;
                        input.placeholder = t('Provided by server');
                        // Add a note if not already there
                        let note = input.parentElement?.querySelector('.server-key-note');
                        if (!note) {
                            note = document.createElement('div');
                            note.className = 'server-key-note';
                            note.style.fontSize = '10px';
                            note.style.color = '#89d185';
                            note.style.marginTop = '2px';
                            note.textContent = t('This key is provided by the server environment.');
                            input.parentElement?.appendChild(note);
                        }
                    } else if (input) {
                        input.disabled = false;
                        input.placeholder = '';
                        const note = input.parentElement?.querySelector('.server-key-note');
                        if (note) note.remove();
                    }
                });
            }
        } catch (err) {
            console.error('Failed to load models', err);
        }
    };

    loadModels();

    const openApiKeysModal = () => {
        if (apiKeysModal) {
            openaiKeyInput.value = localStorage.getItem('le-openai-key') || '';
            anthropicKeyInput.value = localStorage.getItem('le-anthropic-key') || '';
            googleKeyInput.value = localStorage.getItem('le-google-key') || '';
            groqKeyInput.value = localStorage.getItem('le-groq-key') || '';
            togetherKeyInput.value = localStorage.getItem('le-together-key') || '';
            if (assistantMaxStepsInput) {
                assistantMaxStepsInput.value = localStorage.getItem('le-assistant-max-steps') || '10';
            }
            loadModels();
            apiKeysModal.style.display = 'flex';
        }
    };

    const closeApiKeysModal = () => {
        if (apiKeysModal) apiKeysModal.style.display = 'none';
    };

    document.getElementById('menu-api-keys')?.addEventListener('click', openApiKeysModal);
    apiKeysClose?.addEventListener('click', closeApiKeysModal);
    apiKeysCancel?.addEventListener('click', closeApiKeysModal);
    apiKeysSave?.addEventListener('click', () => {
        localStorage.setItem('le-openai-key', openaiKeyInput.value);
        localStorage.setItem('le-anthropic-key', anthropicKeyInput.value);
        localStorage.setItem('le-google-key', googleKeyInput.value);
        localStorage.setItem('le-groq-key', groqKeyInput.value);
        localStorage.setItem('le-together-key', togetherKeyInput.value);
        localStorage.setItem('le-assistant-model', modelSelect.value);
        if (assistantMaxStepsInput) {
            let val = parseInt(assistantMaxStepsInput.value, 10);
            if (isNaN(val) || val < 1) val = 1;
            if (val > 50) val = 50;
            localStorage.setItem('le-assistant-max-steps', val.toString());
        }
        closeApiKeysModal();
    });

    // Explanations Preferences Modal
    const explanationsModal = document.getElementById('explanations-modal');
    const explanationsClose = document.getElementById('explanations-close');
    const explanationsCancel = document.getElementById('explanations-cancel');
    const explanationsSave = document.getElementById('explanations-save');
    const failedPrefixInput = document.getElementById('failed-prefix-input') as HTMLInputElement;
    const detailedFailuresInput = document.getElementById('detailed-failures-input') as HTMLInputElement;
    const hideRepeatedInput = document.getElementById('hide-repeated-input') as HTMLInputElement;
    const largerReasonsInput = document.getElementById('larger-important-reasons-input') as HTMLInputElement;

    const openExplanationsModal = () => {
        if (explanationsModal && failedPrefixInput) {
            failedPrefixInput.value = failedNodePrefix;
            if (detailedFailuresInput) detailedFailuresInput.checked = detailedFailures;
            if (hideRepeatedInput) hideRepeatedInput.checked = hideRepeatedExplanations;
            if (largerReasonsInput) largerReasonsInput.checked = largerImportantReasons;
            explanationsModal.style.display = 'flex';
        }
    };

    const closeExplanationsModal = () => {
        if (explanationsModal) explanationsModal.style.display = 'none';
    };

    document.getElementById('menu-explanations')?.addEventListener('click', openExplanationsModal);
    explanationsClose?.addEventListener('click', closeExplanationsModal);
    explanationsCancel?.addEventListener('click', closeExplanationsModal);
    explanationsSave?.addEventListener('click', () => {
        if (failedPrefixInput) {
            failedNodePrefix = failedPrefixInput.value;
            localStorage.setItem('le-failed-node-prefix', failedNodePrefix);
        }
        if (detailedFailuresInput) {
            detailedFailures = detailedFailuresInput.checked;
            localStorage.setItem('le-detailed-failures', detailedFailures.toString());
        }
        if (hideRepeatedInput) {
            hideRepeatedExplanations = hideRepeatedInput.checked;
            localStorage.setItem('le-hide-repeated-explanations', hideRepeatedExplanations.toString());
        }
        if (largerReasonsInput) {
            largerImportantReasons = largerReasonsInput.checked;
            localStorage.setItem('le-larger-important-reasons', largerImportantReasons.toString());
        }
        closeExplanationsModal();
    });

    // Tab Switching
    const tabs = document.querySelectorAll('.tab');
    const tabContents = document.querySelectorAll('.tab-content');

    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            const target = tab.getAttribute('data-tab');
            tabs.forEach(t => t.classList.remove('active'));
            tabContents.forEach(c => c.classList.remove('active'));
            tab.classList.add('active');
            document.getElementById(target!)?.classList.add('active');
        });
    });

    // Source Graph: rendered in its own browser tab (graph.html / graph-client.ts),
    // opened from Misc > View Source Graph or the editor context menu. The editor
    // talks to it over the le-graph-sync BroadcastChannel (state, theme, caret focus).
    function sendStateToGraph() {
        graphChannel.postMessage({
            type: 'init-state',
            data: {
                sessionModule,
                theme: localStorage.getItem('le-editor-theme') || 'le-theme',
                isLoaded,
                filename: panelDoc.fileName
            }
        });
    }

    graphChannel.onmessage = (event) => {
        const { type, data } = event.data;
        if (type === 'select-range') {
            (window as any).selectRange(data.start, data.end, data);
        } else if (type === 'request-state') {
            sendStateToGraph();
        }
    };

    editor.onDidChangeCursorPosition((e: any) => {
        // The graph shows the program in the panels: only its caret counts.
        if (activeDoc !== panelDoc) return;
        const model = editor.getModel();
        const offset = model.getOffsetAt(e.position);
        // Keep the graph window's focused node in sync with the caret.
        graphChannel.postMessage({
            type: 'focus-offset',
            data: { offset }
        });
    });

    // Open the Source Graph in a new browser tab, loading the module first so
    // the graph has something to render when it asks for the editor's state.
    async function openSourceGraph() {
        if (!isLoaded && !isLoading) {
            await loadModule();
        }
        window.open('graph.html', '_blank');
    }

    editor.addAction({
        id: 'open-graph-window',
        label: 'View Source Graph',
        contextMenuGroupId: 'navigation',
        contextMenuOrder: 1.8,
        run: () => { openSourceGraph(); }
    });

    document.getElementById('menu-view-source-graph')?.addEventListener('click', () => {
        openSourceGraph();
    });

    document.getElementById('menu-fold-all')?.addEventListener('click', () => {
        editor.focus();
        editor.trigger('keyboard', 'editor.foldAll', null);
    });
    document.getElementById('menu-unfold-all')?.addEventListener('click', () => {
        editor.focus();
        editor.trigger('keyboard', 'editor.unfoldAll', null);
    });

    // Query Panel Logic
    const scenarioSelect = document.getElementById('scenario-select') as HTMLSelectElement;
    const querySelect = document.getElementById('query-select') as HTMLSelectElement;
    const engineSelect = document.getElementById('engine-select') as HTMLSelectElement | null;
    // Once the user (or a URL param) picks an engine explicitly, a program's
    // declared target must not silently override it.
    let engineUserSet = false;

    // --- Engine-picker visibility preference (Misc menu) ---------------------
    // LE is Prolog-biased, so the engine picker is clutter for most programs.
    // 'always' (default) shows it for every program; 'nonprolog' shows it only
    // when the loaded program's target language is not prolog (or a non-prolog
    // engine is currently active, so a pinned/chosen engine is never hidden).
    // Persisted in localStorage.
    const engineControl = document.getElementById('engine-control') as HTMLElement | null;
    let enginePickerMode: 'always' | 'nonprolog' =
        localStorage.getItem('le-engine-picker-mode') === 'nonprolog' ? 'nonprolog' : 'always';
    let currentTargetLanguage = 'prolog';
    function applyEnginePickerVisibility() {
        if (!engineControl) return;
        const active = engineSelect ? engineSelect.value : 'prolog';
        const show = enginePickerMode === 'always'
            || currentTargetLanguage !== 'prolog'
            || active !== 'prolog';
        engineControl.style.display = show ? '' : 'none';
    }
    function updateEnginePickerChecks() {
        const a = document.getElementById('engine-always-check');
        const n = document.getElementById('engine-nonprolog-check');
        if (a) a.style.visibility = enginePickerMode === 'always' ? 'visible' : 'hidden';
        if (n) n.style.visibility = enginePickerMode === 'nonprolog' ? 'visible' : 'hidden';
    }
    function setEnginePickerMode(mode: 'always' | 'nonprolog') {
        enginePickerMode = mode;
        localStorage.setItem('le-engine-picker-mode', mode);
        updateEnginePickerChecks();
        applyEnginePickerVisibility();
    }
    document.getElementById('menu-engine-always')?.addEventListener('click', () => setEnginePickerMode('always'));
    document.getElementById('menu-engine-nonprolog')?.addEventListener('click', () => setEnginePickerMode('nonprolog'));
    // Track the declared target language from the editor text directly, so the
    // picker reflects the preference immediately (the module otherwise loads
    // lazily, e.g. on mouse-enter, which would delay the update). The load handler
    // still refines it from the authoritative server `res.target`.
    function refreshEnginePickerTarget() {
        try { currentTargetLanguage = detectTargetLanguage(programText()); }
        catch { currentTargetLanguage = 'prolog'; }
        applyEnginePickerVisibility();
    }
    updateEnginePickerChecks();
    refreshEnginePickerTarget();
    const btnQuery = document.getElementById('btn-query') as HTMLButtonElement;
    const btnTrace = document.getElementById('btn-trace') as HTMLButtonElement;
    const resultsDisplay = document.getElementById('results-display') as HTMLPreElement;

    const customScenarioContainer = document.getElementById('custom-scenario-container')!;
    const customScenarioText = document.getElementById('custom-scenario-text') as HTMLTextAreaElement;
    const customQueryContainer = document.getElementById('custom-query-container')!;
    const customQueryText = document.getElementById('custom-query-text') as HTMLTextAreaElement;

    // Reflect the current scenario/query selection in the URL (alongside the
    // example/text it was loaded from), so the user can copy a shareable link.
    // Only real named selections are written; placeholders/empties are removed.
    function updateUrlSelection() {
        const url = new URL(window.location.href);
        const sc = scenarioSelect.value;
        const q = querySelect.value;
        if (sc && sc !== '___custom___') url.searchParams.set('scenario', sc);
        else url.searchParams.delete('scenario');
        if (q && q !== '___custom___') url.searchParams.set('query', q);
        else url.searchParams.delete('query');
        // Engine is part of the shareable state (WP5); omit it for the default so
        // existing links stay clean.
        const eng = engineSelect ? engineSelect.value : 'prolog';
        if (eng && eng !== 'prolog') url.searchParams.set('engine', eng);
        else url.searchParams.delete('engine');
        // A change of scenario/query invalidates a previously selected answer; it is
        // re-added when an answer is selected after the query is (re-)run.
        url.searchParams.delete('answer');
        window.history.replaceState({}, '', url.toString());
    }

    // Reflect the currently-viewed answer (its 1-based order) in the URL, so a link
    // can point straight at one answer's explanation.
    function setAnswerInUrl(order: number) {
        const url = new URL(window.location.href);
        url.searchParams.set('answer', String(order));
        window.history.replaceState({}, '', url.toString());
    }

    scenarioSelect.addEventListener('change', () => {
        customScenarioContainer.style.display = scenarioSelect.value === '___custom___' ? 'flex' : 'none';
        updateQueryButtonState();
        updateUrlSelection();
    });

    querySelect.addEventListener('change', () => {
        customQueryContainer.style.display = querySelect.value === '___custom___' ? 'flex' : 'none';
        updateQueryButtonState();
        updateUrlSelection();
    });

    if (engineSelect) {
        engineSelect.addEventListener('change', () => {
            engineUserSet = true;
            updateQueryButtonState();
            updateUrlSelection();
            applyEnginePickerVisibility();
        });
    }

    const kbModuleDisplay = document.getElementById('kb-module-display')!;
    const sessionModuleDisplay = document.getElementById('session-module-display')!;

    const updateQueryButtonState = () => {
        if (!btnQuery) return;
        
        // the verifier's findings on the program in the panels (other tabs have their own)
        const markers = monaco.editor.getModelMarkers({ owner: 'le-verifier', resource: programModel().uri });
        const hasErrors = markers.some(m => m.severity === monaco.MarkerSeverity.Error);
        
        const scenarioSelected = true; // Allow empty scenario
        const querySelected = querySelect.value !== "";
        
        const disabled = hasErrors || !querySelected;
        
        btnQuery.disabled = disabled;
        // Trace is Prolog-only (WP5e): the s(CASP) justification tree supersedes
        // step tracing, so grey the button out under the s(CASP) engine.
        const scaspEngine = !!engineSelect && engineSelect.value === 'scasp';
        if (btnTrace) {
            btnTrace.disabled = disabled || scaspEngine;
            if (scaspEngine && !disabled) {
                btnTrace.title = 'Trace is only available with the Prolog engine; use the s(CASP) explanation tree instead.';
            }
        }
        if (scaspEngine && !disabled) return;

        if (hasErrors) {
            const title = 'Cannot query while there are errors in the document';
            btnQuery.title = title;
            if (btnTrace) btnTrace.title = title;
        } else if (!querySelected) {
            const title = 'Please select a query';
            btnQuery.title = title;
            if (btnTrace) btnTrace.title = title;
        } else {
            // Show template as tooltip if everything is OK
            const selectedOption = querySelect.options[querySelect.selectedIndex];
            if (selectedOption && selectedOption.dataset.template) {
                btnQuery.title = `Template: ${selectedOption.dataset.template}`;
            } else {
                btnQuery.title = '';
            }
            if (btnTrace) btnTrace.title = '';
        }
    };

    const updateMarkers = (issues: any[], model: any = programModel()) => {
        if (!model) return;

        issueFixes.clear();
        // An issue of an included resource is shown on the document's
        // "includes these resources" section, saying where it really is.
        const includeSection = (includedResources || []).find((r: any) => !isForeignOffset(r.start));
        const markers = issues.map((issue: any) => {
            const foreign = isForeignOffset(issue.start);
            const start = foreign ? (includeSection ? includeSection.start : 0) : issue.start;
            const end = foreign ? (includeSection ? includeSection.end : 0) : issue.end;
            const startPos = model.getPositionAt(start);
            const endPos = model.getPositionAt(end);
            const message = foreign
                ? `${t('In the included resource')} ${describeResourceRange(issue)}: ${issue.message}`
                : issue.message;
            const marker = {
                severity: issue.severity === 'error' ? monaco.MarkerSeverity.Error : monaco.MarkerSeverity.Warning,
                startLineNumber: startPos.lineNumber,
                startColumn: startPos.column,
                endLineNumber: endPos.lineNumber,
                endColumn: endPos.column,
                message,
                source: 'LE Verifier'
            };
            if (issue.fix) {
                issueFixes.set(getMarkerKey(marker), issue.fix);
            }
            return marker;
        });

        monaco.editor.setModelMarkers(model, 'le-verifier', markers);
        updateQueryButtonState();
    };

    // Loads the program in the panels on the server. A load already under
    // way is shared, not repeated: its callers all wait for it. While it runs
    // the pickers show a busy cursor. A load overtaken by a switch of program
    // (switchPanel) is dropped: it reports false and touches nothing.
    let loadPromise: Promise<boolean> | null = null;
    let loadGen = 0;
    const queryTab = document.getElementById('query-tab');
    const loadModule = (): Promise<boolean> => {
        if (isLoaded) return Promise.resolve(true);
        if (isLoading && loadPromise) return loadPromise;
        const gen = ++loadGen;
        isLoading = true;
        queryTab?.classList.add('le-loading');
        loadPromise = loadProgram(gen).finally(() => {
            if (gen === loadGen) {
                isLoading = false;
                loadPromise = null;
                queryTab?.classList.remove('le-loading');
            }
        });
        return loadPromise;
    };

    const loadProgram = async (gen: number): Promise<boolean> => {
        const doc = panelDoc;
        resultsDisplay.textContent = t('Loading module on server...');
        try {
            const response = await fetch('/leapi', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    token: 'myToken123',
                    operation: 'load',
                    le: doc.model.getValue(),
                    // The example this text came from, so the server resolves
                    // relative include resources against the example's folder.
                    source: doc.example || '',
                    // If the document was fetched from a URL, its base URL, so
                    // relative includes resolve against the remote location.
                    base: doc.baseUrl || ''
                })
            });
            const res = await response.json();
            if (gen !== loadGen) return false;   // another program took the panels meanwhile
            
            if (res && res.sessionModule) {
                sessionModule = res.sessionModule;
                isLoaded = true;
                lastIssues = res.issues || [];
                lastLoadError = '';
                includedResources = res.included_resources || [];
                lastTemplateDefs = res.template_defs || [];
                setCitations(doc.model, res.citations || []);

                kbModuleDisplay.textContent = `KB: ${res.kb || 'unknown'}`;
                sessionModuleDisplay.textContent = `Session: ${sessionModule}`;

                // Pre-select the engine from the program's declared target
                // (`the target language is: …`), unless the user already chose one
                // or the URL pins `engine` (which applyUrlSelection restores).
                if (engineSelect && !engineUserSet) {
                    const urlEngine = new URLSearchParams(window.location.search).get('engine');
                    if (!urlEngine && (res.target === 'prolog' || res.target === 'scasp')) {
                        engineSelect.value = res.target;
                        updateQueryButtonState();
                        updateUrlSelection();
                    }
                }

                // Engine-picker visibility tracks the program's declared target
                // language (see the 'nonprolog' preference in the Misc menu).
                currentTargetLanguage = (typeof res.target === 'string') ? res.target : 'prolog';
                applyEnginePickerVisibility();
                
                graphChannel.postMessage({
                    type: 'module-loaded',
                    data: { sessionModule }
                });

                // Populate scenarios
                scenarioSelect.innerHTML = `<option value="">${t('[Empty Scenario]')}</option>`;
                if (res.examples) {
                    res.examples.forEach((ex: any) => {
                        if (ex.name) {
                            const option = document.createElement('option');
                            option.value = ex.name;
                            option.textContent = ex.name;
                            scenarioSelect.appendChild(option);
                        }
                    });
                }
                const anotherScenarioOption = document.createElement('option');
                anotherScenarioOption.value = '___custom___';
                anotherScenarioOption.textContent = t('Another...');
                scenarioSelect.appendChild(anotherScenarioOption);
                
                // Remember the KB name and query list for the Scenario Variations window.
                lastKb = res.kb || '';
                lastFactImages = Array.isArray(res.fact_images) ? res.fact_images : [];
                lastTemplateImages = Array.isArray(res.template_images) ? res.template_images : [];
                lastQueries = Array.isArray(res.queries) ? res.queries : [];

                // Populate queries
                querySelect.innerHTML = `<option value="">${t('Select a query...')}</option>`;
                if (res.queries) {
                    res.queries.forEach((q: any) => {
                        const option = document.createElement('option');
                        // q is now an object with name, template, and le
                        option.value = q.name;
                        const label = q.le || q.template;
                        const full = q.name ? `${label} (${q.name})` : label;
                        // Long queries make the picker so wide it pushes the panel
                        // buttons off screen: truncate the query text to 70 chars,
                        // suffix "...(name)", and keep the full text as a tooltip.
                        const MAX_QUERY_LABEL = 70;
                        if (label.length > MAX_QUERY_LABEL) {
                            const suffix = q.name ? `...(${q.name})` : '...';
                            option.textContent = label.slice(0, MAX_QUERY_LABEL).trimEnd() + suffix;
                        } else {
                            option.textContent = full;
                        }
                        option.title = full;
                        option.dataset.template = q.template;
                        querySelect.appendChild(option);
                    });
                }
                const anotherQueryOption = document.createElement('option');
                anotherQueryOption.value = '___custom___';
                anotherQueryOption.textContent = t('Another...');
                querySelect.appendChild(anotherQueryOption);
                
                if (res.issues) {
                    updateMarkers(res.issues);
                } else {
                    updateMarkers([]);
                }

                resultsDisplay.textContent = t('Results');
                return true;
            } else {
                lastLoadError = res?.error || 'Unknown error';
                resultsDisplay.textContent = t('Error loading module: ') + lastLoadError;
                updateMarkers([]);
                return false;
            }
        } catch (err) {
            if (gen !== loadGen) return false;
            lastLoadError = 'Error connecting to server.';
            resultsDisplay.textContent = lastLoadError;
            console.error(err);
            updateMarkers([]);
            return false;
        }
    };

    // A short modal dialog (used to report problems applying URL parameters).
    function showModal(message: string, title = 'Notice') {
        const overlay = document.createElement('div');
        overlay.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.5);z-index:10000;display:flex;align-items:center;justify-content:center;';
        const box = document.createElement('div');
        box.style.cssText = 'background:#252526;color:#ddd;border:1px solid #555;border-radius:8px;max-width:480px;padding:20px;box-shadow:0 8px 24px rgba(0,0,0,0.5);font-family:sans-serif;';
        const h = document.createElement('div');
        h.textContent = title;
        h.style.cssText = 'font-weight:bold;font-size:15px;margin-bottom:10px;';
        const p = document.createElement('div');
        p.textContent = message;
        p.style.cssText = 'font-size:13px;line-height:1.5;white-space:pre-wrap;margin-bottom:16px;';
        const btn = document.createElement('button');
        btn.textContent = t('OK');
        btn.style.cssText = 'float:right;padding:6px 16px;background:#0e639c;color:#fff;border:none;border-radius:4px;cursor:pointer;';
        const close = () => overlay.remove();
        btn.addEventListener('click', close);
        overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });
        box.appendChild(h); box.appendChild(p); box.appendChild(btn);
        overlay.appendChild(box);
        document.body.appendChild(overlay);
        btn.focus();
    }

    // Apply the optional `scenario` / `query` URL parameters: select the named
    // scenario and/or query in the menus (without running the query — the user
    // presses the button). Reports problems (errors in the document, or an
    // unknown scenario/query) in a modal.
    function selectIfPresent(select: HTMLSelectElement, value: string): boolean {
        const opt = Array.from(select.options).find(o => o.value === value);
        if (!opt) return false;
        select.value = value;
        select.dispatchEvent(new Event('change'));
        return true;
    }
    async function applyUrlSelection() {
        const p = new URLSearchParams(window.location.search);
        const scenarioParam = p.get('scenario');
        const queryParam = p.get('query');
        // The scenario/query parameters only make sense for a document loaded via
        // `example` or `text`.
        if ((!scenarioParam && !queryParam) || !(p.get('example') || p.get('text'))) return;
        const ok = await loadModule();
        if (!ok) {
            showModal('Could not load the document.' + (lastLoadError ? '\n\n' + lastLoadError : ''), 'Cannot select scenario/query');
            return;
        }
        const errs = lastIssues.filter((i: any) => i.severity === 'error');
        if (errs.length > 0) {
            const list = errs.slice(0, 5).map((e: any) => '• ' + e.message).join('\n');
            showModal('The document has errors; fix them before selecting a scenario or query:\n\n' + list, 'Document has errors');
            return;
        }
        if (scenarioParam && !selectIfPresent(scenarioSelect, scenarioParam)) {
            showModal(`Scenario "${scenarioParam}" does not exist in this document.`, 'Unknown scenario');
            return;
        }
        if (queryParam && !selectIfPresent(querySelect, queryParam)) {
            showModal(`Query "${queryParam}" does not exist in this document.`, 'Unknown query');
            return;
        }
        // Restore the engine choice (WP5) so a shared link pins program + scenario
        // + query + engine.
        const engineParam = p.get('engine');
        if (engineParam && engineSelect) {
            selectIfPresent(engineSelect, engineParam);
            updateQueryButtonState();
            applyEnginePickerVisibility();   // a pinned non-prolog engine must stay visible
        }
        // `answer` runs the (just-selected) query and selects the answer with the
        // given 1-based order, so its explanation is shown. Requires scenario+query.
        const answerParam = p.get('answer');
        if (answerParam) {
            if (!scenarioParam || !queryParam) {
                showModal('The "answer" parameter requires both a "scenario" and a "query".', 'Cannot select answer');
                return;
            }
            const n = parseInt(answerParam, 10);
            if (!Number.isInteger(n) || n < 1) {
                showModal(`Invalid answer order "${answerParam}" — expected a positive whole number.`, 'Cannot select answer');
                return;
            }
            if (btnQuery.disabled) {
                showModal('The query cannot be run (the document has errors or no query is selected).', 'Cannot select answer');
                return;
            }
            pendingAnswerIndex = n - 1;
            btnQuery.click();   // executes the query; the Nth answer is auto-selected
        }
    }

    scenarioSelect.addEventListener('mouseenter', () => {
        if (!isLoaded && !isLoading) loadModule();
    });

    querySelect.addEventListener('mouseenter', () => {
        if (!isLoaded && !isLoading) loadModule();
    });

    // A picker clicked before its program is loaded: the menu can only list the
    // scenarios/queries once the server has read the program, which for a large
    // one takes seconds. Meanwhile the whole window shows a waiting cursor; the
    // menu opens when the load is done.
    const openPickerAfterLoad = async (select: HTMLSelectElement, e: MouseEvent) => {
        if (isLoaded) return;
        e.preventDefault();
        document.body.classList.add('le-busy');
        let ok = false;
        try {
            ok = await loadModule();
        } finally {
            document.body.classList.remove('le-busy');
        }
        if (!ok) return;
        select.focus();
        // showPicker needs the click's user activation, which a long load may
        // outlive: then the picker is focused (keyboard arrows open it).
        try { (select as any).showPicker?.(); } catch { /* focused only */ }
    };
    scenarioSelect.addEventListener('mousedown', (e) => { openPickerAfterLoad(scenarioSelect, e); });
    querySelect.addEventListener('mousedown', (e) => { openPickerAfterLoad(querySelect, e); });

    // If the URL carried scenario/query parameters, apply them now (the document
    // has been loaded into the editor from example/text above).
    applyUrlSelection();

    const bottomPanel = document.getElementById('bottom-panel')!;
    const resizer = document.getElementById('resizer')!;

    let isResizing = false;
    resizer.addEventListener('mousedown', (e) => {
        isResizing = true;
        document.body.style.cursor = 'ns-resize';
    });

    document.addEventListener('mousemove', (e) => {
        if (!isResizing) return;
        const offsetTop = e.clientY;
        const windowHeight = window.innerHeight;
        const headerHeight = container.getBoundingClientRect().top; // header, menu bar, file tabs
        const newContainerHeight = offsetTop - headerHeight;
        const newPanelHeight = windowHeight - offsetTop - 5; // 5 is resizer height

        if (newContainerHeight > 100 && newPanelHeight > 100) {
            container.style.height = `${newContainerHeight}px`;
            bottomPanel.style.height = `${newPanelHeight}px`;
            editor.layout();
        }
    });

    document.addEventListener('mouseup', () => {
        isResizing = false;
        document.body.style.cursor = 'default';
    });

    const resultsResizer = document.getElementById('results-resizer')!;
    const answersPanel = document.getElementById('answers-panel')!;
    let isResizingResults = false;

    resultsResizer.addEventListener('mousedown', (e) => {
        isResizingResults = true;
        document.body.style.cursor = 'ew-resize';
    });

    document.addEventListener('mousemove', (e) => {
        if (!isResizingResults) return;
        const resultsArea = document.getElementById('results-area')!;
        const rect = resultsArea.getBoundingClientRect();
        const offsetLeft = e.clientX - rect.left;
        const percentage = (offsetLeft / rect.width) * 100;

        if (percentage > 10 && percentage < 90) {
            answersPanel.style.width = `${percentage}%`;
        }
    });

    document.addEventListener('mouseup', () => {
        isResizingResults = false;
        if (!isResizing) document.body.style.cursor = 'default';
    });

    // The answers + explanation of the program in the panels. Each open
    // program has its own pair of elements and view (switchPanel swaps them
    // in), so going back to a tab finds its answers as they were.
    let answersList = document.getElementById('answers-list')!;
    let explanationTree = document.getElementById('explanation-tree')!;

    // The answers + explanation view (Query panel body), now a reusable component
    // shared with the Scenario Variations window. Source navigation selects the range
    // in this editor; answer selection keeps the URL's `answer` param in sync.
    const makeExplanationView = (answersList: HTMLElement, explanationTree: HTMLElement) => new ExplanationView({
        answersList,
        explanationTree,
        explanationTitle: document.getElementById('explanation-title') || undefined,
        menus: {
            answerContextMenu: document.getElementById('answer-context-menu')!,
            menuCopyAnswer: document.getElementById('menu-copy-answer')!,
            explanationContextMenu: document.getElementById('explanation-context-menu')!,
            menuCopyExplanation: document.getElementById('menu-copy-explanation')!,
            menuCopyMermaid: document.getElementById('menu-copy-mermaid')!,
            menuGotoOriginal: document.getElementById('menu-goto-original')!,
            answerTooltip: document.getElementById('answer-tooltip')!,
            titleMenu: document.getElementById('explanation-title-menu')!,
            menuShowStrongest: document.getElementById('menu-show-strongest')!,
            menuExplanationDrill: document.getElementById('menu-explanation-drill')!,
            menuBentoBox: document.getElementById('menu-bento-box') || undefined,
        },
        onOpenBento: (why: any, answer: string) => {
            localStorage.setItem('le_bento_box_data', JSON.stringify({ kbName: lastKb, answer, why, factImages: lastFactImages, templateImages: lastTemplateImages }));
            const currentTheme = document.body.className.includes('light-theme') ? 'light-theme' :
                                 document.body.className.includes('hc-theme') ? 'hc-theme' : '';
            window.open(`bento-box.html?theme=${currentTheme}&v=${Date.now()}`, '_blank');
        },
        onOpenDrill: (why: any) => {
            if (!sessionModule) { showModal('Load the module and run a query first.', 'Explanation Drill'); return; }
            // Pass the program so the drill window can run its OWN independent session.
            localStorage.setItem('le_explanation_drill_data', JSON.stringify({ source: programText(), sessionModule, kbName: lastKb, why }));
            const currentTheme = document.body.className.includes('light-theme') ? 'light-theme' :
                                 document.body.className.includes('hc-theme') ? 'hc-theme' : '';
            window.open(`explanation-drill.html?theme=${currentTheme}&v=${Date.now()}`, '_blank');
        },
        failedNodePrefix: () => failedNodePrefix,
        hierarchicalNumbering: () => showHierarchicalNumbering,
        onNavigate: (start: number, end: number) => {
            showProgramInEditor();
            const model = editor.getModel();
            const startPos = model.getPositionAt(start);
            const endPos = model.getPositionAt(end);
            const range = new monaco.Range(startPos.lineNumber, startPos.column, endPos.lineNumber, endPos.column);
            editor.setSelection(range);
            editor.revealRangeInCenter(range);
            editor.focus();
        },
        onSelectAnswer: (index: number) => setAnswerInUrl(index),
        documentContext: () => ({
            source: panelDoc.example || '',
            base: panelDoc.baseUrl || '',
        }),
    });
    let explView = makeExplanationView(answersList, explanationTree);

    const debugPanel = document.getElementById('debug-panel')!;
    const debugStack = document.getElementById('debug-stack')!;
    const debugVariables = document.getElementById('debug-variables')!;
    const debugStatus = document.getElementById('debug-status')!;
    const debugContinue = document.getElementById('debug-continue') as HTMLButtonElement;
    const debugStep = document.getElementById('debug-step') as HTMLButtonElement;
    const debugStop = document.getElementById('debug-stop') as HTMLButtonElement;
    const debugClose = document.getElementById('debug-panel-close')!;
    let debugFrames: any[] = [];        // last stackTrace frames (DAP order: [0]=current/deepest)
    let debugSelectedFrameId = 1;       // frame whose variables are shown
    const debugHeader = document.getElementById('debug-panel-header')!;

    let dapSocket: WebSocket | null = null;
    let dapSeq = 1;
    let debugDecorations: string[] = [];

    const sendDapRequest = (command: string, args: any = {}) => {
        if (!dapSocket || dapSocket.readyState !== WebSocket.OPEN) return;
        const request = {
            seq: dapSeq++,
            type: 'request',
            command: command,
            arguments: args
        };
        console.log('Sending DAP Request:', request);
        dapSocket.send(JSON.stringify(request));
    };

    const startTrace = async () => {
        if (!isLoaded) {
            const success = await loadModule();
            if (!success) return;
        }

        const scenario = scenarioSelect.value;
        const query = querySelect.value;
        const customScenario = scenario === '___custom___' ? customScenarioText.value : null;
        const customQuery = query === '___custom___' ? customQueryText.value : null;

        debugPanel.style.display = 'flex';
        debugStatus.textContent = t('Connecting to debugger...');
        debugStack.innerHTML = '';
        debugVariables.innerHTML = '';
        debugContinue.disabled = false;
        debugStep.disabled = false;
        debugStop.disabled = false;

        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${window.location.host}/dap?sessionModule=${sessionModule}`;
        
        if (dapSocket) dapSocket.close();
        dapSocket = new WebSocket(wsUrl);

        dapSocket.onopen = () => {
            debugStatus.textContent = t('Debugger connected. Initializing...');
            sendDapRequest('initialize', { adapterID: 'le-debug' });
            sendDapRequest('launch', {});
            
            // Start the query in debug mode
            fetch('/leapi', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    token: 'myToken123',
                    operation: 'answeringQuery',
                    sessionModule: sessionModule,
                    query: query,
                    scenario: scenario,
                    customScenario: customScenario,
                    customQuery: customQuery,
                    debug: true,
                    detailedFailures: detailedFailures,
                    hideRepeated: hideRepeatedExplanations,
                    largerImportantReasons: largerImportantReasons
                })
            }).then(res => res.json()).then(data => {
                console.log('Debug query finished', data);
                debugStatus.textContent = t('Query finished.');
                debugContinue.disabled = true;
                debugStep.disabled = true;
                debugStop.disabled = true;
                debugDecorations = editor.deltaDecorations(debugDecorations, []);
            }).catch(err => {
                console.error('Debug query failed', err);
                debugStatus.textContent = t('Query failed.');
                debugContinue.disabled = true;
                debugStep.disabled = true;
                debugStop.disabled = true;
                debugDecorations = editor.deltaDecorations(debugDecorations, []);
            });
        };

        dapSocket.onmessage = (event) => {
            const msg = JSON.parse(event.data);
            console.log('DAP Message:', msg);
            if (msg.type === 'event' && msg.event === 'stopped') {
                debugStatus.textContent = `Stopped: ${msg.body.reason}`;
                sendDapRequest('stackTrace', { threadId: 1 });
            } else if (msg.type === 'response' && msg.success) {
                if (msg.command === 'stackTrace') {
                    debugFrames = msg.body.stackFrames || [];
                    renderStack(debugFrames);
                    // Auto-select the current (deepest) frame: highlight its source
                    // span and show its variables.
                    if (debugFrames.length > 0) selectFrame(debugFrames[0].id);
                } else if (msg.command === 'scopes') {
                    if (msg.body.scopes && msg.body.scopes.length > 0) {
                        sendDapRequest('variables', { variablesReference: msg.body.scopes[0].variablesReference });
                    }
                } else if (msg.command === 'variables') {
                    renderVariables(msg.body.variables);
                }
            } else if (msg.type === 'response' && !msg.success) {
                console.error(`DAP Command failed: ${msg.command}`, msg.message);
            }
        };

        dapSocket.onclose = () => {
            debugStatus.textContent = t('Debugger disconnected.');
            debugContinue.disabled = true;
            debugStep.disabled = true;
                debugStop.disabled = true;
            debugDecorations = editor.deltaDecorations(debugDecorations, []);
        };
    };

    // The frames arrive innermost-first (DAP order). We render them TOP-DOWN — the
    // root query at the top, the goal executing right now at the bottom — mirroring
    // top-down LE/Prolog execution.
    const renderStack = (frames: any[]) => {
        debugStack.innerHTML = '';
        const model = programModel();

        [...frames].reverse().forEach((f) => {
            const div = document.createElement('div');
            div.className = 'stack-frame';
            div.dataset.frameId = String(f.id);
            if (f.id === 1) div.classList.add('executing');   // deepest = current goal

            const pos = f.offset !== undefined && !isForeignOffset(f.offset)
                ? model.getPositionAt(f.offset) : { lineNumber: 1, column: 1 };

            const nameSpan = document.createElement('span');
            nameSpan.className = 'stack-frame-name';
            nameSpan.textContent = f.name;
            div.appendChild(nameSpan);

            const sourceSpan = document.createElement('span');
            sourceSpan.className = 'stack-frame-source';
            sourceSpan.textContent = `${f.source.name}:${pos.lineNumber}`;
            div.appendChild(sourceSpan);

            div.onclick = () => selectFrame(f.id);
            debugStack.appendChild(div);
        });
    };

    // Highlight a frame's exact source span in the editor and reveal it.
    const highlightFrameRange = (f: any) => {
        showProgramInEditor();
        const model = editor.getModel();
        if (!f || f.offset === undefined || isForeignOffset(f.offset)) {
            debugDecorations = editor.deltaDecorations(debugDecorations, []);
            return;
        }
        const start = model.getPositionAt(f.offset);
        const hasSpan = f.endOffset !== undefined && f.endOffset > f.offset;
        const end = hasSpan ? model.getPositionAt(f.endOffset) : start;
        const range = new monaco.Range(start.lineNumber, start.column, end.lineNumber, end.column);
        editor.revealRangeInCenterIfOutsideViewport(range);
        debugDecorations = editor.deltaDecorations(debugDecorations, [
            {
                range: new monaco.Range(start.lineNumber, 1, start.lineNumber, 1),
                options: { isWholeLine: true, className: 'debug-line-highlight', glyphMarginClassName: 'debug-anchor-glyph' }
            },
            ...(hasSpan ? [{
                range,
                options: { className: 'debug-range-highlight', inlineClassName: 'debug-range-highlight' }
            }] : [])
        ]);
    };

    // Select a stack frame: mark it, highlight its source, and load its variables.
    const selectFrame = (frameId: number) => {
        debugSelectedFrameId = frameId;
        const f = debugFrames.find(fr => fr.id === frameId);
        document.querySelectorAll('.stack-frame').forEach(el => {
            el.classList.toggle('selected', (el as HTMLElement).dataset.frameId === String(frameId));
        });
        if (f) highlightFrameRange(f);
        sendDapRequest('scopes', { frameId });
    };

    const renderVariables = (vars: any[]) => {
        debugVariables.innerHTML = '';
        if (!vars || vars.length === 0) {
            const empty = document.createElement('div');
            empty.style.padding = '4px 6px';
            empty.style.color = '#888';
            empty.textContent = t('No variables for this call.');
            debugVariables.appendChild(empty);
            return;
        }
        vars.forEach(v => {
            const div = document.createElement('div');
            div.style.padding = '2px 5px';
            div.style.fontFamily = 'monospace';
            const name = document.createElement('span');
            name.className = 'debug-var-name';
            name.textContent = v.name;
            const val = document.createElement('span');
            const unbound = v.value === '(unbound)';
            val.className = unbound ? 'debug-var-unbound' : 'debug-var-value';
            val.textContent = unbound ? ' = ?' : ` = ${v.value}`;
            div.appendChild(name);
            div.appendChild(val);
            debugVariables.appendChild(div);
        });
    };

    btnTrace.addEventListener('click', startTrace);

    debugContinue.onclick = () => sendDapRequest('continue', { threadId: 1 });
    debugStep.onclick = () => sendDapRequest('stepIn', { threadId: 1 });
    debugStop.onclick = () => {
        sendDapRequest('disconnect', {});
        debugStatus.textContent = t('Trace stopped.');
        debugContinue.disabled = true;
        debugStep.disabled = true;
                debugStop.disabled = true;
        debugDecorations = editor.deltaDecorations(debugDecorations, []);
    };
    debugClose.onclick = () => {
        debugPanel.style.display = 'none';
        debugDecorations = editor.deltaDecorations(debugDecorations, []);
        if (dapSocket) {
            sendDapRequest('disconnect');
            dapSocket.close();
        }
    };

    // Draggable logic for Debug Panel
    let isDraggingDebug = false;
    let debugStartX: number, debugStartY: number;
    let debugStartLeft: number, debugStartTop: number;

    debugHeader.onmousedown = (e) => {
        isDraggingDebug = true;
        debugStartX = e.clientX;
        debugStartY = e.clientY;
        debugStartLeft = debugPanel.offsetLeft;
        debugStartTop = debugPanel.offsetTop;
        document.body.style.userSelect = 'none';
    };

    document.addEventListener('mousemove', (e) => {
        if (!isDraggingDebug) return;
        const dx = e.clientX - debugStartX;
        const dy = e.clientY - debugStartY;
        debugPanel.style.left = `${debugStartLeft + dx}px`;
        debugPanel.style.top = `${debugStartTop + dy}px`;
    });

    document.addEventListener('mouseup', () => {
        isDraggingDebug = false;
        document.body.style.userSelect = 'auto';
    });

    // Interrupt support for long-running queries: the button appears after 2s of
    // waiting and signals the server to abort the in-progress query.
    const btnInterruptQuery = document.getElementById('btn-interrupt-query') as HTMLButtonElement;
    let interruptTimer: number | undefined;
    const showInterruptSoon = () => {
        clearTimeout(interruptTimer);
        btnInterruptQuery.style.display = 'none';
        btnInterruptQuery.disabled = false;
        interruptTimer = window.setTimeout(() => {
            btnInterruptQuery.style.display = '';
            // Show a waiting cursor while the (long-running) query is in progress.
            document.body.style.cursor = 'wait';
        }, 2000);
    };
    const hideInterrupt = () => {
        clearTimeout(interruptTimer);
        interruptTimer = undefined;
        btnInterruptQuery.style.display = 'none';
        document.body.style.cursor = '';
    };
    btnInterruptQuery.addEventListener('click', () => {
        btnInterruptQuery.disabled = true;
        btnInterruptQuery.textContent = t('Interrupting…');
        fetch('/leapi', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ token: 'myToken123', operation: 'interruptQuery', sessionModule: sessionModule })
        }).catch(() => {}).finally(() => { btnInterruptQuery.textContent = t('Interrupt'); });
    });

    btnQuery.addEventListener('click', async () => {
        if (!isLoaded) {
            const success = await loadModule();
            if (!success) return;
        }

        const scenario = scenarioSelect.value;
        const query = querySelect.value;
        
        const customScenario = scenario === '___custom___' ? customScenarioText.value : null;
        const customQuery = query === '___custom___' ? customQueryText.value : null;

        if (!query) {
            resultsDisplay.textContent = t('Please select a query.');
            return;
        }
        
        if (query === '___custom___' && !customQuery) {
            resultsDisplay.textContent = t('Please enter a custom query.');
            return;
        }
        
        // A pending answer selection (from the `answer` URL parameter) applies to
        // this run only.
        const wantAnswer = pendingAnswerIndex;
        pendingAnswerIndex = null;

        // The answers go to this program's view, even if another tab takes
        // the panels while the query runs.
        const view = explView;
        const answersEl = answersList;
        answersList.innerHTML = '<div style="color: #888;">Executing query...</div>';
        explanationTree.innerHTML = '';
        showInterruptSoon();

        // Engine selector (WP5): Prolog (default) or s(CASP). The s(CASP) path
        // hits a different endpoint but returns the same {results:[{answer, why}]}
        // shape, so the explanation view renders it unchanged; each result is one
        // stable model (model grouping reads naturally as one answer card each).
        const engine = engineSelect ? engineSelect.value : 'prolog';

        try {
            const runAnsweringQuery = () => fetch('/leapi', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(
                    engine === 'scasp'
                    ? {
                        token: 'myToken123',
                        operation: 'scaspQuery',
                        sessionModule: sessionModule,
                        query: query,
                        scenario: scenario,
                        customScenario: customScenario,
                        customQuery: customQuery
                    }
                    : {
                        token: 'myToken123',
                        operation: 'answeringQuery',
                        sessionModule: sessionModule,
                        query: query,
                        scenario: scenario,
                        customScenario: customScenario,
                        customQuery: customQuery,
                        detailedFailures: detailedFailures,
                        hideRepeated: hideRepeatedExplanations,
                        largerImportantReasons: largerImportantReasons
                    })
            }).then(r => r.json());

            let res = await runAnsweringQuery();
            // The server reclaims long-idle sessions; if ours was reclaimed,
            // transparently reload the module and retry the query once.
            if (res && res.session_expired) {
                isLoaded = false;
                if (await loadModule()) {
                    scenarioSelect.value = scenario;
                    querySelect.value = query;
                    res = await runAnsweringQuery();
                }
            }

            // Which answer to auto-select: the one asked for by `answer` (if in
            // range), otherwise the first. Warn if the requested one does not exist.
            const nResults = (res && res.results) ? res.results.length : 0;
            let target = 0;
            if (wantAnswer !== null) {
                if (nResults > 0 && wantAnswer >= 0 && wantAnswer < nResults) target = wantAnswer;
                else if (nResults > 0) showModal(`Answer ${wantAnswer + 1} does not exist — the query has ${nResults} answer(s) in this scenario.`, 'No such answer');
                else if (res && res.why) showModal('The query has no answers (it is false in this scenario), so there is no answer to select.', 'No such answer');
            }
            view.showResults(res, target);
        } catch (err) {
            answersEl.textContent = t('Error executing query.');
            console.error(err);
        } finally {
            hideInterrupt();
        }
    });

    // --- Flip -----------------------------------------------------------------
    // A flip query (docs/le_summary.md §17.7) about what is on screen: "which
    // minimal change to the scenario makes it the case that <goal>". The goal
    // is the selected answer, negated — what would make it not so — or, when
    // the query has no answer, the query itself; the author may edit either.
    // It runs as a custom query, so the sentence stays in view and the answers
    // (the change sets) and their proofs show in the usual panels.
    const flipModal = document.getElementById('flip-modal') as HTMLElement | null;
    const flipGoal = document.getElementById('flip-goal') as HTMLTextAreaElement | null;
    const flipNot = document.getElementById('flip-not') as HTMLInputElement | null;
    const flipPhrase = (key: string): string => {
        const lang = detectProgramLanguage(programText());
        return kwPhrases(lang, key)[0] || kwPhrases('en', key)[0] || '';
    };
    const closeFlip = () => { if (flipModal) flipModal.style.display = 'none'; };
    document.getElementById('flip-close')?.addEventListener('click', closeFlip);
    document.getElementById('flip-cancel')?.addEventListener('click', closeFlip);
    flipModal?.addEventListener('click', (e) => { if (e.target === flipModal) closeFlip(); });

    document.getElementById('btn-flip')?.addEventListener('click', async () => {
        if (!flipModal || !flipGoal || !flipNot) return;
        if (!isLoaded) { const ok = await loadModule(); if (!ok) return; }
        const opener = flipPhrase('flip_query');
        const notWords = flipPhrase('not_the_case');
        let goal = '';
        let negate = false;
        const current = querySelect.value === '___custom___' ? customQueryText.value.trim() : '';
        if (current && opener && current.toLowerCase().startsWith(opener.toLowerCase())) {
            // already a flip: offer it again, to edit
            goal = current.slice(opener.length).trim().replace(/\.$/, '');
            if (notWords && goal.toLowerCase().startsWith(notWords.toLowerCase())) {
                negate = true;
                goal = goal.slice(notWords.length).trim();
            }
        } else if (explView.selectedAnswer) {
            goal = explView.selectedAnswer;
            negate = true;
        } else {
            const q = lastQueries.find((x: any) => x.name === querySelect.value);
            goal = q ? (q.le || '') : current;
        }
        (document.getElementById('flip-opener') as HTMLElement).textContent = `${opener} …`;
        (document.getElementById('flip-not-words') as HTMLElement).textContent = notWords;
        flipNot.checked = negate;
        flipGoal.value = goal;
        flipModal.style.display = 'flex';
        flipGoal.focus();
    });

    document.getElementById('flip-run')?.addEventListener('click', () => {
        if (!flipGoal || !flipNot) return;
        const goal = flipGoal.value.trim().replace(/\.$/, '');
        if (!goal) return;
        const text = `${flipPhrase('flip_query')} ${flipNot.checked ? flipPhrase('not_the_case') + ' ' : ''}${goal}`;
        querySelect.value = '___custom___';
        customQueryContainer.style.display = 'flex';
        customQueryText.value = text;
        updateQueryButtonState();
        updateUrlSelection();
        closeFlip();
        btnQuery.click();
    });

    const btnProofGame = document.getElementById('btn-proof-game') as HTMLButtonElement;
    
    btnProofGame.addEventListener('click', async () => {
        if (!isLoaded) {
            const success = await loadModule();
            if (!success) return;
        }
        
        const scenario = scenarioSelect.value;
        const query = querySelect.value;
        
        const customScenario = scenario === '___custom___' ? customScenarioText.value : null;
        const customQuery = query === '___custom___' ? customQueryText.value : null;

        if (!query) {
            alert(t('Please select a query for the Proof Game.'));
            return;
        }
        
        // Fetch the rules and facts from the server to populate the game
        try {
            const runGetGameData = () => fetch('/leapi', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    token: 'myToken123',
                    operation: 'getGameData',
                    sessionModule: sessionModule,
                    query: query,
                    scenario: scenario,
                    customScenario: customScenario,
                    customQuery: customQuery,
                    detailedFailures: detailedFailures,
                    hideRepeated: hideRepeatedExplanations,
                    largerImportantReasons: largerImportantReasons
                })
            }).then(r => r.json());

            let res = await runGetGameData();
            // Reload and retry once if the session was reclaimed for being idle.
            if (res && res.session_expired) {
                isLoaded = false;
                if (await loadModule()) {
                    scenarioSelect.value = scenario;
                    querySelect.value = query;
                    res = await runGetGameData();
                }
            }

            if (res && res.gameData) {
                const text = programText();
                
                // Process rules to extract exact text
                res.gameData.rules = res.gameData.rules.map((rule: any) => {
                    if (rule.start !== undefined && rule.end !== undefined) {
                        const ruleText = text.substring(rule.start, rule.end);
                        const lines = ruleText.split('\n').map(l => l.trim()).filter(l => l.length > 0);
                        
                        let exactHead = null;
                        let exactBody = null;
                        
                        if (lines.length > 1) {
                            // Multi-line rule
                            exactHead = lines[0].replace(/:$/, '').replace(/^(?:only\s+if|if)\b/i, '').trim();
                            let bodyLines = lines.slice(1);
                            if (bodyLines[0].toLowerCase() === 'if' || bodyLines[0].toLowerCase() === 'only if') {
                                bodyLines = bodyLines.slice(1);
                            }
                            exactBody = bodyLines.map(l => l.replace(/^(?:only\s+if|if|and|or)\b/i, '').replace(/\b(?:and|or)$/i, '').replace(/\.$/, '').trim());
                        } else if (lines.length === 1) {
                            // Single-line rule
                            const match = lines[0].match(/\b(?:only\s+if|if)\b/i);
                            if (match) {
                                exactHead = lines[0].substring(0, match.index).replace(/:$/, '').trim();
                                const bodyStr = lines[0].substring(match.index + match[0].length).replace(/\.$/, '').trim();
                                exactBody = bodyStr.split(/\band\b|\bor\b/i).map(s => s.trim());
                            }
                        }
                        
                        // Only use exact text if the number of body conditions matches
                        if (exactHead && exactBody && exactBody.length === rule.body.length) {
                            rule.head = exactHead;
                            rule.body = exactBody;
                        }
                    }
                    return rule;
                });
                
                // Process facts to extract exact text
                res.gameData.facts = res.gameData.facts.map((fact: any) => {
                    if (fact.start !== undefined && fact.end !== undefined && fact.start !== 0) {
                        const factText = text.substring(fact.start, fact.end).replace(/\.$/, '').trim();
                        if (factText) {
                            fact.fact = factText;
                        }
                    }
                    return fact;
                });

                // Embed the request so the game's answer picker can re-fetch a
                // different answer's explanation (with a new answerIndex). Carried
                // inside gameData so it travels with it.
                res.gameData.request = {
                    token: 'myToken123',
                    operation: 'getGameData',
                    sessionModule: sessionModule,
                    query: query,
                    scenario: scenario,
                    customScenario: customScenario,
                    customQuery: customQuery,
                    detailedFailures: detailedFailures,
                    hideRepeated: hideRepeatedExplanations,
                    largerImportantReasons: largerImportantReasons
                };
                // The program source, so the game window can establish its OWN session
                // (independent of this editor's) rather than reusing sessionModule.
                res.gameData.source = text;
                localStorage.setItem('le_proof_game_data', JSON.stringify(res.gameData));
                const currentTheme = document.body.className.includes('light-theme') ? 'light-theme' :
                                     document.body.className.includes('hc-theme') ? 'hc-theme' : '';
                window.open(`proof-game.html?theme=${currentTheme}&v=${Date.now()}`, '_blank');
            } else if (res && res.error) {
                alert(t('Could not open the Proof Game:\n\n') + res.error);
            } else {
                alert(t('Failed to get game data from server.'));
            }
        } catch (err) {
            console.error(err);
            alert(t('Error connecting to server for game data.'));
        }
    });

    // Listen for messages from the Proof Game window
    window.addEventListener('message', (event) => {
        if (event.data && event.data.type === 'le-highlight' && event.data.loc) {
            const loc = event.data.loc;
            if (loc.start !== undefined && loc.end !== undefined && !isForeignOffset(loc.start)) {
                showProgramInEditor();
                const model = editor.getModel();
                const startPos = model.getPositionAt(loc.start);
                const endPos = model.getPositionAt(loc.end);
                editor.setSelection(new monaco.Range(
                    startPos.lineNumber, startPos.column,
                    endPos.lineNumber, endPos.column
                ));
                editor.revealRangeInCenter(new monaco.Range(
                    startPos.lineNumber, startPos.column,
                    endPos.lineNumber, endPos.column
                ));
                // The Explanation Drill highlights without stealing focus from its window.
                if (!event.data.noFocus) editor.focus();
            }
        }
    });

    // --- Scenario Editor window ----------------------------------------------
    // Open a separate window that edits scenarios as template-instance forms. It
    // needs the program's templates (to build the form fields) and the current
    // source (to list/parse existing scenarios); both are pure client data.
    document.getElementById('menu-scenario-editor')?.addEventListener('click', async () => {
        // The templates of included resources (and the values the rules read
        // in each place) come from a load: opened before one, the window
        // would offer none of them.
        adoptActiveAsProgram();
        if (!isLoaded) await loadModule();
        // The window parses templates and scenarios straight from the source.
        const data = {
            source: programText(),
            // the templates of included resources (from the last load), and
            // where the program came from — for "Write it in English" from a document
            templateDefs: lastTemplateDefs,
            example: panelDoc.example || '',
            base: panelDoc.baseUrl || '',
        };
        localStorage.setItem('le_scenario_editor_data', JSON.stringify(data));
        const currentTheme = document.body.className.includes('light-theme') ? 'light-theme' :
                             document.body.className.includes('hc-theme') ? 'hc-theme' : '';
        window.open(`scenario-editor.html?theme=${currentTheme}&v=${Date.now()}`, '_blank');
    });

    // --- Query Editor window -------------------------------------------------
    // Open a separate window that builds/edits queries from template instances joined
    // by the basic connectives. Like the Scenario Editor it parses templates and
    // existing queries straight from the source (pure client data).
    document.getElementById('menu-query-editor')?.addEventListener('click', async () => {
        const data = { source: programText() };
        localStorage.setItem('le_query_editor_data', JSON.stringify(data));
        const currentTheme = document.body.className.includes('light-theme') ? 'light-theme' :
                             document.body.className.includes('hc-theme') ? 'hc-theme' : '';
        window.open(`query-editor.html?theme=${currentTheme}&v=${Date.now()}`, '_blank');
    });

    // --- Scenario Variations window ------------------------------------------
    // Pick/alter a scenario and run queries against the variation, in a separate
    // window. The window establishes its OWN server session from this source (so the
    // editor reloading never breaks it); navigation messages flow back here.
    document.getElementById('btn-variations')?.addEventListener('click', async () => {
        if (!isLoaded) { const ok = await loadModule(); if (!ok) return; }
        const data = {
            source: programText(),
            kbName: lastKb,
            // the templates of included resources, and where the program came
            // from (its own load resolves its includes against it)
            templateDefs: lastTemplateDefs,
            example: panelDoc.example || '',
            base: panelDoc.baseUrl || '',
            queries: lastQueries.map((q: any) => ({ name: q.name, label: q.le || q.template })),
            selectedScenario: scenarioSelect.value === '___custom___' ? '' : scenarioSelect.value,
            selectedQuery: querySelect.value === '___custom___' ? '' : querySelect.value,
        };
        localStorage.setItem('le_scenario_variations_data', JSON.stringify(data));
        const currentTheme = document.body.className.includes('light-theme') ? 'light-theme' :
                             document.body.className.includes('hc-theme') ? 'hc-theme' : '';
        window.open(`scenario-variations.html?theme=${currentTheme}&v=${Date.now()}`, '_blank');
    });

    // Apply a scenario block sent back from the Scenario Editor window: replace the
    // named scenario in place when it still exists, otherwise append after the last
    // scenario (or at the end of the document). The Prolog side re-checks syntax on
    // the next load.
    scenarioChannel.onmessage = (event) => {
        const msg = event.data;
        if (!msg || msg.type !== 'insert-scenario' || typeof msg.blockText !== 'string') return;
        showProgramInEditor();   // the window edits the program in the panels
        const model = editor.getModel();
        if (!model) return;
        const source = editor.getValue();
        const blocks = parseScenarioBlocks(source);
        const target = msg.replaceName ? blocks.find(b => b.name === msg.replaceName) : null;

        let startOff: number, endOff: number, text: string;
        if (target) {
            startOff = target.start;
            endOff = target.end;
            text = msg.blockText;
        } else {
            // Append: after the last scenario block, else at end of document.
            const last = blocks.length ? blocks[blocks.length - 1] : null;
            const insertAt = last ? last.end : source.length;
            const before = source.slice(0, insertAt).replace(/\s*$/, '');
            startOff = insertAt;
            endOff = insertAt;
            text = (before.length ? '\n\n' : '') + msg.blockText + '\n';
        }
        const startPos = model.getPositionAt(startOff);
        const endPos = model.getPositionAt(endOff);
        const range = new monaco.Range(startPos.lineNumber, startPos.column, endPos.lineNumber, endPos.column);
        editor.executeEdits('scenario-editor', [{ range, text, forceMoveMarkers: true }]);
        // Reveal and select the inserted block so the user sees the change land.
        const newEndPos = model.getPositionAt(startOff + text.length);
        editor.setSelection(new monaco.Range(startPos.lineNumber, startPos.column, newEndPos.lineNumber, newEndPos.column));
        editor.revealRangeInCenter(range);
        editor.focus();
        isLoaded = false;   // source changed: force a re-load (and Prolog syntax check) next query
    };

    // Apply a query block sent back from the Query Editor window: replace the named
    // query in place when it still exists, otherwise append after the last query (or
    // at the end of the document). The Prolog side re-checks syntax on the next load.
    queryChannel.onmessage = (event) => {
        const msg = event.data;
        if (!msg || msg.type !== 'insert-query' || typeof msg.blockText !== 'string') return;
        showProgramInEditor();   // the window edits the program in the panels
        const model = editor.getModel();
        if (!model) return;
        const source = editor.getValue();
        const blocks = parseQueryBlocks(source);
        const target = msg.replaceName ? blocks.find(b => b.name === msg.replaceName) : null;

        let startOff: number, endOff: number, text: string;
        if (target) {
            startOff = target.start;
            endOff = target.end;
            text = msg.blockText;
        } else {
            // Append: after the last query block, else at end of document.
            const last = blocks.length ? blocks[blocks.length - 1] : null;
            const insertAt = last ? last.end : source.length;
            const before = source.slice(0, insertAt).replace(/\s*$/, '');
            startOff = insertAt;
            endOff = insertAt;
            text = (before.length ? '\n\n' : '') + msg.blockText + '\n';
        }
        const startPos = model.getPositionAt(startOff);
        const endPos = model.getPositionAt(endOff);
        const range = new monaco.Range(startPos.lineNumber, startPos.column, endPos.lineNumber, endPos.column);
        editor.executeEdits('query-editor', [{ range, text, forceMoveMarkers: true }]);
        const newEndPos = model.getPositionAt(startOff + text.length);
        editor.setSelection(new monaco.Range(startPos.lineNumber, startPos.column, newEndPos.lineNumber, newEndPos.column));
        editor.revealRangeInCenter(range);
        editor.focus();
        isLoaded = false;   // source changed: force a re-load (and Prolog syntax check) next query
    };

    // Assistant Logic
    const assistantInput = document.getElementById('assistant-input') as HTMLInputElement;
    const btnAssistantSend = document.getElementById('btn-assistant-send') as HTMLButtonElement;
    // The conversation about the program in the panels (switchPanel swaps it).
    let assistantHistory = document.getElementById('assistant-history')!;
    const assistantGreeting = assistantHistory.firstElementChild?.cloneNode(true) as HTMLElement | undefined;
    const btnAssistantInterrupt = document.getElementById('btn-assistant-interrupt') as HTMLButtonElement;
    const assistantProgress = document.getElementById('assistant-progress')!;
    const assistantProgressText = document.getElementById('assistant-progress-text')!;
    const assistantModeToggle = document.getElementById('assistant-mode-toggle') as HTMLInputElement;

    // Load saved mode
    if (assistantModeToggle) {
        const savedMode = localStorage.getItem('le-assistant-mode') || 'light';
        assistantModeToggle.checked = savedMode === 'light';
        assistantModeToggle.addEventListener('change', () => {
            localStorage.setItem('le-assistant-mode', assistantModeToggle.checked ? 'light' : 'deep');
        });
    }
    let assistantStartTime: number | null = null;

    const addChatMessage = (role: 'user' | 'assistant', text: string, details?: string, history: HTMLElement = assistantHistory) => {
        const msg = document.createElement('div');
        msg.className = `chat-message ${role}`;
        
        const content = document.createElement('div');
        content.className = 'message-content';
        
        const markedLib = (window as any).marked;
        console.log('LE Assistant: marked library found:', !!markedLib, typeof markedLib);
        if (role === 'assistant' && markedLib) {
            try {
                // Handle different marked versions/exports
                let html = '';
                if (typeof markedLib.parse === 'function') {
                    html = markedLib.parse(text);
                } else if (typeof markedLib === 'function') {
                    html = markedLib(text);
                } else if (markedLib.marked && typeof markedLib.marked.parse === 'function') {
                    html = markedLib.marked.parse(text);
                }
                
                if (html) {
                    console.log('LE Assistant: Markdown parsed successfully');
                    content.innerHTML = html;
                    // Ensure links open in new tab
                    content.querySelectorAll('a').forEach(a => a.target = '_blank');
                } else {
                    console.warn('LE Assistant: Markdown parsing returned empty string');
                    content.textContent = text;
                }
            } catch (e) {
                console.error('LE Assistant: Markdown parsing failed:', e);
                content.textContent = text;
            }
        } else {
            if (role === 'assistant') console.warn('LE Assistant: marked library not found on window');
            content.textContent = text;
        }
        msg.appendChild(content);

        if (details) {
            const detailsEl = document.createElement('details');
            detailsEl.style.marginTop = '8px';
            detailsEl.style.fontSize = '11px';
            detailsEl.style.borderTop = '1px solid rgba(255,255,255,0.1)';
            detailsEl.style.paddingTop = '5px';

            const summary = document.createElement('summary');
            summary.textContent = t('System Logs (stderr)');
            summary.style.cursor = 'pointer';
            summary.style.opacity = '0.6';
            summary.style.outline = 'none';
            detailsEl.appendChild(summary);

            const pre = document.createElement('pre');
            pre.textContent = details;
            pre.style.margin = '5px 0 0 0';
            pre.style.whiteSpace = 'pre-wrap';
            pre.style.maxHeight = '150px';
            pre.style.overflowY = 'auto';
            pre.style.background = 'rgba(0,0,0,0.2)';
            pre.style.padding = '5px';
            pre.style.borderRadius = '3px';
            pre.style.fontFamily = 'monospace';
            detailsEl.appendChild(pre);
            
            msg.appendChild(detailsEl);
        }

        history.appendChild(msg);
        history.scrollTop = history.scrollHeight;
    };

    let currentJobId: string | null = null;

    const handleAssistantSend = async () => {
        const command = assistantInput.value.trim();
        if (!command) return;

        const selectedModel = localStorage.getItem('le-assistant-model') || '';
        if (!selectedModel) {
            addChatMessage('assistant', 'Warning: No assistant model selected. Please go to **Misc > API Keys...** to select one.');
            return;
        }
        
        const modelInfo = availableModels.find(m => m.short === selectedModel);
        const provider = modelInfo ? modelInfo.provider : '';
        const serverP = provider === 'google' ? 'gemini' : provider;
        const localP = provider === 'gemini' ? 'google' : provider;
        
        const hasServerKey = serverKeys.includes(serverP);
        const hasLocalKey = !!localStorage.getItem(`le-${localP}-key`);

        if (provider && !hasServerKey && !hasLocalKey) {
            addChatMessage('assistant', `Warning: You have selected model **${selectedModel}** but no API key is configured for provider **${provider}**. Please go to **Misc > API Keys...** to set it up.`);
            return;
        }

        addChatMessage('user', command);
        assistantInput.value = '';
        btnAssistantSend.disabled = true;
        btnAssistantInterrupt.style.display = 'inline-block';
        assistantProgress.style.display = 'block';
        assistantProgressText.textContent = t('Starting...');
        assistantStartTime = Date.now();

        const apiKeys = {
            openai: localStorage.getItem('le-openai-key'),
            anthropic: localStorage.getItem('le-anthropic-key'),
            google: localStorage.getItem('le-google-key'),
            groq: localStorage.getItem('le-groq-key'),
            together: localStorage.getItem('le-together-key')
        };

        // The request is about this program: its reply goes to its conversation
        // and its changes to its text, whichever tab is in front by then.
        const jobDoc = panelDoc;
        const jobHistory = assistantHistory;
        console.log('Sending assistant command with session ID:', jobDoc.assistantSessionId);
        try {
            const response = await fetch('/leapi', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    token: 'myToken123',
                    operation: 'assistant_command',
                    command: command,
                    content: jobDoc.model.getValue(),
                    session_id: jobDoc.assistantSessionId,
                    api_keys: apiKeys,
                    model: localStorage.getItem('le-assistant-model'),
                    mode: assistantModeToggle ? (assistantModeToggle.checked ? 'light' : 'deep') : 'light',
                    max_steps: parseInt(localStorage.getItem('le-assistant-max-steps') || '10', 10)
                })
            });
            const data = await response.json();
            if (data.result === 'ok') {
                currentJobId = data.job_id;
                pollAssistantStatus(data.job_id, jobDoc, jobHistory);
            } else {
                addChatMessage('assistant', 'Error: ' + (data.error || 'Unknown error'), undefined, jobHistory);
                finishAssistantRequest();
            }
        } catch (err) {
            console.error('Assistant error:', err);
            addChatMessage('assistant', 'Failed to connect to the assistant.', undefined, jobHistory);
            finishAssistantRequest();
        }
    };

    const pollAssistantStatus = async (jobId: string, jobDoc: EditorDoc, jobHistory: HTMLElement) => {
        try {
            const response = await fetch('/leapi', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    token: 'myToken123',
                    operation: 'assistant_status',
                    job_id: jobId
                })
            });
            const data = await response.json();
            if (data.result === 'ok') {
                if (data.status === 'running') {
                    // Update progress with last line of stderr or stdout if available
                    let progressText = '';
                    if (data.stderr) {
                        const lines = data.stderr.trim().split('\n');
                        progressText = lines[lines.length - 1];
                    } else if (data.stdout) {
                        const lines = data.stdout.trim().split('\n');
                        progressText = lines[lines.length - 1];
                    }
                    
                    if (progressText) {
                        assistantProgressText.textContent = progressText.substring(0, 60) + (progressText.length > 60 ? '...' : '');
                    }
                    setTimeout(() => pollAssistantStatus(jobId, jobDoc, jobHistory), 1000);
                } else if (data.status === 'finished') {
                    const duration = assistantStartTime ? Math.round((Date.now() - assistantStartTime) / 1000) : 0;
                    if (data.session_id) {
                        jobDoc.assistantSessionId = data.session_id;
                        console.log('Updated assistant session ID:', data.session_id);
                    }
                    
                    let stdout = data.stdout || '';
                    let newContent = data.new_content || '';

                    if (stdout) {
                        addChatMessage('assistant', stdout, data.stderr, jobHistory);
                    } else if (data.stderr) {
                        addChatMessage('assistant', 'The assistant finished with some logs but no direct output.', data.stderr, jobHistory);
                    }

                    if (newContent && newContent !== jobDoc.model.getValue() && docs.includes(jobDoc)) {
                        // a whole-text edit, undoable in its tab
                        jobDoc.model.pushEditOperations([], [{ range: jobDoc.model.getFullModelRange(), text: newContent }], () => null);
                        addChatMessage('assistant', t('I have updated the editor content with the changes.'), undefined, jobHistory);
                    }
                    addChatMessage('assistant', `_${t('Request completed in {n} seconds.').replace('{n}', String(duration))}_`, undefined, jobHistory);
                    finishAssistantRequest();
                }
            } else {
                addChatMessage('assistant', 'Error polling status: ' + (data.error || 'Unknown error'), undefined, jobHistory);
                finishAssistantRequest();
            }
        } catch (err) {
            console.error('Polling error:', err);
            addChatMessage('assistant', 'Lost connection while waiting for assistant.', undefined, jobHistory);
            finishAssistantRequest();
        }
    };

    const handleAssistantInterrupt = async () => {
        if (!currentJobId) return;
        const duration = assistantStartTime ? Math.round((Date.now() - assistantStartTime) / 1000) : 0;
        
        try {
            const response = await fetch('/leapi', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    token: 'myToken123',
                    operation: 'assistant_interrupt',
                    job_id: currentJobId
                })
            });
            const data = await response.json();
            if (data.result === 'ok') {
                addChatMessage('assistant', `_${t('Request interrupted by user after {n} seconds.').replace('{n}', String(duration))}_`);
            }
        } catch (err) {
            console.error('Interrupt error:', err);
        }
        finishAssistantRequest();
    };

    const finishAssistantRequest = () => {
        btnAssistantSend.disabled = false;
        btnAssistantInterrupt.style.display = 'none';
        assistantProgress.style.display = 'none';
        currentJobId = null;
    };

    btnAssistantSend.addEventListener('click', handleAssistantSend);
    btnAssistantInterrupt.addEventListener('click', handleAssistantInterrupt);
    assistantInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') handleAssistantSend();
    });

    // ---- file tabs ----------------------------------------------------------
    // The strip above the editor (editor-tabs.ts) shows the open documents.
    // Clicking a tab brings its document into the editor AND its program into
    // the panels: the Query panel's pickers, answers and explanation, the
    // Assistant's conversation, the graph — each program keeps its own, so
    // switching back and forth loses nothing. A click in an explanation that
    // leads into an included resource opens (or brings forward) the resource's
    // tab but leaves the panels on the program being explained; a click on
    // one of the program's own nodes brings its tab back.
    const tabBar = new TabBar(document.getElementById('editor-tabs')!, {
        onSelect: (id) => { const d = docs.find(x => x.id === id); if (d) activateDoc(d, true); },
        onClose: (id) => { const d = docs.find(x => x.id === id); if (d) closeDoc(d); },
        onNew: () => newTab(),
        newTitle: t('New tab'),
        programTitle: t('The queries and the assistant are about this program'),
    });

    function refreshTabs() {
        tabBar.render(docs.map(d => ({
            id: d.id,
            title: d.fileName.split('/').pop() || d.fileName,
            tooltip: d.baseUrl ? d.baseUrl + (d.fileName.split('/').pop() || '') : d.fileName,
            dirty: d.dirty,
            program: d === panelDoc && d !== activeDoc,
        })), activeDoc.id);
        if (filenameDisplay) filenameDisplay.textContent = activeDoc.fileName;
        updateSaveMenu();
    }

    function setDirty(doc: EditorDoc, dirty: boolean) {
        if (doc.dirty === dirty) return;
        doc.dirty = dirty;
        refreshTabs();
    }

    // Any change to a document's text, typed or not, in front or not.
    function docChanged(doc: EditorDoc) {
        setDirty(doc, true);
        lspChange(doc);
        if (doc === activeDoc) syncEditorLanguage(doc.model.getValue());
        if (doc === panelDoc) {
            if (isLoaded) {
                isLoaded = false;
                scenarioSelect.innerHTML = `<option value="">${t('[Empty Scenario]')}</option>`;
                querySelect.innerHTML = `<option value="">${t('Select a query...')}</option>`;
            }
            refreshEnginePickerTarget();
            // Debounced proactive load
            if (loadTimeout) clearTimeout(loadTimeout);
            loadTimeout = setTimeout(() => {
                if (!isLoaded && !isLoading) loadModule();
            }, 1500);
            doc.textInUrl = true;
            const url = new URL(window.location.href);
            url.searchParams.set('text', doc.model.getValue());
            window.history.replaceState({}, '', url.toString());
        } else if (doc.panel) {
            // its program, set aside, is out of date: reloaded when it is back
            doc.panel.isLoaded = false;
            doc.panel.scenarioOptions = `<option value="">${t('[Empty Scenario]')}</option>`;
            doc.panel.queryOptions = `<option value="">${t('Select a query...')}</option>`;
        }
    }

    // Puts a document in the editor. `takePanels`: its program also goes to
    // the panels (the user chose this tab); otherwise the panels stay as they
    // are (navigation from them). `focus` defaults to the user's choice.
    function activateDoc(doc: EditorDoc, takePanels: boolean, focus = takePanels) {
        if (doc !== activeDoc) {
            activeDoc.viewState = editor.saveViewState();
            activeDoc = doc;
            editor.setModel(doc.model);
            if (doc.viewState) editor.restoreViewState(doc.viewState);
            syncEditorLanguage(doc.model.getValue());
        }
        if (takePanels && doc !== panelDoc) switchPanel(doc);
        refreshTabs();
        if (focus) editor.focus();
    }

    // Before selecting a range of the program in the panels.
    function showProgramInEditor() {
        if (activeDoc !== panelDoc) activateDoc(panelDoc, false, false);
    }

    // Before an action at the cursor that asks the server about the program.
    function adoptActiveAsProgram() {
        if (activeDoc !== panelDoc) { switchPanel(activeDoc); refreshTabs(); }
    }

    // The state of the panels that belongs to the program in them.
    function capturePanel() {
        return {
            sessionModule, isLoaded, lastIssues, lastLoadError, includedResources,
            lastTemplateDefs, lastKb, lastFactImages, lastTemplateImages, lastQueries,
            engineUserSet,
            scenarioOptions: scenarioSelect.innerHTML, scenario: scenarioSelect.value,
            queryOptions: querySelect.innerHTML, query: querySelect.value,
            engine: engineSelect ? engineSelect.value : 'prolog',
            customScenario: customScenarioText.value, customQuery: customQueryText.value,
            kbText: kbModuleDisplay.textContent || '', sessionText: sessionModuleDisplay.textContent || '',
            resultsText: resultsDisplay.textContent || '',
            answersList, explanationTree, explView, assistantHistory,
            answersScroll: answersList.parentElement?.scrollTop || 0,
            explanationScroll: explanationTree.parentElement?.scrollTop || 0,
        };
    }

    function swapElement(current: HTMLElement, next: HTMLElement): HTMLElement {
        if (current === next) return next;
        const id = current.id;
        current.replaceWith(next);
        current.removeAttribute('id');
        next.id = id;
        return next;
    }

    // Hands the panels to another program: what they show now is set aside
    // with its program, and the other program's comes back (fresh, the first
    // time). Its program then loads if it is not loaded.
    function switchPanel(doc: EditorDoc) {
        panelDoc.panel = capturePanel();
        panelDoc = doc;
        const p = doc.panel;
        doc.panel = null;
        // a load or a proactive load of the program leaving is of no use now
        loadGen++;
        isLoading = false;
        loadPromise = null;
        queryTab?.classList.remove('le-loading');
        if (loadTimeout) { clearTimeout(loadTimeout); loadTimeout = null; }

        const emptyScenarios = `<option value="">${t('[Empty Scenario]')}</option>`;
        const emptyQueries = `<option value="">${t('Select a query...')}</option>`;
        sessionModule = p ? p.sessionModule : null;
        isLoaded = p ? p.isLoaded : false;
        lastIssues = p ? p.lastIssues : [];
        lastLoadError = p ? p.lastLoadError : '';
        includedResources = p ? p.includedResources : [];
        lastTemplateDefs = p ? p.lastTemplateDefs : [];
        lastKb = p ? p.lastKb : '';
        lastFactImages = p ? p.lastFactImages : [];
        lastTemplateImages = p ? p.lastTemplateImages : [];
        lastQueries = p ? p.lastQueries : [];
        engineUserSet = p ? p.engineUserSet : false;
        scenarioSelect.innerHTML = p ? p.scenarioOptions : emptyScenarios;
        scenarioSelect.value = p ? p.scenario : '';
        querySelect.innerHTML = p ? p.queryOptions : emptyQueries;
        querySelect.value = p ? p.query : '';
        if (engineSelect) engineSelect.value = p ? p.engine : 'prolog';
        customScenarioText.value = p ? p.customScenario : '';
        customQueryText.value = p ? p.customQuery : '';
        customScenarioContainer.style.display = scenarioSelect.value === '___custom___' ? 'flex' : 'none';
        customQueryContainer.style.display = querySelect.value === '___custom___' ? 'flex' : 'none';
        kbModuleDisplay.textContent = p ? p.kbText : '';
        sessionModuleDisplay.textContent = p ? p.sessionText : '';
        resultsDisplay.textContent = p ? p.resultsText : t('Results');

        let nextAnswers: HTMLElement, nextTree: HTMLElement, nextHistory: HTMLElement;
        if (p) {
            nextAnswers = p.answersList; nextTree = p.explanationTree; nextHistory = p.assistantHistory;
            explView = p.explView;
        } else {
            nextAnswers = document.createElement('div');
            nextTree = document.createElement('div');
            nextHistory = document.createElement('div');
            if (assistantGreeting) nextHistory.appendChild(assistantGreeting.cloneNode(true));
            explView = makeExplanationView(nextAnswers, nextTree);
        }
        answersList = swapElement(answersList, nextAnswers);
        explanationTree = swapElement(explanationTree, nextTree);
        assistantHistory = swapElement(assistantHistory, nextHistory);
        explView.refreshTitle();
        if (p) {
            if (answersList.parentElement) answersList.parentElement.scrollTop = p.answersScroll;
            if (explanationTree.parentElement) explanationTree.parentElement.scrollTop = p.explanationScroll;
        }

        syncUrlForPanel();
        refreshEnginePickerTarget();
        updateQueryButtonState();
        sendStateToGraph();
        if (!isLoaded) loadModule();
    }

    // The address bar names the program in the panels: its example (or its
    // text, once edited) and its scenario/query/engine selections.
    function syncUrlForPanel() {
        const url = new URL(window.location.href);
        for (const k of ['example', 'text', 'filename', 'line', 'scenario', 'query', 'engine', 'answer']) {
            url.searchParams.delete(k);
        }
        const doc = panelDoc;
        if (doc.example) url.searchParams.set('example', doc.example);
        if (doc.textInUrl) url.searchParams.set('text', doc.model.getValue());
        if (!doc.example && doc.fileName !== 'document.le') url.searchParams.set('filename', doc.fileName);
        url.hash = doc.textInUrl ? '' : doc.hash;
        window.history.replaceState({}, '', url.toString());
        updateUrlSelection();
    }

    // A document opened from the File menu (Open, Open copy from server, New
    // from URL) goes into a tab of its own, which comes forward with its
    // program in the panels. If it is open already, its tab comes forward
    // instead; an untouched new document in front is replaced rather than
    // left behind as an empty tab.
    type DocProps = { fileName: string, fileHandle?: any, baseUrl?: string | null, example?: string | null };
    async function openDocument(text: string, props: DocProps) {
        const open = await findOpenDocument(props);
        if (open) { activateDoc(open, true); return; }
        if (isUntouchedNewDocument(activeDoc)) { replaceActiveDocument(text, props); return; }
        const doc = createDoc(text, props.fileName, {
            fileHandle: props.fileHandle ?? null, baseUrl: props.baseUrl ?? null, example: props.example ?? null,
        });
        lspOpen(doc);
        activateDoc(doc, true);
    }

    async function findOpenDocument(props: DocProps): Promise<EditorDoc | undefined> {
        for (const d of docs) {
            if (props.example && d.example === props.example && !d.baseUrl && d.fileName === props.fileName) return d;
            if (props.baseUrl && d.baseUrl === props.baseUrl && d.fileName === props.fileName) return d;
            if (props.fileHandle && d.fileHandle) {
                try { if (await d.fileHandle.isSameEntry(props.fileHandle)) return d; } catch { /* not comparable */ }
            }
        }
        return undefined;
    }

    function isUntouchedNewDocument(doc: EditorDoc): boolean {
        return !doc.dirty && !doc.fileHandle && !doc.example && !doc.baseUrl && !doc.textInUrl && !doc.hash
            && doc.fileName === 'document.le'
            && doc.model.getValue().trim() === newDocumentText().trim();
    }

    // Replaces the document in the current tab (an untouched new one, see
    // openDocument). The tab's program takes the panels, afresh.
    function replaceActiveDocument(text: string, props: { fileName: string, fileHandle?: any, baseUrl?: string | null, example?: string | null }) {
        const doc = activeDoc;
        if (doc !== panelDoc) switchPanel(doc);
        doc.fileName = props.fileName;
        doc.fileHandle = props.fileHandle ?? null;
        doc.baseUrl = props.baseUrl ?? null;
        doc.example = props.example ?? null;
        doc.hash = '';
        doc.model.setValue(text);    // docChanged: the program must be reloaded
        doc.textInUrl = false;
        doc.viewState = null;
        isLoaded = false;
        scenarioSelect.innerHTML = `<option value="">${t('[Empty Scenario]')}</option>`;
        querySelect.innerHTML = `<option value="">${t('Select a query...')}</option>`;
        kbModuleDisplay.textContent = '';
        sessionModuleDisplay.textContent = '';
        explView.clear();
        setDirty(doc, false);
        syncUrlForPanel();
        updateQueryButtonState();
        refreshTabs();
    }

    // "+": a new, empty document in a tab of its own.
    function newTab(): EditorDoc {
        const doc = createDoc(newDocumentText(), 'document.le');
        lspOpen(doc);
        activateDoc(doc, true);
        return doc;
    }

    function closeDoc(doc: EditorDoc) {
        if (doc.dirty && !confirm(t('You have unsaved changes. Close this tab anyway?'))) return;
        if (docs.length === 1) newTab();     // there is always a document to edit
        const i = docs.indexOf(doc);
        if (doc === activeDoc) {
            const next = docs[i + 1] || docs[i - 1];
            activateDoc(next, true);
        } else if (doc === panelDoc) {
            switchPanel(activeDoc);
        }
        docs.splice(docs.indexOf(doc), 1);
        lspClose(doc);
        doc.model.dispose();
        refreshTabs();
    }

    // An included resource, shown in a tab of its own at the given range: the
    // tab that has it already, or a new one with the server's copy of it. The
    // panels stay on the program that led here.
    async function openResourceTab(info: any): Promise<void> {
        let doc = docs.find(d => d.example === info.resourceExample);
        if (!doc) {
            try {
                const response = await fetch('/leapi', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ token: 'myToken123', operation: 'examples', file: info.resourceExample })
                });
                const data = await response.json();
                if (data.document === undefined) {
                    alert(`${t('Could not open the included resource')} ${describeResourceRange(info)}.`);
                    return;
                }
                doc = createDoc(data.document, info.resourceExample + '.le', { example: info.resourceExample });
                doc.dirty = false;
                lspOpen(doc);
            } catch (err) {
                console.error('Failed to open included resource', err);
                alert(`${t('Could not open the included resource')} ${describeResourceRange(info)}.`);
                return;
            }
        }
        rememberJumpOrigin(editor);
        activateDoc(doc, false, true);
        const model = doc.model;
        let range;
        if (typeof info.resourceStart === 'number' && typeof info.resourceEnd === 'number') {
            const a = model.getPositionAt(info.resourceStart), b = model.getPositionAt(info.resourceEnd);
            range = new monaco.Range(a.lineNumber, a.column, b.lineNumber, b.column);
        } else {
            const line = info.resourceLine || 1;
            range = new monaco.Range(line, 1, line, model.getLineMaxColumn(line));
        }
        editor.setSelection(range);
        editor.revealRangeInCenter(range);
    }
    // resource-nav.ts opens included resources through this
    (window as any).leOpenResourceTab = openResourceTab;

    syncEditorLanguage(editor.getValue());
    refreshTabs();

    // Window closing check
    window.addEventListener('beforeunload', (e) => {
        if (docs.some(d => d.dirty)) {
            e.preventDefault();
            e.returnValue = '';
        }
    });

    const worker = new Worker(new URL('../dist/server.js', import.meta.url), { type: 'module' });

    let messageId = 0;
    const pendingRequests = new Map<number, (value: any) => void>();

    worker.onmessage = (event) => {
        const message = event.data;
        if (message.id !== undefined) {
            const resolve = pendingRequests.get(message.id);
            if (resolve) {
                resolve(message.result);
                pendingRequests.delete(message.id);
            }
        } else if (message.method === 'textDocument/publishDiagnostics') {
            const diagnostics = message.params.diagnostics;
            const markers = diagnostics.map((d: any) => ({
                severity: d.severity === 1 ? monaco.MarkerSeverity.Error : monaco.MarkerSeverity.Warning,
                startLineNumber: d.range.start.line + 1,
                startColumn: d.range.start.character + 1,
                endLineNumber: d.range.end.line + 1,
                endColumn: d.range.end.character + 1,
                message: d.message
            }));
            const target = monaco.editor.getModel(monaco.Uri.parse(message.params.uri));
            if (target) monaco.editor.setModelMarkers(target, 'le', markers);
        }
    };

    function sendRequest(method: string, params: any) {
        const id = messageId++;
        return new Promise((resolve) => {
            pendingRequests.set(id, resolve);
            worker.postMessage({ jsonrpc: '2.0', id, method, params });
        });
    }

    function sendNotification(method: string, params: any) {
        worker.postMessage({ jsonrpc: '2.0', method, params });
    }

    sendRequest('initialize', { capabilities: {} });
    sendNotification('initialized', {});

    // Every open document is a text document of the language server, under
    // its model's URI; hover, completion, folding and colouring ask about the
    // model they are for.
    lspOpen = (doc: EditorDoc) => sendNotification('textDocument/didOpen', {
        textDocument: {
            uri: doc.model.uri.toString(),
            languageId: 'le',
            version: doc.model.getVersionId(),
            text: doc.model.getValue()
        }
    });
    lspChange = (doc: EditorDoc) => sendNotification('textDocument/didChange', {
        textDocument: { uri: doc.model.uri.toString(), version: doc.model.getVersionId() },
        contentChanges: [{ text: doc.model.getValue() }]
    });
    lspClose = (doc: EditorDoc) => sendNotification('textDocument/didClose', {
        textDocument: { uri: doc.model.uri.toString() }
    });
    docs.forEach(doc => lspOpen(doc));

    monaco.languages.registerHoverProvider('le', {
        provideHover: async (model: any, position: any) => {
            const offset = model.getOffsetAt(position);
            if (model === programModel() && includedResources && includedResources.length > 0) {
                for (const res of includedResources) {
                    if (offset >= res.start && offset <= res.end) {
                        return {
                            contents: [
                                { value: `**Included Resource:** ${res.resource}` },
                                { value: `Rules: ${res.rules} | Templates: ${res.templates}` }
                            ]
                        };
                    }
                }
            }

            const res: any = await sendRequest('textDocument/hover', {
                textDocument: { uri: model.uri.toString() },
                position: { line: position.lineNumber - 1, character: position.column - 1 }
            });
            if (res && res.contents) {
                return {
                    contents: Array.isArray(res.contents) ? res.contents : [res.contents]
                };
            }
            return null;
        }
    });

    monaco.languages.registerCompletionItemProvider('le', {
        triggerCharacters: [' ', '*'],
        provideCompletionItems: async (model: any, position: any) => {
            const res: any = await sendRequest('textDocument/completion', {
                textDocument: { uri: model.uri.toString() },
                position: { line: position.lineNumber - 1, character: position.column - 1 }
            });
            if (res) {
                const items = Array.isArray(res) ? res : res.items;
                const lineContent = model.getLineContent(position.lineNumber);
                const textBefore = lineContent.substring(0, position.column - 1);
                const articles = ['a', 'an', 'the', 'some'];
                
                return {
                    suggestions: items.map((item: any) => {
                        const label = item.label;
                        const templateText = String(item.insertText || label).replace(/\*/g, '');
                        const wordsBefore = textBefore.split(/(\s+)/);
                        const wordsTemplate = templateText.split(/(\s+)/);
                        const cleanWordsBefore = wordsBefore.filter(w => w.trim().length > 0);
                        const cleanWordsTemplate = wordsTemplate.filter(w => w.trim().length > 0);
                        
                        let overlapCleanWords = 0;
                        for (let n = 1; n <= Math.min(cleanWordsBefore.length, cleanWordsTemplate.length); n++) {
                            let match = true;
                            for (let i = 0; i < n; i++) {
                                const wBefore = cleanWordsBefore[cleanWordsBefore.length - n + i].toLowerCase();
                                const wTemplate = cleanWordsTemplate[i].toLowerCase();
                                if (wBefore === wTemplate || (articles.includes(wBefore) && articles.includes(wTemplate)) || (i === n - 1 && wTemplate.startsWith(wBefore))) {
                                    continue;
                                }
                                match = false;
                                break;
                            }
                            if (match) overlapCleanWords = n;
                        }

                        let range;
                        let insertText = templateText;
                        if (overlapCleanWords > 0) {
                            const overlapSequence = cleanWordsBefore.slice(cleanWordsBefore.length - overlapCleanWords);
                            let searchIdx = textBefore.length;
                            for (let i = overlapSequence.length - 1; i >= 0; i--) {
                                searchIdx = textBefore.toLowerCase().lastIndexOf(overlapSequence[i].toLowerCase(), searchIdx - 1);
                            }
                            if (searchIdx !== -1) {
                                range = { startLineNumber: position.lineNumber, startColumn: searchIdx + 1, endLineNumber: position.lineNumber, endColumn: position.column };
                                const keptText = textBefore.substring(searchIdx);
                                let templateOverlapEndIdx = 0;
                                let templateWordsFound = 0;
                                while (templateWordsFound < overlapCleanWords && templateOverlapEndIdx < templateText.length) {
                                    const remainingTemplate = templateText.substring(templateOverlapEndIdx);
                                    const nextWordMatch = remainingTemplate.match(/\S+/);
                                    if (nextWordMatch) {
                                        templateOverlapEndIdx += nextWordMatch.index! + nextWordMatch[0].length;
                                        templateWordsFound++;
                                    } else break;
                                }
                                insertText = keptText + templateText.substring(templateOverlapEndIdx);
                            } else {
                                const word = model.getWordUntilPosition(position);
                                range = { startLineNumber: position.lineNumber, startColumn: word.startColumn, endLineNumber: position.lineNumber, endColumn: word.endColumn };
                            }
                        } else {
                            const word = model.getWordUntilPosition(position);
                            range = { startLineNumber: position.lineNumber, startColumn: word.startColumn, endLineNumber: position.lineNumber, endColumn: word.endColumn };
                        }
                        return { label, kind: item.kind !== undefined ? item.kind - 1 : 1, insertText, detail: item.detail, range };
                    })
                };
            }
            return { suggestions: [] };
        }
    });

    monaco.languages.registerFoldingRangeProvider('le', {
        provideFoldingRanges: async (model: any, context: any, token: any) => {
            console.log('Providing folding ranges for', model.uri.toString());
            const res: any = await sendRequest('textDocument/foldingRange', {
                textDocument: { uri: model.uri.toString() }
            });
            console.log('Folding ranges from server:', res);
            if (res) {
                return res.map((range: any) => ({
                    start: range.startLine + 1,
                    end: range.endLine + 1,
                    kind: monaco.languages.FoldingRangeKind.Region
                }));
            }
            return [];
        }
    });

    monaco.languages.registerDocumentSemanticTokensProvider('le', {
        getLegend: () => ({
            tokenTypes: ['keyword', 'variable', 'string', 'number', 'comment', 'type', 'templateWord'],
            tokenModifiers: []
        }),
        provideDocumentSemanticTokens: async (model: any, lastResultId: any, token: any) => {
            const res: any = await sendRequest('textDocument/semanticTokens/full', {
                textDocument: { uri: model.uri.toString() }
            });
            if (res && res.data) {
                return {
                    data: new Uint32Array(res.data)
                };
            }
            return null;
        },
        releaseDocumentSemanticTokens: (resultId: any) => {}
    });
}

(window as any).startEditor = start;
