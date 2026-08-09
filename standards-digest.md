# JS/TS Full-Stack Standards (always active)

These rules are MANDATORY for all JavaScript/TypeScript code you write, edit,
generate, review, or refactor (.js, .jsx, .ts, .tsx, .mjs, .cjs). Apply them without
being asked. Full rules and examples live in the `ts-full-stack:*` skills — load the
matching skill before writing code. If `STACK-PROFILE.md` exists at the repo root,
its values override anything inferred from the repo.

## Code style (details: ts-full-stack:code-style)

- Arrow functions ONLY — never the `function` keyword, anywhere, React components included.
- Single consolidated `export { ... }` block at the END of each file; no inline exports.
- `export type { ... }` and `import type { ... }` separately; never mix types with runtime imports.
- Import order: type imports, then library imports, then local imports, blank line between groups.
- No nested function definitions — all functions top-level; pass state explicitly.
- No hardcoded reusable values — hoist to UPPER_SNAKE_CASE named constants.
- String literal unions: derive from `as const` objects. No `enum`, no `any`, no `@ts-ignore`.
- Every function gets a 1-2 line intent comment above it. No emojis anywhere.
- Files/folders kebab-case with role suffix (`auth.service.ts`); functions camelCase verb-first;
  booleans is/has/should/can-prefixed; no abbreviations (exceptions: req, res, next, err, id).
- `strict: true` stays on; compiler baseline set once per workspace, packages override paths only.
- Generated or vendored files (a generator's `components/ui/`, `components.json` present) are
  exempt from style rules — wrap them, never edit them.

## Testing (details: ts-full-stack:backend-testing, ts-full-stack:frontend-testing)

- ZERO mocking — no mocks, stubs, spies, or test doubles. Real execution against real
  dependencies and a dedicated test database, never the dev database.
- Tests co-located: `<name>.test.ts` next to the source file. Explicit property-level
  assertions; no snapshot tests.
- UI is verified ONLY by Playwright end-to-end tests against a running app — no JSDOM,
  no component unit tests, no mocked routers or stores.
- Role-based selectors (`getByRole`, `getByLabel`); relative `page.goto` paths against `baseURL`.

## Architecture (details: ts-full-stack:backend-architecture, ts-full-stack:frontend-architecture)

- Reusable technical capability goes in a shared package; domain logic goes in an app
  module. Hexagonal layout: domain and services framework-agnostic; only the channel
  layer touches the web framework; dependencies point inward.
- Frontend business logic lives outside components (hooks, helpers, services).
- Theme tokens over raw color values; mobile-first; one theme provider.
- Main logic = classes with private fields; helpers = pure functions in `helpers/*.util.ts`.

## Accessibility and packages

- Semantic HTML first, ARIA only when semantics cannot express it; full keyboard support
  with visible focus; WCAG 2.1 AA is the floor (ts-full-stack:frontend-accessibility).
- Packages: class public API + functional helpers; own types in public signatures, never
  the underlying library's; an `exports` map that resolves after a clean build; config
  passed in — packages never read environment variables.

## Routing (load the skill BEFORE writing code on that surface)

| Task surface | Skill |
| ------------ | ----- |
| Any JavaScript or TypeScript file | `ts-full-stack:code-style` |
| Backend feature, endpoint, service, or module | `ts-full-stack:backend-architecture` |
| Creating a shared package | `ts-full-stack:package-scaffold`, then `ts-full-stack:package-checklist` |
| Backend or package tests | `ts-full-stack:backend-testing` |
| Any UI code | `ts-full-stack:frontend-architecture` |
| UI tests | `ts-full-stack:frontend-testing` |
| Shared UI components | `ts-full-stack:frontend-accessibility` and `ts-full-stack:frontend-component-docs` |
| Reviews | `ts-full-stack:code-review` |

If a task touches one of these surfaces and the linked skill was not followed, the
change is incomplete.
