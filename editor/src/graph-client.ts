import cytoscape from 'cytoscape';
import { t, applyI18nDom, installLeApiLang } from './i18n';
import fcose from 'cytoscape-fcose';
import dagre from 'cytoscape-dagre';
import elk from 'cytoscape-elk';
import { graphToMermaid } from './mermaid-export';

cytoscape.use(fcose);
cytoscape.use(dagre);
cytoscape.use(elk);

const graphContainer = document.getElementById('graph-container')!;
const btnRefreshGraph = document.getElementById('btn-refresh-graph')!;
const btnCopyMermaid = document.getElementById('btn-copy-mermaid')!;
const layoutSelect = document.getElementById('layout-select') as HTMLSelectElement;
const directionSelect = document.getElementById('direction-select') as HTMLSelectElement;
const scenarioSelect = document.getElementById('scenario-select') as HTMLSelectElement;
const graphSearch = document.getElementById('graph-search') as HTMLInputElement;
const tooltip = document.getElementById('tooltip')!;
const contextMenu = document.getElementById('context-menu')!;
const ctxLayoutFromHere = document.getElementById('ctx-layout-from-here')!;
const ctxCopyNode = document.getElementById('ctx-copy-node')!;
const ctxCopyUrl = document.getElementById('ctx-copy-url')!;

// Navigation buttons
const btnZoomIn = document.getElementById('btn-zoom-in')!;
const btnZoomOut = document.getElementById('btn-zoom-out')!;
const btnFit = document.getElementById('btn-fit')!;
const btnCenter = document.getElementById('btn-center')!;

// Visibility checkboxes
const visibilityCheckboxes = document.querySelectorAll('.checkbox-item input[type="checkbox"]') as NodeListOf<HTMLInputElement>;

let sessionModule: string | null = null;
let rawGraphData: { nodes: any[], edges: any[] } | null = null;
const graphChannel = new BroadcastChannel('le-graph-sync');

// --- View preferences, persisted in LocalStorage -------------------------------
// Layout algorithm, direction, and the selected layers (node/edge type
// checkboxes) survive across graph windows, so the view opens the way the user
// last configured it.
const PREF_LAYOUT = 'le-graph-layout';
const PREF_DIRECTION = 'le-graph-direction';
const PREF_LAYERS = 'le-graph-layers';

function restorePreferences() {
    const layout = localStorage.getItem(PREF_LAYOUT);
    if (layout && Array.from(layoutSelect.options).some(o => o.value === layout)) {
        layoutSelect.value = layout;
    }
    const direction = localStorage.getItem(PREF_DIRECTION);
    if (direction && Array.from(directionSelect.options).some(o => o.value === direction)) {
        directionSelect.value = direction;
    }
    try {
        const layers = JSON.parse(localStorage.getItem(PREF_LAYERS) || 'null');
        if (layers && typeof layers === 'object') {
            visibilityCheckboxes.forEach(cb => {
                const t = cb.dataset.type || '';
                if (t in layers) cb.checked = !!layers[t];
            });
        }
    } catch { /* corrupt preference: keep the defaults */ }
}

function savePreferences() {
    localStorage.setItem(PREF_LAYOUT, layoutSelect.value);
    localStorage.setItem(PREF_DIRECTION, directionSelect.value);
    const layers: { [t: string]: boolean } = {};
    visibilityCheckboxes.forEach(cb => { layers[cb.dataset.type || ''] = cb.checked; });
    localStorage.setItem(PREF_LAYERS, JSON.stringify(layers));
}

restorePreferences();

