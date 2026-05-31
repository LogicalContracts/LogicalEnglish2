import * as React from 'react';
import { NodeEditor, GetSchemes, ClassicPreset } from 'rete';
import { AreaPlugin, AreaExtensions } from 'rete-area-plugin';
import { ConnectionPlugin, Presets as ConnectionPresets } from 'rete-connection-plugin';
import { ReactPlugin, Presets, ReactArea2D } from 'rete-react-plugin';
import { AutoArrangePlugin, Presets as ArrangePresets } from 'rete-auto-arrange-plugin';
import { createRoot } from 'react-dom/client';

const { RefSocket, Socket, useConnection } = Presets.classic;

type Schemes = GetSchemes<
    ClassicPreset.Node,
    ClassicPreset.Connection<ClassicPreset.Node, ClassicPreset.Node>
>;
type AreaExtra = ReactArea2D<Schemes>;

class FactNode extends ClassicPreset.Node {
    width = 220;
    height = 60;
    public sourceLoc?: { start: number, end: number };
    public templateId: string;
    public tokens: any[];
    public complete: boolean = false;
    
    constructor(public label: string, public color: string, templateId: string, tokens: any[], sourceLoc?: { start: number, end: number }) {
        super(label);
        this.type = 'fact';
        this.templateId = templateId;
        this.tokens = tokens;
        this.sourceLoc = sourceLoc;
        this.addOutput('out', new ClassicPreset.Output(new ClassicPreset.Socket('socket')));
    }
    type: string;
}

class QueryNode extends ClassicPreset.Node {
    width = 220;
    height = 60;
    public templateId: string = 'query';
    public tokens: any[] = [];
    public clash: boolean = false;
    public complete: boolean = false;
    
    constructor(public label: string, public color: string) {
        super(label);
        this.type = 'query';
        this.addInput('in', new ClassicPreset.Input(new ClassicPreset.Socket('query-socket')));
    }
    type: string;
}

class RuleNode extends ClassicPreset.Node {
    width = 220;
    height = 180;
    public sourceLoc?: { start: number, end: number };
    public templateId: string;
    public headTokens: any[];
    public bodyTokens: any[][];
    public clash: boolean = false;
    public complete: boolean = false;
    
    constructor(public rule: any, sourceLoc?: { start: number, end: number }) {
        super('');
        this.type = 'rule';
        this.templateId = rule.id;
        this.headTokens = rule.headTokens;
        this.bodyTokens = rule.bodyTokens;
        this.sourceLoc = sourceLoc;
        const socket = new ClassicPreset.Socket('socket');
        this.addOutput('out', new ClassicPreset.Output(socket));
        if (rule.body) {
            rule.body.forEach((cond: string, i: number) => {
                this.addInput(`in-${i}`, new ClassicPreset.Input(socket));
            });
        }
    }
    type: string;
}

function renderTokens(tokens: any[]) {
    if (!tokens) return '';
    return tokens.map(t => t.text).join(' ');
}

