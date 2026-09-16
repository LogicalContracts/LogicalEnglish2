import { test, expect } from '@playwright/test';

// Contextual help: a "?" beside each part of the editor opens its section of
// the documentation, and a diagnostic's hover links to where it is explained.
test.describe('Contextual help', () => {
    test('every "?" of the editor and its pages opens an existing document', async ({ page, request }) => {
        const pages = ['index.html', 'scenario-editor.html', 'query-editor.html', 'scenario-variations.html',
                       'explanation-drill.html', 'proof-game.html', '/executive'];
        const hrefs = new Set<string>();
        for (const p of pages) {
            await page.goto(p);
            for (const h of await page.locator('a.help-link').evaluateAll(as => as.map(a => a.getAttribute('href')!))) {
                hrefs.add(h);
            }
        }
        expect(hrefs.size).toBeGreaterThanOrEqual(8);
        for (const h of hrefs) {
            const [path] = h.split('#');
            expect((await request.get(path + '.md')).status(), h).toBe(200);
        }
    });

    test('a diagnostic links to the section that explains it', async ({ page }) => {
        const prog = 'the target language is: prolog.\n\nthe templates are:\n*a person* is happy.\n\n' +
            'the knowledge base k includes:\na person is happy if\n    the person sings loudly.\n';
        await page.goto('index.html?text=' + encodeURIComponent(prog));
        // A program is loaded (and verified) when something asks for it: the pickers do.
        await page.hover('#scenario-select');
        await expect.poll(async () => page.evaluate(() => {
            const ms = (window as any).monaco?.editor?.getModelMarkers({}) ?? [];
            const m = ms.find((x: any) => x.code && typeof x.code === 'object');
            return m ? String(m.code.target) : '';
        }), { timeout: 30000 }).toContain('/docs/user/guide/warnings#');
    });

    test('a #sec- fragment scrolls the reference to that section', async ({ page }) => {
        await page.goto('/docs/user/reference/language#sec-17.10');
        const heading = page.locator('#content h3', { hasText: /^17\.10 / });
        await expect(heading).toBeVisible();
        await expect.poll(async () => (await heading.boundingBox())!.y, { timeout: 15000 }).toBeLessThan(150);
    });
});
