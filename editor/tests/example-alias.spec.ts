import { test, expect } from '@playwright/test';

// Examples that were merged or regrouped keep their old names
// (le_kbs:example_alias/2, docs/project/plans/NewExamplesStructure.md): an old ?example=
// link opens the example as it is now, and the API answers the old name.
const modelText = () => {
    const ed = (window as any).monaco?.editor?.getEditors()[0];
    return ed ? ed.getModel().getValue() as string : '';
};

test.describe('Old example names', () => {
    test('an old ?example= link opens the merged example', async ({ page }) => {
        test.setTimeout(90000);
        await page.goto('index.html?example=sum_onto');
        await expect.poll(() => page.evaluate(modelText), { timeout: 45000 })
            .toContain('the knowledge base sums includes');
    });

    test('the examples operation answers an old name', async ({ request }) => {
        const resp = await request.post('/leapi', {
            data: { token: 'myToken123', operation: 'examples', file: 'short/sets' }
        });
        const data = await resp.json();
        expect(data.document).toContain('the knowledge base subset includes');
    });
});
