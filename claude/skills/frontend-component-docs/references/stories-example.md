# Storybook Stories Example

A complete stories file for the wrapped `Button`, followed by the Storybook
configuration it runs under. The story requirements themselves live in
`SKILL.md` hard rule 2.

## Stories

```tsx
// button.stories.tsx
import type { Meta, StoryObj } from "@storybook/react";

import { useState } from "react";
import { X as CloseIcon } from "lucide-react"; // any icon source works

import { Button } from "./button";

/**
 * Triggers an action. Use `primary` for the main action on a screen,
 * `secondary` alongside it, and `ghost` for tertiary actions.
 */
const meta = {
  title: "Wrappers/Button",
  component: Button,
  tags: ["autodocs"],
  argTypes: {
    variant: {
      control: "select",
      options: ["primary", "secondary", "ghost"],
      description: "Visual weight",
    },
    size: {
      control: "select",
      options: ["sm", "md", "lg"],
      description: "Size preset",
    },
    isLoading: { control: "boolean" },
    isFullWidth: { control: "boolean" },
    disabled: { control: "boolean" },
    children: { control: "text" },
    onClick: { action: "clicked" },
  },
} satisfies Meta<typeof Button>;

type Story = StoryObj<typeof meta>;

const Default: Story = {
  args: {
    children: "Save changes",
    variant: "primary",
    size: "md",
  },
};

const Variants: Story = {
  render: () => (
    <div className="flex gap-4">
      <Button variant="primary">Save changes</Button>
      <Button variant="secondary">Cancel</Button>
      <Button variant="ghost">Skip for now</Button>
    </div>
  ),
};

const Sizes: Story = {
  render: () => (
    <div className="flex items-center gap-4">
      <Button size="sm">Small</Button>
      <Button size="md">Medium</Button>
      <Button size="lg">Large</Button>
    </div>
  ),
};

const Loading: Story = {
  args: {
    children: "Save changes",
    isLoading: true,
    loadingText: "Saving…",
  },
};

const Disabled: Story = {
  args: {
    children: "Save changes",
    disabled: true,
  },
};

const IconOnly: Story = {
  args: {
    icon: <CloseIcon />,
    ariaLabel: "Close dialog",
    variant: "ghost",
  },
};

// A realistic composition, so layout problems surface in the story rather than in a page.
const InForm: Story = {
  render: () => {
    const [isSaving, setIsSaving] = useState(false);

    return (
      <form
        className="flex gap-2"
        onSubmit={(event) => {
          event.preventDefault();
          setIsSaving(true);
          window.setTimeout(() => setIsSaving(false), 1500);
        }}
      >
        <label htmlFor="story-email" className="sr-only">
          Email
        </label>
        <input
          id="story-email"
          type="email"
          required
          placeholder="you@example.com"
          className="rounded border px-3 py-2"
        />
        <Button type="submit" isLoading={isSaving} loadingText="Subscribing…">
          Subscribe
        </Button>
      </form>
    );
  },
};

export default meta;

export { Default, Disabled, IconOnly, InForm, Loading, Sizes, Variants };
```

## Storybook setup

```typescript
// .storybook/main.ts
import type { StorybookConfig } from "@storybook/react-vite";

const config: StorybookConfig = {
  stories: ["../src/**/*.stories.tsx"],
  addons: [
    "@storybook/addon-essentials",
    "@storybook/addon-interactions",
    "@storybook/addon-a11y",
  ],
  framework: {
    name: "@storybook/react-vite",
    options: {},
  },
  docs: { autodocs: true },
};

export default config;
```
