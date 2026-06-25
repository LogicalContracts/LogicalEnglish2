import * as React from 'react';
import { NodeEditor, GetSchemes, ClassicPreset } from 'rete';
import { AreaPlugin, AreaExtensions } from 'rete-area-plugin';
import { ConnectionPlugin, Presets as ConnectionPresets } from 'rete-connection-plugin';
import { ReactPlugin, Presets, ReactArea2D } from 'rete-react-plugin';
import { AutoArrangePlugin, Presets as ArrangePresets, ArrangeAppliers } from 'rete-auto-arrange-plugin';
import { createRoot } from 'react-dom/client';

const { RefSocket, Socket, useConnection } = Presets.classic;

type Schemes = GetSchemes<
    ClassicPreset.Node,
    ClassicPreset.Connection<ClassicPreset.Node, ClassicPreset.Node>
>;
type AreaExtra = ReactArea2D<Schemes>;

const PRESET_COLORS = [
    '#4caf50', // Green
    '#2196f3', // Blue
    '#ff9800', // Orange
    '#9c27b0', // Purple
    '#e91e63', // Pink
    '#00bcd4', // Cyan
    '#ff5722', // Deep Orange
    '#3f51b5', // Indigo
    '#009688', // Teal
    '#673ab7', // Deep Purple
    '#8bc34a', // Light Green
    '#ffc107', // Amber
    '#03a9f4', // Light Blue
    '#e040fb', // Magenta
    '#00e676', // Bright Green
    '#ff1744', // Bright Red
];

const templateColors = new Map<string, string>();

function getPredicateTemplate(tokens: any[]): string {
    if (!tokens || tokens.length === 0) return '';
    return tokens.map(t => t.kind === 'var' ? '*' : t.text).join(' ');
}

