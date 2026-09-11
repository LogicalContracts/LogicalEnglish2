import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

// The line of apparel.le whose rule proves the root: the head of the
// subheading rule.
function subheadingRuleLine(): number {
    const text = fs.readFileSync(path.join(__dirname, '../../examples/RulesRus/customs/apparel.le'), 'utf8');
    return text.split('\n').findIndex(l => l.startsWith('the subheading of a good is a code')) + 1;
}

// An explanation node proved by a rule of an INCLUDED resource must open that
// resource at the rule — not select whatever sits at the same offsets in the
// document on screen (apparel_cbp.le includes apparel.le and gri.le; the root
// of the explanation is proved by the subheading rule of apparel.le).
test.describe('Navigation into included resources', () => {
    test('clicking a node proved in an included file opens that file at the rule', async ({ page }) => {
        test.setTimeout(120000);
        await page.goto('index.html?example=RulesRus/customs/apparel_cbp&scenario=ny_n362700&query=subheading');
        // Wait until the URL's selections applied (the module load can be slow).
        await expect(page.locator('#query-select')).toHaveValue('subheading', { timeout: 60000 });
        await page.click('#btn-query');
        await expect(page.locator('#answers-list .answer-item').first()).toBeVisible({ timeout: 60000 });

        const root = page.locator('#explanation-tree .tree-label .tree-text').first();
        await expect(root).toContainText('the subheading of style');
        const line = subheadingRuleLine();
        expect(line).toBeGreaterThan(0);
        await expect(root).toHaveAttribute('title', new RegExp(`apparel\\.le, line ${line}`));

        const selectionBefore = await page.evaluate(() =>
            (window as any).monaco.editor.getEditors()[0].getSelection().startLineNumber);

        const [popup] = await Promise.all([page.waitForEvent('popup'), root.click()]);
        const url = new URL(popup.url());
        expect(url.searchParams.get('example')).toBe('RulesRus/customs/apparel');
        expect(url.searchParams.get('line')).toBe(String(line));

        // The document on screen did not jump to the scenario text at those offsets.
        const selectionAfter = await page.evaluate(() =>
            (window as any).monaco.editor.getEditors()[0].getSelection().startLineNumber);
        expect(selectionAfter).toBe(selectionBefore);
        await popup.close();
    });
});
