# Naming Conventions

Helper for the `code-style` skill.

## Files

- **Always kebab-case** — lowercase letters separated by hyphens.
- Include a descriptive suffix that reflects the file's role.

| File role | Pattern | Example |
| --------- | ------- | ------- |
| Component | `<name>.component.tsx` | `user-profile.component.tsx` |
| Service | `<name>.service.ts` | `auth.service.ts` |
| Controller | `<name>.controller.ts` | `order.controller.ts` |
| Entity | `<name>.entity.ts` | `user.entity.ts` |
| Port | `<name>.port.ts` or `<name>-repository.port.ts` | `user-repository.port.ts` |
| Adapter | `<name>.adapter.ts` | `postgres-user.adapter.ts` |
| Model / Schema | `<name>.schema.ts` | `product.schema.ts` |
| Route | `<name>.routes.ts` | `payment.routes.ts` |
| Middleware | `<name>.middleware.ts` | `rate-limiter.middleware.ts` |
| Utility / Helper | `<name>.util.ts` | `string.util.ts` |
| Hook | `use-<name>.ts` | `use-auth.ts` |
| Test | `<name>.test.ts` | `auth.service.test.ts` |
| End-to-end spec | `<flow>.spec.ts` | `user-login.spec.ts` |
| Type definitions | `<name>.types.ts` | `user.types.ts` |
| Constants | `constants.ts` or `<name>.constants.ts` | `api.constants.ts` |
| Config | `config.ts` or `<name>.config.ts` | `database.config.ts` |
| Barrel | `index.ts` | `index.ts` |

**Wrong:** `UserProfile.tsx`, `authService.ts`, `Rate_Limiter.middleware.ts`

**Right:** `user-profile.component.tsx`, `auth.service.ts`, `rate-limiter.middleware.ts`

### Where a generator owns the filename

A package whose components are emitted by a UI generator keeps that generator's
layout and casing — `components/ui/button.tsx`, not `button.component.tsx`. Renaming
them produces a conflict on every regeneration. The suffix convention applies to the
files you author around them: the wrapper, its `.types.ts`, its stories.

### Where the repository already disagrees

An existing package that uses a different filename convention throughout keeps it. Do
not convert half a package. Either the whole package moves in one dedicated change, or
it stays as it is and the new file matches its neighbours — a directory with two
conventions is worse than a directory with the wrong one.

## Folders

Always kebab-case. Plural for collections, singular for single-purpose directories.

**Wrong:** `UserComponents/`, `sharedUtils/`, `API_Routes/`

**Right:** `user-components/`, `shared-utils/`, `api-routes/`

## Identifiers

| Identifier | Convention | Example |
| ---------- | ---------- | ------- |
| Class | PascalCase | `UserProfile` |
| Interface / Type | PascalCase, no `I` prefix | `OrderPayload`, `ServerConfig` |
| Public contract of a package | PascalCase with a `Contract` suffix | `MongoDbContract` |
| Private field | `#camelCase` | `#underlyingClient` |
| Variable | camelCase | `orderCount` |
| Boolean | camelCase with `is`/`has`/`should`/`can` | `isLoading`, `hasError` |
| Constant | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Function / Method | camelCase, verb-first | `getUserById`, `createApiServer` |
| React component | PascalCase | `UserProfile` |
| Enum and members | PascalCase | `OrderStatus.Shipped` |
| Environment variable | UPPER_SNAKE_CASE | `DATABASE_URL` |
| Package name | kebab-case, scoped | `<pkg-scope>/schema-validator` |

Repositories that predate this rule often carry an `I` prefix on some interfaces
(`ILogger`, `IRestClient`) alongside unprefixed ones. Do not sweep them. New interfaces
go unprefixed, or take the `Contract` suffix when they are a package's public shape;
an existing prefixed interface is renamed only when something else already requires
touching every one of its call sites.

## Avoid abbreviations

