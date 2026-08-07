---
name: frontend-architecture
description: "Use when writing any component, hook, or utility in the web application or a shared UI package. Enforces separation of business logic from presentation, component layering, state-management tiers, theme tokens over raw colors, one-directional package tiers, mobile-first responsive design, custom hooks for reuse, and the vendored-primitive exemption. Triggers on build a page, add a component, new screen, refactor UI, set up theming, add a variant."
metadata:
  version: "2.1"
---

# Frontend Architecture

Structural patterns, state discipline, and reuse strategy for `<web-dir>/src/` and
shared UI packages in `<ui-packages-dir>/`.

## Resolving project conventions

Values in angle brackets come from the project's stack profile. Resolve them in this
order:

1. Read `STACK-PROFILE.md` at the repo root and use its values verbatim.
2. If it is absent or a key is missing, infer from the repo:
   - `ui-framework`, `meta-framework`, `css-strategy` — dependencies in the web
     application's `package.json`
   - `web-dir`, `ui-packages-dir`, `ui-scope` — workspace globs and existing package
     names
   - `theme-pkg`, `primitives-pkg`, `wrappers-pkg`, `utils-pkg` — existing packages
     under `<ui-packages-dir>`, identified by what they contain rather than by name
   - `token-format` — whether tokens are authored in CSS, a preprocessor, or TypeScript
   - `dark-mode-strategy` — what the existing theme provider writes to the document
     element
3. If still unresolved, match the dominant convention already present in the repo.
4. Only when the repo is empty, fall back to this skill's stated default — then write
   the chosen values into `STACK-PROFILE.md`.

Never invent a new convention when the repo already expresses one.

Patterns here assume React. The layering, state tiers, and reuse thresholds transfer
to other component frameworks; the syntax does not.

---

## Hard rules

### 1. Business logic is not a component

- Domain logic goes into custom hooks (`hooks/use-*.ts`) or pure utilities (`utils/`).
- Components are presentational shells that receive computed data.
- No data fetching, no async orchestration, no business branching inside JSX.

### 2. Mobile-first, pixel-accurate

- Breakpoints start at mobile and scale up. The unprefixed style is the mobile style.
- Use the framework's responsive prefixes; never hardcode pixel dimensions.
- Verify at a 375px viewport before calling the work done.
- Match spacing, alignment, font size, and line height to the design source.

### 3. Theme through tokens

- Colors, spacing, and typography come from `<ui-scope>/<theme-pkg>`. Never a raw hex
  value in a component.
- Use semantic names — `text-primary`, `bg-surface`, `border-divider` — not
  palette-literal names like `blue-500`.
- Dynamic theming goes through CSS custom properties so light and dark share one
  component tree.
- Every theme defines the same token keys. A key defined in one mode and absent in
  another does not fall back — it renders as nothing, and only in that mode.

### 4. Package structure for reuse

Shared UI packages under `<ui-packages-dir>` divide by role, not by feature, and form
a one-directional chain. **Each tier may import only from tiers to its left.** A
reverse import — a primitive reaching for a wrapper, a theme package importing a
component — is a defect, not a style preference: it makes the graph uncyclable and
breaks `<build-orchestrator>`'s build ordering.

```
<theme-pkg>  →  <primitives-pkg>  →  <wrappers-pkg>  →  <web-dir>
  tokens          primitives          brand wrappers     application

<utils-pkg> — outside the chain. Imports no UI package and no component framework.
```

| Role | Profile key | Contents |
| ---- | ----------- | -------- |
| Theme | `<theme-pkg>` | Design tokens, color scales, typography, the theme provider, fonts and icons. No components. |
| Primitives | `<primitives-pkg>` | Button, Input, Select, Sheet — the unstyled or minimally styled atoms. Frequently vendored; see rule 11. |
| Brand wrappers | `<wrappers-pkg>` | Primitives re-exported with the product's variants, sizes, and defaults applied. This is where local API decisions live. |
| Utilities | `<utils-pkg>` | HTTP clients, API helpers, formatting. No UI, no framework imports. |

A repo without a distinct wrapper tier collapses wrappers into primitives — but once
primitives are vendored, the wrapper tier is mandatory, because it is the only place
local changes survive regeneration.

**Extraction threshold:** when more than three pages share a component or a piece of
logic, extract it into a package. Below that, duplication is cheaper than the
indirection.

Every package needs `src/`, `package.json` with an exports map whose paths match what
the build actually emits, `README.md`, and `tsconfig.json`. An `exports` or `types`
field pointing at a directory the build never writes is a broken package even when
`tsc` passes locally — consumers resolve it, the workspace does not.