function CustomNode(props: any) {
    const { data, emit } = props;
    const modeToggle = document.getElementById('mode-toggle') as HTMLInputElement;
    const isAdultMode = modeToggle?.checked;
    
    if (data.type === 'rule') {
        const headColor = data.clash ? '#f44336' : (data.complete ? '#4caf50' : (isAdultMode ? '#333' : '#ff9800'));
        const bodyColor = data.complete ? '#81c784' : (isAdultMode ? '#333' : '#ffeb3b');
        const textColor = isAdultMode ? '#fff' : 'transparent';
        
        const bodyCount = data.rule.body ? data.rule.body.length : 0;
        const nodeWidth = Math.max(220, bodyCount * 220);
        data.width = nodeWidth;
        data.height = bodyCount > 0 ? 180 : 80;
        
        const headText = renderTokens(data.headTokens) || data.rule.head;
        
        return React.createElement('div', {
            className: `le-node rule-node ${data.selected ? 'selected' : ''} ${data.clash ? 'clash' : ''} ${data.complete ? 'complete' : ''}`,
            style: {
                width: nodeWidth + 'px',
                position: 'relative',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: '40px',
                border: data.selected ? '2px solid #0e639c' : (data.clash ? '2px solid #f44336' : (data.complete ? '2px solid #2e7d32' : '2px solid transparent')),
                borderRadius: '8px',
                padding: '10px',
                background: isAdultMode ? '#252526' : 'rgba(255,255,255,0.05)'
            }
        },
            React.createElement('div', {
                style: {
                    background: headColor,
                    color: textColor,
                    padding: '10px',
                    borderRadius: '8px',
                    width: '200px',
                    textAlign: 'center',
                    boxShadow: '0 4px 6px rgba(0,0,0,0.3)',
                    position: 'relative',
                    zIndex: 1,
                    border: isAdultMode ? '1px solid #444' : 'none'
                },
                title: !isAdultMode ? headText : ''
            }, 
                isAdultMode ? headText : '',
                React.createElement('div', {
                    style: { position: 'absolute', left: '50%', top: '-16px', transform: 'translateX(-50%)' }
                }, React.createElement(RefSocket, {
                    name: 'output-socket', emit, side: 'output', nodeId: data.id, socketKey: 'out', payload: data.outputs['out']?.socket
                }))
            ),
            
            bodyCount > 0 && React.createElement('div', {
                style: { display: 'flex', justifyContent: 'center', gap: '20px', width: '100%', zIndex: 1 }
            }, data.rule.body.map((cond: string, i: number) => {
                const condText = renderTokens(data.bodyTokens[i]) || cond;
                return React.createElement('div', {
                    key: i,
                    style: {
                        position: 'relative', background: bodyColor, color: textColor,
                        padding: '10px', borderRadius: '8px', width: '200px',
                        textAlign: 'center', boxShadow: '0 4px 6px rgba(0,0,0,0.3)',
                        border: isAdultMode ? '1px solid #444' : 'none'
                    },
                    title: !isAdultMode ? condText : ''
                }, 
                    isAdultMode ? condText : '',
                    React.createElement('div', {
                        style: { position: 'absolute', left: '50%', bottom: '-16px', transform: 'translateX(-50%)' }
                    }, React.createElement(RefSocket, {
                        name: 'input-socket', emit, side: 'input', nodeId: data.id, socketKey: `in-${i}`, payload: data.inputs[`in-${i}`]?.socket
                    }))
                );
            })),
            
            bodyCount > 0 && React.createElement('svg', {
                style: { position: 'absolute', top: '0', left: '0', width: '100%', height: '100%', pointerEvents: 'none', zIndex: 0 }
            }, 
                React.createElement('defs', null, 
                    React.createElement('marker', {
                        id: 'arrowhead-internal', markerWidth: '10', markerHeight: '7', refX: '9', refY: '3.5', orient: 'auto'
                    }, React.createElement('polygon', { points: '0 0, 10 3.5, 0 7', fill: data.complete ? '#2e7d32' : '#888' }))
                ),
                data.rule.body.map((_: any, i: number) => {
                    const headX = nodeWidth / 2;
                    const headY = 50; 
                    const totalBodyWidth = bodyCount * 200 + (bodyCount - 1) * 20;
                    const startX = (nodeWidth - totalBodyWidth) / 2;
                    const bodyBlockX = startX + i * 220 + 100; 
                    const bodyY = 90; 
                    return React.createElement('path', {
                        key: `arrow-${i}`, d: `M ${bodyBlockX} ${bodyY} L ${headX} ${headY}`,
                        stroke: data.complete ? '#2e7d32' : '#888', strokeWidth: '2', fill: 'none', markerEnd: 'url(#arrowhead-internal)'
                    });
                })
            )
        );
    } else {
        // Fact or Query
        const bgColor = data.clash ? '#f44336' : (data.complete ? '#4caf50' : (isAdultMode ? '#333' : data.color));
        const textColor = isAdultMode ? '#fff' : 'transparent';
        data.width = 220;
        data.height = 60;
        
        const labelText = (data.type === 'fact' || data.type === 'query') ? (renderTokens(data.tokens) || data.label) : data.label;
        
        return React.createElement('div', {
            className: `le-node ${data.type}-node ${data.selected ? 'selected' : ''} ${data.clash ? 'clash' : ''} ${data.complete ? 'complete' : ''}`,
            style: {
                background: bgColor,
                color: textColor,
                padding: '10px',
                borderRadius: '8px',
                width: '200px',
                textAlign: 'center',
                boxShadow: '0 4px 6px rgba(0,0,0,0.3)',
                border: data.selected ? '2px solid #0e639c' : (data.clash ? '2px solid #f44336' : (data.complete ? '2px solid #2e7d32' : (isAdultMode ? '1px solid #444' : '2px solid transparent'))),
                position: 'relative'
            },
            title: !isAdultMode ? labelText : ''
        },
            isAdultMode ? labelText : '',
            data.type === 'fact' && React.createElement('div', {
                style: { position: 'absolute', left: '50%', top: '-16px', transform: 'translateX(-50%)' }
            }, React.createElement(RefSocket, {
                name: 'output-socket', emit, side: 'output', nodeId: data.id, socketKey: 'out', payload: data.outputs['out']?.socket
            })),
            
            data.type === 'query' && React.createElement('div', {
                style: { position: 'absolute', left: '50%', bottom: '-16px', transform: 'translateX(-50%)' }
            }, React.createElement(RefSocket, {
                name: 'input-socket', emit, side: 'input', nodeId: data.id, socketKey: 'in', payload: data.inputs['in']?.socket
            }))
        );
    }
}

