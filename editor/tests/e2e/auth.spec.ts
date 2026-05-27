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
});
