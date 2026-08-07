---
name: code-review
description: "Use when asked to review a package, an application, or the whole codebase. Checks every source and test file against 13 categories, then writes durable findings with severity and file:line into a per-package review document. Triggers on review this package, review the codebase, audit, check my code before PR."
metadata:
  version: "2.0"
---

# Code Review

On-demand review of packages and applications against the project's rules and skills.
Findings are written to a durable document rather than reported once and lost.

## Resolving project conventions

Values in angle brackets come from the project's stack profile. Resolve them in this
order:

1. Read `STACK-PROFILE.md` at the repo root and use its values verbatim.
2. If it is absent or a key is missing, infer from the repo:
   - `pkg-scope`, `packages-dir` — root `package.json` and workspace globs
   - `review-doc` — an existing review document anywhere in the repo sets the pattern
3. If still unresolved, match the dominant convention already present in the repo.
4. Only when the repo is empty, fall back to this skill's stated default —
   `<review-doc>` defaults to `docs/review.md`, relative to the package root.

Never invent a new convention when the repo already expresses one.

---

## Trigger

- *"review the codebase"* — every package under `<packages-dir>` plus each application
- *"review `<name>`"* — that package only

Run once the package is implementation-complete, and again before opening a pull
request.

## Procedure

For each package under review:

1. **Read**, in this order:
   - `<packages-dir>/<name>/src/**/*.{ts,tsx}` — all source and test files
   - `<packages-dir>/<name>/package.json` and `tsconfig.json` — the declared surface
     and the compiler settings are as reviewable as the code, and are where a
     dangling `exports` path or a drifted `moduleResolution` shows up
   - `<packages-dir>/<name>/SKILL.md` — the package's own rules, if it has one
   - `<packages-dir>/<name>/README.md`

   Vendored directories are read but reviewed only for `security` and `invariant`.
   Style and design findings against a file a generator will overwrite are noise.

2. **Check** every file against all 13 categories below. Flag **everything**. A
   missing comment is as worth recording as a security issue — severity separates
   them, not the decision to record. For each finding capture:
   - a short description of the problem,
   - the exact path and line (`src/logger.ts:42`),
   - the category label,
   - a severity prefix: `[high]`, `[med]`, or `[low]`.

3. **Write or update** `<packages-dir>/<name>/<review-doc>`:
   - Create it from the template below if absent.
   - Append new findings to **Open Issues**. Never remove or reorder existing entries.
   - Move any previously open issue that the current code has fixed into
     **Completed**, with a resolution date.

4. For an application, follow the same procedure against `<app-dir>` or `<web-dir>`,
   writing to that application's `<review-doc>`.

## Review document template

```markdown
# Review — <pkg-scope>/<name>

Last reviewed: <ISO date>

## Open Issues

- [ ] <severity> <short description> — `<file>:<line>` — [category]

## Completed

- [x] <short description> — resolved <date or PR>
```

**Maintenance rules:**

- Append under **Open Issues**; never overwrite or reorder.
- Move verified fixes to **Completed** rather than deleting them.
- Completed entries are permanent history.
- Every entry carries a `file:line` reference and a category label.

## Review categories

| Category | Label | What to flag |
| -------- | ----- | ------------ |
| Code style | `style` | `function` keyword, nested functions, inline exports, hardcoded values, business logic in a class body that belongs in a helper, emojis |
| Type safety | `types` | `any`, unexplained `as` and `as unknown as`, `!` without a stated reason, `@ts-ignore`, a strictness flag disabled, `enum`, a type-only import not marked `import type`, an unnarrowed external value, a union branched over without an exhaustiveness check, a package `tsconfig.json` restating compiler settings its workspace base already sets, `module`/`moduleResolution` disagreeing with a sibling package or with the import extensions in use |
| Generics | `generics` | A type parameter used once in its signature, or only in the return position with nothing validating it — flag as `[med]`, since it is an unchecked cast that reads as a type. Also: unconstrained parameters, `<T = any>`, `as T` inside a generic body standing in for a constraint, explicit type arguments required at every call site, single-letter names where there are two or more parameters, inline conditional types that should be named aliases |
| Edge case coverage | `test-coverage` | Missing tests for null or undefined input, empty collections, concurrent calls, error paths, reinitialization after teardown, boundary values, invalid config |
| Logic issues | `logic` | Missing guards, unhandled rejections, missing `await`, races on shared mutable state, incorrect error propagation, silent failures |
| Design issues | `design` | Business logic embedded in class methods, functions beyond roughly 20 lines, missing abstraction, objects doing too many jobs |
| Resource management | `resource` | Connections or handles never closed, missing flush or drain before teardown, no timeout on external calls, listeners not removed, timers not cleared |
| API surface leakage | `api` | Underlying library types exposed in public signatures, types not declared in the types module, public methods without a comment |
| Security | `security` | Credentials in source, unvalidated external input reaching a datastore or shell, sensitive values written to logs |
| Framework coupling | `coupling` | Business logic inside the web framework's route handlers or middleware, request and response objects reaching deep into logic, a raw driver used directly where a shared package exists |
| Docs completeness | `docs` | README missing its API or config table, package `SKILL.md` missing its rules section |
| Checklist compliance | `checklist` | Package name not `<pkg-scope>/*`, folder not under `<packages-dir>/<pkg-prefix>*`, missing `SKILL.md` or `README.md`, `package.json` missing build, test, typecheck, or clean scripts |
| Package invariants | `invariant` | A raw driver, HTTP client, or cloud SDK used directly in application code where a shared package exists; environment variables read inside a package rather than passed in; library-internal types imported past the barrel; secrets not injected by the application |

## Severity

- `[high]` — security issue, data loss risk, resource leak, broken invariant
- `[med]` — logic bug, missing coverage on a critical path, design issue
- `[low]` — style violation, missing comment, minor documentation gap

```markdown
## Open Issues

- [ ] [high] Database connection never closed on the error path — `src/client.ts:87` — [resource]
- [ ] [med] Missing test for concurrent create() calls — `src/logger.test.ts` — [test-coverage]
- [ ] [low] `buildTransport` missing its intent comment — `src/helpers/build-transport.util.ts:12` — [api]
```

## Before writing the document

- [ ] Every source file checked for style, types, generics, logic, design, resource, api, security, coupling
- [ ] `package.json` and `tsconfig.json` checked against the workspace baseline
- [ ] Every test file checked for coverage gaps — lifecycle, per-feature, per-error-path, scoped instances
- [ ] README checked for its API table and config reference
- [ ] Package rules section read, then verified against the code
- [ ] Package name and folder checked against the profile
- [ ] Severity assigned to every finding
- [ ] Previously open issues that are now fixed moved to Completed
