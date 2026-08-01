// Editor actions that need to know WHICH predicate the cursor is on: the
// server resolves it from the parsed KB (operation predicateAt), the client
// then navigates to its first rule or folds every rule it has.
import { test, expect } from '@playwright/test';

const PROGRAM = `the target language is: prolog.

the templates are:
    *a person* is happy.
    *a person* is healthy.
    *a person* is rich.

the knowledge base tiny includes:

a person is happy
    if the person is healthy.

a person is happy
    if the person is rich.

a person is healthy
    if the person is rich.

query who is:
    which person is happy.
`;

test.describe('predicate actions', () => {
    test('Show definition jumps to the first rule of the predicate under the cursor', async ({ page }) => {
        test.setTimeout(90000);
        await page.goto('/editor/index.html?text=' + encodeURIComponent(PROGRAM));
        await page.waitForSelector('.monaco-editor', { timeout: 30000 });
        await page.waitForTimeout(4000);   // language client + KB load

        // put the cursor on the "is healthy" CONDITION inside the first rule (line 11)
        await page.evaluate(() => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            ed.setPosition({ lineNumber: 11, column: 20 });
        });
        const before = await page.evaluate(() => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            return ed.getPosition().lineNumber;
        });
        expect(before).toBe(11);

        await page.evaluate(async () => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            await ed.getAction('le-show-definition').run(ed);
        });
        await page.waitForTimeout(2500);
        const after = await page.evaluate(() => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            return ed.getPosition().lineNumber;
        });
        // the rule "a person is healthy ..." has its head on line 16
        expect(after).toBe(16);
    });

    test('Fold all rules folds every rule of that predicate', async ({ page }) => {
        test.setTimeout(90000);
        await page.goto('/editor/index.html?text=' + encodeURIComponent(PROGRAM));
        await page.waitForSelector('.monaco-editor', { timeout: 30000 });
        await page.waitForTimeout(4000);

        // cursor on the head of the first "is happy" rule (line 10)
        await page.evaluate(() => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            ed.setPosition({ lineNumber: 10, column: 3 });
        });
        await page.evaluate(async () => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            await ed.getAction('le-fold-predicate-rules').run(ed);
        });
        await page.waitForTimeout(2500);
        // both "is happy" rules (lines 10 and 13) are folded, the "is healthy"
        // rule (line 16) is not
        const collapsed = await page.evaluate(async () => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            const fm: any = await (ed.getContribution('editor.contrib.folding') as any).getFoldingModel();
            // rule heads: the two "is happy" rules (10, 13) and "is healthy" (16)
            return [10, 13, 16].map(l => {
                const r = fm.getRegionAtLine(l);
                return r ? r.isCollapsed : null;
            });
        });
        console.log('COLLAPSED', JSON.stringify(collapsed));
        expect(collapsed[0]).toBe(true);    // both rules of the predicate folded
        expect(collapsed[1]).toBe(true);
        expect(collapsed[2]).toBe(false);   // the other predicate untouched

        // ... and unfolding brings them back
        await page.evaluate(async () => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            ed.setPosition({ lineNumber: 10, column: 3 });
            await ed.getAction('le-unfold-predicate-rules').run(ed);
        });
        await page.waitForTimeout(2000);
        const after = await page.evaluate(async () => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            const fm: any = await (ed.getContribution('editor.contrib.folding') as any).getFoldingModel();
            return [10, 13].map(l => fm.getRegionAtLine(l).isCollapsed);
        });
        expect(after).toEqual([false, false]);
    });
});
