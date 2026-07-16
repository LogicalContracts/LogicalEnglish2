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

    // Headings get GitHub-style ids after client-side rendering (marked v5+
    // stopped generating them), so #deep-links and the documents' own
    // table-of-contents links navigate correctly.
    test('a #deep-link scrolls to its section', async ({ page }) => {
        await page.goto('/docs/tutorial0/IntroToLE2#10-explanation-preferences-and-the-explanation-drill');
        // [id=…]: a CSS #id selector cannot start with a digit
        const heading = page.locator('[id="10-explanation-preferences-and-the-explanation-drill"]');
        await expect(heading).toHaveText(/10\. Explanation preferences/);
        // The heading sits near the top of the viewport (below the sticky
        // docbar), i.e. the page actually scrolled. Poll: late-loading images
        // shift the layout, and the viewer re-scrolls on window load.
        await expect.poll(async () => (await heading.boundingBox())!.y,
            { timeout: 15000 }).toBeLessThan(120);
        expect(await page.evaluate(() => window.scrollY)).toBeGreaterThan(0);
    });

    test('table-of-contents links navigate within the page', async ({ page }) => {
        await page.goto('/docs/tutorial0/IntroToLE2');
        await page.click('a[href="#9-why-not-failure-explanations"]');
        await expect(page).toHaveURL(/#9-why-not-failure-explanations$/);
        const heading = page.locator('[id="9-why-not-failure-explanations"]');
        await expect.poll(async () => (await heading.boundingBox())!.y,
            { timeout: 15000 }).toBeLessThan(120);
    });
});
