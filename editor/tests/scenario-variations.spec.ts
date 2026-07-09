import { test, expect } from '@playwright/test';

// Loads the citizenship example into the editor and opens the Scenario Variations
// window from the "Variations" button, returning the popup page.
async function openVariations(page: any): Promise<any> {
    await page.goto('index.html');
    // The examples dropdown populates from a server fetch that can be slow when
    // the shared Prolog server is under parallel-test load; if it has not
    // appeared, close and reopen the menu to retry the fetch.
    const item = page.locator('#example-list .dropdown-item', { hasText: /^citizenship$/ });
    await page.click('text=File');
    await page.click('#menu-open-server');
    await expect(async () => {
        if (!(await item.isVisible())) {
            await page.keyboard.press('Escape');
            await page.click('text=File');
            await page.click('#menu-open-server');
        }
        await expect(item).toBeVisible({ timeout: 5000 });
    }).toPass({ timeout: 45000 });
    await item.click();
    await expect(page.locator('#filename-display')).toHaveText('citizenship.le');
    // Module loads proactively: scenario-select gains options.
    await expect(async () => {
        expect(await page.locator('#scenario-select option').count()).toBeGreaterThan(1);
    }).toPass({ timeout: 20000 });
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
        test.setTimeout(120000);
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
        test.setTimeout(120000);
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

    test('Add Query excludes already-added queries', async ({ page }) => {
        test.setTimeout(120000);
        const v = await openVariations(page);

        // Citizenship has a single query 'one', already seeded — so the Add Query
        // picker offers nothing and is disabled (a query can't be added twice).
        await expect(v.locator('.query-card')).toHaveCount(1);
        await expect(v.locator('#add-query option')).toHaveCount(0);
        await expect(v.locator('#btn-add-query')).toBeDisabled();

        // Removing the query frees it up: the picker offers it again and can re-add it.
        await v.locator('.query-card .query-remove').first().click();
        await expect(v.locator('.query-card')).toHaveCount(0);
        expect(new URL(v.url()).searchParams.get('queries')).toBe('');
        await expect(v.locator('#btn-add-query')).toBeEnabled();
        await expect(v.locator('#add-query option')).toHaveCount(1);

        await v.locator('#add-query').selectOption('one');
        await v.locator('#btn-add-query').click();
        await expect(v.locator('.query-card')).toHaveCount(1);
        expect(new URL(v.url()).searchParams.get('queries')).toBe('one');
    });

    test('Patch scenario / Assume fact from explanation nodes', async ({ page }) => {
        test.setTimeout(120000);
        const v = await openVariations(page);

        // Run query "one" against scenario "alice" — it succeeds, so the explanation
        // is a tree of green (succeeded) nodes.
        await v.locator('#btn-run').click();
        await expect(v.locator('.query-card .answer-item').first()).toContainText(
            'John acquires British citizenship', { timeout: 30000 });

        const rowsBefore = await v.locator('.fact-row').count();
        await expect(v.locator('.fact-row', { hasText: 'is the mother of' })).toHaveCount(1);

        // Right-click the succeeded "Alice is the mother of John" node: the menu offers
        // "Patch scenario — delete this fact" but NOT "Assume fact" (succeeded node).
        const motherNode = v.locator('.query-card .tree-label', { hasText: 'is the mother of' }).first();
        await motherNode.click({ button: 'right' });
        const patch = v.locator('#menu-patch-scenario');
        await expect(patch).toBeVisible();
        await expect(patch).toHaveText(/delete this fact/);
        await expect(v.locator('#menu-assume-fact')).toBeHidden();

        // Deleting removes the matching scenario fact row AND auto-re-runs the query:
        // without the mother (and no father) fact, John no longer acquires citizenship,
        // so the query now fails — a red (failed) node — with no manual Query click.
        await patch.click();
        await expect(v.locator('.fact-row', { hasText: 'is the mother of' })).toHaveCount(0);
        await expect(v.locator('.fact-row')).toHaveCount(rowsBefore - 1);
        await expect(v.locator('.query-card .answer-item.failure')).toContainText(
            'No answers', { timeout: 30000 });

        // Right-click the failed node: the menu offers "Patch scenario — add this fact"
        // AND "Assume fact" (both, for a failed node).
        const failNode = v.locator('.query-card .tree-label.failure').first();
        await failNode.click({ button: 'right' });
        await expect(patch).toHaveText(/add this fact/);
        const assume = v.locator('#menu-assume-fact');
        await expect(assume).toBeVisible();

        // "Assume fact" adds the fact as an assumed unknown, selects (highlights) the
        // new row, and auto-re-runs the query.
        await assume.click();
        const assumedRow = v.locator('.fact-row.assumed');
        await expect(assumedRow).toHaveCount(1);
        await expect(assumedRow).toHaveClass(/selected/);
        await expect(v.locator('#status')).toContainText('Ran', { timeout: 30000 });
    });

    test('Delete matches date facts and skips derived nodes (alice_harry)', async ({ page }) => {
        test.setTimeout(120000);
        const v = await openVariations(page);

        // Switch to alice_harry, whose proof of "one" mixes date-bearing scenario facts
        // (born/settled) with a rule-derived node ("Harry is the father of John").
        await v.selectOption('#scenario-picker', 'alice_harry');
        await expect(v.locator('.fact-row', { hasText: 'is born in' })).toHaveCount(1);
        await v.locator('#btn-run').click();
        await expect(v.locator('.query-card .answer-item').first()).toContainText(
            'John acquires British citizenship', { timeout: 30000 });

        const patch = v.locator('#menu-patch-scenario');

        // The rule-derived "Harry is the father of John" node is green but is NOT a
        // scenario fact, so it offers no "delete this fact".
        const derived = v.locator('.query-card .tree-text').filter({ hasText: /^Harry is the father of John$/ }).first();
        await derived.click({ button: 'right' });
        await expect(patch).toBeHidden();
        await page.keyboard.press('Escape');

        // The date-bearing scenario fact "John is born in the UK on 2021-10-09" renders in
        // the explanation as "…2021-10-9T0:0:0.0"; delete must still match it (date-tolerant)
        // and, being required for citizenship, its removal auto-re-runs the query to failure.
        const bornNode = v.locator('.query-card .tree-text').filter({ hasText: /is born in the UK/ }).first();
        await bornNode.click({ button: 'right' });
        await expect(patch).toBeVisible();
        await expect(patch).toHaveText(/delete this fact/);
        await patch.click();
        await expect(v.locator('.fact-row', { hasText: 'is born in' })).toHaveCount(0);
        await expect(v.locator('.query-card .answer-item.failure')).toContainText(
            'No answers', { timeout: 30000 });
    });

});
