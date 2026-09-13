import { test, expect } from '@playwright/test';

// File > Open of a file that is not Logical English: the server translates it
// with the translator registered for it (le_import.pl) and the program opens
// in a tab of its own, with a note saying what was done. A file no translator
// reads still opens — as a program whose TODO comment holds its text.
// The picker is the plain <input type=file> (the File System Access picker is
// removed first, since a test cannot drive the native dialog).

const editorText = (page: any) => page.evaluate(() => {
    const ms = (window as any).monaco?.editor?.getModels?.() || [];
    return ms.map((m: any) => m.getValue()).join('\n=====\n');
});

async function openFile(page: any, name: string, content: string) {
    await page.evaluate(() => { delete (window as any).showOpenFilePicker; });
    const [chooser] = await Promise.all([
        page.waitForEvent('filechooser'),
        page.evaluate(() => (document.getElementById('menu-open') as HTMLElement).click()),
    ]);
    await chooser.setFiles({ name, mimeType: 'text/plain', buffer: Buffer.from(content) });
}

test.describe('Opening another system\'s file', () => {
    test('a file no translator reads opens as a TODO', async ({ page }) => {
        await page.goto('index.html');
        await page.waitForSelector('.monaco-editor', { timeout: 30000 });
        await openFile(page, 'notes.xyz', 'first line\nsecond line');
        await expect.poll(() => editorText(page), { timeout: 30000 }).toContain('% TODO: translate notes.xyz');
        expect(await editorText(page)).toContain('%   | second line');
        await expect(page.locator('#import-report')).toBeVisible();
        await expect(page.locator('#filename-display')).toHaveText('notes.le');
        // File > Show the Original: the upload, kept in sources/ beside the program
        await page.locator('#import-report span').click();
        await page.evaluate(() => (document.getElementById('menu-show-original') as HTMLElement).click());
        await expect(page.locator('#source-viewer')).toBeVisible({ timeout: 15000 });
        await expect(page.locator('#source-viewer pre')).toContainText('second line', { timeout: 15000 });
    });

    test('a program that was not converted says it has no original', async ({ page }) => {
        await page.goto('index.html');
        await page.waitForSelector('.monaco-editor', { timeout: 30000 });
        const message = new Promise<string>(resolve => page.once('dialog', async (d: any) => {
            resolve(d.message()); await d.dismiss();
        }));
        await page.evaluate(() => (document.getElementById('menu-show-original') as HTMLElement).click());
        expect(await message).toContain('No original is kept for this program');
    });

    test('a file a translator reads opens translated', async ({ page, request }) => {
        const formats = await (await request.post('/leapi', {
            data: { token: 'myToken123', operation: 'importFormats' } })).json();
        test.skip(!(formats.formats || []).some((f: any) => f.id === 'miniscript'),
                  'no Miniscript translator on this server (the InsurLE extensions are not installed)');
        await page.goto('index.html');
        await page.waitForSelector('.monaco-editor', { timeout: 30000 });
        await openFile(page, 'vault.policy', 'or(pk(A),and(pk(B),older(144)))\n');
        await expect.poll(() => editorText(page), { timeout: 60000 }).toContain('the coin can be spent');
        await expect(page.locator('#import-report')).toContainText('translated from');
    });
});
