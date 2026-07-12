import { test, expect } from '@playwright/test';

// The editor's Help menu links to the three user-documentation resources,
// opening them in a new tab.
test.describe('Help menu', () => {
    // Links now point at the LE server's own rendered-docs route (/docs/...),
    // not GitHub — clean rendering, no repo chrome.
    const DOCS = [
        { text: 'Introduction to Logical English (tutorial)', href: '/docs/tutorial0/IntroToLE2' },
        { text: 'Using this editor (manual)', href: '/docs/howToUse' },
        { text: 'Logical English syntax (reference)', href: '/docs/le_summary' },
    ];

    test('lists the three docs in order, each opening in a new tab', async ({ page }) => {
        await page.goto('index.html');
        await page.click('text=Help');

        const items = page.locator('.menu-item:has-text("Help") a.dropdown-item');
        await expect(items).toHaveCount(3);
        for (let i = 0; i < DOCS.length; i++) {
            await expect(items.nth(i)).toHaveText(DOCS[i].text);
            await expect(items.nth(i)).toHaveAttribute('href', DOCS[i].href);
            await expect(items.nth(i)).toHaveAttribute('target', '_blank');
        }
    });
});
