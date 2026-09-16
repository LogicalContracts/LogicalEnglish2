import { test, expect, Page } from '@playwright/test';

// View Original Text (context menu and File menu): where what is under the
// cursor comes from. A citation there opens its passage (source-viewer.spec.ts);
// otherwise the construct under the cursor is looked for in the originals the
// program keeps (operation originalTextAt): here, a LegalRuleML twin whose
// rules are labelled with the keys of the statements of its source.
const LRML_TWIN = 'migration/legalruleml/ex12_usc_17_504_context/ex12_usc_17_504_context';

async function openExample(page: Page, example: string) {
    await page.goto(`index.html?example=${example}`);
    await page.waitForSelector('.monaco-editor', { timeout: 30000 });
    await expect.poll(() => page.evaluate(() =>
        (window as any).monaco.editor.getEditors()[0].getModel().getValueLength()), { timeout: 30000 }).toBeGreaterThan(0);
}

// Put the cursor `lines` lines below the first line containing `needle`.
async function cursorAt(page: Page, needle: string, lines = 0) {
    return page.evaluate(({ needle, lines }) => {
        const ed = (window as any).monaco.editor.getEditors()[0];
        const match = ed.getModel().findMatches(needle, false, false, true, null, false)[0];
        const line = match.range.startLineNumber + lines;
        ed.revealLineInCenter(line);
        ed.setPosition({ lineNumber: line, column: 6 });
        const pos = ed.getScrolledVisiblePosition({ lineNumber: line, column: 6 });
        const box = ed.getDomNode().getBoundingClientRect();
        return { x: box.left + pos.left, y: box.top + pos.top + pos.height / 2 };
    }, { needle, lines });
}

// Run the action the way the other specs run editor actions: a click on a
// Monaco menu entry is timing-dependent in headless runs.
async function runViewOriginalText(page: Page) {
    await page.evaluate(async () => {
        const ed = (window as any).monaco.editor.getEditors()[0];
        await ed.getAction('le-show-original-text').run(ed);
    });
}

test.describe('View Original Text', () => {
    test('a labelled rule of a twin shows its statement in the source', async ({ page }) => {
        test.setTimeout(120000);
        await openExample(page, LRML_TWIN);

        // offered on a line with no citation (inside rule ps2_tblock1)
        const point = await cursorAt(page, 'rule ps2_tblock1:', 2);
        await page.mouse.click(point.x, point.y, { button: 'right' });
        await expect(page.getByRole('menuitem', { name: 'View Original Text' })).toBeVisible({ timeout: 30000 });
        await page.keyboard.press('Escape');

        await cursorAt(page, 'rule ps2_tblock1:', 2);
        await runViewOriginalText(page);
        const viewer = page.locator('#source-viewer');
        await expect(viewer).toBeVisible({ timeout: 60000 });
        await expect(viewer.locator('h2')).toHaveText('ex12-USC_17_504_context-normal.lrml');
        const mark = viewer.locator('mark');
        await expect(mark).toContainText('<lrml:PrescriptiveStatement key="ps2-tblock1">', { timeout: 30000 });
        await expect(mark).toContainText('</lrml:PrescriptiveStatement>');
        await expect(mark).not.toContainText('ps3-tblock1');
        await viewer.locator('button.primary').click();
        await expect(viewer).toHaveCount(0);

        // the same from the File menu, on the label line of rule ps1
        await cursorAt(page, 'rule ps1:');
        await page.evaluate(() => (document.getElementById('menu-view-original-text') as HTMLElement).click());
        await expect(viewer.locator('mark')).toContainText('<lrml:PrescriptiveStatement key="ps1">', { timeout: 30000 });
        await viewer.locator('button.primary').click();
    });

    test('with no located passage the original itself is shown, saying so', async ({ page }) => {
        test.setTimeout(120000);
        await openExample(page, LRML_TWIN);
        // a query: nothing of the source is about it
        await cursorAt(page, 'query breaches is:', 1);
        await runViewOriginalText(page);
        const viewer = page.locator('#source-viewer');
        await expect(viewer).toBeVisible({ timeout: 60000 });
        await expect(viewer.locator('h2')).toHaveText('ex12-USC_17_504_context-normal.lrml');
        await expect(viewer.locator('.sv-note')).toContainText('No passage of the original was located');
        await expect(viewer.locator('pre')).toContainText('PrescriptiveStatement', { timeout: 30000 });
        await expect(viewer.locator('mark')).toHaveCount(0);
    });

    test('a program with no original text says so in a dialog', async ({ page }) => {
        test.setTimeout(120000);
        let alerted = false;
        page.on('dialog', async d => { alerted = true; await d.dismiss(); });
        await openExample(page, 'citizenship');
        await cursorAt(page, 'the templates are', 1);
        await runViewOriginalText(page);
        const dialog = page.locator('#message-dialog');
        await expect(dialog).toBeVisible({ timeout: 60000 });
        await expect(dialog).toContainText('This program keeps no original text');
        await dialog.getByRole('button', { name: 'Close' }).click();
        await expect(dialog).toHaveCount(0);
        expect(alerted).toBe(false);
    });
});