### 5. Application folder structure

```
<web-dir>/src/
  main.tsx           # entry: mounts the root, imports the global stylesheet
  App.tsx            # composes providers around the route surface
  app/               # the route surface — pages and their providers
  components/
    common/          # used across three or more pages
    features/        # scoped to a single flow
  hooks/             # use-auth.ts, use-fetch.ts, use-pagination.ts
  context/           # cross-cutting providers (auth, theme, locale)
  utils/             # pure functions
  types/             # shared type declarations
  styles/            # global styles and theme wiring
```

The route directory follows the meta-framework's convention — file-based routing under
`next` and `remix`, an explicitly mounted route surface under `vite`. Everything
outside it is framework-neutral.

**Under `vite`, `app/` is a plain directory, not a routing convention.** Borrowing the
Next.js name does not bring Next.js behaviour: `page.tsx` is not a route, `layout.tsx`
is not applied, and server components do not exist. Keep the name if the repo already
uses it — consistency beats correctness in naming — but wire routes explicitly and do
not add Next-only files that will never execute.

A page grows into these folders; it does not start in them. A single-page app with
nothing extracted yet is correct. What is not correct is a page that has grown past a
few hundred lines with everything still inline — at that point the sections are
components and the derived values are hooks.

### 6. Component layering

| Layer | What it is | Example |
| ----- | ---------- | ------- |
| Atoms | Single purpose, no state | Button, Input, Badge |
| Molecules | Two or three atoms with simple interaction | Form field, card header |
| Organisms | Stateful compositions | Login form, data table |
| Templates | Page structure | Header plus sidebar plus content |
| Features | Complete flows with business logic | Checkout, onboarding |

Compose organisms at the page or feature level, never inside another component's
file.

### 7. State management tiers

| Tier | Use for | Where |
| ---- | ------- | ----- |
| Local | UI-only state — modal open, active tab, input value | `useState` in the component |
| Custom hook | Logic with state — fetching, pagination, filters | `hooks/use-*.ts` |
| Context | Shared across many pages — session, theme, locale | `context/` |

Never prop-drill more than three levels. Reach for a hook or a context instead.

### 8. Reuse

- **Custom hooks** for shared stateful logic.
- **Utilities** for pure logic.
- **Compound components** to avoid repeating JSX structure.
- **A class-name helper** for conditional classes — never string concatenation.
- Duplicating something a third time means extracting it. Twice is tolerable.

### 9. Styling

- No inline `style={{}}`. **One exception:** when the style value *is* the data being
  displayed — a token swatch, a chart series color, a user-chosen accent. A utility
  class cannot express a value that is not known until render. Extract it into a
  component (`<TokenSwatch token="primary" />`) so the exception lives in one file
  rather than scattered through a page.
- No CSS-in-JS or CSS modules under a utility-class strategy, except where an
  animation library requires it. Preprocessor files that emit design tokens are not
  CSS modules and are fine — see `<token-format>`.
- Responsive images through `srcSet` or `<picture>`.
- Dark mode follows `<dark-mode-strategy>`, applied through tokens. Whatever the
  strategy, it is applied in exactly one place — the theme provider — and read
  everywhere else.
- Animation through the framework's utilities, gated on reduced-motion preference.
- No emoji in rendered strings. Use the project's icon library — an emoji renders
  differently on every platform, has no accessible name, and cannot be themed.

### 10. Accessibility and performance

- Labels on inputs, ARIA only where semantics fall short, real semantic elements.
- Images always carry `alt`; decorative images carry `alt=""`.
- Lazy-load routes, memoize genuinely expensive renders, virtualize long lists.
- Split feature packages into dynamic imports.

Accessibility details belong to `frontend-accessibility`; this list is the floor.

### 11. Vendored code is exempt, and extended by wrapping

Some primitives are not authored here — they are emitted by a generator (`shadcn add`
and its equivalents) into `<primitives-pkg>/src/components/ui/`. Those files keep
**upstream naming, `function` declarations, and internal structure** so the generator
can regenerate them without producing a conflict on every run.

The style, naming, and per-component documentation rules in this set apply from
`<wrappers-pkg>` outward. They do not apply to vendored files.

- **Never hand-edit a vendored file.** The next generator run reverts it, silently, and
  the diff that reverts it looks like an upgrade.
- **Extend by wrapping.** A local variant, a changed default, an added size — all of it
  goes in `<wrappers-pkg>`, which imports the primitive and re-exports it.
- **Deleting is allowed** where the vendored file ships something the project must not
  have — leftover debug logging, for instance. Record it, because it will come back.
