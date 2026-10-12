---
name: backend-architecture
description: "MANDATORY before writing any backend code. Decides where code belongs — technical and reusable code becomes a shared package, business and domain logic becomes an application module — then enforces the hexagonal layout (entities, domain, ports, schemas, service, channels, infrastructure, shared). Triggers on add a feature, build X, create a service, add an endpoint, new module, refactor service, integrate a third party."
metadata:
  version: "2.0"
---

# Backend Architecture

Two jobs: route new code to the right place, then enforce the layout once it is
there. Read this before writing backend code, not after.

## Resolving project conventions

Values in angle brackets come from the project's stack profile. Resolve them in this
order:

1. Read `STACK-PROFILE.md` at the repo root and use its values verbatim.
2. If it is absent or a key is missing, infer from the repo:
   - `pkg-scope`, `pkg-prefix` — an existing package's `package.json` name and its
     folder name; these are independent, so read both
   - `packages-dir`, `app-dir` — workspace globs in `pnpm-workspace.yaml` or
     `package.json#workspaces`
   - `http-framework`, `db` — dependencies in the application's `package.json`
3. If still unresolved, match the dominant convention already present in the repo.
4. Only when the repo is empty, fall back to this skill's stated default — then write
   the chosen values into `STACK-PROFILE.md`.

Never invent a new convention when the repo already expresses one.

**Package name and folder path are different things.** A package named
`<pkg-scope>/logger` lives at `<packages-dir>/<pkg-prefix>logger/`. Never write the
scope into a path.

---

## Mandatory application layout

Every module inside `<app-dir>/src/` follows this structure.

```
<app-dir>/src/
├── <module>/              # Bounded context (user, order, billing)
│   ├── entities/          # Core types; no framework
│   ├── domain/            # Events, invariants, errors (optional)
│   ├── ports/             # Outbound interfaces
│   ├── schemas/           # Validation schemas for storage and API (optional)
│   ├── service/           # Application services and use cases
│   └── index.ts
├── channels/http/         # HTTP routes (user.routes.ts, order.routes.ts)
├── infrastructure/        # Connection pools, HTTP clients, external SDKs
├── shared/                # Cross-module utilities
└── index.ts
```

| Need | Add to |
| ---- | ------ |
| New entity | `<module>/entities/` |
| Domain event | `<module>/domain/` |
| Outbound contract | `<module>/ports/` |
| Use case | `<module>/service/` |
| Validation schema | `<module>/schemas/` |
| HTTP endpoint | `channels/http/` |
| Datastore or external client | `infrastructure/` |
| Cross-module utility | `shared/` |

**Enforcement:**

- No `helpers/` folder at a module root — internal helpers live inside `service/`.
- No framework imports in `entities/` or `ports/`.
- Services import from `infrastructure/`, never from `channels/`.
- Every module has an `index.ts` exporting only its public API.
- `shared/` never holds domain logic.

---

## Step 1: package or module?

| If the code is… | It belongs in… |
| --------------- | -------------- |
| **Technical** — reusable now or plausibly later, with no product rules or domain entities | `<packages-dir>/` as `<pkg-scope>/*` |
| **Business** — product rules, workflows, domain language, entities tied to this product | `<app-dir>/src/<module>/` |

```
┌──────────────────────────────────────────────────────────────┐
│ Is this technical code we could reuse, with no domain        │
│ entities and no business rules shipped inside it?            │
└──────────────────────────────────────────────────────────────┘
         YES ↓                        NO ↓
    ┌─────────────┐            ┌─────────────────┐
    │ Package     │            │ Domain module   │
    └─────────────┘            └─────────────────┘
         ↓                            ↓
  Search <packages-dir>        Search <app-dir>/src
  for an existing match        for an existing module
```

### Technical code → a shared package

Libraries, adapters, algorithms, infrastructure clients, formatting, validation
primitives. Capabilities that typically become packages:

- structured logging
- cache or session store access
- database connection pooling
- token minting and verification
- error shape normalization
- rate limiting
- secrets retrieval
- distributed tracing
- schema validation
- HTTP server bootstrap and middleware

A package qualifies when **all** of these hold:

- **No domain entities.** No `User`, `Order`, or `Invoice` as business concepts.
- **Framework-agnostic** where practical. Adapters may target a specific framework,
  but the core stays portable.
- **Reusable** across features or services. One-off glue with no plausible reuse
  stays in the application, under `shared/` or inside a module.
- **Defined by a technical problem** — logging, storage, parsing — not a business one.

