---
name: package-scaffold
description: "MANDATORY when creating a new shared runtime package. Use whenever backend code is technical and reusable — logger, HTTP client, database wrapper, validator, retry, cache, secrets, parser, formatter, crypto, queue, rate limiter, config loader. Defines the folder layout, the public-class-wraps-library pattern, config files, tests, and package documentation. Triggers on new package, build a util, create a wrapper, vendor a library, share between services."
metadata:
  version: "2.1"
---

# Package Scaffold

Follow this when creating a package under `<packages-dir>`. It defines layout, the
public API pattern, configuration files, and documentation. For validating an
existing package, use `package-checklist`.

## Scope

This skill scaffolds a **runtime package**: one public class wrapping a capability,
with helpers behind it and tests against the real dependency.

It does not apply to UI packages — components, hooks, design tokens, styles. Those
have no main class to wrap and no co-located tests to write, and forcing this layout
onto one produces an `interfaces.ts` nobody imports. For a UI package, take the layout
from `package-checklist`'s UI template and the tier rules from `frontend-architecture`
rule 4; the naming, scripts, exports-map, and README requirements below still apply.

**Before creating anything, check whether it should exist.** If a package already
covers 80% of the need, extend it. A second package overlapping the first is worse
than a slightly broader first one, because the overlap is invisible at the import
site.

## Resolving project conventions

Values in angle brackets come from the project's stack profile. Resolve them in this
order:

1. Read `STACK-PROFILE.md` at the repo root and use its values verbatim.
2. If it is absent or a key is missing, infer from the repo:
   - `pkg-scope`, `pkg-prefix` — read an existing package's `package.json` name and
     its folder name; they are independent
   - `packages-dir` — workspace globs
   - `test-runner`, `pkg-manager`, `module-system` — devDependencies, lockfile, and
     `"type"` in the root `package.json`
3. If still unresolved, match the dominant convention already present in the repo.
4. Only when the repo is empty, fall back to this skill's stated default — then write
   the chosen values into `STACK-PROFILE.md`.

Never invent a new convention when the repo already expresses one.

**Prerequisites** — every file generated here also obeys:

- **`code-style`** — arrow functions, consolidated exports, type separation, import
  ordering, no hardcoded values, function comments, focused classes.
- **`code-style/helpers/naming-conventions.md`** — kebab-case files, PascalCase
  classes, camelCase functions, UPPER_SNAKE_CASE constants.
- **`code-style/helpers/typescript-conventions.md`** — the compiler baseline this
  package's `tsconfig.json` extends, and the module resolution it must not diverge
  from.
- **`code-style/helpers/generics.md`** — a package's public contract is where
  generics either earn their place or become casts. Ports are generic over their
  entity; the adapter fixes the parameters and nothing generic leaks past it.
- **`backend-testing`** — zero mocking, real execution, co-located tests.

Those rules are not repeated here.

---

## 1. Folder structure

```
<packages-dir>/<pkg-prefix><name>/
  src/
    helpers/                  # internal helpers, not public API
      <helper-name>.util.ts
      <helper-name>.util.test.ts
    <sub-feature>/            # optional (transports/, adapters/, providers/)
      <module>.ts
      <module>.test.ts
    interfaces.ts             # public contracts — mandatory
    constants.ts              # package constants
    config.ts                 # typed config normalization
    types.ts                  # public and internal types
    <main-class>.ts           # the public API class
    <main-class>.test.ts
    index.ts                  # barrel — public API only
  test.env                    # optional inputs for the test harness
  tsconfig.json
  package.json
  SKILL.md                    # how to adopt this package
  README.md                   # API reference
```

All source lives under `src/`. Tests sit next to what they test.

### Build order

1. **Scaffold** — `package.json`, `tsconfig.json`, `interfaces.ts`, `types.ts`,
   `constants.ts`, `config.ts`, and an `index.ts` skeleton.
2. **Implement** — the main class, its public methods, helpers under `src/helpers/`.
3. **Test** — every category from `backend-testing`.
4. **Document** — `README.md` with a full API table, then `SKILL.md`.

Run `code-review` once implementation is complete and clear `[high]` and `[med]`
findings before opening a pull request.

---

## 2. The public interface class

Every package exposes **one primary class** as its public API. That class wraps the
underlying library so consumers never import the library directly — which is what
makes the library replaceable later.

### Choosing a pattern

| Pattern | When | Example |
| ------- | ---- | ------- |
| **Singleton and factory** | A shared stateful resource, where a single instance is genuinely justified | `Logger.create()`, `Logger.getInstance()` |
| **Static only** | Stateless utilities | `Crypto.hash(data)`, `Validator.isEmail(value)` |
| **Instance-based** | Each consumer needs independent state | `new HttpClient(baseUrl)` |

### Singleton and factory

