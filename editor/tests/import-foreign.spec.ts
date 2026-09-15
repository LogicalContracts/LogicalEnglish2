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

    // File > Export to Another System: the way back. A program no exporter
    // writes says so; a spending policy's twin is written as a Miniscript
    // policy, shown with its notes and the Minsc link.
    test('a program no exporter writes says so', async ({ page }) => {
        await page.goto('index.html');
        await page.waitForSelector('.monaco-editor', { timeout: 30000 });
        const message = new Promise<string>(resolve => page.once('dialog', async (d: any) => {
            resolve(d.message()); await d.dismiss();
        }));
        await page.evaluate(() => (document.getElementById('menu-export') as HTMLElement).click());
        expect(await message).toContain('No exporter on this server can write this program');
    });

    // A program the exporter is offered for but cannot write faithfully is
    // refused: nothing is written, and each problem links to its line.
    test('a program with something the target cannot say is refused, with its lines', async ({ page, request }) => {
        const PROG = 'the target language is: prolog.\n\nthe templates are:\n    *a person* owes *an amount*.\n    *a person* has a debt of *an amount*.\n\nthe knowledge base t includes:\n\na person has a debt of a total if\n    the total is the sum of each amount such that\n        the person owes the amount.\n';
        const formats = await (await request.post('/leapi', {
            data: { token: 'myToken123', operation: 'exportFormats', le: PROG } })).json();
        test.skip(!(formats.formats || []).some((f: any) => f.id === 'legalruleml'),
                  'no LegalRuleML exporter on this server (the InsurLE extensions are not installed)');
        await page.goto('index.html');
        await page.waitForSelector('.monaco-editor', { timeout: 30000 });
        await page.evaluate((p: string) => (window as any).monaco.editor.getModels()[0].setValue(p), PROG);
        await page.evaluate(() => (document.getElementById('menu-export') as HTMLElement).click());
        if (await page.locator('#export-list').count()) {
            await page.locator('#export-list div', { hasText: /^LegalRuleML/ }).click();
        }
        await expect(page.locator('#export-refused')).toBeVisible({ timeout: 60000 });
        await expect(page.locator('#export-result')).toHaveCount(0);
        await expect(page.locator('#export-refused')).toContainText('nothing was written');
        const line = page.locator('#export-problems .export-problem-line').first();
        await expect(line).toHaveText('line 10');
        await expect(page.locator('#export-problems li').first()).toContainText('the total is the sum of each amount such that');
        await line.click();
        await expect(page.locator('#export-refused')).toHaveCount(0);
        const at = await page.evaluate(() => (window as any).monaco.editor.getEditors()[0].getPosition().lineNumber);
        expect(at).toBe(10);
    });

    test('a translated policy exports back as a policy', async ({ page, request }) => {
        const formats = await (await request.post('/leapi', {
            data: { token: 'myToken123', operation: 'importFormats' } })).json();
        test.skip(!(formats.formats || []).some((f: any) => f.id === 'miniscript'),
                  'no Miniscript translator on this server (the InsurLE extensions are not installed)');
        await page.goto('index.html');
        await page.waitForSelector('.monaco-editor', { timeout: 30000 });
        await openFile(page, 'vault.policy', 'or(pk(A),and(pk(B),older(144)))\n');
        await expect.poll(() => editorText(page), { timeout: 60000 }).toContain('the coin can be spent');
        await page.locator('#import-report span').click();
        await page.evaluate(() => (document.getElementById('menu-export') as HTMLElement).click());
        // Other exporters (LegalRuleML) can write it too: pick Miniscript.
        await expect(page.locator('#export-list, #export-result').first()).toBeVisible({ timeout: 60000 });
        if (await page.locator('#export-list').count()) {
            await page.locator('#export-list div', { hasText: /^Bitcoin Miniscript policy/ }).click();
        }
        await expect(page.locator('#export-result')).toBeVisible({ timeout: 60000 });
        await expect(page.locator('#export-text')).toContainText('or(pk(key_a),and(pk(key_b),older(144)))');
        await expect(page.locator('#export-result .export-link')).toHaveText('Try it in Minsc');
    });
});
