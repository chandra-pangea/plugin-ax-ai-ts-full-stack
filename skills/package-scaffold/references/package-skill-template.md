# Package SKILL.md Template

The `SKILL.md` every package carries at its root, so another repository can adopt it.

````markdown
---
name: <pkg-prefix><name>
description: <What the package does and when to reach for it.>
metadata:
  version: "0.1.0"
  repo: <repo-url>
  path: <packages-dir>/<pkg-prefix><name>
---

# <pkg-scope>/<name>

<One-line summary.>

Full API reference: [README.md](./README.md).

## When to use

Adopt this package when you need:

- <capability>
- <capability>

## Adopting into another repository

```bash
PACKAGE_REF="<git-tag-or-main>"
TMPDIR=$(mktemp -d)
git clone --depth 1 --branch "$PACKAGE_REF" --filter=blob:none --sparse \
  <repo-url> "$TMPDIR"
git -C "$TMPDIR" sparse-checkout set <packages-dir>/<pkg-prefix><name>
cp -r "$TMPDIR/<packages-dir>/<pkg-prefix><name>" ./<packages-dir>/
rm -rf "$TMPDIR"
```

Then install and build from the package directory.

### Provenance

Record where the copy came from, in `.vendor.json`:

```json
{
  "source": "<repo-url>",
  "package": "<packages-dir>/<pkg-prefix><name>",
  "tag": "<git-tag-or-main>",
  "vendoredAt": "<ISO-8601 date>",
  "forked": false
}
```

Updating means repeating the sparse checkout at a new ref and updating that file.

## Quick usage

(5–10 lines, no more)

## Rules

- Do not modify adopted code. Extend through adapters or wrappers.
- If you must modify it, set `"forked": true` in `.vendor.json`.
- Connection strings and secrets come from the application, never from inside this
  package.
````
