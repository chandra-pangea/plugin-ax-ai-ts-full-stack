---
name: frontend-testing
description: "Use when writing or reviewing any test for the web application or a shared UI package. Enforces Playwright end-to-end coverage against a real running app — no JSDOM, no mocked routers, stores, or HTTP clients — with role-based selectors and required coverage per flow (happy path, validation, loading and empty, auth boundary, navigation, accessibility, mobile). Triggers on test the UI, e2e, Playwright, add coverage for this page."
metadata:
  version: "2.0"
---

# Frontend Testing

UI behavior is verified end to end against a running application. This skill owns
`<e2e-dir>` and everything in it; `backend-testing` owns co-located server tests and
does not duplicate these rules.

## Resolving project conventions

Values in angle brackets come from the project's stack profile. Resolve them in this
order:

1. Read `STACK-PROFILE.md` at the repo root and use its values verbatim.
2. If it is absent or a key is missing, infer from the repo:
   - `dev-url` — the dev server port in the web application's scripts or config
   - `e2e-dir` — an existing Playwright config's `testDir`
   - `pkg-manager` — which lockfile exists
3. If still unresolved, match the dominant convention already present in the repo.
4. Only when the repo is empty, fall back to this skill's stated default — then write
   the chosen values into `STACK-PROFILE.md`.

Never invent a new convention when the repo already expresses one.

---

## Hard rules

### 1. Real browser, real app

- Tests drive a real running application — real server, real API, real database.
- No mocking of `fetch`, the router, state management, or component internals.
- No JSDOM-only unit tests for UI flows. They pass while the integration is broken.
- **Exception, narrowly:** intercepting a route to inject a network *failure* is
  allowed, because some error paths cannot otherwise be produced. Substituting a
  successful response to avoid setting up real data is not.

### 2. Location and naming

- Specs live in `<e2e-dir>`, never beside components.
- Named for the flow: `user-login.spec.ts`, `product-checkout.spec.ts`.
- One spec per user-facing flow, not per component.
- Shared setup lives in `<e2e-dir>/fixtures/`.

### 3. Role-based selectors only

Query the way a user perceives the page — by role, label, or visible text. A CSS
selector couples the test to markup that will change for reasons unrelated to
behavior.

| Use | Avoid |
| --- | ----- |
| `getByRole("button", { name: "Sign in" })` | `locator("button[type=submit]")` |
| `getByLabel("Email")` | `locator("input[name=email]")` |
| `getByRole("heading", { name: "Dashboard" })` | `locator("h1:has-text('Dashboard')")` |
| `getByTestId("cart-total")` | `locator(".cart .total > span")` |

`getByTestId` is the escape hatch when nothing semantic identifies the element — and
usually signals a missing accessible name worth fixing in the component instead.

### 4. No component unit tests

Rendering is covered by the end-to-end suite, which renders for real. Do not test
props in isolation. If you are writing `render()` plus a query, stop and write a
spec instead.

The exception is a pure utility function, which is tested by `backend-testing` rules
as a normal co-located unit test.

### 5. Relative paths

The Playwright config sets `baseURL`. Specs navigate with relative paths so the suite
runs unchanged against local, preview, and CI environments.

```typescript
await page.goto("/login");   // right
await page.goto("http://localhost:3000/login");  // wrong
```

### 6. Coverage per flow

Every shipped page or flow needs all of:

- **Happy path** — the user completes the flow and reaches the success state.
- **Validation errors** — empty required field, invalid value, server rejection.
- **Loading and empty states** — pending indicator, empty placeholder.
- **Auth boundary** — unauthenticated users redirected, authorized users pass.
- **Navigation** — deep links and the back button leave the app coherent.
- **Accessibility** — keyboard operation plus an automated scan.
- **Mobile** — usable at 375px.

### 7. Async discipline

- `await` every action and every assertion.
- Web-first assertions (`toBeVisible`, `toHaveURL`) retry; bare truthiness checks do
  not.
- Never `waitForTimeout`. Wait for a condition.

### 8. Independence

Each test sets up its own data and runs in any order. Create data through the same
API a user would reach, never by writing to the database from a spec. Never share
mutable state between specs.

---

## Layout

