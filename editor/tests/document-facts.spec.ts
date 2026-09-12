import { test, expect } from '@playwright/test';

// "Write it in English…" from a document: the dialog fetches the text of a
// document beside the program, sends its name with the request, and the facts
// that come back — each citing its passage — load as editable rows with their
// provenance kept; the "where is the document" facts come along. The templates
// of included resources (reported by the server's load) are offered too.
test.describe('Facts from a document', () => {
    test('fetch a document, extract cited facts, keep their provenance', async ({ page }) => {
        test.setTimeout(120000);
        const seed = {
            // the scenario file of the customs prototype: its templates are all
            // in the resources it includes
            source: [
                'the target language is: prolog.',
                'scenario facts require provenance.',
                '',
                'the knowledge base apparel cbp includes these resources:',
                '    tariff.',
                '',
                'the knowledge base apparel cbp includes:',
                '',
                'query subheading is:',
                '    the subheading of which good is which code.',
            ].join('\n'),
            templateDefs: [
                { label: '*a garment* has a collar', scenario_element: true },
                { label: '*a garment* contains *a number* percent of *a material*', scenario_element: true },
            ],
            example: 'RulesRus/customs/apparel_cbp',
            base: '',
        };
        await page.goto('index.html');
        await page.evaluate((s) => {
            localStorage.setItem('le_scenario_editor_data', JSON.stringify(s));
            localStorage.setItem('le-assistant-model', 'openai/gpt-oss-120b');
        }, seed);
        let request: any = null;
        await page.route('**/leapi*', async (route) => {
            const body = JSON.parse(route.request().postData() || '{}');
            if (body.operation === 'nl_to_le') {
                request = body;
                await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({
                    result: 'ok',
                    le: 'style 1025AD has a collar, confer "zips through a self-fabric stand-up collar".\n'
                      + 'style 1025AD contains 92 percent of polyester, confer "92 percent polyester and 8 percent spandex".',
                    warnings: [],
                    document_facts: ['the text of ruling NY N362700 is at "sources/cbp/N362700.txt"'],
                }) });
            } else { await route.continue(); }
        });
        await page.goto('scenario-editor.html');
        await page.fill('#scenario-name', 'fromdoc');

        // The included templates are offered.
        await expect(page.locator('#add-template option', { hasText: 'a garment has a collar' })).toHaveCount(1);

        await page.selectOption('#add-template', '__write_in_english__');
        await page.click('#btn-add');
        const dialog = page.locator('.nl-dialog');
        await expect(dialog).toBeVisible();
        await dialog.locator('details.nl-document summary').click();
        await dialog.locator('.nl-doc-name').fill('ruling NY N362700');
        await dialog.locator('.nl-doc-address').fill('sources/cbp/N362700.txt');
        await dialog.locator('button', { hasText: 'Fetch text' }).click();
        // The document's text (served from beside the program) fills the text area.
        await expect(dialog.locator('textarea')).toHaveValue(/Style 1025AD/, { timeout: 30000 });
        await dialog.locator('button.primary').click();

        await expect(dialog).toHaveCount(0);
        expect(request.document).toBe('ruling NY N362700');
        expect(request.address).toBe('sources/cbp/N362700.txt');
        expect(request.source).toBe('RulesRus/customs/apparel_cbp');

        // Two editable rows with their provenance, and the document's address.
        const rows = page.locator('.fact-row');
        await expect(rows).toHaveCount(3);
        await expect(rows.nth(0).locator('input.field')).toHaveValue('style 1025AD');
        // (its citation, editable in the row's citation field)
        await expect(rows.nth(0).locator('input.cite-field')).toHaveValue(/confer "zips through/);
        // the scenario's default provenance names the document
        await expect(page.locator('#scenario-provenance')).toHaveValue('as stated in ruling NY N362700');
        await expect(rows.nth(1).locator('input.field').nth(1)).toHaveValue('92');
        await expect(rows.nth(2)).toContainText('the text of ruling NY N362700 is at');

    });
});
