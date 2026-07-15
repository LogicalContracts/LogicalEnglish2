import { test, expect } from '@playwright/test';

// A small program with a success explanation (rule + fact) and every graph
// layer; also used to exercise the failure/unknown classes via its queries.
const PROGRAM = `the target language is: prolog.

the templates are:
*a person* is happy.
*a person* is healthy.
it is sunny; assumable.

the knowledge base wellbeing includes:

a person is happy
    if the person is healthy
    and it is sunny.

scenario base is:
    fluffy is healthy.

query happy is:
    which person is happy.
`;

// Load the program, select scenario/query, and run the query.
async function runQuery(page: any) {
    await page.goto('index.html?text=' + encodeURIComponent(PROGRAM));
    await page.waitForTimeout(800);
    await page.locator('#scenario-select').hover();   // triggers the module load
    await expect.poll(() => page.locator('#scenario-select option').count(), { timeout: 30000 }).toBeGreaterThan(1);
    await page.selectOption('#scenario-select', 'base');
    await page.selectOption('#query-select', 'happy');
    await page.click('#btn-query');
    await expect(page.locator('#answers-list .answer-item').first()).toBeVisible({ timeout: 30000 });
}

test.describe('Mermaid export', () => {
    test('Copy as Mermaid diagram puts a flowchart of the explanation on the clipboard', async ({ page, context }) => {
        test.setTimeout(120000);
        await context.grantPermissions(['clipboard-read', 'clipboard-write']);
        await runQuery(page);

        // Right-click a node of the explanation tree and pick "Copy as Mermaid diagram".
        await page.locator('#explanation-tree .tree-label').first().click({ button: 'right' });
        const item = page.locator('#menu-copy-mermaid');
        await expect(item).toBeVisible();
        await item.click();

        const copied = await page.evaluate(() => navigator.clipboard.readText());
        expect(copied).toContain('flowchart TD');
        expect(copied).toContain('fluffy is happy');
        expect(copied).toContain('fluffy is healthy');
        expect(copied).toContain(':::success');
        // "it is sunny" is assumable and unproven: an unknown (amber) node.
        expect(copied).toMatch(/it is sunny"\]:::unknown/);
        expect(copied).toContain('classDef unknown');
        // Structure: the conclusion points at its conditions.
        expect(copied).toMatch(/e1 --> e\d/);
    });

    test('the graph window copies the visible graph as Mermaid', async ({ page, context }) => {
        test.setTimeout(120000);
        await context.grantPermissions(['clipboard-read', 'clipboard-write']);
        // Deterministic view: all layers on.
        await page.goto('index.html');
        await page.evaluate(() => {
            localStorage.setItem('le-graph-layout', 'grid');
            localStorage.setItem('le-graph-layers', JSON.stringify({
                template: true, rule: true, fact: true, scenario: true, type: true, query: true,
                'uses': true, 'depends-on': true, 'negates': true, 'is-a': true,
            }));
        });
        await runQuery(page);
        await page.evaluate(() => localStorage.setItem('le_graph_test', '1'));
        await page.click('text=Misc');
        const [popup] = await Promise.all([
            page.waitForEvent('popup'),
            page.click('#menu-view-source-graph'),
        ]);
        await popup.waitForLoadState();
        await expect.poll(() => popup.evaluate(() => !!(window as any).__graphTest), { timeout: 30000 }).toBe(true);
        await expect.poll(() => popup.evaluate(() =>
            (window as any).__graphTest.nodes().length), { timeout: 30000 }).toBeGreaterThan(0);

        // The generator behind the button, on the visible elements.
        const mermaid = await popup.evaluate(() => (window as any).__graphTest.mermaid());
        expect(mermaid).toContain('flowchart');
        expect(mermaid).toContain('is happy');            // a template/rule label
        expect(mermaid).toContain(':::template');
        expect(mermaid).toMatch(/subgraph n\d+\["[^"]*base[^"]*"\]/); // the scenario as a subgraph
        expect(mermaid).toContain('classDef fact');
        expect(mermaid).toMatch(/n\d+ (-->|-\.->)/);       // at least one edge

        // And the button itself: copies + confirms via alert.
        popup.once('dialog', (d: any) => d.accept());
        await popup.click('#btn-copy-mermaid');
        const copied = await popup.evaluate(() => navigator.clipboard.readText());
        expect(copied).toBe(mermaid);
    });
});
