import { test, expect } from '@playwright/test';

// LE Views (docs/le_summary.md §17.10): a program's view sections, rendered by
// the executive view with generic widgets (editor/src/le-views.ts), and the LE
// Assistant's "Generate LE view".
const ready = async (page: any) => {
    await page.waitForFunction(() => {
        const r = document.getElementById('view-root');
        return r && !r.hidden && r.querySelector('.lv-card, .lv-interview') && !/Running…|Searching…/.test(r.innerText);
    }, null, { timeout: 90000 });
};

test.describe('LE Views', () => {
    test('a program lists its views; the claim desk shows its widgets', async ({ page }) => {
        test.setTimeout(240000);
        await page.goto('/executive?program=RulesRus/eu261_integration');
        await expect(page.locator('#view-links a', { hasText: 'Passenger claim desk' })).toBeVisible({ timeout: 60000 });

        await page.goto('/executive?program=RulesRus/eu261_integration&view=claim%20desk');
        await ready(page);
        const root = page.locator('#view-root');
        // the result, headed by the amount, in euros
        await expect(root.locator('[data-widget="result"] .lv-big').first()).toContainText('250', { timeout: 60000 });
        await expect(root.locator('[data-widget="result"]')).toContainText('euros');
        // the stage: the three sections passed
        await expect(root.locator('[data-widget="stage"] .lv-ok')).toHaveCount(3);
        // the fact groups, and the fact the case does not state
        await expect(root.locator('.lv-grp', { hasText: 'the booking' })).toBeVisible();
        await expect(root.locator('.lv-absent', { hasText: 'is notified of the cancellation' })).toBeVisible();
        // every fact shows who states it: the carrier's facts carry its name
        await expect(root.locator('.lv-grp + div .lv-who', { hasText: 'Alitalia' }).first()).toBeVisible();
        // a table of another query's answers
        // (the widgets that run queries of their own render after the result)
        await expect(root.locator('[data-widget="tables"] td', { hasText: 'the inspection defect' })).toBeVisible({ timeout: 90000 });
        // the comparison with another scenario
        await expect(root.locator('[data-widget="compare"]')).toContainText('bird_strike', { timeout: 90000 });
        await expect(root.locator('[data-widget="compare"]')).toContainText('fails at question', { timeout: 90000 });
        // the cited steps reach the Court's reasoning
        await expect(root.locator('[data-widget="citations"]')).toContainText('C-549/07');
    });

    test('an interview asks one question at a time and flips the answer', async ({ page }) => {
        test.setTimeout(120000);
        await page.setViewportSize({ width: 480, height: 900 });
        await page.goto('/executive?program=RulesRus/flip_housing&view=benefit%20check');
        await ready(page);
        const ask = page.locator('.lv-ask');
        const answer = async (a: string) => {
            await page.locator('.lv-bigbtn', { hasText: new RegExp(`^${a}$`) }).click();
            await page.waitForTimeout(300);
        };
        await expect(ask).toHaveText('Do you receive other benefits?');
        await answer('No');
        await expect(ask).toHaveText('Do you work part-time?', { timeout: 30000 });
        await answer('Yes');
        await expect(ask).toHaveText('Do you work full-time on a low income?', { timeout: 30000 });
        await answer('No');
        await expect(ask).toHaveText('Is your income low?', { timeout: 30000 });
        await answer('No');
        const root = page.locator('#view-root');
        await expect(root.locator('.lv-res.no')).toHaveText('You cannot get help to pay your rent, on what you told us.', { timeout: 30000 });
        await expect(root).toContainText('Do you work part-time? — yes');
        await expect(root).toContainText('Answering yes to “Is your income low?”', { timeout: 60000 });
    });

    test('what is missing: a fact stated from the question runs only once its value is in', async ({ page }) => {
        test.setTimeout(180000);
        await page.goto('/executive?program=RulesRus/sections_benefit&view=rent%20help');
        const root = page.locator('#view-root');
        await expect(root.locator('.lv-card').first()).toBeVisible({ timeout: 90000 });
        await root.locator('select').first().selectOption('no_rent');
        const stateIt = root.locator('[data-widget="questions"] .lv-chip', { hasText: 'Yes, state it' });
        await expect(stateIt).toBeVisible({ timeout: 60000 });
        await stateIt.click();
        // the new row reads "the rent of dee is an amount" until a value is typed:
        // not a fact about every amount, so still no answer (not "…is _123/2")
        const rent = root.locator('.fact-row').last().locator('input.field').last();
        await expect(rent).toHaveValue('an amount');
        await page.waitForTimeout(2500);
        await expect(root.locator('[data-widget="result"]')).toContainText('No answer', { timeout: 30000 });
        await expect(root.locator('[data-widget="result"]')).not.toContainText('_');
        await rent.fill('800');
        await expect(root.locator('[data-widget="result"] .lv-big').first()).toHaveText('400', { timeout: 60000 });
    });

    test('a program without views offers its automatic view, drawn when opened', async ({ page }) => {
        test.setTimeout(120000);
        await page.goto('/executive?program=citizenship');
        const chip = page.locator('#view-links a', { hasText: 'Automatic view' });
        await expect(chip).toBeVisible({ timeout: 60000 });
        // the plain screen still runs as before
        await expect(page.locator('#answers .answer').first()).toBeVisible({ timeout: 60000 });
        await chip.click();
        await expect(page).toHaveURL(/view=\*/);
        await expect(page.locator('#view-links .auto-note')).toBeVisible({ timeout: 60000 });
        await expect(page.locator('#title')).toHaveText('Citizenship');
        await expect(page.locator('#view-root [data-widget="result"]')).toBeVisible({ timeout: 60000 });
        await expect(page.locator('#view-root .lv-grp', { hasText: 'the case' })).toBeVisible();
        // a program with views of its own: those, no automatic one
        await page.goto('/executive?program=RulesRus/sections_benefit');
        await expect(page.locator('#view-links a', { hasText: 'Help with the rent' })).toBeVisible({ timeout: 60000 });
        await expect(page.locator('#view-links a', { hasText: 'Automatic view' })).toHaveCount(0);
    });

    test('Misc > Open Executive View opens the program as it is in the editor, unsaved', async ({ page, context }) => {
        test.setTimeout(120000);
        await page.goto('index.html?example=RulesRus/sections_benefit&scenario=no_rent&query=help');
        await expect.poll(async () => page.locator('#scenario-select option').count(), { timeout: 60000 }).toBeGreaterThan(1);
        await expect(page.locator('#scenario-select')).toHaveValue('no_rent');
        const open = async () => {
            const [p] = await Promise.all([
                context.waitForEvent('page'),
                page.evaluate(() => (document.getElementById('menu-open-executive') as HTMLElement).click()),
            ]);
            await p.waitForLoadState();
            return p;
        };
        // on the scenario and query picked here
        const first = await open();
        expect(first.url()).toContain('/executive?program=RulesRus%2Fsections_benefit&text=');
        expect(first.url()).toContain('&scenario=no_rent&query=help');
        await first.close();
        // an edit not saved: the view's title
        await page.evaluate(() => {
            const model = (window as any).monaco.editor.getEditors()[0].getModel();
            model.setValue(model.getValue().replace('the title is "Help with the rent".', 'the title is "Rent desk, unsaved".'));
        });
        const exec = await open();
        await expect(exec.locator('#view-links a', { hasText: 'Rent desk, unsaved' })).toBeVisible({ timeout: 60000 });
        // the view's link keeps the editor's copy
        await exec.locator('#view-links a', { hasText: 'Rent desk, unsaved' }).click();
        await expect(exec.locator('#title')).toHaveText('Rent desk, unsaved', { timeout: 60000 });
        await expect(exec.locator('#view-root .lv-card').first()).toBeVisible({ timeout: 60000 });
    });

    test('Generate LE view drafts a view at the end of the program', async ({ page }) => {
        test.setTimeout(120000);
        page.on('dialog', d => d.dismiss());
        await page.goto('index.html?example=RulesRus/sections_benefit');
        await page.waitForSelector('.monaco-editor', { timeout: 30000 });
        await page.click('.tab[data-tab="assistant-tab"]');
        await page.click('#btn-generate-view');
        await expect(page.locator('#assistant-history')).toContainText('I drafted a view', { timeout: 90000 });
        const text = await page.evaluate(() => (window as any).monaco.editor.getEditors()[0].getModel().getValue());
        const draft = text.slice(text.lastIndexOf('the view sections benefit is:'));
        expect(draft).toContain('the result is the answer to query help.');
        expect(draft).toContain('the result shows the stage it reaches.');
        expect(draft).toContain('a person is on a low income');
        await expect(page.locator('#assistant-input')).toHaveValue(/Refine the view section/);
        // the drafted view, unsaved, on the executive view
        const [exec] = await Promise.all([
            page.context().waitForEvent('page'),
            page.locator('#assistant-history a', { hasText: 'Open the view' }).last().click(),
        ]);
        await exec.waitForLoadState();
        expect(exec.url()).toMatch(/&view=sections(\+|%20)benefit/);
        await expect(exec.locator('#title')).toHaveText('Sections benefit', { timeout: 60000 });
        await expect(exec.locator('#view-root [data-widget="result"]')).toBeVisible({ timeout: 60000 });
        await expect(exec.locator('#view-root .lv-grp', { hasText: 'the case' })).toBeVisible();
    });
});
