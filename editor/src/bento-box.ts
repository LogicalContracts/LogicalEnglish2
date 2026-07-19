// Bento Box window: renders the explanation tree of one answer as nested
// compartments, bento style — the rule proving the root is the outer box, its
// body conditions are the boxes within it, and so on down to the leaves (the
// facts, the "food"). Compartment sizes are weighted by subproof size, so a
// bigger derivation naturally becomes the hero cell; orientation alternates
// with depth, giving the classic bento subdivision. Failed nodes render as
// empty dark space; assumed ("unknown") nodes get a dashed amber rim. Every
// node has a unique hue, indexed in the legend; hovering a box shows its
// literal, clicking it highlights its source in the editor that opened this
// window (same le-highlight message the Explanation Drill uses).
import { t, applyI18nDom } from './i18n';

interface WhyNode {
    type?: string;        // "success" | "failure" | "unknown" (assumed)
    literal?: string;
    start?: number;
    end?: number;
    children?: WhyNode[];
}

interface BentoData {
    kbName?: string;
    answer?: string;
    why?: any;            // a WhyNode or an array of them
}

// Unique, well-spread hues: successive nodes advance by the golden angle.
const GOLDEN_ANGLE = 137.508;

function hue(index: number): number {
    return (index * GOLDEN_ANGLE) % 360;
}

export function initBentoBox() {
    const $ = (id: string) => document.getElementById(id)!;
    applyI18nDom();

    const data: BentoData = JSON.parse(localStorage.getItem('le_bento_box_data') || '{}');
    ($('title') as HTMLElement).textContent = `${t('Bento Box')}${data.kbName ? ` — ${data.kbName}` : ''}`;
    document.title = `${t('Bento Box')}${data.kbName ? ` — ${data.kbName}` : ''}`;
    $('answer').textContent = data.answer || '';

    const roots: WhyNode[] = Array.isArray(data.why) ? data.why : (data.why ? [data.why] : []);
    const tray = $('tray');
    const legendRows = $('legend-rows');
    if (!roots.length) {
        tray.textContent = t('No explanation to display.');
        (tray as HTMLElement).style.color = '#d4d4d4';
        return;
    }

    const light = document.body.classList.contains('light-theme');
    const boxByPath = new Map<string, HTMLElement>();
    let seq = 0;   // hue index, DFS order

    // How many leaves a subtree holds — a compartment's share of the tray.
    function weight(node: WhyNode): number {
        const kids = node.children || [];
        if (!kids.length) return 1;
        return kids.reduce((s, k) => s + weight(k), 0);
    }

    function markerFor(node: WhyNode): string {
        if (node.type === 'failure') return 'x ';
        if (node.type === 'unknown') return '? ';
        return '';
    }

    function render(node: WhyNode, parent: HTMLElement, depth: number, path: string) {
        const el = document.createElement('div');
        el.className = 'bento-box';
        el.dataset.path = path;
        const kids = node.children || [];
        const failed = node.type === 'failure';
        const assumed = node.type === 'unknown';
        const h = hue(seq++);
        const fill = light ? `hsl(${h}, 62%, 86%)` : `hsl(${h}, 42%, 26%)`;
        const edge = light ? `hsl(${h}, 55%, 55%)` : `hsl(${h}, 55%, 48%)`;

        el.style.background = fill;
        el.style.borderColor = edge;
        el.style.flexGrow = String(weight(node));
        el.style.flexBasis = '0';
        // Alternate the split orientation with depth — the bento subdivision.
        el.style.flexDirection = depth % 2 === 0 ? 'row' : 'column';
        if (failed) el.classList.add('failed');
        if (assumed) el.classList.add('assumed');

        // The literal as a hover tooltip (with the tree markers: x failed, ? assumed).
        const literal = node.literal ? String(node.literal) : '';
        if (literal) el.title = `${path}  ${markerFor(node)}${literal}`;

        // Clicking highlights the node's source in the editor (without stealing
        // focus from this window). stopPropagation: only the innermost box hit.
        el.addEventListener('click', (e) => {
            e.stopPropagation();
            flash(el);
            if (typeof node.start === 'number' && typeof node.end === 'number' && node.end > node.start) {
                window.opener?.postMessage({ type: 'le-highlight', loc: { start: node.start, end: node.end }, noFocus: true }, '*');
            }
        });

        parent.appendChild(el);
        boxByPath.set(path, el);
        // Legend BEFORE the children so it reads in preorder (1, 1.1, 1.2, …).
        addLegendRow(node, path, failed ? '' : fill, failed ? '' : edge);

        if (failed) {
            // Empty dark space: the compartment stays, its contents (and any
            // sub-derivations) are not shown.
        } else if (!kids.length) {
            el.classList.add('leaf');
            el.textContent = literal;
        } else {
            kids.forEach((k, i) => render(k, el, depth + 1, `${path}.${i + 1}`));
        }
    }

    function addLegendRow(node: WhyNode, path: string, fill: string, edge: string) {
        const row = document.createElement('div');
        row.className = 'legend-row';
        if (node.type === 'failure') row.classList.add('failed');
        if (node.type === 'unknown') row.classList.add('assumed');
        const swatch = document.createElement('span');
        swatch.className = 'legend-swatch';
        swatch.style.background = fill || 'var(--empty-bg)';
        swatch.style.borderColor = edge || '#000';
        if (node.type === 'unknown') swatch.style.borderStyle = 'dashed';
        const pathEl = document.createElement('span');
        pathEl.className = 'legend-path';
        pathEl.textContent = path;
        const text = document.createElement('span');
        text.className = 'legend-text';
        text.textContent = `${markerFor(node)}${node.literal ? String(node.literal) : ''}`;
        row.append(swatch, pathEl, text);
        // Hovering a legend entry flashes its box; clicking acts like clicking it.
        row.addEventListener('mouseenter', () => boxByPath.get(path)?.classList.add('flash'));
        row.addEventListener('mouseleave', () => boxByPath.get(path)?.classList.remove('flash'));
        row.addEventListener('click', () => boxByPath.get(path)?.dispatchEvent(new MouseEvent('click')));
        legendRows.appendChild(row);
    }

    function flash(el: HTMLElement) {
        el.classList.add('flash');
        setTimeout(() => el.classList.remove('flash'), 400);
    }

    roots.forEach((r, i) => render(r, tray, 0, String(i + 1)));
}
