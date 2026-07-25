import { test, expect } from '@playwright/test';

/*
 * The LPS surface (M8e). Two backends: this page asks /leapi to parse Logical
 * English and /lpsapi to run the result, and the second one is a SEPARATE
 * server — `./lps ide` in the LPS(2) repository, on :3060 by default.
 *
 * Every test here is skipped when that server is not up, rather than failing:
 * the LE2 suite must stay green in a checkout that has no LPS(2) beside it.
 * Point it elsewhere with LPS_API_URL.
 */

const LPS_API = process.env.LPS_API_URL ?? 'http://localhost:3060/lpsapi';

async function lpsUp(): Promise<boolean> {
    try {
        const r = await fetch(LPS_API, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ operation: 'example', name: 'goat_declarative' }),
        });
        return r.ok;
    } catch {
        return false;
    }
}

const page_url = `lps.html?lpsapi=${encodeURIComponent(LPS_API)}`;

test.describe('Logical English -> LPS', () => {
    test.beforeEach(async () => {
        test.skip(!(await lpsUp()), `no LPS(2) server at ${LPS_API}`);
    });

    test('an LE program compiles through both backends and runs', async ({ page }) => {
        const errors: string[] = [];
        page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
        page.on('pageerror', (e) => errors.push(String(e)));

        await page.goto(page_url);
        await expect(page.locator('#endpoints')).toContainText('lpsapi');

        await page.click('#run');
        await expect(page.locator('#status')).toContainText('after', { timeout: 60000 });

        // The internal syntax LE2 generated is shown, and it is LPS's, not LE's.
        await page.click('.tabs button[data-pane="internal"]');
        await expect(page.locator('#internal')).toContainText('fluents(');
        await expect(page.locator('#internal')).toContainText('reactive_rule(');

        expect(errors, errors.join('\n')).toEqual([]);
    });

    test('the timeline and the state-transitions diagram both draw', async ({ page }) => {
        await page.goto(page_url);
        await page.click('#run');
        await expect(page.locator('#status')).toContainText('after', { timeout: 60000 });

        await page.click('.tabs button[data-pane="timeline"]');
        expect(await page.locator('#pane-timeline svg rect').count()).toBeGreaterThan(0);

        await page.click('.tabs button[data-pane="automaton"]');
        await page.waitForTimeout(800);
        const states = await page.locator('#dfa svg rect').count();
        const edges = await page.locator('#dfa svg path[marker-end]').count();
        expect(states).toBeGreaterThan(1);
        expect(edges).toBeGreaterThan(0);
        // Exactly one state is the initial one, and it is the marked one.
        expect(await page.locator('#dfa svg rect[stroke-width="3"]').count()).toBe(1);
    });

    test('the lps mode compiles external syntax with no LE round trip', async ({ page }) => {
        await page.goto(page_url);
        await page.selectOption('#mode', 'lps');
        await page.click('#run');
        await expect(page.locator('#status')).toContainText('after', { timeout: 60000 });
        await page.click('.tabs button[data-pane="automaton"]');
        await page.waitForTimeout(800);
        expect(await page.locator('#dfa svg rect').count()).toBeGreaterThan(1);
    });

    test('an LE error is reported at the .le line it came from', async ({ page }) => {
        await page.goto(page_url);
        // `the goal is that ...` with no planning support is an LPS-side
        // diagnostic; what matters is that it lands on a line of THIS document,
        // not of the internal text LE2 generated (docs/le_lps_interface.md §4).
        await page.evaluate(() => {
            const ed = (window as any).monaco.editor.getModels()[0];
            ed.setValue([
                'the target language is: lps.',
                '',
                'the maximum time is 3.',
                '',
                'the fluents are:',
                '    it is dark; known as dark.',
                '',
                'the knowledge base w includes:',
                '',
                'initially it is dark.',
                '',
                'the goal is that it is dark.',
                ''
            ].join('\n'));
        });
        await page.click('#run');
        await expect(page.locator('#diags .diag')).toHaveCount(1, { timeout: 60000 });
        const text = await page.textContent('#diags');
        expect(text).toContain('LPS');
        expect(text).toMatch(/line 1[0-9]|line [1-9]/);
    });
});
