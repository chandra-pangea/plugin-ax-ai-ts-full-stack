---
name: package-checklist
description: "MANDATORY when creating, validating, or modifying any shared package. Enforces scoped kebab-case naming, folder structure, required package.json scripts, the exports map, README sections, a package SKILL.md, the public-API class with functional helpers, SOLID and adapter/factory patterns, and a pre-PR gate. Use alongside package-scaffold for new packages and standalone for audits."
metadata:
  version: "2.0"
---

# Package Checklist

Validation for packages under `<packages-dir>` and `<ui-packages-dir>`. For creating
one from scratch, use `package-scaffold` first and this skill second.

## Two kinds of package

The structural requirements below describe a **runtime package** — a class wrapping a
capability, with helpers, interfaces, and tests against a real dependency. That shape
is correct for a logger, an HTTP client, a database wrapper.

It is wrong for a **UI package**, which exports components, tokens, or styles rather
than a service. Applying the runtime template there produces an `interfaces.ts` nobody
imports and a `<main-class>.ts` that does not exist.

| | Runtime package | UI package |
| --- | --- | --- |
| Exports | One public class plus helpers | Components, hooks, tokens, styles |
| Entry point | `src/<main-class>.ts` | `src/index.ts` barrel only |
| `interfaces.ts` | Required — it is the boundary | Not required; prop types live beside their component |
| Tests | Co-located, real execution, per `backend-testing` | End-to-end, per `frontend-testing`. No co-located component tests |
| Build | `tsc --build` | Bundler emitting both formats plus types, and any compiled stylesheet |
| Extra docs | `SKILL.md` | `SKILL.md` plus per-component docs, per `frontend-component-docs` |

Everything outside that table — naming, scripts, exports map, README, dependency
rules, the pre-PR gate — applies to both. Where a rule below is runtime-only, it says
so.

A UI package that is **vendored** (a generator emits its contents) is checked on its
`package.json`, its exports map, and its README only. Its source is not this skill's
business; see `frontend-architecture` rule 11.

## Resolving project conventions

Values in angle brackets come from the project's stack profile. Resolve them in this
order:

1. Read `STACK-PROFILE.md` at the repo root and use its values verbatim.
2. If it is absent or a key is missing, infer from the repo:
   - `pkg-scope` — the `name` field of any existing package
   - `pkg-prefix` — the folder name of that same package, minus its package name
   - `packages-dir`, `pkg-manager`, `test-runner` — workspace globs, lockfile,
     devDependencies
3. If still unresolved, match the dominant convention already present in the repo.
4. Only when the repo is empty, fall back to this skill's stated default — then write
   the chosen values into `STACK-PROFILE.md`.

Never invent a new convention when the repo already expresses one.

> Style, naming, and testing rules are not repeated here. Load `code-style` and
> `backend-testing` directly when generating or reviewing a file.

---

## Scope and folder prefix are independent

Two separate values, and conflating them is the most common mistake:

| Value | Where it appears | Example |
| ----- | ---------------- | ------- |
| `pkg-scope` | `package.json` `name` | `<pkg-scope>/schema-validator` |
| `pkg-prefix` | Directory name | `<packages-dir>/<pkg-prefix>schema-validator` |

They may match, differ, or one may be empty. Read both from the profile — or from an
existing package — rather than deriving one from the other.

## Naming

| Convention | Example | Avoid |
| ---------- | ------- | ----- |
| Single-word utilities | `<pkg-scope>/logger` | camelCase (`schemaValidator`) |
| Hyphenated descriptive | `<pkg-scope>/schema-validator`, `<pkg-scope>/secrets-manager` | unscoped (`logger`), conflated concerns (`utils-schema-validation`) |

**Naming follows responsibility.** `utils` means generic helpers;
`schema-validator` validates and nothing else; `secrets-manager` abstracts secrets.
Split rather than conflate.

## SOLID and patterns in a package

| Principle | Applied | Example |
| --------- | ------- | ------- |
| **Single responsibility** | One package, one concern | A generic-helpers package and a validator stay separate |
| **Interface segregation** | Small, focused exports | Subpath exports for heavy or optional modules |
| **Dependency inversion** | Depend on abstractions | A portable core plus a framework adapter |
| **Adapter** | Framework integration as a submodule | Core validator plus a middleware adapter |
| **Factory** | Export a factory when wiring is non-trivial | `LoggerFactory`, `SecretsManagerFactory` |

Full reference: `package-scaffold/helpers/design-patterns.md`.

## Required structure

**Runtime package:**

```
<packages-dir>/<pkg-prefix><name>/
├── src/
│   ├── helpers/
│   ├── <sub-feature>/        # optional
│   ├── interfaces.ts
│   ├── constants.ts
│   ├── config.ts
│   ├── types.ts
│   ├── <main-class>.ts
│   ├── <main-class>.test.ts
│   └── index.ts
├── test.env              # only when tests need environment input
├── tsconfig.json
├── package.json
├── SKILL.md
└── README.md
```

**UI package** — divided by what it exports, not by the runtime template:

```
<ui-packages-dir>/<name>/
├── src/
│   ├── components/ui/        # components (a generator's layout, where vendored)
│   ├── hooks/
│   ├── providers/
│   ├── themes/               # tokens, where this is the theme package
│   └── index.ts              # the only public entry point
├── assets/                   # fonts, icons — outside src/, copied by the build
├── tsconfig.json
├── package.json
├── SKILL.md
└── README.md
```

A theme package carries no components, and a primitives package carries no tokens.
When one starts importing the other's concern, the tier boundary in
`frontend-architecture` rule 4 has been crossed.

