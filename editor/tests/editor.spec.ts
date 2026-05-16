import { test, expect } from '@playwright/test';

test.describe('Logical English Editor', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('./index.html');
  });

  test('should load the editor', async ({ page }) => {
    await expect(page.locator('#container')).toBeVisible();
    await expect(page.locator('h1')).toContainText('LE Editor');
  });

  test('should switch themes', async ({ page }) => {
    // Open Misc menu
    await page.click('text=Misc');
    // Select Light theme
    await page.click('#theme-light');
    await expect(page.locator('body')).toHaveClass(/light-theme/);

    // Select High Contrast theme
    await page.click('text=Misc');
    await page.click('#theme-hc');
    await expect(page.locator('body')).toHaveClass(/hc-theme/);

    // Back to Dark
    await page.click('text=Misc');
    await page.click('#theme-dark');
    await expect(page.locator('body')).not.toHaveClass(/light-theme/);
    await expect(page.locator('body')).not.toHaveClass(/hc-theme/);
  });

  test('should navigate between bottom panels', async ({ page }) => {
    // Graph tab
    await page.click('text=Graph');
    await expect(page.locator('#graph-tab')).toBeVisible();
    await expect(page.locator('#query-tab')).not.toBeVisible();

    // Assistant tab
    await page.click('text=LE Assistant');
    await expect(page.locator('#assistant-tab')).toBeVisible();
    await expect(page.locator('#graph-tab')).not.toBeVisible();

    // Query tab
    await page.click('text=Query');
    await expect(page.locator('#query-tab')).toBeVisible();
    await expect(page.locator('#assistant-tab')).not.toBeVisible();
  });

  test('citizenship example integration test', async ({ page }) => {
    test.setTimeout(60000); // Increase timeout for this complex test

    // 1. Open "File" -> "Open copy from server..."
    await page.click('text=File');
    await page.click('#menu-open-server');

    // 2. Wait for the modal and click "citizenship"
    const exampleItem = page.locator('#example-list .dropdown-item', { hasText: /^citizenship$/ });
    await expect(exampleItem).toBeVisible();
    await exampleItem.click();

    // 3. Wait for the editor to load the content
    // We can check if the filename display updated
    await expect(page.locator('#filename-display')).toHaveText('citizenship.le');

    // 4. Wait for the module to load (it happens proactively)
    // We know it's loaded when scenario-select has more than 1 option
    await expect(async () => {
      const count = await page.locator('#scenario-select option').count();
      expect(count).toBeGreaterThan(1);
    }).toPass({ timeout: 10000 });

    // 5. Select first scenario (index 1)
    await page.selectOption('#scenario-select', { index: 1 });

    // 6. Select first query (index 1)
    await page.selectOption('#query-select', { index: 1 });

    // 7. Hit Query button
    await page.click('#btn-query');

    // 8. Verify presence of Answers
    const firstAnswer = page.locator('#answers-list .answer-item').first();
    await expect(firstAnswer).toBeVisible();

    // 9. Click answer (it's clicked by default, but let's be explicit)
    await firstAnswer.click();
    
    // 10. In the explanation click a node to select a rule in the editor
    // Wait for explanation tree to populate
    const treeLabel = page.locator('#explanation-tree .tree-label span:not(.tree-toggle)').first();
    await expect(treeLabel).toBeVisible();
    
    // Click the first label
    await treeLabel.click();
    
    // Wait a bit for Monaco to update
    await page.waitForTimeout(500);

    // Take screenshot of the selection in editor
    await page.screenshot({ path: '../docs/images/editor_selection.png' });

    // 11. Verify selection in Monaco
    const selectionInfo = await page.evaluate(() => {
      const editors = (window as any).monaco.editor.getEditors();
      return editors.map((ed: any, i: number) => {
        const sel = ed.getSelection();
        return {
          index: i,
          isEmpty: sel.isEmpty()
        };
      });
    });
    
    expect(selectionInfo.some((s: any) => !s.isEmpty)).toBe(true);

    // Go to Graph tab
    await page.click('text=Graph');
    await page.waitForTimeout(2000); // Wait for graph to render

    // Go to Assistant tab
    await page.click('text=LE Assistant');
  });
});
