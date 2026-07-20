// Bento Box window: an answer's explanation tree rendered as nested bento
// compartments — outer box = the rule proving the root, inner boxes = its body
// conditions, leaves = the facts. Opened from the answer context menu. Each
// box has a unique colour (legend at the side), its literal as a tooltip, and
// clicking it highlights the node's source in the editor. Failed nodes are
// empty dark compartments.
import { test, expect } from '@playwright/test';

test.describe('Bento Box', () => {
    test('opens from the answer menu, boxes + legend + editor highlight', async ({ page }) => {
        test.setTimeout(120000);
        await page.goto('index.html?example=happy_dragon&scenario=smoky&query=happy');
        await expect(page.locator('#filename-display')).toHaveText('happy_dragon.le');
        // Wait until the URL's scenario/query selections applied (the module
        // load can be slow on a cold server) — clicking Query before that
        // queries an empty selection.
        await expect(page.locator('#query-select')).toHaveValue('happy', { timeout: 45000 });

        await page.click('#btn-query');
        const answer = page.locator('.answer-item').first();
        await expect(answer).toBeVisible({ timeout: 45000 });

        // Right-click the answer -> "Bento Box…" in the context menu.
        await answer.click({ button: 'right' });
        const item = page.locator('#menu-bento-box');
        await expect(item).toBeVisible();
        const [bento] = await Promise.all([
            page.waitForEvent('popup'),
            item.click(),
        ]);
        await bento.waitForLoadState();

        // Nested boxes: an outer compartment containing inner ones, and leaves
        // carrying the fact text ("the food").
        await expect(bento.locator('.bento-box').first()).toBeVisible();
        expect(await bento.locator('.bento-box').count()).toBeGreaterThan(3);
        expect(await bento.locator('.bento-box .bento-box').count()).toBeGreaterThan(0);
        const leaf = bento.locator('.bento-box.leaf').first();
        await expect(leaf).not.toBeEmpty();
        // The literal is the hover tooltip.
        expect(await leaf.getAttribute('title')).toBeTruthy();

        // The vacuous "for all cases" branch shows as empty dark space.
        expect(await bento.locator('.bento-box.failed').count()).toBeGreaterThan(0);

        // One legend entry per box, colour-swatched.
        const boxes = await bento.locator('.bento-box').count();
        await expect(bento.locator('#legend-rows .legend-row')).toHaveCount(boxes);
        await expect(bento.locator('#legend h2')).toHaveText('Legend');

        // Clicking a box highlights its source in the editor that opened it.
        await leaf.click();
        await expect.poll(async () =>
            await page.evaluate(() => {
                const ed = (window as any).monaco?.editor?.getEditors?.()[0];
                const sel = ed?.getSelection();
                return sel ? !sel.isEmpty() : false;
            })
        ).toBe(true);
    });

    // Scenario fact image additions ("<fact>; image \"URL\".") become the leaf
    // compartments' content. Only the img elements' src attributes are asserted
    // (not actual loading), so the test needs no network access.
    test('fact image additions render in the leaves', async ({ page }) => {
        test.setTimeout(120000);
        await page.goto('index.html?example=sequencer&scenario=groovebox&query=design');
        await expect(page.locator('#filename-display')).toHaveText('sequencer.le');
        await expect(page.locator('#query-select')).toHaveValue('design', { timeout: 45000 });
        await page.click('#btn-query');
        const answer = page.locator('.answer-item').first();
        await expect(answer).toBeVisible({ timeout: 45000 });
        await answer.click({ button: 'right' });
        const [bento] = await Promise.all([
            page.waitForEvent('popup'),
            page.click('#menu-bento-box'),
        ]);
        await bento.waitForLoadState();
        await expect(bento.locator('.bento-box').first()).toBeVisible();
        // 8 annotated facts (run button, tempo dial, 4 pads, fader, filter
        // knob) + 1 template image ("the power is on" — a no-variable
        // template's addition, used as the fallback for its plain fact).
        await expect(bento.locator('img.bento-img')).toHaveCount(9);
        expect(await bento.locator('img.bento-img').first().getAttribute('src'))
            .toContain('upload.wikimedia.org');
        // The template-image leaf: its fact has no image of its own.
        await expect(bento.locator('.bento-box.leaf.has-image[title*="the power is on"] img')).toHaveCount(1);
        // Un-annotated leaves (the panel facts) still show their text.
        await expect(bento.locator('.bento-box.leaf', { hasText: 'is a panel of' }).first()).toBeVisible();
    });
});
