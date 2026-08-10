# Playwright Configuration, Plan Template, and Debugging

Reference material for the `frontend-testing` skill: the full Playwright
configuration sample, the e2e plan template, and the debugging guide.

## Configuration

```typescript
import { defineConfig, devices } from "@playwright/test";

const BASE_URL = process.env.E2E_BASE_URL ?? "<dev-url>";

export default defineConfig({
  // Playwright resolves testDir relative to this config file. This config sits at
  // the repository root, so the repo-relative <e2e-dir> works as written; a config
  // living elsewhere must adjust the path accordingly.
  testDir: "<e2e-dir>",
  testMatch: "**/*.spec.ts",
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? "github" : "list",

  use: {
    baseURL: BASE_URL,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },

  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
    { name: "firefox", use: { ...devices["Desktop Firefox"] } },
    { name: "webkit", use: { ...devices["Desktop Safari"] } },
    { name: "mobile-chrome", use: { ...devices["Pixel 5"] } },
    { name: "mobile-safari", use: { ...devices["iPhone 12"] } },
  ],

  webServer: {
    command: "<pkg-manager> run dev",
    url: BASE_URL,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
```

Scripts:

```json
{
  "scripts": {
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui",
    "test:e2e:debug": "playwright test --debug",
    "test:e2e:headed": "playwright test --headed"
  }
}
```

## Test plan template

```markdown
# End-to-End Test Plan

## Scope

- Application: <dev-url>
- Accounts: generated per test
- Data: seeded through the public API before each spec

## Flows

### Authentication
- [ ] Sign in with valid credentials → dashboard
- [ ] Invalid email format → error
- [ ] Empty password → error
- [ ] Unauthenticated visit to a protected route → redirect
- [ ] Sign out → home, session cleared

### Profile
- [ ] Update each field → success, persisted
- [ ] Required field empty → error
- [ ] Server rejection → error shown, form recoverable
- [ ] Saving state → button disabled, progress announced
- [ ] Keyboard: full form reachable
- [ ] Mobile: usable at 375px

## Acceptance

- Passes on Chromium, Firefox, WebKit
- Passes on a 375px viewport
- Automated accessibility scan clean
- No console errors during the run
- No flakes across three consecutive runs
```

## Debugging

**Element not found** — use a locator rather than an immediate action. Locators carry
built-in waiting; `page.click` on a raw selector does not.

```typescript
// Fragile
await page.click("button[type=submit]");

// Correct
await page.getByRole("button", { name: "Save" }).click();
```

**Flaky test** — you are waiting on time instead of state.

```typescript
// Wrong
await page.waitForTimeout(1000);
await page.getByRole("button", { name: "Save" }).click();

// Right
await page.getByRole("button", { name: "Save" }).click();
await expect(page.getByRole("status")).toContainText("Saved");
```

**Strict mode violation** — the locator matched several elements. Narrow it with a
name or a role rather than reaching for `.first()`, which hides the ambiguity instead
of resolving it.

Interactive investigation: `<pkg-manager> run test:e2e:ui`, or `:debug` for a
step-through, or `:headed` to watch it run.
