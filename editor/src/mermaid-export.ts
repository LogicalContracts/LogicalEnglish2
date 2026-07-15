// Mermaid text generation for LE artefacts: explanation trees ("Copy as
// Mermaid diagram" in the explanation context menu) and the source graph
// ("Copy Mermaid" in the graph window). Pure string builders — no DOM, no
// cytoscape — shared by both windows. The output is a `flowchart` pasteable
// into anything that renders Mermaid (GitHub, Obsidian, Notion, mermaid.live).

// A label inside a Mermaid quoted string: double quotes would end the string,
// so use Mermaid's HTML-entity escape (#quot;); collapse whitespace.
function esc(label: any): string {
    return String(label ?? '').replace(/"/g, '#quot;').replace(/\s+/g, ' ').trim();
}

// --- Explanation tree -> Mermaid ---------------------------------------------
// `why` is the explanation as rendered by ExplanationView: a node (or array of
// nodes) of { literal, type: 'failure'|'unknown'|other, repeated, repeatedCount,
// children }. Succeeded/failed/assumed nodes get the tree view's green/red/amber.
export function explanationToMermaid(why: any): string {
    const lines: string[] = ['flowchart TD'];
    let n = 0;
    const emit = (node: any, parentId: string | null) => {
        const id = `e${++n}`;
        let label = (node && typeof node === 'object') ? (node.literal ?? '') : node;
        if (node?.repeated) {
            const c = node.repeatedCount;
            label += (typeof c === 'number' && c > 1) ? ` (${c} repeated sub-explanations)` : ' (repeated)';
        }
        const cls = node?.type === 'failure' ? 'failure'
            : node?.type === 'unknown' ? 'unknown' : 'success';
        lines.push(`    ${id}["${esc(label)}"]:::${cls}`);
        if (parentId) lines.push(`    ${parentId} --> ${id}`);
        (node?.children ?? []).forEach((child: any) => emit(child, id));
    };
    (Array.isArray(why) ? why : [why]).forEach((w) => emit(w, null));
    lines.push('    classDef success fill:#e7f6e7,stroke:#2e7d32,color:#1b5e20');
    lines.push('    classDef failure fill:#fdecea,stroke:#c62828,color:#b71c1c');
    lines.push('    classDef unknown fill:#fff8e1,stroke:#e2a93d,color:#7a5d00');
    return lines.join('\n');
}

// --- Source graph -> Mermaid --------------------------------------------------
export interface MermaidGraphNode { id: string; type?: string; label?: string; parent?: string; }
export interface MermaidGraphEdge { source: string; target: string; type?: string; }

// Node statement in the shape the graph view uses for that type: templates as
// stadiums, facts rounded, types as diamonds, queries as hexagons, rules as
// rectangles.
function nodeStatement(id: string, node: MermaidGraphNode): string {
    const label = esc(node.label || node.id);
    switch (node.type) {
        case 'template': return `${id}(["${label}"]):::template`;
        case 'fact': return `${id}("${label}"):::fact`;
        case 'type': return `${id}{"${label}"}:::type`;
        case 'query': return `${id}{{"${label}"}}:::query`;
        case 'rule': return `${id}["${label}"]:::rule`;
        default: return `${id}["${label}"]`;
    }
}

// The graph (typically the VISIBLE elements of the graph window, so the export
// matches the current layers/scenario filter) as a Mermaid flowchart. Scenario
// compound nodes become subgraphs containing their facts; 'scopes' edges are
// skipped because that containment already expresses them.
export function graphToMermaid(nodes: MermaidGraphNode[], edges: MermaidGraphEdge[],
                               direction: 'LR' | 'TD' = 'LR'): string {
    const lines: string[] = [`flowchart ${direction}`];
    const idOf = new Map<string, string>();
    nodes.forEach((node, i) => idOf.set(node.id, `n${i}`));

    const parents = new Set(nodes.filter(n => n.parent && idOf.has(n.parent!)).map(n => n.parent!));
    const topLevel = nodes.filter(n => !parents.has(n.id) && !(n.parent && idOf.has(n.parent)));
    const childrenOf = (pid: string) => nodes.filter(n => n.parent === pid);

    for (const node of topLevel) lines.push(`    ${nodeStatement(idOf.get(node.id)!, node)}`);
    for (const node of nodes.filter(n => parents.has(n.id))) {
        lines.push(`    subgraph ${idOf.get(node.id)}["${esc(node.label || node.id)}"]`);
        for (const child of childrenOf(node.id)) lines.push(`        ${nodeStatement(idOf.get(child.id)!, child)}`);
        lines.push('    end');
    }

    for (const e of edges) {
        const s = idOf.get(e.source), t = idOf.get(e.target);
        if (!s || !t || e.type === 'scopes') continue;
        const label = esc((e.type || '').replace(/-/g, ' '));
        const arrow = e.type === 'depends-on' ? '-.->' : '-->';
        lines.push(label ? `    ${s} ${arrow}|${label}| ${t}` : `    ${s} ${arrow} ${t}`);
    }

    lines.push('    classDef template fill:#fff3e0,stroke:#ffb74d,color:#5d4037');
    lines.push('    classDef rule fill:#fff8ef,stroke:#ffb74d,color:#5d4037');
    lines.push('    classDef fact fill:#388e3c,stroke:#2e7d32,color:#ffffff');
    lines.push('    classDef type fill:#6a1b9a,stroke:#4a148c,color:#ffffff');
    lines.push('    classDef query fill:#c62828,stroke:#8e0000,color:#ffffff');
    return lines.join('\n');
}
