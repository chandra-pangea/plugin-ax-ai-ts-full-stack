---
name: frontend-accessibility
description: "Use when building or maintaining any interactive component, form, dialog, or page. Enforces WCAG 2.1 AA — semantic HTML first, ARIA only where semantics fall short, full keyboard operation, visible focus, contrast ratios, labelled inputs, and respected motion preferences. Triggers on add a modal, build a dropdown, form validation, keyboard navigation, screen reader, contrast, accessibility audit."
metadata:
  version: "2.0"
---

# Frontend Accessibility

Applies to components in `<ui-packages-dir>` and pages in `<web-dir>/src/`. The
target is WCAG 2.1 Level AA, and it is a floor rather than a goal.

## Resolving project conventions

Values in angle brackets come from the project's stack profile. Resolve them in this
order:

1. Read `STACK-PROFILE.md` at the repo root and use its values verbatim.
2. If it is absent or a key is missing, infer from the repo — `css-strategy` and
   `ui-framework` from the web application's dependencies.
3. If still unresolved, match the dominant convention already present in the repo.
4. Only when the repo is empty, fall back to this skill's stated default — then write
   the chosen values into `STACK-PROFILE.md`.

Never invent a new convention when the repo already expresses one.

---

## Hard rules

### 1. Semantic HTML first

- `<button>` for actions, `<a>` for navigation. Never a `<div>` with a click handler.
- Heading levels descend without skipping.
- `<label>` for every form field, associated with `htmlFor`.
- `<fieldset>` and `<legend>` for grouped controls.
- Landmarks — `<nav>`, `<main>`, `<footer>`, `<aside>` — on every page.

### 2. ARIA only where HTML cannot

The order of preference is semantic element, then ARIA attribute, then custom
behavior. Never use ARIA to override semantics an element already carries — a
`role="button"` on a `<div>` reimplements, badly, what `<button>` gives free.

Incorrect ARIA is worse than none: a wrong `aria-label` silently replaces the
accessible name a screen reader would otherwise compute correctly.

### 3. Keyboard operation is mandatory

- Everything interactive is reachable with Tab.
- Tab order follows visual order.
- Focus is always visible. Never remove an outline without replacing it.
- `Escape` closes dialogs and popovers; `Enter` and `Space` activate controls; arrow
  keys move within composite widgets.
- Custom widgets manage focus explicitly.

### 4. Color and contrast

- 4.5:1 for normal text, 3:1 for large text (18px, or 14px bold) and for meaningful
  UI boundaries.
- Color never carries meaning alone — pair it with text, an icon, or a pattern.
- Both themes are checked, not just the default one.

### 5. Images and media

- Every image has `alt`. Descriptive for content, `alt=""` for decoration.
- Never "image", "photo", or the filename.
- Complex images get a long description through `aria-describedby` or a caption.
- Video carries captions; audio carries a transcript.

### 6. Forms

- Every input labelled.
- Errors linked with `aria-describedby` and announced with `role="alert"`.
- Invalid fields marked `aria-invalid`.
- Required fields marked with the `required` attribute — and if an asterisk is shown,
  its meaning is stated in text somewhere.
- On a failed submit, focus moves to the first invalid field.

### 7. Target size

WCAG 2.1 AA has no minimum target size (2.2 AA sets 24×24 CSS px; the 44×44 figure is
2.1 AAA and the platform HIG convention). Treat **44×44 as the floor for primary
actions on touch surfaces**, and apply it as follows:

- Primary and destructive actions, and anything a user reaches for on a phone: 44×44.
- Dense desktop chrome — toolbars, table row actions, compact form controls — may go
  smaller, down to 24×24, provided the targets are not adjacent to other targets and
  an equivalent full-size control exists elsewhere.
- Spacing counts. A 32px control with 6px of clear space on each side meets the 2.2
  criterion; a 32px control butted against its neighbour does not.

**Vendored component libraries typically ship below this floor** — a default button
height of 32 or 36 CSS px is common. Do not hand-edit the vendored file to fix it, and
do not treat the mismatch as acceptable by default. Raise the default in
`<wrappers-pkg>` so every consumer inherits the compliant size, and keep the smaller
sizes available as explicit opt-ins for dense contexts. That way the accessible choice
is the one you get by not thinking about it.

Record which resolution the project took in `STACK-PROFILE.md`. An unstated waiver
gets rediscovered as a bug every six months.

### 8. Motion

