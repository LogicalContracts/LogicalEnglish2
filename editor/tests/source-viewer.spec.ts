import { test, expect } from '@playwright/test';

// A node proved by a rule or a fact with provenance carries a § badge; it
// opens the cited document's text (the program says where it is: "the text of
// <document> is at <address>") with the quoted passage highlighted.
test.describe('Source viewer', () => {
    test('the § badge of a cited rule shows its source passage', async ({ page }) => {
        test.setTimeout(120000);
        await page.goto('index.html?example=RulesRus/customs/apparel_cbp&scenario=ny_n362700&query=subheading');
        await expect(page.locator('#query-select')).toHaveValue('subheading', { timeout: 60000 });
        await page.click('#btn-query');
        await expect(page.locator('#answers-list .answer-item').first()).toBeVisible({ timeout: 60000 });

        // The root: rule apparel_subheading, citing Section XI subheading note 2.
        const badge = page.locator('#explanation-tree .tree-label .tree-prov').first();
        await expect(badge).toHaveAttribute('title', /apparel_subheading/);
        await badge.click();
        const viewer = page.locator('#source-viewer');
        await expect(viewer).toBeVisible();
        await expect(viewer.locator('h2')).toHaveText('HTSUS Section XI and Chapter 50');
        await expect(viewer.locator('mark')).toContainText('Products of chapters 56 to 63', { timeout: 30000 });
        await viewer.locator('button.primary').click();
        await expect(viewer).toHaveCount(0);
    });
});
