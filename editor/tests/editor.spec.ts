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
    await expect(page.locator('#container')).toBeVisible();
    
    // Graph tab
    const graphTabButton = page.locator('.tab', { hasText: 'Graph' });
    await expect(graphTabButton).toBeVisible();
    await graphTabButton.click();
    await expect(page.locator('#graph-tab')).toBeVisible();
    await expect(page.locator('#query-tab')).not.toBeVisible();

    // Assistant tab
    const assistantTabButton = page.locator('.tab', { hasText: 'LE Assistant' });
    await expect(assistantTabButton).toBeVisible();
    await assistantTabButton.click();
    await expect(page.locator('#assistant-tab')).toBeVisible();
    await expect(page.locator('#graph-tab')).not.toBeVisible();

    // Query tab
    const queryTabButton = page.locator('.tab', { hasText: 'Query' });
    await expect(queryTabButton).toBeVisible();
    await queryTabButton.click();
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

  test('payg example integration test', async ({ page }) => {
    test.setTimeout(60000); // Increase timeout for this complex test

    // 1. Open "File" -> "Open copy from server..."
    await page.click('text=File');
    await page.click('#menu-open-server');

    // 2. Wait for the modal and click "payg"
    const exampleItem = page.locator('#example-list .dropdown-item', { hasText: /^payg$/ });
    await expect(exampleItem).toBeVisible();
    await exampleItem.click();

    // 3. Wait for the editor to load the content
    await expect(page.locator('#filename-display')).toHaveText('payg.le');

    // 4. Wait for the module to load proactively
    await expect(async () => {
      const count = await page.locator('#scenario-select option').count();
      expect(count).toBeGreaterThan(1);
    }).toPass({ timeout: 10000 });

    // 5. Select scenario "ato_4_quarter_2"
    await page.selectOption('#scenario-select', 'ato_4_quarter_2');

    // 6. Select query "payg_income"
    await page.selectOption('#query-select', 'payg_income');

    // 7. Hit Query button
    await page.click('#btn-query');

    // 8. Verify presence of exactly one Answer
    const answers = page.locator('#answers-list .answer-item');
    await expect(answers).toHaveCount(1);

    // 9. Click answer
    await answers.first().click();
    
    // 10. Verify that the explanation tree is populated
    const treeLabel = page.locator('#explanation-tree .tree-label span:not(.tree-toggle)').first();
    await expect(treeLabel).toBeVisible();
  });

  test('should configure explanations preferences', async ({ page }) => {
    // 1. Open Misc menu
    await page.click('text=Misc');

    // 2. Click Preferences... under EXPLANATIONS
    await page.click('#menu-explanations');

    // 3. Verify modal is visible
    const modal = page.locator('#explanations-modal');
    await expect(modal).toBeVisible();

    // 4. Verify default prefix is "x "
    const prefixInput = page.locator('#failed-prefix-input');
    await expect(prefixInput).toHaveValue('x ');

    // 5. Change prefix to "[FAIL] "
    await prefixInput.fill('[FAIL] ');

    // 6. Click Save
    await page.click('#explanations-save');

    // 7. Verify modal is closed
    await expect(modal).not.toBeVisible();

    // 8. Open Misc menu again and click Preferences...
    await page.click('text=Misc');
    await page.click('#menu-explanations');

    // 9. Verify custom prefix is loaded
    await expect(prefixInput).toHaveValue('[FAIL] ');

    // 10. Click Cancel
    await page.click('#explanations-cancel');
    await expect(modal).not.toBeVisible();
  });
});