```typescript
import type { WidgetConfig } from "./types";

class Widget {
  static #instance: Widget | null = null;

  #client: UnderlyingClient;

  private constructor(client: UnderlyingClient) {
    this.#client = client;
  }

  // Builds the singleton from config; heavy setup belongs in helpers/.
  static create = (config?: WidgetConfig): Widget => {
    const widget = new Widget(buildClient(config));
    Widget.#instance = widget;
    return widget;
  };

  // Returns the initialized instance, failing loudly if create() was skipped.
  static getInstance = (): Widget => {
    if (Widget.#instance === null) {
      throw new Error("Widget not initialized. Call Widget.create() first.");
    }

    return Widget.#instance;
  };

  // Flushes pending work and clears the singleton so create() can run again.
  close = async (): Promise<void> => {
    await this.#client.drain();

    if (Widget.#instance === this) {
      Widget.#instance = null;
    }
  };
}

export { Widget };
```

### Static only

```typescript
class Hasher {
  private constructor() {}

  // Returns a hex digest of the input using the configured algorithm.
  static hash = (input: string): string => {
    return computeDigest(input);
  };
}

export { Hasher };
```

### Instance-based

```typescript
import type { HttpClientConfig } from "./types";

class HttpClient {
  #client: UnderlyingClient;

  constructor(config: HttpClientConfig) {
    this.#client = buildClient(config);
  }

  // Issues a GET and returns the decoded body, translating transport errors.
  get = async <T>(path: string): Promise<T> => {
    return this.#client.request<T>("GET", path);
  };
}

export { HttpClient };
```

### Rules

- The underlying library lives in a **private field** (`#field`). Consumers never
  reach it.
- Public methods use **your own types** from `types.ts`, never the library's. This is
  what lets you swap the library without a breaking change.
- Expose `close()` and `flush()` when there is anything to clean up.
- Expose `child(bindings)` when the package supports scoped instances.
- Extract a method to `helpers/` once it exceeds roughly 20 lines or becomes reusable.
- Never read environment variables inside a package. The application reads config and
  passes it in — otherwise the package cannot be used by a second application.

For other patterns, see the helper:

| Deep dive | Helper |
| --------- | ------ |
| Adapter, factory, strategy, and the other patterns a package's public class leans on | [`helpers/design-patterns.md`](helpers/design-patterns.md) |

---

## 3. File conventions

### `src/constants.ts`

```typescript
const DEFAULT_TIMEOUT_MS = 5000;
const DEFAULT_MAX_RETRIES = 3;
const DEFAULT_POOL_SIZE = 10;

export { DEFAULT_TIMEOUT_MS, DEFAULT_MAX_RETRIES, DEFAULT_POOL_SIZE };
```

### `src/config.ts`

Normalizes config the caller passes in. Package code never loads an env file.

```typescript
import type { WidgetConfig } from "./types";

import { DEFAULT_TIMEOUT_MS } from "./constants";

// Fills defaults into caller-supplied config and validates required fields.
const createWidgetConfig = (input: Partial<WidgetConfig> = {}): WidgetConfig => {
  if (input.endpoint === undefined) {
    throw new Error("WidgetConfig.endpoint is required");
  }

  return {
    timeoutMs: DEFAULT_TIMEOUT_MS,
    ...input,
    endpoint: input.endpoint,
  };
};

export { createWidgetConfig };
```

### `src/types.ts`

Every type — public config, internal shapes, discriminated unions.

```typescript
type WidgetConfig = {
  endpoint: string;
  timeoutMs?: number;
};

type InternalOptions = {
  retryBudget: number;
};

export type { WidgetConfig, InternalOptions };
```

### `src/interfaces.ts` (mandatory)

Public contracts — the API boundary.

```typescript
import type { WidgetConfig } from "./types";

type WidgetContract = {
  send: (payload: string) => Promise<void>;
  close: () => Promise<void>;
};

type WidgetModule = {
  create: (config: WidgetConfig) => WidgetContract;
};

export type { WidgetContract, WidgetModule };
```

### `src/index.ts`

Minimal. Only what consumers need.

```typescript
import { Widget } from "./widget";

import type { WidgetConfig } from "./types";
import type { WidgetContract } from "./interfaces";

export { Widget };

export type { WidgetConfig, WidgetContract };
```

### `src/helpers/`

Internal, functional, one file each with a co-located test. Never re-exported from
the barrel.

```
src/helpers/
  build-targets.util.ts
  build-targets.util.test.ts
  parse-options.util.ts
  parse-options.util.test.ts
```

---

## 4. Configuration files

