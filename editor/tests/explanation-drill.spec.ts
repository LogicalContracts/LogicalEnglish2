import { test, expect } from '@playwright/test';

// Its "alice is happy" answer's strongest reason is an internal "for all cases …" node,
// so "Not yet" can descend into it.
const HAPPY_DRAGON = `the target language is: prolog.
the templates are:
*a creature* is a parent of *a dragon*.
*a creature* is healthy.
*a creature* is happy.
*a creature* is a dragon.
the knowledge base d includes:
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

async function openDrillFrom(page: any, opened: () => Promise<void>): Promise<any> {
    await opened();
    await page.locator('#explanation-title').click({ button: 'right' });
    const [drill] = await Promise.all([
        page.waitForEvent('popup'),
        page.click('#menu-explanation-drill'),
    ]);
    await drill.waitForLoadState();
    await expect(drill.locator('.q-card')).toHaveCount(1);
    return drill;
}

// Drill happy_dragon's "alice is happy" answer (its strongest reason is an internal
// "for all cases …" node, so "Not yet" can descend).
const openHappyDrill = (page: any) => openDrillFrom(page, async () => {
    await page.goto('index.html?text=' + encodeURIComponent(HAPPY_DRAGON));
    await page.waitForTimeout(800);
    await page.locator('#scenario-select').hover();
    await expect.poll(() => page.locator('#scenario-select option').count(), { timeout: 20000 }).toBeGreaterThan(1);
    await page.selectOption('#scenario-select', 'mary');
    await page.selectOption('#query-select', 'happy');
    await page.click('#btn-query');
    await page.locator('#answers-list .answer-item', { hasText: 'alice is happy' }).click();
});

// Click the given answer on the last (pending) question and wait for the round-trip.
async function answerLast(drill: any, cls: 'yes' | 'notyet') {
    await Promise.all([
        drill.waitForResponse((r: any) => r.url().includes('/leapi')),
        drill.locator('.q-card').last().locator(`.q-btn.${cls}`).click(),
    ]);
}

// Load citizenship, run query "one" against "alice", select the answer, then open the
// Explanation Drill from the EXPLANATION title context menu. Returns the drill popup.
async function openDrill(page: any): Promise<any> {
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
    await page.click('#btn-query');
    await page.locator('#answers-list .answer-item').first().click();

    await page.locator('#explanation-title').click({ button: 'right' });
    const [drill] = await Promise.all([
        page.waitForEvent('popup'),
        page.click('#menu-explanation-drill'),
    ]);
    await drill.waitForLoadState();
    await expect(drill.locator('.q-card')).toHaveCount(1);   // the first pending question
    return drill;
}

test.describe('Explanation Drill', () => {
    test('drives yes/no questions to completion', async ({ page }) => {
        test.setTimeout(60000);
        const drill = await openDrill(page);

        // The first question and the progress bar (a plain "Progress" label) are shown,
        // under a title naming the goal being explained.
        await expect(drill.locator('.q-card .q-node')).not.toBeEmpty();
        await expect(drill.locator('.q-card .q-btn.yes')).toBeVisible();
        await expect(drill.locator('.q-card .q-btn.notyet')).toBeVisible();
        await expect(drill.locator('#progress-label')).toHaveText('Progress');
        await expect(drill.locator('#drill-title')).toHaveText(/^Understanding why .+:$/);

        // Opening a question highlights its source in the editor (without stealing focus).
        expect(await page.evaluate(() => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            return ed && !ed.getSelection().isEmpty();
        })).toBe(true);

        // Answer "Yes" until the drill completes.
        for (let i = 0; i < 15; i++) {
            if (await drill.locator('#final').isVisible()) break;
            await Promise.all([
                drill.waitForResponse((r: any) => r.url().includes('/leapi')),
                drill.locator('.q-card').last().locator('.q-btn.yes').click(),
            ]);
        }
        await expect(drill.locator('#final')).toBeVisible();
        await expect(drill.locator('#final')).toContainText('Nothing else to show');
        // Progress reached 100%-ish and answers retained their "Yes" state.
        await expect(drill.locator('.q-card .q-btn.yes.on').first()).toBeVisible();
    });

    test('"Not yet" descends, and changing an answer re-questions', async ({ page }) => {
        test.setTimeout(60000);
        const drill = await openHappyDrill(page);

        // "Not yet" on the first question descends into it — a new question appears and
        // the first card retains its "Not yet" state.
        await answerLast(drill, 'notyet');
        await expect(drill.locator('.q-card')).toHaveCount(2);
        await expect(drill.locator('.q-card').first().locator('.q-btn.notyet.on')).toBeVisible();

        // Change the first answer to "Yes": the descended question is dropped and the
        // drill re-questions from there (back to a single pending card here).
        await Promise.all([
            drill.waitForResponse((r: any) => r.url().includes('/leapi')),
            drill.locator('.q-card').first().locator('.q-btn.yes').click(),
        ]);
        await expect(drill.locator('.q-card').first().locator('.q-btn.yes.on')).toBeVisible();
        await expect(drill.locator('.q-card').first().locator('.q-btn.notyet.on')).toHaveCount(0);
    });

    test('a ✕ deletes a question, keeping the others', async ({ page }) => {
        test.setTimeout(60000);
        const drill = await openHappyDrill(page);
        // Build up two answered questions (descend, then understand a case).
        await answerLast(drill, 'notyet');
        await answerLast(drill, 'yes');
        const before = await drill.locator('.q-del').count();   // one ✕ per answered question
        expect(before).toBeGreaterThanOrEqual(2);

        // Delete the first question: one fewer answered question, the drill re-derives.
        await Promise.all([
            drill.waitForResponse((r: any) => r.url().includes('/leapi')),
            drill.locator('.q-del').first().click(),
        ]);
        await expect(drill.locator('.q-del')).toHaveCount(before - 1);
    });

    test('uses its own session, distinct from the editor', async ({ page }) => {
        test.setTimeout(60000);
        const grab = (r: any, op: string, set: (s: string) => void) => {
            if (r.url().includes('/leapi') && r.method() === 'POST') {
                try { const d = JSON.parse(r.postData() || '{}'); if (d.operation === op && d.sessionModule) set(d.sessionModule); } catch { /* ignore */ }
            }
        };
        let editorSession = '';
        page.on('request', (r: any) => grab(r, 'answeringQuery', (s) => (editorSession = s)));
        const drill = await openDrill(page);
        let drillSession = '';
        drill.on('request', (r: any) => grab(r, 'explanationDrill', (s) => (drillSession = s)));

        // Trigger a further drill request so we capture the drill's session module.
        await answerLast(drill, 'yes');
        expect(editorSession).toBeTruthy();
        await expect.poll(() => drillSession).not.toBe('');
        expect(drillSession).not.toBe(editorSession);
    });
});
