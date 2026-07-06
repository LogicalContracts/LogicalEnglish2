import { test, expect } from '@playwright/test';

// Seeds the Query Editor's localStorage data, then opens the window directly.
const SEED = {
    source: [
        'the templates are:',
        '    *a person* is happy.',
        '    *a person* is rich.',
        '    *a person* likes *a thing*.',
        '',
        'the knowledge base kb includes:',
        '    a person is happy if the person is rich.',
        '',
        'query one is:',
        '    which person is happy.',
        '',
        'query two is:',
        '    a person is rich',
        '    and it is not the case that the person likes broccoli.',
    ].join('\n'),
};

const SEED_FATHER = {
    source: [
        'the templates are:',
        '    *a person* is the father of *a person*.',
    ].join('\n'),
};

test.describe('Query Editor', () => {
    test('loads a query into editable rows with connectives and negation', async ({ page, context }) => {
        await context.grantPermissions(['clipboard-read', 'clipboard-write']);

        await page.goto('index.html');
        await page.evaluate((seed) => {
            localStorage.setItem('le_query_editor_data', JSON.stringify(seed));
        }, SEED);
        await page.goto('query-editor.html');

        // Picker offers "New…" plus the two declared queries.
        const picker = page.locator('#query-picker');
        await expect(picker.locator('option')).toHaveCount(3);
        await expect(picker.locator('option', { hasText: 'one' })).toHaveCount(1);
        await expect(picker.locator('option', { hasText: 'two' })).toHaveCount(1);

        // Load query "two": two condition rows.
        await picker.selectOption('two');
        await expect(page.locator('#query-name')).toHaveValue('two');
        const rows = page.locator('.fact-row');
        await expect(rows).toHaveCount(2);

        // Row 0: "a person is rich" — one field "a person", literal "is rich"; no
        // connective selector on the first row.
        await expect(rows.nth(0).locator('input.field')).toHaveValue('a person');
        await expect(rows.nth(0).locator('.word')).toHaveText('is rich');
        await expect(rows.nth(0).locator('select.connective')).toHaveCount(0);

        // Row 1: joined by "and", negated ("it is not the case that"), matching the
        // "*a person* likes *a thing*" template.
        await expect(rows.nth(1).locator('select.connective')).toHaveValue('and');
        await expect(rows.nth(1).locator('.neg-phrase')).toHaveText('it is not the case that');
        await expect(rows.nth(1).locator('.negate input[type=checkbox]')).toBeChecked();
        const r1 = rows.nth(1).locator('input.field');
        await expect(r1.nth(0)).toHaveValue('the person');
        await expect(r1.nth(1)).toHaveValue('broccoli');

        // Copy reproduces the query block verbatim.
        await page.locator('#btn-copy').click();
        const copied = await page.evaluate(() => navigator.clipboard.readText());
        expect(copied).toBe(
            'query two is:\n    a person is rich\n    and it is not the case that the person likes broccoli.'
        );
    });

    test('builds a new query from templates, connectives and negation', async ({ page, context }) => {
        await context.grantPermissions(['clipboard-read', 'clipboard-write']);
        await page.goto('index.html');
        await page.evaluate((seed) => localStorage.setItem('le_query_editor_data', JSON.stringify(seed)), SEED);
        await page.goto('query-editor.html');

        // New query, named "q".
        await page.locator('#query-name').fill('q');

        // The Add picker offers every declared template (placeholders shown bare).
        await expect(page.locator('#add-template option')).toHaveCount(3);

        // Condition 1: "which person is happy".
        await page.locator('#add-template').selectOption({ label: 'a person is happy' });
        await page.locator('#btn-add').click();
        await page.locator('.fact-row').nth(0).locator('input.field').fill('which person');

        // Condition 2: "the person is rich", joined by "or".
        await page.locator('#add-template').selectOption({ label: 'a person is rich' });
        await page.locator('#btn-add').click();
        const row2 = page.locator('.fact-row').nth(1);
        await row2.locator('input.field').fill('the person');
        await row2.locator('select.connective').selectOption('or');
        // Negate it via the "not" checkbox.
        await row2.locator('.negate input[type=checkbox]').check();

        await page.locator('#btn-copy').click();
        const copied = await page.evaluate(() => navigator.clipboard.readText());
        expect(copied).toBe(
            'query q is:\n    which person is happy\n    or it is not the case that the person is rich.'
        );
    });

    test('untouched template fields fall back to the variable name (not blank)', async ({ page, context }) => {
        await context.grantPermissions(['clipboard-read', 'clipboard-write']);
        await page.goto('index.html');
        await page.evaluate((seed) => localStorage.setItem('le_query_editor_data', JSON.stringify(seed)), SEED_FATHER);
        await page.goto('query-editor.html');

        // A hint clarifies conditions are combined (and by default).
        await expect(page.locator('#join-hint')).toContainText('and by default');

        await page.locator('#query-name').fill('teste');
        // Add the template but DON'T fill the placeholders.
        await page.locator('#add-template').selectOption({ label: 'a person is the father of a person' });
        await page.locator('#btn-add').click();

        await page.locator('#btn-copy').click();
        const copied = await page.evaluate(() => navigator.clipboard.readText());
        // The empty fields become the variable name — a valid query, not "is the father of".
        expect(copied).toBe('query teste is:\n    a person is the father of a person.');
    });

    test('indent/unindent scopes conditions and round-trips through the text', async ({ page, context }) => {
        await context.grantPermissions(['clipboard-read', 'clipboard-write']);
        await page.goto('index.html');
        await page.evaluate((seed) => localStorage.setItem('le_query_editor_data', JSON.stringify(seed)), SEED);
        await page.goto('query-editor.html');
        await page.locator('#query-name').fill('q');

        // Three conditions: happy AND rich OR likes chocolate, with the OR nested one
        // level deeper so it scopes under "rich".
        await page.locator('#add-template').selectOption({ label: 'a person is happy' });
        await page.locator('#btn-add').click();
        await page.locator('.fact-row').nth(0).locator('input.field').fill('a person');

        await page.locator('#add-template').selectOption({ label: 'a person is rich' });
        await page.locator('#btn-add').click();
        await page.locator('.fact-row').nth(1).locator('input.field').fill('the person');

        await page.locator('#add-template').selectOption({ label: 'a person likes a thing' });
        await page.locator('#btn-add').click();
        const row3 = page.locator('.fact-row').nth(2);
        await row3.locator('input.field').nth(0).fill('the person');
        await row3.locator('input.field').nth(1).fill('chocolate');
        await row3.locator('select.connective').selectOption('or');

        // Row 0 cannot indent; indent row 3 once (nest it under "rich").
        await expect(page.locator('.fact-row').nth(0).locator('.indent-btn').first()).toBeDisabled();
        await row3.locator('.indent-btn').nth(1).click();   // the ⇥ (indent) button
        await expect(page.locator('.fact-row').nth(2)).toHaveClass(/indented/);

        await page.locator('#btn-copy').click();
        const copied = await page.evaluate(() => navigator.clipboard.readText());
        expect(copied).toBe(
            'query q is:\n' +
            '    a person is happy\n' +
            '    and the person is rich\n' +
            '        or the person likes chocolate.'
        );

        // Round-trip: an indented query loads back with the same nesting.
        const src = SEED.source + '\n\n' + copied;
        await page.evaluate((s) => localStorage.setItem('le_query_editor_data', JSON.stringify({ source: s })), src);
        await page.goto('query-editor.html');
        await page.locator('#query-picker').selectOption('q');
        await expect(page.locator('.fact-row')).toHaveCount(3);
        await expect(page.locator('.fact-row').nth(2)).toHaveClass(/indented/);
        await expect(page.locator('.fact-row').nth(1)).not.toHaveClass(/indented/);
    });

    test('Insert into Editor replaces the query in the document', async ({ context }) => {
        // The real editor, seeded with the program via the URL text param.
        const editorPage = await context.newPage();
        await editorPage.goto('index.html?text=' + encodeURIComponent(SEED.source));
        await expect(editorPage.locator('#container')).toBeVisible();
        await editorPage.waitForFunction(() =>
            typeof (window as any).monaco !== 'undefined' &&
            (window as any).monaco.languages.getLanguages().some((l: any) => l.id === 'le'));

        // Open the Query Editor with the same source.
        const qePage = await context.newPage();
        await qePage.goto('index.html');
        await qePage.evaluate((seed) => localStorage.setItem('le_query_editor_data', JSON.stringify(seed)), SEED);
        await qePage.goto('query-editor.html');

        // Load "one" and change its condition, then Insert.
        await qePage.locator('#query-picker').selectOption('one');
        await expect(qePage.locator('#query-name')).toHaveValue('one');
        await qePage.locator('.fact-row').nth(0).locator('input.field').fill('which person');
        // Add a rich condition too.
        await qePage.locator('#add-template').selectOption({ label: 'a person is rich' });
        await qePage.locator('#btn-add').click();
        await qePage.locator('.fact-row').nth(1).locator('input.field').fill('the person');

        await qePage.locator('#btn-insert').click();

        // The editor's "query one" block is replaced in place; "query two" is untouched.
        await expect.poll(async () =>
            editorPage.evaluate(() => (window as any).monaco.editor.getModels()[0].getValue())
        ).toContain('query one is:\n    which person is happy\n    and the person is rich.');
        const value = await editorPage.evaluate(() => (window as any).monaco.editor.getModels()[0].getValue());
        expect(value).toContain('query two is:');
        // Exactly one "query one is:" header (replaced, not duplicated).
        expect(value.match(/query one is:/g)?.length).toBe(1);
    });
});
