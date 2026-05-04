import { leLanguageConfiguration, leMonarchTokens } from './le-language';

declare var monaco: any;

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
                        const match = text.match(/the (predicates|templates|fluents|events) are:/i);
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
                { token: 'variable', foreground: '9cdcfe' },
                { token: 'number.date', foreground: 'b5cea8' },
                { token: 'templateWord', foreground: 'd4d4d4' } // Plain text color for template words
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
                { token: 'variable', foreground: '001080' },
                { token: 'number.date', foreground: '098658' },
                { token: 'templateWord', foreground: '000000' }
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
        const filenameDisplay = document.getElementById('filename-display');
        if (filenameDisplay) {
            filenameDisplay.textContent = currentFileName;
        }

        const savedTheme = localStorage.getItem('le-editor-theme') || 'le-theme';
        const savedFontSize = parseInt(localStorage.getItem('le-editor-font-size') || '16');
        let isDirty = false;
        let isLoaded = false;
        let isLoading = false;
        let sessionModule: string | null = null;
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
            showFoldingControls: 'always'
        });

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
        updateSaveMenu();
        if (filenameDisplay) filenameDisplay.textContent = currentFileName;
        isDirty = false;
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
                data.examples.sort().forEach((ex: string) => {
                    const item = document.createElement('div');
                    item.className = 'dropdown-item'; // Reuse styling
                    item.style.padding = '10px 15px';
                    item.style.borderBottom = '1px solid #333';
                    item.textContent = ex;
                    item.addEventListener('click', async () => {
                        closeModal();
                        await loadExampleFromServer(ex);
                    });
                    exampleList.appendChild(item);
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
                scenarioSelect.innerHTML = '<option value="">Select a scenario...</option>';
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
    };
    document.getElementById('theme-dark')?.addEventListener('click', () => setTheme('le-theme'));
    document.getElementById('theme-light')?.addEventListener('click', () => setTheme('le-theme-light'));
    document.getElementById('theme-hc')?.addEventListener('click', () => setTheme('hc-black'));

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
        closeApiKeysModal();
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
    const resultsDisplay = document.getElementById('results-display') as HTMLPreElement;

    const customScenarioContainer = document.getElementById('custom-scenario-container')!;
    const customScenarioText = document.getElementById('custom-scenario-text') as HTMLTextAreaElement;
    const customQueryContainer = document.getElementById('custom-query-container')!;
    const customQueryText = document.getElementById('custom-query-text') as HTMLTextAreaElement;

    scenarioSelect.addEventListener('change', () => {
        customScenarioContainer.style.display = scenarioSelect.value === '___custom___' ? 'flex' : 'none';
        updateQueryButtonState();
    });

    querySelect.addEventListener('change', () => {
        customQueryContainer.style.display = querySelect.value === '___custom___' ? 'flex' : 'none';
        updateQueryButtonState();
    });

    const kbModuleDisplay = document.getElementById('kb-module-display')!;
    const sessionModuleDisplay = document.getElementById('session-module-display')!;

    const updateQueryButtonState = () => {
        if (!btnQuery) return;
        
        const model = editor.getModel();
        const markers = model ? monaco.editor.getModelMarkers({ owner: 'le-verifier' }) : [];
        const hasErrors = markers.some(m => m.severity === monaco.MarkerSeverity.Error);
        
        const scenarioSelected = scenarioSelect.value !== "";
        const querySelected = querySelect.value !== "";
        
        if (hasErrors) {
            btnQuery.disabled = true;
            btnQuery.title = 'Cannot query while there are errors in the document';
        } else if (!scenarioSelected || !querySelected) {
            btnQuery.disabled = true;
            btnQuery.title = 'Please select both a scenario and a query';
        } else {
            btnQuery.disabled = false;
            btnQuery.title = '';
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
                    le: editor.getValue()
                })
            });
            const res = await response.json();
            
            if (res && res.sessionModule) {
                sessionModule = res.sessionModule;
                isLoaded = true;
                
                kbModuleDisplay.textContent = `KB: ${res.kb || 'unknown'}`;
                sessionModuleDisplay.textContent = `Session: ${sessionModule}`;
                
                // Populate scenarios
                scenarioSelect.innerHTML = '<option value="">Select a scenario...</option>';
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
                
                // Populate queries
                querySelect.innerHTML = '<option value="">Select a query...</option>';
                if (res.queries) {
                    res.queries.forEach((q: any) => {
                        const option = document.createElement('option');
                        // q is now an object with name, template, and le
                        option.value = q.name;
                        const label = q.le || q.template;
                        option.textContent = q.name ? `${label} (${q.name})` : label;
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
                resultsDisplay.textContent = 'Error loading module: ' + (res?.error || 'Unknown error');
                isLoading = false;
                updateMarkers([]);
                return false;
            }
        } catch (err) {
            resultsDisplay.textContent = 'Error connecting to server.';
            console.error(err);
            isLoading = false;
            updateMarkers([]);
            return false;
        }
    };

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

    const renderExplanation = (why: any) => {
        explanationTree.innerHTML = '';
        if (!why) return;

        const createNode = (node: any, depth: number): HTMLElement => {
            const container = document.createElement('div');
            container.className = 'tree-node';

            const label = document.createElement('div');
            label.className = `tree-label ${node.type || 'success'}`;
            
            const hasChildren = node.children && node.children.length > 0;
            if (hasChildren) {
                const toggle = document.createElement('span');
                toggle.className = 'tree-toggle';
                toggle.textContent = depth < 2 ? '-' : '+';
                label.appendChild(toggle);
            }

            const text = document.createElement('span');
            text.textContent = node.literal || node;
            label.appendChild(text);
            
            if (node.start !== undefined && node.end !== undefined) {
                text.addEventListener('click', (e) => {
                    e.stopPropagation();
                    const startPos = model.getPositionAt(node.start);
                    const endPos = model.getPositionAt(node.end);
                    editor.setSelection(new monaco.Range(
                        startPos.lineNumber, startPos.column,
                        endPos.lineNumber, endPos.column
                    ));
                    editor.revealRangeInCenter(new monaco.Range(
                        startPos.lineNumber, startPos.column,
                        endPos.lineNumber, endPos.column
                    ));
                    editor.focus();
                });
            }

            container.appendChild(label);

            if (hasChildren) {
                const childrenContainer = document.createElement('div');
                childrenContainer.className = 'tree-children';
                childrenContainer.style.display = depth < 2 ? 'block' : 'none';
                
                label.querySelector('.tree-toggle')?.addEventListener('click', (e) => {
                    e.stopPropagation();
                    const isExpanded = childrenContainer.style.display !== 'none';
                    childrenContainer.style.display = isExpanded ? 'none' : 'block';
                    (e.target as HTMLElement).textContent = isExpanded ? '+' : '-';
                });

                node.children.forEach((child: any) => {
                    childrenContainer.appendChild(createNode(child, depth + 1));
                });
                container.appendChild(childrenContainer);
            }

            return container;
        };

        if (Array.isArray(why)) {
            why.forEach(w => explanationTree.appendChild(createNode(w, 0)));
        } else {
            explanationTree.appendChild(createNode(why, 0));
        }
    };

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
        
        answersList.innerHTML = '<div style="color: #888;">Executing query...</div>';
        explanationTree.innerHTML = '';
        
        try {
            const response = await fetch('/leapi', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    token: 'myToken123',
                    operation: 'answeringQuery',
                    sessionModule: sessionModule,
                    query: query,
                    scenario: scenario,
                    customScenario: customScenario,
                    customQuery: customQuery
                })
            });
            const res = await response.json();
            
            answersList.innerHTML = '';
            if (res && res.results && res.results.length > 0) {
                res.results.forEach((result: any, index: number) => {
                    const item = document.createElement('div');
                    item.className = 'answer-item';
                    item.textContent = result.answer;
                    item.addEventListener('click', () => {
                        document.querySelectorAll('.answer-item').forEach(el => el.classList.remove('selected'));
                        item.classList.add('selected');
                        renderExplanation(result.why);
                    });
                    answersList.appendChild(item);
                    if (index === 0) item.click(); // Select first by default
                });
            } else if (res && res.why) {
                const item = document.createElement('div');
                item.className = 'answer-item failure selected';
                item.style.color = '#f48771';
                item.textContent = 'No answers (false)';
                item.addEventListener('click', () => {
                    document.querySelectorAll('.answer-item').forEach(el => el.classList.remove('selected'));
                    item.classList.add('selected');
                    renderExplanation(res.why);
                });
                answersList.appendChild(item);
                renderExplanation(res.why);
            } else if (res && res.error) {
                answersList.textContent = 'Error: ' + res.error;
            } else {
                answersList.textContent = 'No results returned.';
            }
        } catch (err) {
            answersList.textContent = 'Error executing query.';
            console.error(err);
        }
    });

    // Assistant Logic
    const assistantInput = document.getElementById('assistant-input') as HTMLInputElement;
    const btnAssistantSend = document.getElementById('btn-assistant-send') as HTMLButtonElement;
    const assistantHistory = document.getElementById('assistant-history')!;
    const btnAssistantInterrupt = document.getElementById('btn-assistant-interrupt') as HTMLButtonElement;
    const assistantProgress = document.getElementById('assistant-progress')!;
    const assistantProgressText = document.getElementById('assistant-progress-text')!;
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
                    model: localStorage.getItem('le-assistant-model')
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
            scenarioSelect.innerHTML = '<option value="">Select a scenario...</option>';
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
