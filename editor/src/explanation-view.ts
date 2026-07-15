// Reusable answers + explanation view: the body of the Query panel (a list of
// answers with unknown-goal tooltips, side by side with the navigable explanation
// tree of the selected answer). Shared by the main editor (client.ts) and the
// Scenario Variations window. Source navigation is delegated via onNavigate; the
// shared context menus are wired once per window and act on whichever view was last
// interacted with (activeView).

import { explanationToMermaid } from './mermaid-export';
import { t, applyI18nDom, installLeApiLang } from './i18n';

export interface MenuEls {
    answerContextMenu: HTMLElement;
    menuCopyAnswer: HTMLElement;
    explanationContextMenu: HTMLElement;
    menuCopyExplanation: HTMLElement;
    menuCopyMermaid: HTMLElement;       // "Copy as Mermaid diagram"
    menuGotoOriginal: HTMLElement;
    answerTooltip: HTMLElement;
    titleMenu: HTMLElement;             // context menu for the EXPLANATION title
    menuShowStrongest: HTMLElement;     // its "Show important reason" item
    menuExplanationDrill: HTMLElement;  // its "Explanation Drill…" item
    menuPatchScenario?: HTMLElement;    // node menu: add (failed) / delete (succeeded) the fact
    menuAssumeFact?: HTMLElement;       // node menu (failed only): assume the fact unknown+true
}

export interface ExplanationViewOptions {
    answersList: HTMLElement;
    explanationTree: HTMLElement;
    menus: MenuEls;
    explanationTitle?: HTMLElement;        // the "EXPLANATION" label — hosts the strongest-reason tooltip
    failedNodePrefix?: () => string;       // prefix for failed nodes when copying
    hierarchicalNumbering?: () => boolean; // show "1.2.3" path numbers
    onNavigate?: (start: number, end: number) => void;   // a node was clicked -> reveal source
    onSelectAnswer?: (index: number) => void;            // an answer was selected (1-based)
    onOpenDrill?: (why: any) => void;                    // open the Explanation Drill for a `why`
    // Scenario Variations only: patch the scenario from a tree node. onPatchScenario
    // adds the node's fact when it failed / removes it when it succeeded; onAssumeFact
    // (failed nodes) adds it as an assumed unknown. Absent => the items are not shown.
    onPatchScenario?: (node: any) => void;
    onAssumeFact?: (node: any) => void;
    // Gate the node menu items: "delete this fact" is offered on a succeeded node only
    // when it corresponds to a current scenario fact; "add this fact" / "Assume fact"
    // on a failed node only when its literal is a real template. Absent => always show.
    canDeleteScenarioFact?: (node: any) => boolean;
    canAddScenarioFact?: (node: any) => boolean;
}

let activeView: ExplanationView | null = null;
let menusWired = false;

// Wire the window's shared context menus once. They operate on `activeView`.
function wireMenus(m: MenuEls) {
    if (menusWired) return;
    menusWired = true;
    document.addEventListener('click', () => {
        m.answerContextMenu.style.display = 'none';
        m.explanationContextMenu.style.display = 'none';
        m.titleMenu.style.display = 'none';
    });
    m.menuShowStrongest.addEventListener('click', (e) => {
        e.stopPropagation();
        activeView?.showStrongestReason();
        m.titleMenu.style.display = 'none';
    });
    m.menuExplanationDrill.addEventListener('click', (e) => {
        e.stopPropagation();
        activeView?.openDrill();
        m.titleMenu.style.display = 'none';
    });
    m.menuCopyAnswer.addEventListener('click', (e) => {
        e.stopPropagation();
        if (activeView && activeView.currentAnswerToCopy) navigator.clipboard.writeText(activeView.currentAnswerToCopy);
        m.answerContextMenu.style.display = 'none';
    });
    m.menuGotoOriginal.addEventListener('click', (e) => {
        e.stopPropagation();
        activeView?.gotoOriginal();
        m.explanationContextMenu.style.display = 'none';
    });
    m.menuCopyExplanation.addEventListener('click', (e) => {
        e.stopPropagation();
        activeView?.copyExplanation();
        m.explanationContextMenu.style.display = 'none';
    });
    m.menuCopyMermaid.addEventListener('click', (e) => {
        e.stopPropagation();
        activeView?.copyExplanationMermaid();
        m.explanationContextMenu.style.display = 'none';
    });
    m.menuPatchScenario?.addEventListener('click', (e) => {
        e.stopPropagation();
        activeView?.patchCurrentNode();
        m.explanationContextMenu.style.display = 'none';
    });
    m.menuAssumeFact?.addEventListener('click', (e) => {
        e.stopPropagation();
        activeView?.assumeCurrentNode();
        m.explanationContextMenu.style.display = 'none';
    });
}

