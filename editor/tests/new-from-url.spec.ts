import { test, expect } from '@playwright/test';

// The "File > New from URL..." flow: a modal takes a URL, the document is
// fetched and loaded into the editor. The fetch is intercepted so the test
// needs no external host.

const PROGRAM = [
    'the templates are:',
    '    *a person* is happy.',
    '',
    'the knowledge base fromurl includes:',
    '',
    'a person is happy if the person is healthy.',
    ''
].join('\n');

test.describe('New from URL', () => {
    test('fetches a URL and loads it into the editor', async ({ page }) => {
        // Serve the fixture program at an arbitrary external-looking URL.
        await page.route('https://example.test/kb/demo.le', route =>
            route.fulfill({ status: 200, contentType: 'text/plain', body: PROGRAM }));

        await page.goto('index.html');
        await page.click('text=File');
        await page.click('#menu-new-from-url');

        const modal = page.locator('#new-from-url-modal');
        await expect(modal).toBeVisible();

        await page.fill('#new-from-url-input', 'https://example.test/kb/demo.le');
        await page.click('#new-from-url-load');

        // Modal closes, the program is in the editor, filename reflects the URL.
        await expect(modal).toBeHidden();
        await expect(page.locator('#filename-display')).toHaveText('demo.le');
        await expect.poll(async () =>
            await page.evaluate(() => (window as any).monaco?.editor?.getModels?.()[0]?.getValue() || '')
        ).toContain('a person is happy if');
    });

    test('shows an error when the fetch fails', async ({ page }) => {
        await page.route('https://example.test/missing.le', route =>
            route.fulfill({ status: 404, contentType: 'text/plain', body: 'not found' }));

        await page.goto('index.html');
        await page.click('text=File');
        await page.click('#menu-new-from-url');
        await page.fill('#new-from-url-input', 'https://example.test/missing.le');
        await page.click('#new-from-url-load');

        // The modal stays open and shows the error; the editor is untouched.
        await expect(page.locator('#new-from-url-modal')).toBeVisible();
        await expect(page.locator('#new-from-url-error')).toBeVisible();
        await expect(page.locator('#new-from-url-error')).toContainText('404');
    });

    test('rejects an invalid URL without fetching', async ({ page }) => {
        await page.goto('index.html');
        await page.click('text=File');
        await page.click('#menu-new-from-url');
        await page.fill('#new-from-url-input', 'not a url');
        await page.click('#new-from-url-load');
        await expect(page.locator('#new-from-url-error')).toContainText('valid URL');
        await expect(page.locator('#new-from-url-modal')).toBeVisible();
    });
});