// A predicate template ("* smokes", "* is a parent of *") as a regex that matches
// any instance of it ("bob smokes", "alice is a parent of bob").
function templateToRegex(template: string): RegExp | null {
    if (!template) return null;
    const escaped = template
        .split('*')
        .map(part => part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
        .join('.+');
    try { return new RegExp('^' + escaped + '$'); } catch { return null; }
}

// The rule (from gameData.rules) whose head predicate would prove `literal`
// (e.g. the smokes rule proves "bob smokes"). Used to anchor failure-subtree
// nodes, whose explanation literal is an instance, not a template.
function ruleProving(literal: string, rules: any[]): any {
    if (!literal) return null;
    return rules.find(r => {
        const re = templateToRegex(getPredicateTemplate(r.headTokens));
        return re && re.test(literal);
    }) || null;
}

// Identify the game node (rule/fact) an explanation node corresponds to, returning
// a stable key, or null for purely structural nodes (for-all wrappers, the NAF
// condition itself, or a leaf failure with no proving rule). Success/spine nodes
// match by source range; failure nodes match by the proving rule's predicate.
function expNodeKey(expNode: any, rules: any[], facts: any[]): string | null {
    if (!expNode) return null;
    if (typeof expNode.start === 'number' && typeof expNode.end === 'number') {
        const r = rules.find(x => x.start === expNode.start && x.end === expNode.end);
        if (r) return 'rule:' + r.id;
        const f = facts.find(x => x.start === expNode.start && x.end === expNode.end);
        if (f) return 'fact:' + f.id;
    }
    if (expNode.type === 'failure') {
        const r = ruleProving(expNode.literal, rules);
        if (r) return 'rule:' + r.id;
    }
    return null;
}

// True if reconstructing the explanation would use some game node more than once
// (so the clone tool is needed) — e.g. the smokes rule appears twice in a failure
// subtree.
function explanationNeedsCloning(explanation: any, rules: any[], facts: any[]): boolean {
    const counts = new Map<string, number>();
    const visit = (node: any) => {
        if (Array.isArray(node)) { node.forEach(visit); return; }
        if (!node || typeof node !== 'object') return;
        const key = expNodeKey(node, rules, facts);
        if (key) {
            const n = (counts.get(key) || 0) + 1;
            counts.set(key, n);
        }
        if (Array.isArray(node.children)) node.children.forEach(visit);
    };
    visit(explanation);
    for (const n of counts.values()) if (n > 1) return true;
    return false;
}

class FactNode extends ClassicPreset.Node {
    width = 220;
    height = 60;
    public sourceLoc?: { start: number, end: number };
    public templateId: string;
    public tokens: any[];
    public complete: boolean = false;
    public failing: boolean = false;
    
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
    // Once the query is connected to a proof its variables get bound, so show the
    // bound answer (e.g. "bob is happy") rather than the interrogative label.
    public bound: boolean = false;
    
    constructor(public label: string, public color: string) {
        super(label);
        this.type = 'query';
        this.addInput('in', new ClassicPreset.Input(new ClassicPreset.Socket('query-socket')));
    }
    type: string;
}

class FailNode extends ClassicPreset.Node {
    width = 220;
    height = 60;
    public templateId: string = 'fail';
    public tokens: any[] = [];
    public clash: boolean = false;
    public complete: boolean = false;

    constructor(public label: string, public color: string) {
        super(label);
        this.type = 'fail';
        // Output connects up into a rule body condition (a NAF condition).
        this.addOutput('out', new ClassicPreset.Output(new ClassicPreset.Socket('socket')));
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
    public bodyNaf: number[];
    public bodyForall: any[];
    public bodyRanges: any[];
    public forallIndexSet: Set<number>;
    public clash: boolean = false;
    public complete: boolean = false;
    public failing: boolean = false;
    // When applied in failing mode, the bound instance of the head (e.g. "bob
    // smokes") taken from the explanation spine — the failure edges aren't unified,
    // so the binding comes from the explanation rather than the backend.
    public boundHead: string | null = null;
    // In failing mode, the bound instance of each body condition (index -> literal,
    // e.g. 0 -> "a creature is a parent of bob"), also from the explanation spine.
    public boundBody: { [i: number]: string } | null = null;
    // Per-negation bound inner goal reported by the backend: [{index, goal, ground}].
    // Used to reject a "not the case" link whose connected failing rule denotes a
    // different goal than this rule's bindings actually negate.
    public bodyNafInner: any[] = [];

    constructor(public rule: any, sourceLoc?: { start: number, end: number }) {
        super('');
        this.type = 'rule';
        this.templateId = rule.id;
        this.headTokens = rule.headTokens;
        this.bodyTokens = rule.bodyTokens;
        this.bodyNaf = Array.isArray(rule.bodyNaf) ? rule.bodyNaf : [];
        this.bodyForall = Array.isArray(rule.bodyForall) ? rule.bodyForall : [];
        this.bodyRanges = Array.isArray(rule.bodyRanges) ? rule.bodyRanges : [];
        this.forallIndexSet = new Set(this.bodyForall.map((m: any) => m.index));
        this.sourceLoc = sourceLoc;
        const socket = new ClassicPreset.Socket('socket');
        this.addOutput('out', new ClassicPreset.Output(socket));
        if (rule.body) {
            rule.body.forEach((_cond: string, i: number) => {
                if (this.forallIndexSet.has(i)) {
                    // A "for all cases in which <Cond> it is the case that <Cons>"
                    // condition exposes two sub-sockets: -0 for the Cond, -1 for
                    // the Cons.
                    this.addInput(`in-${i}-0`, new ClassicPreset.Input(socket));
                    this.addInput(`in-${i}-1`, new ClassicPreset.Input(socket));
                } else {
                    this.addInput(`in-${i}`, new ClassicPreset.Input(socket));
                }
            });
        }
    }
    type: string;
    forallMeta(i: number): any {
        return this.bodyForall.find((m: any) => m.index === i);
    }
}

function renderTokens(tokens: any[]) {
    if (!tokens) return '';
    return tokens.map(t => t.text).join(' ');
}

function CustomNode(props: any) {
    const { data, emit } = props;
    const modeToggle = document.getElementById('mode-toggle') as HTMLInputElement;
    // Checkbox checked => Child Mode (hide text); unchecked => Adult Mode (show text).
    const isAdultMode = !modeToggle?.checked;

    if (data.type === 'fail') {
        // Generic FAIL node: a stop sign (child mode) / "FAIL" (adult mode)
        // that satisfies a negation-as-failure ("it is not the case that ...")
        // condition when connected to it.
        data.width = 120;
        data.height = 120;
        const bg = data.clash ? '#b71c1c' : '#d32f2f';
        return React.createElement('div', {
            className: `le-node fail-node ${data.selected ? 'selected' : ''} ${data.clash ? 'clash' : ''} ${data.complete ? 'complete' : ''}`,
            style: {
                position: 'relative',
                width: '100px',
                height: '100px',
                background: bg,
                // Octagon (stop sign) shape.
                clipPath: 'polygon(30% 0%, 70% 0%, 100% 30%, 100% 70%, 70% 100%, 30% 100%, 0% 70%, 0% 30%)',
                border: data.selected ? '3px solid #0e639c' : 'none',
                boxShadow: '0 4px 6px rgba(0,0,0,0.3)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#fff',
                fontWeight: 'bold',
                fontSize: isAdultMode ? '18px' : '16px',
                textAlign: 'center'
            },
            title: 'FAIL: satisfies an "it is not the case that ..." condition'
        },
            isAdultMode ? 'FAIL' : 'STOP',
            React.createElement('div', {
                style: { position: 'absolute', left: '50%', top: '0px', transform: 'translate(-50%, -50%)' }
            }, React.createElement(RefSocket, {
                style: SOCKET_HIT_STYLE, name: 'output-socket', emit, side: 'output', nodeId: data.id, socketKey: 'out', payload: data.outputs['out']?.socket
            }))
        );
    }

    if (data.type === 'rule') {
        const headTemplate = getPredicateTemplate(data.headTokens) || data.rule.head;
        const headPredicateColor = templateColors.get(headTemplate) || '#ff9800';
        // A rule applied in "failing mode" (under a negation): it shows WHY the
        // goal fails, so it is tinted red and only its one failing condition needs
        // to be connected.
        const headColor = data.failing ? '#7a2e2e'
            : (data.clash ? '#f44336' : (data.complete ? '#4caf50' : (isAdultMode ? '#333' : headPredicateColor)));
        const textColor = isAdultMode ? '#fff' : 'transparent';
        
        const bodyCount = data.rule.body ? data.rule.body.length : 0;
        const nodeWidth = Math.max(220, bodyCount * 220);
        data.width = nodeWidth;
        data.height = bodyCount > 0 ? 180 : 80;
        
        const headText = (data.failing && data.boundHead)
            ? data.boundHead
            : (renderTokens(data.headTokens) || data.rule.head);

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
                    style: { position: 'absolute', left: '50%', top: '0px', transform: 'translate(-50%, -50%)' }
                }, React.createElement(RefSocket, {
                    style: SOCKET_HIT_STYLE, name: 'output-socket', emit, side: 'output', nodeId: data.id, socketKey: 'out', payload: data.outputs['out']?.socket
                }))
            ),

            bodyCount > 0 && React.createElement('div', {
                style: { display: 'flex', justifyContent: 'center', gap: '20px', width: '100%', zIndex: 1 }
            }, data.rule.body.map((cond: string, i: number) => {
                const isForall = data.forallIndexSet && data.forallIndexSet.has(i);
                const isNaf = Array.isArray(data.bodyNaf) && data.bodyNaf.includes(i);
                const condText = (data.failing && data.boundBody && data.boundBody[i])
                    ? data.boundBody[i]
                    : (renderTokens(data.bodyTokens[i]) || cond);
                const condTemplate = getPredicateTemplate(data.bodyTokens[i]) || cond;
                const condPredicateColor = templateColors.get(condTemplate) || '#ffeb3b';
                const bodyColor = data.complete ? '#81c784' : (isAdultMode ? '#333' : condPredicateColor);

                if (isForall) {
                    // A "for all cases in which <Cond> it is the case that <Cons>"
                    // condition: render two stacked sub-rows, each with its own
                    // link socket (sub 0 = the condition, sub 1 = the consequence).
                    const meta = data.rule.bodyForall.find((m: any) => m.index === i) || {};
                    const condLE = renderTokens(meta.condTokens) || meta.condLE || '';
                    const consLE = renderTokens(meta.consTokens) || meta.consLE || '';
                    const subRow = (subIdx: number, label: string, text: string) =>
                        React.createElement('div', {
                            key: subIdx,
                            style: { position: 'relative', marginTop: subIdx === 1 ? '14px' : '0' }
                        },
                            isAdultMode ? React.createElement('div', {
                                style: { fontSize: '10px', opacity: 0.8 }
                            }, label) : '',
                            isAdultMode ? text : '',
                            React.createElement('div', {
                                style: { position: 'absolute', left: '50%', bottom: '-10px', transform: 'translate(-50%, 50%)' }
                            }, React.createElement(RefSocket, {
                                style: SOCKET_HIT_STYLE, name: 'input-socket', emit, side: 'input',
                                nodeId: data.id, socketKey: `in-${i}-${subIdx}`, payload: data.inputs[`in-${i}-${subIdx}`]?.socket
                            }))
                        );
                    return React.createElement('div', {
                        key: i,
                        style: {
                            position: 'relative', background: bodyColor, color: textColor,
                            padding: '10px 10px 18px', borderRadius: '8px', width: '200px',
                            textAlign: 'center', boxShadow: '0 4px 6px rgba(0,0,0,0.3)',
                            border: isAdultMode ? '1px dashed #888' : 'none'
                        },
                        title: !isAdultMode ? condText : 'for all cases'
                    },
                        subRow(0, 'for all cases in which', condLE),
                        subRow(1, 'it is the case that', consLE)
                    );
                }

                return React.createElement('div', {
                    key: i,
                    style: {
                        position: 'relative', background: bodyColor, color: textColor,
                        padding: '10px', borderRadius: '8px', width: '200px',
                        textAlign: 'center', boxShadow: '0 4px 6px rgba(0,0,0,0.3)',
                        border: isAdultMode ? (isNaf ? '1px dashed #e57373' : '1px solid #444') : 'none'
                    },
                    title: !isAdultMode ? condText : (isNaf ? 'negation: connect the rule that would prove it, or a FAIL node' : '')
                },
                    isAdultMode ? condText : '',
                    React.createElement('div', {
                        style: { position: 'absolute', left: '50%', bottom: '0px', transform: 'translate(-50%, 50%)' }
                    }, React.createElement(RefSocket, {
                        style: SOCKET_HIT_STYLE, name: 'input-socket', emit, side: 'input', nodeId: data.id, socketKey: `in-${i}`, payload: data.inputs[`in-${i}`]?.socket
                    }))
                );
            })),
            
            bodyCount > 0 && React.createElement('svg', {
                style: { position: 'absolute', top: '0', left: '0', width: '100%', height: '100%', pointerEvents: 'none', zIndex: 0 }
            }, 
                React.createElement('defs', null,
                    React.createElement('marker', {
                        id: `arrowhead-internal-${data.id}`, markerWidth: '10', markerHeight: '7', refX: '9', refY: '3.5', orient: 'auto'
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
                        stroke: data.complete ? '#2e7d32' : '#888', strokeWidth: '2', fill: 'none', markerEnd: `url(#arrowhead-internal-${data.id})`
                    });
                })
            )
        );
    } else {
        // Fact or Query
        // Query nodes show the bound answer (e.g. "bob is happy") once connected to
        // a proof; otherwise the interrogative label (e.g. "which dragon is happy").
        const labelText = data.type === 'query'
            ? (data.bound ? (renderTokens(data.tokens) || data.label) : (data.label || renderTokens(data.tokens)))
            : (data.type === 'fact' ? (renderTokens(data.tokens) || data.label) : data.label);
        const template = getPredicateTemplate(data.tokens) || labelText;
        const predicateColor = templateColors.get(template) || data.color;
        
        const bgColor = data.failing ? '#7a2e2e'
            : (data.clash ? '#f44336' : (data.complete ? '#4caf50' : (isAdultMode ? '#333' : predicateColor)));
        const textColor = isAdultMode ? '#fff' : 'transparent';
        data.width = 220;
        data.height = 60;
        
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
                style: { position: 'absolute', left: '50%', top: '0px', transform: 'translate(-50%, -50%)' }
            }, React.createElement(RefSocket, {
                style: SOCKET_HIT_STYLE, name: 'output-socket', emit, side: 'output', nodeId: data.id, socketKey: 'out', payload: data.outputs['out']?.socket
            })),

            data.type === 'query' && React.createElement('div', {
                style: { position: 'absolute', left: '50%', bottom: '0px', transform: 'translate(-50%, 50%)' }
            }, React.createElement(RefSocket, {
                style: SOCKET_HIT_STYLE, name: 'input-socket', emit, side: 'input', nodeId: data.id, socketKey: 'in', payload: data.inputs['in']?.socket
            }))
        );
    }
}

