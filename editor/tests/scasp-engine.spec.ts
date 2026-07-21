import { test, expect } from '@playwright/test';

// A tiny program that runs under both engines: one rule, no negation.
const PROG = `the target language is: prolog.
the templates are:
    *a person* is happy.
    *a person* is rich.
the knowledge base t includes:
    A person is happy
        if the person is rich.
scenario s is:
    alice is rich.
query happy is:
    which person is happy.`;

async function loadAndSelect(page: any) {
    await page.goto('index.html?text=' + encodeURIComponent(PROG));
    await page.waitForFunction(() =>
        typeof (window as any).monaco !== 'undefined' &&
        (window as any).monaco.languages.getLanguages().some((l: any) => l.id === 'le')
    );
    await page.waitForTimeout(800);
    await page.locator('#scenario-select').hover();          // triggers the module load
    await expect.poll(() => page.locator('#query-select option').count(), { timeout: 30000 }).toBeGreaterThan(1);
    await page.selectOption('#scenario-select', 's');
    await page.selectOption('#query-select', 'happy');
}

test.describe('s(CASP) engine', () => {
    test('the engine selector exists with Prolog and s(CASP) options', async ({ page }) => {
        await page.goto('index.html?text=' + encodeURIComponent(PROG));
        await expect(page.locator('#engine-select')).toBeVisible();
        await expect(page.locator('#engine-select option')).toHaveCount(2);
        await expect(page.locator('#engine-select')).toHaveValue('prolog');
    });

    test('the engine pre-selects from the declared target language', async ({ page }) => {
        test.setTimeout(60000);
        // CLP_PROG declares `the target language is: scasp.`
        await page.goto('index.html?text=' + encodeURIComponent(CLP_PROG));
        await page.waitForFunction(() => typeof (window as any).monaco !== 'undefined');
        await page.waitForTimeout(800);
        await page.locator('#scenario-select').hover();   // triggers the load
        await expect.poll(() => page.locator('#query-select option').count(), { timeout: 30000 }).toBeGreaterThan(1);
        await expect(page.locator('#engine-select')).toHaveValue('scasp');
    });

    test('a query answered by the s(CASP) engine renders the answer and explanation', async ({ page }) => {
        test.setTimeout(60000);
        await loadAndSelect(page);
        await page.selectOption('#engine-select', 'scasp');
        await page.click('#btn-query');
        // The answer card appears (same answers pane as the Prolog engine).
        await expect(page.locator('#answers-list .answer-item', { hasText: 'alice is happy' }))
            .toBeVisible({ timeout: 30000 });
        // Selecting it shows the normalised justification tree.
        await page.locator('#answers-list .answer-item', { hasText: 'alice is happy' }).first().click();
        await expect(page.locator('#explanation-tree')).toContainText('alice is happy');
    });

    test('Trace is disabled under the s(CASP) engine (WP5e)', async ({ page }) => {
        test.setTimeout(60000);
        await loadAndSelect(page);
        await expect(page.locator('#btn-trace')).toBeEnabled();
        await page.selectOption('#engine-select', 'scasp');
        await expect(page.locator('#btn-trace')).toBeDisabled();
        await page.selectOption('#engine-select', 'prolog');
        await expect(page.locator('#btn-trace')).toBeEnabled();
    });

    // A program with no scenario: the answer is a CLP constraint, not a value.
    const CLP_PROG = `the target language is: scasp.
the predicates are:
    a claim of *an amount* is covered.
the knowledge base clp includes:
    a claim of an amount is covered
        if the amount is greater than 25000.
query covered is:
    a claim of which amount is covered.`;

    test('s(CASP) renders a symbolic constraint answer (§5b)', async ({ page }) => {
        test.setTimeout(60000);
        await page.goto('index.html?text=' + encodeURIComponent(CLP_PROG));
        await page.waitForFunction(() => typeof (window as any).monaco !== 'undefined');
        await page.waitForTimeout(800);
        await page.locator('#query-select').hover();
        await expect.poll(() => page.locator('#query-select option').count(), { timeout: 30000 }).toBeGreaterThan(1);
        await page.selectOption('#query-select', 'covered');
        await page.selectOption('#engine-select', 'scasp');
        await page.click('#btn-query');
        // The answer is rendered symbolically through the LE template.
        await expect(page.locator('#answers-list .answer-item', { hasText: 'any amount greater than 25000' }))
            .toBeVisible({ timeout: 30000 });
    });

    // Several stable models ("possible worlds"), each with its own assumption set.
    const MULTI_PROG = `the target language is: scasp.
the predicates are:
    the loan is approved.
    the applicant is creditworthy.
    the applicant has collateral.
    the applicant has a good credit score; assumable.
    the applicant has a guarantor; assumable.
    the applicant owns property; assumable.
    the applicant has a large deposit; assumable.
    the applicant is bankrupt.
the knowledge base loan includes:
the loan is approved if
    the applicant is creditworthy
    and the applicant has collateral
    and it is not the case that the applicant is bankrupt.
the applicant is creditworthy if the applicant has a good credit score.
the applicant is creditworthy if the applicant has a guarantor.
the applicant has collateral if the applicant owns property.
the applicant has collateral if the applicant has a large deposit.
scenario application is:
    the applicant is a person.
query approval is:
    the loan is approved.`;

    test('s(CASP) shows several models with per-world assumption sets (§5a/§5c)', async ({ page }) => {
        test.setTimeout(60000);
        await page.goto('index.html?text=' + encodeURIComponent(MULTI_PROG));
        await page.waitForFunction(() => typeof (window as any).monaco !== 'undefined');
        await page.waitForTimeout(800);
        await page.locator('#query-select').hover();
        await expect.poll(() => page.locator('#query-select option').count(), { timeout: 30000 }).toBeGreaterThan(1);
        await page.selectOption('#query-select', 'approval');
        await page.selectOption('#engine-select', 'scasp');
        await page.click('#btn-query');
        // Four distinct possible worlds, each labelled and carrying assumptions.
        await expect(page.locator('#answers-list .answer-item')).toHaveCount(4, { timeout: 30000 });
        await expect(page.locator('#answers-list .model-badge').first()).toContainText('world 1 of 4');
        await expect(page.locator('#answers-list .answer-item.has-unknowns').first()).toBeVisible();
    });

    test('the chosen engine is pinned in the URL', async ({ page }) => {
        await loadAndSelect(page);
        await page.selectOption('#engine-select', 'scasp');
        await expect.poll(() => new URL(page.url()).searchParams.get('engine')).toBe('scasp');
        await page.selectOption('#engine-select', 'prolog');
        await expect.poll(() => new URL(page.url()).searchParams.get('engine')).toBeNull();
    });
});
