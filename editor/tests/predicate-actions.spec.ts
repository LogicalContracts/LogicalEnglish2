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

    // "Show occurrences" lists every mention of the predicate — its
    // declaration, the rules that define it, the conditions that use it, the
    // scenario facts and the queries — and each row jumps to its line.
    test('Show occurrences lists every mention and navigates to it', async ({ page }) => {
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
            await ed.getAction('le-show-occurrences').run(ed);
        });

        const modal = page.locator('#occurrences-modal');
        await expect(modal).toBeVisible({ timeout: 20000 });
        const rows = page.locator('#occurrences-list .occurrence-row');
        // declaration (line 4), the two rule heads (10, 13) and the query (20)
        await expect(rows).toHaveCount(4);
        await expect(page.locator('#occurrences-subtitle')).toContainText('is happy');
        const lines = await page.locator('#occurrences-list .occurrence-line').allTextContents();
        expect(lines).toEqual(['4', '10', '13', '20']);
        const kinds = await page.locator('#occurrences-list .occurrence-kind').allTextContents();
        expect(kinds).toEqual(['declaration', 'rule head', 'rule head', 'query']);

        // clicking a row closes the list and goes to that line
        await rows.nth(3).click();
        await expect(modal).toBeHidden();
        const after = await page.evaluate(() => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            return ed.getPosition().lineNumber;
        });
        expect(after).toBe(20);
    });

    // A condition lives inside a rule whose source range covers the whole rule,
    // so the occurrence has to resolve to the condition's OWN line.
    test('Show occurrences resolves a condition to its own line', async ({ page }) => {
        test.setTimeout(90000);
        await page.goto('/editor/index.html?text=' + encodeURIComponent(PROGRAM));
        await page.waitForSelector('.monaco-editor', { timeout: 30000 });
        await page.waitForTimeout(4000);

        // cursor on the "is rich" condition (line 14)
        await page.evaluate(() => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            ed.setPosition({ lineNumber: 14, column: 20 });
        });
        await page.evaluate(async () => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            await ed.getAction('le-show-occurrences').run(ed);
        });
        await expect(page.locator('#occurrences-modal')).toBeVisible({ timeout: 20000 });
        const lines = await page.locator('#occurrences-list .occurrence-line').allTextContents();
        // declaration (6), and the conditions of the two rules (14 and 17) —
        // NOT the rule heads on lines 13 and 16
        expect(lines).toEqual(['6', '14', '17']);
        const kinds = await page.locator('#occurrences-list .occurrence-kind').allTextContents();
        expect(kinds).toEqual(['declaration', 'condition', 'condition']);
    });

    // Go back (Ctrl+-) returns to where a jump started.
    test('Go back returns to the line the jump started from', async ({ page }) => {
        test.setTimeout(90000);
        await page.goto('/editor/index.html?text=' + encodeURIComponent(PROGRAM));
        await page.waitForSelector('.monaco-editor', { timeout: 30000 });
        await page.waitForTimeout(4000);

        await page.evaluate(() => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            ed.setPosition({ lineNumber: 11, column: 20 });   // "is healthy" condition
        });
        await page.evaluate(async () => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            await ed.getAction('le-show-definition').run(ed);
        });
        await page.waitForTimeout(2500);
        expect(await page.evaluate(() => (window as any).monaco.editor.getEditors()[0].getPosition().lineNumber)).toBe(16);

        await page.evaluate(async () => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            await ed.getAction('le-go-back').run(ed);
        });
        expect(await page.evaluate(() => (window as any).monaco.editor.getEditors()[0].getPosition().lineNumber)).toBe(11);

        // The history is a stack, not a toggle: a second Go back with nothing
        // left on it leaves the cursor where it is.
        await page.evaluate(async () => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            await ed.getAction('le-go-back').run(ed);
        });
        expect(await page.evaluate(() => (window as any).monaco.editor.getEditors()[0].getPosition().lineNumber)).toBe(11);
    });

    // A head whose predicate carries prepositional additions ("we will make
    // *a payment*" folded with the composite templates "*a payment* under
    // *a policy*" and "*a payment* in respect of *a claim*"): the head literal
    // is a fraction of the words on its own line, and Fold-all-rules used to
    // fold whichever condition of the rule shared the most words with it.
    const FOLD_PROGRAM = `the target language is: prolog.

the templates are:
    we will make *a payment* ; opposite: we will not make *a payment*.
    *a payment* under *a policy*; composite.
    *a payment* is under *a policy*.
    *a payment* in respect of *a claim*; composite.
    *a payment* is in respect of *a claim*.
    *a claim* against *a person*; composite.
    *a claim* is against *a person*.
    *a payment* in respect of *a claim* fulfills all the general conditions of *a policy*.
    *a claim* is covered by this section.
    *a person* is an employee.

the knowledge base tiny includes:

we will make a payment under this policy in respect of a claim
    if the claim is covered by this section
    and the payment in respect of the claim fulfills all the general conditions of this policy.

we will make a payment under this policy in respect of a claim against a person
    if the person is an employee
    and the payment in respect of the claim fulfills all the general conditions of this policy.

query who is:
    which payment is in respect of which claim.
`;

    test('Fold all rules works on a head with prepositional additions', async ({ page }) => {
        test.setTimeout(90000);
        await page.goto('/editor/index.html?text=' + encodeURIComponent(FOLD_PROGRAM));
        await page.waitForSelector('.monaco-editor', { timeout: 30000 });
        await page.waitForTimeout(4000);

        // cursor on the first head (line 17), whose predicate also has the
        // second, longer head (line 21)
        await page.evaluate(() => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            ed.setPosition({ lineNumber: 17, column: 3 });
        });
        await page.evaluate(async () => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            await ed.getAction('le-fold-predicate-rules').run(ed);
        });
        await page.waitForTimeout(2500);
        const collapsed = await page.evaluate(async () => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            const fm: any = await (ed.getContribution('editor.contrib.folding') as any).getFoldingModel();
            return [17, 21].map(l => {
                const r = fm.getRegionAtLine(l);
                return r ? r.isCollapsed : null;
            });
        });
        expect(collapsed).toEqual([true, true]);
    });
});
