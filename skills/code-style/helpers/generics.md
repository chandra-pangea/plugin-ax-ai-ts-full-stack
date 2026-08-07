# Generics

Helper for the `code-style` skill. For compiler configuration, narrowing, and error
types, see [`typescript-conventions.md`](typescript-conventions.md).

A generic is a relationship between types that the compiler enforces. Anything that
does not express such a relationship is not a generic — it is a cast wearing angle
brackets, and it is worse than a cast because it looks checked.

---

## 1. A type parameter must be used at least twice

Once to receive a type, once to relate it to something. A parameter that appears
exactly once in a signature constrains nothing.

```typescript
// Not a generic. The caller names T, nothing verifies it, and the body cannot
// do anything with a value it knows nothing about.
const parse = <T>(raw: string): T => JSON.parse(raw) as T;

// A generic. TValue appears in the input and in the output, so the compiler
// enforces the relationship between them.
const first = <TValue>(items: readonly TValue[]): TValue | undefined => {
  return items[0];
};
```

Counting the occurrences is the fastest review heuristic there is. One occurrence in
the return position, and the caller is choosing a type the function never checks.

## 2. A type parameter only in the return position is an unchecked cast

This is the most common way a codebase acquires `any` after banning it.

```typescript
// The shape of a network response is not knowable at compile time. This
// signature claims otherwise, and every caller inherits the claim.
interface RestClient {
  get<T>(path: string): Promise<T>;
}

const user = await client.get<User>("/me"); // `user` is a User because we said so
```

Nothing at runtime checks the response. If the endpoint changes, every call site
keeps compiling and fails somewhere later, far from the cause, with a message about a
property of `undefined`.

Two honest alternatives:

```typescript
// A. Return unknown and make the caller narrow. Blunt, and the type system
//    stays truthful.
interface RestClient {
  get(path: string): Promise<unknown>;
}

// B. Take a parser. TData is now *inferred from a runtime value that does the
//    checking*, so the type and the check cannot drift apart.
interface RestClient {
  get<TData>(path: string, parse: (raw: unknown) => TData): Promise<TData>;
}

const user = await client.get("/me", userSchema.parse); // TData inferred as User
```

Option B is the pattern to reach for. The type parameter earns its place because it
appears in an argument *and* the return, and the argument is the thing that makes the
return type true.

Where an existing client already exposes the `get<T>` shape, do not spread it further:
wrap the call in a typed function that validates once, and have features use that.

## 3. Constrain every type parameter

An unconstrained parameter can do nothing but be passed along. `extends` states the
requirement, and moves the error to the call site where it can be fixed.

```typescript
// Wrong — the body cannot touch `entity`, so the constraint lives in a comment
// or nowhere at all.
const save = <TEntity>(entity: TEntity): Promise<void> => { … };

// Right — the requirement is in the signature, and calling it with the wrong
// thing fails at the call, not inside the implementation.
const save = <TEntity extends { id: string }>(entity: TEntity): Promise<void> => { … };
```

`keyof` constraints are how a generic stays honest about property access:

```typescript
// Reads one property, preserving the exact type of that property.
const pluck = <TSource, TKey extends keyof TSource>(
  source: TSource,
  key: TKey
): TSource[TKey] => {
  return source[key];
};

const port = pluck(config, "port"); // number, not string | number | undefined
```

Without the `extends keyof`, this needs an index signature or a cast, and the return
type collapses to a union of every property type.

## 4. Let inference work; explicit type arguments are a smell

A well-formed generic is called without angle brackets.

```typescript
first([1, 2, 3]);        // TValue inferred as number
first<number>([1, 2, 3]); // noise
```

If call sites *must* pass explicit type arguments for the code to be correct, the type
parameter is not inferable from the arguments — which usually means it appears only in
the return position, and rule 2 applies.

Where inference picks something wider than intended, `NoInfer` blocks a position from
participating rather than forcing every caller to annotate:

```typescript
// The default is checked against TValue, but does not widen it.
const withFallback = <TValue>(
  items: readonly TValue[],
  fallback: NoInfer<TValue>
): TValue => {
  return items[0] ?? fallback;
};
```

## 5. Name type parameters for what they carry

`T` is acceptable when there is exactly one and its meaning is obvious. Past that,
single letters stop being shorthand and start being a puzzle.

| Count | Convention |
| ----- | ---------- |
| One, obvious | `T` |
| Two or more | Descriptive, `T`-prefixed: `TEntity`, `TKey`, `TResult`, `TConfig` |

`Repository<TEntity, TId>` reads; `Repository<T, U>` requires looking up which is
which every time.

## 6. Defaults are `unknown`, never `any`

