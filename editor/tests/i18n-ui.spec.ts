// UI-language (chrome i18n) regression tests: the editor renders its menus,
// the landing page and /login in the selected UI language (Portuguese here),
// driven by the shared i18n/ui.csv catalog. The language selector lists every
// language registered in i18n/languages.csv.
import { test, expect } from '@playwright/test';

test.describe('UI language', () => {
    test('Portuguese chrome, landing page and login', async ({ page }) => {
        await page.addInitScript(() => localStorage.setItem('le-ui-lang', 'pt'));
        await page.goto('/editor/index.html');
        await expect(page.locator('#menu-save-as')).toHaveText('Guardar como...');
        await expect(page.locator('#btn-query')).toHaveText('Consulta');
        await expect(page.locator('#language-menu-items .dropdown-item').first()).toBeAttached();

        await page.context().addCookies([{ name: 'le_ui_lang', value: 'pt', url: 'http://localhost:3000' }]);
        await page.goto('/');
        await expect(page.locator('h2').first()).toHaveText('Documentação');
        await page.goto('/login');
        await expect(page.locator('h1')).toHaveText('Iniciar sessão');
    });

    test('English remains the default', async ({ page }) => {
        await page.goto('/editor/index.html');
        await expect(page.locator('#menu-save-as')).toHaveText('Save As...');
        await page.goto('/login');
        await expect(page.locator('h1')).toHaveText('Login');
    });
});
