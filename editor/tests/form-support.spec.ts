import { test, expect } from '@playwright/test';

// The forms and views for people who state facts rather than write rules,
// on a program whose templates all come from the resources it includes
// (examples/RulesRus/customs/by_hand.le includes the tariff):
// - the Scenario Editor, opened before the program has loaded, still offers
//   the included templates; each blank suggests the values the rules read
//   there; a fact takes the passage that states it ("confer …");
// - Scenario Variations makes such a scenario's facts editable rows;
// - the executive view opens an answer on its cited steps, each one tap from
//   the passage it cites.
test.describe('Forms and views for stating facts', () => {
    test('Scenario Editor: included templates, value suggestions, a citation', async ({ page, context }) => {
        test.setTimeout(120000);
        await context.grantPermissions(['clipboard-read', 'clipboard-write']);
        await page.goto('index.html?example=RulesRus/customs/by_hand');
        await page.waitForSelector('.monaco-editor', { timeout: 30000 });
        // no load yet: the menu entry loads the program before opening the window
        const [se] = await Promise.all([
            context.waitForEvent('page', { timeout: 90000 }),
            page.evaluate(() => (document.getElementById('menu-scenario-editor') as HTMLElement).click()),
        ]);
        await se.waitForLoadState();
        await expect(se.locator('#add-template option', { hasText: 'the fabric construction of a garment is a construction' }))
            .toHaveCount(1, { timeout: 30000 });

        await se.fill('#scenario-name', 'trial');
        await se.fill('#scenario-provenance', 'as stated in ruling NY N345059');
        await se.selectOption('#add-template', { label: 'the fabric construction of a garment is a construction' });
        await se.click('#btn-add');
        const row = se.locator('#rows .fact-row').last();
        await row.locator('input.field').nth(0).fill('style THW14690');
        const value = row.locator('input.field').nth(1);
        const listId = await value.getAttribute('list');
        expect(listId).toBeTruthy();
        const suggestions = await se.evaluate((id) =>
            [...(document.getElementById(id as string) as HTMLDataListElement).options].map(o => o.value), listId);
        expect(suggestions).toEqual(['felt', 'knitted', 'lace', 'nonwoven', 'woven']);
        await value.fill('knitted');

        // the passage, typed bare, becomes the fact's `confer "…"`
        await row.locator('button.cite-toggle').click();
        await row.locator('input.cite-field').fill('a women’s knit sweater constructed from 100 percent cashmere yarn');
        await se.locator('#btn-copy').click();
        const text = await se.evaluate(() => navigator.clipboard.readText());
        expect(text).toContain('scenario trial is, as stated in ruling NY N345059:');
        expect(text).toContain('the fabric construction of style THW14690 is knitted, confer "a women’s knit sweater constructed from 100 percent cashmere yarn".');
    });

    test('Scenario Variations: the facts of included templates are editable rows', async ({ page, context }) => {
        test.setTimeout(120000);
        await page.goto('/executive?program=RulesRus/customs/plastics_cbp&scenario=ny_n363253&query=subheading');
        await expect(page.locator('#answers .answer').first()).toBeVisible({ timeout: 90000 });
        const [sv] = await Promise.all([context.waitForEvent('page'), page.click('#tool-variations')]);
        await sv.waitForLoadState();
        await expect(sv.locator('#rows input.field').first()).toBeVisible({ timeout: 60000 });
        await expect(sv.locator('#title')).toHaveText('Scenario variations for plastics cbp');
        expect(await sv.locator('#rows input.field').count()).toBeGreaterThan(2);
    });

    test('Executive view: the cited steps first, each opening its passage', async ({ page }) => {
        test.setTimeout(120000);
        await page.goto('/executive?program=RulesRus/customs/cbp_62&scenario=ny_n346508&query=subheading');
        const answer = page.locator('#answers .answer').first();
        await expect(answer).toBeVisible({ timeout: 90000 });
        await answer.locator('.answer-head').click();
        const steps = answer.locator('.cite-list > li');
        await expect(steps.first()).toContainText('the subheading of the silk scarves is 6214.10');
        // the table row that gave the subheading cites the tariff's line
        const row = steps.filter({ hasText: 'row w93 of table woven' });
        await expect(row.locator('.cite')).toContainText('HTSUS Chapter 62');
        await expect(row.locator('.cite')).toContainText('Of silk or silk waste:6214.10');
        // a fact's step reads without its trailers; its citation says where
        const fact = steps.filter({ hasText: 'the kind of the silk scarves is scarf' });
        await expect(fact.locator('.lit')).toHaveText('the kind of the silk scarves is scarf');
        await expect(fact.locator('.cite')).toContainText('ruling NY N346508');
        // § opens the passage in the ruling's text
        await row.locator('button.src').click();
        const viewer = page.locator('#source-viewer');
        await expect(viewer.locator('mark')).toHaveText('Of silk or silk waste:6214.10', { timeout: 30000 });
        await viewer.locator('button.primary').click();
        // the whole explanation is still there, folded — and reachable from the
        // top of the citations, however long their list
        const full = answer.locator('details.full');
        await expect(full.locator('> summary')).toBeVisible();
        expect(await full.evaluate((d: any) => d.open)).toBe(false);
        await answer.locator('.cites-head a.to-full').click();
        expect(await full.evaluate((d: any) => d.open)).toBe(true);
    });

    // A browser that kept the executive page from before views existed runs the
    // new script on it: the missing places are added, the program still opens.
    test('Executive view: a page without the places of views still opens', async ({ page }) => {
        test.setTimeout(120000);
        let stale = false;
        await page.route((url: URL) => url.pathname === '/executive', async (route) => {
            const resp = await route.fetch();
            const html = (await resp.text())
                .replace(/<nav id="view-links"[^>]*><\/nav>/, '')
                .replace(/<div id="view-root" hidden><\/div>/, '')
                .replace('<div id="default-screen">', '<div>');
            stale = !/view-links|view-root|default-screen/.test(html);
            await route.fulfill({ response: resp, body: html });
        });
        await page.goto('/executive?program=RulesRus/flip_housing&view=benefit%20check');
        expect(stale).toBe(true);
        await expect(page.locator('#view-root .lv-ask')).toBeVisible({ timeout: 90000 });
    });
});
