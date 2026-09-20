/*  The same tests, against the deployment with no server in it.
 *
 *  `playwright.config.ts` starts a SWI-Prolog server and points the editor at
 *  it. This one starts nothing but a file server over `wasm/dist/`, where
 *  `wasm/build.sh` put the WebAssembly build — so every request the editor
 *  makes is answered by the Prolog compiled into the page, and a test that
 *  passes here is a feature that works with no server at all.
 *
 *      ./wasm/build.sh --skip-editor
 *      cd editor && npx playwright test -c playwright.wasm.config.ts
 *
 *  Not everything passes, and the ones that do not are not failures of the
 *  build: the Assistant runs a sub-process, the login page needs accounts, and
 *  a running query is interrupted from a second thread. wasm/test/README.md
 *  lists them, and `--grep-invert` in the default `grep` below leaves them out.
 */
import { defineConfig, devices } from '@playwright/test';

const PORT = Number(process.env.LE_WASM_PORT || 8088);

export default defineConfig({
    testDir: './tests',
    fullyParallel: true,
    forbidOnly: !!process.env.CI,
    retries: process.env.CI ? 2 : 0,
    //  One engine per page, and each one is a Prolog: two at a time is what a
    //  laptop takes gracefully, and the file server is not the limit.
    workers: process.env.CI ? 1 : 2,
    reporter: 'list',
    expect: { timeout: 45000 },
    //  Booting the engine is part of every test here (2–4 s cold), so the cap
    //  is above the server suite's.
    timeout: 120000,
    use: {
        baseURL: `http://localhost:${PORT}/editor/`,
        trace: 'on-first-retry'
    },
    projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
    webServer: {
        //  The build's own preview server, which applies the rewrites in the
        //  build's vercel.json — so /editor, /executive and /docs/<name> land
        //  where they land on the deployment, rather than 404ing here and
        //  nowhere else.
        command: `node wasm/runtime/serve.mjs wasm/dist ${PORT}`,
        url: `http://localhost:${PORT}/editor/index.html`,
        reuseExistingServer: true,
        cwd: '../'
    }
});
