# Exports and Imports

Helper for the `code-style` skill.

## Consolidated exports

Gather **all** exports into a single export block at the **end** of the file. Do not
use inline `export` on individual declarations.

**Wrong:**

```typescript
export const PORT = 3000;

export const startServer = () => { ... };

export class AppServer { ... }
```

**Right:**

```typescript
const PORT = 3000;

const startServer = () => { ... };

class AppServer { ... }

export { PORT, startServer, AppServer };
```

This holds for React components and hooks too — a component file ends with
`export { UserCard };`, not `export function UserCard`.

For default exports, prefer a named export block. When a default is genuinely
required — a framework's page or layout convention, for instance — place it at the
bottom alongside the named exports:

```typescript
const HomePage = () => { ... };

export default HomePage;
```

## Separate type exports and imports

Always use `export type` for type-only exports and `import type` for type-only
imports. Never mix runtime values and types in the same statement.

**Wrong:**

```typescript
import { UserService, UserProfile } from "./user.service";
//       ^ runtime       ^ type — mixed together

export { UserService, UserProfile };
```

**Right:**

```typescript
import { UserService } from "./user.service";
import type { UserProfile } from "./user.types";

export { UserService };
export type { UserProfile };
```

This enables tree-shaking and makes the boundary between runtime and compile-time
artifacts explicit. It also means `verbatimModuleSyntax` and `isolatedModules` behave
predictably.

## Import ordering

Imports appear in this order, with a blank line between groups:

1. **Type imports** (`import type { ... }`) — all type-only imports, regardless of source.
2. **Library imports** — third-party and built-in packages.
3. **Local imports** — project-relative paths (`./`, `../`, or an alias such as `@/`).

Within each group, order by path proximity: siblings (`./`) first, then parents
(`../`), then deeper ancestors.

```typescript
import type { RequestHandler } from "express";
import type { User } from "./user.types";

import { randomUUID } from "node:crypto";
import express from "express";

import { normalizeInput } from "./normalize-input.util";
import { AppError } from "../shared/app-error";
```

## Barrel files

An `index.ts` re-exports a module's public surface and nothing else.

```typescript
import { UserService } from "./service/user.service";

import type { User } from "./entities/user.entity";
import type { UserServicePort } from "./ports/user-service.port";

export { UserService };

export type { User, UserServicePort };
```

Do not re-export internal helpers from a barrel. If a consumer needs a helper, it
belongs in the public surface deliberately, not by accident of a wildcard export.
Avoid `export *` — it makes the public API impossible to read at a glance and defeats
the point of having a barrel.