function CustomSocket(props: any) {
    const { data } = props;
    const isQuery = data.name === 'query-socket';
    
    if (isQuery) {
        return React.createElement('div', {
            style: {
                width: '16px',
                height: '16px',
                background: '#e2b93d',
                border: '2px solid #fff',
                transform: 'rotate(45deg)',
                cursor: 'pointer',
                boxSizing: 'border-box'
            }
        });
    }
    
    return React.createElement('div', {
        style: {
            width: '16px',
            height: '16px',
            borderRadius: '50%',
            background: '#fff',
            border: '2px solid #333',
            cursor: 'pointer',
            boxSizing: 'border-box'
        }
    });
}

function CustomConnection(props: any) {
    const { start, end, path: defaultPath } = useConnection();
    
    let path = defaultPath;
    if (start && end) {
        // Vertical path: start is output (top of body), end is input (bottom of head)
        path = `M ${start.x} ${start.y} C ${start.x} ${start.y - 50}, ${end.x} ${end.y + 50}, ${end.x} ${end.y}`;
    }
    
    if (!path) return null;
    
    return React.createElement(
        'svg',
        { style: { overflow: 'visible', position: 'absolute', pointerEvents: 'none', width: '100%', height: '100%', left: 0, top: 0 } },
        React.createElement(
            'defs',
            null,
            React.createElement(
                'marker',
                {
                    id: 'arrowhead',
                    markerWidth: '10',
                    markerHeight: '7',
                    refX: '9',
                    refY: '3.5',
                    orient: 'auto'
                },
                React.createElement('polygon', { points: '0 0, 10 3.5, 0 7', fill: 'steelblue' })
            )
        ),
        React.createElement('path', {
            d: path,
            fill: 'none',
            stroke: 'steelblue',
            strokeWidth: '3px',
            markerEnd: 'url(#arrowhead)'
        })
    );
}

function playSuccessSound() {
    const audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
    const notes = [523.25, 659.25, 783.99, 1046.50]; // C5, E5, G5, C6
    notes.forEach((freq, i) => {
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(freq, audioCtx.currentTime + i * 0.1);
        gain.gain.setValueAtTime(0.1, audioCtx.currentTime + i * 0.1);
        gain.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + i * 0.1 + 0.5);
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        osc.start(audioCtx.currentTime + i * 0.1);
        osc.stop(audioCtx.currentTime + i * 0.1 + 0.5);
    });
}

