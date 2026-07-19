// The File > "QR code…" feature: shows the current document as a scannable
// QR. A server example uses its plain parameterized URL; an edited document
// travels compressed in the #lzp fragment (deflate + base64url), which the
// editor decompresses on load. A URL longer than the QR limit is refused
// with an explanatory message instead of producing an unscannable code.
import { test, expect } from '@playwright/test';

const PROGRAM = `the target language is: prolog.

the templates are:
    *a creature* is a dragon,
    *a creature* is happy.

the knowledge base qr includes:

a creature is happy
    if the creature is a dragon.

scenario s is:
    Bob is a dragon.

query q is:
    which creature is happy.
`;

test.describe('QR code', () => {
    test('a server example gets a QR of its parameterized URL', async ({ page }) => {
        await page.goto('index.html?example=happy_dragon&scenario=smoky&query=happy');
        await expect(page.locator('#filename-display')).toHaveText('happy_dragon.le');
        await page.click('text=File');
        await page.click('#menu-qr-code');
        await expect(page.locator('#qr-modal')).toBeVisible();
        const src = await page.locator('#qr-image').getAttribute('src');
        expect(src).toMatch(/^data:image\/gif/);
        await expect(page.locator('#qr-url')).toContainText('example=happy_dragon');
        await expect(page.locator('#qr-url')).not.toContainText('lzp=');
        await page.click('#qr-modal-close');
        await expect(page.locator('#qr-modal')).toBeHidden();
    });

    test('an edited document round-trips through the compressed #lzp URL', async ({ page }) => {
        await page.goto('index.html?text=' + encodeURIComponent(PROGRAM));
        await page.click('text=File');
        await page.click('#menu-qr-code');
        await expect(page.locator('#qr-modal')).toBeVisible();
        expect(await page.locator('#qr-image').getAttribute('src')).toMatch(/^data:image\/gif/);
        const url = (await page.locator('#qr-url').textContent()) || '';
        expect(url).toContain('#lzp=');
        expect(url).not.toContain('text=');

        // Following the QR's URL restores the exact program.
        await page.goto(url);
        await expect.poll(async () =>
            await page.evaluate(() => (window as any).monaco?.editor?.getModels?.()[0]?.getValue() || '')
        ).toBe(PROGRAM);
    });

    test('an over-long URL is refused with an explanation', async ({ page }) => {
        await page.goto('index.html');
        // A program too big even after compression (incompressible content).
        await page.waitForFunction(() => !!(window as any).monaco?.editor?.getModels?.()?.length);
        await page.evaluate(() => {
            const junk = Array.from({ length: 4000 }, () => Math.random().toString(36).slice(2)).join(' ');
            (window as any).monaco.editor.getModels()[0].setValue('the target language is: prolog.\n% ' + junk);
        });
        await page.click('text=File');
        await page.click('#menu-qr-code');
        await expect(page.locator('#qr-modal')).toBeHidden();
        await expect(page.getByText(/too long for a QR code/)).toBeVisible();
    });
});