### `tsconfig.json`

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "rootDir": "src",
    "outDir": "dist",
    "composite": true
  },
  "include": ["src/**/*.ts"],
  "exclude": ["src/**/*.test.ts", "dist", "node_modules"]
}
```

### `package.json`

Packages use the **root test-runner config**; they do not carry their own.

When `test-runner` is `jest`:

```json
{
  "name": "<pkg-scope>/<name>",
  "version": "0.1.0",
  "type": "module",
  "description": "<one line>",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "exports": {
    ".": { "types": "./dist/index.d.ts", "import": "./dist/index.js" }
  },
  "files": ["dist"],
  "scripts": {
    "build": "tsc --build",
    "test": "jest --config ../../jest.config.cjs --testPathPatterns=\"<packages-dir>/<pkg-prefix><name>\"",
    "test:watch": "jest --config ../../jest.config.cjs --testPathPatterns=\"<packages-dir>/<pkg-prefix><name>\" --watch",
    "typecheck": "tsc --noEmit",
    "clean": "rm -rf dist *.tsbuildinfo"
  },
  "engines": {
    "node": ">=<node-version>.0.0"
  },
  "dependencies": {},
  "devDependencies": {}
}
```

Jest 30 renamed `--testPathPattern` to `--testPathPatterns`; on Jest 29 and earlier
use the singular form.

When `test-runner` is `vitest`, the scripts become:

```json
{
  "test": "vitest run --root ../.. --dir <packages-dir>/<pkg-prefix><name>",
  "test:watch": "vitest --root ../.. --dir <packages-dir>/<pkg-prefix><name>"
}
```

Set `"type": "module"` only when `module-system` is `esm`. Under `cjs`, omit it, drop
the `.js` extensions from relative imports, and the `exports` entry uses `"require"`
instead of `"import"`. Every subpath added later gets its own `exports` entry — an
export that does not resolve after a clean build fails `package-checklist`.

### `test.env` (optional — only when tests need environment input)

```
# Optional inputs for the test harness. Package code never reads this file —
# the harness loads it and passes values in.
```

---

## 5. Package `SKILL.md`

Every package carries its own `SKILL.md` at its root, so another repository can adopt
it.

````markdown
---
name: <pkg-prefix><name>
description: <What the package does and when to reach for it.>
metadata:
  version: "0.1.0"
  repo: <repo-url>
  path: <packages-dir>/<pkg-prefix><name>
---

# <pkg-scope>/<name>

<One-line summary.>

Full API reference: [README.md](./README.md).

## When to use

Adopt this package when you need:

- <capability>
- <capability>

## Adopting into another repository

```bash
PACKAGE_REF="<git-tag-or-main>"
TMPDIR=$(mktemp -d)
git clone --depth 1 --branch "$PACKAGE_REF" --filter=blob:none --sparse \
  <repo-url> "$TMPDIR"
git -C "$TMPDIR" sparse-checkout set <packages-dir>/<pkg-prefix><name>
cp -r "$TMPDIR/<packages-dir>/<pkg-prefix><name>" ./<packages-dir>/
rm -rf "$TMPDIR"
```

Then install and build from the package directory.

### Provenance

Record where the copy came from, in `.vendor.json`:

```json
{
  "source": "<repo-url>",
  "package": "<packages-dir>/<pkg-prefix><name>",
  "tag": "<git-tag-or-main>",
  "vendoredAt": "<ISO-8601 date>",
  "forked": false
}
```

Updating means repeating the sparse checkout at a new ref and updating that file.

## Quick usage

(5–10 lines, no more)

## Rules

- Do not modify adopted code. Extend through adapters or wrappers.
- If you must modify it, set `"forked": true` in `.vendor.json`.
- Connection strings and secrets come from the application, never from inside this
  package.
````

---

## 6. Package `README.md`

1. Name and one-line description
2. Install — the `<pkg-manager>` add command, plus any peer dependencies
3. Quick start — a minimal working example
4. Use cases — a table mapping flows to entry points, when there are several
5. How to use — an example per major flow
6. Singleton usage, if applicable
7. Full API table — every public method with its signature and description
8. Config reference — field, type, default, description
9. Sub-feature reference — one section per transport, adapter, or provider
10. Test infrastructure — the commands that bring up anything the tests need

**Sync rule:** changing a package means updating its README and `SKILL.md` in the same
commit.

---

## 7. Checklist

| # | Check |
| - | ----- |
| 1 | Folder structure matches section 1 |
| 2 | One public class wraps the underlying library |
| 3 | Private fields hide library internals |
| 4 | `interfaces.ts` exists and defines the boundary |
| 5 | `types.ts` holds all types; no library type reaches a consumer |
| 6 | `constants.ts` holds every magic value |
| 7 | `config.ts` normalizes input; no env loading inside the package |
| 8 | `index.ts` exports the public API and nothing else |
| 9 | Tests use the root runner config; `test.env` is harness-only |
| 10 | Tests cover happy path, edge cases, lifecycle, per-feature, per-method, scoped instances |
| 11 | Tests co-located, zero mocks, real execution |
| 12 | `tsconfig.json` matches the workspace convention |
| 13 | `package.json` has correct name, scripts, engines |
| 14 | `SKILL.md` present at the package root |
| 15 | `README.md` has install, quick start, full API, config reference |
| 16 | `code-review` run; `[high]` and `[med]` findings resolved |
| 17 | Every file follows `code-style` |
| 18 | Every test follows `backend-testing` |
