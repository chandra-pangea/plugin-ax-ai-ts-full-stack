# Structure, Control Flow, and Constants

Helper for the `code-style` skill.

## Function documentation

**Every function carries a comment** — one or two lines above it stating what it does
and why. No exceptions, including private helpers and arrow functions assigned to
variables.

Describe **intent and side effects**, not a line-by-line narration of obvious code.

```typescript
// Wrong — no comment
const buildMeta = (context?: string, defaultMeta?: object) => { ... };

// Wrong — narrates the obvious
// Takes context and defaultMeta and returns an object.
const buildMeta = (context?: string, defaultMeta?: object) => { ... };

// Right — states intent
// Merges defaultMeta and request context into the flat shape the transport expects.
const buildMeta = (context?: string, defaultMeta?: object) => { ... };
```

## Classes: keep logic focused

Class methods may hold straightforward logic — null checks, simple transformations,
wiring dependencies together. Complex business logic, heavy calculation, and reusable
transformation belong in standalone helper functions under `helpers/`, called from
the class.

A method should be extracted when it:

1. Exceeds roughly 20 lines,
2. Contains logic that is independently testable, or
3. Would be reused by more than one method or class.

**Acceptable — simple wiring inside the class:**

```typescript
// Builds the client from config and stores it as the active singleton.
static create = async (config?: ClientConfig): Promise<Client> => {
  const timeout = config?.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const client = new Client(buildTransport({ timeout }));
  Client.#instance = client;
  return client;
};
```

**Better for complex setup — delegate to helpers:**

```typescript
// Builds the client singleton from config; heavy setup lives in helpers/.
static create = async (config?: ClientConfig): Promise<Client> => {
  const transports = await buildTransports(config?.transports);
  const metadata = buildMetadata(config?.context, config?.defaultMeta);
  const client = new Client(buildInstance({ config, metadata, transports }));
  Client.#instance = client;
  return client;
};
```

## No nested function definitions

Do not define functions inside other functions. Nested definitions create hidden
coupling through closures and make code harder to read, test, and reuse. Define all
functions at the module's top level and pass shared state explicitly as parameters.

Inline callbacks passed directly to another function — `items.map((item) => item.id)`
— are not nested definitions and are fine.

## Early returns and guard clauses

Use early returns freely for guards and error conditions. This flattens nesting and
makes the happy path obvious. Multiple returns are fine when each marks a distinct,
well-understood exit.

```typescript
// Loads a user by id, rejecting unusable input before touching the datastore.
const getUserById = async (id: string): Promise<User> => {
  if (!id) {
    throw new AppError("id is required", 400);
  }

  const user = await userRepository.findById(id);

  if (!user) {
    throw new AppError("User not found", 404);
  }

  return user;
};
```

## No hardcoded values

Do not hardcode reusable values inline. Any value used in more than one place, or any
value representing a meaningful concept — URLs, limits, timeouts, keys, status codes,
configuration — becomes a named constant.

Constants are:

- Defined at the top of the file, or in a dedicated `constants.ts` / `config.ts`
  module when shared.
- Named in `UPPER_SNAKE_CASE` when they never change at runtime.
- Exported from a constants module and imported where needed, never duplicated.

## String literal unions as constants

When a type is a union of string literals, extract the values into an `as const`
object and derive the union from it. Compare against the constant, never a raw
string.

```typescript
const LOG_LEVEL = {
  DEBUG: "debug",
  INFO: "info",
  WARN: "warn",
  ERROR: "error",
} as const;

type LogLevel = (typeof LOG_LEVEL)[keyof typeof LOG_LEVEL];

// Right
if (level === LOG_LEVEL.DEBUG) { ... }

// Wrong
if (level === "debug") { ... }

export { LOG_LEVEL };
export type { LogLevel };
```

## No emojis

Do not include emojis in code comments, log messages, error messages, console output,
commit messages, or any text produced during code generation.
