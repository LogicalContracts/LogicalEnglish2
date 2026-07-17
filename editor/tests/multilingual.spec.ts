// The /multilingual entry point: a language picker (or ?lang=<code>) leading
// to a landing page circumscribed to that language — only the examples of
// examples/<lang>/, chrome strings in that language — with a link back to the
// standard (English) landing page. Driven by i18n/languages.csv, i18n/ui.csv
// and the per-language example trees.
import { test, expect } from '@playwright/test';

test.describe('/multilingual entry point', () => {
    test('language picker lists the per-language landing pages', async ({ page }) => {
        await page.goto('/multilingual');
        await expect(page.locator('h1')).toHaveText('Logical English — Multilingual');
        await expect(page.locator('a[href="/multilingual?lang=pt"]')).toHaveText('Português Lógico');
        await expect(page.locator('a[href="/multilingual?lang=es"]')).toHaveText('Español Lógico');
        await expect(page.locator('#le-back-english')).toHaveText('Logical English (in English)');
    });

    test('Portuguese landing page: localized chrome, only pt examples', async ({ page }) => {
        await page.goto('/multilingual?lang=pt');
        await expect(page.locator('h1')).toHaveText('Português Lógico 2.0');
        // Chrome strings come from the pt column of i18n/ui.csv.
        await expect(page.locator('body')).toContainText('Editar e consultar:');
        // Examples are the examples/pt/ tree only, opened as pt/<name>.
        const exampleLinks = page.locator('ul ul a');
        expect(await exampleLinks.count()).toBeGreaterThan(0);
        for (const href of await exampleLinks.evaluateAll(
            as => as.map(a => a.getAttribute('href')))) {
            expect(href).toContain('/editor/index.html?example=pt/');
        }
        // Visiting the page makes pt the UI-language preference.
        expect(await page.evaluate(() => localStorage.getItem('le-ui-lang'))).toBe('pt');
        // Back link to the standard English page, and links to the other languages.
        await expect(page.locator('#le-back-english')).toHaveText('Logical English (em inglês)');
        await expect(page.locator('a[href="/multilingual?lang=es"]')).toBeAttached();
    });

    test('opens a Portuguese example in the editor, in Portuguese', async ({ page }) => {
        await page.goto('/multilingual?lang=pt');
        await page.click('a[href="/editor/index.html?example=pt/cidadania"]');
        // The pt/<name> example resolves to examples/pt/<name>.le ...
        await expect(page.locator('#filename-display')).toHaveText('pt/cidadania.le');
        await expect.poll(async () =>
            await page.evaluate(() => (window as any).monaco?.editor?.getModels?.()[0]?.getValue() || '')
        ).toContain('a linguagem alvo é');
        // ... and the editor chrome follows the preference set by the landing page,
        // with the Home link returning to that same landing page.
        await expect(page.locator('#menu-save-as')).toHaveText('Guardar como...');
        await expect(page.locator('a.home-link')).toHaveAttribute('href', '/multilingual?lang=pt');
    });

    // Scenario/query blocks are recognised in the program's own language (the
    // client-side block parsers used to be English-only, so a Spanish program's
    // scenarios never reached the Scenario Variations window).
    test('Spanish scenarios are recognised in Scenario Variations', async ({ page }) => {
        test.setTimeout(120000);
        await page.goto('/editor/index.html?example=es/conjuntos&scenario=hechos&query=subconjunto');
        await expect(page.locator('#filename-display')).toHaveText('es/conjuntos.le');
        await expect(async () => {
            expect(await page.locator('#scenario-select option').count()).toBeGreaterThan(2);
        }).toPass({ timeout: 45000 });
        await expect(page.locator('#scenario-select')).toHaveValue('hechos');
        await expect(page.locator('#query-select')).toHaveValue('subconjunto');
        const [v] = await Promise.all([
            page.waitForEvent('popup'),
            page.click('#btn-variations'),
        ]);
        await v.waitForLoadState();
        // Both es scenarios are listed, the selected one preloaded as fact rows.
        await expect(v.locator('#scenario-picker')).toHaveValue('hechos');
        await expect(v.locator('#scenario-picker option', { hasText: 'listas' })).toHaveCount(1);
        await expect(v.locator('.fact-row .word', { hasText: 'pertenece a' }).first()).toBeVisible();
    });

    test('back link resets the preference to English', async ({ page }) => {
        await page.goto('/multilingual?lang=pt');
        await page.click('#le-back-english');
        await expect(page.locator('h2').first()).toHaveText('Documentation');
        expect(await page.evaluate(() => localStorage.getItem('le-ui-lang'))).toBe('en');
    });
});
