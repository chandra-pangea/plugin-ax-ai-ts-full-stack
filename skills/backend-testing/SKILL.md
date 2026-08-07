---
name: backend-testing
description: "Use when generating, reviewing, or refactoring any backend or shared-package test. Enforces zero mocking and real execution against a dedicated test database, co-located spec files, explicit assertions, and full coverage categories (happy path, edge cases, lifecycle, per-feature, per-method, scoped instances). Triggers on write tests, add coverage, fix failing test, test this service."
metadata:
  version: "2.0"
---

# Backend Testing

Covers services, shared packages, and anything else running on the server. UI flows
are owned by the `frontend-testing` skill — this skill does not duplicate its rules.

## Resolving project conventions

Values in angle brackets come from the project's stack profile. Resolve them in this
order:

1. Read `STACK-PROFILE.md` at the repo root and use its values verbatim.
2. If it is absent or a key is missing, infer from the repo:
   - `test-runner` — devDependencies plus config files (`jest.config.*`, `vitest.config.*`)
   - `db`, `test-db-url` — the application's dependencies and any existing test setup file
   - `pkg-manager` — which lockfile exists
3. If still unresolved, match the dominant convention already present in the repo.
4. Only when the repo is empty, fall back to this skill's stated default — then write
   the chosen values into `STACK-PROFILE.md`.

Never invent a new convention when the repo already expresses one.

| Surface | Tool | Location |
| ------- | ---- | -------- |
| Services and packages | `<test-runner>` | Co-located `*.test.ts` beside the source |
| UI flows | Playwright | `<e2e-dir>/*.spec.ts` — see `frontend-testing` |

There is exactly one end-to-end directory in the repository, `<e2e-dir>`, and
`frontend-testing` defines what goes in it.

---

## Zero mocking

Do not use mocks, stubs, spies, or any test double.

```typescript
// All of these are disallowed
jest.mock("./user.service");
jest.spyOn(service, "findUser");
vi.mock("../lib/mailer");
sinon.stub(db, "query");
```

If a test feels like it needs a mock, either the code under test needs refactoring —
usually an injected port it does not yet have — or the test should be written as a
broader integration test that exercises the real dependency.

### The one carve-out: injecting faults you cannot otherwise produce

Some error paths cannot be triggered against healthy infrastructure — a socket reset
mid-request, a provider returning a 503, a timeout. Injecting that fault at the
process boundary is permitted, because it substitutes the *environment*, not the code
under test.

```typescript
// Allowed — the failure is injected at the network boundary
it("should wrap an upstream timeout in a typed error", async () => {
  await withUnreachablePort(async (port) => {
    const client = PaymentClient.create({ baseUrl: `http://127.0.0.1:${port}` });
    await expect(client.charge(chargeInput)).rejects.toBeInstanceOf(UpstreamError);
  });
});
```

```typescript
// Not allowed — this replaces the code under test
jest.spyOn(paymentClient, "charge").mockRejectedValue(new UpstreamError());
```

The distinction: you may make the world fail. You may not make your own function
lie about what it does.

## Real execution

Every test calls the actual implementation and all of its dependencies. No fake or
in-memory replacement for a database, cache, queue, or service you control.

**Wrong:**

```typescript
const fakeRepository = { findById: () => Promise.resolve(fakeUser) };
const service = UserService.create(fakeRepository);
const result = await service.getById("123");
```

**Right:**

```typescript
const service = UserService.create(userRepository);
const result = await service.getById(testUserId);
```

The test environment must provide those real dependencies — typically a dedicated
test database at `<test-db-url>`, seeded with known data. Never the development
database.

An adapter written specifically for testing is not a mock if it is a real
implementation of the port with its own tests — an in-memory repository that genuinely
stores and retrieves is a legitimate adapter. A bare object literal returning canned
values is not.

## Unit tests are functional integration tests

Because tests run against a dedicated database:

- Side effects are permitted — create, update, and delete freely.
- Tests set up their own preconditions and clean up after themselves.
- Order must not matter; every test is independently runnable.

```typescript
describe("OrderService", () => {
  let orderId: string;

  beforeAll(async () => {
    await seedTestData();
  });

  afterAll(async () => {
    await cleanupTestData();
  });

  it("should create an order in the pending state", async () => {
    const order = await orderService.createOrder(validOrderPayload);
    orderId = order.id;
    expect(order.status).toBe("pending");
  });

  it("should retrieve the order that was created", async () => {
    const order = await orderService.getOrderById(orderId);
    expect(order.id).toBe(orderId);
  });
});
```

## File conventions

- Co-located with the source, in the same directory.
- Named `<source-file-name>.test.ts`.
- One test file per source module.

```
service/
  user.service.ts
  user.service.test.ts
  order.service.ts
  order.service.test.ts
