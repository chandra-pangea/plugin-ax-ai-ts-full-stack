# Reuse and Performance Patterns

## Reuse patterns

### Shared fetching logic

```tsx
import { useEffect, useState } from "react";

// Fetches JSON from a path and tracks loading and error state. The parser is what
// makes TData true, so it is a parameter rather than something the caller asserts.
const useFetch = <TData,>(url: string, parse: (raw: unknown) => TData) => {
  const [data, setData] = useState<TData | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    const controller = new AbortController();

    const load = async () => {
      try {
        const response = await fetch(url, { signal: controller.signal });
        setData(parse(await response.json()));
      } catch (err) {
        if (!controller.signal.aborted) {
          setError(err as Error);
        }
      } finally {
        setIsLoading(false);
      }
    };

    void load();

    return () => controller.abort();
  }, [url, parse]);

  return { data, isLoading, error };
};

export { useFetch };
```

Two things here are not optional.

**The abort on unmount** — without it, a resolved fetch sets state on an unmounted
component and leaks the request.

**The parser** — `useFetch<User>(url)` with the response cast to `User` is the most
common unchecked cast in a React codebase. The type parameter appears only in the
return, nothing verifies the payload, and a changed endpoint keeps compiling until it
fails somewhere unrelated. Passing the parser makes `TData` inferred from the thing
that actually checks it. See `code-style/references/generics.md`.

### Compound components

```tsx
import type { ReactNode } from "react";

const Card = ({ children }: { children: ReactNode }) => {
  return <div className="rounded-lg border border-divider p-4">{children}</div>;
};

const CardTitle = ({ children }: { children: ReactNode }) => {
  return <h3 className="text-lg font-semibold">{children}</h3>;
};

const CardDescription = ({ children }: { children: ReactNode }) => {
  return <p className="text-muted">{children}</p>;
};

export { Card, CardTitle, CardDescription };
```

### Pure utilities

```typescript
const DEFAULT_LOCALE = "en-US";

// Formats a date for display in the user's locale.
const formatDate = (date: Date, locale: string = DEFAULT_LOCALE): string => {
  return new Intl.DateTimeFormat(locale).format(date);
};

// Formats a minor-unit amount as currency.
const formatCurrency = (
  amount: number,
  currency: string,
  locale: string = DEFAULT_LOCALE
): string => {
  return new Intl.NumberFormat(locale, { style: "currency", currency }).format(amount);
};

export { formatDate, formatCurrency };
```

Currency and locale are parameters, not constants. Hardcoding `USD` is the kind of
default that survives all the way to a production incident.

## Performance

### Lazy routes

```tsx
import { lazy, Suspense } from "react";

import { LoadingIndicator } from "<ui-scope>/<wrappers-pkg>";

const Dashboard = lazy(() => import("./pages/dashboard.page"));

const App = () => {
  return (
    <Suspense fallback={<LoadingIndicator />}>
      <Dashboard />
    </Suspense>
  );
};

export { App };
```

### Memoization

Measure first. `memo` on a cheap component costs more than it saves.

```tsx
import type { Product } from "./product.types";

import { memo } from "react";

const ProductCard = memo(({ product }: { product: Product }) => {
  return <article>{product.name}</article>;
});

ProductCard.displayName = "ProductCard";

export { ProductCard };
```

### Long lists

Virtualize past a few hundred rows. Below that, the virtualization overhead and the
accessibility cost of a windowed list are not worth it.
