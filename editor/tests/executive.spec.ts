import { test, expect, devices } from '@playwright/test';

// The minimalist mobile-first "executive" entry point at /executive.
// Emulate a phone so the mobile layout and tap flow are what's exercised.
test.use({ ...devices['iPhone 13'] });

test.describe('Executive view', () => {
    test('shows the login affordance top-right', async ({ page }) => {
        await page.goto('/executive?program=citizenship');
        // Anonymous session: a Login link that returns to this page.
        const login = page.locator('#auth a', { hasText: 'Login' });
        await expect(login).toBeVisible();
        await expect(login).toHaveAttribute('href', /\/login\?return=/);
    });

    test('menu lists programs and filters', async ({ page }) => {
        await page.goto('/executive');
        await expect(page.locator('#screen-menu')).toBeVisible();
        await expect(page.locator('#menu-list li.item')).not.toHaveCount(0);

        // The citizenship example is present; filtering narrows to it.
        await page.fill('#menu-filter', 'citizenship');
        const items = page.locator('#menu-list li.item a');
        await expect(items.first()).toBeVisible();
        for (const t of await items.allTextContents()) expect(t).toContain('citizenship');
    });

    test('opens on the first scenario and auto-runs, with the explanation', async ({ page }) => {
        await page.goto('/executive?program=citizenship');
        await expect(page.locator('#screen-program')).toBeVisible();
        await expect(page.locator('#title')).toHaveText('citizenship');

        // There is no Run button; the first scenario is pre-selected and the
        // query runs on load (no user interaction required).
        await expect(page.locator('#run-btn')).toHaveCount(0);
        await expect(page.locator('#scenario-select')).toHaveValue('alice');

        const answer = page.locator('.answer .answer-text').first();
        await expect(answer).toBeVisible({ timeout: 30000 });
        await expect(answer).toContainText('John acquires British citizenship');

        // Tapping the answer reveals its explanation tree.
        await page.locator('.answer-head').first().click();
        await expect(page.locator('.answer.open .tree li').first()).toBeVisible();
        await expect(page.locator('.answer.open .tree')).toContainText('Alice is the mother of John');

        // Selection is reflected in the URL for sharing.
        const u = new URL(page.url());
        expect(u.searchParams.get('scenario')).toBe('alice');
        expect(u.searchParams.get('query')).toBe('one');
    });

    test('a full deep link runs automatically', async ({ page }) => {
        await page.goto('/executive?program=citizenship&scenario=alice&query=one');
        const answer = page.locator('.answer .answer-text').first();
        await expect(answer).toBeVisible({ timeout: 30000 });
        await expect(answer).toContainText('John acquires British citizenship');
    });

    test('the back link returns to the program menu', async ({ page }) => {
        await page.goto('/executive?program=citizenship');
        await expect(page.locator('#screen-program')).toBeVisible();
        await page.click('#back-link');
        await expect(page.locator('#screen-menu')).toBeVisible();
    });

    test('Scenario Variations (between the pickers) opens with the program loaded', async ({ page, context }) => {
        await page.goto('/executive?program=citizenship');
        const varBtn = page.locator('#tool-variations');
        await expect(varBtn).toBeVisible();

        // It sits between the Scenario picker and the Question picker.
        const order = await page.evaluate(() => {
            const ids = [...document.querySelectorAll('#screen-program *')]
                .filter(el => ['scenario-select', 'tool-variations', 'query-select'].includes(el.id))
                .map(el => el.id);
            return ids;
        });
        expect(order).toEqual(['scenario-select', 'tool-variations', 'query-select']);

        // Opens the editor's variations window on this program.
        const [varWin] = await Promise.all([
            context.waitForEvent('page'),
            varBtn.click(),
        ]);
        expect(varWin.url()).toContain('/editor/scenario-variations.html');
        const varData = JSON.parse(await page.evaluate(() =>
            localStorage.getItem('le_scenario_variations_data') || '{}'));
        expect(varData.source).toContain('British citizen');
        expect(Array.isArray(varData.queries)).toBe(true);
        await varWin.close();

        // Query Editor was removed.
        await expect(page.locator('#tool-query-editor')).toHaveCount(0);
    });
});
