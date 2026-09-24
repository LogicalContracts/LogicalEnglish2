// UI-language (chrome i18n) regression tests: the editor renders its menus
// and assistant greeting in the reader's menu language (Portuguese here),
// driven by the shared i18n/ui.csv catalog. The reader chooses it in the
// editor (Misc > Language); until then the browser's language is
// adopted, and remembered. The language of the program being edited never
// changes it, and neither do the landing pages. The Home link returns to the
// landing page of the program's language. /login honors the cookie the
// editor sets.
import { test, expect } from '@playwright/test';

test.describe('UI language', () => {
    test('Portuguese chrome and login', async ({ page }) => {
        await page.addInitScript(() => localStorage.setItem('le-ui-lang', 'pt'));
        await page.goto('/editor/index.html');
        await expect(page.locator('#menu-save-as')).toHaveText('Guardar como...');
        await expect(page.locator('#btn-query')).toHaveText('Consulta');
        // The Query panel's ANSWERS/EXPLANATION titles (uppercased by CSS) are
        // localized too.
        await expect(page.locator('#explanation-title')).toHaveText('Explicação');
        await expect(page.locator('#answers-panel > div').first()).toHaveText('Respostas');
        // The assistant greeting is localized too.
        await expect(page.locator('#assistant-history .chat-message').first())
            .toHaveText('Olá! Sou o seu Assistente de Logical English. Como posso ajudar hoje?');
        // An English program: Home returns to the standard landing page.
        await expect(page.locator('a.home-link')).toHaveAttribute('href', '/');

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

    test('English remains the default for an English browser', async ({ page }) => {
        await page.goto('/editor/index.html');
        await expect(page.locator('#menu-save-as')).toHaveText('Save As...');
        await expect(page.locator('a.home-link')).toHaveAttribute('href', '/');
        await page.goto('/login');
        await expect(page.locator('h1')).toHaveText('Login');
    });

    test('the menu language is chosen in the Misc menu, and kept', async ({ page }) => {
        await page.goto('/editor/index.html');
        // One item per language, named in its own language, English ticked.
        await expect(page.locator('#menu-ui-lang-en')).toContainText('English');
        await expect(page.locator('#menu-ui-lang-pt')).toContainText('Português');
        await expect(page.locator('#menu-ui-lang-es')).toContainText('Español');
        await expect(page.locator('#menu-ui-lang-en span')).toHaveCSS('visibility', 'visible');
        await expect(page.locator('#menu-ui-lang-es span')).toHaveCSS('visibility', 'hidden');
        // The languages are a second-level menu: hidden in the Misc menu until
        // the pointer rests on its Language item.
        await page.locator('.menu-item', { hasText: 'Misc' }).first().hover();
        await expect(page.locator('#menu-ui-language')).toBeVisible();
        await expect(page.locator('#menu-ui-lang-en')).toBeHidden();
        await page.locator('#menu-ui-language').hover();
        await expect(page.locator('#menu-ui-lang-en')).toBeVisible();
        // Choosing Español reloads the editor in Spanish, and remembers it.
        await page.evaluate(() => (document.getElementById('menu-ui-lang-es') as HTMLElement).click());
        await expect(page.locator('#btn-query')).toHaveText('Consulta');
        await expect(page.locator('#menu-ui-lang-es span')).toHaveCSS('visibility', 'visible');
        expect(await page.evaluate(() => localStorage.getItem('le-ui-lang'))).toBe('es');
        const cookies = await page.context().cookies();
        expect(cookies.find(c => c.name === 'le_ui_lang')?.value).toBe('es');
        // Back to English the same way.
        await page.evaluate(() => (document.getElementById('menu-ui-lang-en') as HTMLElement).click());
        await expect(page.locator('#menu-save-as')).toHaveText('Save As...');
    });
});

// A browser whose preferred language is Portuguese gets Portuguese menus the
// first time, and the choice is remembered.
test.describe('UI language on first use', () => {
    test.use({ locale: 'pt-BR' });
    test('adopts the browser language', async ({ page }) => {
        await page.goto('/editor/index.html');
        await expect(page.locator('#menu-save-as')).toHaveText('Guardar como...');
        expect(await page.evaluate(() => localStorage.getItem('le-ui-lang'))).toBe('pt');
        await expect(page.locator('#menu-ui-lang-pt span')).toHaveCSS('visibility', 'visible');
    });
});
