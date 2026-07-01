import { test, expect } from '@playwright/test';

// Open File -> "Open copy from server…" and pick the example matching `name`. The menu
// handlers are wired late during app init, so an early click can be dropped; retry the
// File -> menu-open-server sequence until the example list actually appears, then click.
async function openFromServer(page: any, name: RegExp) {
  const item = page.locator('#example-list .dropdown-item', { hasText: name });
  await expect(async () => {
    await page.click('text=File');
    await page.click('#menu-open-server');
    await expect(item).toBeVisible({ timeout: 1000 });
  }).toPass();
  await item.click();
}

// A program whose "alice is happy" answer has an internal "for all cases …" node as
// its strongest reason (used to test the one-level expansion).
const HAPPY_DRAGON = `the target language is: prolog.
the templates are:
*a creature* is a parent of *a dragon*.
*a creature* is healthy.
*a creature* is happy.
*a creature* is a dragon.
the knowledge base d includes:
A creature is happy
    if the creature is a dragon
    and for all cases in which
	    the creature is a parent of an other creature
		it is the case that
		the other creature is healthy.
scenario mary is:
	bob is a dragon.
	alice is a dragon.
	alice is a parent of bob.
	alice is a parent of mary.
	mary is a dragon.
	mary is healthy.
	bob is healthy.
query happy is:
	which dragon is happy.`;

