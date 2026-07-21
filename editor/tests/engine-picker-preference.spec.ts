import { test, expect } from '@playwright/test';

// LE is Prolog-biased, so the engine picker can be hidden for Prolog programs.
// The Misc-menu preference "Always show engine choice" (default) vs "Show engine
// choice only for non-Prolog" controls this; it is persisted in localStorage.

const PROLOG_PROG = `the target language is: prolog.
the templates are:
    *a person* is happy.
    *a person* is rich.
the knowledge base t includes:
    a person is happy if the person is rich.
scenario s is:
    alice is rich.
query happy is:
    which person is happy.`;

const SCASP_PROG = `the target language is: scasp.
the templates are:
    *a person* is happy.
    *a person* is rich.
the knowledge base t includes:
    a person is happy if the person is rich.
scenario s is:
    alice is rich.
query happy is:
    which person is happy.`;

async function loadProgram(page: any, prog: string) {
    await page.goto('index.html?text=' + encodeURIComponent(prog));
    await page.waitForFunction(() =>
        typeof (window as any).monaco !== 'undefined' &&
        (window as any).monaco.languages.getLanguages().some((l: any) => l.id === 'le')
    );
    await page.waitForTimeout(800);
    await page.locator('#scenario-select').hover();          // triggers the module load
    await expect.poll(() => page.locator('#query-select option').count(), { timeout: 30000 }).toBeGreaterThan(1);
}

test.describe('engine-picker visibility preference', () => {
    test('default (always) shows the engine picker for a Prolog program', async ({ page }) => {
        await loadProgram(page, PROLOG_PROG);
        await expect(page.locator('#engine-control')).toBeVisible();
    });

    test('non-Prolog mode hides the picker for a Prolog program', async ({ page }) => {
        await page.addInitScript(() => localStorage.setItem('le-engine-picker-mode', 'nonprolog'));
        await loadProgram(page, PROLOG_PROG);
        await expect(page.locator('#engine-control')).toBeHidden();
    });

    test('non-Prolog mode still shows the picker for an s(CASP) program', async ({ page }) => {
        test.setTimeout(60000);
        await page.addInitScript(() => localStorage.setItem('le-engine-picker-mode', 'nonprolog'));
        await loadProgram(page, SCASP_PROG);
        await expect(page.locator('#engine-select')).toHaveValue('scasp');
        await expect(page.locator('#engine-control')).toBeVisible();
    });

    // The picker visibility must be correct from the editor text alone, BEFORE the
    // module is lazily loaded (which happens on mouse-enter of the query controls).
    async function openWithoutLoading(page: any, prog: string) {
        await page.goto('index.html?text=' + encodeURIComponent(prog));
        await page.waitForFunction(() => typeof (window as any).monaco !== 'undefined');
        await page.waitForTimeout(600);   // editor content set; NO scenario/query hover
    }

    test('non-Prolog mode hides the picker for a Prolog program without loading', async ({ page }) => {
        await page.addInitScript(() => localStorage.setItem('le-engine-picker-mode', 'nonprolog'));
        await openWithoutLoading(page, PROLOG_PROG);
        await expect(page.locator('#engine-control')).toBeHidden();
    });

    test('non-Prolog mode shows the picker for an s(CASP) program without loading', async ({ page }) => {
        await page.addInitScript(() => localStorage.setItem('le-engine-picker-mode', 'nonprolog'));
        await openWithoutLoading(page, SCASP_PROG);
        await expect(page.locator('#engine-control')).toBeVisible();
    });

    test('the Misc-menu toggle hides/shows the picker and persists', async ({ page }) => {
        await loadProgram(page, PROLOG_PROG);
        await expect(page.locator('#engine-control')).toBeVisible();

        // "Show engine choice only for non-Prolog" — Prolog program -> hidden.
        await page.evaluate(() => (document.getElementById('menu-engine-nonprolog') as HTMLElement).click());
        await expect(page.locator('#engine-control')).toBeHidden();
        expect(await page.evaluate(() => localStorage.getItem('le-engine-picker-mode'))).toBe('nonprolog');

        // Back to "Always show engine choice" -> visible again.
        await page.evaluate(() => (document.getElementById('menu-engine-always') as HTMLElement).click());
        await expect(page.locator('#engine-control')).toBeVisible();
        expect(await page.evaluate(() => localStorage.getItem('le-engine-picker-mode'))).toBe('always');
    });
});
