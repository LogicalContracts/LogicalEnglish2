import { test, expect } from '@playwright/test';

// Loads the citizenship example into the editor and opens the Scenario Variations
// window from the "Variations" button, returning the popup page.
async function openVariations(page: any): Promise<any> {
    await page.goto('index.html');
    await page.click('text=File');
    await page.click('#menu-open-server');
    const item = page.locator('#example-list .dropdown-item', { hasText: /^citizenship$/ });
    await expect(item).toBeVisible();
    await item.click();
    await expect(page.locator('#filename-display')).toHaveText('citizenship.le');
    // Module loads proactively: scenario-select gains options.
    await expect(async () => {
        expect(await page.locator('#scenario-select option').count()).toBeGreaterThan(1);
    }).toPass({ timeout: 10000 });
    // Preselect scenario "alice" and query "one" so the window seeds them.
    await page.selectOption('#scenario-select', 'alice');
    await page.selectOption('#query-select', 'one');
    const [popup] = await Promise.all([
        page.waitForEvent('popup'),
        page.click('#btn-variations'),
    ]);
    await popup.waitForLoadState();
    return popup;
}

test.describe('Scenario Variations', () => {
    test('alter a scenario and run a query against the variation', async ({ page, context }) => {
        test.setTimeout(60000);
        await context.grantPermissions(['clipboard-read', 'clipboard-write']);
        const v = await openVariations(page);

        // Title names the KB; the scenario picker is preselected with "alice".
        await expect(v.locator('#title')).toHaveText('Scenario variations for citizenship');
        await expect(v.locator('#scenario-picker')).toHaveValue('alice');

        // The scenario facts loaded as editable rows ("John is born in the UK …").
        const fields = v.locator('.fact-row input.field');
        await expect(fields.first()).toBeVisible();
        await expect(v.locator('.fact-row .word', { hasText: 'is born in' }).first()).toBeVisible();

        // The selected query was seeded as a card.
        await expect(v.locator('.query-card')).toHaveCount(1);
        await expect(v.locator('.query-card .query-name')).toContainText('one');

        // Run: the query's answers + explanation appear in the card.
        await v.locator('#btn-run').click();
        const answer = v.locator('.query-card .answer-item').first();
        await expect(answer).toBeVisible({ timeout: 30000 });
        await expect(answer).toContainText('John acquires British citizenship');
        await expect(v.locator('.query-card .tree-label').first()).toBeVisible();

        // After running, the Query button is disabled; editing re-enables it.
        await expect(v.locator('#btn-run')).toBeDisabled();

        // Editing a fact must take effect on the next run: changing who is born in the
        // UK from "John" to "Mary" (field 0 of the born fact) breaks John's only path
        // to citizenship, so the query that was true becomes false.
        await fields.nth(0).fill('Mary');
        await expect(v.locator('#btn-run')).toBeEnabled();
        await v.locator('#btn-run').click();
        const failure = v.locator('.query-card .answer-item.failure');
        await expect(failure).toBeVisible({ timeout: 30000 });
        await expect(failure).toContainText('No answers');

        // The URL captures the variation for sharing.
        const u = new URL(v.url());
        expect(u.searchParams.get('scenario')).toBe('alice');
        expect(u.searchParams.get('queries')).toBe('one');
        expect(u.searchParams.get('scenarioText') || '').toContain('is born in');

        // Copy Scenario puts a full block on the clipboard.
        await v.locator('#btn-copy-scenario').click();
        const copied = await v.evaluate(() => navigator.clipboard.readText());
        expect(copied).toContain('scenario alice is:');
        expect(copied).toContain('is born in');
    });

    test('uses its own session, distinct from the editor Query panel', async ({ page }) => {
        test.setTimeout(60000);
        let winSession = '';
        let edSession = '';
        const v = await openVariations(page);

        const grab = (r: any, set: (s: string) => void) => {
            if (r.url().includes('/leapi') && r.method() === 'POST') {
                try {
                    const d = JSON.parse(r.postData() || '{}');
                    if (d.operation === 'answeringQuery' && d.sessionModule) set(d.sessionModule);
                } catch { /* ignore */ }
            }
        };
        v.on('request', (r) => grab(r, (s) => (winSession = s)));
        page.on('request', (r) => grab(r, (s) => (edSession = s)));

        // Run a query in the variations window…
        await v.locator('#btn-run').click();
        await expect(v.locator('.query-card .answer-item').first()).toBeVisible({ timeout: 30000 });
        // …and one in the editor's Query panel (scenario/query already selected).
        await page.locator('#btn-query').click();
        await expect(page.locator('#answers-list .answer-item').first()).toBeVisible({ timeout: 30000 });

        // Each ran against its own session, so the editor reloading or its session being
        // reclaimed cannot break the variations window.
        expect(winSession).toBeTruthy();
        expect(edSession).toBeTruthy();
        expect(winSession).not.toBe(edSession);
    });

    test('Add Query and remove a query card', async ({ page }) => {
        test.setTimeout(60000);
        const v = await openVariations(page);

        // One query was seeded; add a second of the same query, then remove both.
        await expect(v.locator('.query-card')).toHaveCount(1);
        await v.locator('#add-query').selectOption('one');
        await v.locator('#btn-add-query').click();
        await expect(v.locator('.query-card')).toHaveCount(2);
        expect(new URL(v.url()).searchParams.get('queries')).toBe('one,one');

        await v.locator('.query-card .query-remove').first().click();
        await expect(v.locator('.query-card')).toHaveCount(1);
        await v.locator('.query-card .query-remove').first().click();
        await expect(v.locator('.query-card')).toHaveCount(0);
        expect(new URL(v.url()).searchParams.get('queries')).toBe('');
    });
});
