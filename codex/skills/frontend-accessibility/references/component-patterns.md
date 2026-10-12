# Accessible Component Patterns

Full implementations for the patterns summarised in the `frontend-accessibility`
skill.

## Button

```tsx
import type { ButtonHTMLAttributes, ReactNode } from "react";

import { cn } from "../utils/class-names.util";

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  children?: ReactNode;
  /** Required when the button renders only an icon. */
  ariaLabel?: string;
};

// Renders a semantic button with a visible focus ring and motion-safe transitions.
const Button = ({ children, ariaLabel, type = "button", ...rest }: ButtonProps) => {
  return (
    <button
      type={type}
      aria-label={ariaLabel}
      className={cn(
        "rounded px-4 py-2 font-medium",
        "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary",
        "disabled:cursor-not-allowed disabled:opacity-50",
        "motion-safe:transition-colors"
      )}
      {...rest}
    >
      {children}
    </button>
  );
};

export { Button };

export type { ButtonProps };
```

`focus-visible` rather than `focus` keeps the ring off mouse clicks while keeping it
for keyboard users.

## Form input

```tsx
import type { InputHTMLAttributes } from "react";

import { cn } from "../utils/class-names.util";

type FormInputProps = InputHTMLAttributes<HTMLInputElement> & {
  id: string;
  label: string;
  error?: string;
};

// Renders a labelled input whose error text is announced and programmatically linked.
const FormInput = ({ id, label, error, required, ...rest }: FormInputProps) => {
  const errorId = error === undefined ? undefined : `${id}-error`;

  return (
    <div className="mb-4">
      <label htmlFor={id} className="mb-1 block text-sm font-medium">
        {label}
        {required === true ? <span aria-hidden="true"> *</span> : null}
      </label>

      <input
        id={id}
        required={required}
        aria-invalid={error !== undefined}
        aria-describedby={errorId}
        className={cn(
          "w-full rounded border px-3 py-2",
          error === undefined ? "border-divider" : "border-danger"
        )}
        {...rest}
      />

      {error !== undefined ? (
        <p id={errorId} role="alert" className="mt-1 text-sm text-danger">
          {error}
        </p>
      ) : null}
    </div>
  );
};

export { FormInput };
```

The asterisk is `aria-hidden` because `required` already conveys the state — a screen
reader announcing "star" adds nothing. State what the asterisk means once, in text,
at the top of the form.

## Dialog

```tsx
import type { ReactNode } from "react";

import { useEffect, useRef } from "react";

type ModalProps = {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
};

// Renders a modal dialog, moving focus in on open and restoring it on close.
const Modal = ({ isOpen, onClose, title, children }: ModalProps) => {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const previouslyFocusedRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    const dialog = dialogRef.current;

    if (dialog === null) {
      return;
    }

    if (isOpen) {
      previouslyFocusedRef.current = document.activeElement as HTMLElement | null;
      dialog.showModal();
      return;
    }

    dialog.close();
    previouslyFocusedRef.current?.focus();
  }, [isOpen]);

  return (
    <dialog
      ref={dialogRef}
      aria-labelledby="modal-title"
      className="rounded-lg bg-surface p-6 shadow-lg backdrop:bg-black/50"
      onClose={onClose}
      onCancel={onClose}
    >
      <h2 id="modal-title" className="mb-4 text-xl font-bold">
        {title}
      </h2>

      <div>{children}</div>

      <button type="button" onClick={onClose} className="mt-4 rounded px-4 py-2">
        Close
      </button>
    </dialog>
  );
};

export { Modal };
```

`showModal()` on a native `<dialog>` gives focus trapping, `Escape` handling, inert
background content, and the top layer — all behaviors that are painful to reproduce
by hand on a `<div>`. Use it rather than rebuilding it. The `onCancel` handler is what
catches `Escape`.

## Listbox

When a native `<select>` fits the need, use it. Build this only when it does not.

```tsx
import type { KeyboardEvent } from "react";

import { useRef, useState } from "react";

type Option = { value: string; label: string };

type SelectProps = {
  id: string;
  label: string;
  options: Option[];
  value: string;
  onChange: (value: string) => void;
};

// Renders a listbox with roving arrow-key navigation and correct ARIA wiring.
const Select = ({ id, label, options, value, onChange }: SelectProps) => {
  const [isOpen, setIsOpen] = useState(false);
  const [activeValue, setActiveValue] = useState(value);
  const triggerRef = useRef<HTMLButtonElement>(null);

  // Moves the active option, commits a selection, or dismisses the list.
  const handleKeyDown = (event: KeyboardEvent<HTMLButtonElement>) => {
    const currentIndex = options.findIndex((option) => option.value === activeValue);

    if (event.key === "ArrowDown") {
      event.preventDefault();
      setActiveValue(options[Math.min(currentIndex + 1, options.length - 1)].value);
      return;
    }

    if (event.key === "ArrowUp") {
      event.preventDefault();
      setActiveValue(options[Math.max(currentIndex - 1, 0)].value);
      return;
    }

    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      onChange(activeValue);
      setIsOpen(false);
      triggerRef.current?.focus();
      return;
    }

    if (event.key === "Escape") {
      setIsOpen(false);
      triggerRef.current?.focus();
    }
  };

  const selected = options.find((option) => option.value === value);

  return (
    <div className="relative inline-block">
      <span id={`${id}-label`} className="text-sm font-medium">
        {label}
      </span>

      <button
        ref={triggerRef}
        id={id}
        type="button"
        aria-haspopup="listbox"
        aria-expanded={isOpen}
        aria-labelledby={`${id}-label ${id}`}
        onClick={() => setIsOpen(!isOpen)}
        onKeyDown={handleKeyDown}
        className="w-full rounded border border-divider px-3 py-2"
      >
        {selected?.label}
      </button>

      {isOpen ? (
        <ul
          role="listbox"
          aria-labelledby={`${id}-label`}
          aria-activedescendant={`${id}-option-${activeValue}`}
          tabIndex={-1}
          onKeyDown={handleKeyDown}
          className="absolute inset-x-0 top-full z-10 mt-1 rounded border border-divider bg-surface shadow-lg"
        >
          {options.map((option) => (
            <li
              key={option.value}
              id={`${id}-option-${option.value}`}
              role="option"
              aria-selected={value === option.value}
              onClick={() => {
                onChange(option.value);
                setIsOpen(false);
              }}
              className="cursor-pointer px-3 py-2"
            >
              {option.label}
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
};

export { Select };
```

## Skip link

```tsx
// Lets keyboard users jump past the navigation; visible only when focused.
const SkipLink = () => {
  return (
    <a
      href="#main-content"
      className="sr-only focus:not-sr-only focus:fixed focus:left-0 focus:top-0 focus:z-50 focus:bg-primary focus:px-4 focus:py-2 focus:text-on-primary"
    >
      Skip to main content
    </a>
  );
};

export { SkipLink };
```

The target needs `tabIndex={-1}` so focus actually lands there:

```tsx
<main id="main-content" tabIndex={-1}>
```

## Visually hidden CSS

Most utility frameworks already ship `sr-only` and `not-sr-only`. Use them; do not
redefine them. If yours does not, this is the implementation:

```css
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip-path: inset(50%);
  white-space: nowrap;
  border-width: 0;
}
```

## Automated Axe scan in Playwright

Scans run inside the Playwright suite — see `frontend-testing`.

```typescript
import { expect, test } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test("home page has no detectable accessibility violations", async ({ page }) => {
  await page.goto("/");

  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
    .analyze();

  expect(results.violations).toEqual([]);
});
```
