import { test, expect } from '@playwright/test';

// Seeds the Scenario Editor's localStorage data, then opens the window directly.
const SEED = {
    source: [
        'the templates are:',
        '    *a person* is born in *a place* on *a date*.',
        '    *a person* is the mother of *a person*.',
        '    *a thing* is *a colour*.',
        '    *a person* has passed the test; undefined.',
        '    *a person* acquires citizenship on *a date*.',
        '',
        'scenario alice is:',
        '% from the claim',                       // column-0 comment INSIDE the scenario
        '    John is born in the UK on 2021-10-09. % an INLINE comment after the fact',
        '    Alice is the mother of John.',
        '    this wall is green.',                // would mis-split to ["th","wall is green"] without \\b
        '    John is a british citizen.',         // a type assertion ("is a TYPE")
        '    one expects answers ["yes"].',
        '',
        'query one is:',
        '    which person is born in which place on which date.',
    ].join('\n'),
};

// A program whose scenario declares one fact unknown ("it is unknown whether …")
// and one plain fact — for the Assume checkbox.
const SEED_ASSUME = {
    source: [
        'the templates are:',
        '    *a person* is happy.',
        '    *a person* likes *a thing*.',
        '',
        'scenario s is:',
        '    it is unknown whether Bob is happy.',
        '    Alice likes chocolate.',
    ].join('\n'),
};

