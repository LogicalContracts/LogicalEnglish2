import { test, expect } from '@playwright/test';

// The landing page's ?dir= parameter focuses the example list on one example
// subdirectory (sharable links into a group of examples), with a "[show all]"
// link back. Unknown and access-restricted directories fall back to the full
// list with a not-found note — indistinguishably, so the parameter cannot
// probe restricted directories' existence.
test.describe('Landing page ?dir= focus', () => {
    test('focuses the example list on a subdirectory', async ({ page }) => {
        await page.goto('http://localhost:3000/?dir=abduction');
        // Focus note with a way back to the full list.
        await expect(page.locator('text=showing')).toBeVisible();
        await expect(page.locator('a', { hasText: '[show all]' })).toHaveAttribute('href', '/');
        // The subdirectory's examples link into the editor with the dir prefix…
        await expect(page.locator('a[href="/editor/index.html?example=abduction/grass_is_wet"]')).toBeVisible();
        // …and top-level examples are not listed.
        await expect(page.locator('a[href="/editor/index.html?example=citizenship"]')).not.toBeVisible();
    });

    test('unknown directory falls back to the full list with a note', async ({ page }) => {
        await page.goto('http://localhost:3000/?dir=no_such_dir');
        await expect(page.locator("text=Example directory 'no_such_dir' not found.")).toBeVisible();
        await expect(page.locator('a[href="/editor/index.html?example=citizenship"]')).toBeVisible();
    });

    test('restricted directory behaves as not found for anonymous users', async ({ page }) => {
        await page.goto('http://localhost:3000/?dir=insureLE2');
        await expect(page.locator('text=Logged in as: anonymous')).toBeVisible();
        await expect(page.locator("text=Example directory 'insureLE2' not found.")).toBeVisible();
        await expect(page.locator('a[href^="/editor/index.html?example=insureLE2/"]')).not.toBeVisible();
    });

    test('restricted directory can be focused by an authorized user', async ({ page }) => {
        await page.goto('http://localhost:3000/login');
        await page.fill('input[name="email"]', 'support@logicalcontracts.com');
        await page.fill('input[name="password"]', 'LE2rocks');
        await page.click('input[type="submit"]');
        await page.goto('http://localhost:3000/?dir=insureLE2');
        await expect(page.locator('text=showing')).toBeVisible();
        await expect(page.locator('a[href^="/editor/index.html?example=insureLE2/"]').first()).toBeVisible();
    });
});
