import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

// The line of gri.le whose rule proves the root: the head of the GRI 6 rule
// (the subheading within the heading the good is classified in).
function subheadingRuleLine(): number {
    const text = fs.readFileSync(path.join(__dirname, '../../examples/moreExamples/insureLE2/customs/gri.le'), 'utf8');
    return text.split('\n').findIndex(l => l.startsWith('the subheading of a good is a code')) + 1;
}

const editorState = () => {
    const ed = (window as any).monaco.editor.getEditors()[0];
    return { line: ed.getSelection().startLineNumber, text: ed.getModel().getValue() as string };
};

// An explanation node proved by a rule of an INCLUDED resource must open that
// resource at the rule — not select whatever sits at the same offsets in the
// document on screen (apparel_cbp.le includes tariff.le, which includes the
// chapters and gri.le; the root of the explanation is proved by the GRI 6
// rule of gri.le). The
// resource opens in an editor tab of its own; the explanation stays.
test.describe('Navigation into included resources', () => {
    test('clicking a node proved in an included file opens that file at the rule, in a tab', async ({ page }) => {
        test.setTimeout(120000);
        await page.goto('index.html?example=insureLE2/customs/apparel_cbp&scenario=ny_n362700&query=subheading');
        // Wait until the URL's selections applied (the module load can be slow).
        await expect(page.locator('#query-select')).toHaveValue('subheading', { timeout: 60000 });
        await page.click('#btn-query');
        await expect(page.locator('#answers-list .answer-item').first()).toBeVisible({ timeout: 60000 });

        const root = page.locator('#explanation-tree .tree-label .tree-text').first();
        await expect(root).toContainText('the subheading of style');
        const line = subheadingRuleLine();
        expect(line).toBeGreaterThan(0);
        await expect(root).toHaveAttribute('title', new RegExp(`gri\\.le, line ${line}`));

        await root.click();

        // A second tab, in front, with gri.le at the rule.
        const tabs = page.locator('#editor-tabs .le-tab');
        await expect(tabs).toHaveCount(2);
        await expect(tabs.nth(1)).toHaveClass(/active/);
        await expect(tabs.nth(1).locator('.le-tab-title')).toHaveText('gri.le');
        await expect.poll(() => page.evaluate(editorState).then(s => s.line)).toBe(line);
        expect((await page.evaluate(editorState)).text).toContain('the subheading of a good is a code');

        // The panels stay on the program being explained, marked on its tab.
        await expect(tabs.nth(0)).toHaveClass(/program/);
        await expect(root).toContainText('the subheading of style');
        await expect(page.locator('#query-select')).toHaveValue('subheading');
        expect(new URL(page.url()).searchParams.get('example')).toBe('insureLE2/customs/apparel_cbp');

        // A range of the program itself (a click on one of its own nodes, in
        // the graph, the proof game...) brings its tab back.
        await page.evaluate(() => (window as any).selectRange(0, 10));
        await expect(tabs.nth(0)).toHaveClass(/active/);
        expect((await page.evaluate(editorState)).text).toContain('scenario ny_n362700 is');

        // Going back to the resource's tab by hand makes it the program: the
        // panels now belong to gri.le (not loaded yet → fresh pickers).
        await tabs.nth(1).click();
        await expect(tabs.nth(1)).toHaveClass(/active/);
        await expect(page.locator('#answers-list .answer-item')).toHaveCount(0);
        expect(new URL(page.url()).searchParams.get('example')).toBe('insureLE2/customs/gri');
        // ... and back: apparel_cbp's answers and explanation are as they were.
        await tabs.nth(0).click();
        await expect(page.locator('#answers-list .answer-item').first()).toBeVisible();
        await expect(root).toContainText('the subheading of style');
        await expect(page.locator('#query-select')).toHaveValue('subheading');
        await expect(page.locator('#scenario-select')).toHaveValue('ny_n362700');
    });
});

// Show definition on the NAME of an included resource opens the resource: an
// example in an editor tab of its own, a Prolog resource in the source viewer.
test.describe('Show definition on an included resource', () => {
    const showDefinitionOn = async (page: any, lineText: string, word: string) => {
        await page.evaluate(({ lineText, word }) => {
            const ed = (window as any).monaco.editor.getEditors()[0];
            const lines: string[] = ed.getModel().getLinesContent();
            const n = lines.findIndex(l => l.trim() === lineText);
            ed.setPosition({ lineNumber: n + 1, column: lines[n].indexOf(word) + 2 });
            ed.getAction('le-show-definition').run();
        }, { lineText, word });
    };

    test('a Logical English resource opens in a tab', async ({ page }) => {
        await page.goto('index.html?example=language/includes/prolog_resources/postcodes');
        await page.waitForFunction(() => (window as any).monaco?.editor.getEditors().length > 0, null, { timeout: 60000 });
        await expect.poll(() => page.evaluate(() =>
            (window as any).monaco.editor.getEditors()[0].getModel().getValue()), { timeout: 30000 }).toContain('postcodes_layer.');
        await showDefinitionOn(page, 'postcodes_layer.', 'postcodes_layer');
        await expect.poll(() => page.evaluate(() =>
            (window as any).monaco.editor.getEditors()[0].getModel().getValue()), { timeout: 30000 }).toContain('the knowledge base postcodes_layer includes these resources');
    });

    test('a Prolog resource opens in the source viewer', async ({ page }) => {
        await page.goto('index.html?example=language/includes/prolog_resources/postcodes_layer');
        await page.waitForFunction(() => (window as any).monaco?.editor.getEditors().length > 0, null, { timeout: 60000 });
        await expect.poll(() => page.evaluate(() =>
            (window as any).monaco.editor.getEditors()[0].getModel().getValue()), { timeout: 30000 }).toContain('postcodes_facts.pl.');
        await showDefinitionOn(page, 'postcodes_facts.pl.', 'postcodes_facts');
        await expect(page.getByText('A Prolog *resource* included by a Logical English program').first()).toBeVisible({ timeout: 30000 });
    });
});