```

## Assertions

- Explicit assertions over snapshots.
- Assert on specific properties rather than whole objects.
- Test names state the expected behavior.

**Wrong:**

```typescript
it("works", async () => {
  const result = await doSomething();
  expect(result).toMatchSnapshot();
});
```

**Right:**

```typescript
it("should return the user email when given a valid id", async () => {
  const result = await getUserById(testUserId);
  expect(result.email).toBe("alice@example.com");
});
```

## One variable for input and expectation

When a test compares what it passed in against what it asserts on, use a single
variable. This removes the drift between the two.

**Wrong:**

```typescript
it("should persist the log message", async () => {
  logger.info("logger persistence test message");
  await logger.close();
  const records = await collection.findAll();
  expect(records.find((r) => r.msg === "logger persistence test message")).toBeDefined();
});
```

**Right:**

```typescript
it("should persist the log message", async () => {
  const message = "logger persistence test message";
  logger.info(message);
  await logger.close();
  const records = await collection.findAll();
  expect(records.find((record) => record.msg === message)).toBeDefined();
});
```

## Coverage categories

Plan which categories apply before writing anything, and list the specific cases.

### Happy path

The normal, successful flow.

```typescript
it("should create a logger with a console transport and emit a message", async () => { ... });
it("should insert a record and return its identifier", async () => { ... });
```

### Edge cases and error paths

Boundaries, invalid input, missing config, failures.

```typescript
it("should throw when getInstance() is called before create()", () => { ... });
it("should reject with a typed error when the datastore is unreachable", async () => { ... });
it("should handle an empty string without throwing", async () => { ... });
```

### Lifecycle

For anything using the singleton and factory pattern:

- `create()` initializes and stores the instance
- `getInstance()` returns that same instance
- `getInstance()` throws before `create()`
- `close()` flushes, cleans up, and clears the singleton
- `create()` after `close()` reinitializes cleanly

### Per feature, transport, or adapter

Each one gets its own `describe` block with at minimum a happy path and one error
case.

```typescript
describe("console transport", () => {
  it("should write to stdout", () => { ... });
});

describe("database transport", () => {
  it("should write a record to the collection", async () => { ... });
  it("should reconnect after a dropped connection", async () => { ... });
});
```

### Per method

Each public method gets its own `it` block. Do not bundle several calls into one
end-to-end test and call it coverage.

```typescript
// Wrong
it("should work end to end", async () => { ... });

// Right
it("should create with the default level", async () => { ... });
it("should emit at the requested level", async () => { ... });
it("should flush pending writes on close()", async () => { ... });
```

### Function-level matrix

For every public function and every significant helper, write both a happy-path test
and an issue-path test — invalid input, a boundary, or a dependency failure.

When the happy path needs external infrastructure that is not always available, keep
it as an opt-in integration test guarded by an environment variable rather than
dropping the coverage.

### Scoped instances

When a package supports child or request-scoped instances:

- the child inherits parent configuration,
- child bindings do not leak into the parent,
- the parent's lifecycle does not break child usage.

## Summary

| Rule | Requirement |
| ---- | ----------- |
| Mocking | Never — except injecting environment faults at the process boundary |
| Execution | Real implementations against real dependencies |
| Tool | `<test-runner>`, co-located `*.test.ts` |
| Database | Dedicated test database at `<test-db-url>`, never the development one |
| Side effects | Permitted |
| Isolation | Every test independently runnable |
| Assertions | Explicit and property-level; no snapshots |
| Input and output | One variable for both |
| Happy path | Always |
| Edge cases | Always — invalid input, missing config, error paths |
| Lifecycle | Full cycle covered where the pattern applies |
| Per feature | Each transport or adapter in its own describe block |
| Per method | Each public method in its own it block |
| Scoped instances | Covered where supported |
| UI flows | Out of scope — see `frontend-testing` |
