import { test, expect } from '@playwright/test';

test.describe('Authentication and Access Control', () => {
  test('anonymous user should not see insurLE2 examples', async ({ page }) => {
    await page.goto('http://localhost:3000/');
    await expect(page.locator('text=Logged in as: anonymous')).toBeVisible();
    await expect(page.locator('text=insureLE2')).not.toBeVisible();
  });

  test('authenticated user should see insurLE2 examples', async ({ page }) => {
    await page.goto('http://localhost:3000/login');
    await page.fill('input[name="email"]', 'support@logicalcontracts.com');
    await page.fill('input[name="password"]', 'LE2rocks');
    await page.click('input[type="submit"]');

    await expect(page.locator('text=Logged in as: support@logicalcontracts.com')).toBeVisible();
    await expect(page.locator('text=insureLE2')).toBeVisible();
  });

  // Regression: opening a restricted example unauthenticated used to silently
  // show an empty editor. It must report the denial and send the user to the
  // login page — and return to the example after a successful login.
  test('restricted example redirects anonymous user to login, then loads', async ({ page }) => {
    test.setTimeout(60000);
    const dialogs: string[] = [];
    page.on('dialog', async (d) => { dialogs.push(d.message()); await d.accept(); });

    await page.goto('http://localhost:3000/editor/index.html?example=insureLE2/globals');
    await page.waitForURL(/\/login/, { timeout: 20000 });
    expect(dialogs.some(m => m.includes('requires login'))).toBe(true);
    // The login form carries the editor URL to return to after login.
    await expect(page.locator('input[name="return"]')).toHaveValue(/example=insureLE2/);

    // Logging in returns to the editor, which now loads the restricted example.
    await page.fill('input[name="email"]', 'support@logicalcontracts.com');
    await page.fill('input[name="password"]', 'LE2rocks');
    await page.click('input[type="submit"]');
    await page.waitForURL(/example=insureLE2/, { timeout: 20000 });
    await expect(page.locator('#filename-display')).toHaveText('insureLE2/globals.le');
  });
});