const getThemeStyles = (theme: string) => {
    const isLight = theme === 'le-theme-light';
    const isHC = theme === 'hc-black';
    
    document.body.classList.remove('light-theme', 'hc-theme');
    if (isLight) document.body.classList.add('light-theme');
    else if (isHC) document.body.classList.add('hc-theme');

    const bgColor = isLight ? '#ffffff' : (isHC ? '#000000' : '#1e1e1e');
    const textColor = isLight ? '#000000' : '#ffffff';
    const edgeColor = isLight ? '#888' : '#444';
    const nodeLabelColor = isLight ? '#000' : '#fff';

    document.body.style.backgroundColor = bgColor;
    document.body.style.color = textColor;
    graphContainer.style.backgroundColor = bgColor;

    return [
        {
            selector: 'node',
            style: {
                'label': 'data(label)',
                'color': nodeLabelColor,
                'text-valign': 'center',
                'text-halign': 'center',
                'font-size': '14px',
                'background-color': isLight ? '#ddd' : '#666',
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
            selector: 'node[type="scenario"]',
            style: {
                'background-color': isLight ? '#e8f5e9' : '#3c3c3c',
                'border-width': 1,
                'border-color': '#89d185',
                'shape': 'rectangle',
                'text-valign': 'top'
            }
        },
        {
            selector: 'node[type="template"]',
            style: {
                'background-color': isLight ? '#fff3e0' : '#795e26',
                'shape': 'round-rectangle',
                'border-width': 1,
                'border-color': '#ffb74d'
            }
        },
        {
            selector: 'node[type="rule"]',
            style: {
                'background-color': isLight ? '#fff3e0' : '#795e26',
                'shape': 'round-rectangle',
                'border-width': 1,
                'border-color': '#ffb74d',
                'font-size': '14px',
                'text-justification': 'left'
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
                'line-color': edgeColor,
                'target-arrow-color': edgeColor,
                'target-arrow-shape': 'triangle',
                'curve-style': 'bezier',
                'label': 'data(type)',
                'font-size': '8px',
                'color': isLight ? '#666' : '#aaa',
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
        },
        {
            selector: '.hidden',
            style: {
                'display': 'none'
            }
        }
    ];
};

let cy = cytoscape({
    container: graphContainer,
    style: getThemeStyles('le-theme'),
    wheelSensitivity: 0.2
});

let rightClickedNode: any = null;

cy.on('cxttap', 'node', (evt) => {
    rightClickedNode = evt.target;
    const containerRect = graphContainer.getBoundingClientRect();
    contextMenu.style.left = `${evt.renderedPosition.x + containerRect.left}px`;
    contextMenu.style.top = `${evt.renderedPosition.y + containerRect.top}px`;
    contextMenu.style.display = 'block';
});

document.addEventListener('click', () => {
    contextMenu.style.display = 'none';
});

ctxLayoutFromHere.addEventListener('click', () => {
    if (rightClickedNode) {
        cy.layout({
            name: 'breadthfirst',
            roots: rightClickedNode,
            animate: true,
            nodeDimensionsIncludeLabels: true
        } as any).run();
    }
});

// Copy the node's text (its label — the LE sentence, template, or name) so it
// can be pasted into the editor, a document, or a chat.
ctxCopyNode.addEventListener('click', () => {
    if (rightClickedNode) {
        const label = rightClickedNode.data('label') || rightClickedNode.id();
        navigator.clipboard.writeText(String(label)).then(() => {
            alert(t('Node copied to clipboard'));
        });
    }
});

ctxCopyUrl.addEventListener('click', () => {
    if (rightClickedNode) {
        const url = new URL(window.location.href);
        url.searchParams.set('focus', rightClickedNode.id());
        navigator.clipboard.writeText(url.toString()).then(() => {
            alert(t('URL copied to clipboard'));
        });
    }
});

cy.on('tap', 'node', (evt) => {
    const node = evt.target;
    const source = node.data('source');
    if (source && source.start !== undefined && source.end !== undefined) {
        graphChannel.postMessage({
            type: 'select-range',
            data: { start: source.start, end: source.end }
        });
    }
});

cy.on('mouseover', 'node, edge', (evt) => {
    const ele = evt.target;
    const type = ele.data('type');
    const label = ele.data('label') || '';
    
    if (ele.isNode()) {
        // Map internal types to user-friendly names
        let typeName = type.toUpperCase();
        if (type === 'template') typeName = 'TEMPLATE';
        else if (type === 'rule') typeName = 'RULE';
        else if (type === 'fact') typeName = 'FACT';
        else if (type === 'scenario') typeName = 'SCENARIO';
        else if (type === 'type') typeName = 'TYPE';
        else if (type === 'query') typeName = 'QUERY';

        tooltip.textContent = `${typeName}: ${label}`;
    } else {
        const sourceEle = ele.source();
        const sourceType = sourceEle.data('type');
        const targetType = ele.target().data('type');
        let msg = `${type}: ${sourceType} -> ${targetType}`;
        if (type === 'uses') {
            if (sourceType === 'fact') msg = 'fact uses template';
            else if (sourceType === 'query') msg = 'query uses template';
            else msg = 'rule uses template';
        }
        else if (type === 'negates') msg = 'rule negates template';
        else if (type === 'depends-on') msg = 'rule depends on rule/fact';
        else if (type === 'is-a') msg = 'type is a supertype';
        tooltip.textContent = msg;
    }
    tooltip.style.display = 'block';
});

cy.on('mousemove', 'node, edge', (evt) => {
    const containerRect = graphContainer.getBoundingClientRect();
    tooltip.style.left = `${evt.renderedPosition.x + containerRect.left + 15}px`;
    tooltip.style.top = `${evt.renderedPosition.y + containerRect.top + 15}px`;
});

cy.on('mouseout', 'node, edge', () => {
    tooltip.style.display = 'none';
});

async function refreshGraph() {
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
            rawGraphData = data;
            
            // Update scenario select
            const scenarios = data.nodes.filter((n: any) => n.data.type === 'scenario');
            const currentVal = scenarioSelect.value;
            scenarioSelect.innerHTML = '<option value="">None</option>';
            scenarios.forEach((s: any) => {
                const opt = document.createElement('option');
                opt.value = s.data.id;
                opt.textContent = s.data.label;
                scenarioSelect.appendChild(opt);
            });
            scenarioSelect.value = currentVal;

            cy.elements().remove();
            cy.add(data.nodes);
            cy.add(data.edges);

            // One deterministic sequence: filter to the selected layers, then lay
            // out the visible elements once. (A second, deferred layout used to
            // race the initial one, so the view sometimes settled on a layout
            // computed from a stale visible set — "fewer layers than selected".)
            applyFilters();
            runLayout();
        }
    } catch (err) {
        console.error('Failed to refresh graph', err);
    }
}

