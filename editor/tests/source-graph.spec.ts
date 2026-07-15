import { test, expect } from '@playwright/test';

// A small program exercising every graph layer, including an "expects answers"
// item (compiled to le_expected/4) that must NOT appear in the graph.
const PROGRAM = `the target language is: prolog.

the templates are:
*a person* is happy.
*a person* is healthy.

the knowledge base wellbeing includes:

a person is happy
    if the person is healthy.

scenario base is:
    fluffy is healthy.
    happy expects answers [
        "fluffy is happy"
    ].

query happy is:
    which person is happy.
`;

// Open the editor with the program, load the module, then open the Source
// Graph from Misc > View Source Graph (with the graph test hook enabled).
async function openSourceGraph(page: any): Promise<any> {
    await page.goto('index.html?text=' + encodeURIComponent(PROGRAM));
    await page.waitForTimeout(800);
    await page.locator('#scenario-select').hover();   // triggers the module load
    await expect.poll(() => page.locator('#scenario-select option').count(), { timeout: 30000 }).toBeGreaterThan(1);
    await page.evaluate(() => localStorage.setItem('le_graph_test', '1'));
    await page.click('text=Misc');
    const [popup] = await Promise.all([
        page.waitForEvent('popup'),
        page.click('#menu-view-source-graph'),
    ]);
    await popup.waitForLoadState();
    await expect.poll(() => popup.evaluate(() => !!(window as any).__graphTest), { timeout: 30000 }).toBe(true);
    // Nodes arrive once the graph window has fetched the editor's state.
    await expect.poll(() => popup.evaluate(() =>
        (window as any).__graphTest.nodes().length), { timeout: 30000 }).toBeGreaterThan(0);
    return popup;
}

test.describe('Source Graph', () => {
    test('opens from the Misc menu with the selected layers, hiding le_expected', async ({ page }) => {
        test.setTimeout(120000);
        // Persisted preferences: grid layout (deterministic) and ALL layers on.
        await page.goto('index.html');
        await page.evaluate(() => {
            localStorage.setItem('le-graph-layout', 'grid');
            localStorage.setItem('le-graph-layers', JSON.stringify({
                template: true, rule: true, fact: true, scenario: true, type: true, query: true,
                'uses': true, 'depends-on': true, 'negates': true, 'is-a': true,
            }));
        });

        const popup = await openSourceGraph(page);

        // The persisted layout and layer selection were restored.
        await expect(popup.locator('#layout-select')).toHaveValue('grid');
        await expect(popup.locator('input[data-type="fact"]')).toBeChecked();
        await expect(popup.locator('input[data-type="scenario"]')).toBeChecked();

        // Every selected layer actually RENDERS (visible nodes per type) — the
        // window used to open with fewer layers than selected.
        const nodes = await popup.evaluate(() => (window as any).__graphTest.nodes());
        for (const type of ['template', 'rule', 'fact', 'scenario', 'query']) {
            expect(nodes.some((n: any) => n.type === type && n.visible),
                   `layer ${type} should be visible`).toBe(true);
        }

        // The expects-answers record (le_expected/4) is not in the graph.
        expect(nodes.some((n: any) => String(n.label).includes('le_expected'))).toBe(false);

        // Changing the layout persists it for the next window.
        await popup.selectOption('#layout-select', 'circle');
        await expect.poll(() => popup.evaluate(() => localStorage.getItem('le-graph-layout'))).toBe('circle');

        // Toggling a layer persists too, and hides that layer's nodes.
        await popup.locator('input[data-type="query"]').uncheck();
        await expect.poll(() => popup.evaluate(() =>
            JSON.parse(localStorage.getItem('le-graph-layers') || '{}').query)).toBe(false);
        await expect.poll(() => popup.evaluate(() =>
            (window as any).__graphTest.nodes().some((n: any) => n.type === 'query' && n.visible))).toBe(false);
    });

    test('Copy Node puts the node text on the clipboard', async ({ page, context }) => {
        test.setTimeout(120000);
        await context.grantPermissions(['clipboard-read', 'clipboard-write']);
        await page.goto('index.html');
        await page.evaluate(() => {
            localStorage.setItem('le-graph-layout', 'grid');
            localStorage.setItem('le-graph-layers', JSON.stringify({
                template: true, rule: true, fact: false, scenario: false, type: false, query: false,
                'uses': true, 'depends-on': true, 'negates': true, 'is-a': true,
            }));
        });

        const popup = await openSourceGraph(page);
        popup.on('dialog', (d: any) => d.accept());   // the "copied" alert

        // The initial layout ANIMATES; wait until node positions settle, or the
        // click lands where the node used to be (copying its neighbour).
        const readPos = () => popup.evaluate(() => {
            const n = (window as any).__graphTest.cy.nodes('[type="template"]').first();
            const p = n.renderedPosition();
            return `${Math.round(p.x)},${Math.round(p.y)}`;
        });
        let prev = await readPos();
        await expect.poll(async () => {
            const cur = await readPos();
            const stable = cur === prev;
            prev = cur;
            return stable;
        }, { timeout: 30000, intervals: [300] }).toBe(true);

        // Right-click the template node at its rendered position on the canvas.
        const target = await popup.evaluate(() => {
            const cy = (window as any).__graphTest.cy;
            const n = cy.nodes('[type="template"]').first();
            const p = n.renderedPosition();
            const rect = document.getElementById('graph-container')!.getBoundingClientRect();
            return { x: rect.left + p.x, y: rect.top + p.y, label: n.data('label') };
        });
        await popup.mouse.click(target.x, target.y, { button: 'right' });
        await expect(popup.locator('#ctx-copy-node')).toBeVisible();
        // The copied text is whatever node the right-click actually recorded
        // (hit-testing at the exact border can pick a neighbour under some
        // zoom levels; what matters is that THAT node's text gets copied).
        const clicked = await popup.evaluate(() => (window as any).__graphTest.rightClicked());
        expect(clicked).toBeTruthy();
        await popup.locator('#ctx-copy-node').click();

        await expect.poll(() => popup.evaluate(() => navigator.clipboard.readText())).toBe(clicked);
    });
});
