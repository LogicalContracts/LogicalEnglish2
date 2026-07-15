import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  // All tests hit ONE shared Prolog server (see webServer below). The heaviest
  // operations (payg / happy_dragon "for all cases" queries, explanation renders)
  // overwhelm it beyond ~2 concurrent requests, so a fully-parallel local run (one
  // worker per core) is flaky. Cap local workers at 2 for a reliable `run_tests.sh`;
  // CI runs serially (workers: 1) with retries.
  workers: process.env.CI ? 1 : 2,
  reporter: 'html',
  // All tests share one Prolog server, so under parallel load the heaviest
  // operations (e.g. the payg query + explanation render, scenario-variations
  // patch/assume flows) can take far longer than Playwright's default 5s
  // assertion timeout. Give web-first assertions generous headroom so these are
  // not flaky; an overall per-test cap still applies.
  expect: {
    timeout: 30000,
  },
  // Per-test cap: must exceed the assertion timeout above (otherwise one slow
  // assertion exhausts the whole test). Matches the test.setTimeout(60000) the
  // heaviest tests already use.
  timeout: 60000,
  use: {
    baseURL: 'http://localhost:3000/editor/',
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  webServer: {
    // ./myswipl.sh (run from the repo root via cwd below) picks the right
    // SWI-Prolog interpreter: $SWIPL override, then the macOS app bundle, then
    // `swipl` on PATH. See myswipl.sh.
    command: './myswipl.sh -l classic_web_api.pl -g "start_api_server(3000), thread_get_message(_)."',
    url: 'http://localhost:3000/editor/index.html',
    reuseExistingServer: !process.env.CI,
    cwd: '../'
  },
});
