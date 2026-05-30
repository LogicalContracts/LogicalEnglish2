import { test, expect } from '@playwright/test';

// Sample game data mimicking the shape produced by the server's getGameData
// operation: a query goal, rules (head + body conditions) and facts.
//
// Proof tree for this data:
//   GOAL: "john is a citizen"
//     <- rule "john is a citizen if born + adult"
//          body slot 1 "john is born in the country" <- fact
//          body slot 2 "john is an adult"            <- fact
const SAMPLE_GAME_DATA = {
    query: 'john is a citizen',
    rules: [
        {
            head: 'john is a citizen',
            body: ['john is born in the country', 'john is an adult'],
            start: 0,
            end: 50
        }
    ],
    facts: [
        { fact: 'john is born in the country', start: 60, end: 90 },
        { fact: 'john is an adult', start: 100, end: 120 },
        { fact: 'mary is a tourist', start: 130, end: 150 }
    ]
};

async function openProofGame(page: any) {
    // Seed localStorage before the page module reads it.
    await page.goto('./proof-game.html');
    await page.evaluate((data: any) => {
        localStorage.setItem('le_proof_game_data', JSON.stringify(data));
    }, SAMPLE_GAME_DATA);
    await page.reload();
    await expect(page.locator('.pg-board')).toBeVisible();
}

test.describe('LE Proof Game (drag piece into slot)', () => {
    test('renders the goal, a draggable rule card, and fact pieces', async ({ page }) => {
        await openProofGame(page);

        // Goal card present with exactly one (empty) slot on the board.
        await expect(page.locator('.pg-query-card')).toBeVisible();

        // Tray holds 3 fact pieces + 1 rule piece.
        await expect(page.locator('#pg-tray-pieces > .pg-piece-fact')).toHaveCount(3);
        await expect(page.locator('#pg-tray-pieces > .pg-piece-rule')).toHaveCount(1);

        // The rule piece carries its own two body slots (rendered inside it).
        await expect(page.locator('.pg-piece-rule .pg-slot')).toHaveCount(2);
    });

    test('a rule can be dropped into the goal, then facts into its body slots', async ({ page }) => {
        await openProofGame(page);

        const goalSlot = page.locator('.pg-query-card > .pg-slot');
        const rulePiece = page.locator('.pg-piece-rule');

        // Drag the whole rule card into the goal slot.
        await rulePiece.dragTo(goalSlot);
        await expect(goalSlot).toHaveClass(/pg-slot-filled/);
        // The rule (with its nested body slots) now lives inside the goal slot.
        await expect(page.locator('.pg-query-card .pg-piece-rule')).toBeVisible();
        await expect(page.locator('.pg-query-card .pg-piece-rule .pg-slot')).toHaveCount(2);

        // Now fill the rule's two body slots with the matching facts.
        const bornFact = page.locator('.pg-piece-fact', { hasText: 'john is born in the country' });
        const adultFact = page.locator('.pg-piece-fact', { hasText: 'john is an adult' });
        const bornSlot = page.locator('.pg-piece-rule .pg-slot').nth(0);
        const adultSlot = page.locator('.pg-piece-rule .pg-slot').nth(1);

        await bornFact.dragTo(bornSlot);
        await adultFact.dragTo(adultSlot);

        // Only the leftover (wrong) fact remains in the tray.
        await expect(page.locator('#pg-tray-pieces > .pg-piece')).toHaveCount(1);

        // Check Proof => the whole tree is correct.
        await page.click('#btn-check');
        await expect(goalSlot).toHaveClass(/pg-slot-correct/);
        await expect(bornSlot).toHaveClass(/pg-slot-correct/);
        await expect(adultSlot).toHaveClass(/pg-slot-correct/);
        await expect(page.locator('#pg-status')).toContainText('Proof complete');
    });

    test('a rule whose body slots are unfilled is not a complete proof', async ({ page }) => {
        await openProofGame(page);

        const goalSlot = page.locator('.pg-query-card > .pg-slot');
        const rulePiece = page.locator('.pg-piece-rule');

        // Drop the rule into the goal but leave its body slots empty.
        await rulePiece.dragTo(goalSlot);

        await page.click('#btn-check');
        // Goal slot is flagged wrong because the rule isn't fully justified.
        await expect(goalSlot).toHaveClass(/pg-slot-wrong/);
        await expect(page.locator('#pg-status')).not.toContainText('Proof complete');
    });

    test('a wrong fact in a body slot is flagged on Check Proof', async ({ page }) => {
        await openProofGame(page);

        const goalSlot = page.locator('.pg-query-card > .pg-slot');
        await page.locator('.pg-piece-rule').dragTo(goalSlot);

        const wrongFact = page.locator('.pg-piece-fact', { hasText: 'mary is a tourist' });
        const bornSlot = page.locator('.pg-piece-rule .pg-slot').nth(0);
        await wrongFact.dragTo(bornSlot);

        await page.click('#btn-check');
        await expect(bornSlot).toHaveClass(/pg-slot-wrong/);
        await expect(page.locator('#pg-status')).not.toContainText('Proof complete');
    });

    test('Reset clears slots and returns all pieces to the tray', async ({ page }) => {
        await openProofGame(page);

        const goalSlot = page.locator('.pg-query-card > .pg-slot');
        await page.locator('.pg-piece-rule').dragTo(goalSlot);
        await expect(page.locator('#pg-tray-pieces > .pg-piece')).toHaveCount(3);

        await page.click('#btn-reset');
        // 3 facts + 1 rule back in the tray.
        await expect(page.locator('#pg-tray-pieces > .pg-piece')).toHaveCount(4);
        await expect(goalSlot).not.toHaveClass(/pg-slot-filled/);
    });

    test('pre-school mode hides text on pieces', async ({ page }) => {
        await openProofGame(page);
        await page.uncheck('#mode-toggle');
        const fact = page.locator('#pg-tray-pieces > .pg-piece-fact').first();
        await expect(fact).toHaveText('');
    });
});