function playClashSound() {
    const audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(100, audioCtx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(50, audioCtx.currentTime + 0.3);
    
    gain.gain.setValueAtTime(0.1, audioCtx.currentTime);
    gain.gain.linearRampToValueAtTime(0, audioCtx.currentTime + 0.3);
    
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    
    osc.start();
    osc.stop(audioCtx.currentTime + 0.3);
}

export async function initProofGame(container: HTMLElement, gameData: any) {
    const editor = new NodeEditor<Schemes>();
    const area = new AreaPlugin<Schemes, AreaExtra>(container);
    const connection = new ConnectionPlugin<Schemes, AreaExtra>();
    const render = new ReactPlugin<Schemes, AreaExtra>({ createRoot });
    const sessionModule = gameData.sessionModule;
    let wasComplete = false;
    let wasClash = false;

    function checkCompletion() {
        const nodes = editor.getNodes();
        const connections = editor.getConnections();
        const queryNode = nodes.find(n => n instanceof QueryNode) as QueryNode;
        
        if (!queryNode) return false;
        
        const visited = new Set<string>();
        const fragmentNodes = new Set<string>();
        
        function isComplete(nodeId: string): boolean {
            if (visited.has(nodeId)) return true;
            visited.add(nodeId);
            
            const node = editor.getNode(nodeId);
            if (!node) return false;
            fragmentNodes.add(nodeId);
            
            if (node instanceof FactNode) return true;
            
            if (node instanceof QueryNode) {
                const conn = connections.find(c => c.target === nodeId);
                if (!conn) return false;
                return isComplete(conn.source);
            }
            
            if (node instanceof RuleNode) {
                const bodyCount = node.rule.body ? node.rule.body.length : 0;
                for (let i = 0; i < bodyCount; i++) {
                    const conn = connections.find(c => c.target === nodeId && c.targetInput === `in-${i}`);
                    if (!conn) return false;
                    if (!isComplete(conn.source)) return false;
                }
                return true;
            }
            
            return false;
        }
        
        const complete = isComplete(queryNode.id);
        
        // Reset complete flag on all nodes
        nodes.forEach(n => {
            const old = (n as any).complete;
            (n as any).complete = complete && fragmentNodes.has(n.id);
            if (old !== (n as any).complete) area.update('node', n.id);
        });
        
        if (complete && !wasComplete) {
            playSuccessSound();
            wasComplete = true;
        } else if (!complete) {
            wasComplete = false;
        }
        
        return complete;
    }

    async function updateUnification() {
        const nodes = editor.getNodes();
        const connections = editor.getConnections();
        
        const nodeSpecs = nodes.map(n => {
            if (n instanceof RuleNode) return { instanceId: n.id, templateId: n.templateId };
            if (n instanceof FactNode) return { instanceId: n.id, templateId: n.templateId };
            if (n instanceof QueryNode) return { instanceId: n.id, templateId: n.templateId };
            return null;
        }).filter(n => n !== null);
        
        const edges = connections.map(c => {
            const source = editor.getNode(c.source);
            const target = editor.getNode(c.target);
            if (!source || !target) return null;
            
            let bodyIndex = 0;
            if (c.targetInput.startsWith('in-')) {
                bodyIndex = parseInt(c.targetInput.split('-')[1]);
            }
            
            return {
                child: c.source,
                parent: c.target,
                bodyIndex: bodyIndex
            };
        }).filter(e => e !== null);

        try {
            const response = await fetch('/leapi', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    token: 'myToken123',
                    operation: 'unifyGameNodes',
                    sessionModule: sessionModule,
                    nodes: nodeSpecs,
                    edges: edges
                })
            });
            const res = await response.json();
            
            if (res.status === 'ok') {
                res.nodes.forEach((nodeData: any) => {
                    const node = editor.getNode(nodeData.instanceId) as any;
                    if (node) {
                        node.clash = false;
                        if (node instanceof RuleNode) {
                            node.headTokens = nodeData.headTokens;
                            node.bodyTokens = nodeData.bodyTokens;
                        } else if (node instanceof FactNode) {
                            node.tokens = nodeData.headTokens;
                        } else if (node instanceof QueryNode) {
                            node.tokens = nodeData.bodyTokens[0];
                        }
                        area.update('node', node.id);
                    }
                });
                checkCompletion();
                wasClash = false;
            } else if (res.status === 'clash') {
                if (!wasClash) {
                    playClashSound();
                    wasClash = true;
                }
                const connectedNodeIds = new Set();
                connections.forEach(c => {
                    connectedNodeIds.add(c.source);
                    connectedNodeIds.add(c.target);
                });
                nodes.forEach(n => {
                    if (connectedNodeIds.has(n.id)) {
                        (n as any).clash = true;
                        (n as any).complete = false;
                        area.update('node', n.id);
                    }
                });
            }
        } catch (err) {
            console.error('Unification failed:', err);
        }
    }

    AreaExtensions.selectableNodes(area, AreaExtensions.selector(), {
        accumulating: AreaExtensions.accumulateOnCtrl()
    });

    render.addPreset(Presets.classic.setup({
        customize: {
            node() {
                return CustomNode;
            },
            connection() {
                return CustomConnection;
            },
            socket() {
                return CustomSocket;
            }
        }
    }));

    connection.addPreset(ConnectionPresets.classic.setup());

    editor.use(area);
    area.use(connection);
    area.use(render);

    AreaExtensions.simpleNodesOrder(area);

    const arrange = new AutoArrangePlugin<Schemes>();
    arrange.addPreset(ArrangePresets.classic.setup());
    area.use(arrange);

    // Hook into connection events
    editor.addPipe(context => {
        if (context.type === 'connectioncreated' || context.type === 'connectionremoved') {
            updateUnification();
        }
        return context;
    });

    // Parse gameData and create nodes
    const nodes: any[] = [];
    
    // Layout parameters
    const startX = 100;
    let currentX = startX;
    const factY = 500;
    const ruleY = 250;
    const queryY = 50;
    
    // Add Query Node
    if (gameData.query) {
        const queryNode = new QueryNode(gameData.query, '#2196f3');
        await editor.addNode(queryNode);
        await area.translate(queryNode.id, { x: currentX, y: queryY });
        nodes.push(queryNode);
        currentX += 250;
    }
    
    // Add Rules
    if (gameData.rules) {
        for (const rule of gameData.rules) {
            const ruleNode = new RuleNode(rule, { start: rule.start, end: rule.end });
            await editor.addNode(ruleNode);
            await area.translate(ruleNode.id, { x: currentX, y: ruleY });
            nodes.push(ruleNode);
            
            const bodyCount = rule.body ? rule.body.length : 0;
            const nodeWidth = Math.max(220, bodyCount * 220);
            currentX += nodeWidth + 50;
        }
    }
    
    // Add Facts
    currentX = startX;
    if (gameData.facts) {
        for (const fact of gameData.facts) {
            const factNode = new FactNode(fact.fact, '#4caf50', fact.id, fact.factTokens, { start: fact.start, end: fact.end });
            await editor.addNode(factNode);
            await area.translate(factNode.id, { x: currentX, y: factY });
            currentX += 250;
            nodes.push(factNode);
        }
    }

    setTimeout(() => {
        AreaExtensions.zoomAt(area, editor.getNodes());
    }, 100);

    document.getElementById('btn-rearrange')?.addEventListener('click', async () => {
        await arrange.layout();
        AreaExtensions.zoomAt(area, editor.getNodes());
    });

    // Zoom controls
    document.getElementById('btn-zoom-in')?.addEventListener('click', () => {
        const zoom = area.area.zoom;
        area.area.setZoom(zoom * 1.2);
    });
    document.getElementById('btn-zoom-out')?.addEventListener('click', () => {
        const zoom = area.area.zoom;
        area.area.setZoom(zoom / 1.2);
    });
    document.getElementById('btn-zoom-fit')?.addEventListener('click', () => {
        AreaExtensions.zoomAt(area, editor.getNodes());
    });

    // Selection logic for editor highlighting
    area.addPipe(context => {
        if (context.type === 'nodepicked') {
            const node = editor.getNode(context.data.id) as any;
            if (node && node.sourceLoc) {
                if (window.opener) {
                    window.opener.postMessage({ type: 'le-highlight', loc: node.sourceLoc }, '*');
                }
            }
        }
        return context;
    });
    
    // Mode toggle logic
    document.getElementById('mode-toggle')?.addEventListener('change', () => {
        nodes.forEach(n => area.update('node', n.id));
    });
    
    // Show proof logic
    document.getElementById('btn-show')?.addEventListener('click', async () => {
        if (!gameData.explanation) {
            alert("No proof found for this query.");
            return;
        }
        
        if (!confirm("Are you sure you want to miss the excitement of finding the proof yourself?")) {
            return;
        }

        // Clear existing connections
        const existingConnections = editor.getConnections();
        for (const c of existingConnections) {
            await editor.removeConnection(c.id);
        }

        const nodes = editor.getNodes();
        const queryNode = nodes.find(n => n instanceof QueryNode);
        if (!queryNode) return;

        const explanation = Array.isArray(gameData.explanation) ? gameData.explanation[0] : gameData.explanation;
        if (!explanation) return;

        const usedNodes = new Set<string>();

        async function connectExplanation(expNode: any, targetNodeId: string, targetInputKey: string) {
            // Find a matching game node
            const match = nodes.find(n => {
                if (usedNodes.has(n.id)) return false;
                if (n instanceof RuleNode) {
                    return n.sourceLoc?.start === expNode.start && n.sourceLoc?.end === expNode.end;
                }
                if (n instanceof FactNode) {
                    return n.sourceLoc?.start === expNode.start && n.sourceLoc?.end === expNode.end;
                }
                return false;
            });

            if (match) {
                usedNodes.add(match.id);
                await editor.addConnection(new ClassicPreset.Connection(match, 'out', editor.getNode(targetNodeId) as any, targetInputKey));
                
                if (expNode.children && match instanceof RuleNode) {
                    for (let i = 0; i < expNode.children.length; i++) {
                        await connectExplanation(expNode.children[i], match.id, `in-${i}`);
                    }
                }
            }
        }

        await connectExplanation(explanation, queryNode.id, 'in');
        
        // 1. Identify proof tree nodes and non-proof tree nodes
        const proofTreeNodes = new Set<string>();
        proofTreeNodes.add(queryNode.id);
        for (const id of usedNodes) {
            proofTreeNodes.add(id);
        }

        const nonProofNodes = nodes.filter(n => !proofTreeNodes.has(n.id));

        // 2. Lay out non-proof tree nodes in a single compact column at the left
        let currentY = 50;
        for (const n of nonProofNodes) {
            await area.translate(n.id, { x: 50, y: currentY });
            const nodeHeight = (n as any).height || 100;
            currentY += nodeHeight + 30; // 30px spacing
        }

        // 3. Lay out ONLY the PROOF tree nodes
        const proofNodesList = Array.from(proofTreeNodes).map(id => editor.getNode(id));
        const proofConnectionsList = editor.getConnections().filter(c => proofTreeNodes.has(c.source) && proofTreeNodes.has(c.target));

        await arrange.layout({
            nodes: proofNodesList,
            connections: proofConnectionsList,
            options: {
                'elk.direction': 'UP',
                'elk.spacing.nodeNode': '50',
                'elk.layered.spacing.nodeNodeBetweenLayers': '80'
            }
        });

        // 4. Shift proof tree nodes to the right of the non-proof nodes column
        let maxNonProofWidth = 0;
        for (const n of nonProofNodes) {
            const w = (n as any).width || 220;
            if (w > maxNonProofWidth) {
                maxNonProofWidth = w;
            }
        }

        const proofTreeStartX = maxNonProofWidth > 0 ? 50 + maxNonProofWidth + 100 : 100;

        let minProofX = Infinity;
        let minProofY = Infinity;
        for (const id of proofTreeNodes) {
            const pos = area.nodeViews.get(id)?.position;
            if (pos) {
                if (pos.x < minProofX) minProofX = pos.x;
                if (pos.y < minProofY) minProofY = pos.y;
            }
        }

        if (minProofX !== Infinity && minProofY !== Infinity) {
            const dx = proofTreeStartX - minProofX;
            const dy = 50 - minProofY;
            for (const id of proofTreeNodes) {
                const pos = area.nodeViews.get(id)?.position;
                if (pos) {
                    await area.translate(id, { x: pos.x + dx, y: pos.y + dy });
                }
            }
        }

        AreaExtensions.zoomAt(area, editor.getNodes());
    });
}
