# TypeScript Conventions

Helper for the `code-style` skill. For function style, exports, imports, and naming,
see the sibling helpers.

TypeScript is the language of record on every surface. `.js` files are not added to a
TypeScript workspace, `allowJs` is not turned on to avoid converting one, and a type
error is not worked around — it is the tool doing the job it was installed for.

---

## Compiler configuration

The compiler settings are part of the code. A rule this helper states is only real if
the configuration enforces it, and a project that disables a strictness flag has
changed the language for every file in it.

### Strictness baseline

`strict: true` is the floor and is non-negotiable. It turns on no-implicit-`any`,
strict null checks, strict function types, strict property initialization, and
no-implicit-`this`.

Beyond it, these are worth enabling and are ordered by value per unit of pain:

| Option | Catches | Cost |
| ------ | ------- | ---- |
| `noUncheckedIndexedAccess` | `arr[0]` and `record[key]` typed as `T` when the index may not exist — the single most common source of a runtime `undefined` in otherwise strict code | Real. Expect to add `?.` and guards at every index site |
| `noImplicitOverride` | A method that no longer overrides anything because the base renamed it | Near zero |
| `noFallthroughCasesInSwitch` | A missing `break` | Near zero |
| `verbatimModuleSyntax` | A type-only import emitted as a runtime import, and the import cycles that follow | Low — it forces the `import type` this helper already requires |
| `exactOptionalPropertyTypes` | `{ a?: string }` being assigned an explicit `undefined`, which is a different thing from absent | Moderate, and it surfaces genuine bugs at API boundaries |

Turn one on at a time, in its own change, and fix the errors it reveals. Turning on
four at once produces a diff nobody can review and a temptation to turn them all off
again.

**Never disabled to make code compile:** `strict` and any flag under it. If a value's
type is genuinely unknowable, that is what `unknown` plus a narrowing function is for.
`// @ts-ignore` is not a fix — `@ts-expect-error` with a one-line reason is the
supported form, because it fails when the underlying problem is fixed and the
suppression becomes stale.

### One module resolution per workspace

`module` and `moduleResolution` describe the runtime that will execute the output.
They are not style preferences, and they must be answered once per workspace:

| Runtime | `module` | `moduleResolution` | Consequence |
| ------- | -------- | ------------------ | ----------- |
| Node, ESM | `NodeNext` | `NodeNext` | **Relative imports must carry the `.js` extension**, even from a `.ts` file. Node resolves the emitted path, not the source path |
| Bundler (Vite, webpack, tsup) | `ESNext` | `bundler` | No extension needed; the bundler resolves. Do not add `.js` here — it is inert at best and wrong if the file is later moved |
| Legacy | anything | `node` / `node10` | Cannot see `exports` maps. A dependency that ships subpath exports resolves to its fallback or not at all |

**Sibling packages in one workspace must agree.** Four packages built by the same
pipeline with three different `moduleResolution` values is not four local decisions —
it is a workspace where an import that compiles in one package fails in the next, and
where a package writing `./types.js` while set to `node` resolution is relying on a
coincidence.

The tell that this has drifted: a package whose relative imports carry `.js`
extensions while its `moduleResolution` is `node` or `bundler`, or a shared base
config that most packages override rather than extend.

### Configuration inheritance

One base per workspace, extended by every package in it:

```jsonc
// <workspace>/tsconfig.base.json — the settings that define the language
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  }
}
```