- Configure the linter to relax file-naming and function-declaration rules for that
  directory, so the exemption is enforced by tooling rather than remembered.

This rule is what makes the rest of the set enforceable. Without it, every skill has
three standing violations that everyone learns to ignore, and the ignoring spreads.

---

## Naming

- Components — PascalCase export, kebab-case file: `user-card.component.tsx` exporting
  `UserCard`
- Hooks — `use-` prefix on the file, camelCase export: `use-auth.ts` exporting `useAuth`
- Utilities — kebab-case file, camelCase export: `format-date.util.ts`
- Context — `<name>.context.tsx`

---

## State patterns

### Local state

```tsx
const Modal = () => {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <>
      <button type="button" onClick={() => setIsOpen(true)}>
        Open
      </button>
      {isOpen ? <ModalContent onClose={() => setIsOpen(false)} /> : null}
    </>
  );
};

export { Modal };
```

### Custom hook holding the logic

```tsx
// hooks/use-auth.ts — owns auth state and the login transition.
import type { User } from "../types/user.types";

import { useCallback, useState } from "react";

import { authClient } from "../utils/auth-client.util";

const useAuth = () => {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  // Authenticates and stores the session, surfacing failure as state.
  const login = useCallback(async (email: string, password: string) => {
    setIsLoading(true);
    setError(null);

    try {
      const result = await authClient.login(email, password);
      setUser(result.user);
    } catch (err) {
      setError(err as Error);
    } finally {
      setIsLoading(false);
    }
  }, []);

  return { user, isLoading, error, login };
};

export { useAuth };
```

```tsx
// components/features/auth/login-form.component.tsx — presentation only.
import type { FormEvent } from "react";

import { useState } from "react";

import { useAuth } from "../../../hooks/use-auth";

const LoginForm = () => {
  const { isLoading, error, login } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  // Forwards credentials to the auth hook; no business logic lives here.
  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    void login(email, password);
  };

  return (
    <form onSubmit={handleSubmit}>
      <label htmlFor="email">Email</label>
      <input
        id="email"
        type="email"
        value={email}
        onChange={(event) => setEmail(event.target.value)}
      />

      <label htmlFor="password">Password</label>
      <input
        id="password"
        type="password"
        value={password}
        onChange={(event) => setPassword(event.target.value)}
      />

      <button type="submit" disabled={isLoading}>
        {isLoading ? "Signing in…" : "Sign in"}
      </button>

      {error ? <p role="alert">{error.message}</p> : null}
    </form>
  );
};

export { LoginForm };
```

### Context for cross-cutting state

```tsx
import type { ReactNode } from "react";
import type { User } from "../types/user.types";

import { createContext, useContext } from "react";

import { useAuth } from "../hooks/use-auth";

type AuthContextValue = {
  user: User | null;
  login: (email: string, password: string) => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

// Provides one auth instance to the whole tree.
const AuthProvider = ({ children }: { children: ReactNode }) => {
  const { user, login } = useAuth();

  return <AuthContext.Provider value={{ user, login }}>{children}</AuthContext.Provider>;
};

// Reads the auth context, failing loudly when used outside the provider.
const useAuthContext = (): AuthContextValue => {
  const context = useContext(AuthContext);

  if (context === undefined) {
    throw new Error("useAuthContext must be used inside AuthProvider");
  }

  return context;
};

export { AuthProvider, useAuthContext };

export type { AuthContextValue };
```

---

## Theming

All of `<theme-pkg>` exists to answer one question: what does `bg-primary` resolve to
right now. Three layers answer it, and each has exactly one job.

### Layer 1 — token definitions

Tokens are authored in `<token-format>` and emitted as CSS custom properties scoped to
a theme selector. Every theme defines the same key set; a key present in light and
missing in dark is a token that renders transparent in dark mode, silently.

```scss
// <theme-pkg>/src/themes/<name>/light/colors.scss
@mixin colors {
  --background: hsl(210 35% 99%);
  --foreground: hsl(210 50% 5%);

  // A scale plus a semantic alias pointing into it. Components use the alias;
  // the scale exists so the alias can move without a find-and-replace.
  --primary-50: hsl(210 90% 96%);
  --primary-500: hsl(210 80% 45%);
  --primary-900: hsl(210 70% 18%);
  --primary: var(--primary-500);
  --primary-foreground: hsl(0 0% 100%);
}
```

```scss
// <theme-pkg>/src/themes/<name>/light/index.scss — applied under the theme attribute
@use 'colors' as colors;

[data-theme="<name>"] {
  @include colors.colors;
}
```

### Layer 2 — the utility-class bridge