export class ExplanationView {
    currentAnswerToCopy = '';
    // The tree node last right-clicked, target of the Patch scenario / Assume fact items.
    private currentMenuNode: any = null;
    private o: ExplanationViewOptions;
    private m: MenuEls;
    private lastWhy: any = null;
    private currentRepeatedOf: string | null = null;
    private pathToContainer = new Map<string, HTMLElement>();
    private currentExpansion: Map<string, boolean> | null = null;
    private fullByLiteral = new Map<string, string>();
    // Tree path ("1.2.3") of the selected answer's strongest-reason node, for the
    // "Show strongest reason" action.
    private currentStrongestPath: string | null = null;
    // Per-answer expansion state (keyed by the answer's `why` object), so toggles
    // persist when switching between answers.
    private expansionStore = new WeakMap<object, Map<string, boolean>>();

    constructor(opts: ExplanationViewOptions) {
        this.o = opts;
        this.m = opts.menus;
        wireMenus(opts.menus);
        // Right-click the EXPLANATION title -> title menu (shown whenever there is an
        // explanation). "Show important reason" appears only when there is one.
        opts.explanationTitle?.addEventListener('contextmenu', (e) => {
            if (!this.lastWhy) return;
            e.preventDefault();
            activeView = this;
            this.m.menuShowStrongest.style.display = this.currentStrongestPath ? '' : 'none';
            this.m.titleMenu.style.display = 'block';
            this.m.titleMenu.style.left = `${(e as MouseEvent).clientX}px`;
            this.m.titleMenu.style.top = `${(e as MouseEvent).clientY}px`;
        });
    }

    private failedNodePrefix(): string { return this.o.failedNodePrefix?.() ?? 'x '; }
    private hierarchical(): boolean { return this.o.hierarchicalNumbering?.() ?? false; }

    clear() { this.o.answersList.innerHTML = ''; this.o.explanationTree.innerHTML = ''; this.lastWhy = null; this.setStrongestReason(); }
    rerender() { if (this.lastWhy) this.renderExplanation(this.lastWhy); }   // e.g. after a preference change
    showMessage(text: string) { this.o.answersList.textContent = text; this.o.explanationTree.innerHTML = ''; this.setStrongestReason(); }

    // Record the selected answer's "strongest reason" (a terse summary computed on the
    // Prolog side): shown as a tooltip on the EXPLANATION title and revealable via its
    // context menu. `path` is that node's tree path ("1.2.3"). Cleared when there is none.
    private setStrongestReason(reason?: string, path?: string) {
        this.currentStrongestPath = (reason && path) ? path : null;
        const el = this.o.explanationTitle;
        if (!el) return;
        const r = (reason || '').trim();
        if (r) { el.title = `Important reason: ${r}`; el.classList.add('has-reason'); }
        else { el.removeAttribute('title'); el.classList.remove('has-reason'); }
    }

    // Open the Explanation Drill for the current answer's explanation.
    openDrill() {
        if (this.lastWhy) this.o.onOpenDrill?.(this.lastWhy);
    }

    // Expand the tree to the strongest-reason node, open it one level, and flash it.
    showStrongestReason() {
        if (!this.currentStrongestPath) return;
        const container = this.pathToContainer.get(this.currentStrongestPath);
        if (!container) return;
        this.expandOneLevel(container);      // reveal the node's own direct children too
        this.revealAndHighlight(container);
    }