### Business code → a domain module

Rules, workflows, and data belonging to this product, expressed in domain language.

Characteristics:

- Holds domain entities and business rules.
- The service layer encodes use cases and policies.
- Ports define outbound contracts; `channels/http/` exposes the API.
- **Consumes** packages for technical building blocks rather than reimplementing them.

## Step 2: does it already exist?

### For a package

```bash
# From the repo root
grep -rl "\"name\": \"<pkg-scope>/" <packages-dir>/*/package.json
ls <packages-dir>
```

**Found:** add it to the application's dependencies, import it, stop here.

**Not found, but something covers 80% of the need:** extend that package. A near-
duplicate package is worse than a slightly broader one.

**Not found:** create it — see the `package-scaffold` skill.

### For a module

```bash
ls -d <app-dir>/src/*/
```

**Found:** add the capability to that module's service and port, staying inside its
boundaries.

**Not found:** create the module using the layout above.

## Step 3: layout and contracts

Only for domain modules. Packages follow `package-scaffold`.

```
<app-dir>/src/<module>/
├── entities/
│   └── <name>.entity.ts        # Core domain types; no framework, no infrastructure
├── domain/
│   ├── events/                 # optional
│   └── <name>.error.ts         # optional domain errors and invariants
├── ports/
│   └── <name>-service.port.ts  # Outbound interface the service implements
├── schemas/
│   └── <name>.schema.ts        # Storage or API shape validation
├── service/
│   ├── <name>.service.ts       # Application service
│   └── <name>.service.test.ts  # Integration tests against real infrastructure
└── index.ts                    # Public exports: entity, port, service
```

### Dependency direction

```
channels/http/            imports entities, ports, and the module barrel
    ↓
service/                  imports entities, ports, schemas, infrastructure
    ↓
entities/ + ports/        import types only; no framework
    ↓
infrastructure/           imports drivers and SDKs
    ↓
<packages-dir>/<pkg-prefix>*
```

Framework code stays in `channels/http/` and `infrastructure/`. It never reaches
entities, ports, or services.

### What each file does

| File | Exports | Notes |
| ---- | ------- | ----- |
| `entities/<name>.entity.ts` | Plain types and interfaces | No external imports; serializable |
| `ports/<name>-service.port.ts` | Interface plus error types | Contract only, no implementation |
| `service/<name>.service.ts` | Class plus factory | Implements the port; `close()` if stateful |
| `schemas/<name>.schema.ts` | Validation schemas | Storage shape or API input, kept apart from entities |
| `index.ts` | Re-exports entity, port, service | Consumers import only from here |

### Worked example

**`entities/user.entity.ts`**

```typescript
type User = {
  id: string;
  email: string;
  name: string;
};

export type { User };
```

**`ports/user-service.port.ts`**

```typescript
import type { User } from "../entities/user.entity";

type CreateUserInput = {
  email: string;
  name: string;
};

type UserServicePort = {
  getById: (userId: string) => Promise<User>;
  create: (input: CreateUserInput) => Promise<User>;
};

class UserNotFoundError extends Error {
  constructor(userId: string) {
    super(`User ${userId} not found`);
    this.name = "UserNotFoundError";
  }
}

export { UserNotFoundError };

export type { UserServicePort, CreateUserInput };
```

**`ports/user-repository.port.ts`**

The service depends on this, not on a driver. Swapping the datastore changes only the
adapter in `infrastructure/`.

```typescript
import type { User } from "../entities/user.entity";

type UserRepositoryPort = {
  findById: (userId: string) => Promise<User | null>;
  insert: (user: User) => Promise<void>;
};

export type { UserRepositoryPort };
```

**`service/user.service.ts`**

```typescript
import type { User } from "../entities/user.entity";
import type { UserRepositoryPort } from "../ports/user-repository.port";
import type { CreateUserInput, UserServicePort } from "../ports/user-service.port";

import { randomUUID } from "node:crypto";

import { UserNotFoundError } from "../ports/user-service.port";

class UserService implements UserServicePort {
  static #instance: UserService | null = null;

  #repository: UserRepositoryPort;

  private constructor(repository: UserRepositoryPort) {
    this.#repository = repository;
  }

  // Builds the service against a repository adapter and stores it as the singleton.
  static create = (repository: UserRepositoryPort): UserService => {
    const service = new UserService(repository);
    UserService.#instance = service;
    return service;
  };

  // Returns the initialized service, failing loudly if wiring was skipped.
  static getInstance = (): UserService => {
    if (UserService.#instance === null) {
      throw new Error("UserService not initialized. Call UserService.create() first.");
    }

    return UserService.#instance;
  };

  // Loads a user, translating absence into a domain error the channel can map.
  getById = async (userId: string): Promise<User> => {
    const user = await this.#repository.findById(userId);

    if (user === null) {
      throw new UserNotFoundError(userId);
    }

    return user;
  };

  // Creates a user with a generated identifier and persists it.
  create = async (input: CreateUserInput): Promise<User> => {
    const user: User = { id: randomUUID(), ...input };
    await this.#repository.insert(user);
    return user;
  };
}

export { UserService };
```