- Respect `prefers-reduced-motion`.
- Auto-playing content has a pause control.
- Nothing flashes more than three times per second.

### 9. Testing is part of the work

- Operate the feature with the keyboard alone.
- Listen to it with a screen reader — VoiceOver on macOS, NVDA on Windows.
- Run an automated scan in the end-to-end suite.

Automated tools catch roughly a third of real issues. They are a floor, not a pass.

---

## Patterns

Full implementations live in
[`references/component-patterns.md`](references/component-patterns.md). What each
pattern guarantees:

- **Button** — a semantic `<button>` whose focus ring shows for keyboard users but
  not mouse clicks (`focus-visible`), with motion-safe transitions and an
  `ariaLabel` prop for icon-only use.
- **Form input** — a labelled input whose error text is programmatically linked
  with `aria-describedby`, announced with `role="alert"`, and flagged with
  `aria-invalid`; the required asterisk is `aria-hidden`.
- **Dialog** — a native `<dialog>` using `showModal()` for free focus trapping,
  `Escape` handling, and inert background; focus moves in on open and restores to
  the trigger on close.
- **Listbox** — a custom select with roving arrow-key navigation and correct ARIA
  wiring (`aria-activedescendant`, `role="listbox"`); build it only when a native
  `<select>` does not fit.
- **Skip link** — lets keyboard users jump past the navigation, visible only when
  focused; the target carries `tabIndex={-1}` so focus actually lands there.

---

## WCAG quick reference

| Principle | Requirement | In practice |
| --------- | ----------- | ----------- |
| Perceivable | Content available to every sense | Alt text, captions, colour plus icon |
| Operable | Everything reachable by keyboard | Tab order, Escape closes, focus visible |
| Understandable | Predictable, clearly worded | Consistent navigation, plain language |
| Robust | Works with assistive technology | Valid HTML, correct ARIA, semantic elements |

| Issue | Fix |
| ----- | --- |
| Unlabelled input | Add `<label htmlFor>` |
| Low contrast | Meet 4.5:1, or 3:1 for large text |
| No keyboard path | Real interactive elements, managed focus |
| Missing alt | Describe it, or `alt=""` if decorative |
| Colour-only meaning | Add text or an icon |
| Icon-only button | Add `aria-label` |
| Flashing content | Keep under three flashes per second |

---

## Motion preferences

Handle reduced motion in plain CSS. A utility-class variant such as `motion-safe:`
only applies when motion is *allowed*, so putting it inside a reduced-motion query
produces a rule that can never match.

```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

Near-zero rather than `none` keeps transition-end events firing, so components
waiting on them do not hang.

For per-component control, apply the `motion-safe:` variant to the animated utility
itself — `motion-safe:transition-colors`, as in the Button above.

## Visually hidden content

Most utility frameworks already ship `sr-only` and `not-sr-only`. Use them; do not
redefine them. If yours does not, the reference implementation lives in
[`references/component-patterns.md`](references/component-patterns.md).

---

## Testing checklist

**Keyboard**

- [ ] Every interactive element reachable by Tab
- [ ] Tab order matches visual order
- [ ] Focus always visible
- [ ] Escape closes dialogs and popovers
- [ ] Arrow keys work in composite widgets
- [ ] Focus returns to the trigger when a dialog closes

**Screen reader**

- [ ] All content reachable
- [ ] Control purposes clear without surrounding context
- [ ] Labels announced with their fields
- [ ] Errors announced through `role="alert"`
- [ ] Landmarks present
- [ ] Decorative elements hidden with `aria-hidden`

**Colour**

- [ ] 4.5:1 normal text, 3:1 large text and UI boundaries
- [ ] No colour-only meaning
- [ ] Both themes verified

**Motion**

- [ ] Reduced-motion honoured
- [ ] No flashing beyond three per second
- [ ] Auto-playing content pausable

**Automated**

Scans run inside the Playwright suite — see `frontend-testing`. The Axe-in-Playwright
snippet lives in
[`references/component-patterns.md`](references/component-patterns.md).

## Reference documents

| Deep dive | Reference |
| --------- | --------- |
| Accessible component implementations: button, form input, modal, listbox, skip link | [`references/component-patterns.md`](references/component-patterns.md) |

## Related skills

- **`frontend-architecture`** — component layering and theming
- **`frontend-testing`** — where these checks run
- **`frontend-component-docs`** — documenting a component's accessibility contract
