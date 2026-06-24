import { test, expect } from '@playwright/test';

test('unauthenticated root redirects to login', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveURL(/\/session\/new/);
});

test('login page renders', async ({ page }) => {
  await page.goto('/session/new');
  await expect(page.getByRole('button', { name: /sign in/i })).toBeVisible();
});
