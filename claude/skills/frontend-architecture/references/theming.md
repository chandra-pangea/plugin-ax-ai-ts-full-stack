# Three-Layer Theming

All of `<theme-pkg>` exists to answer one question: what does `bg-primary` resolve to
right now. Three layers answer it, and each has exactly one job.

## Layer 1 — token definitions

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

## Layer 2 — the utility-class bridge

When `css-framework-version` is `4`, Tailwind is configured in CSS, not in a
JavaScript config file. **Do not add a `tailwind.config.ts` to a v4 project** — it is
not read, and its presence tells the next reader to edit a file that does nothing.
When it is `3`, the config file is real and the CSS-first `@theme` block below does
not apply — the token mapping lives in `tailwind.config.ts` instead.

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

## Layer 3 — the provider

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

## The token values

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

## In components

```tsx
// Wrong — palette literal, no dark-mode story
<button className="bg-blue-500 text-white">Save</button>

// Right — semantic token, themes automatically
<button className="bg-primary text-on-primary">Save</button>
```