    // Open a node's immediate children (one level), if it has any.
    private expandOneLevel(container: HTMLElement) {
        const children = container.querySelector(':scope > .tree-children') as HTMLElement | null;
        if (!children) return;
        children.style.display = 'block';
        const toggle = container.querySelector(':scope > .tree-label > .tree-toggle');
        if (toggle) toggle.textContent = t('-');
        const path = container.dataset.path;
        if (path) this.currentExpansion?.set(path, true);
    }

    // Render the answer list of an `answeringQuery` response and auto-select one.
    // Handles the success (results), failure (why), interrupted and error cases.
    showResults(res: any, selectIndex = 0) {
        const answersList = this.o.answersList;
        answersList.innerHTML = '';
        this.o.explanationTree.innerHTML = '';
        this.m.answerTooltip.style.display = 'none';

        if (res && res.results && res.results.length > 0) {
            const target = Math.min(Math.max(selectIndex, 0), res.results.length - 1);
            res.results.forEach((result: any, index: number) => {
                const item = document.createElement('div');
                item.className = 'answer-item';
                item.textContent = result.answer;
                const unknowns: string[] = Array.isArray(result.unknowns) ? result.unknowns : [];
                if (unknowns.length > 0) {
                    item.classList.add('has-unknowns');
                    const marker = document.createElement('span');
                    marker.className = 'unknowns-marker';
                    marker.textContent = t('?');
                    item.appendChild(marker);
                    this.attachAnswerTooltip(item, unknowns);
                }
                item.addEventListener('click', () => {
                    answersList.querySelectorAll('.answer-item').forEach(el => el.classList.remove('selected'));
                    item.classList.add('selected');
                    this.renderExplanation(result.why);
                    this.setStrongestReason(result.strongestReason, result.strongestReasonPath);
                    this.o.onSelectAnswer?.(index + 1);
                });
                item.addEventListener('contextmenu', (e) => this.answerMenu(e as MouseEvent, result.answer));
                answersList.appendChild(item);
                if (index === target) item.click();
            });
        } else if (res && res.why) {
            const item = document.createElement('div');
            item.className = 'answer-item failure selected';
            item.style.color = '#f48771';
            item.textContent = t('No answers (false)');
            item.addEventListener('click', () => {
                answersList.querySelectorAll('.answer-item').forEach(el => el.classList.remove('selected'));
                item.classList.add('selected');
                this.renderExplanation(res.why);
                this.setStrongestReason(res.strongestReason, res.strongestReasonPath);
            });
            item.addEventListener('contextmenu', (e) => this.answerMenu(e as MouseEvent, 'No answers (false)'));
            answersList.appendChild(item);
            this.renderExplanation(res.why);
            this.setStrongestReason(res.strongestReason, res.strongestReasonPath);
        } else if (res && res.interrupted) {
            answersList.textContent = t('Query interrupted.');
            this.setStrongestReason();
        } else if (res && res.error) {
            answersList.textContent = t('Error: ') + res.error;
            this.setStrongestReason();
        } else {
            answersList.textContent = t('No results returned.');
            this.setStrongestReason();
        }
    }

    private answerMenu(e: MouseEvent, answer: string) {
        e.preventDefault();
        activeView = this;
        this.currentAnswerToCopy = answer;
        this.m.answerContextMenu.style.display = 'block';
        this.m.answerContextMenu.style.left = `${e.clientX}px`;
        this.m.answerContextMenu.style.top = `${e.clientY}px`;
    }

    // --- Unknown-goal tooltip --------------------------------------------------
    private attachAnswerTooltip(item: HTMLElement, unknowns: string[]) {
        const tip = this.m.answerTooltip;
        item.addEventListener('mouseenter', (e) => {
            const title = document.createElement('div');
            title.className = 'tooltip-title';
            title.textContent = unknowns.length === 1 ? 'Unknown goal:' : `${unknowns.length} unknown goals:`;
            tip.innerHTML = '';
            tip.appendChild(title);
            unknowns.forEach((u) => {
                const line = document.createElement('div');
                line.className = 'tooltip-unknown';
                line.textContent = u;
                tip.appendChild(line);
            });
            tip.style.display = 'block';
            this.positionTooltip(e as MouseEvent);
        });
        item.addEventListener('mousemove', (e) => { if (tip.style.display === 'block') this.positionTooltip(e as MouseEvent); });
        item.addEventListener('mouseleave', () => { tip.style.display = 'none'; });
    }
    private positionTooltip(e: MouseEvent) {
        const tip = this.m.answerTooltip;
        const offset = 12;
        let x = e.clientX + offset, y = e.clientY + offset;
        const rect = tip.getBoundingClientRect();
        if (x + rect.width > window.innerWidth) x = e.clientX - rect.width - offset;
        if (y + rect.height > window.innerHeight) y = e.clientY - rect.height - offset;
        tip.style.left = `${Math.max(0, x)}px`;
        tip.style.top = `${Math.max(0, y)}px`;
    }

