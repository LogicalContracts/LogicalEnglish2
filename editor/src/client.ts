import { leLanguageConfiguration, leMonarchTokens } from './le-language';

declare var monaco: any;

function start() {
    if (typeof monaco === 'undefined') {
        console.error('Monaco not loaded');
        return;
    }

    monaco.languages.register({ id: 'le' });
    monaco.languages.setLanguageConfiguration('le', leLanguageConfiguration);
    monaco.languages.setMonarchTokensProvider('le', leMonarchTokens);

    function getInitialValue() {
        const params = new URLSearchParams(window.location.search);
        const text = params.get('text');
        return text || '% Welcome to Logical English Editor\n\nthe knowledge base my_kb includes:\n  *a person* is happy if\n    *the person* is healthy.\n';
    }

    function getInitialFilename() {
        const params = new URLSearchParams(window.location.search);
        const filename = params.get('filename');
        return filename || 'document.le';
    }

    let currentFileName = getInitialFilename();
    let fileHandle: any = null;
    const filenameDisplay = document.getElementById('filename-display');
    if (filenameDisplay) {
        filenameDisplay.textContent = currentFileName;
    }

    const savedTheme = localStorage.getItem('le-editor-theme') || 'vs-dark';
    const savedFontSize = parseInt(localStorage.getItem('le-editor-font-size') || '16');
    let isDirty = false;
    let isLoaded = false;
    let isLoading = false;
    let sessionModule: string | null = null;
    let loadTimeout: any = null;

    const container = document.getElementById('container')!;

    const editor = monaco.editor.create(container, {
        value: getInitialValue(),
        language: 'le',
        theme: savedTheme,
        automaticLayout: true,
        fontSize: savedFontSize,
        minimap: { enabled: false },
        folding: true,
        showFoldingControls: 'always'
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
    document.getElementById('theme-dark')?.addEventListener('click', () => setTheme('vs-dark'));
    document.getElementById('theme-light')?.addEventListener('click', () => setTheme('vs'));
    document.getElementById('theme-hc')?.addEventListener('click', () => setTheme('hc-black'));

    const setFontSize = (size: number) => {
        editor.updateOptions({ fontSize: size });
        localStorage.setItem('le-editor-font-size', size.toString());
    };
    document.getElementById('font-small')?.addEventListener('click', () => setFontSize(12));
    document.getElementById('font-medium')?.addEventListener('click', () => setFontSize(16));
    document.getElementById('font-large')?.addEventListener('click', () => setFontSize(20));

    document.getElementById('menu-fold-all')?.addEventListener('click', () => {
        console.log('Collapse All clicked');
        editor.focus();
        const foldingContrib = editor.getContribution('editor.contrib.folding');
        if (foldingContrib) {
            const foldingModelPromise = (foldingContrib as any).getFoldingModel();
            if (foldingModelPromise && typeof foldingModelPromise.then === 'function') {
                foldingModelPromise.then((foldingModel: any) => {
                    if (foldingModel) {
                        const regions = foldingModel.regions;
                        if (regions && regions.length > 0) {
                            console.log(`Collapsing ${regions.length} regions`);
                            for (let i = 0; i < regions.length; i++) {
                                regions.setCollapsed(i, true);
                            }
                            // Use the internal update method that doesn't clear regions
                            if (typeof foldingModel.onBeforeModelContentChange === 'function') {
                                foldingModel.onBeforeModelContentChange();
                            }
                            // Trigger the change event that Monaco expects to refresh the view
                            if (foldingModel._updateEventEmitter) {
                                foldingModel._updateEventEmitter.fire();
                            }
                        }
                    }
                });
            }
        }
    });
    document.getElementById('menu-unfold-all')?.addEventListener('click', () => {
        console.log('Expand All clicked');
        editor.focus();
        const foldingContrib = editor.getContribution('editor.contrib.folding');
        if (foldingContrib) {
            const foldingModelPromise = (foldingContrib as any).getFoldingModel();
            if (foldingModelPromise && typeof foldingModelPromise.then === 'function') {
                foldingModelPromise.then((foldingModel: any) => {
                    if (foldingModel) {
                        const regions = foldingModel.regions;
                        if (regions && regions.length > 0) {
                            for (let i = 0; i < regions.length; i++) {
                                regions.setCollapsed(i, false);
                            }
                            if (foldingModel._updateEventEmitter) {
                                foldingModel._updateEventEmitter.fire();
                            }
                        }
                    }
                });
            }
        }
    });

    // Query Panel Logic
    const scenarioSelect = document.getElementById('scenario-select') as HTMLSelectElement;
    const querySelect = document.getElementById('query-select') as HTMLSelectElement;
    const btnQuery = document.getElementById('btn-query') as HTMLButtonElement;
    const resultsDisplay = document.getElementById('results-display') as HTMLPreElement;

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
                
                // Populate queries
                querySelect.innerHTML = '<option value="">Select a query...</option>';
                if (res.queries) {
                    res.queries.forEach((q: any) => {
                        const option = document.createElement('option');
                        // q is now an object with name, template, and le
                        option.value = q.name;
                        option.textContent = q.le || q.template;
                        querySelect.appendChild(option);
                    });
                }
                
                resultsDisplay.textContent = 'Results';
                isLoading = false;
                return true;
            } else {
                resultsDisplay.textContent = 'Error loading module: ' + (res?.error || 'Unknown error');
                isLoading = false;
                return false;
            }
        } catch (err) {
            resultsDisplay.textContent = 'Error connecting to server.';
            console.error(err);
            isLoading = false;
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

    const answersList = document.getElementById('answers-list')!;
    const explanationTree = document.getElementById('explanation-tree')!;

    const renderExplanation = (why: any) => {
        explanationTree.innerHTML = '';
        if (!why) return;

        const createNode = (node: any): HTMLElement => {
            const container = document.createElement('div');
            container.className = 'tree-node';

            const label = document.createElement('div');
            label.className = `tree-label ${node.type || 'success'}`;
            label.textContent = node.literal || node;
            
            if (node.start !== undefined && node.end !== undefined) {
                label.addEventListener('click', (e) => {
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

            if (node.children && node.children.length > 0) {
                const childrenContainer = document.createElement('div');
                childrenContainer.className = 'tree-children';
                node.children.forEach((child: any) => {
                    childrenContainer.appendChild(createNode(child));
                });
                container.appendChild(childrenContainer);
            }

            return container;
        };

        if (Array.isArray(why)) {
            why.forEach(w => explanationTree.appendChild(createNode(w)));
        } else {
            explanationTree.appendChild(createNode(why));
        }
    };

    btnQuery.addEventListener('click', async () => {
        if (!isLoaded) {
            const success = await loadModule();
            if (!success) return;
        }
        
        const scenario = scenarioSelect.value;
        const query = querySelect.value;
        
        if (!query) {
            resultsDisplay.textContent = 'Please select a query.';
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
                    scenario: scenario
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
                item.className = 'answer-item failure';
                item.style.color = '#f48771';
                item.textContent = 'false';
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
}

(window as any).startEditor = start;