```jsonc
// <workspace>/<packages-dir>/<name>/tsconfig.json — paths only
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

A package config that re-states `strict`, `target`, or `moduleResolution` has either
diverged deliberately — in which case say why in a comment — or drifted. Both are
worth a look; the second is far more common.

`skipLibCheck` is the one concession. It is there because a transitive dependency's
`.d.ts` should not be able to break your build, not because your own declarations go
unchecked.

### Project references

Where the build orchestrator compiles packages in dependency order, mirror that graph
in TypeScript: `composite: true` on each package, and a `references` array in the
workspace root config listing every one of them.

```jsonc
{
  "extends": "./tsconfig.base.json",
  "references": [
    { "path": "app" },
    { "path": "packages/<name>" }
  ],
  "include": [],
  "exclude": ["node_modules", "dist"]
}
```

The payoff is incremental builds and an editor that resolves cross-package types to
source rather than to stale `dist` output. The cost is that a new package is not
built until its reference is added — which is why that step is in
`package-checklist`'s gate.

### Declaration output

A package that ships types declares them and emits them:

- `declaration: true`, and `declarationMap: true` so consumers can jump to source.
- `types` in `package.json` pointing at a path the build actually writes.
- Tests excluded from the build, so `dist/` holds no `*.test.d.ts`.

A `types` field aimed at a directory the compiler never produces fails only in a
consumer, at import time, with an error that names neither the package nor the
setting.

---

## Interface vs type

- **Interface** — object shapes that may be extended or implemented.
- **Type** — unions, intersections, mapped types, and aliases.

**Package boundary rule:**

- `src/interfaces.ts` holds only public abstract contracts consumed outside the
  module or package.
- `src/types.ts` holds internal implementation shapes, DTO and config shapes, adapter
  typings, and aliases not required as public contracts.

```typescript
interface AppConfig {
  port?: number;
  envPath?: string;
}

type RouteHandler = (context: RouteContext) => Promise<void>;
type Nullable<T> = T | null;

export type { AppConfig, RouteHandler, Nullable };
```

## Type-only imports and exports

Always `import type` and `export type` for anything used only in a type position.

This is not cosmetic. Under `isolatedModules` — which every bundler-driven build sets
— the compiler transpiles one file at a time and cannot see whether an imported name
is a type. A value import of a type-only name survives into the output as a real
`import`, which drags the module in at runtime and can produce an import cycle that
exists in neither file's source.

```typescript
// Wrong — `User` is a type, but this emits a runtime import of the module
import { User, createUser } from "./user";

// Right
import type { User } from "./user";

import { createUser } from "./user";
```

## Derive types from values, do not repeat them

A literal list and a union describing it will drift. Write the value once, constrain
it with `satisfies`, and derive the type:

```typescript
type ColorTheme = "blue" | "slate";

const COLOR_THEMES = [
  { value: "blue", label: "Blue" },
  { value: "slate", label: "Slate" },
] as const satisfies ReadonlyArray<{ value: ColorTheme; label: string }>;

type ColorThemeOption = (typeof COLOR_THEMES)[number];

export { COLOR_THEMES };

export type { ColorTheme, ColorThemeOption };
```

`as const` freezes the literals; `satisfies` checks them against the contract
**without widening them** to it. `const X: T = …` would type-check the same value and
then throw away exactly the literal information the derived type needs.

## No `enum`

Use an `as const` object and a derived union. A TypeScript `enum` emits a runtime
object, is not erasable, has no place in a `.d.ts` a consumer can tree-shake, and
numeric enums accept any number.

```typescript
// Wrong
enum Status { Active, Archived }

// Right
const STATUS = { active: "active", archived: "archived" } as const;

type Status = (typeof STATUS)[keyof typeof STATUS];
```

## Exhaustiveness

When branching over a union, make the compiler prove the branches are complete. The
`never` assignment fails the moment a new member is added to the union — which is the
one moment anyone needs to be told.

```typescript
// Fails to compile if a Status member is added without a branch here.
const describe = (status: Status): string => {
  switch (status) {
    case "active":
      return "Active";
    case "archived":
      return "Archived";
    default: {
      const unreachable: never = status;
      throw new Error(`Unhandled status: ${String(unreachable)}`);
    }
  }
};
```

## Narrow at the boundary

Every value entering the program from outside it — a request body, a response, a
parsed file, `localStorage`, an environment value — is `unknown` until something
proves otherwise.

```typescript
// Wrong — a lie that the compiler will happily believe, and propagate
const order = (await response.json()) as Order;

