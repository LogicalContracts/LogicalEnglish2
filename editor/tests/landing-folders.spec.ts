// The landing pages' example folders: each has a link symbol after its name
// that copies the web address of the folder (the page with ?dir=<folder>);
// the click copies without opening or closing the folder, and opening the
// address shows that folder: the standard page's server narrows the list to
// it, and on every landing page the folder and those around it open.
import { test, expect } from '@playwright/test';

test.describe('landing page folder links', () => {
    test('every folder has a link that copies its address', async ({ page, context }) => {
        await context.grantPermissions(['clipboard-read', 'clipboard-write']);
        await page.goto('/');
        const folders = page.locator('details.le-folder[data-path]');
        const links = page.locator('details.le-folder > summary > a.folder-link');
        expect(await folders.count()).toBeGreaterThan(0);
        expect(await links.count()).toBe(await folders.count());
        const first = folders.first();
        const wasOpen = await first.evaluate((d: HTMLDetailsElement) => d.open);
        const path = (await first.getAttribute('data-path'))!.replace(/\/+$/, '');
        await links.first().click();
        await expect(links.first()).toHaveText('Copied');
        const copied = await page.evaluate(() => navigator.clipboard.readText());
        expect(new URL(copied).pathname).toBe('/');
        expect(new URL(copied).searchParams.get('dir')).toBe(path);
        expect(await first.evaluate((d: HTMLDetailsElement) => d.open)).toBe(wasOpen);
        await expect(links.first()).toHaveAttribute('href', copied);
    });

    test('a folder address narrows the standard page to the folder', async ({ page }) => {
        await page.goto('/?dir=regulatory');
        await expect(page.locator('body')).toContainText('showing');
        await expect(page.locator('body')).not.toContainText('not found');
        const hrefs = await page.locator('ul ul a[href^="/editor/index.html?example="]')
            .evaluateAll(as => as.map(a => a.getAttribute('href')));
        expect(hrefs.length).toBeGreaterThan(0);
        for (const h of hrefs) expect(h).toContain('example=regulatory/');
    });

    test('a folder address on a language page opens that folder', async ({ page }) => {
        await page.goto('/multilingual?lang=pt');
        const nested = page.locator('details.le-folder details.le-folder[data-path]').first();
        const any = page.locator('details.le-folder[data-path]').first();
        // examples/pt/ may have no subfolders yet: nothing to open then
        test.skip(await any.count() === 0, 'the Portuguese examples have no folders');
        const target = (await nested.count()) ? nested : any;
        const path = (await target.getAttribute('data-path'))!;
        await page.evaluate(() => localStorage.clear());
        await page.goto(`/multilingual?lang=pt&dir=${encodeURIComponent(path.replace(/\/+$/, ''))}`);
        const opened = await page.evaluate((p) => {
            const d = Array.from(document.querySelectorAll('details.le-folder'))
                .find(x => x.getAttribute('data-path') === p);
            let all = !!d;
            for (let x: Element | null = d || null; x; x = x.parentElement ? x.parentElement.closest('details') : null) {
                all = all && (x as HTMLDetailsElement).open;
            }
            return all;
        }, path);
        expect(opened).toBe(true);
        // The address copied there keeps the page's language.
        const href = await page.locator(`details.le-folder[data-path="${path}"] > summary > a.folder-link`).getAttribute('href');
        expect(new URL(href!).searchParams.get('lang')).toBe('pt');
    });
});
