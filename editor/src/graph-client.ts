import cytoscape from 'cytoscape';
import fcose from 'cytoscape-fcose';
import dagre from 'cytoscape-dagre';
import elk from 'cytoscape-elk';

cytoscape.use(fcose);
cytoscape.use(dagre);
cytoscape.use(elk);

const graphContainer = document.getElementById('graph-container')!;
const btnRefreshGraph = document.getElementById('btn-refresh-graph')!;
const layoutSelect = document.getElementById('layout-select') as HTMLSelectElement;
const scenarioSelect = document.getElementById('scenario-select') as HTMLSelectElement;
const graphSearch = document.getElementById('graph-search') as HTMLInputElement;
const tooltip = document.getElementById('tooltip')!;
const contextMenu = document.getElementById('context-menu')!;
const ctxLayoutFromHere = document.getElementById('ctx-layout-from-here')!;
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
                'font-size': '12px',
                'background-color': isLight ? '#ddd' : '#666',
                'width': 'label',
                'height': 'label',
                'padding': '15px',
                'shape': 'round-rectangle',
                'text-wrap': 'wrap',
                'text-max-width': '350px',
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
                'font-size': '9px',
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

ctxCopyUrl.addEventListener('click', () => {
    if (rightClickedNode) {
        const url = new URL(window.location.href);
        url.searchParams.set('focus', rightClickedNode.id());
        navigator.clipboard.writeText(url.toString()).then(() => {
            alert('URL copied to clipboard');
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
            const type = ele.data('type');
            const parent = ele.data('parent');
            
            let visible = activeTypes.includes(type);
            
            // Special handling for scenario facts
            if (type === 'fact' && parent && typeof parent === 'string' && parent.startsWith('scenario_')) {
                // If Scenarios are hidden, hide their facts too
                if (!activeTypes.includes('scenario')) {
                    visible = false;
                } else {
                    visible = visible && (selectedScenarioId === "" || parent === selectedScenarioId);
                }
            }
            
            // Special handling for scenario compound nodes
            if (type === 'scenario') {
                visible = visible && (selectedScenarioId === "" || ele.id() === selectedScenarioId);
            }

            if (visible) {
                ele.removeClass('hidden');
                ele.style('display', 'element');
            } else {
                ele.addClass('hidden');
                ele.style('display', 'none');
            }
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
            
            applyFilters();
            
            // Force a layout run after a short delay to ensure elements are ready
            setTimeout(() => {
                runLayout();
            }, 100);
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
    console.log('Running layout:', layoutName);
    
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
        options.idealEdgeLength = 150;
        options.nodeRepulsion = 8000;
        options.gravity = 0.25;
        options.numIter = 2500;
        // fCoSE specific
        options.nodeDimensionsIncludeLabels = true;
        options.uniformNodeDimensions = false;
    } else if (layoutName === 'dagre') {
        options.rankDir = 'LR';
        options.spacingFactor = 1.2;
    } else if (layoutName === 'elk') {
        options.elk = {
            'algorithm': 'layered',
            'direction': 'RIGHT',
            'spacing.nodeNode': 40,
            'spacing.componentComponent': 40,
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
                    } else {
                        runLayout(); // Ensure layout runs after initial load
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

// Event Listeners
btnRefreshGraph.addEventListener('click', refreshGraph);
layoutSelect.addEventListener('change', runLayout);
scenarioSelect.addEventListener('change', applyFilters);

visibilityCheckboxes.forEach(cb => {
    cb.addEventListener('change', applyFilters);
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

// Request initial state
graphChannel.postMessage({ type: 'request-state' });
