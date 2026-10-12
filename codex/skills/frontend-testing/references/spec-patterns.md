# End-to-End Spec Patterns

Worked Playwright spec examples for the coverage categories required by the
`frontend-testing` skill. Each section is a complete, runnable pattern.

## Authentication flow

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

## Forms, loading, and failure

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

## Empty state

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

## Navigation

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

## Accessibility

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

## Mobile

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

## Theming and design-system surfaces

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
