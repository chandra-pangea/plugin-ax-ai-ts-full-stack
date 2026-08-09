---
name: code-style
description: "Use when generating, reviewing, or refactoring any JavaScript or TypeScript file, on any surface. Enforces arrow functions, consolidated exports, separated type imports and exports, import ordering, kebab-case filenames, no nested functions, no hardcoded values, no emojis, function comments, and focused classes. Triggers on write code, refactor, clean up, fix style, review this file."
metadata:
  version: "2.0"
---

# Code Style

Applies to every JavaScript and TypeScript file **authored in this repository** —
backend services, shared packages, frontend components, tests, and configuration.
There is no authored surface where these rules are relaxed.

## What this skill does not govern

Generated and vendored files are not authored here, and rewriting them to satisfy a
style rule guarantees a conflict on the next regeneration. Exempt:

- Component primitives emitted by a UI generator — `shadcn add` and its equivalents.
  A package containing `components.json` is the signal.
- Protobuf, GraphQL, ORM, and API-client output.
- Lockfiles, build output, and anything under a `generated/` directory.

For these, the rule is **do not edit, extend instead**: wrap the generated symbol in an
authored file, and apply the rules there. Configure the linter to relax filename and
function-declaration rules for those paths so the exemption is enforced rather than
remembered. See `frontend-architecture` rule 11 for the UI case.

An exemption covers style, not correctness. Debug logging or a secret in a vendored
file still comes out — and gets recorded, because the next regeneration restores it.

## Resolving project conventions

Values in angle brackets (`<pkg-scope>`, `<packages-dir>`, …) come from the project's
stack profile. Resolve them in this order:

1. Read `STACK-PROFILE.md` at the repo root and use its values verbatim.
2. If it is absent or a key is missing, infer from the repo:
   - `pkg-scope`, `pkg-manager` — root `package.json` (`name`, `packageManager`) and
     which lockfile exists (`pnpm-lock.yaml` / `package-lock.json` / `yarn.lock` / `bun.lockb`)
   - `packages-dir`, `app-dir`, `web-dir` — workspace globs in `pnpm-workspace.yaml`
     or `package.json#workspaces`
   - `test-runner` — devDependencies plus config files (`jest.config.*`, `vitest.config.*`)
3. If still unresolved, match the dominant convention already present in the repo.
4. Only when the repo is empty, fall back to this skill's stated default — then write
   the chosen values into `STACK-PROFILE.md` so the next task is deterministic.

Never invent a new convention when the repo already expresses one.

---

## The rules

| Rule | Requirement |
| ---- | ----------- |
| Arrow functions | No `function` keyword — anywhere, including React components and route handlers |
| Consolidated exports | One `export { ... }` block at the end of the file; no inline `export` on declarations |
| Type exports | `export type { ... }` as a separate statement |
| Type imports | `import type { ... }` as a separate statement |
| Import order | Type imports → library imports → local imports, blank line between groups |
| Filenames | kebab-case with a role suffix (`user.service.ts`, `use-auth.ts`) |
| No nested functions | Every function defined at module top level; pass state as parameters |
| Early returns | Guard clauses freely; avoid deep nesting |
| No hardcoded values | Anything reused or meaningful becomes a named constant |
| Literal unions | Extract string unions into an `as const` object; derive the type from it |
| Function comments | Every function carries a 1–2 line comment stating intent, not narration |
| Focused classes | Extract logic over ~20 lines, or reusable logic, into `helpers/` |
| No emojis | Not in code, comments, logs, errors, console output, or commit messages |
| TypeScript everywhere | No `.js` source, no `allowJs`, no `any`, no `enum`. `strict` stays on and suppressions carry a reason |
| One compiler baseline | `module`/`moduleResolution`/`target` are set once per workspace; packages extend it and override paths only |
| Real generics | Every type parameter used at least twice and constrained to what the body needs. A parameter appearing only in the return position is a cast, not a generic |

## Helper documents

Load only what the current task needs.

| Topic | Document |
| ----- | -------- |
| Arrow functions, and why React is not an exception | [`helpers/arrow-functions.md`](helpers/arrow-functions.md) |
| Export blocks, type separation, import ordering | [`helpers/exports-and-imports.md`](helpers/exports-and-imports.md) |
| Function comments, class focus, nesting, guard clauses, constants | [`helpers/structure-and-constants.md`](helpers/structure-and-constants.md) |
| Files, folders, classes, variables, booleans, tests, and skill names | [`helpers/naming-conventions.md`](helpers/naming-conventions.md) |
| Compiler configuration, module resolution, project references, `interface` vs `type`, type-only imports, deriving types from values, exhaustiveness, narrowing at boundaries, error classes | [`helpers/typescript-conventions.md`](helpers/typescript-conventions.md) |
| Type parameters, constraints, inference, generic ports and components, and the generic shapes that are really casts | [`helpers/generics.md`](helpers/generics.md) |
| Hexagonal boundaries, package handling, dependency direction, build pipeline | [`helpers/build-standards.md`](helpers/build-standards.md) |

---

## Quick reference

**A file that satisfies this skill:**

```typescript
import type { User, UserRepository } from "./user.types";

import { randomUUID } from "node:crypto";

import { AppError } from "../shared/app-error";

const DEFAULT_PAGE_SIZE = 25;
const MAX_PAGE_SIZE = 100;

// Clamps a caller-supplied page size into the range the datastore will accept.
const normalizePageSize = (requested?: number): number => {
  if (requested === undefined) {
    return DEFAULT_PAGE_SIZE;
  }

  return Math.min(Math.max(requested, 1), MAX_PAGE_SIZE);
};

// Loads one page of users at a size the datastore will accept.
const listUsers = async (
  repository: UserRepository,
  pageSize?: number
): Promise<User[]> => {
  return repository.list(normalizePageSize(pageSize));
};

export { listUsers, normalizePageSize, DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE };
```

Note the shape: type imports first, then libraries, then local; constants named and
hoisted; every function an arrow with a comment; a single export block last.

## Precedence

When this skill overlaps with another, `code-style` wins on function style, exports,
imports, and naming. `backend-architecture` and `frontend-architecture` win on where
files live and how layers depend on each other. `backend-testing` and
`frontend-testing` win on test structure.
