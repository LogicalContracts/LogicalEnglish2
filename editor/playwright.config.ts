import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
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
    command: '/Applications/SWI-Prolog10.0.0-1.app/Contents/MacOS/swipl -l classic_web_api.pl -g "start_api_server(3000), thread_get_message(_)."',
    url: 'http://localhost:3000/editor/index.html',
    reuseExistingServer: !process.env.CI,
    cwd: '../'
  },
});
