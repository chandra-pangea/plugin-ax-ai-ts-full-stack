# Arrow Functions Only

Helper for the `code-style` skill.

Use arrow function expressions for **all** function definitions. Never use the
`function` keyword.

**Wrong:**

```typescript
function getUserById(id: string) {
  return repository.findById(id);
}

export default function App() {
  return <div />;
}
```

**Right:**

```typescript
const getUserById = (id: string) => {
  return repository.findById(id);
};

const App = () => {
  return <div />;
};

export default App;
```

This applies everywhere: top-level functions, callbacks, utility helpers, route
handlers, and React components.

## React components are not an exception

The `export function Button() {}` form is common in React documentation and in
generated component code. It is still forbidden here. Components are functions, and
the rule has no carve-outs.

**Wrong:**

```tsx
export function UserCard({ user }: UserCardProps) {
  return <article>{user.name}</article>;
}

export function useAuth() {
  const [user, setUser] = useState<User | null>(null);
  return { user, setUser };
}
```

**Right:**

```tsx
const UserCard = ({ user }: UserCardProps) => {
  return <article>{user.name}</article>;
};

const useAuth = () => {
  const [user, setUser] = useState<User | null>(null);
  return { user, setUser };
};

export { UserCard, useAuth };
```

Two practical consequences worth knowing rather than discovering:

- Arrow components are not hoisted. Define a component before the component that
  renders it, or rely on the module boundary.
- Arrow components have no `.name` inference problem when assigned to a `const`, so
  React DevTools still shows `UserCard`.

## Generic arrow functions in `.tsx`

In a `.tsx` file, `<T>` at the start of an arrow function parses as JSX. Add a
trailing comma or an `extends` clause.

```tsx
// Fails to parse in .tsx
const identity = <T>(value: T): T => value;

// Both of these work
const identity = <T,>(value: T): T => value;
const identityAlt = <T extends unknown>(value: T): T => value;
```