| Avoid | Prefer |
| ----- | ------ |
| `ee` | `eventEmitter` |
| `msg` | `message` |
| `ev` | `event` |
| `cfg`, `conf` | `config` |
| `cb` | `callback` |
| `fn` in loops | `listener`, `handler` |
| `h1`, `h2` | `primaryHandler`, `fallbackHandler` |

**Exceptions**, being established conventions: `req`, `res`, `next` in HTTP handlers;
`err` in a catch block; `id` when clearly an identifier (`clientId`).

## Boolean prefixes

- `is` — state or identity: `isEnabled`, `isLoading`
- `has` — presence: `hasError`, `hasPendingWrites`
- `should` — intent: `shouldRetry`, `shouldValidate`
- `can` — capability: `canEdit`, `canSubmit`

## Type and interface suffixes

| Suffix | Purpose | Example |
| ------ | ------- | ------- |
| `Config` | Configuration object | `ServerConfig` |
| `Options` | Optional settings | `BuildOptions` |
| `Context` | Request or scope context | `RouteContext` |
| `Definition` | Declarative structure | `RouteDefinition` |
| `Handler` | Callback or async handler | `RouteHandler` |
| `Deps` | Dependency container | `SignalHandlerDeps` |
| `Port` | Outbound contract | `UserServicePort` |

## Generic type parameters

Single generic: `T` when the meaning is obvious — `ApiResponse<T>`. Multiple
generics: descriptive names — `TKey`, `TValue`, `TInput`, `TOutput`.

## Test block naming

- `describe` — the function, class, or module under test: `describe("buildTarget", ...)`
- `it` — `"should <expected behavior>"`, describing the outcome rather than the setup

```typescript
describe("normalizePageSize", () => {
  it("should return the default when no size is supplied", () => { ... });
  it("should clamp a size above the maximum", () => { ... });
});
```

---

## Naming skills and agent documents

These rules govern the skill set itself, so that a repository's conventions and its
tooling read the same way.

### Skill names

Format: `<surface>-<concern>`, kebab-case. Surface is `backend`, `frontend`, or
`package`. Concerns applying to every surface take no prefix.

1. **No language or runtime prefixes.** `js-code-style` goes stale the moment the
   repository is TypeScript, and the language is already obvious from the
   description.
2. **No methodology in the name.** `ddd-package-selector` names the technique rather
   than the job. Name the job — `backend-architecture` — and teach the technique
   inside.
3. **No filler nouns.** `-guide`, `-helper`, `-rules`, `-stuff` carry no signal.
   `-checklist` survives only where the artifact genuinely is a checklist.
4. **No abbreviations or numeronyms.** `frontend-a11y` loses against a plain
   "accessibility" query. `docs` stays — it is a word in its own right.
5. **Name the tool when the tool is the subject.** A skill that is entirely about one
   tool's files should say so — someone searching will use the tool's name, not a
   category noun. This is the narrow exception to rule 1, not a licence to prefix.
6. **Prefer symmetry.** `backend-testing`/`frontend-testing` and
   `backend-architecture`/`frontend-architecture` let a reader predict a name before
   finding it.
7. **Folder name, YAML `name:`, and every cross-reference must match exactly.**

### Skill descriptions

The `description` field is the second matching surface, and often the deciding one.
One shape:

```
<When to use it>. <What it enforces>. <Trigger phrases>.
```

Every description names the surface it governs, so two skills never both look like
the right match for one task. State triggers as the phrases a user would actually
type, not as categories.

### Documents that support a skill

- Helper documents live in `helpers/` inside the skill folder and are named for their
  concern alone — `naming-conventions.md`, not `skill-naming-conventions-helper.md`.
- A document generated by a skill is named for its content, not its generator:
  `review.md`, not `code-review-output.md`.
- Hand-authored input and generated output never share a name stem. A reader cannot
  tell which of two `PROJECT-*.md` files is safe to edit, and will eventually edit the
  one that gets overwritten.