// Size of the (mostly transparent) square that actually receives pointer/touch
// events, and the size of the visible dot centered inside it.
//
// IMPORTANT: the element the connection plugin registers for hit-testing is the
// <span> that rete-react-plugin's RefSocket/RefComponent renders (it caches that
// span and matches it against document.elementsFromPoint). A <span> is
// display:inline and shrink-wraps, so enlarging an inner div does NOT enlarge
// the grabbable area. We therefore size the span itself via SOCKET_HIT_STYLE,
// which RefSocket forwards onto the span as `style`. The big square lets a
// fingertip grab a connector on touch devices (iPad); without it the touch
// misses the tiny span and the whole block gets dragged/selected instead.
const SOCKET_HIT_SIZE = 40;
const SOCKET_DOT_SIZE = 16;

// Forwarded by RefSocket onto its <span> (the registered, hit-tested element).
const SOCKET_HIT_STYLE = {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    width: `${SOCKET_HIT_SIZE}px`,
    height: `${SOCKET_HIT_SIZE}px`,
    cursor: 'pointer',
    touchAction: 'none'
};

function CustomSocket(props: any) {
    const { data } = props;
    const isQuery = data.name === 'query-socket';

    // Only the small visible dot; it must not eat the pointer event, so the
    // registered <span> parent is what document.elementsFromPoint returns.
    return React.createElement('div', {
        style: {
            width: `${SOCKET_DOT_SIZE}px`,
            height: `${SOCKET_DOT_SIZE}px`,
            boxSizing: 'border-box',
            pointerEvents: 'none',
            ...(isQuery
                ? { background: '#e2b93d', border: '2px solid #fff', transform: 'rotate(45deg)' }
                : { background: '#fff', border: '2px solid #333', borderRadius: '50%' })
        }
    });
}

