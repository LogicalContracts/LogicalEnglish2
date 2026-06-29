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

  test('tolerates extra spaces in section headers when highlighting', async ({ page }) => {
    // Regression: a header with extra spaces (e.g. "the  templates are:") must
    // still be recognised, so the template definition lines below are
    // highlighted in the templates state (plain text) rather than the root
    // state (which would emphasise words like "there"/"are"). See AItest.le.
    await expect(page.locator('#container')).toBeVisible();
    // Wait until the 'le' Monarch language has been registered.
    await page.waitForFunction(() =>
      typeof (window as any).monaco !== 'undefined' &&
      (window as any).monaco.languages.getLanguages().some((l: any) => l.id === 'le')
    );

    const result = await page.evaluate(() => {
      const body =
        '\n*a message* implies *a set*.\n' +
        'there are enough references for every statement in *a set*.\n';
      const tokenize = (header: string) =>
        (window as any).monaco.editor
          .tokenize(header + body, 'le')
          .map((line: any[]) => line.map((t) => t.type));
      const doubleSpace = tokenize('the  templates are:');
      const singleSpace = tokenize('the templates are:');
      return { doubleSpace, singleSpace };
    });

    // The double-spaced header line is itself recognised as a section header.
    expect(result.doubleSpace[0].some((t: string) => t.includes('keyword.header'))).toBeTruthy();
    // And the template body lines are tokenized identically to the single-space
    // form — i.e. removing the extra space changes nothing below the header.
    expect(result.doubleSpace.slice(1)).toEqual(result.singleSpace.slice(1));
    // Sanity: no body token is emphasised as a template "word" (root state).
    const bodyTokens = result.doubleSpace.slice(1).flat();
    expect(bodyTokens.some((t: string) => t.includes('templateword'))).toBeFalsy();
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

    // 3. Wait for the editor to load the content (payg.le now lives under tax/)
    await expect(page.locator('#filename-display')).toHaveText('tax/payg.le');

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

  test('non-terminating query can be interrupted', async ({ page }) => {
    test.setTimeout(60000);

    // 1. Open the 'nonterminating' example from the server
    await page.click('text=File');
    await page.click('#menu-open-server');
    const exampleItem = page.locator('#example-list .dropdown-item', { hasText: /^nonterminating$/ });
    await expect(exampleItem).toBeVisible();
    await exampleItem.click();
    // nonterminating.le now lives under testing/
    await expect(page.locator('#filename-display')).toHaveText('testing/nonterminating.le');

    // 2. Wait for the module to load (scenario dropdown populated)
    await expect(async () => {
      const count = await page.locator('#scenario-select option').count();
      expect(count).toBeGreaterThan(1);
    }).toPass({ timeout: 10000 });

    // 3. Select the 'base' scenario and the non-terminating 'loop' query
    await page.selectOption('#scenario-select', 'base');
    await page.selectOption('#query-select', 'loop');

    // 4. Run the query (it never returns on its own)
    await page.click('#btn-query');

    // 5. The Interrupt button appears after ~2s of waiting
    const interruptBtn = page.locator('#btn-interrupt-query');
    await expect(interruptBtn).toBeVisible({ timeout: 8000 });

    // 6. Interrupt the query
    await interruptBtn.click();

    // 7. The query stops: the result reports the interruption and the button hides
    await expect(page.locator('#answers-list')).toContainText('Query interrupted', { timeout: 15000 });
    await expect(interruptBtn).toBeHidden();
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

  test('answer with unknown goals shows them in a tooltip', async ({ page }) => {
    test.setTimeout(60000);

    // 1. Open the "unknowns" example from the server
    await page.click('text=File');
    await page.click('#menu-open-server');
    const exampleItem = page.locator('#example-list .dropdown-item', { hasText: /^unknowns$/ });
    await expect(exampleItem).toBeVisible();
    await exampleItem.click();
    await expect(page.locator('#filename-display')).toHaveText('unknowns.le');

    // 2. Wait for the module to load (scenario dropdown populated)
    await expect(async () => {
      const count = await page.locator('#scenario-select option').count();
      expect(count).toBeGreaterThan(1);
    }).toPass({ timeout: 10000 });

    // 3. Select scenario "one" and query "one"
    await page.selectOption('#scenario-select', 'one');
    await page.selectOption('#query-select', 'one');

    // 4. Run the query
    await page.click('#btn-query');

    // 5. The answer with an unknown goal ("alice becomes rich") is marked
    const aliceAnswer = page.locator('#answers-list .answer-item', { hasText: /alice becomes rich/ });
    await expect(aliceAnswer).toBeVisible();
    await expect(aliceAnswer).toHaveClass(/has-unknowns/);

    // 6. The answer without unknowns ("bob becomes rich") is not marked
    const bobAnswer = page.locator('#answers-list .answer-item', { hasText: /bob becomes rich/ });
    await expect(bobAnswer).toBeVisible();
    await expect(bobAnswer).not.toHaveClass(/has-unknowns/);

    // 7. Hovering the marked answer reveals a tooltip with the unknown goal
    const tooltip = page.locator('#answer-tooltip');
    await expect(tooltip).toBeHidden();
    await aliceAnswer.hover();
    await expect(tooltip).toBeVisible();
    await expect(tooltip).toContainText('alice knows that 42 will win the lottery');

    // 8. Moving the mouse away hides the tooltip
    await bobAnswer.hover();
    await expect(tooltip).toBeHidden();
  });
});
