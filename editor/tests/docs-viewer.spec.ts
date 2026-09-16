import { test, expect } from '@playwright/test';

// The server renders the repo's docs cleanly (no repo chrome) at /docs/<name>,
// client-side with marked.js, serving sibling images from the same tree.
test.describe('Docs viewer', () => {
    test('renders the syntax reference from Markdown', async ({ page }) => {
        await page.goto('/docs/user/reference/language');
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
        await page.goto('/docs/user/tutorials/intro-to-le/intro-to-le');
        await expect(page.locator('#content h1').first()).toContainText('Gentle Introduction');
        // A relative screenshot (e.g. 01-editor-overview.png) must resolve under
        // /docs/user/tutorials/intro-to-le/ and actually load (naturalWidth > 0).
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
        await page.goto('/docs/user/tutorials/intro-to-le/intro-to-le#10-explanation-preferences-and-the-explanation-drill');
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
        await page.goto('/docs/user/tutorials/intro-to-le/intro-to-le');
        await page.click('a[href="#9-why-not-failure-explanations"]');
        await expect(page).toHaveURL(/#9-why-not-failure-explanations$/);
        const heading = page.locator('[id="9-why-not-failure-explanations"]');
        await expect.poll(async () => (await heading.boundingBox())!.y,
            { timeout: 15000 }).toBeLessThan(120);
    });

    test('only the published documents are served', async ({ request }) => {
        // docs/ also holds developer and project documents and private notes:
        // /docs/ serves docs/user only (classic_web_api.pl public_doc/1).
        expect((await request.get('/docs/user/reference/language.md')).status()).toBe(200);
        expect((await request.get('/docs/user/tutorials/intro-to-le/01-editor-overview.png')).status()).toBe(200);
        for (const hidden of ['/docs/vibeCodingNotes', '/docs/vibeCodingNotes.md',
                              '/docs/project/papers/LE2paperDraft.md', '/docs/dev/assistant',
                              '/docs/project/plans/sCASP_plan']) {
            expect((await request.get(hidden)).status(), hidden).toBe(404);
        }
    });

    test('old addresses redirect to where the documents are now', async ({ page }) => {
        await page.goto('/docs/le_summary');
        await expect(page).toHaveURL(/\/docs\/user\/reference\/language$/);
        await expect(page.locator('#content h1').first()).toContainText('Logical English');
    });

    test('a sidebar lists the documentation, and links between documents open rendered', async ({ page }) => {
        await page.goto('/docs/user/guide/editor');
        await expect(page.locator('#toc a.current')).toHaveText('How to use the LE2 web application');
        await expect(page.locator('#toc a', { hasText: 'Logical English syntax summary' }))
            .toHaveAttribute('href', '/docs/user/reference/language');
        // editor.md links ../tutorials/views.md: rendered, without .md
        await expect(page.locator('#content a[href^="/docs/user/tutorials/views"]').first()).toBeVisible();
    });
});