function CustomConnection(props: any) {
    const { start, end, path: defaultPath } = useConnection();
    const label: string = props?.data?.label || '';
    // Unique marker id per connection: many connections each render their own
    // <defs><marker> and duplicate DOM ids make url(#id) references unreliable.
    const markerId = React.useMemo(
        () => `arrowhead-${Math.random().toString(36).slice(2)}`, []);

    // While the endpoints aren't known yet (e.g. mid-drag), fall back to the
    // preset's path inside a full-area SVG.
    if (!start || !end) {
        if (!defaultPath) return null;
        return React.createElement('svg',
            { width: 1, height: 1, overflow: 'visible',
              style: { overflow: 'visible', position: 'absolute', pointerEvents: 'none', left: 0, top: 0 } },
            React.createElement('path', {
                d: defaultPath, fill: 'none', stroke: 'steelblue', strokeWidth: '3px'
            })
        );
    }

    // Cubic bezier from the output (start) up to the input (end).
    const c1x = start.x, c1y = start.y - 50;
    const c2x = end.x,   c2y = end.y + 50;

    // Size and position the SVG to the curve's bounding box (plus a margin for
    // stroke width and the arrowhead). This avoids a 0x0 SVG relying on
    // `overflow: visible`, which Chromium on Windows often fails to paint.
    const margin = 14;
    const minX = Math.min(start.x, end.x, c1x, c2x) - margin;
    const minY = Math.min(start.y, end.y, c1y, c2y) - margin;
    const maxX = Math.max(start.x, end.x, c1x, c2x) + margin;
    const maxY = Math.max(start.y, end.y, c1y, c2y) + margin;
    const width = Math.max(1, maxX - minX);
    const height = Math.max(1, maxY - minY);

    // Path expressed in the SVG's local coordinate space.
    const path = `M ${start.x - minX} ${start.y - minY} ` +
                 `C ${c1x - minX} ${c1y - minY}, ${c2x - minX} ${c2y - minY}, ` +
                 `${end.x - minX} ${end.y - minY}`;

    return React.createElement(
        'svg',
        {
            width, height, overflow: 'visible',
            style: {
                position: 'absolute',
                left: `${minX}px`,
                top: `${minY}px`,
                width: `${width}px`,
                height: `${height}px`,
                overflow: 'visible',
                pointerEvents: 'none'
            }
        },
        React.createElement(
            'defs',
            null,
            React.createElement(
                'marker',
                {
                    id: markerId,
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
            stroke: label ? '#e57373' : 'steelblue',
            strokeWidth: '3px',
            strokeDasharray: label ? '6 4' : undefined,
            markerEnd: `url(#${markerId})`
        }),
        // Optional edge label (e.g. "not the case" on a negation link), drawn at
        // the curve's midpoint (cubic Bezier at t = 0.5).
        label && (() => {
            const mx = 0.125 * start.x + 0.375 * c1x + 0.375 * c2x + 0.125 * end.x - minX;
            const my = 0.125 * start.y + 0.375 * c1y + 0.375 * c2y + 0.125 * end.y - minY;
            const w = label.length * 6.5 + 10;
            return React.createElement('g', { key: 'label' },
                React.createElement('rect', {
                    x: mx - w / 2, y: my - 9, width: w, height: 18, rx: 4,
                    fill: '#3a1f1f', stroke: '#e57373', strokeWidth: '1'
                }),
                React.createElement('text', {
                    x: mx, y: my + 4, textAnchor: 'middle',
                    fill: '#ffcdd2', fontSize: '11px', fontStyle: 'italic'
                }, label)
            );
        })()
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

    // Clone-tool state (wired further below; declared here so the answer picker can
    // refresh the tool's visibility when the chosen answer changes).
    let cloneMode = false;
    let refreshCloneToolVisibility: () => void = () => {};

    // Answer picker: a query can have several answers with very different proofs
    // (e.g. "which dragon is happy" → bob, vacuously; alice, via a failure
    // subtree). Only the explanation (the solution spine) differs between answers,
    // so switching just re-fetches the chosen answer's explanation. Shown only
    // when there is more than one answer.
    const answers: string[] = Array.isArray(gameData.answers) ? gameData.answers : [];
    if (answers.length > 1) {
        const picker = document.getElementById('answer-picker') as HTMLElement | null;
        const select = document.getElementById('answer-select') as HTMLSelectElement | null;
        if (picker && select) {
            select.innerHTML = '';
            answers.forEach((label, i) => {
                const opt = document.createElement('option');
                opt.value = String(i);
                opt.textContent = label;
                select.appendChild(opt);
            });
            select.value = String(gameData.answerIndex || 0);
            picker.style.display = '';
            select.addEventListener('change', async () => {
                const idx = parseInt(select.value);
                try {
                    const req = gameData.request
                        ? { ...gameData.request }
                        : JSON.parse(localStorage.getItem('le_proof_game_request') || 'null');
                    if (!req) { console.error('No stored request to switch answers'); return; }
                    req.answerIndex = idx;
                    const res = await fetch('/leapi', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify(req)
                    }).then(r => r.json());
                    if (res && res.gameData && res.gameData.explanation !== undefined) {
                        // Swap in the new answer's spine; the rules/facts/nodes are
                        // answer-independent and stay as they are.
                        gameData.explanation = res.gameData.explanation;
                        gameData.answerIndex = idx;
                        refreshCloneToolVisibility();
                    }
                } catch (err) {
                    console.error('Answer switch failed:', err);
                }
            });
        }
    }

    // Populate template colors
    templateColors.clear();
    const predicateTemplates = new Set<string>();

    if (gameData.queryTokens) {
        const t = getPredicateTemplate(gameData.queryTokens);
        if (t) predicateTemplates.add(t);
    } else if (gameData.query) {
        predicateTemplates.add(gameData.query);
    }

    if (gameData.rules) {
        for (const rule of gameData.rules) {
            if (rule.headTokens) {
                const t = getPredicateTemplate(rule.headTokens);
                if (t) predicateTemplates.add(t);
            }
            if (rule.bodyTokens) {
                for (const tokens of rule.bodyTokens) {
                    const t = getPredicateTemplate(tokens);
                    if (t) predicateTemplates.add(t);
                }
            }
        }
    }

    if (gameData.facts) {
        for (const fact of gameData.facts) {
            if (fact.factTokens) {
                const t = getPredicateTemplate(fact.factTokens);
                if (t) predicateTemplates.add(t);
            }
        }
    }

    let colorIndex = 0;
    for (const template of predicateTemplates) {
        const color = PRESET_COLORS[colorIndex % PRESET_COLORS.length];
        templateColors.set(template, color);
        colorIndex++;
    }

    // Populate legend dialog content
    const legendContent = document.getElementById('legend-content');
    if (legendContent) {
        legendContent.innerHTML = '';
        templateColors.forEach((color, template) => {
            const item = document.createElement('div');
            item.className = 'legend-item';
            
            const colorBox = document.createElement('div');
            colorBox.className = 'legend-color-box';
            colorBox.style.backgroundColor = color;
            
            const text = document.createElement('span');
            text.textContent = template;
            
            item.appendChild(colorBox);
            item.appendChild(text);
            legendContent.appendChild(item);
        });
    }

    // Set up legend dialog event listeners
    document.getElementById('btn-legend')?.addEventListener('click', () => {
        const dialog = document.getElementById('legend-dialog');
        if (dialog) {
            if (dialog.style.display === 'none') {
                dialog.style.display = 'flex';
            } else {
                dialog.style.display = 'none';
            }
        }
    });

    document.getElementById('btn-legend-close')?.addEventListener('click', () => {
        const dialog = document.getElementById('legend-dialog');
        if (dialog) {
            dialog.style.display = 'none';
        }
    });

    // Make legend dialog draggable
    const legendDialog = document.getElementById('legend-dialog');
    const legendHeader = legendDialog?.querySelector('.legend-header') as HTMLElement;
    if (legendDialog && legendHeader) {
        let isDragging = false;
        let startX = 0;
        let startY = 0;
        let initialLeft = 0;
        let initialTop = 0;

        legendHeader.addEventListener('mousedown', (e) => {
            isDragging = true;
            startX = e.clientX;
            startY = e.clientY;
            const rect = legendDialog.getBoundingClientRect();
            initialLeft = rect.left;
            initialTop = rect.top;
            e.preventDefault();
        });

        document.addEventListener('mousemove', (e) => {
            if (!isDragging) return;
            const dx = e.clientX - startX;
            const dy = e.clientY - startY;
            legendDialog.style.left = `${initialLeft + dx}px`;
            legendDialog.style.top = `${initialTop + dy}px`;
            legendDialog.style.right = 'auto';
        });

        document.addEventListener('mouseup', () => {
            isDragging = false;
        });
    }

    let wasComplete = false;
    let wasClash = false;

    // The explanation failure node (the spine root) for a negation whose condition
    // spans [start,end]; null when the current answer's explanation has no failure
    // subtree there.
    function expFailureSpineFor(start: number, end: number): any {
        let found: any = null;
        const visit = (node: any) => {
            if (found) return;
            if (Array.isArray(node)) { node.forEach(visit); return; }
            if (!node || typeof node !== 'object') return;
            if (node.naf === true && node.start === start && node.end === end) {
                found = (node.children || []).find((c: any) => c.type === 'failure') || null;
                return;
            }
            (node.children || []).forEach(visit);
        };
        visit(gameData.explanation);
        return found;
    }


    function checkCompletion() {
        const nodes = editor.getNodes();
        const connections = editor.getConnections();
        const queryNode = nodes.find(n => n instanceof QueryNode) as QueryNode;

        if (!queryNode) return false;

        const fragmentNodes = new Set<string>();
        // Cycle-safe memoization for isComplete: a node currently being evaluated
        // (in `computing`) that is reached again means the connections form a cycle —
        // it cannot justify its own completeness, so it is treated as incomplete
        // rather than vacuously complete. `completeCache` memoizes settled results.
        const computing = new Set<string>();
        const completeCache = new Map<string, boolean>();

        function markFragment(nodeId: string) {
            if (fragmentNodes.has(nodeId)) return;
            fragmentNodes.add(nodeId);
            connections.filter(c => c.target === nodeId).forEach(c => markFragment(c.source));
        }

        // Structural validation of a failure subtree against the explanation spine:
        // the node feeding the socket must be the rule that would prove the failing
        // goal (in failing mode) with its one failing condition connected, recursing
        // down to a FAIL leaf — or a FAIL node for a leaf failure.
        function failureMatches(sourceNodeId: string, expFail: any): boolean {
            if (!expFail) return false;
            const node = editor.getNode(sourceNodeId) as any;
            if (!node) return false;
            const provRule = ruleProving(expFail.literal, gameData.rules || []);
            const expChild = (expFail.children || []).find((c: any) => c.type === 'failure');
            if (!provRule || !expChild) {
                // Leaf failure (nothing could prove it): a FAIL node represents it.
                return node instanceof FailNode;
            }
            if (!(node instanceof RuleNode)) return false;
            if (node.templateId !== provRule.id) return false;
            const idx = (node.bodyRanges || []).findIndex((r: any) => r.start === expChild.start && r.end === expChild.end);
            if (idx < 0) return false;
            const conn = connections.find(c => c.target === node.id && c.targetInput === `in-${idx}`);
            if (!conn) return false;
            return failureMatches(conn.source, expChild);
        }

        function isComplete(nodeId: string): boolean {
            const cached = completeCache.get(nodeId);
            if (cached !== undefined) return cached;
            if (computing.has(nodeId)) return false;   // cycle: cannot prove itself
            computing.add(nodeId);
            const result = computeComplete(nodeId);
            computing.delete(nodeId);
            completeCache.set(nodeId, result);
            return result;
        }

        function computeComplete(nodeId: string): boolean {
            const node = editor.getNode(nodeId);
            if (!node) return false;
            fragmentNodes.add(nodeId);

            if (node instanceof FactNode) return true;
            if (node instanceof FailNode) return true;

            if (node instanceof QueryNode) {
                const conn = connections.find(c => c.target === nodeId);
                if (!conn) return false;
                return isComplete(conn.source);
            }

            if (node instanceof RuleNode) {
                const bodyCount = node.rule.body ? node.rule.body.length : 0;
                for (let i = 0; i < bodyCount; i++) {
                    if (node.forallIndexSet.has(i)) {
                        // The condition socket decides which: a FAIL means the
                        // universal is VACUOUS (no cases) and the consequence is not
                        // required; anything else is a witnessing CASE, which must be
                        // proven AND its consequence proven. (Independent of which
                        // answer's explanation is selected, so it can't be fooled.)
                        const condConn = connections.find(c => c.target === nodeId && c.targetInput === `in-${i}-0`);
                        if (!condConn) return false;
                        const condSrc = editor.getNode(condConn.source);
                        if (condSrc instanceof FailNode) {
                            markFragment(condConn.source);   // vacuous: no cases
                        } else {
                            if (!isComplete(condConn.source)) return false;
                            const consConn = connections.find(c => c.target === nodeId && c.targetInput === `in-${i}-1`);
                            if (!consConn) return false;
                            if (!isComplete(consConn.source)) return false;
                        }
                    } else if (node.bodyNaf.includes(i)) {
                        // A negation: its failure subtree must reproduce the
                        // explanation's failure spine (structural match). When the
                        // current answer has no such spine, any connection (e.g. a
                        // FAIL node) suffices.
                        const conn = connections.find(c => c.target === nodeId && c.targetInput === `in-${i}`);
                        if (!conn) return false;
                        // The connected failing rule must denote the goal this rule's
                        // bindings actually negate (not, say, "bob smokes" under "it is
                        // not the case that alice smokes").
                        if (!nafLinkConsistent(node, i, editor.getNode(conn.source))) return false;
                        const range = node.bodyRanges[i];
                        const spine = range ? expFailureSpineFor(range.start, range.end) : null;
                        if (spine && !failureMatches(conn.source, spine)) return false;
                        markFragment(conn.source);
                    } else {
                        const conn = connections.find(c => c.target === nodeId && c.targetInput === `in-${i}`);
                        if (!conn) return false;
                        if (!isComplete(conn.source)) return false;
                    }
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

    // True if `targetInput` of `targetNode` is a negation ("it is not the case
    // that ...") socket.
    function isNafSocket(targetNode: any, targetInput: string): boolean {
        if (!(targetNode instanceof RuleNode) || typeof targetInput !== 'string') return false;
        const parts = targetInput.split('-');
        return parts.length === 2 && targetNode.bodyNaf.includes(parseInt(parts[1]));
    }

    // A "not the case" link is consistent only if the connected failing rule
    // denotes the SAME goal the parent's bindings actually negate. The parent
    // reports its bound inner goal (e.g. "alice smokes") in bodyNafInner[i]; the
    // connected failing rule carries its goal as boundHead (e.g. "bob smokes",
    // taken from the selected answer's spine). When the parent's inner goal is
    // ground and the two disagree, the link is invalid (e.g. using "bob smokes"
    // to discharge "it is not the case that alice smokes").
    function normalizeGoal(s: string): string {
        return (s || '').trim().toLowerCase().replace(/\s+/g, ' ');
    }
    function nafLinkConsistent(parent: any, i: number, source: any): boolean {
        if (!(source instanceof RuleNode)) return true;   // FAIL leaves checked elsewhere
        const info = (parent.bodyNafInner || []).find((x: any) => x.index === i);
        if (!info || !info.ground) return true;           // parent's negated goal not pinned yet
        const head = source.boundHead;
        if (!head) return true;                           // not in failing mode / unlabelled
        return normalizeGoal(head) === normalizeGoal(info.goal);
    }
    // Node ids on either end of an inconsistent negation link.
    function invalidNegationLinks(): Set<string> {
        const bad = new Set<string>();
        for (const c of editor.getConnections()) {
            const target = editor.getNode(c.target);
            if (target instanceof RuleNode && isNafSocket(target, c.targetInput)) {
                const i = parseInt((c.targetInput as string).split('-')[1]);
                const source = editor.getNode(c.source);
                if (!nafLinkConsistent(target, i, source)) { bad.add(c.target); bad.add(c.source); }
            }
        }
        return bad;
    }

    // Nodes in a failure subtree: a node whose output reaches a negation socket,
    // directly or through other failing nodes.
    function computeFailing(): Set<string> {
        const conns = editor.getConnections();
        const failing = new Set<string>();
        for (const c of conns) {
            if (isNafSocket(editor.getNode(c.target), c.targetInput)) failing.add(c.source);
        }
        let changed = true;
        while (changed) {
            changed = false;
            for (const c of conns) {
                if (failing.has(c.target) && !failing.has(c.source)) { failing.add(c.source); changed = true; }
            }
        }
        return failing;
    }

    // A failing rule shows its bound head (e.g. "bob smokes") taken from the
    // explanation spine, since failure edges are not unified by the backend. Walk
    // each negation socket's failure subtree and label the rules along it.
    function updateFailingLabels() {
        const conns = editor.getConnections();
        editor.getNodes().forEach(n => {
            if ((n as any).boundHead || (n as any).boundBody) {
                (n as any).boundHead = null;
                (n as any).boundBody = null;
                area.update('node', n.id);
            }
        });
        const assign = (sourceNodeId: string, expFail: any) => {
            const node = editor.getNode(sourceNodeId) as any;
            if (!node || !expFail || !(node instanceof RuleNode)) return;
            node.boundHead = expFail.literal;
            // Bind each body condition shown on the failing card to the explanation's
            // instance (e.g. body[0] of "bob smokes" becomes "a creature is a parent
            // of bob"), matching explanation children to body conditions by range.
            const boundBody: { [i: number]: string } = {};
            (expFail.children || []).forEach((ch: any) => {
                if (!ch || typeof ch.start !== 'number') return;
                const bi = (node.bodyRanges || []).findIndex((r: any) => r.start === ch.start && r.end === ch.end);
                if (bi >= 0) boundBody[bi] = ch.literal;
            });
            node.boundBody = boundBody;
            area.update('node', node.id);
            const expChild = (expFail.children || []).find((c: any) => c.type === 'failure');
            if (!expChild) return;
            const idx = (node.bodyRanges || []).findIndex((r: any) => r.start === expChild.start && r.end === expChild.end);
            const conn = conns.find(c => c.target === node.id && c.targetInput === `in-${idx}`);
            if (conn) assign(conn.source, expChild);
        };
        for (const c of conns) {
            const target = editor.getNode(c.target) as any;
            if (target instanceof RuleNode && isNafSocket(target, c.targetInput)) {
                const i = parseInt(c.targetInput.split('-')[1]);
                const range = target.bodyRanges[i];
                const spine = range ? expFailureSpineFor(range.start, range.end) : null;
                if (spine) assign(c.source, spine);
            }
        }
    }

    // Each unification round gets a sequence number; since the server round-trip is
    // async and a round runs per connection change (Show Proof adds several in a
    // row), a stale earlier reply must not clobber the latest, fuller binding.
    let unifySeq = 0;
    async function updateUnification() {
        const mySeq = ++unifySeq;
        const nodes = editor.getNodes();
        const connections = editor.getConnections();

        // The connection set just changed, so completeness is unknown until THIS
        // round's authoritative result returns. Clear any green now: otherwise a
        // stale "complete" state could survive a round that is superseded
        // (mySeq !== unifySeq), clashes, errors, or never returns — leaving an
        // invalid proof (e.g. "bob is a dragon" feeding the alice-bound "the
        // creature is a dragon") painted as solved.
        nodes.forEach(n => {
            if ((n as any).complete) { (n as any).complete = false; area.update('node', n.id); }
        });

        // Failure-subtree nodes/edges are validated structurally against the
        // explanation (see checkCompletion), not by unification — so tint them and
        // keep their edges out of the unify payload (a FAIL node on a positive
        // condition, etc., would otherwise clash).
        const failing = computeFailing();
        nodes.forEach(n => {
            const old = (n as any).failing;
            (n as any).failing = failing.has(n.id);
            if (old !== (n as any).failing) area.update('node', n.id);
        });
        updateFailingLabels();
        // A negation link's dotted line + "not the case" label is purely structural
        // (target is a NAF socket, source is not a FAIL node), so set it now —
        // synchronously — rather than only after a successful unification round.
        // Otherwise a round that clashes, errors, or is superseded would leave a
        // manually drawn negation link rendered as an ordinary solid edge.
        updateConnectionLabels();

        const nodeSpecs = nodes.map(n => {
            if (n instanceof RuleNode) return { instanceId: n.id, templateId: n.templateId };
            if (n instanceof FactNode) return { instanceId: n.id, templateId: n.templateId };
            if (n instanceof QueryNode) return { instanceId: n.id, templateId: n.templateId };
            if (n instanceof FailNode) return { instanceId: n.id, templateId: 'fail' };
            return null;
        }).filter(n => n !== null);

        const edges = connections.map(c => {
            const source = editor.getNode(c.source);
            const target = editor.getNode(c.target);
            if (!source || !target) return null;
            // Skip failure-subtree edges (target is a negation socket or a failing
            // node) — those are validated structurally, not unified.
            if (isNafSocket(target, c.targetInput) || failing.has(c.target)) return null;
            // FAIL nodes never participate in unification (they represent a failed
            // or empty condition — a negation, or a vacuous "for all cases"); they
            // are validated structurally instead.
            if (source instanceof FailNode) return null;

            // targetInput is "in-<bodyIndex>" or, for a "for all cases" condition,
            // "in-<bodyIndex>-<subIndex>" (sub 0 = condition, sub 1 = consequence).
            let bodyIndex = 0;
            let subIndex = -1;
            if (c.targetInput.startsWith('in-')) {
                const parts = c.targetInput.split('-');
                bodyIndex = parseInt(parts[1]);
                if (parts.length > 2) subIndex = parseInt(parts[2]);
            }

            const edge: any = { child: c.source, parent: c.target, bodyIndex };
            if (subIndex >= 0) edge.subIndex = subIndex;
            return edge;
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
            // A newer unification round has superseded this one; drop the stale reply.
            if (mySeq !== unifySeq) return;

            if (res.status === 'ok') {
                res.nodes.forEach((nodeData: any) => {
                    const node = editor.getNode(nodeData.instanceId) as any;
                    if (node) {
                        node.clash = false;
                        if (node instanceof RuleNode) {
                            node.headTokens = nodeData.headTokens;
                            node.bodyTokens = nodeData.bodyTokens;
                            // Refresh the "for all cases" sub-condition tokens so a
                            // binding (e.g. "the creature" -> alice) shows there too.
                            if (Array.isArray(nodeData.bodyForall)) {
                                node.rule.bodyForall = nodeData.bodyForall;
                            }
                            node.bodyNafInner = Array.isArray(nodeData.bodyNafInner) ? nodeData.bodyNafInner : [];
                        } else if (node instanceof FactNode) {
                            node.tokens = nodeData.headTokens;
                        } else if (node instanceof QueryNode) {
                            node.tokens = nodeData.bodyTokens[0];
                            // The query is bound once something feeds its socket.
                            node.bound = connections.some(c => c.target === node.id);
                        }
                        area.update('node', node.id);
                    }
                });
                // A negation link that denotes the wrong goal (e.g. "bob smokes"
                // feeding "it is not the case that alice smokes") is a clash even
                // though the backend — which never sees failure edges — said ok.
                const badNaf = invalidNegationLinks();
                if (badNaf.size > 0) {
                    if (!wasClash) { playClashSound(); wasClash = true; }
                    nodes.forEach(n => {
                        const bad = badNaf.has(n.id);
                        if ((n as any).clash !== bad) { (n as any).clash = bad; }
                        if (bad) (n as any).complete = false;
                        area.update('node', n.id);
                    });
                    checkCompletion();
                    updateConnectionLabels();
                } else {
                    checkCompletion();
                    updateConnectionLabels();
                    wasClash = false;
                }
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

    // Label connections that are negation links — a rule/fact (not a FAIL node)
    // feeding an "it is not the case that ..." condition — with "not the case".
    function updateConnectionLabels() {
        for (const c of editor.getConnections()) {
            const target = editor.getNode(c.target) as any;
            const source = editor.getNode(c.source) as any;
            let label = '';
            if (target instanceof RuleNode && typeof c.targetInput === 'string'
                && c.targetInput.startsWith('in-')) {
                const parts = c.targetInput.split('-');
                const i = parseInt(parts[1]);
                if (parts.length === 2 && target.bodyNaf.includes(i) && !(source instanceof FailNode)) {
                    label = 'not the case';
                }
            }
            if ((c as any).label !== label) {
                (c as any).label = label;
                area.update('connection', c.id);
            }
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

    const arrange = new AutoArrangePlugin<any>();
    arrange.addPreset(ArrangePresets.classic.setup());
    area.use(arrange);

    // Smooth movement for auto-layout. Unlike a CSS transition on the node
    // transform, this animates by updating each node's logical position
    // (nodeView.position) every frame, so connection endpoints and socket
    // hit-testing stay correct while nodes move.
    const arrangeApplier = new ArrangeAppliers.TransitionApplier<any, never>({
        duration: 500,
        timingFunction: (t) => t
    });

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
        queryNode.tokens = gameData.queryTokens || [];
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

    // Add a generic FAIL node when any rule has a negation-as-failure condition.
    // A single FAIL node can be connected to every such condition.
    const hasNaf = (gameData.rules || []).some((r: any) => Array.isArray(r.bodyNaf) && r.bodyNaf.length > 0);
    if (hasNaf) {
        const failNode = new FailNode('FAIL', '#d32f2f');
        await editor.addNode(failNode);
        await area.translate(failNode.id, { x: currentX, y: factY });
        currentX += 250;
        nodes.push(failNode);
    }

    setTimeout(() => {
        AreaExtensions.zoomAt(area, editor.getNodes());
    }, 100);

    document.getElementById('btn-rearrange')?.addEventListener('click', async () => {
        await arrange.layout({ applier: arrangeApplier });
        AreaExtensions.zoomAt(area, editor.getNodes());
    });

    // Zoom controls. area.area.zoom(level, ox, oy) sets the absolute zoom level;
    // the current level is area.area.transform.k.
    document.getElementById('btn-zoom-in')?.addEventListener('click', () => {
        area.area.zoom(area.area.transform.k * 1.2, 0, 0);
    });
    document.getElementById('btn-zoom-out')?.addEventListener('click', () => {
        area.area.zoom(area.area.transform.k / 1.2, 0, 0);
    });
    document.getElementById('btn-zoom-fit')?.addEventListener('click', () => {
        AreaExtensions.zoomAt(area, editor.getNodes());
    });

    // Clone tool: duplicating a rule/fact node. Only offered when the proof needs
    // the same node more than once (e.g. a failure subtree applies one rule twice).
    async function cloneNode(orig: any) {
        let clone: any = null;
        if (orig instanceof RuleNode) clone = new RuleNode(orig.rule, orig.sourceLoc);
        else if (orig instanceof FactNode) clone = new FactNode(orig.label, orig.color, orig.templateId, orig.tokens, orig.sourceLoc);
        if (!clone) return null;
        await editor.addNode(clone);
        const pos = area.nodeViews.get(orig.id)?.position || { x: 100, y: 100 };
        await area.translate(clone.id, { x: pos.x + 40, y: pos.y + 60 });
        return clone;
    }

    const btnClone = document.getElementById('btn-clone') as HTMLElement | null;
    // Shown only when the selected answer's proof reuses a node (e.g. a failure
    // subtree applies one rule twice). Re-evaluated when the answer changes.
    refreshCloneToolVisibility = () => {
        if (!btnClone) return;
        const need = explanationNeedsCloning(gameData.explanation, gameData.rules || [], gameData.facts || []);
        btnClone.style.display = need ? '' : 'none';
        if (!need && cloneMode) {
            cloneMode = false;
            btnClone.style.background = '';
            btnClone.style.color = '';
        }
    };
    if (btnClone) {
        btnClone.addEventListener('click', () => {
            cloneMode = !cloneMode;
            btnClone.style.background = cloneMode ? '#0e639c' : '';
            btnClone.style.color = cloneMode ? '#fff' : '';
        });
    }
    refreshCloneToolVisibility();

    // A node may be deleted when it is a FAIL node, or a rule/fact that has more
    // than one instance (clones) — so at least one original always remains.
    function canDelete(node: any): boolean {
        if (node instanceof FailNode) return true;
        if (node instanceof RuleNode || node instanceof FactNode) {
            const tid = node.templateId;
            const count = editor.getNodes().filter(n =>
                (n instanceof RuleNode || n instanceof FactNode) && (n as any).templateId === tid).length;
            return count > 1;
        }
        return false;
    }
    async function removeNodeWithConnections(node: any) {
        for (const c of editor.getConnections().filter(c => c.source === node.id || c.target === node.id)) {
            await editor.removeConnection(c.id);
        }
        await editor.removeNode(node.id);
    }
    // Delete/Backspace removes the selected deletable node(s) — the way to remove a
    // clone. Ignored while a form control (the answer picker, theme select) is focused.
    document.addEventListener('keydown', async (e) => {
        if (e.key !== 'Delete' && e.key !== 'Backspace') return;
        const tag = (e.target as HTMLElement)?.tagName;
        if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA') return;
        const selected = editor.getNodes().filter(n => (n as any).selected);
        for (const n of selected) {
            if (canDelete(n)) await removeNodeWithConnections(n);
        }
    });

    // Selection logic for editor highlighting (and clone-on-click when the clone
    // tool is active).
    area.addPipe(context => {
        if (context.type === 'nodepicked') {
            const node = editor.getNode(context.data.id) as any;
            if (cloneMode && (node instanceof RuleNode || node instanceof FactNode)) {
                cloneNode(node);
                return context;
            }
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

        // True if the target node actually has the given input socket. "For all
        // cases" conditions expose `in-i-0`/`in-i-1` instead of `in-i`, which the
        // explanation-driven auto-connect does not yet address, so we skip those
        // rather than crash on a missing input.
        function hasInput(nodeId: string, key: string): boolean {
            const n = editor.getNode(nodeId) as any;
            return !!(n && n.inputs && n.inputs[key]);
        }

        // The rule/fact game node whose source range matches an explanation node.
        function matchNode(expNode: any): any {
            return nodes.find(n => !usedNodes.has(n.id)
                && (n instanceof RuleNode || n instanceof FactNode)
                && (n as any).sourceLoc?.start === expNode.start
                && (n as any).sourceLoc?.end === expNode.end);
        }

        // Connect a positive (rule/fact) explanation node into a target input,
        // then recurse into its body.
        async function connectNode(expNode: any, targetNodeId: string, targetInputKey: string) {
            if (!expNode || !hasInput(targetNodeId, targetInputKey)) return;
            const match = matchNode(expNode);
            if (!match) return;
            usedNodes.add(match.id);
            await editor.addConnection(new ClassicPreset.Connection(
                match, 'out', editor.getNode(targetNodeId) as any, targetInputKey));
            if (match instanceof RuleNode) await connectRuleBody(expNode, match);
        }

        // A game RuleNode instance for ruleId that isn't used yet, cloning one when
        // all existing instances are taken (a failure subtree can reapply a rule).
        async function acquireRuleInstance(ruleId: string): Promise<any> {
            let inst = editor.getNodes().find(n => n instanceof RuleNode
                && (n as RuleNode).templateId === ruleId && !usedNodes.has(n.id)) as any;
            if (!inst) {
                const ruleData = (gameData.rules || []).find((r: any) => r.id === ruleId);
                if (!ruleData) return null;
                inst = new RuleNode(ruleData, { start: ruleData.start, end: ruleData.end });
                await editor.addNode(inst);
            }
            return inst;
        }

        async function addFailLeaf(parentNodeId: string, inputKey: string) {
            const failNode = new FailNode('FAIL', '#d32f2f');
            await editor.addNode(failNode);
            usedNodes.add(failNode.id);
            await editor.addConnection(new ClassicPreset.Connection(
                failNode as any, 'out', editor.getNode(parentNodeId) as any, inputKey));
        }

        // Build a failure subtree from an explanation [failure] node into
        // (parentNodeId, inputKey): the proving rule in failing mode with its one
        // failing condition, recursing down to a FAIL leaf — exactly the spine.
        async function buildFailure(expFail: any, parentNodeId: string, inputKey: string) {
            if (!expFail || !hasInput(parentNodeId, inputKey)) return;
            const provRule = ruleProving(expFail.literal, gameData.rules || []);
            const expChild = (expFail.children || []).find((c: any) => c.type === 'failure');
            if (!provRule || !expChild) {
                await addFailLeaf(parentNodeId, inputKey);
                return;
            }
            const inst = await acquireRuleInstance(provRule.id);
            if (!inst) { await addFailLeaf(parentNodeId, inputKey); return; }
            usedNodes.add(inst.id);
            await editor.addConnection(new ClassicPreset.Connection(
                inst, 'out', editor.getNode(parentNodeId) as any, inputKey));
            const idx = (inst.bodyRanges || []).findIndex((r: any) => r.start === expChild.start && r.end === expChild.end);
            if (idx >= 0) await buildFailure(expChild, inst.id, `in-${idx}`);
        }

        // Connect each body condition of a matched rule (its explanation children
        // line up with the body conditions), handling "for all cases" and negation.
        async function connectRuleBody(expNode: any, ruleNode: any) {
            const children = expNode.children || [];
            for (let i = 0; i < children.length; i++) {
                const child = children[i];
                if (ruleNode.forallIndexSet && ruleNode.forallIndexSet.has(i)) {
                    // child is the "for all cases" node; connect the first case's
                    // condition (sub 0) and consequence (sub 1) sub-proofs.
                    const subs = (child && child.children) || [];
                    const condExp = subs.find((s: any) => typeof s.literal === 'string' && s.literal.startsWith('for case'));
                    const consExp = subs.find((s: any) => typeof s.literal === 'string' && s.literal.startsWith('it is true that'));
                    if (condExp || consExp) {
                        if (condExp) await connectNode(condExp, ruleNode.id, `in-${i}-0`);
                        if (consExp) await connectNode(consExp, ruleNode.id, `in-${i}-1`);
                    } else {
                        // Vacuously true (no cases): the condition has no solutions —
                        // represent it with a FAIL on the condition socket.
                        await addFailLeaf(ruleNode.id, `in-${i}-0`);
                    }
                } else if (child && child.naf) {
                    // Negation: build the failure subtree from the explanation spine
                    // (the NAF node's failure child); fall back to a FAIL leaf.
                    const spine = (child.children || []).find((c: any) => c.type === 'failure');
                    if (spine) await buildFailure(spine, ruleNode.id, `in-${i}`);
                    else await addFailLeaf(ruleNode.id, `in-${i}`);
                } else {
                    await connectNode(child, ruleNode.id, `in-${i}`);
                }
            }
        }

        await connectNode(explanation, queryNode.id, 'in');
        updateConnectionLabels();
        updateFailingLabels();

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
        const proofNodesList = Array.from(proofTreeNodes)
            .map(id => editor.getNode(id))
            .filter((n): n is NonNullable<typeof n> => !!n);
        const proofConnectionsList = editor.getConnections().filter(c => proofTreeNodes.has(c.source) && proofTreeNodes.has(c.target));

        await arrange.layout({
            applier: arrangeApplier,
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
