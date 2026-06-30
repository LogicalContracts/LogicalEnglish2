import { test, expect } from '@playwright/test';

// Capture the sessionModule of a getGameData POST (works for both the editor page
// and the game popup).
function grabGameSession(r: any, set: (s: string) => void) {
    if (r.url().includes('/leapi') && r.method() === 'POST') {
        try {
            const d = JSON.parse(r.postData() || '{}');
            if (d.operation === 'getGameData' && d.sessionModule) set(d.sessionModule);
        } catch { /* ignore */ }
    }
}

test.describe('Proof Game', () => {
    test('uses its own session, distinct from the editor', async ({ page }) => {
        test.setTimeout(60000);
        await page.goto('index.html');
        await page.click('text=File');
        await page.click('#menu-open-server');
        await page.locator('#example-list .dropdown-item', { hasText: /^citizenship$/ }).click();
        await expect(page.locator('#filename-display')).toHaveText('citizenship.le');
        await expect(async () => {
            expect(await page.locator('#scenario-select option').count()).toBeGreaterThan(1);
        }).toPass({ timeout: 10000 });
        await page.selectOption('#scenario-select', 'alice');
        await page.selectOption('#query-select', 'one');

        // The editor fetches game data on its own session when the button is clicked.
        let editorSession = '';
        page.on('request', (r) => grabGameSession(r, (s) => (editorSession = s)));

        const [popup] = await Promise.all([
            page.waitForEvent('popup'),
            page.click('#btn-proof-game'),
        ]);
        // The game window then loads its OWN session and re-asserts the terms on it.
        let gameSession = '';
        popup.on('request', (r) => grabGameSession(r, (s) => (gameSession = s)));
        await popup.waitForLoadState();

        await expect.poll(() => gameSession, { timeout: 30000 }).not.toBe('');
        expect(editorSession).toBeTruthy();
        expect(gameSession).not.toBe(editorSession);
    });
});