    // --- Patch-scenario context-menu actions (Scenario Variations only) --------
    patchCurrentNode() { if (this.currentMenuNode) this.o.onPatchScenario?.(this.currentMenuNode); }
    assumeCurrentNode() { if (this.currentMenuNode) this.o.onAssumeFact?.(this.currentMenuNode); }

    // Show/label the node-specific menu items for the right-clicked node (or hide
    // them when there is no node, e.g. a background right-click). "Patch scenario"
    // adds the fact for a failed node and deletes it for a succeeded one; "Assume
    // fact" is offered only for failed nodes.
    private updateNodeMenuItems(node: any) {
        this.currentMenuNode = node;
        const isFailure = node?.type === 'failure';
        let showPatch = false, patchLabel = '';
        if (node && this.o.onPatchScenario) {
            if (isFailure) {
                showPatch = this.o.canAddScenarioFact ? this.o.canAddScenarioFact(node) : true;
                patchLabel = 'Patch scenario — add this fact';
            } else {
                showPatch = this.o.canDeleteScenarioFact ? this.o.canDeleteScenarioFact(node) : true;
                patchLabel = 'Patch scenario — delete this fact';
            }
        }
        const patch = this.m.menuPatchScenario;
        if (patch) {
            patch.style.display = showPatch ? 'block' : 'none';
            if (showPatch) patch.textContent = patchLabel;
        }
        const showAssume = !!(node && isFailure && this.o.onAssumeFact
            && (this.o.canAddScenarioFact ? this.o.canAddScenarioFact(node) : true));
        const assume = this.m.menuAssumeFact;
        if (assume) assume.style.display = showAssume ? 'block' : 'none';
    }

    // --- Copy / navigate context-menu actions ----------------------------------
    gotoOriginal() {
        if (this.currentRepeatedOf) {
            const target = this.pathToContainer.get(this.currentRepeatedOf);
            if (target) this.revealAndHighlight(target);
        }
    }
    copyExplanation() {
        if (!this.lastWhy) return;
        const text = this.explanationToText(this.lastWhy, 0, '');
        const html = this.explanationToHtml(this.lastWhy, 0, '');
        try {
            navigator.clipboard.write([new ClipboardItem({
                'text/plain': new Blob([text], { type: 'text/plain' }),
                'text/html': new Blob([html], { type: 'text/html' }),
            })]);
        } catch {
            navigator.clipboard.writeText(text);
        }
    }

    // Copy the current explanation as a Mermaid flowchart (text), pasteable
    // into GitHub, Obsidian, docs and chats that render Mermaid.
    copyExplanationMermaid() {
        if (!this.lastWhy) return;
        navigator.clipboard.writeText(explanationToMermaid(this.lastWhy));
    }

