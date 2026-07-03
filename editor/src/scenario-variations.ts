// Scenario Variations window. Pick a scenario, alter its facts (via the shared
// ScenarioForm), and run one or more of the program's queries against the altered
// scenario — each query shown with the Query-panel body (answers + explanation, via
// the shared ExplanationView). The window's URL captures the variation
// (scenario / scenarioText / queries, plus the program text) so it can be shared.

import { parseScenarioBlocks } from './le-templates';
import { ScenarioForm } from './scenario-form';
import { ExplanationView, MenuEls } from './explanation-view';

interface VariationsData {
    source?: string;
    kbName?: string;
    queries?: { name: string; label?: string }[];
    scenarios?: string[];
    selectedScenario?: string;
    selectedQuery?: string;
}

const TOKEN = 'myToken123';

async function leapi(body: any): Promise<any> {
    return fetch('/leapi', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token: TOKEN, ...body }),
    }).then(r => r.json());
}

export async function initScenarioVariations() {
    const $ = (id: string) => document.getElementById(id)!;
    const url = new URLSearchParams(location.search);
    const ls: VariationsData = JSON.parse(localStorage.getItem('le_scenario_variations_data') || '{}');

    // Program text: from the URL (shared link) or localStorage (opened from editor).
    let source = url.get('text') || ls.source || '';
    let kbName = ls.kbName || '';
    let queryDefs: { name: string; label?: string }[] = Array.isArray(ls.queries) ? ls.queries : [];

    // This window keeps its OWN reasoning session, independent of the editor's. The
    // editor reloading its module (or its session being reclaimed) must never break
    // the variation being explored here, so we deliberately do NOT reuse the editor's
    // sessionModule — we load our own from the program text.
    let sessionModule: string | null = null;
    let sessionLoad: Promise<void> | null = null;
    function startSessionLoad(): Promise<void> {
        if (!sessionLoad) {
            sessionLoad = (source ? leapi({ operation: 'load', le: source }) : Promise.resolve(null))
                .then((r: any) => {
                    if (r && r.sessionModule) {
                        sessionModule = r.sessionModule;
                        if (!kbName) kbName = r.kb || '';
                        if (queryDefs.length === 0 && Array.isArray(r.queries)) {
                            queryDefs = r.queries.map((q: any) => ({ name: q.name, label: q.le || q.template }));
                        }
                    }
                })
                .catch(() => { /* reported when the user actually runs a query */ });
        }
        return sessionLoad;
    }
    // A shared link carries only the text, so we must load to discover the queries;
    // otherwise we render immediately and load the session in the background, so it is
    // ready by the time the user runs a query.
    if (queryDefs.length === 0 && source) await startSessionLoad();
    else startSessionLoad();

    const blocks = parseScenarioBlocks(source);
    const blockByName = new Map(blocks.map(b => [b.name, b]));
    const scenarioNames = Array.isArray(ls.scenarios) && ls.scenarios.length ? ls.scenarios : blocks.map(b => b.name);

    ($('title') as HTMLElement).textContent = `Scenario variations for ${kbName || 'this program'}`;

    // --- Scenario picker -------------------------------------------------------
    const picker = $('scenario-picker') as HTMLSelectElement;
    picker.innerHTML = '';
    const emptyOpt = document.createElement('option');
    emptyOpt.value = '';
    emptyOpt.textContent = '(empty)';
    picker.appendChild(emptyOpt);
    scenarioNames.forEach(n => {
        const o = document.createElement('option');
        o.value = n; o.textContent = n;
        picker.appendChild(o);
    });

    // --- Scenario form ---------------------------------------------------------
    const statusEl = $('status');
    const btnRun = $('btn-run') as HTMLButtonElement;
    const setStatus = (t: string) => { statusEl.textContent = t; };

    const form = new ScenarioForm({
        source,
        rowsEl: $('rows'),
        addSelect: $('add-template') as HTMLSelectElement,
        btnAdd: $('btn-add') as HTMLButtonElement,
        assumeTitle: 'Consider this unknown, and assume it to be true',
        onChange: () => { markStale(); syncUrl(); },
    });

    // --- Query cards (each with its own answers + explanation view) ------------
    const menus: MenuEls = {
        answerContextMenu: $('answer-context-menu'),
        menuCopyAnswer: $('menu-copy-answer'),
        explanationContextMenu: $('explanation-context-menu'),
        menuCopyExplanation: $('menu-copy-explanation'),
        menuGotoOriginal: $('menu-goto-original'),
        answerTooltip: $('answer-tooltip'),
        titleMenu: $('explanation-title-menu'),
        menuShowStrongest: $('menu-show-strongest'),
        menuExplanationDrill: $('menu-explanation-drill'),
        menuPatchScenario: $('menu-patch-scenario'),
        menuAssumeFact: $('menu-assume-fact'),
    };
    // Patch the shared scenario form from a right-clicked explanation node. A failed
    // node's fact is added (so a re-run can prove it); a succeeded node's fact is
    // deleted; "Assume fact" (failed nodes) adds it as an assumed unknown. Editing the
    // form marks the run stale, so the user re-runs with the Query button.
    const nodeFactText = (node: any): string => (node && typeof node.literal === 'string' ? node.literal.trim() : '');
    const onPatchScenario = (node: any) => {
        const fact = nodeFactText(node);
        if (!fact) return;
        if (node.type === 'failure') {
            form.addFact(fact, false);        // selects the added row
            setStatus(`Added to scenario: ${fact}`);
        } else {
            const removed = form.removeFact(fact);
            setStatus(removed > 0 ? `Deleted from scenario: ${fact}` : `No matching scenario fact to delete: ${fact}`);
        }
        void runAll();                        // re-run so the effect of the patch is visible
    };
    const onAssumeFact = (node: any) => {
        const fact = nodeFactText(node);
        if (!fact) return;
        form.addFact(fact, true);             // selects the added row
        setStatus(`Assuming (unknown, true) in scenario: ${fact}`);
        void runAll();
    };
    const openDrill = (w: any) => {
        // The drill runs its own session from the program source (independent of ours).
        localStorage.setItem('le_explanation_drill_data', JSON.stringify({ source, sessionModule, kbName, why: w }));
        const theme = document.body.className.match(/(light|hc)-theme/)?.[0] || '';
        window.open(`explanation-drill.html?theme=${theme}&v=${Date.now()}`, '_blank');
    };
    // A drill opened from THIS window highlights source via us; relay it on to the editor.
    window.addEventListener('message', (e) => {
        if (e.data && e.data.type === 'le-highlight') window.opener?.postMessage(e.data, '*');
    });
    const failedNodePrefix = () => localStorage.getItem('le-failed-node-prefix') ?? 'x ';
    const hierarchical = () => localStorage.getItem('le-hierarchical-numbering') === 'true';
    const navigate = (start: number, end: number) => {
        // Reveal the source in the editor that opened this window.
        window.opener?.postMessage({ type: 'le-highlight', loc: { start, end } }, '*');
    };

    interface QueryCard { name: string; card: HTMLElement; view: ExplanationView; }
    const queryCards: QueryCard[] = [];
    const queryListEl = $('query-list');

    function addQueryCard(name: string) {
        const card = document.createElement('div');
        card.className = 'query-card';

        const header = document.createElement('div');
        header.className = 'query-header';
        const nameEl = document.createElement('span');
        nameEl.className = 'query-name';
        const def = queryDefs.find(q => q.name === name);
        nameEl.textContent = def?.label ? `${def.label} (${name})` : name;
        header.appendChild(nameEl);
        const remove = document.createElement('button');
        remove.className = 'query-remove';
        remove.textContent = '✕';
        remove.title = 'Remove query';
        header.appendChild(remove);
        card.appendChild(header);

        const area = document.createElement('div');
        area.className = 'results-area';
        const aPanel = document.createElement('div');
        aPanel.className = 'answers-panel';
        aPanel.innerHTML = '<div class="panel-label">Answers</div>';
        const answersList = document.createElement('div');
        aPanel.appendChild(answersList);
        const ePanel = document.createElement('div');
        ePanel.className = 'explanation-panel';
        const eTitle = document.createElement('div');
        eTitle.className = 'panel-label';
        eTitle.textContent = 'Explanation';
        ePanel.appendChild(eTitle);
        const explanationTree = document.createElement('div');
        ePanel.appendChild(explanationTree);
        area.appendChild(aPanel);
        area.appendChild(ePanel);
        card.appendChild(area);

        const view = new ExplanationView({
            answersList, explanationTree, menus, failedNodePrefix,
            explanationTitle: eTitle,
            hierarchicalNumbering: hierarchical, onNavigate: navigate,
            onOpenDrill: openDrill, onPatchScenario, onAssumeFact,
        });
        const entry: QueryCard = { name, card, view };
        remove.addEventListener('click', () => {
            const i = queryCards.indexOf(entry);
            if (i >= 0) queryCards.splice(i, 1);
            card.remove();
            refreshAddQueryOptions();
            markStale(); syncUrl();
        });
        queryCards.push(entry);
        queryListEl.appendChild(card);
        refreshAddQueryOptions();
        return entry;
    }

    // --- Add Query picker ------------------------------------------------------
    // Offer only queries not already added; disable the picker once all are in.
    const addQuerySelect = $('add-query') as HTMLSelectElement;
    const btnAddQuery = $('btn-add-query') as HTMLButtonElement;
    function refreshAddQueryOptions() {
        const used = new Set(queryCards.map(q => q.name));
        const available = queryDefs.filter(q => !used.has(q.name));
        addQuerySelect.innerHTML = '';
        available.forEach(q => {
            const o = document.createElement('option');
            o.value = q.name;
            o.textContent = q.label ? `${q.label} (${q.name})` : q.name;
            addQuerySelect.appendChild(o);
        });
        const none = available.length === 0;
        addQuerySelect.disabled = none;
        btnAddQuery.disabled = none;
    }
    refreshAddQueryOptions();
    btnAddQuery.addEventListener('click', () => {
        const name = addQuerySelect.value;
        if (!name) return;
        addQueryCard(name);
        markStale(); syncUrl();
    });

    // --- Run / staleness -------------------------------------------------------
    // The Query button is disabled after a run and re-enabled by any edit.
    function markStale() { btnRun.disabled = false; }

    async function ensureSession(): Promise<boolean> {
        if (sessionModule) return true;
        await startSessionLoad();          // awaits the in-flight load (or starts one)
        return !!sessionModule;
    }

    async function runOne(entry: QueryCard) {
        entry.view.showMessage('Running…');
        const reqBody = () => ({
            operation: 'answeringQuery',
            sessionModule,
            query: entry.name,
            customScenario: form.factsText(),
            detailedFailures: localStorage.getItem('le-detailed-failures') === 'true',
            hideRepeated: (localStorage.getItem('le-hide-repeated-explanations') ?? 'true') === 'true',
        });
        let res = await leapi(reqBody());
        if (res && res.session_expired) {            // our session was reclaimed (idle) — load a fresh one and retry once
            sessionModule = null;
            sessionLoad = null;
            if (await ensureSession()) res = await leapi(reqBody());
        }
        entry.view.showResults(res);
    }

    async function runAll() {
        if (queryCards.length === 0) { setStatus('Add a query first.'); return; }
        if (!(await ensureSession())) { setStatus('Could not load the program on the server.'); return; }
        btnRun.disabled = true;
        setStatus('Running queries…');
        // Sequential: each query re-applies the custom scenario to the session.
        for (const entry of queryCards) await runOne(entry);
        setStatus(`Ran ${queryCards.length} quer${queryCards.length > 1 ? 'ies' : 'y'}`);
    }
    btnRun.addEventListener('click', runAll);

    // --- Copy Scenario ---------------------------------------------------------
    $('btn-copy-scenario').addEventListener('click', async () => {
        const name = picker.value || 'variation';
        const text = form.blockText(name);
        try { await navigator.clipboard.writeText(text); setStatus('Scenario copied to clipboard'); }
        catch { window.prompt('Copy the scenario text:', text); }
    });

    // --- URL sync (for sharing) ------------------------------------------------
    function syncUrl() {
        const u = new URL(location.href);
        u.searchParams.set('text', source);                 // self-contained for sharing
        u.searchParams.set('scenario', picker.value);
        u.searchParams.set('scenarioText', form.factsText());
        u.searchParams.set('queries', queryCards.map(q => q.name).join(','));
        window.history.replaceState({}, '', u.toString());
    }

    // --- Loading a scenario ----------------------------------------------------
    function loadScenarioFromPicker() {
        const name = picker.value;
        const block = name ? blockByName.get(name) : null;
        form.loadFacts(block ? block.facts : []);
    }
    picker.addEventListener('change', () => { loadScenarioFromPicker(); markStale(); syncUrl(); });

    // --- Initial state (URL params override the localStorage defaults) ---------
    const urlScenario = url.get('scenario');
    const urlScenarioText = url.get('scenarioText');
    const urlQueries = url.get('queries');

    picker.value = urlScenario !== null ? urlScenario : (ls.selectedScenario || '');
    if (urlScenarioText !== null) {
        // Restore the exact altered facts.
        form.loadFacts(urlScenarioText.split(/\n+/).map(s => s.trim()).filter(Boolean));
    } else {
        loadScenarioFromPicker();
    }
    const initialQueries = urlQueries !== null
        ? urlQueries.split(',').map(s => s.trim()).filter(Boolean)
        : (ls.selectedQuery ? [ls.selectedQuery] : []);
    // Add each query at most once, even if a shared URL lists it twice.
    [...new Set(initialQueries)].forEach(n => addQueryCard(n));

    syncUrl();
    setStatus('Ready');
}
