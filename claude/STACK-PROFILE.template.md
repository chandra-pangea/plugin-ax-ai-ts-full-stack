# Stack Profile

Copy this file to your repository root as `STACK-PROFILE.md` and fill in the values.
Every skill in this set reads it before doing anything, so one accurate table here
keeps every skill aligned with your layout.

This file is **hand-authored input**. Nothing generates it, and nothing in this set
rewrites it — a skill may append a value it had to decide, and says so when it does.

## How to fill it in

**Delete rows that do not apply.** A missing row is not an error: skills fall back to
detecting from the repository, which usually works. A row asserting something false
makes them act confidently on bad information. When unsure, delete.

**The notes column is doing real work.** `meta-framework: vite` is worth little on its
own. `vite`, *and not Next.js despite a directory named `app/` and a stale `next` peer
dependency*, prevents a specific wrong turn the bare value would not. Write notes for
the reader about to make the mistake you already made.

**Record decisions, not just observations.** It is fine — often necessary — for a row
to describe where the project is going rather than where it is: an `e2e-dir` that does
not exist yet, a `wrappers-pkg` no package implements yet. Writing it down stops every
future task from re-opening the question. Marking it as a target stops the profile
from becoming a lie.

**A repository with two workspaces answers some keys twice.** If a frontend and a
backend live side by side with separate lockfiles and toolchains, give both values and
say which is which — particularly for the toolchain keys, which describe the runtime
that executes the output.

The keys detection is least reliable for, so worth setting even when you skip the
rest: `pkg-scope` and `pkg-prefix` (name and path are separate facts, neither derivable
from the other), `app-dir` and `web-dir` (detection guesses from dependencies and gets
split repositories wrong), `e2e-dir` (nothing indicates where specs should live until
they do), and `test-runner`.

---

## Identity

| Key | Value | Notes |
| --- | ----- | ----- |
| `pkg-scope` | `@acme` | npm scope for internal packages. Empty if packages are unscoped. |
| `pkg-prefix` | `util-` | Folder prefix inside `packages-dir`. May differ from the scope; empty is fine. |
| `ui-scope` | `@acme-ui` | Scope for shared UI packages. Same as `pkg-scope` in a single-scope repo, and deliberately different where the two publish separately. |

A package named `@acme/logger` living at `packages/util-logger/` has
`pkg-scope: @acme` and `pkg-prefix: util-`. The scope and the folder prefix are
independent — state both.

## Layout

Paths are relative to the repository root unless a row says otherwise, so a skill can
locate a file without knowing which workspace it is in.

| Key | Value | Notes |
| --- | ----- | ----- |
| `packages-dir` | `packages` | Shared backend/runtime packages. |
| `app-dir` | `app` | Backend application root. Contains `src/`. |
| `web-dir` | `web` | Frontend application root. Contains `src/`. Watch for a singular `app`, not `apps/<name>`. |
| `ui-packages-dir` | `packages` | Shared UI packages. Same as `packages-dir` in a single-workspace repo. |
| `e2e-dir` | `web/e2e` | Playwright specs. One location for the whole repo. |
| `review-doc` | `docs/review.md` | Relative to **each package root**, not the repository root — every package gets its own review document, written by `code-review`. |

## Toolchain

| Key | Value | Options |
| --- | ----- | ------- |
| `pkg-manager` | `pnpm` | `pnpm` \| `npm` \| `yarn` \| `bun` |
| `test-runner` | `jest` | `jest` \| `vitest` \| `node:test`. A frontend with only end-to-end tests has none — say so rather than naming one nothing uses. |
| `build-orchestrator` | `turbo` | `turbo` \| `nx` \| `none` |
| `node-version` | `22` | Major version. Drives `engines`. |
| `module-system` | `esm` | `esm` \| `cjs` |

## TypeScript

The compiler baseline is not profiled here: it lives once in the workspace
`tsconfig.base.json` and is governed by the `code-style` skill's
`typescript-conventions` helper — target, module resolution, strict extras, and
project references are read from that config, not from this file. Sibling packages
disagreeing with the base config is a defect rather than a set of local choices.

The tell that a workspace has drifted: packages whose relative imports carry `.js`
extensions while resolution is set to `node` or `bundler`, or a shared base config that
most packages override rather than extend. Where that has happened, record the target
and note the gap — `code-review` will raise `types` findings until it closes.

## Frontend

| Key | Value | Options |
| --- | ----- | ------- |
| `ui-framework` | `react` | `react` \| `vue` \| `svelte` — patterns in this set assume React |
| `meta-framework` | `next` | `next` \| `vite` \| `remix` \| `none`. A directory named `app/` does not make it Next.js. |
| `css-strategy` | `tailwind` | `tailwind` \| `css-modules` \| `vanilla-extract` |
| `css-framework-version` | `4` | For Tailwind, `3` and `4` configure differently: v4 is CSS-first, and a `tailwind.config.ts` in a v4 project is never read. |
| `token-format` | `css` | `css` \| `scss-mixin` \| `typescript` — how design tokens are authored before they become custom properties. |
| `theme-pkg` | `tokens` | Package holding design tokens, resolved as `<ui-scope>/<theme-pkg>`. Carries no components. |
| `primitives-pkg` | `ui-core` | Package holding base components, resolved as `<ui-scope>/<primitives-pkg>`. **Note whether it is vendored** — a `components.json` is the signal. |
| `wrappers-pkg` | *(none)* | Brand wrappers over the primitives. **Mandatory when `primitives-pkg` is vendored** — it is the only layer where local changes survive regeneration. |
| `utils-pkg` | `web-utils` | Frontend utilities. No UI, no component-framework imports. |
| `dark-mode-strategy` | `class` | `class` \| `data-attribute` — what the theme provider writes to the document element. Pick one; two is a bug. |
| `dev-url` | `http://localhost:3000` | Base URL the dev server listens on. |

State the UI package dependency direction if the repo has more than two tiers. Each
tier may import only from tiers to its left, and a reverse import is a defect:

```
<theme-pkg>  →  <primitives-pkg>  →  <wrappers-pkg>  →  <web-dir>
  tokens          primitives          brand wrappers     application

<utils-pkg> — outside the chain. Imports no UI package and no component framework.
```

Where `primitives-pkg` is vendored, say so explicitly and say what follows from it:
generated files keep upstream naming and structure so the generator can regenerate
them, style and documentation rules apply from `wrappers-pkg` outward, and a primitive
is extended by wrapping rather than editing.

## Backend

| Key | Value | Options |
| --- | ----- | ------- |
| `http-framework` | `express` | `express` \| `fastify` \| `hono` \| `nest` |
| `db` | `postgres` | `postgres` \| `mongodb` \| `mysql` \| `sqlite` |
| `test-db-url` | `postgres://localhost:5432/app_test` | Dedicated test database. Never the dev database. Where it comes from an env file, name the file rather than inlining a credential. |

---

## Conventions this profile does not cover

Anything not listed here should be inferred from the repo, not invented. If you find
yourself wanting a new key, add it to this file first so every skill sees the same
answer.