    private explanationToText(node: any, depth = 0, prefix = ''): string {
        if (Array.isArray(node)) return node.map((n, i) => this.explanationToText(n, depth, (i + 1).toString())).join('');
        const indent = '  '.repeat(depth);
        let text = (node && typeof node === 'object') ? (node.literal ?? '') : node;
        if (node.type === 'failure') text = `${this.failedNodePrefix()}${text}`;
        if (node.repeated) {
            const c = node.repeatedCount;
            text = (typeof c === 'number' && c > 1) ? `${text} [${c} repeated sub-explanations]` : `${text} [Repeated sub-explanation]`;
        }
        if (this.hierarchical() && prefix && depth > 0) text = `${prefix} ${text}`;
        let result = `${indent}${text}\n`;
        if (node.children) node.children.forEach((child: any, i: number) =>
            result += this.explanationToText(child, depth + 1, prefix ? `${prefix}.${i + 1}` : `${i + 1}`));
        return result;
    }
    private explanationToHtml(node: any, depth = 0, prefix = ''): string {
        if (Array.isArray(node)) return node.map((n, i) => this.explanationToHtml(n, depth, (i + 1).toString())).join('');
        const indent = '&nbsp;&nbsp;'.repeat(depth);
        let text = (node && typeof node === 'object') ? (node.literal ?? '') : node;
        if (node.type === 'failure') text = `${this.failedNodePrefix()}${text}`;
        if (node.repeated) {
            const c = node.repeatedCount;
            text = (typeof c === 'number' && c > 1) ? `${text} [${c} repeated sub-explanations]` : `${text} [Repeated sub-explanation]`;
        }
        if (this.hierarchical() && prefix && depth > 0) text = `${prefix} ${text}`;
        const color = node.type === 'failure' ? '#f48771' : (node.type === 'unknown' ? '#e2b93d' : '#89d185');
        let result = `<div style="color: ${color}; font-family: monospace; white-space: nowrap;">${indent}${text}</div>`;
        if (node.children) node.children.forEach((child: any, i: number) =>
            result += this.explanationToHtml(child, depth + 1, prefix ? `${prefix}.${i + 1}` : `${i + 1}`));
        return result;
    }

    private revealAndHighlight(container: HTMLElement) {
        const tree = this.o.explanationTree;
        let el: HTMLElement | null = container;
        while (el && el !== tree) {
            const parent = el.parentElement as HTMLElement | null;
            if (parent && parent.classList.contains('tree-children')) {
                parent.style.display = 'block';
                const ownerLabel = parent.previousElementSibling as HTMLElement | null;
                const toggle = ownerLabel?.querySelector('.tree-toggle');
                if (toggle) toggle.textContent = t('-');
                const ownerPath = (parent.parentElement as HTMLElement | null)?.dataset.path;
                if (ownerPath) this.currentExpansion?.set(ownerPath, true);
            }
            el = el.parentElement;
        }
        container.scrollIntoView({ block: 'center', behavior: 'smooth' });
        const label = container.querySelector(':scope > .tree-label') as HTMLElement | null;
        if (label) {
            label.classList.add('explanation-highlight');
            setTimeout(() => label.classList.remove('explanation-highlight'), 2200);
        }
    }

