import { test, expect } from '@playwright/test';

// The Flip… button beside Query: a flip query (docs/le_summary.md §17.7) about
// the selected answer — "which minimal change to the scenario makes it the
// case that it is not the case that <answer>" — composed in a small dialog and
// run as a custom query, so its change sets show as the answers.
test.describe('Flip button', () => {
    test('flips the selected answer', async ({ page }) => {
        test.setTimeout(120000);
        await page.goto('index.html?example=RulesRus/customs/plastics_cbp&scenario=ny_n363253&query=heading');
        await expect(page.locator('#query-select')).toHaveValue('heading', { timeout: 90000 });
        await page.click('#btn-query');
        const answer = page.locator('#answers-list .answer-item.selected');
        await expect(answer).toHaveText('the heading of the self-feeding bowl clamp is 3926', { timeout: 60000 });

        await page.click('#btn-flip');
        await expect(page.locator('#flip-modal')).toBeVisible();
        await expect(page.locator('#flip-opener')).toContainText('which minimal change to the scenario makes it the case that');
        await expect(page.locator('#flip-not')).toBeChecked();
        await expect(page.locator('#flip-goal')).toHaveValue('the heading of the self-feeding bowl clamp is 3926');

        await page.click('#flip-run');
        await expect(page.locator('#flip-modal')).toBeHidden();
        await expect(page.locator('#query-select')).toHaveValue('___custom___');
        await expect(page.locator('#custom-query-text')).toHaveValue(
            'which minimal change to the scenario makes it the case that it is not the case that the heading of the self-feeding bowl clamp is 3926');
        // the change sets are the answers; the office's principal-use judgment is one
        await expect(page.locator('#answers-list .answer-item', {
            hasText: 'add: the principal use of the self-feeding bowl clamp is household use' })).toHaveCount(1, { timeout: 90000 });

        // Flip again offers the flip itself, to edit
        await page.click('#btn-flip');
        await expect(page.locator('#flip-not')).toBeChecked();
        await expect(page.locator('#flip-goal')).toHaveValue('the heading of the self-feeding bowl clamp is 3926');
        await page.click('#flip-cancel');
    });
});
