import { test, expect } from '@playwright/test';

// The documentation's full-text search (web_extras/docsview/docs-extras.js),
// "Documentation for this" in the editor's context menu (src/doc-for-this.ts),
// and the integrations map with its links to the LPS2 IDE.
test.describe('Documentation search', () => {
    test('finds sections, best first, linking to their headings', async ({ page }) => {
        await page.goto('/docs/search?q=variables');
        await expect(page.locator('.docs-search-status')).toContainText(/\d+ sections in \d+ documents/, { timeout: 20000 });
        const first = page.locator('.docs-search-results li a').first();
        await expect(first).toHaveAttribute('href', /^\/docs\/user\/reference\/language#/);
        await expect(first).toContainText(/Variable/);
        await expect(page.locator('.docs-search-snippet mark').first()).toBeVisible();
    });

    test('is deterministic, and a quoted phrase must occur as written', async ({ page }) => {
        const hrefs = async (q: string) => {
            await page.goto('/docs/search?q=' + encodeURIComponent(q));
            await expect(page.locator('.docs-search-status')).not.toHaveText(/Searching/, { timeout: 20000 });
            return page.locator('.docs-search-results li a').evaluateAll(as => as.map(a => a.getAttribute('href')));
        };
        const once = await hrefs('explanation tree');
        expect(once.length).toBeGreaterThan(0);
        expect(await hrefs('explanation tree')).toEqual(once);
        expect((await hrefs('"tree explanation zebra"')).length).toBe(0);
    });

    test('the landing page and every document have a search box', async ({ page }) => {
        await page.goto('/');
        await expect(page.locator('form[action="/docs/search"] input[name=q]')).toBeVisible();
        await page.goto('/docs/user/guide/editor');
        await page.fill('header.docbar input[name=q]', 'scenario');
        await page.press('header.docbar input[name=q]', 'Enter');
        await expect(page).toHaveURL(/\/docs\/search\?q=scenario/);
        await expect(page.locator('.docs-search-results li').first()).toBeVisible({ timeout: 20000 });
    });

    test('Documentation for this searches by the class of the token', async ({ page, context }) => {
        await page.goto('index.html');
        await page.waitForFunction(() => (window as any).monaco?.editor.getEditors().length > 0);
        const ask = async (line: number, column: number) => {
            const popup = context.waitForEvent('page');
            await page.evaluate(({ line, column }) => {
                const ed = (window as any).monaco.editor.getEditors()[0];
                ed.setValue('the templates are:\n*a person* is happy on *a date*.\n\nthe knowledge base k includes:\n'
                    + 'a person X is happy on 2024-01-01\n    if it is not the case that\n        X is sad.\n');
                ed.setPosition({ lineNumber: line, column });
                ed.getSupportedActions().find((a: any) => /documentation-for-this$/.test(a.id)).run();
            }, { line, column });
            const p = await popup;
            const params = new URL(p.url()).searchParams;
            await p.close();
            return params.get('q');
        };
        expect(await ask(5, 10)).toBe('variables');                     // X
        expect(await ask(5, 28)).toBe('dates');                         // 2024-01-01
        expect(await ask(6, 22)).toBe('"it is not the case that"');     // a keyword
        expect(await ask(5, 17)).toBe('templates');                     // happy
    });

    test('the integrations map is drawn, its nodes link to documents and to the LPS2 IDE', async ({ page }) => {
        await page.goto('/docs/user/integrations/index');
        const svg = page.locator('.docs-diagram svg');
        await expect(svg).toBeVisible({ timeout: 30000 });
        const links = await page.locator('.docs-diagram a').evaluateAll(as =>
            as.map(a => a.getAttribute('xlink:href') || a.getAttribute('href')));
        expect(links).toContain('miniscript');
        // Canonical lps2.logicalcontracts.com links become the peer IDE's
        // address: on localhost, LPS2's default port.
        expect(links.some(l => /^http:\/\/localhost:3060\/docs\/user\/integrations\/drools$/.test(l ?? ''))).toBe(true);
    });

    test('the old import-export guide redirects to the integrations overview', async ({ page }) => {
        await page.goto('/docs/user/guide/import-export');
        await expect(page).toHaveURL(/\/docs\/user\/integrations\/index$/);
    });
});
