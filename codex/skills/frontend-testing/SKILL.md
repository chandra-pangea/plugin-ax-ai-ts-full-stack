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

A worked spec example for every pattern below lives in
[`references/spec-patterns.md`](references/spec-patterns.md). The per-pattern
requirements:

- **Authentication flow** — happy-path sign-in landing on the dashboard, a
  malformed email error, an empty password error, redirect of an unauthenticated
  visitor away from a protected route, and sign-out returning home.
- **Forms, loading, and failure** — a valid save persists across navigation, a
  missing required field errors, the submit button disables and progress is
  announced while saving, and a server rejection shows an error while leaving the
  form recoverable (the failure injected by aborting the route — the only
  interception this skill permits).
- **Empty state** — a query with no results shows the empty placeholder and zero
  list items.
- **Navigation** — link navigation reaches the target page, browser back restores
  the previous page, and an unknown route renders a not-found page.
- **Accessibility** — an automated axe scan (WCAG 2 A/AA plus 2.1 AA) with zero
  violations, keyboard-only reachability of forms, dialogs closing on Escape and
  returning focus to their trigger, exposed landmarks, and a dark-theme contrast
  scan.
- **Mobile** — no horizontal overflow at a small viewport, primary actions meet a
  44px minimum touch target, and the collapsed navigation opens. Assert on the
  targets that matter, not every button on the page.
- **Theming and design-system surfaces** — see below.

### Theming and design-system surfaces

A design system's showcase page is a real flow, and it is usually the first thing in a
UI repo worth covering — the theme switch is the one piece of global state every screen
depends on, and a broken token resolves to `transparent` rather than throwing, so
nothing else catches it.

Assert on **computed styles**, not class names. `toHaveClass("bg-primary")` passes
while the token behind `bg-primary` is undefined; the whole failure mode lives in the
gap between the class and the value it resolves to.

Required coverage: the theme switches to dark and back with the resolved token value
actually changing, the chosen theme survives a reload, the system preference is
honoured on a first visit, and every semantic token resolves to a non-empty value in
both modes. The worked spec — including the `readToken` helper that reads a resolved
custom property off the document element — is in
[`references/spec-patterns.md`](references/spec-patterns.md).

For a component showcase, cover the axes rather than the instances — every variant
renders with a non-transparent background, every size produces a distinct height,
disabled blocks activation. One test per axis, not one per cell of the matrix.

### When a flow has no auth and no routes

Rule 6 lists seven coverage categories. A single-page design-system app has no auth
boundary and no navigation to cover. Skip those two, cover the remaining five, and say
so in the plan document — an explicitly skipped category is a decision, a silently
missing one is a gap. Do not invent a login screen to satisfy a checklist.

---

## Configuration, test plan, and debugging

The full Playwright config sample, the npm scripts, the e2e plan template, and the
debugging guide live in
[`references/configuration-and-debugging.md`](references/configuration-and-debugging.md).
The rules from those sections that always apply:

- The config sets `baseURL`; specs navigate with relative paths only (rule 5).
- Playwright resolves `testDir` relative to the config file — a config that does not
  sit at the repository root must adjust the repo-relative `<e2e-dir>` path
  accordingly.
- Write `<web-dir>/docs/e2e-plan.md` before the first spec. It is what you check
  coverage against afterwards.
- Use locators, never immediate actions on raw selectors — locators carry built-in
  waiting.
- Fix flakiness by waiting on state, never on time (rule 7).
- Resolve a strict mode violation by narrowing the locator with a name or role, not
  with `.first()`, which hides the ambiguity instead of resolving it.

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

## Reference documents

| Deep dive | Reference |
| --------- | --------- |
| Spec patterns per flow: auth, forms, empty states, navigation, accessibility, mobile, theming | [`references/spec-patterns.md`](references/spec-patterns.md) |
| Playwright config, e2e plan template, debugging | [`references/configuration-and-debugging.md`](references/configuration-and-debugging.md) |

## Related skills

- **`frontend-architecture`** — the structure under test
- **`frontend-accessibility`** — what the accessibility specs enforce
- **`backend-testing`** — server-side tests, co-located and separate from this suite
