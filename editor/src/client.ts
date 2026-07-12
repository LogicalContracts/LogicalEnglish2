import { leLanguageConfiguration, leMonarchTokens } from './le-language';
import { parseScenarioBlocks, parseQueryBlocks } from './le-templates';
import { ExplanationView } from './explanation-view';
import cytoscape from 'cytoscape';
import fcose from 'cytoscape-fcose';

cytoscape.use(fcose);

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
        monaco.languages.setMonarchTokensProvider('le', leMonarchTokens);

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

        if (textParam) {
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
                if (data.document) {
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

        let currentFileName = initialFilename;
        let fileHandle: any = null;
        // When the current document was fetched from a URL, its directory — sent
        // to the server so the program's relative `includes these resources:`
        // resolve against the URL's location. Cleared on New/Open (local files).
        let currentBaseUrl: string | null = null;
        const filenameDisplay = document.getElementById('filename-display');
        if (filenameDisplay) {
            filenameDisplay.textContent = currentFileName;
        }

        const savedTheme = localStorage.getItem('le-editor-theme') || 'le-theme';
        const savedFontSize = parseInt(localStorage.getItem('le-editor-font-size') || '16');
        let showHierarchicalNumbering = localStorage.getItem('le-hierarchical-numbering') === 'true';
        let failedNodePrefix = localStorage.getItem('le-failed-node-prefix') ?? 'x ';
        let detailedFailures = localStorage.getItem('le-detailed-failures') === 'true';
        let hideRepeatedExplanations = (localStorage.getItem('le-hide-repeated-explanations') ?? 'true') === 'true';
        
        const numberingCheck = document.getElementById('hierarchical-numbering-check');
        if (numberingCheck) {
            numberingCheck.style.visibility = showHierarchicalNumbering ? 'visible' : 'hidden';
        }

        let isDirty = false;
        let isLoaded = false;
        let isLoading = false;
        let lastIssues: any[] = [];
        let lastLoadError = '';
        // Set (0-based) when an `answer` URL parameter asks the next query run to
        // auto-select a specific answer instead of the first.
        let pendingAnswerIndex: number | null = null;
        let sessionModule: string | null = null;
        let includedResources: any[] = [];
        let lastKb = '';
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

        const editor = monaco.editor.create(container, {
            value: initialValue,
            language: 'le',
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

        (window as any).selectRange = (start: number, end: number) => {
            const model = editor.getModel();
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
                const params = new URLSearchParams(window.location.search);
                const example = params.get('example');
                if (!example) {
                    alert('Copy URL is only available for existing examples.');
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

                if (!isLoaded && !isLoading) {
                    await loadModule();
                }

                if (!sessionModule) {
                    alert('Please wait for the module to load.');
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
                if (!isLoaded && !isLoading) {
                    await loadModule();
                }

                if (!sessionModule) {
                    alert('Please wait for the module to load.');
                    return;
                }

                const url = `hierarchy.html?sessionModule=${sessionModule}`;
                window.open(url, '_blank', 'width=800,height=600');
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
            prologCopy.textContent = 'Copied!';
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
        menuSaveAs.textContent = 'Download';
    }

    const updateSaveMenu = () => {
        if (menuSave) {
            menuSave.style.display = fileHandle ? 'block' : 'none';
        }
    };

    // Menu Actions
    document.getElementById('menu-new')?.addEventListener('click', () => {
        if (isDirty && !confirm('You have unsaved changes. Create new file anyway?')) return;
        editor.setValue('');
        currentFileName = 'document.le';
        fileHandle = null;
        currentBaseUrl = null;
        updateSaveMenu();
        if (filenameDisplay) filenameDisplay.textContent = currentFileName;
        isDirty = false;
    });

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
        if (isDirty && !confirm('You have unsaved changes. Load from URL anyway?')) return;
        if (urlError) urlError.style.display = 'none';
        if (urlModal) urlModal.style.display = 'flex';
        urlInput?.focus();
        urlInput?.select();
    });
    document.getElementById('new-from-url-close')?.addEventListener('click', closeUrlModal);
    document.getElementById('new-from-url-cancel')?.addEventListener('click', closeUrlModal);

    const loadFromUrl = async () => {
        const raw = (urlInput?.value || '').trim();
        if (!raw) { showUrlError('Please enter a URL.'); return; }
        let url: URL;
        try { url = new URL(raw); }
        catch { showUrlError('That is not a valid URL.'); return; }

        const prevLabel = urlLoadBtn.textContent;
        urlLoadBtn.disabled = true;
        urlLoadBtn.textContent = 'Loading…';
        if (urlError) urlError.style.display = 'none';
        try {
            const resp = await fetch(raw, { redirect: 'follow' });
            if (!resp.ok) throw new Error(`server returned ${resp.status} ${resp.statusText}`);
            const content = await resp.text();

            editor.setValue(content);
            // Filename from the URL's last path segment (default document.le).
            const seg = url.pathname.split('/').filter(Boolean).pop() || 'document.le';
            currentFileName = /\.[A-Za-z0-9]+$/.test(seg) ? seg : seg + '.le';
            fileHandle = null;                 // remote: no local write-back handle
            // Base = the URL up to its last '/', so relative includes resolve.
            currentBaseUrl = raw.slice(0, raw.length - url.pathname.split('/').pop()!.length);
            if (filenameDisplay) filenameDisplay.textContent = currentFileName;
            isDirty = false;
            updateSaveMenu();
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
        if (isDirty && !confirm('You have unsaved changes. Open another file anyway?')) return;
        
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
                
                fileHandle = handle;
                currentFileName = file.name;
                currentBaseUrl = null;
                if (filenameDisplay) filenameDisplay.textContent = currentFileName;
                editor.setValue(content);
                isDirty = false;
                updateSaveMenu();
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
        currentFileName = file.name;
        fileHandle = null; // Traditional input doesn't give us a handle we can write back to
        currentBaseUrl = null;
        updateSaveMenu();
        if (filenameDisplay) filenameDisplay.textContent = currentFileName;
        const reader = new FileReader();
        reader.onload = (e) => {
            const content = e.target?.result as string;
            if (content !== undefined) {
                editor.setValue(content);
                isDirty = false;
            }
        };
        reader.readAsText(file);
        fileInput.value = '';
    });

    const saveToFile = async (handle: any) => {
        const content = editor.getValue();
        const writable = await handle.createWritable();
        await writable.write(content);
        await writable.close();
        isDirty = false;
    };

    const saveAction = async () => {
        if (fileHandle) {
            try {
                await saveToFile(fileHandle);
                return;
            } catch (err) {
                console.error('Direct save failed, falling back to Save As', err);
            }
        }
        await saveAsAction();
    };

    const saveAsAction = async () => {
        const content = editor.getValue();
        
        // Try to use the File System Access API for "Save As"
        if ('showSaveFilePicker' in window) {
            try {
                const handle = await (window as any).showSaveFilePicker({
                    suggestedName: currentFileName,
                    types: [{
                        description: 'Logical English File',
                        accept: { 'text/plain': ['.le'] },
                    }],
                });
                await saveToFile(handle);
                
                fileHandle = handle;
                currentFileName = handle.name;
                if (filenameDisplay) filenameDisplay.textContent = currentFileName;
                updateSaveMenu();
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
        a.download = currentFileName;
        a.click();
        URL.revokeObjectURL(url);
        isDirty = false;
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

    document.getElementById('menu-open-server')?.addEventListener('click', async () => {
        if (isDirty && !confirm('You have unsaved changes. Open from server anyway?')) return;
        
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
            if (data.document !== undefined) {
                editor.setValue(data.document);
                currentFileName = name + '.le';
                fileHandle = null;
                updateSaveMenu();
                if (filenameDisplay) filenameDisplay.textContent = currentFileName;
                isDirty = false;
                
                // Reset loading state for the new file
                isLoaded = false;
                scenarioSelect.innerHTML = '<option value="">[Empty Scenario]</option>';
                querySelect.innerHTML = '<option value="">Select a query...</option>';
                kbModuleDisplay.textContent = '';
                sessionModuleDisplay.textContent = '';
            }
        } catch (err) {
            alert('Failed to load example from server.');
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
                        input.placeholder = 'Provided by server';
                        // Add a note if not already there
                        let note = input.parentElement?.querySelector('.server-key-note');
                        if (!note) {
                            note = document.createElement('div');
                            note.className = 'server-key-note';
                            note.style.fontSize = '10px';
                            note.style.color = '#89d185';
                            note.style.marginTop = '2px';
                            note.textContent = 'This key is provided by the server environment.';
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

    const openExplanationsModal = () => {
        if (explanationsModal && failedPrefixInput) {
            failedPrefixInput.value = failedNodePrefix;
            if (detailedFailuresInput) detailedFailuresInput.checked = detailedFailures;
            if (hideRepeatedInput) hideRepeatedInput.checked = hideRepeatedExplanations;
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
            
            if (target === 'graph-tab') {
                refreshGraph();
            }
        });
    });

    // Graph Logic
    const graphContainer = document.getElementById('graph-container')!;
    const btnRefreshGraph = document.getElementById('btn-refresh-graph')!;
    const layoutSelect = document.getElementById('layout-select') as HTMLSelectElement;
    const checkShowTypes = document.getElementById('check-show-types') as HTMLInputElement;

    let cy = cytoscape({
        container: graphContainer,
        style: [
            {
                selector: 'node',
                style: {
                    'label': 'data(label)',
                    'color': '#fff',
                    'text-valign': 'center',
                    'text-halign': 'center',
                    'font-size': '14px',
                    'background-color': '#666',
                    'width': 'label',
                    'height': 'label',
                    'padding': '20px',
                    'shape': 'round-rectangle',
                    'text-wrap': 'wrap',
                    'text-max-width': '450px',
                    'text-justification': 'center'
                }
            },
            {
                selector: 'node[type="kb"]',
                style: {
                    'background-color': '#2d2d2d',
                    'border-width': 2,
                    'border-color': '#4fc1ff',
                    'shape': 'rectangle',
                    'text-valign': 'top'
                }
            },
            {
                selector: 'node[type="scenario"]',
                style: {
                    'background-color': '#3c3c3c',
                    'border-width': 1,
                    'border-color': '#89d185',
                    'shape': 'rectangle',
                    'text-valign': 'top'
                }
            },
            {
                selector: 'node[type="template"]',
                style: {
                    'background-color': '#795e26',
                    'shape': 'round-rectangle',
                    'border-width': 1,
                    'border-color': '#ffb74d'
                }
            },
            {
                selector: 'node[type="rule"]',
                style: {
                    'background-color': '#795e26',
                    'shape': 'round-rectangle',
                    'border-width': 1,
                    'border-color': '#ffb74d',
                    'font-size': '14px'
                }
            },
            {
                selector: 'node[type="fact"]',
                style: {
                    'background-color': '#388e3c'
                }
            },
            {
                selector: 'node[type="type"]',
                style: {
                    'background-color': '#6a1b9a',
                    'shape': 'diamond'
                }
            },
            {
                selector: 'node[type="query"]',
                style: {
                    'background-color': '#c62828',
                    'shape': 'hexagon'
                }
            },
            {
                selector: 'edge',
                style: {
                    'width': 2,
                    'line-color': '#444',
                    'target-arrow-color': '#444',
                    'target-arrow-shape': 'triangle',
                    'curve-style': 'bezier',
                    'label': 'data(type)',
                    'font-size': '8px',
                    'color': '#aaa',
                    'text-rotation': 'autorotate',
                    'text-margin-y': -10
                }
            },
            {
                selector: 'edge[type="uses"]',
                style: { 'line-color': '#569cd6', 'target-arrow-color': '#569cd6' }
            },
            {
                selector: 'edge[type="depends-on"]',
                style: { 'line-color': '#4fc1ff', 'target-arrow-color': '#4fc1ff', 'line-style': 'dashed' }
            },
            {
                selector: 'edge[type="negates"]',
                style: { 'line-color': '#f48771', 'target-arrow-color': '#f48771' }
            },
            {
                selector: 'edge[type="is-a"]',
                style: { 'line-color': '#b5cea8', 'target-arrow-color': '#b5cea8' }
            },
            {
                selector: '.focused',
                style: {
                    'border-width': 4,
                    'border-color': '#ffeb3b',
                    'line-color': '#ffeb3b',
                    'target-arrow-color': '#ffeb3b'
                }
            },
            {
                selector: '.dimmed',
                style: {
                    'opacity': 0.2
                }
            }
        ]
    });

    cy.on('tap', 'node', (evt) => {
        const node = evt.target;
        const source = node.data('source') || node.scratch('source');
        if (source && source.start !== undefined && source.end !== undefined) {
            (window as any).selectRange(source.start, source.end);
        }
    });

    // Communication with Graph Window
    function sendStateToGraph() {
        graphChannel.postMessage({
            type: 'init-state',
            data: {
                sessionModule,
                theme: localStorage.getItem('le-editor-theme') || 'le-theme',
                isLoaded,
                filename: currentFileName
            }
        });
    }

    graphChannel.onmessage = (event) => {
        const { type, data } = event.data;
        if (type === 'select-range') {
            (window as any).selectRange(data.start, data.end);
        } else if (type === 'request-state') {
            sendStateToGraph();
        }
    };

    editor.onDidChangeCursorPosition((e: any) => {
        const model = editor.getModel();
        const offset = model.getOffsetAt(e.position);
        
        // Sync local graph tab
        syncGraphFocus(offset);
        
        // Sync external graph window
        graphChannel.postMessage({
            type: 'focus-offset',
            data: { offset }
        });
    });

    function syncGraphFocus(offset: number) {
        const nodes = cy.nodes();
        let bestNode: any = null;
        let minRange = Infinity;

        nodes.forEach((node: any) => {
            const source = node.data('source') || node.scratch('source');
            if (source && source.start <= offset && source.end >= offset) {
                const range = source.end - source.start;
                if (range < minRange) {
                    minRange = range;
                    bestNode = node;
                }
            }
        });

        if (bestNode) {
            cy.nodes().removeClass('focused');
            bestNode.addClass('focused');
        }
    }

    editor.addAction({
        id: 'open-graph-window',
        label: 'Open Graph in New Window',
        contextMenuGroupId: 'navigation',
        contextMenuOrder: 1.8,
        run: () => {
            window.open('graph.html', 'le-graph', 'width=1000,height=800');
        }
    });

    async function refreshGraph() {
        if (!isLoaded && !isLoading) {
            await loadModule();
        }
        if (!sessionModule) return;

        try {
            const response = await fetch('/leapi', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    token: 'myToken123',
                    operation: 'graph',
                    sessionModule: sessionModule
                })
            });
            const data = await response.json();
            if (data.nodes && data.edges) {
                let nodes = data.nodes;
                if (!checkShowTypes.checked) {
                    nodes = nodes.filter((n: any) => n.data.type !== 'type');
                }
                
                cy.elements().remove();
                cy.add(nodes);
                cy.add(data.edges);
                
                const layoutName = layoutSelect.value;
                cy.layout({ 
                    name: layoutName,
                    animate: true,
                    nodeDimensionsIncludeLabels: true,
                    // fCoSE specific options
                    padding: 30,
                    randomize: true,
                    idealEdgeLength: 100,
                    nodeRepulsion: 4500
                } as any).run();
            }
        } catch (err) {
            console.error('Failed to refresh graph', err);
        }
    }

    btnRefreshGraph.addEventListener('click', refreshGraph);
    layoutSelect.addEventListener('change', refreshGraph);
    checkShowTypes.addEventListener('change', refreshGraph);

    document.getElementById('btn-open-graph-window')?.addEventListener('click', () => {
        window.open('graph.html', 'le-graph', 'width=1000,height=800');
    });

    const graphSearch = document.getElementById('graph-search') as HTMLInputElement;
    graphSearch.addEventListener('input', () => {
        const term = graphSearch.value.toLowerCase();
        if (!term) {
            cy.elements().removeClass('dimmed').removeClass('focused');
            return;
        }

        const matches = cy.elements().filter((ele: any) => {
            const label = ele.data('label') || '';
            return label.toLowerCase().includes(term);
        });

        cy.elements().addClass('dimmed');
        matches.removeClass('dimmed').addClass('focused');
        
        if (matches.length > 0) {
            cy.animate({ center: { eles: matches } }, { duration: 500 });
        }
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

    const kbModuleDisplay = document.getElementById('kb-module-display')!;
    const sessionModuleDisplay = document.getElementById('session-module-display')!;

    const updateQueryButtonState = () => {
        if (!btnQuery) return;
        
        const model = editor.getModel();
        const markers = model ? monaco.editor.getModelMarkers({ owner: 'le-verifier' }) : [];
        const hasErrors = markers.some(m => m.severity === monaco.MarkerSeverity.Error);
        
        const scenarioSelected = true; // Allow empty scenario
        const querySelected = querySelect.value !== "";
        
        const disabled = hasErrors || !querySelected;
        
        btnQuery.disabled = disabled;
        if (btnTrace) btnTrace.disabled = disabled;
        
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

    const updateMarkers = (issues: any[]) => {
        const model = editor.getModel();
        if (!model) return;

        issueFixes.clear();
        const markers = issues.map((issue: any) => {
            const startPos = model.getPositionAt(issue.start);
            const endPos = model.getPositionAt(issue.end);
            const marker = {
                severity: issue.severity === 'error' ? monaco.MarkerSeverity.Error : monaco.MarkerSeverity.Warning,
                startLineNumber: startPos.lineNumber,
                startColumn: startPos.column,
                endLineNumber: endPos.lineNumber,
                endColumn: endPos.column,
                message: issue.message,
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

    const loadModule = async () => {
        if (isLoaded || isLoading) return true;
        isLoading = true;
        
        resultsDisplay.textContent = 'Loading module on server...';
        try {
            const response = await fetch('/leapi', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    token: 'myToken123',
                    operation: 'load',
                    le: editor.getValue(),
                    // The example this text came from, so the server resolves
                    // relative include resources against the example's folder.
                    source: new URLSearchParams(window.location.search).get('example') || '',
                    // If the document was fetched from a URL, its base URL, so
                    // relative includes resolve against the remote location.
                    base: currentBaseUrl || ''
                })
            });
            const res = await response.json();
            
            if (res && res.sessionModule) {
                sessionModule = res.sessionModule;
                isLoaded = true;
                lastIssues = res.issues || [];
                lastLoadError = '';
                includedResources = res.included_resources || [];

                kbModuleDisplay.textContent = `KB: ${res.kb || 'unknown'}`;
                sessionModuleDisplay.textContent = `Session: ${sessionModule}`;
                
                graphChannel.postMessage({
                    type: 'module-loaded',
                    data: { sessionModule }
                });

                // Populate scenarios
                scenarioSelect.innerHTML = '<option value="">[Empty Scenario]</option>';
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
                anotherScenarioOption.textContent = 'Another...';
                scenarioSelect.appendChild(anotherScenarioOption);
                
                // Remember the KB name and query list for the Scenario Variations window.
                lastKb = res.kb || '';
                lastQueries = Array.isArray(res.queries) ? res.queries : [];

                // Populate queries
                querySelect.innerHTML = '<option value="">Select a query...</option>';
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
                anotherQueryOption.textContent = 'Another...';
                querySelect.appendChild(anotherQueryOption);
                
                if (res.issues) {
                    updateMarkers(res.issues);
                } else {
                    updateMarkers([]);
                }

                resultsDisplay.textContent = 'Results';
                isLoading = false;
                return true;
            } else {
                lastLoadError = res?.error || 'Unknown error';
                resultsDisplay.textContent = 'Error loading module: ' + lastLoadError;
                isLoading = false;
                updateMarkers([]);
                return false;
            }
        } catch (err) {
            lastLoadError = 'Error connecting to server.';
            resultsDisplay.textContent = lastLoadError;
            console.error(err);
            isLoading = false;
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
        btn.textContent = 'OK';
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

    scenarioSelect.addEventListener('mousedown', async (e) => {
        if (!isLoaded) {
            if (!isLoading) {
                e.preventDefault();
                const success = await loadModule();
                if (success) {
                    setTimeout(() => {
                        scenarioSelect.focus();
                        scenarioSelect.click();
                    }, 100);
                }
            } else {
                // If already loading, just wait for it to finish
                e.preventDefault();
            }
        }
    });

    querySelect.addEventListener('mousedown', async (e) => {
        if (!isLoaded) {
            if (!isLoading) {
                e.preventDefault();
                const success = await loadModule();
                if (success) {
                    setTimeout(() => {
                        querySelect.focus();
                        querySelect.click();
                    }, 100);
                }
            } else {
                e.preventDefault();
            }
        }
    });

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
        const headerHeight = 35 + 30; // header + menu-bar
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

    const answersList = document.getElementById('answers-list')!;
    const explanationTree = document.getElementById('explanation-tree')!;

    // The answers + explanation view (Query panel body), now a reusable component
    // shared with the Scenario Variations window. Source navigation selects the range
    // in this editor; answer selection keeps the URL's `answer` param in sync.
    const explView = new ExplanationView({
        answersList,
        explanationTree,
        explanationTitle: document.getElementById('explanation-title') || undefined,
        menus: {
            answerContextMenu: document.getElementById('answer-context-menu')!,
            menuCopyAnswer: document.getElementById('menu-copy-answer')!,
            explanationContextMenu: document.getElementById('explanation-context-menu')!,
            menuCopyExplanation: document.getElementById('menu-copy-explanation')!,
            menuGotoOriginal: document.getElementById('menu-goto-original')!,
            answerTooltip: document.getElementById('answer-tooltip')!,
            titleMenu: document.getElementById('explanation-title-menu')!,
            menuShowStrongest: document.getElementById('menu-show-strongest')!,
            menuExplanationDrill: document.getElementById('menu-explanation-drill')!,
        },
        onOpenDrill: (why: any) => {
            if (!sessionModule) { showModal('Load the module and run a query first.', 'Explanation Drill'); return; }
            // Pass the program so the drill window can run its OWN independent session.
            localStorage.setItem('le_explanation_drill_data', JSON.stringify({ source: editor.getValue(), sessionModule, kbName: lastKb, why }));
            const currentTheme = document.body.className.includes('light-theme') ? 'light-theme' :
                                 document.body.className.includes('hc-theme') ? 'hc-theme' : '';
            window.open(`explanation-drill.html?theme=${currentTheme}&v=${Date.now()}`, '_blank');
        },
        failedNodePrefix: () => failedNodePrefix,
        hierarchicalNumbering: () => showHierarchicalNumbering,
        onNavigate: (start: number, end: number) => {
            const model = editor.getModel();
            const startPos = model.getPositionAt(start);
            const endPos = model.getPositionAt(end);
            const range = new monaco.Range(startPos.lineNumber, startPos.column, endPos.lineNumber, endPos.column);
            editor.setSelection(range);
            editor.revealRangeInCenter(range);
            editor.focus();
        },
        onSelectAnswer: (index: number) => setAnswerInUrl(index),
    });

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
        debugStatus.textContent = 'Connecting to debugger...';
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
            debugStatus.textContent = 'Debugger connected. Initializing...';
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
                    hideRepeated: hideRepeatedExplanations
                })
            }).then(res => res.json()).then(data => {
                console.log('Debug query finished', data);
                debugStatus.textContent = 'Query finished.';
                debugContinue.disabled = true;
                debugStep.disabled = true;
                debugStop.disabled = true;
                debugDecorations = editor.deltaDecorations(debugDecorations, []);
            }).catch(err => {
                console.error('Debug query failed', err);
                debugStatus.textContent = 'Query failed.';
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
            debugStatus.textContent = 'Debugger disconnected.';
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
        const model = editor.getModel();

        [...frames].reverse().forEach((f) => {
            const div = document.createElement('div');
            div.className = 'stack-frame';
            div.dataset.frameId = String(f.id);
            if (f.id === 1) div.classList.add('executing');   // deepest = current goal

            const pos = f.offset !== undefined ? model.getPositionAt(f.offset) : { lineNumber: 1, column: 1 };

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
        const model = editor.getModel();
        if (!f || f.offset === undefined) {
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
            empty.textContent = 'No variables for this call.';
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
        debugStatus.textContent = 'Trace stopped.';
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
        btnInterruptQuery.textContent = 'Interrupting…';
        fetch('/leapi', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ token: 'myToken123', operation: 'interruptQuery', sessionModule: sessionModule })
        }).catch(() => {}).finally(() => { btnInterruptQuery.textContent = 'Interrupt'; });
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
            resultsDisplay.textContent = 'Please select a query.';
            return;
        }
        
        if (query === '___custom___' && !customQuery) {
            resultsDisplay.textContent = 'Please enter a custom query.';
            return;
        }
        
        // A pending answer selection (from the `answer` URL parameter) applies to
        // this run only.
        const wantAnswer = pendingAnswerIndex;
        pendingAnswerIndex = null;

        answersList.innerHTML = '<div style="color: #888;">Executing query...</div>';
        explanationTree.innerHTML = '';
        showInterruptSoon();

        try {
            const runAnsweringQuery = () => fetch('/leapi', {
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
                    detailedFailures: detailedFailures,
                    hideRepeated: hideRepeatedExplanations
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
            explView.showResults(res, target);
        } catch (err) {
            answersList.textContent = 'Error executing query.';
            console.error(err);
        } finally {
            hideInterrupt();
        }
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
            alert('Please select a query for the Proof Game.');
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
                    hideRepeated: hideRepeatedExplanations
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
                const text = editor.getValue();
                
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
                    hideRepeated: hideRepeatedExplanations
                };
                // The program source, so the game window can establish its OWN session
                // (independent of this editor's) rather than reusing sessionModule.
                res.gameData.source = text;
                localStorage.setItem('le_proof_game_data', JSON.stringify(res.gameData));
                const currentTheme = document.body.className.includes('light-theme') ? 'light-theme' :
                                     document.body.className.includes('hc-theme') ? 'hc-theme' : '';
                window.open(`proof-game.html?theme=${currentTheme}&v=${Date.now()}`, '_blank');
            } else if (res && res.error) {
                alert('Could not open the Proof Game:\n\n' + res.error);
            } else {
                alert('Failed to get game data from server.');
            }
        } catch (err) {
            console.error(err);
            alert('Error connecting to server for game data.');
        }
    });

    // Listen for messages from the Proof Game window
    window.addEventListener('message', (event) => {
        if (event.data && event.data.type === 'le-highlight' && event.data.loc) {
            const loc = event.data.loc;
            const model = editor.getModel();
            if (model && loc.start !== undefined && loc.end !== undefined) {
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
        // The window parses templates and scenarios straight from the source.
        const data = { source: editor.getValue() };
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
        const data = { source: editor.getValue() };
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
            source: editor.getValue(),
            kbName: lastKb,
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
    const assistantHistory = document.getElementById('assistant-history')!;
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
    let assistantSessionId = 'ses_' + Math.random().toString(36).substring(7);
    let assistantStartTime: number | null = null;

    const addChatMessage = (role: 'user' | 'assistant', text: string, details?: string) => {
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
            summary.textContent = 'System Logs (stderr)';
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

        assistantHistory.appendChild(msg);
        assistantHistory.scrollTop = assistantHistory.scrollHeight;
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
        assistantProgressText.textContent = 'Starting...';
        assistantStartTime = Date.now();

        const apiKeys = {
            openai: localStorage.getItem('le-openai-key'),
            anthropic: localStorage.getItem('le-anthropic-key'),
            google: localStorage.getItem('le-google-key'),
            groq: localStorage.getItem('le-groq-key'),
            together: localStorage.getItem('le-together-key')
        };

        console.log('Sending assistant command with session ID:', assistantSessionId);
        try {
            const response = await fetch('/leapi', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    token: 'myToken123',
                    operation: 'assistant_command',
                    command: command,
                    content: editor.getValue(),
                    session_id: assistantSessionId,
                    api_keys: apiKeys,
                    model: localStorage.getItem('le-assistant-model'),
                    mode: assistantModeToggle ? (assistantModeToggle.checked ? 'light' : 'deep') : 'light',
                    max_steps: parseInt(localStorage.getItem('le-assistant-max-steps') || '10', 10)
                })
            });
            const data = await response.json();
            if (data.result === 'ok') {
                currentJobId = data.job_id;
                pollAssistantStatus(data.job_id);
            } else {
                addChatMessage('assistant', 'Error: ' + (data.error || 'Unknown error'));
                finishAssistantRequest();
            }
        } catch (err) {
            console.error('Assistant error:', err);
            addChatMessage('assistant', 'Failed to connect to the assistant.');
            finishAssistantRequest();
        }
    };

    const pollAssistantStatus = async (jobId: string) => {
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
                    setTimeout(() => pollAssistantStatus(jobId), 1000);
                } else if (data.status === 'finished') {
                    const duration = assistantStartTime ? Math.round((Date.now() - assistantStartTime) / 1000) : 0;
                    if (data.session_id) {
                        assistantSessionId = data.session_id;
                        console.log('Updated assistant session ID:', assistantSessionId);
                    }
                    
                    let stdout = data.stdout || '';
                    let newContent = data.new_content || '';

                    if (stdout) {
                        addChatMessage('assistant', stdout, data.stderr);
                    } else if (data.stderr) {
                        addChatMessage('assistant', 'The assistant finished with some logs but no direct output.', data.stderr);
                    }

                    if (newContent && newContent !== editor.getValue()) {
                        editor.setValue(newContent);
                        addChatMessage('assistant', 'I have updated the editor content with the changes.');
                    }
                    addChatMessage('assistant', `_Request completed in ${duration} seconds._`);
                    finishAssistantRequest();
                }
            } else {
                addChatMessage('assistant', 'Error polling status: ' + (data.error || 'Unknown error'));
                finishAssistantRequest();
            }
        } catch (err) {
            console.error('Polling error:', err);
            addChatMessage('assistant', 'Lost connection while waiting for assistant.');
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
                addChatMessage('assistant', `_Request interrupted by user after ${duration} seconds._`);
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

    // Window closing check
    window.addEventListener('beforeunload', (e) => {
        if (isDirty) {
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
            monaco.editor.setModelMarkers(editor.getModel()!, 'le', markers);
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

    const model = editor.getModel()!;
    sendNotification('textDocument/didOpen', {
        textDocument: {
            uri: 'file:///main.le',
            languageId: 'le',
            version: 1,
            text: model.getValue()
        }
    });

    editor.onDidChangeModelContent(() => {
        isDirty = true;
        if (isLoaded) {
            isLoaded = false;
            scenarioSelect.innerHTML = '<option value="">[Empty Scenario]</option>';
            querySelect.innerHTML = '<option value="">Select a query...</option>';
        }
        
        // Debounced proactive load
        if (loadTimeout) clearTimeout(loadTimeout);
        loadTimeout = setTimeout(() => {
            if (!isLoaded && !isLoading) loadModule();
        }, 1500);

        const text = model.getValue();
        sendNotification('textDocument/didChange', {
            textDocument: {
                uri: 'file:///main.le',
                version: 1
            },
            contentChanges: [{ text }]
        });

        const url = new URL(window.location.href);
        url.searchParams.set('text', text);
        window.history.replaceState({}, '', url.toString());
    });

    monaco.languages.registerHoverProvider('le', {
        provideHover: async (model: any, position: any) => {
            const offset = model.getOffsetAt(position);
            if (includedResources && includedResources.length > 0) {
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
                textDocument: { uri: 'file:///main.le' },
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
                textDocument: { uri: 'file:///main.le' },
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
                textDocument: { uri: 'file:///main.le' }
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
                textDocument: { uri: 'file:///main.le' }
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