test.describe('Logical English Editor', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('./index.html');
  });

  test('should load the editor', async ({ page }) => {
    await expect(page.locator('#container')).toBeVisible();
    await expect(page.locator('h1')).toContainText('LE Editor');
  });

  test('should switch themes', async ({ page }) => {
    const body = page.locator('body');
    // The Misc menu's handlers are wired during app init, so an early click can be
    // dropped. Retry Misc -> theme item until the theme actually applies (the dark theme
    // adds no class of its own — it just clears the others).
    const pickTheme = async (itemId: string, assertApplied: () => Promise<void>) => {
      await expect(async () => {
        await page.click('text=Misc');
        await page.click(itemId);
        await assertApplied();
      }).toPass();
    };

    await pickTheme('#theme-light', () => expect(body).toHaveClass(/light-theme/, { timeout: 1000 }));
    await pickTheme('#theme-hc', () => expect(body).toHaveClass(/hc-theme/, { timeout: 1000 }));
    await pickTheme('#theme-dark', async () => {
      await expect(body).not.toHaveClass(/light-theme/, { timeout: 1000 });
      await expect(body).not.toHaveClass(/hc-theme/, { timeout: 1000 });
    });
  });

  test('should navigate between bottom panels', async ({ page }) => {
    await expect(page.locator('#container')).toBeVisible();

    // The tab click handlers are wired late during app init (after the Monaco editor is
    // created), so an early click can be dropped. Retry the click until the tab switches.
    const switchTo = async (label: string, tabId: string, hiddenId: string) => {
      const btn = page.locator('.tab', { hasText: label });
      await expect(btn).toBeVisible();
      await expect(async () => {
        await btn.click();
        await expect(page.locator(tabId)).toBeVisible({ timeout: 1000 });
      }).toPass();
      await expect(page.locator(hiddenId)).not.toBeVisible();
    };
    await switchTo('Graph', '#graph-tab', '#query-tab');
    await switchTo('LE Assistant', '#assistant-tab', '#graph-tab');
    await switchTo('Query', '#query-tab', '#assistant-tab');
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

    // 1. Open "File" -> "Open copy from server..." and pick "citizenship"
    await openFromServer(page, /^citizenship$/);

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

    // 7. Hit Query button (capture the answer's strongest-reason path from the response)
    let strongestPath = '';
    page.on('response', async (r) => {
      if (!r.url().includes('/leapi')) return;
      try {
        const b = await r.json();
        const p = b?.results?.[0]?.strongestReasonPath;
        if (p) strongestPath = p;
      } catch { /* not JSON */ }
    });
    await page.click('#btn-query');

    // 8. Verify presence of Answers
    const firstAnswer = page.locator('#answers-list .answer-item').first();
    await expect(firstAnswer).toBeVisible();

    // 9. Click answer (it's clicked by default, but let's be explicit)
    await firstAnswer.click();

    // The EXPLANATION title carries the selected answer's "important reason" as a
    // hover tooltip (computed on the Prolog side).
    const explTitle = page.locator('#explanation-title');
    await expect(explTitle).toHaveClass(/has-reason/);
    await expect(explTitle).toHaveAttribute('title', /^Important reason: .+/);

    // Its context menu "Show important reason" expands the tree to that node (the path
    // returned by the server) and flashes it.
    await expect.poll(() => strongestPath).not.toBe('');
    await explTitle.click({ button: 'right' });
    await page.click('#menu-show-strongest');
    const strongestNode = page.locator(`#explanation-tree .tree-node[data-path="${strongestPath}"] > .tree-label`);
    await expect(strongestNode).toHaveClass(/explanation-highlight/);

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

  test('Show strongest reason expands the node one level', async ({ page }) => {
    test.setTimeout(60000);
    let alicePath = '';
    page.on('response', async (r) => {
      if (!r.url().includes('/leapi')) return;
      try {
        const b = await r.json();
        const a = (b?.results || []).find((x: any) => x.answer === 'alice is happy');
        if (a?.strongestReasonPath) alicePath = a.strongestReasonPath;
      } catch { /* not JSON */ }
    });

    await page.goto('index.html?text=' + encodeURIComponent(HAPPY_DRAGON));
    await page.waitForTimeout(800);
    await page.locator('#scenario-select').hover();   // triggers the module load
    await expect.poll(() => page.locator('#scenario-select option').count(), { timeout: 20000 }).toBeGreaterThan(1);
    await page.selectOption('#scenario-select', 'mary');
    await page.selectOption('#query-select', 'happy');
    await page.click('#btn-query');

    // The "alice is happy" answer's strongest reason is a "for all cases …" node.
    await page.locator('#answers-list .answer-item', { hasText: 'alice is happy' }).click();
    await expect.poll(() => alicePath).not.toBe('');

    const node = page.locator(`#explanation-tree .tree-node[data-path="${alicePath}"]`);
    const children = node.locator(':scope > .tree-children');
    await expect(children).toBeVisible();   // it is a non-leaf node

    // Collapse it, then jump back via the menu: it must re-expand one level and flash.
    await node.locator(':scope > .tree-label > .tree-toggle').click();
    await expect(children).toBeHidden();
    await page.locator('#explanation-title').click({ button: 'right' });
    await page.click('#menu-show-strongest');
    await expect(children).toBeVisible();
    await expect(node.locator(':scope > .tree-label')).toHaveClass(/explanation-highlight/);
  });

  test('payg example integration test', async ({ page }) => {
    test.setTimeout(60000); // Increase timeout for this complex test

    // 1. Open "File" -> "Open copy from server..." and pick "payg"
    await openFromServer(page, /^payg$/);

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
    await openFromServer(page, /^nonterminating$/);
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
    const modal = page.locator('#explanations-modal');
    const prefixInput = page.locator('#failed-prefix-input');

    // The Misc menu's handlers are wired during app init, so an early click can be
    // dropped. Retry Misc -> Preferences… until the modal actually opens.
    const openPreferences = async () => {
      await expect(async () => {
        await page.click('text=Misc');
        await page.click('#menu-explanations');
        await expect(modal).toBeVisible({ timeout: 1000 });
      }).toPass();
    };

    // Default prefix is "x "; change it to "[FAIL] " and save.
    await openPreferences();
    await expect(prefixInput).toHaveValue('x ');
    await prefixInput.fill('[FAIL] ');
    await page.click('#explanations-save');
    await expect(modal).not.toBeVisible();

    // Reopen: the custom prefix persisted. Cancel out.
    await openPreferences();
    await expect(prefixInput).toHaveValue('[FAIL] ');
    await page.click('#explanations-cancel');
    await expect(modal).not.toBeVisible();
  });

  test('answer with unknown goals shows them in a tooltip', async ({ page }) => {
    test.setTimeout(60000);

    // 1. Open the "unknowns" example from the server
    await openFromServer(page, /^unknowns$/);
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
