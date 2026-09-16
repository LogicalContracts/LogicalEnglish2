import { test, expect } from '@playwright/test';

// The editor's Help menu links to the user-documentation resources nav.json
// gives a menu label, and to the documentation's search, each opening in a new tab.
test.describe('Help menu', () => {
    // Links point at the LE server's own rendered-docs route (/docs/...),
    // not GitHub — clean rendering, no repo chrome.
    const DOCS = [
        { text: 'Introduction to Logical English (tutorial)', href: '/docs/user/tutorials/intro-to-le/intro-to-le' },
        { text: 'Using this editor (manual)', href: '/docs/user/guide/editor' },
        { text: 'Logical English syntax (reference)', href: '/docs/user/reference/language' },
        { text: 'Other systems: import and export', href: '/docs/user/integrations/index' },
        { text: 'Search the documentation…', href: '/docs/search' },
    ];

    test('lists the docs in order, then the search, each opening in a new tab', async ({ page }) => {
        await page.goto('index.html');
        await page.click('text=Help');

        const items = page.locator('.menu-item:has-text("Help") a.dropdown-item');
        await expect(items).toHaveCount(DOCS.length);
        for (let i = 0; i < DOCS.length; i++) {
            await expect(items.nth(i)).toHaveText(DOCS[i].text);
            await expect(items.nth(i)).toHaveAttribute('href', DOCS[i].href);
            await expect(items.nth(i)).toHaveAttribute('target', '_blank');
        }
    });
});
