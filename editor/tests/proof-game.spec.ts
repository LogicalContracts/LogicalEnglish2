import { test, expect } from '@playwright/test';

// Capture the sessionModule of a getGameData POST (works for both the editor page
// and the game popup).
function grabGameSession(r: any, set: (s: string) => void) {
    if (r.url().includes('/leapi') && r.method() === 'POST') {
        try {
            const d = JSON.parse(r.postData() || '{}');
            if (d.operation === 'getGameData' && d.sessionModule) set(d.sessionModule);
        } catch { /* ignore */ }
    }
}

// happpy_dragon's "mary" scenario: alice is a parent of BOTH bob and mary, so
// "alice is happy" requires the forall consequent ("… is healthy") for BOTH.
const HAPPY_DRAGON = `the target language is: prolog.

the templates are:
*a creature* is a parent of *a dragon*.
*a creature* is healthy.
*a creature* is happy.
*a creature* is a dragon.

the knowledge base happpy_dragon includes:

A creature is happy
    if the creature is a dragon
    and for all cases in which
	    the creature is a parent of an other creature
		it is the case that
		the other creature is healthy.

scenario mary is:
	bob is a dragon.
	alice is a dragon.
	alice is a parent of bob.
	alice is a parent of mary.
	mary is a dragon.
	mary is healthy.
	bob is healthy.

query happy is:
	which dragon is happy.`;

// Open the editor with a program, load the module, select scenario/query, then open
// the Proof Game (with the test hook enabled). Returns the popup page.
async function openGame(page: any, source: string, scenario: string, query: string): Promise<any> {
    await page.goto('index.html?text=' + encodeURIComponent(source));
    await page.waitForTimeout(800);
    await page.locator('#scenario-select').hover();   // triggers the module load
    await expect.poll(async () => page.locator('#scenario-select option').count(), { timeout: 20000 }).toBeGreaterThan(1);
    await page.selectOption('#scenario-select', scenario);
    await page.selectOption('#query-select', query);
    await page.evaluate(() => localStorage.setItem('le_pg_test', '1'));   // enable the game test hook
    const [popup] = await Promise.all([page.waitForEvent('popup'), page.click('#btn-proof-game')]);
    await popup.waitForLoadState();
    await expect.poll(async () => popup.evaluate(() => !!(window as any).__pgTest), { timeout: 30000 }).toBe(true);
    return popup;
}

const complete = (popup: any, id: string) => popup.evaluate((i: string) => (window as any).__pgTest.complete(i), id);

test.describe('Proof Game', () => {
    test('uses its own session, distinct from the editor', async ({ page }) => {
        test.setTimeout(60000);
        await page.goto('index.html');
        await page.click('text=File');
        await page.click('#menu-open-server');
        await page.locator('#example-list .dropdown-item', { hasText: /^citizenship$/ }).click();
        await expect(page.locator('#filename-display')).toHaveText('citizenship.le');
        await expect(async () => {
            expect(await page.locator('#scenario-select option').count()).toBeGreaterThan(1);
        }).toPass({ timeout: 10000 });
        await page.selectOption('#scenario-select', 'alice');
        await page.selectOption('#query-select', 'one');

        let editorSession = '';
        page.on('request', (r) => grabGameSession(r, (s) => (editorSession = s)));

        const [popup] = await Promise.all([
            page.waitForEvent('popup'),
            page.click('#btn-proof-game'),
        ]);
        let gameSession = '';
        popup.on('request', (r) => grabGameSession(r, (s) => (gameSession = s)));
        await popup.waitForLoadState();

        await expect.poll(() => gameSession, { timeout: 30000 }).not.toBe('');
        expect(editorSession).toBeTruthy();
        expect(gameSession).not.toBe(editorSession);
    });

    // Regression for the "all green but missing a forall consequent" bug: proving
    // "alice is happy" needs BOTH "mary is healthy" AND "bob is healthy" (alice is a
    // parent of both). The proof must not count as complete with only one of them.
    test('a multi-case "for all" needs every consequent', async ({ page }) => {
        test.setTimeout(60000);
        const popup = await openGame(page, HAPPY_DRAGON, 'mary', 'happy');

        // Build alice's FULL, correct proof (both consequents connected).
        const ids = await popup.evaluate(async () => {
            const t = (window as any).__pgTest;
            const ns = t.nodes();
            const rule = ns.find((n: any) => n.kind === 'RuleNode').id;
            const query = ns.find((n: any) => n.kind === 'QueryNode').id;
            const f = (s: string) => ns.find((n: any) => n.kind === 'FactNode' && n.label === s).id;
            await t.connect(rule, query, 'in');
            await t.connect(f('alice is a dragon'), rule, 'in-0');
            await t.connect(f('alice is a parent of mary'), rule, 'in-1-0');
            await t.connect(f('alice is a parent of bob'), rule, 'in-1-0');
            await t.connect(f('mary is healthy'), rule, 'in-1-1');
            await t.connect(f('bob is healthy'), rule, 'in-1-1');
            await t.updateUnification();
            return { rule, bob: f('bob is healthy') };
        });

        // The game opens on the first answer ("bob is happy" — bob has no children, so
        // the forall is vacuous). A real, non-vacuous alice proof must NOT pass against
        // that mismatched answer (previously it did — the reported false green).
        expect(await complete(popup, ids.rule)).toBe(false);

        // Select the matching answer ("alice is happy", index 1) and re-validate: the
        // full proof now holds.
        await popup.locator('#answer-select').selectOption('1');
        await expect.poll(() => popup.evaluate(() => (window as any).__pgTest.gameData.answerIndex)).toBe(1);
        await popup.evaluate(() => (window as any).__pgTest.updateUnification());
        expect(await complete(popup, ids.rule)).toBe(true);

        // Remove the "bob is healthy" consequent: now bob's case is unproven, so the
        // universal — and the whole proof — must go incomplete again.
        await popup.evaluate(async (rule: string) => {
            const t = (window as any).__pgTest;
            const bob = t.nodes().find((n: any) => n.label === 'bob is healthy').id;
            await t.disconnect(bob, rule, 'in-1-1');
            await t.updateUnification();
        }, ids.rule);
        expect(await complete(popup, ids.rule)).toBe(false);
    });
});