**`index.ts`**

```typescript
import { UserService } from "./service/user.service";
import { UserNotFoundError } from "./ports/user-service.port";

import type { User } from "./entities/user.entity";
import type { UserServicePort } from "./ports/user-service.port";

export { UserService, UserNotFoundError };

export type { User, UserServicePort };
```

**`channels/http/user.routes.ts`** — the only layer that knows about HTTP.

```typescript
import type { Router } from "<http-framework>";

import { UserNotFoundError, UserService } from "../../user";

// Maps domain errors onto status codes; no business logic lives here.
const registerUserRoutes = (router: Router): void => {
  router.get("/users/:id", async (req, res, next) => {
    try {
      const user = await UserService.getInstance().getById(req.params.id);
      res.json(user);
    } catch (err) {
      if (err instanceof UserNotFoundError) {
        res.status(404).json({ error: err.message });
        return;
      }

      next(err);
    }
  });
};

export { registerUserRoutes };
```

## Step 4: enforcement checklist

**Structure**

- [ ] Folder structure matches the template
- [ ] No framework imports in entities, ports, or services
- [ ] `index.ts` exports entity, port, and service — nothing internal
- [ ] Boundary defined by a port (module) or `interfaces.ts` (package)

**Dependencies**

- [ ] `package.json` lists only what is used
- [ ] Service depends on ports, infrastructure, and packages — nothing else
- [ ] Routes import from the module barrel and infrastructure only
- [ ] No circular imports between routes and services

**Contracts**

- [ ] The port states what the service must implement; the service implements it exactly
- [ ] Entity types are serializable — no class instances in exported types
- [ ] Errors are custom classes extending `Error`, thrown with context

**Testing**

- [ ] Happy path and error path covered
- [ ] No mocks; real datastore and real dependencies
- [ ] Test environment supplies every required value
- [ ] Tests runnable in isolation

**Docs**

- [ ] Package README has install, quick start, exports, and an API table
- [ ] No unresolved `[high]` or `[med]` review findings

## Scaffolding a module

```bash
mkdir -p <app-dir>/src/<module>/{entities,ports,schemas,service}
touch <app-dir>/src/<module>/entities/<name>.entity.ts
touch <app-dir>/src/<module>/ports/<name>-service.port.ts
touch <app-dir>/src/<module>/schemas/<name>.schema.ts
touch <app-dir>/src/<module>/service/<name>.service.ts
touch <app-dir>/src/<module>/index.ts
```

Then implement entities, ports, service, schemas, and routes, and co-locate
`*.test.ts` integration tests against real infrastructure.

## Anti-patterns

| Anti-pattern | Why it is wrong | Instead |
| ------------ | --------------- | ------- |
| Framework imports in a service | The service becomes framework-specific and untestable outside HTTP | Import types only; pass what the service needs as parameters |
| Service depends on a driver directly | The datastore cannot be swapped or substituted in tests | Inject through a repository port |
| No port, free-form service | No contract, so refactors break callers silently | Define the port first |
| Entity with behavior | Domain logic hides inside a type and cannot be tested | Entities are data; logic lives in the service |
| Entity and schema merged | The validation schema becomes public API and storage cannot evolve independently | Entity for the domain, schema for storage and API |
| Circular imports between routes and service | Build and type resolution break | Routes → service → port, one direction only |
| Environment variables read inside a package | The package becomes unusable in another application | The application reads config and passes it in |

## When to use this skill

**Use it when:** adding a feature or module, creating technical code that may become a
package, unsure whether something is technical or business, integrating a third
party, or refactoring existing code into a module.

**Skip it when:** adding a small helper to an existing service, or fixing a bug in
place.

## Related skills

- **`package-scaffold`** — building the package this skill routes you to
- **`package-checklist`** — validating that package before a pull request
- **`backend-testing`** — the test strategy the checklist above assumes
- **`code-style`** — function style, naming, imports, and the build standards helper