    // --- The explanation tree --------------------------------------------------
    renderExplanation(why: any) {
        activeView = this;
        const tree = this.o.explanationTree;
        this.lastWhy = why;
        tree.innerHTML = '';
        this.pathToContainer = new Map<string, HTMLElement>();
        this.fullByLiteral = new Map<string, string>();
        if (!why) return;

        let expansion: Map<string, boolean>;
        if (why !== null && typeof why === 'object') {
            expansion = this.expansionStore.get(why) || new Map<string, boolean>();
            this.expansionStore.set(why, expansion);
        } else {
            expansion = new Map<string, boolean>();
        }
        this.currentExpansion = expansion;

        tree.oncontextmenu = (e) => {
            if (e.target === tree) {
                e.preventDefault();
                activeView = this;
                this.currentRepeatedOf = null;
                this.m.menuGotoOriginal.style.display = 'none';
                this.updateNodeMenuItems(null);
                this.m.explanationContextMenu.style.display = 'block';
                this.m.explanationContextMenu.style.left = `${(e as MouseEvent).clientX}px`;
                this.m.explanationContextMenu.style.top = `${(e as MouseEvent).clientY}px`;
            }
        };

        const repeatedLabels: { label: HTMLElement, node: any, prefix: string }[] = [];

        const navTargetFor = (node: any, prefix: string): string | null => {
            if (!node || !node.repeated) return null;
            let target: string | null = null;
            if (typeof node.repeatedOf === 'string') target = node.repeatedOf;
            else if ((!node.children || node.children.length === 0) && typeof node.literal === 'string') {
                target = this.fullByLiteral.get(node.literal) ?? null;
            }
            return (target && target !== prefix) ? target : null;
        };

        const createNode = (node: any, depth: number, prefix = ''): HTMLElement => {
            const container = document.createElement('div');
            container.className = 'tree-node';
            container.dataset.path = prefix;
            this.pathToContainer.set(prefix, container);

            const label = document.createElement('div');
            label.className = `tree-label ${node.type || 'success'}`;

            const hasChildren = node.children && node.children.length > 0;
            if (hasChildren && typeof node.literal === 'string' && !this.fullByLiteral.has(node.literal)) {
                this.fullByLiteral.set(node.literal, prefix);
            }

            const titleParts: string[] = [];
            if (node.type === 'failure') titleParts.push('Failed: this condition could not be proven');
            else if (node.type === 'unknown') titleParts.push('Unknown: could not be proven true or false, but was assumed true because it matches an "unknown" template');
            else titleParts.push(node.naf === true ? 'Succeeded: this negative condition holds (the inner statement could not be proven)' : 'Succeeded: this condition was proven');
            if (node.repeated) {
                label.classList.add('repeated');
                repeatedLabels.push({ label, node, prefix });
                const c = node.repeatedCount;
                const noun = hasChildren ? 'sub-explanation' : 'occurrence';
                titleParts.push((typeof c === 'number' && c > 1) ? `${c} repeated ${noun}s` : `Repeated ${noun}`);
            }
            label.title = titleParts.join(' · ');

            const isExpandedNow = expansion.has(prefix) ? expansion.get(prefix)! : (depth < 2);
            if (hasChildren) {
                const toggle = document.createElement('span');
                toggle.className = 'tree-toggle';
                toggle.textContent = isExpandedNow ? '-' : '+';
                label.appendChild(toggle);
            }

            const textEl = document.createElement('span');
            textEl.className = 'tree-text';
            let labelText = (node && typeof node === 'object') ? (node.literal ?? '') : node;
            if (this.hierarchical() && prefix && depth > 0) labelText = `${prefix} ${labelText}`;
            textEl.textContent = labelText;
            label.appendChild(textEl);

            label.addEventListener('contextmenu', (e) => {
                e.preventDefault();
                e.stopPropagation();
                activeView = this;
                this.currentRepeatedOf = navTargetFor(node, prefix);
                this.m.menuGotoOriginal.style.display = this.currentRepeatedOf ? 'block' : 'none';
                this.updateNodeMenuItems(node);
                this.m.explanationContextMenu.style.display = 'block';
                this.m.explanationContextMenu.style.left = `${(e as MouseEvent).clientX}px`;
                this.m.explanationContextMenu.style.top = `${(e as MouseEvent).clientY}px`;
            });

            if (node.start !== undefined && node.end !== undefined) {
                textEl.addEventListener('click', (e) => {
                    e.stopPropagation();
                    this.o.onNavigate?.(node.start, node.end);
                });
            }

            container.appendChild(label);

            if (hasChildren) {
                const childrenContainer = document.createElement('div');
                childrenContainer.className = 'tree-children';
                childrenContainer.style.display = isExpandedNow ? 'block' : 'none';
                label.querySelector('.tree-toggle')?.addEventListener('click', (e) => {
                    e.stopPropagation();
                    const newExpanded = childrenContainer.style.display === 'none';
                    childrenContainer.style.display = newExpanded ? 'block' : 'none';
                    (e.target as HTMLElement).textContent = newExpanded ? '-' : '+';
                    expansion.set(prefix, newExpanded);
                });
                node.children.forEach((child: any, index: number) =>
                    childrenContainer.appendChild(createNode(child, depth + 1, prefix ? `${prefix}.${index + 1}` : `${index + 1}`)));
                container.appendChild(childrenContainer);
            }
            return container;
        };

        if (Array.isArray(why)) why.forEach((w, index) => tree.appendChild(createNode(w, 0, (index + 1).toString())));
        else tree.appendChild(createNode(why, 0, '1'));

        for (const { label, node, prefix } of repeatedLabels) {
            if (navTargetFor(node, prefix)) {
                label.classList.add('navigable');
                label.title = `${label.title} · right-click → "Go to full sub-explanation"`;
            }
        }
    }
}