## README requirements

Every package and every application needs a README. Sections marked required are not
negotiable.

| Section | Required | Content |
| ------- | -------- | ------- |
| Title | Yes | `# <pkg-scope>/<name>` |
| One-line summary | Yes | What it does, and where it sits |
| Install | Yes | The `<pkg-manager>` add command plus peer dependencies |
| Quick start | Yes | A minimal working example |
| Infrastructure setup | When it uses an external service | How to run it locally, required environment values, how secrets are wired |
| API | Yes | Method table and config table |
| Package structure | Yes | Directory tree |
| Scripts | Yes | build, test, lint |
| Per-feature reference | When the package has several transports, adapters, providers, or modes | One subsection each, with its own options table |
| Lifecycle | When the package holds state | Singleton usage, scoped instances, graceful shutdown |
| Test infrastructure | When tests need external services | The exact commands that bring them up |

**Sync rule:** modifying a package means updating its README and `SKILL.md` together.
Add new flows and API changes to the README; update `SKILL.md` when adoption guidance
changes.

## `package.json` and `tsconfig.json`

- **`package.json`** — `name`, `version`, `type` (when `module-system` is `esm`),
  `main`, `types`, `files: ["dist"]`, `exports`, and the four scripts below.
- **`tsconfig.json`** — extends the workspace base config, sets `rootDir`, `outDir`,
  `composite`, and excludes tests from the build. It sets **paths only**: a package
  restating `strict`, `target`, `module`, or `moduleResolution` has either diverged
  deliberately, in which case a comment says why, or drifted. Sibling packages
  disagreeing on module resolution is a workspace-level defect, not a local choice —
  see `code-style/helpers/typescript-conventions.md`.

Required scripts: `build`, `test`, `typecheck`, `clean`. A package missing any of
these fails the checklist. A UI package with no unit-test surface still declares
`test` — pointing at the end-to-end suite, or at a no-op that says why.

**Every declared path must exist after a build.** Check them, do not assume:

- A subpath in `exports` whose file the build never emits fails only in a consumer,
  and only at import time. `types` pointing at a directory the build does not write is
  the same failure with a worse error message.
- An `entry` in the bundler config for a directory that does not exist fails the build
  outright — usually long after the entry was added, when someone else runs a clean
  install.
- A peer dependency on a framework the package does not import is noise that becomes a
  spurious install warning for every consumer.

```bash
<pkg-manager> --filter <pkg-scope>/<name> build
node -e "require.resolve('<pkg-scope>/<name>')"   # and once per subpath export
```

Templates for both files are in `package-scaffold`, including the `<test-runner>`
variants.

## Dependencies

- Internal dependencies use the workspace protocol.
- External dependencies are added at the latest version unless compatibility forces a
  pin.
- Add them to the specific package, never to the workspace root.
- No cycles. If A needs B and B needs A, extract the shared types into a third
  package.

## Steps to create

1. Scaffold the files from the structure above.
2. Implement the main class and its helpers.
3. Write tests covering happy path, edge cases, lifecycle, and every public method.
4. Write the README and `SKILL.md`.
5. Add a project reference in the root `tsconfig.json`.
6. Install, build, test.
7. Run `code-review` and clear `[high]` and `[med]` findings.

## Pre-pull-request gate

Both kinds of package:

- [ ] `code-review` run; all `[high]` and `[med]` findings resolved
- [ ] Package name is `<pkg-scope>/<name>` in kebab-case
- [ ] Directory is `<packages-dir>/<pkg-prefix><name>`
- [ ] `package.json` has the correct name, exports map, and all four scripts
- [ ] Every path in `exports`, `main`, `types`, and the bundler config resolves after a
      clean build — checked, not assumed
- [ ] Peer dependencies match what the package actually imports
- [ ] `tsconfig.json` extends the workspace base and overrides paths only
- [ ] `module`/`moduleResolution` match the workspace and the runtime, and relative
      import extensions match that choice
- [ ] `declaration` and `declarationMap` emitted; tests excluded from the build
- [ ] No `any`, no `enum`, no `@ts-ignore`, no strictness flag disabled
- [ ] README has install, quick start, exports, package structure, and scripts
- [ ] Install run; no circular dependencies
- [ ] Imports flow one direction — no dependency back up the tier chain
- [ ] No environment variables read inside the package. In a browser package this is
      not a preference: the bundler does not define `process.env`, so the read returns
      `undefined` at runtime instead of failing at build

Runtime packages:

- [ ] Directory structure matches the runtime template
- [ ] `src/interfaces.ts` exists and defines the package boundary
- [ ] README of an infrastructure package documents local setup, production notes,
      required environment values, and how secrets are injected by the application
- [ ] Tests cover happy path, edge cases, lifecycle, per-feature, per-method, and
      scoped instances where applicable
- [ ] Tests are co-located `*.test.ts`, zero mocks, real execution
- [ ] Root `tsconfig.json` includes the project reference

UI packages:

- [ ] `src/index.ts` is the only public entry point, and it enumerates its exports
      rather than re-exporting a wildcard from several modules — two `export *` lines
      can supply the same name with two different shapes, and the winner is whichever
      the bundler saw last
- [ ] Exactly one implementation of each provider in the whole tier chain
- [ ] Vendored source unmodified; local changes live in the wrapper package
- [ ] Components documented per `frontend-component-docs`
- [ ] Behaviour covered by the end-to-end suite per `frontend-testing`, not by
      co-located component tests

## When this applies

- Creating a package
- Changing a package's structure
- Adding a feature to a package
- Before opening a pull request

Do not skip it.