```
<e2e-dir>/
  fixtures/
    auth.fixture.ts       # login helpers, authenticated contexts
    test-data.fixture.ts  # data builders that call the real API
  auth.spec.ts
  user-profile.spec.ts
  product-search.spec.ts
  checkout.spec.ts
  accessibility.spec.ts
  mobile.spec.ts
```

## Fixtures

Helpers are arrow functions in a module, not `function` declarations inside a spec.

```typescript
// <e2e-dir>/fixtures/auth.fixture.ts
import type { Page } from "@playwright/test";

type Credentials = {
  email: string;
  password: string;
};

// Creates a unique account per test so specs never contend for one user.
const buildCredentials = (): Credentials => {
  return {
    email: `user-${crypto.randomUUID()}@example.test`,
    password: "correct-horse-battery-staple",
  };
};

// Registers and signs in, leaving the page on the dashboard.
const signUpAndLogIn = async (page: Page, credentials: Credentials): Promise<void> => {
  await page.goto("/signup");
  await page.getByLabel("Email").fill(credentials.email);
  await page.getByLabel("Password").fill(credentials.password);
  await page.getByRole("button", { name: "Create account" }).click();
  await page.waitForURL("/dashboard");
};

export { buildCredentials, signUpAndLogIn };

export type { Credentials };
```

Generating credentials per test beats a shared fixture user — a shared user makes
parallel runs interfere and turns one failure into a cascade.

---

## Patterns

### Authentication flow

```typescript
import { expect, test } from "@playwright/test";

import { buildCredentials, signUpAndLogIn } from "./fixtures/auth.fixture";

test.describe("authentication", () => {
  test("signs in with valid credentials and lands on the dashboard", async ({ page }) => {
    const credentials = buildCredentials();
    await signUpAndLogIn(page, credentials);

    await expect(page).toHaveURL("/dashboard");
    await expect(page.getByRole("heading", { name: "Dashboard" })).toBeVisible();
  });

  test("shows a validation error for a malformed email", async ({ page }) => {
    await page.goto("/login");
    await page.getByLabel("Email").fill("not-an-email");
    await page.getByLabel("Password").fill("whatever-value");
    await page.getByRole("button", { name: "Sign in" }).click();

    await expect(page.getByRole("alert")).toContainText("valid email");
    await expect(page).toHaveURL("/login");
  });

  test("requires a password", async ({ page }) => {
    await page.goto("/login");
    await page.getByLabel("Email").fill("someone@example.test");
    await page.getByRole("button", { name: "Sign in" }).click();

    await expect(page.getByRole("alert")).toContainText("Password is required");
  });

  test("redirects an unauthenticated visitor away from the dashboard", async ({ page }) => {
    await page.goto("/dashboard");

    await expect(page).toHaveURL("/login");
  });

  test("signs out and returns to the home page", async ({ page }) => {
    await signUpAndLogIn(page, buildCredentials());
    await page.getByRole("button", { name: "Sign out" }).click();

    await expect(page).toHaveURL("/");
    await expect(page.getByRole("heading", { name: "Welcome" })).toBeVisible();
  });
});
```

### Forms, loading, and failure

```typescript
import { expect, test } from "@playwright/test";

import { buildCredentials, signUpAndLogIn } from "./fixtures/auth.fixture";

test.describe("profile editing", () => {
  test.beforeEach(async ({ page }) => {
    await signUpAndLogIn(page, buildCredentials());
    await page.goto("/profile/edit");
  });

  test("saves valid changes and persists them", async ({ page }) => {
    const firstName = "Ada";

    await page.getByLabel("First name").fill(firstName);
    await page.getByRole("button", { name: "Save" }).click();

    await expect(page.getByRole("status")).toContainText("Profile updated");

    await page.goto("/profile");
    await expect(page.getByRole("heading", { name: firstName })).toBeVisible();
  });

  test("reports a missing required field", async ({ page }) => {
    await page.getByLabel("First name").clear();
    await page.getByRole("button", { name: "Save" }).click();

    await expect(page.getByRole("alert")).toContainText("First name is required");
  });

  test("disables the button and shows progress while saving", async ({ page }) => {
    await page.getByLabel("First name").fill("Grace");

    const save = page.getByRole("button", { name: "Save" });
    await save.click();

    await expect(save).toBeDisabled();
    await expect(page.getByRole("status")).toContainText("Profile updated");
    await expect(save).toBeEnabled();
  });

  test("recovers when the server rejects the save", async ({ page }) => {
    // Injecting a transport failure — the only interception this skill permits.
    await page.route("**/api/profile", (route) => route.abort("failed"));

    await page.getByLabel("First name").fill("Alan");
    await page.getByRole("button", { name: "Save" }).click();

    await expect(page.getByRole("alert")).toContainText("Failed to update profile");
    await expect(page.getByLabel("First name")).toBeEnabled();
  });
});
```

