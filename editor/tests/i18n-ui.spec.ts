// UI-language (chrome i18n) regression tests: the editor renders its menus
// and assistant greeting in the selected UI language (Portuguese here),
// driven by the shared i18n/ui.csv catalog. The preference is set ONLY by
// the /multilingual pages (?lang=X sets X, their back link resets to
// English); there is no in-editor language selector, and the Home link
// returns to the landing page matching the active UI language. /login
// honors the cookie; the standard landing page always renders in English
// but leaves the preference alone.
import { test, expect } from '@playwright/test';

test.describe('UI language', () => {
    test('Portuguese chrome, Home link and login', async ({ page }) => {
        await page.addInitScript(() => localStorage.setItem('le-ui-lang', 'pt'));
        await page.goto('/editor/index.html');
        await expect(page.locator('#menu-save-as')).toHaveText('Guardar como...');
        await expect(page.locator('#btn-query')).toHaveText('Consulta');
        // The assistant greeting is localized too.
        await expect(page.locator('#assistant-history .chat-message').first())
            .toHaveText('Olá! Sou o seu Assistente de Logical English. Como posso ajudar hoje?');
        // No language selector in the Misc menu (the landing pages set the language).
        await expect(page.locator('#language-menu-items')).toHaveCount(0);
        // Home returns to the Portuguese landing page.
        await expect(page.locator('a.home-link')).toHaveAttribute('href', '/multilingual?lang=pt');

        // /login honors the preference cookie...
        await page.context().addCookies([{ name: 'le_ui_lang', value: 'pt', url: 'http://localhost:3000' }]);
        await page.goto('/login');
        await expect(page.locator('h1')).toHaveText('Iniciar sessão');

        // ...while the standard landing page IS the English page — but it does
        // not touch the preference cookie.
        await page.goto('/');
        await expect(page.locator('h2').first()).toHaveText('Documentation');
        const cookies = await page.context().cookies();
        expect(cookies.find(c => c.name === 'le_ui_lang')?.value).toBe('pt');
    });

    test('English remains the default', async ({ page }) => {
        await page.goto('/editor/index.html');
        await expect(page.locator('#menu-save-as')).toHaveText('Save As...');
        await expect(page.locator('a.home-link')).toHaveAttribute('href', '/');
        await page.goto('/login');
        await expect(page.locator('h1')).toHaveText('Login');
    });
});