// Right — a check that fails where the bad data entered
const order = orderSchema.parse(await response.json());
```

Where a schema library is overkill, write a type predicate. It carries the same
guarantee and is greppable:

```typescript
// Narrows an unknown value to Order, checking the fields the caller relies on.
const isOrder = (value: unknown): value is Order => {
  return (
    typeof value === "object" &&
    value !== null &&
    "id" in value &&
    typeof (value as { id: unknown }).id === "string"
  );
};
```

A predicate is an assertion you are responsible for. Check the fields you claim to
check — a predicate that returns `true` unconditionally is worse than a cast, because
it looks validated.

## Prefer `unknown` over `any`

`any` disables checking silently and spreads through call sites. `unknown` forces a
narrowing decision at the boundary where the value enters.

```typescript
// Wrong
const parsePayload = (raw: any): Order => raw;

// Right
const parsePayload = (raw: unknown): Order => {
  return orderSchema.parse(raw);
};
```

The same applies to `as`. A type assertion tells the compiler to stop checking; it
does not convert anything. `as unknown as T` is that with the safety rail removed —
reach for it only across a genuine boundary the type system cannot express, and say
why in a comment.

## Null safety

Reach for `!` only when you can state why the value cannot be undefined, and put that
reason in the function comment. Prefer a shape that makes the question unnecessary:

```typescript
const items: string[] = [];

// Wrong — throws at runtime on an empty list, and type-checks without
// noUncheckedIndexedAccess
const first = items[0].toUpperCase();

// Right — handles the absence regardless of how the project is configured
const first = items[0]?.toUpperCase() ?? DEFAULT_LABEL;
```

Write index access defensively even where `noUncheckedIndexedAccess` is off. The
optional chain costs nothing, and it is what lets the flag be turned on later without
a hundred-file change.

## Error handling

Use custom error classes for domain errors, and map them to transport-level responses
at the channel boundary — never inside a service.

```typescript
class AppError extends Error {
  statusCode: number;
  code?: string;

  constructor(message: string, statusCode = 500, code?: string) {
    super(message);
    this.name = "AppError";
    this.statusCode = statusCode;
    this.code = code;
  }
}

export { AppError };
```

Throwing sites carry context:

```typescript
if (!user) {
  throw new AppError(`User ${userId} not found`, 404, "USER_NOT_FOUND");
}
```

Catch blocks narrow before using the error. `catch (err)` binds `unknown` under
`useUnknownInCatchVariables`, which `strict` enables — so narrowing is not optional:

```typescript
try {
  await service.charge(orderId);
} catch (err) {
  if (err instanceof AppError) {
    return respondWithError(err);
  }

  throw err;
}
```

Rethrow what you did not handle. A `catch` that swallows every error turns a
recoverable failure into silence.

## Generics

Full treatment in [`generics.md`](generics.md). The three rules that matter most:

1. **A type parameter is used at least twice** — once to receive a type, once to
   relate it to something. One occurrence constrains nothing.
2. **A parameter appearing only in the return position is an unchecked cast.** It is
   how a codebase reacquires `any` after banning it. Either return `unknown`, or take
   an argument that validates and let the parameter be inferred from it.
3. **Every parameter is constrained** to what the body actually requires, so the error
   lands at the call site rather than inside the implementation.

```typescript
// Factories are arrow functions, per arrow-functions.md.
const createResponse = <TData,>(data: TData): ApiResponse<TData> => {
  return { data, error: null };
};

type ApiResponse<TData = unknown> = { data: TData | null; error: string | null };
```

The trailing comma in `<TData,>` is required in `.tsx`, where `<TData>` parses as a
JSX tag.

## Strict mode

Assume `strict: true`. Code that only compiles with a strictness flag disabled does
not ship, and neither does code that compiles because of a suppression comment with
no stated reason.