### Empty state

```typescript
import { expect, test } from "@playwright/test";

test("shows an empty placeholder when a search returns nothing", async ({ page }) => {
  await page.goto("/products");
  await page.getByLabel("Search products").fill("zzzz-no-such-product");
  await page.getByRole("button", { name: "Search" }).click();

  await expect(page.getByText("No products found")).toBeVisible();
  await expect(page.getByRole("listitem")).toHaveCount(0);
});
```

### Navigation

```typescript
import { expect, test } from "@playwright/test";

test.describe("navigation", () => {
  test("moves from the home page into products", async ({ page }) => {
    await page.goto("/");
    await page.getByRole("link", { name: "Products" }).click();

    await expect(page).toHaveURL("/products");
    await expect(page.getByRole("heading", { name: "Products" })).toBeVisible();
  });

  test("restores the previous page on browser back", async ({ page }) => {
    await page.goto("/products");
    await page.getByRole("link", { name: "Wireless keyboard" }).click();
    await expect(page).toHaveURL(/\/products\/[\w-]+$/);

    await page.goBack();
    await expect(page).toHaveURL("/products");
    await expect(page.getByRole("heading", { name: "Products" })).toBeVisible();
  });

  test("renders a not-found page for an unknown route", async ({ page }) => {
    await page.goto("/no-such-page");

    await expect(page.getByRole("heading", { name: "Page not found" })).toBeVisible();
  });
});
```

### Accessibility

```typescript
import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test.describe("accessibility", () => {
  test("home page has no detectable violations", async ({ page }) => {
    await page.goto("/");

    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test("login form is reachable and operable by keyboard alone", async ({ page }) => {
    await page.goto("/login");

    await page.keyboard.press("Tab");
    await expect(page.getByLabel("Email")).toBeFocused();

    await page.keyboard.press("Tab");
    await expect(page.getByLabel("Password")).toBeFocused();

    await page.keyboard.press("Tab");
    await expect(page.getByRole("button", { name: "Sign in" })).toBeFocused();
  });

  test("dialog closes on Escape and returns focus to its trigger", async ({ page }) => {
    await page.goto("/settings");

    const trigger = page.getByRole("button", { name: "Delete account" });
    await trigger.click();
    await expect(page.getByRole("dialog")).toBeVisible();

    await page.keyboard.press("Escape");
    await expect(page.getByRole("dialog")).toBeHidden();
    await expect(trigger).toBeFocused();
  });

  test("page exposes its landmarks", async ({ page }) => {
    await page.goto("/");

    await expect(page.getByRole("navigation")).toBeVisible();
    await expect(page.getByRole("main")).toBeVisible();
    await expect(page.getByRole("contentinfo")).toBeVisible();
  });

  test("dark theme keeps sufficient contrast", async ({ page }) => {
    await page.emulateMedia({ colorScheme: "dark" });
    await page.goto("/");

    const results = await new AxeBuilder({ page })
      .withTags(["wcag2aa"])
      .analyze();

    expect(results.violations).toEqual([]);
  });
});
```

### Mobile