Tailwind v4 is configured in CSS, not in a JavaScript config file. **Do not add a
`tailwind.config.ts` to a v4 project** — it is not read, and its presence tells the
next reader to edit a file that does nothing.

```css
/* <theme-pkg>/src/tailwind.css — maps utility names onto the tokens above */
@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
}
```

`inline` is load-bearing. Without it Tailwind resolves each `var()` at build time and
bakes in the light-mode value, and runtime theme switching stops working while the
build still succeeds — the failure shows up only as a page that will not go dark.

The application imports the layers in order, once:

```scss
// <web-dir>/src/app/index.scss
@import "tailwindcss";
@import "<ui-scope>/<theme-pkg>/tailwind";   // the bridge
@import "<ui-scope>/<theme-pkg>/themes";     // the token values
```

### Layer 3 — the provider

One provider owns the DOM. It resolves the requested mode against the system
preference, applies `<dark-mode-strategy>` to the document element, and persists the
choice. Nothing else in the codebase writes a theme class or attribute.

- Read the current color theme before re-applying it. Stamping a literal theme name on
  every mode change overrides the color-theme setter and makes multi-theme support
  unreachable while every individual function still looks correct.
- Wrap `localStorage` — it throws in private browsing and when quota is exceeded.
- Guard on `typeof window` if the package can be imported in a server context.
- **Exactly one provider per repo.** A second implementation of the same provider in a
  downstream package is the defect this rule exists to prevent: consumers import
  whichever one their path resolution happens to find, the two disagree on the shape of
  the context, and the bug reproduces on one screen and not another. Downstream
  packages re-export the provider; they do not reimplement it.

### The token values

```css
[data-theme="blue"] {
  --primary: hsl(210 80% 45%);
  --background: hsl(210 35% 99%);
}

.dark[data-theme="blue"] {
  --primary: hsl(210 85% 60%);
  --background: hsl(210 30% 8%);
}
```

### In components

```tsx
// Wrong — palette literal, no dark-mode story
<button className="bg-blue-500 text-white">Save</button>

// Right — semantic token, themes automatically
<button className="bg-primary text-on-primary">Save</button>
```

---

## Mobile-first checklist

- [ ] Unprefixed styles are the mobile styles; `sm:`/`md:`/`lg:` scale up

```tsx
<div className="flex flex-col gap-4 md:flex-row">
  <Sidebar className="md:w-1/4" />
  <Main className="w-full md:w-3/4" />
</div>
```

- [ ] Touch targets at least 44px in both dimensions
- [ ] Responsive images with art direction where it matters

```tsx
<picture>
  <source srcSet="hero-mobile.webp" media="(max-width: 768px)" />
  <img src="hero-desktop.webp" alt="Product overview" loading="lazy" decoding="async" />
</picture>
```

- [ ] Type scales down on small screens: `text-2xl md:text-3xl lg:text-4xl`
- [ ] No horizontal scroll at any width
- [ ] Verified at 375px

---

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
that actually checks it. See `code-style/helpers/generics.md`.

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

---

## Performance

### Lazy routes

```tsx
import { lazy, Suspense } from "react";

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

---

## Verification checklist

- [ ] Business logic lives in hooks or utilities, not components
- [ ] No prop-drilling beyond three levels
- [ ] No inline styles, or the value-is-the-data exception is isolated in a component
- [ ] Mobile-first responsive classes applied
- [ ] Semantic theme tokens, no raw color values
- [ ] Every token key defined in every theme and mode
- [ ] Duplicate logic extracted into a hook or utility
- [ ] Types declared for every prop and hook return
- [ ] Labels, ARIA where needed, semantic elements
- [ ] Images optimized, routes lazy-loaded, memoization justified
- [ ] No hardcoded dimensions
- [ ] Dark mode covered
- [ ] Verified at 375px
- [ ] Matches the design source

Package-level, when the change touched `<ui-packages-dir>`:

- [ ] Imports flow one direction along the tier chain — no reverse dependency
- [ ] Exactly one implementation of each provider; downstream packages re-export it
- [ ] `exports`, `main`, and `types` resolve to paths the build actually emits
- [ ] Vendored files unmodified; local changes live in `<wrappers-pkg>`
- [ ] No debug logging, and no emoji in rendered strings
- [ ] No `process.env` read in code that ships to the browser — the bundler does not
      define it, and the read yields `undefined` at runtime rather than failing at build

## Related skills

- **`frontend-accessibility`** — the accessibility rules this skill only floors
- **`frontend-component-docs`** — documenting anything extracted into a package
- **`frontend-testing`** — Playwright coverage for every flow built here
- **`code-style`** — arrow functions, export blocks, naming, imports
