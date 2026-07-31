import { test, expect } from '@playwright/test';

// Smoke tests for the LE Contract Assistant web app (web_extras/contract_assistant).
// A job started with a nonexistent model fails in seconds but still emits log
// lines, stage changes and a config summary — enough to exercise the whole
// Run-screen poll loop without any LLM.

const TOKEN = 'myToken123';

async function startFailingJob(request: any): Promise<string> {
    const resp = await request.post('/leapi', {
        data: {
            token: TOKEN,
            operation: 'contract_start',
            wording: { name: 'c.md', text: '# Tiny\n\nA tiny contract.\n' },
            model: 'nonexistent-model',
            budget: { preset: 'draft', minutes: 1 }
        }
    });
    const data = await resp.json();
    expect(data.job).toBeTruthy();
    return data.job;
}

test.describe('Contract Assistant UI', () => {
    test('setup screen loads with models and uploads', async ({ page }) => {
        await page.goto('/web_extras/contract_assistant/index.html');
        await expect(page.locator('#file-wording')).toBeAttached();
        // The model picker fills from list_models.
        await expect(async () => {
            expect(await page.locator('#model option').count()).toBeGreaterThan(0);
        }).toPass({ timeout: 15000 });
        // Start stays disabled until a wording file is chosen.
        await expect(page.locator('#btn-start')).toBeDisabled();
    });

    // The optional "Existing LE code" box (group 2) counts what was pasted and
    // triggers a cost estimate; the cost line lives with the effort budget.
    test('existing LE code box and cost estimate render', async ({ page }) => {
        await page.goto('/web_extras/contract_assistant/index.html');
        const area = page.locator('#existing-code');
        await expect(area).toBeVisible();
        await expect(page.locator('#existing-note')).toHaveText('');
        await area.fill('the templates are:\n    *a person* is happy.\n% a comment line\n');
        await expect(page.locator('#existing-note')).toContainText('2 significant line(s)');

        // The cost line is present and says something (an unpriced model or a
        // price table that could not be fetched still produces a message).
        await expect(page.locator('#cost')).toBeVisible();
        await expect(page.locator('#cost-value')).not.toBeEmpty();
    });

    // Regression: the Run screen must keep showing the scrolling log, the elapsed
    // time and the choices summary on every poll (a title rewrite once destroyed
    // the elapsed span, and the resulting render error killed the log updates).
    test('run screen shows log, elapsed time and config summary', async ({ page, request }) => {
        test.setTimeout(60000);
        const job = await startFailingJob(request);
        // Reattach by URL hash, as a reloaded tab would.
        await page.goto('/web_extras/contract_assistant/index.html#' + job);

        // The log accumulates lines (stage headers at minimum).
        await expect(page.locator('#log')).toContainText('Stage', { timeout: 20000 });
        // The choices summary and the elapsed clock render.
        await expect(page.locator('#run-summary')).toContainText('nonexistent-model');
        await expect(page.locator('#run-summary')).toContainText('K=1 W=1');
        await expect(page.locator('#run-elapsed')).toContainText('elapsed');

        // The job fails fast (unknown model): terminal state disables Cancel and
        // offers the way back.
        await expect(page.locator('#run-title-text')).toHaveText('Failed', { timeout: 30000 });
        await expect(page.locator('#log')).toContainText('Job failed');
        await expect(page.locator('#btn-cancel')).toBeDisabled();
        await expect(page.locator('#btn-run-back')).toBeVisible();

        // ... and the log survived the terminal transition (regression guard).
        await expect(page.locator('#log')).toContainText('Vocabulary sample');
    });
});