```typescript
import { devices, expect, test } from "@playwright/test";

const MINIMUM_TOUCH_TARGET_PX = 44;

test.describe("mobile", () => {
  test.use({ ...devices["iPhone SE"] });

  test("renders without horizontal overflow", async ({ page }) => {
    await page.goto("/");

    const overflow = await page.evaluate(() => {
      return document.documentElement.scrollWidth - document.documentElement.clientWidth;
    });

    expect(overflow).toBeLessThanOrEqual(0);
  });

  test("gives primary actions a large enough touch target", async ({ page }) => {
    await page.goto("/");

    const button = page.getByRole("button", { name: "Get started" });
    const box = await button.boundingBox();

    expect(box?.height ?? 0).toBeGreaterThanOrEqual(MINIMUM_TOUCH_TARGET_PX);
    expect(box?.width ?? 0).toBeGreaterThanOrEqual(MINIMUM_TOUCH_TARGET_PX);
  });

  test("opens the collapsed navigation", async ({ page }) => {
    await page.goto("/");

    await page.getByRole("button", { name: "Open menu" }).click();
    await expect(page.getByRole("navigation")).toBeVisible();
  });
});
```

Measuring every button on the page turns one oversight into dozens of failures and
makes the suite slow. Assert on the targets that matter.

### Theming and design-system surfaces

A design system's showcase page is a real flow, and it is usually the first thing in a
UI repo worth covering — the theme switch is the one piece of global state every screen
depends on, and a broken token resolves to `transparent` rather than throwing, so
nothing else catches it.

Assert on **computed styles**, not class names. `toHaveClass("bg-primary")` passes
while the token behind `bg-primary` is undefined; the whole failure mode lives in the
gap between the class and the value it resolves to.

```typescript
import type { Page } from "@playwright/test";

import { expect, test } from "@playwright/test";

// Reads a resolved custom property off the document element.
const readToken = async (page: Page, token: string): Promise<string> => {
  return page.evaluate((name) => {
    return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  }, token);
};

test.describe("theming", () => {
  test("switches to dark and back", async ({ page }) => {
    await page.goto("/");

    const light = await readToken(page, "--background");
    await page.getByRole("button", { name: "Dark" }).click();

    await expect(page.locator("html")).toHaveClass(/dark/);
    expect(await readToken(page, "--background")).not.toBe(light);
  });

  test("remembers the chosen theme across a reload", async ({ page }) => {
    await page.goto("/");
    await page.getByRole("button", { name: "Dark" }).click();
    await page.reload();

    await expect(page.locator("html")).toHaveClass(/dark/);
  });

  test("honours the system preference on a first visit", async ({ page }) => {
    await page.emulateMedia({ colorScheme: "dark" });
    await page.goto("/");

    await expect(page.locator("html")).toHaveClass(/dark/);
  });

  test("resolves every semantic token in both modes", async ({ page }) => {
    const tokens = ["--background", "--foreground", "--primary", "--destructive"];
    await page.goto("/");

    for (const mode of ["light", "dark"] as const) {
      await page.emulateMedia({ colorScheme: mode });

      for (const token of tokens) {
        expect(await readToken(page, token), `${token} in ${mode}`).not.toBe("");
      }
    }
  });
});
```

An undefined token is the failure this catches. It renders as nothing, in one mode
only, and no build step reports it.

For a component showcase, cover the axes rather than the instances — every variant
renders with a non-transparent background, every size produces a distinct height,
disabled blocks activation. One test per axis, not one per cell of the matrix.

### When a flow has no auth and no routes

Rule 6 lists seven coverage categories. A single-page design-system app has no auth
boundary and no navigation to cover. Skip those two, cover the remaining five, and say
so in the plan document — an explicitly skipped category is a decision, a silently
missing one is a gap. Do not invent a login screen to satisfy a checklist.

---

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

---

## Test plan

Write `<web-dir>/docs/e2e-plan.md` before the first spec. It is what you check
coverage against afterwards.

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

---

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

---

## Before merging

- [ ] Test plan written
- [ ] Suite passes locally
- [ ] Passes on Chromium, Firefox, WebKit
- [ ] Passes at 375px
- [ ] Three consecutive clean runs — no flakes
- [ ] Accessibility scan clean
- [ ] No `waitForTimeout` anywhere
- [ ] No CSS or tag-chain selectors
- [ ] All paths relative
- [ ] Every required coverage category present
- [ ] Interception used only to inject failures

## Related skills

- **`frontend-architecture`** — the structure under test
- **`frontend-accessibility`** — what the accessibility specs enforce
- **`backend-testing`** — server-side tests, co-located and separate from this suite
