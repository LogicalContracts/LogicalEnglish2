import { test, expect } from '@playwright/test';

// A node proved by a rule or a fact with provenance carries a § badge; it
// opens the cited document's text (the program says where it is: "the text of
// <document> is at <address>") with the quoted passage highlighted.
test.describe('Source viewer', () => {
    test('the § badge of a cited rule shows its source passage', async ({ page }) => {
        test.setTimeout(120000);
        await page.goto('index.html?example=RulesRus/customs/apparel_cbp&scenario=ny_n362700&query=subheading');
        await expect(page.locator('#query-select')).toHaveValue('subheading', { timeout: 60000 });
        await page.click('#btn-query');
        await expect(page.locator('#answers-list .answer-item').first()).toBeVisible({ timeout: 60000 });

        // The root: rule gri_6, citing the General Rules of Interpretation.
        const badge = page.locator('#explanation-tree .tree-label .tree-prov').first();
        await expect(badge).toHaveAttribute('title', /gri_6/);
        await badge.click();
        const viewer = page.locator('#source-viewer');
        await expect(viewer).toBeVisible();
        await expect(viewer.locator('h2')).toHaveText('HTSUS General Rules of Interpretation');
        await expect(viewer.locator('mark')).toContainText('the classification of goods in the subheadings of a heading', { timeout: 30000 });
        await viewer.locator('button.primary').click();
        await expect(viewer).toHaveCount(0);
    });

    // In the program itself: the context menu of a line that cites a document
    // offers "Show original text" — the same viewer, the fact's passage
    // highlighted — and, once the program is loaded, the menu of a line that
    // cites nothing does not.
    test('Show original text in the context menu of a cited fact', async ({ page }) => {
        test.setTimeout(120000);
        await page.goto('index.html?example=RulesRus/customs/apparel_cbp');
        await page.waitForSelector('.monaco-editor', { timeout: 30000 });

        const rightClickLine = async (text: string) => {
            const point = await page.evaluate((needle) => {
                const ed = (window as any).monaco.editor.getEditors()[0];
                const model = ed.getModel();
                const match = model.findMatches(needle, false, false, true, null, false)[0];
                const line = match.range.startLineNumber;
                ed.revealLineInCenter(line);
                const pos = ed.getScrolledVisiblePosition({ lineNumber: line, column: match.range.startColumn + 2 });
                const box = ed.getDomNode().getBoundingClientRect();
                return { x: box.left + pos.left, y: box.top + pos.top + pos.height / 2 };
            }, text);
            await page.mouse.click(point.x, point.y, { button: 'right' });
        };
        const item = page.getByRole('menuitem', { name: 'Show original text' });

        // Not loaded yet (no scenario or query in the address): where the
        // program cites is not known, so the entry is offered; opening the
        // menu loads the program, whose citations become decorations.
        await rightClickLine('the target language is: prolog.');
        await expect(item).toBeVisible();
        await page.keyboard.press('Escape');
        await expect.poll(() => page.evaluate(() => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            return ed.getModel().getAllDecorations().filter((d: any) => d.options.description === 'le-citation').length;
        }), { timeout: 60000 }).toBeGreaterThan(50);

        await rightClickLine('the target language is: prolog.');
        await expect(page.getByRole('menuitem', { name: 'Show occurrences' })).toBeVisible();
        await expect(item).toHaveCount(0);
        await page.keyboard.press('Escape');

        await rightClickLine('style 1025AD has a collar');
        await expect(item).toBeVisible();
        // Choose it the way the other specs run editor actions: a click on a
        // Monaco menu entry is timing-dependent in headless runs.
        await page.keyboard.press('Escape');
        await page.evaluate(async () => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            await ed.getAction('le-show-original-text').run(ed);
        });
        const viewer = page.locator('#source-viewer');
        await expect(viewer).toBeVisible();
        await expect(viewer.locator('h2')).toHaveText('ruling NY N362700');
        await expect(viewer.locator('mark')).toContainText('zips through a self-fabric stand-up collar', { timeout: 30000 });
        await viewer.locator('button.primary').click();
        await expect(viewer).toHaveCount(0);
    });

    // The viewer takes its colours from the page's theme: in the light theme
    // its text must not be dark on the dark theme's field.
    test('the source viewer is legible in the light theme', async ({ page }) => {
        test.setTimeout(120000);
        await page.addInitScript(() => localStorage.setItem('le-editor-theme', 'le-theme-light'));
        await page.goto('index.html?example=RulesRus/customs/apparel_cbp&scenario=ny_n362700');
        await expect(page.locator('#scenario-select')).toHaveValue('ny_n362700', { timeout: 60000 });
        await page.evaluate(async () => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            const match = ed.getModel().findMatches('style 1025AD has a collar', false, false, true, null, false)[0];
            ed.setPosition({ lineNumber: match.range.startLineNumber, column: 6 });
            await ed.getAction('le-show-original-text').run(ed);
        });
        const viewer = page.locator('#source-viewer');
        await expect(viewer.locator('mark')).toBeVisible({ timeout: 30000 });
        await page.screenshot({ path: 'test-results/source-viewer-light.png' });

        // WCAG contrast ratio of an element's text against its background
        const contrast = (selector: string) => page.evaluate((sel) => {
            const el = document.querySelector(sel) as HTMLElement;
            const rgb = (c: string) => (c.match(/[\d.]+/g) || []).slice(0, 3).map(Number);
            const lum = ([r, g, b]: number[]) => {
                const f = (v: number) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
                return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
            };
            const style = getComputedStyle(el);
            const [a, b] = [lum(rgb(style.color)), lum(rgb(style.backgroundColor))].sort((x, y) => y - x);
            return (a + 0.05) / (b + 0.05);
        }, selector);
        expect(await contrast('#source-viewer .sv-text')).toBeGreaterThan(7);
        expect(await contrast('#source-viewer')).toBeGreaterThan(7);
    });
});
