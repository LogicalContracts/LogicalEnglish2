import { test, expect } from '@playwright/test';

// The server renders the repo's docs cleanly (no repo chrome) at /docs/<name>,
// client-side with marked.js, serving sibling images from the same tree.
test.describe('Docs viewer', () => {
    test('renders the syntax reference from Markdown', async ({ page }) => {
        await page.goto('/docs/le_summary');
        // marked turns the "# Logical English (LE) Syntax Summary" heading into <h1>.
        const h1 = page.locator('#content h1').first();
        await expect(h1).toBeVisible();
        await expect(h1).toContainText('Logical English');
        // The doc bar links back into the app (not GitHub repo chrome).
        await expect(page.locator('header.docbar a', { hasText: 'Editor' })).toBeVisible();
        // The page title reflects the document's H1.
        await expect(page).toHaveTitle(/Logical English/);
    });

    test('renders the tutorial with its screenshots resolving', async ({ page }) => {
        await page.goto('/docs/tutorial0/IntroToLE2');
        await expect(page.locator('#content h1').first()).toContainText('Gentle Introduction');
        // A relative screenshot (e.g. 01-editor-overview.png) must resolve under
        // /docs/tutorial0/ and actually load (naturalWidth > 0).
        const img = page.locator('#content img').first();
        await expect(img).toBeVisible();
        await expect.poll(async () =>
            await img.evaluate((el: HTMLImageElement) => el.complete && el.naturalWidth > 0)
        ).toBe(true);
    });
});