```typescript
// Wrong — every consumer that omits the argument silently opts out of checking.
interface SecretManagerFactory<Config = any> { … }

// Right — omitting the argument forces a narrowing decision instead of skipping one.
interface SecretManagerFactory<Config = unknown> { … }
```

## 7. Give conditional and mapped types a name

An inline conditional type in a signature is unreadable at the call site and
unhoverable in an editor. Name it, and the name documents the intent.

```typescript
type Nullable<T> = T | null;
type RequiredFields<T, K extends keyof T> = T & Required<Pick<T, K>>;
type AsyncReturn<T extends (...args: never[]) => Promise<unknown>> =
  Awaited<ReturnType<T>>;
```

Prefer the built-ins — `Partial`, `Required`, `Pick`, `Omit`, `Record`, `Readonly`,
`Awaited`, `ReturnType`, `Parameters` — over hand-rolled equivalents. A reader already
knows what they mean.

## 8. Generic ports and repositories

The backend's ports are where generics pay for themselves: one contract, many
entities, and the compiler checking each adapter against it.

```typescript
interface Repository<TEntity extends { id: TId }, TId = string> {
  findById(id: TId): Promise<TEntity | null>;
  save(entity: TEntity): Promise<TEntity>;
  delete(id: TId): Promise<void>;
}

export type { Repository };
```

```typescript
// The adapter fixes the parameters; nothing generic leaks past this point.
class MongoUserRepository implements Repository<User> {
  async findById(id: string): Promise<User | null> { … }
  async save(entity: User): Promise<User> { … }
  async delete(id: string): Promise<void> { … }
}
```

Stop generalizing at the port. A service that is itself generic over its entity is
almost always a sign the business logic has been abstracted past the point where it
says anything.

## 9. Generic components and hooks

In `.tsx`, `<T>` parses as a JSX tag. The trailing comma disambiguates:

```tsx
const List = <TItem,>({ items, renderItem }: ListProps<TItem>) => {
  return <ul>{items.map(renderItem)}</ul>;
};
```

```tsx
type ListProps<TItem> = {
  items: readonly TItem[];
  /** Renders one item. Receives the item and its index. */
  renderItem: (item: TItem, index: number) => ReactNode;
};
```

`TItem` appears in `items` and in `renderItem`, so it is inferred from the props and
the two are guaranteed to agree — pass a `User[]` and the render callback is typed as
`User`.

For hooks, the same rule as rule 2 applies, and fetching hooks are where it is most
often broken:

```tsx
// Wrong — TData is asserted by the caller and never checked.
const useFetch = <TData,>(url: string) => {
  …
  setData((await response.json()) as TData);
};

// Right — TData is inferred from the parser, which is what makes it true.
const useFetch = <TData,>(url: string, parse: (raw: unknown) => TData) => {
  …
  setData(parse(await response.json()));
};
```

Do not make a component generic that is only ever used with one type. Generality has a
readability cost, and it is paid at every call site by everyone.

## 10. Union first, overloads only when the return type varies discretely

```typescript
// Prefer a union parameter.
const format = (value: string | number): string => String(value);

// Overloads when the return type genuinely depends on which input was given.
function parseId(value: string): string;
function parseId(value: number): number;
function parseId(value: string | number): string | number { … }
```

Overloads are the one sanctioned use of the `function` keyword, because the syntax
requires it. Keep the implementation signature private and never call it directly.

## Anti-patterns

| Shape | Why it fails |
| ----- | ------------ |
| `<T>(…): T` with `T` used once | An unchecked cast; the caller invents the type |
| `<T = any>` | Opts every default caller out of checking |
| `as T` inside a generic body | The generic is decorative; the assertion is doing the work |
| `<T>` unconstrained, then `(value as any).field` | Two escapes stacked to undo one missing `extends` |
| Explicit type arguments at every call site | The parameter is not inferable — usually rule 2 |
| A service generic over its own entity | Abstraction past the point of meaning |
| `Repository<T, U>` | Unreadable; use `TEntity`, `TId` |

## Checklist

- [ ] Every type parameter appears at least twice in its signature
- [ ] No type parameter used only in the return position without a validating argument
- [ ] Every type parameter constrained to what the body actually requires
- [ ] Call sites rely on inference rather than explicit type arguments
- [ ] Two or more parameters are named descriptively, `T`-prefixed
- [ ] Defaults are `unknown`, not `any`
- [ ] Conditional and mapped types extracted to named aliases
- [ ] Built-in utility types preferred over hand-rolled equivalents
- [ ] No `as` inside a generic body standing in for a constraint
- [ ] `.tsx` type parameters written `<T,>`
