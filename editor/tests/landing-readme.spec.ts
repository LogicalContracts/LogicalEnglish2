// The landing page's README panel (web_extras/landing/readme-panel.js): a
// folder with a README.md has a button after its name that shows the README
// beside the list, without opening or closing the folder; `?readme=<folder>`
// opens it directly; a link to a program opens that program in the editor on
// the scenario and question the link names.
import { test, expect } from '@playwright/test';

const modelText = () => {
    const ed = (window as any).monaco?.editor?.getEditors()[0];
    return ed ? ed.getModel().getValue() as string : '';
};

test.describe('landing page README panel', () => {
    test('a folder with a README has a button that shows it', async ({ page }) => {
        await page.goto('/');
        const folder = page.locator('details.le-folder[data-path="migration/"]');
        const button = folder.locator(':scope > summary > .readme-button');
        await expect(button).toHaveCount(1);
        const wasOpen = await folder.evaluate((d: HTMLDetailsElement) => d.open);
        await button.click();
        const panel = page.locator('.readme-panel');
        await expect(panel).toBeVisible();
        await expect(panel.locator('h2').first()).toBeVisible();
        expect(await folder.evaluate((d: HTMLDetailsElement) => d.open)).toBe(wasOpen);
        expect(new URL(page.url()).searchParams.get('readme')).toBe('migration');
        await page.keyboard.press('Escape');
        await expect(panel).toBeHidden();
        expect(new URL(page.url()).searchParams.get('readme')).toBeNull();
    });

    test('every README on the page has its button', async ({ page }) => {
        await page.goto('/');
        const sources = await page.locator('.readme-src[data-for]').count();
        expect(sources).toBeGreaterThan(0);
        await expect(page.locator('.readme-button')).toHaveCount(sources);
    });

    test('a folder link in a README opens that folder\'s README', async ({ page }) => {
        await page.goto('/?readme=migration');
        const panel = page.locator('.readme-panel');
        await expect(panel).toBeVisible();
        await panel.locator('a[data-readme="migration/blawx/"]').first().click();
        await expect(panel).toContainText('Blawx');
        expect(new URL(page.url()).searchParams.get('readme')).toBe('migration/blawx');
    });

    test('a program link opens the program on its scenario and question', async ({ page }) => {
        test.setTimeout(90000);
        await page.goto('/?readme=migration/blawx');
        const link = page.locator('.readme-panel a[href*="example=migration/blawx/"][href*="scenario="]').first();
        const href = (await link.getAttribute('href'))!;
        const u = new URL(href, page.url());
        expect(u.pathname).toBe('/editor/index.html');
        expect(u.searchParams.get('query')).not.toBeNull();
        await link.click();
        await expect.poll(() => page.evaluate(modelText), { timeout: 45000 })
            .toContain('scenario ' + u.searchParams.get('scenario'));
    });
});