test.describe('Scenario Editor', () => {
    test('loads a scenario into editable template rows and builds correct text', async ({ page, context }) => {
        await context.grantPermissions(['clipboard-read', 'clipboard-write']);

        // Same origin as scenario-editor.html, so localStorage carries over.
        await page.goto('index.html');
        await page.evaluate((seed) => {
            localStorage.setItem('le_scenario_editor_data', JSON.stringify(seed));
        }, SEED);

        await page.goto('scenario-editor.html');

        // Picker offers "New…" plus the declared scenario.
        const picker = page.locator('#scenario-picker');
        await expect(picker.locator('option')).toHaveCount(2);
        await expect(picker.locator('option', { hasText: 'alice' })).toHaveCount(1);

        // Load the scenario. Comments are SKIPPED and the "expects answers" TEST line is
        // set aside (kept as a comment on save), leaving four editable rows: born,
        // mother, the colour fact and the type assertion.
        await picker.selectOption('alice');
        await expect(page.locator('#scenario-name')).toHaveValue('alice');
        const rows = page.locator('.fact-row');
        await expect(rows).toHaveCount(4);
        // The "%" comment and the test line are not shown anywhere.
        await expect(page.locator('.preserved', { hasText: '% from the claim' })).toHaveCount(0);
        await expect(page.locator('.fact-row', { hasText: 'expects answers' })).toHaveCount(0);

        // Row 0: only the PLACEHOLDERS are editable — "John is born in the UK on
        // 2021-10-09" -> three fields, with "is born in"/"on" as plain labels.
        const fields = rows.nth(0).locator('input.field');
        await expect(fields).toHaveCount(3);
        await expect(rows.nth(0).locator('.word').nth(0)).toHaveText('is born in');
        await expect(fields.nth(0)).toHaveValue('John');
        await expect(fields.nth(1)).toHaveValue('the UK');
        await expect(fields.nth(2)).toHaveValue('2021-10-09');
        await expect(fields.nth(0)).toHaveAttribute('placeholder', 'a person');   // hint = LE variable

        // Row 2: the literal "is" must NOT match inside "th-is" — word boundaries give
        // ["this wall","green"], not ["th","wall is green"].
        const inFields = rows.nth(2).locator('input.field');
        await expect(inFields.nth(0)).toHaveValue('this wall');
        await expect(inFields.nth(1)).toHaveValue('green');

        // Row 3: a type assertion "John is a british citizen" loads as an editable row.
        const typeFields = rows.nth(3).locator('input.field');
        await expect(typeFields.nth(0)).toHaveValue('John');
        await expect(typeFields.nth(1)).toHaveValue('british citizen');

        // The "Add fact" menu: no free-text; only undefined templates + those used by a
        // scenario (incl. the "is a TYPE" assertion since it is used); not conclusions.
        const addOptions = page.locator('#add-template option');
        await expect(page.locator('#add-template option', { hasText: '(free text)' })).toHaveCount(0);
        // 5 templates + the "Write it in English…" entry.
        await expect(addOptions).toHaveCount(6);
        await expect(page.locator('#add-template option', { hasText: 'Write it in English' })).toHaveCount(1);
        await expect(page.locator('#add-template option', { hasText: 'has passed the test' })).toHaveCount(1); // undefined
        await expect(page.locator('#add-template option', { hasText: 'a thing is a colour' })).toHaveCount(1);  // used
        await expect(page.locator('#add-template option', { hasText: 'a thing is a type' })).toHaveCount(1);     // type assertion, used
        await expect(page.locator('#add-template option', { hasText: 'acquires citizenship' })).toHaveCount(0);  // conclusion, excluded

        // Edit a field, then add a new fact via the template picker.
        await fields.nth(1).fill('the United Kingdom');
        await page.locator('#add-template').selectOption({ label: 'a person is the mother of a person' });
        await page.locator('#btn-add').click();
        await expect(page.locator('.fact-row')).toHaveCount(5);

        // Copy builds the scenario block; verify its text on the clipboard.
        await page.locator('#btn-copy').click();
        const copied = await page.evaluate(() => navigator.clipboard.readText());
        expect(copied).toContain('scenario alice is:');
        expect(copied).toContain('John is born in the United Kingdom on 2021-10-09.');
        expect(copied).toContain('this wall is green.');
        expect(copied).toContain('John is a british citizen.');
        // The test line is written back COMMENTED OUT (not as an active fact).
        expect(copied).toContain('% one expects answers ["yes"].');
        expect(copied).not.toContain('    one expects answers');   // i.e. not an uncommented fact
        expect(copied).not.toContain('% from the claim');          // comment skipped entirely
    });

    test('a no-variable template fact loads as a zero-field row (no spurious fields)', async ({ page }) => {
        // A propositional template that also happens to contain "under" — the same word
        // a looser "*x* under *y*" template would split on. It must load as ONE row with
        // NO input fields, not a row split into two fields around "under".
        const seed = {
            source: [
                'the templates are:',
                '    *a payment* under *a policy*; prepositional.',
                '    you give us prompt notice under this policy.',
                '',
                'scenario s is:',
                '    you give us prompt notice under this policy.',
            ].join('\n'),
        };
        await page.goto('index.html');
        await page.evaluate((s) => localStorage.setItem('le_scenario_editor_data', JSON.stringify(s)), seed);
        await page.goto('scenario-editor.html');

        await page.locator('#scenario-picker').selectOption('s');
        const rows = page.locator('.fact-row');
        await expect(rows).toHaveCount(1);
        // Zero editable fields — the whole no-variable template is plain words.
        await expect(rows.nth(0).locator('input.field')).toHaveCount(0);
        await expect(rows.nth(0)).toContainText('you give us prompt notice under this policy');
    });

    test('Write it in English… adds facts from the LLM', async ({ page }) => {
        const seed = {
            source: [
                'the templates are:',
                '    *a person* is happy.',
                '    *a person* is the mother of *a person*.',
            ].join('\n'),
        };
        await page.goto('index.html');
        await page.evaluate((s) => {
            localStorage.setItem('le_scenario_editor_data', JSON.stringify(s));
            localStorage.setItem('le-assistant-model', 'openai/gpt-oss-120b');   // as if configured via API Keys…
        }, seed);
        // Mock the nl_to_le backend (no real LLM/key needed).
        await page.route('**/leapi*', async (route) => {
            const body = JSON.parse(route.request().postData() || '{}');
            if (body.operation === 'nl_to_le') {
                expect(body.kind).toBe('facts');
                expect(body.templates).toContain('*a person* is happy');
                await route.fulfill({ status: 200, contentType: 'application/json',
                    body: JSON.stringify({ result: 'ok', le: 'Alice is happy.\nAlice is the mother of John.' }) });
            } else { await route.continue(); }
        });
        await page.goto('scenario-editor.html');
        await page.fill('#scenario-name', 'nl');

        // Pick "Write it in English…" and Add → the modal opens.
        await page.selectOption('#add-template', '__write_in_english__');
        await page.click('#btn-add');
        await expect(page.locator('.nl-dialog')).toBeVisible();
        await page.fill('.nl-dialog textarea', 'Alice is happy and she is the mother of John');
        await page.click('.nl-dialog button.primary');

        // The modal closes and the two generated facts load as editable rows.
        await expect(page.locator('.nl-dialog')).toHaveCount(0);
        await expect(page.locator('.fact-row')).toHaveCount(2);
        await expect(page.locator('.fact-row').nth(0)).toContainText('is happy');
        await expect(page.locator('.fact-row').nth(1)).toContainText('is the mother of');
    });

    test('Write it in English… warns on new issues but still lets you insert', async ({ page }) => {
        const seed = { source: 'the templates are:\n    *a person* is happy.\n' };
        await page.goto('index.html');
        await page.evaluate((s) => {
            localStorage.setItem('le_scenario_editor_data', JSON.stringify(s));
            localStorage.setItem('le-assistant-model', 'openai/gpt-oss-120b');
        }, seed);
        // Mock a verified-with-issues response (as the backend's baseline-diff would return).
        await page.route('**/leapi*', async (route) => {
            const body = JSON.parse(route.request().postData() || '{}');
            if (body.operation === 'nl_to_le') {
                expect(typeof body.content).toBe('string');   // program is sent for verification
                await route.fulfill({ status: 200, contentType: 'application/json',
                    body: JSON.stringify({ result: 'ok', le: 'Alice is happy.',
                        warnings: ['[warning] Missing template for \'Bob likes chocolate\''] }) });
            } else { await route.continue(); }
        });
        await page.goto('scenario-editor.html');
        await page.fill('#scenario-name', 'nl');
        await page.selectOption('#add-template', '__write_in_english__');
        await page.click('#btn-add');
        await page.fill('.nl-dialog textarea', 'Alice is happy and Bob likes chocolate');
        await page.click('.nl-dialog button.primary');

        // The dialog stays open with a warning, and the primary button becomes "Insert anyway".
        await expect(page.locator('.nl-dialog')).toBeVisible();
        await expect(page.locator('.nl-status.warn')).toContainText('1 new issue');
        await expect(page.locator('.nl-status.warn')).toContainText('Missing template');
        await expect(page.locator('.nl-dialog button.primary')).toHaveText('Insert anyway');

        // Insert anyway → the fact is added and the dialog closes.
        await page.click('.nl-dialog button.primary');
        await expect(page.locator('.nl-dialog')).toHaveCount(0);
        await expect(page.locator('.fact-row')).toHaveCount(1);
        await expect(page.locator('.fact-row').nth(0)).toContainText('is happy');
    });

    // An [error] means the generated text would not do what it says — a
    // sentence matching no template, an asterisked phrase, a broken test of the
    // program. The dialog says so in the error colour rather than filing it
    // under "issues", while still letting the user insert it.
    test('Write it in English… flags an error differently from a warning', async ({ page }) => {
        const seed = { source: 'the templates are:\n    *a person* is happy.\n' };
        await page.goto('index.html');
        await page.evaluate((s) => {
            localStorage.setItem('le_scenario_editor_data', JSON.stringify(s));
            localStorage.setItem('le-assistant-model', 'openai/gpt-oss-120b');
        }, seed);
        await page.route('**/leapi*', async (route) => {
            const body = JSON.parse(route.request().postData() || '{}');
            if (body.operation === 'nl_to_le') {
                await route.fulfill({ status: 200, contentType: 'application/json',
                    body: JSON.stringify({ result: 'ok', le: 'bob likes chocolate.',
                        warnings: ['[error] line 1: \'bob likes chocolate\' matches NO declared template, so it states nothing'] }) });
            } else { await route.continue(); }
        });
        await page.goto('scenario-editor.html');
        await page.fill('#scenario-name', 'nl');
        await page.selectOption('#add-template', '__write_in_english__');
        await page.click('#btn-add');
        await page.fill('.nl-dialog textarea', 'Bob likes chocolate');
        await page.click('.nl-dialog button.primary');

        await expect(page.locator('.nl-status.error')).toContainText('1 problem');
        await expect(page.locator('.nl-status.error')).toContainText('matches NO declared template');
        await expect(page.locator('.nl-status.error')).toContainText('rephrasing and regenerating');
        await expect(page.locator('.nl-dialog button.primary')).toHaveText('Insert anyway');
    });

    test('Insert into Editor replaces the scenario in the document', async ({ context }) => {
        // The real editor, seeded with the program via the URL text param.
        const editorPage = await context.newPage();
        await editorPage.goto('index.html?text=' + encodeURIComponent(SEED.source));
        await expect.poll(() =>
            editorPage.evaluate(() => (window as any).monaco?.editor?.getModels?.()[0]?.getValue() || '')
        ).toContain('scenario alice is:');

        // The Scenario Editor window, same origin, seeded with the same source.
        const sePage = await context.newPage();
        await sePage.goto('index.html');
        await sePage.evaluate((seed) =>
            localStorage.setItem('le_scenario_editor_data', JSON.stringify(seed)), SEED);
        await sePage.goto('scenario-editor.html');
        await sePage.locator('#scenario-picker').selectOption('alice');
        // Edit the "place" field of the born fact (the first row with fields).
        await sePage.locator('.fact-row', { has: sePage.locator('input.field') })
            .first().locator('input.field').nth(1).fill('the United Kingdom');
        await sePage.locator('#btn-insert').click();

        // The editor document now reflects the replaced scenario (via the channel).
        await expect.poll(() =>
            editorPage.evaluate(() => (window as any).monaco.editor.getModels()[0].getValue())
        ).toContain('John is born in the United Kingdom on 2021-10-09.');
        // The other fact is preserved and there is still exactly one alice scenario.
        const finalText: string = await editorPage.evaluate(() =>
            (window as any).monaco.editor.getModels()[0].getValue());
        expect(finalText).toContain('Alice is the mother of John.');
        expect(finalText.match(/scenario alice is:/g)?.length).toBe(1);
    });

    test('Assume checkbox marks a fact unknown ("it is unknown whether …")', async ({ page, context }) => {
        await context.grantPermissions(['clipboard-read', 'clipboard-write']);
        await page.goto('index.html');
        await page.evaluate((seed) =>
            localStorage.setItem('le_scenario_editor_data', JSON.stringify(seed)), SEED_ASSUME);
        await page.goto('scenario-editor.html');
        await page.locator('#scenario-picker').selectOption('s');

        const rows = page.locator('.fact-row');
        await expect(rows).toHaveCount(2);

        // Row 0 ("it is unknown whether Bob is happy") loads with Assume pre-checked and
        // its field disabled — but still showing the parsed value "Bob".
        const unknownRow = rows.nth(0);
        await expect(unknownRow.locator('.assume input[type=checkbox]')).toBeChecked();
        await expect(unknownRow.locator('input.field')).toBeDisabled();
        await expect(unknownRow.locator('input.field')).toHaveValue('Bob');

        // Row 1 ("Alice likes chocolate") is a plain editable fact.
        const plainRow = rows.nth(1);
        await expect(plainRow.locator('.assume input[type=checkbox]')).not.toBeChecked();
        await expect(plainRow.locator('input.field').first()).toBeEnabled();

        // Check Assume on the plain fact: its fields become read-only.
        await plainRow.locator('.assume input[type=checkbox]').check();
        await expect(plainRow.locator('input.field').first()).toBeDisabled();

        // Copy: both facts are now written with the "it is unknown whether" prefix.
        await page.locator('#btn-copy').click();
        const copied = await page.evaluate(() => navigator.clipboard.readText());
        expect(copied).toContain('it is unknown whether Bob is happy.');
        expect(copied).toContain('it is unknown whether Alice likes chocolate.');

        // Uncheck Assume on row 0: the field is editable again and the prefix is gone.
        await unknownRow.locator('.assume input[type=checkbox]').uncheck();
        await expect(unknownRow.locator('input.field')).toBeEnabled();
        await page.locator('#btn-copy').click();
        const copied2 = await page.evaluate(() => navigator.clipboard.readText());
        expect(copied2).toContain('Bob is happy.');
        expect(copied2).not.toContain('it is unknown whether Bob is happy.');
    });
});