function applyFilters() {
    const checkboxes = document.querySelectorAll('.checkbox-item input[type="checkbox"]') as NodeListOf<HTMLInputElement>;
    const activeTypes = Array.from(checkboxes)
        .filter(cb => cb.checked)
        .map(cb => cb.dataset.type || "");
    
    // Internal edge types that don't have checkboxes
    const internalTypes = [...activeTypes];
    if (activeTypes.includes('scenario')) internalTypes.push('scopes');
    if (activeTypes.includes('template') && activeTypes.includes('type')) internalTypes.push('defines');

    console.log('Active types:', activeTypes);
    const selectedScenarioId = scenarioSelect.value;

    // Process nodes first
    cy.nodes().forEach(ele => {
        const type = ele.data('type');
        const parent = ele.data('parent');
        
        let visible = activeTypes.includes(type);
        
        // Special handling for scenario facts
        if (type === 'fact' && parent && typeof parent === 'string' && parent.startsWith('scenario_')) {
            // Scenario facts are visible ONLY if BOTH "Facts" and "Scenarios" are checked
            visible = activeTypes.includes('fact') && activeTypes.includes('scenario');
            if (visible && selectedScenarioId !== "") {
                visible = (parent === selectedScenarioId);
            }
        }
        
        // Special handling for scenario compound nodes
        if (type === 'scenario') {
            visible = activeTypes.includes('scenario');
            if (visible && selectedScenarioId !== "") {
                visible = (ele.id() === selectedScenarioId);
            }
        }

        if (visible) {
            ele.removeClass('hidden');
            ele.style('display', 'element');
        } else {
            ele.addClass('hidden');
            ele.style('display', 'none');
        }
    });

    // Then process edges
    cy.edges().forEach(ele => {
        const type = ele.data('type');
        const source = ele.source();
        const target = ele.target();
        
        // Edge is visible if its type is active AND both endpoints are visible
        // We use internalTypes for the type check to include 'scopes' and 'defines'
        if (internalTypes.includes(type) && !source.hasClass('hidden') && !target.hasClass('hidden')) {
            ele.removeClass('hidden');
            ele.style('display', 'element');
        } else {
            ele.addClass('hidden');
            ele.style('display', 'none');
        }
    });
}

function runLayout() {
    const layoutName = layoutSelect.value;
    const direction = directionSelect.value;
    console.log('Running layout:', layoutName, 'Direction:', direction);
    
    // Filter out hidden elements for the layout engine
    // We use a collection of visible elements to avoid layout crashes
    const visibleEles = cy.elements(':visible');
    
    if (visibleEles.empty()) return;

    const options: any = { 
        name: layoutName,
        animate: true,
        nodeDimensionsIncludeLabels: true,
        padding: 30,
        fit: true,
        eles: visibleEles
    };

    if (layoutName === 'fcose' || layoutName === 'cose') {
        options.randomize = true;
        options.idealEdgeLength = 100;
        options.nodeRepulsion = 4000;
        options.gravity = 0.25;
        options.numIter = 2500;
        // fCoSE specific
        options.nodeDimensionsIncludeLabels = true;
        options.uniformNodeDimensions = false;
    } else if (layoutName === 'dagre') {
        options.rankDir = direction;
        options.spacingFactor = 1.1;
    } else if (layoutName === 'elk') {
        options.elk = {
            'algorithm': 'layered',
            'direction': direction === 'LR' ? 'RIGHT' : 'DOWN',
            'spacing.nodeNode': 30,
            'spacing.componentComponent': 30,
            'hierarchyHandling': 'INCLUDE_CHILDREN'
        };
    }

    try {
        const layout = cy.layout(options);
        layout.one('layoutstop', () => {
            console.log('Layout finished');
            cy.fit(undefined, 30);
        });
        layout.run();
    } catch (e) {
        console.error('Layout failed, falling back to grid', e);
        cy.layout({ name: 'grid', eles: visibleEles }).run();
    }
}

