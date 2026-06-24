import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    // Browser in the chromium container reaches the app container via docker network.
    // Set BASE_URL=http://localhost:3000 when running outside docker-compose (e.g. CI).
    baseURL: process.env.BASE_URL ?? 'http://app:3000',
    trace: 'on-first-retry',
    ...(process.env.PLAYWRIGHT_WS_ENDPOINT
      ? { connectOptions: { wsEndpoint: process.env.PLAYWRIGHT_WS_ENDPOINT } }
      : {}),
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  webServer: {
    command: 'cd .. && bin/rails server -b 0.0.0.0 -e test',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
