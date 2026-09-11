import { test, expect } from '@playwright/test';

const modelText = () => (window as any).monaco.editor.getEditors()[0].getModel().getValue() as string;

// Several documents open at once, one per tab. Each tab's program keeps its
// own Query panel (pickers, answers, explanation); File operations act on the
// tab in front.
test.describe('Editor file tabs', () => {
    test('a new tab, its own program and panels, switching back, closing', async ({ page }) => {
        test.setTimeout(120000);
        await page.goto('index.html?example=citizenship');
        const tabs = page.locator('#editor-tabs .le-tab');
        await expect(tabs).toHaveCount(1);
        await expect(tabs.first().locator('.le-tab-title')).toHaveText('citizenship.le');

        // Run a query in the first program.
        await page.locator('#query-select').hover();
        await expect.poll(() => page.locator('#query-select option').count(), { timeout: 60000 }).toBeGreaterThan(2);
        const firstQuery = await page.locator('#query-select option').nth(1).getAttribute('value');
        await page.selectOption('#scenario-select', 'alice');
        await page.selectOption('#query-select', firstQuery!);
        await page.click('#btn-query');
        await expect(page.locator('#answers-list .answer-item').first()).toBeVisible({ timeout: 60000 });
        const answersBefore = await page.locator('#answers-list').innerText();

        // "+": a second, empty document, in front, with fresh panels.
        await page.click('#editor-tab-new');
        await expect(tabs).toHaveCount(2);
        await expect(tabs.nth(1)).toHaveClass(/active/);
        expect(await page.evaluate(modelText)).toBe('');
        await expect(page.locator('#answers-list .answer-item')).toHaveCount(0);
        await expect(page.locator('#filename-display')).toHaveText('document.le');
        expect(new URL(page.url()).searchParams.get('example')).toBeNull();

        // Its own program, queried in its own panels.
        await page.evaluate(() => (window as any).monaco.editor.getEditors()[0].getModel().setValue([
            'the target language is: prolog.',
            'the templates are:',
            '*a thing* is shiny.',
            '*a thing* is gold.',
            'the knowledge base shiny includes:',
            'a thing is shiny if the thing is gold.',
            'scenario one is:',
            '    the ring is gold.',
            'query shiny is:',
            '    which thing is shiny.',
        ].join('\n')));
        await expect(tabs.nth(1)).toHaveClass(/dirty/);
        await page.locator('#query-select').hover();
        await expect(page.locator('#query-select option[value="shiny"]')).toHaveCount(1, { timeout: 60000 });
        await page.selectOption('#scenario-select', 'one');
        await page.selectOption('#query-select', 'shiny');
        await page.click('#btn-query');
        await expect(page.locator('#answers-list')).toContainText('the ring is shiny', { timeout: 60000 });

        // Back to the first tab: its text, answers and selection are as they were.
        await tabs.nth(0).click();
        await expect(tabs.nth(0)).toHaveClass(/active/);
        expect(await page.evaluate(modelText)).toContain('citizenship');
        await expect(page.locator('#answers-list')).toHaveText(answersBefore);
        await expect(page.locator('#query-select')).toHaveValue(firstQuery!);
        expect(new URL(page.url()).searchParams.get('example')).toBe('citizenship');

        // ... and to the second again.
        await tabs.nth(1).click();
        await expect(page.locator('#answers-list')).toContainText('the ring is shiny');
        await expect(page.locator('#query-select')).toHaveValue('shiny');

        // File > New opens a new tab; the others keep their documents.
        await page.click('text=File');
        await page.click('#menu-new');
        await expect(tabs).toHaveCount(3);
        await expect(tabs.nth(2)).toHaveClass(/active/);
        expect(await page.evaluate(modelText)).toBe('');

        // Closing the tab in front brings its neighbour forward (an untouched
        // tab closes without asking; one with unsaved changes asks first).
        await tabs.nth(2).locator('.le-tab-close').click();
        await expect(tabs).toHaveCount(2);
        await expect(tabs.nth(1)).toHaveClass(/active/);
        expect(await page.evaluate(modelText)).toContain('the ring is gold');
        page.once('dialog', d => d.accept());
        await tabs.nth(1).locator('.le-tab-close').click();
        await expect(tabs).toHaveCount(1);
        await expect(tabs.nth(0)).toHaveClass(/active/);
        expect(await page.evaluate(modelText)).toContain('citizenship');
        await expect(page.locator('#answers-list')).toHaveText(answersBefore);
    });

    test('files opened from the File menu go into tabs of their own', async ({ page }) => {
        test.setTimeout(120000);
        const openFromServer = async (name: RegExp) => {
            const item = page.locator('#example-list .dropdown-item', { hasText: name });
            await expect(async () => {
                await page.click('text=File');
                await page.click('#menu-open-server');
                await expect(item).toBeVisible({ timeout: 1000 });
            }).toPass();
            await item.click();
        };
        await page.goto('index.html');
        const tabs = page.locator('#editor-tabs .le-tab');
        await expect(tabs).toHaveCount(1);

        // The untouched new document the editor starts with is replaced, not
        // left behind as an empty tab.
        await openFromServer(/^citizenship$/);
        await expect(tabs).toHaveCount(1);
        await expect(tabs.nth(0).locator('.le-tab-title')).toHaveText('citizenship.le');
        await expect.poll(() => page.evaluate(modelText)).toContain('citizenship');

        // The next one gets a tab of its own, in front, with its program in the panels.
        await openFromServer(/^happy_dragon$/);
        await expect(tabs).toHaveCount(2);
        await expect(tabs.nth(1)).toHaveClass(/active/);
        await expect(tabs.nth(1).locator('.le-tab-title')).toHaveText('happy_dragon.le');
        expect(await page.evaluate(modelText)).not.toContain('citizenship');
        await expect.poll(() => new URL(page.url()).searchParams.get('example')).toBe('happy_dragon');
        await expect(tabs.nth(0)).not.toHaveClass(/dirty/);

        // A file already open: its tab comes forward, no duplicate.
        await openFromServer(/^citizenship$/);
        await expect(tabs).toHaveCount(2);
        await expect(tabs.nth(0)).toHaveClass(/active/);
        expect(await page.evaluate(modelText)).toContain('citizenship');
    });

    test('a click on a picker before the program is loaded shows a waiting cursor', async ({ page }) => {
        test.setTimeout(60000);
        let release: () => void = () => {};
        const held = new Promise<void>(r => { release = r; });
        await page.route('**/leapi*', async (route) => {
            const body = JSON.parse(route.request().postData() || '{}');
            if (body.operation === 'load') { await held; }
            await route.continue();
        });
        await page.goto('index.html?example=citizenship');
        await expect(page.locator('#editor-tabs .le-tab')).toHaveCount(1);
        // mousedown straight away: no hover first, so the load starts with the click
        await page.locator('#scenario-select').dispatchEvent('mousedown');
        await expect(page.locator('body')).toHaveClass(/le-busy/);
        expect(await page.evaluate(() => getComputedStyle(document.getElementById('scenario-select')!).cursor)).toBe('wait');
        release();
        await expect(page.locator('body')).not.toHaveClass(/le-busy/, { timeout: 30000 });
        await expect.poll(() => page.locator('#scenario-select option').count()).toBeGreaterThan(2);
    });
});