graphChannel.onmessage = (event) => {
    const { type, data } = event.data;
    switch (type) {
        case 'init-state':
            sessionModule = data.sessionModule;
            cy.style(getThemeStyles(data.theme));
            if (data.filename) {
                const titleEl = document.getElementById('title');
                if (titleEl) titleEl.textContent = `Graph View for ${data.filename}`;
            }
            if (data.isLoaded) {
                // refreshGraph already filters and lays out; only the ?focus=
                // deep link needs handling afterwards.
                refreshGraph().then(() => {
                    const urlParams = new URLSearchParams(window.location.search);
                    const focusId = urlParams.get('focus');
                    if (focusId) {
                        const node = cy.getElementById(focusId);
                        if (node.length > 0) {
                            cy.nodes().removeClass('focused');
                            node.addClass('focused');
                            cy.animate({ center: { eles: node } }, { duration: 500 });
                        }
                    }
                });
            }
            break;
        case 'theme-change':
            cy.style(getThemeStyles(data.theme));
            break;
        case 'focus-offset':
            focusNodeAtOffset(data.offset);
            break;
        case 'module-loaded':
            sessionModule = data.sessionModule;
            refreshGraph();
            break;
    }
};

function focusNodeAtOffset(offset: number) {
    const nodes = cy.nodes().not('.hidden');
    let bestNode: any = null;
    let minRange = Infinity;

    nodes.forEach((node: any) => {
        const source = node.data('source');
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
        if (!cy.extent().contains(bestNode.boundingBox())) {
            cy.animate({ center: { eles: bestNode } }, { duration: 300 });
        }
    }
}

// The VISIBLE graph (current layers + scenario filter) as Mermaid text, so the
// export matches what is on screen; direction follows the Direction selector.
function visibleGraphAsMermaid(): string {
    const nodes = cy.nodes(':visible').map((n: any) => ({
        id: n.id(), type: n.data('type'), label: n.data('label') || n.id(),
        parent: n.data('parent'),
    }));
    const edges = cy.edges(':visible').map((e: any) => ({
        source: e.data('source'), target: e.data('target'), type: e.data('type'),
    }));
    return graphToMermaid(nodes, edges, directionSelect.value === 'TB' ? 'TD' : 'LR');
}

// Event Listeners
btnRefreshGraph.addEventListener('click', refreshGraph);
btnCopyMermaid.addEventListener('click', () => {
    navigator.clipboard.writeText(visibleGraphAsMermaid()).then(() => {
        alert(t('Mermaid diagram copied to clipboard'));
    });
});
layoutSelect.addEventListener('change', () => { savePreferences(); runLayout(); });
directionSelect.addEventListener('change', () => { savePreferences(); runLayout(); });
scenarioSelect.addEventListener('change', () => { applyFilters(); runLayout(); });

// A layer toggle must re-run the layout: nodes that were hidden during the
// last layout have no meaningful positions, so merely showing them would pile
// them up unpositioned.
visibilityCheckboxes.forEach(cb => {
    cb.addEventListener('change', () => { savePreferences(); applyFilters(); runLayout(); });
});

btnZoomIn.addEventListener('click', () => cy.zoom(cy.zoom() * 1.2));
btnZoomOut.addEventListener('click', () => cy.zoom(cy.zoom() * 0.8));
btnFit.addEventListener('click', () => cy.fit());
btnCenter.addEventListener('click', () => cy.center());

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

// Handle window resize
window.addEventListener('resize', () => {
    cy.resize();
});

// Test-only hook (enabled by a localStorage flag the e2e sets before opening
// the window): exposes the cytoscape instance so tests can assert on rendered
// nodes/visibility. No-op in normal use.
try {
    if (localStorage.getItem('le_graph_test') === '1') {
        (window as any).__graphTest = {
            cy,
            nodes: () => cy.nodes().map((n: any) => ({
                id: n.id(), type: n.data('type'), label: n.data('label') || '',
                visible: n.style('display') !== 'none',
            })),
            refreshGraph,
            rightClicked: () => rightClickedNode && rightClickedNode.data('label'),
            mermaid: () => visibleGraphAsMermaid(),
        };
    }
} catch { /* localStorage unavailable */ }

// Request initial state
graphChannel.postMessage({ type: 'request-state' });


// UI chrome i18n: translate this page's static chrome and carry the UI
// language on /leapi calls (see src/i18n.ts).
installLeApiLang();
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => applyI18nDom());
} else {
    applyI18nDom();
}
