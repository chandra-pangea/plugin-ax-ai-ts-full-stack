# TS Full-Stack Skill Set

Ten portable agent skills for JavaScript/TypeScript full-stack development, packaged
as a **private plugin**. They carry no project names, no package scopes, and no
hardcoded paths — a `STACK-PROFILE.md` at the consuming repo's root supplies those,
and each skill falls back to detecting them from the repo when the profile is absent.

Delivery concerns — container packaging and commit policy — are deliberately out of
scope. This set governs how code is written and verified, not how it ships.

Install once per machine; the skills then apply to **every** Node/React/JS/TS project
automatically, with nothing copied into any consuming repository. Claude Code loads
the repo as a plugin; Cursor, Codex, and Gemini CLI get the same skills globally via
`install.sh`.

```
skills/                     the ten skills — the whole deliverable
.claude-plugin/             plugin + marketplace manifests (Claude Code)
plugin.json                 open Agent Plugins manifest (Cursor and other conformant clients)
hooks/hooks.json            SessionStart hook that injects the digest below
standards-digest.md         always-active distillation of the mandatory rules
install.sh                  global install for Cursor / Codex / Gemini CLI
STACK-PROFILE.template.md   what a consuming repo fills in (optional)
README.md                   this file: the set, how to install it, how to change it
```

The single source of truth is this repository. Nothing is copied into consuming
projects — Claude Code reads the plugin from its install location, and the other
tools follow symlinks into this clone — so an edit here reaches every project the
next time it is pulled, and installed copies cannot drift from the source.

---

## The set

### Cross-cutting — apply on every surface

| Skill | Governs |
| ----- | ------- |
| [`code-style`](skills/code-style/) | Arrow functions, consolidated exports, type import/export separation, import ordering, naming, no hardcodes, function comments, TypeScript compiler baseline and generics discipline, and what generated code is exempt from. Seven helper documents for depth. |
| [`code-review`](skills/code-review/) | On-demand review against 13 categories, including type safety and generics; writes durable findings to a per-package review document. |

### Backend

| Skill | Governs |
| ----- | ------- |
| [`backend-architecture`](skills/backend-architecture/) | Where code goes: shared package versus domain module. Hexagonal layout, dependency direction, port and service contracts. |
| [`backend-testing`](skills/backend-testing/) | Zero-mock testing against real dependencies, co-located specs, coverage categories. |

### Packages

| Skill | Governs |
| ----- | ------- |
| [`package-scaffold`](skills/package-scaffold/) | Creating a shared runtime package: folder layout, public-class pattern, config files, package documentation. One helper document for design patterns. |
| [`package-checklist`](skills/package-checklist/) | Validating a package — runtime or UI: naming, structure, scripts, exports that actually resolve, README completeness, pre-PR gate. |

### Frontend

| Skill | Governs |
| ----- | ------- |
| [`frontend-architecture`](skills/frontend-architecture/) | One-directional package tiers, component layering, state management, three-layer theming, mobile-first, reuse, performance, and the vendored-primitive exemption. |
| [`frontend-accessibility`](skills/frontend-accessibility/) | WCAG AA, semantic HTML, ARIA, keyboard navigation, focus management, contrast, target size, motion. |
| [`frontend-component-docs`](skills/frontend-component-docs/) | Which layer gets documented, component README, JSDoc props, Storybook stories, documented accessibility. |
| [`frontend-testing`](skills/frontend-testing/) | Playwright end-to-end against a running app. Role-based selectors, required coverage per flow, theming and design-system surfaces. |

---

## Installing — Claude Code (plugin)

This is a private plugin: it is never published to a public marketplace. Connect the
repo itself — from the local clone, or from the private Azure DevOps remote.

```bash
# From a local clone (simplest — no network, no credentials):
claude plugin marketplace add /path/to/plugin-ax-ai-ts-full-stack
```

```bash
# Or straight from the private remote (uses your Azure DevOps credentials):
claude plugin marketplace add https://aatmix@dev.azure.com/aatmix/ax-ai-platform/_git/plugin-ax-ai-ts-full-stack
```

Then, inside Claude Code:

```
/plugin install ts-full-stack@ax-ai-skills
```

**If the older `js-ts-plugin` is installed, remove or disable it first** (`/plugin`).
Its digest overlaps this one, and two rule sets injected into the same session give
the agent contradictory instructions — worse than either alone.

What you get, in every project, with no per-repo files:

- The ten skills, namespaced `ts-full-stack:<name>`, auto-loading when a task matches
  their description — *"add a rate limiter to the API"* loads
  `ts-full-stack:backend-architecture` without being asked.
- A `SessionStart` hook that injects [`standards-digest.md`](standards-digest.md) —
  the mandatory rules plus a routing table — into context, but **only in JS/TS
  projects** (it checks for `package.json`, `tsconfig.json`, or
  `pnpm-workspace.yaml`, so a Python repo pays nothing). This replaces the routing
  block earlier versions asked every consuming repo to paste into its `AGENTS.md`.

Updating: `git pull` in the clone, then `claude plugin marketplace update ax-ai-skills`.

## Installing — Cursor (as a plugin)

The root [`plugin.json`](plugin.json) makes this repo a conformant
[Agent Plugins](https://agent-plugins.org/) package, which Cursor loads without
changes. From a clone:

```bash
ln -s /path/to/plugin-ax-ai-ts-full-stack ~/.cursor/plugins/local/ts-full-stack
```

Then restart Cursor (or **Developer: Reload Window**). Teams/Enterprise plans can
instead import the repo as a team marketplace from the dashboard.

The plugin route loads the ten skills. The Agent Plugins standard has no hooks, so
the **always-active digest** still comes from `install.sh` below — run both for the
full Claude Code-equivalent behavior, or just `install.sh`, which also covers the
skills.

## Installing — Cursor, Codex, Gemini CLI (global skills + digest)

These tools read the same open Agent Skills format from a **global** directory, so
one install serves every project. Anyone with repo access, starting from nothing:

```bash
git clone https://dev.azure.com/aatmix/ax-ai-platform/_git/plugin-ax-ai-ts-full-stack "$HOME/.ts-full-stack" && "$HOME/.ts-full-stack/install.sh"
```

Or from a clone you already have:

```bash
/path/to/plugin-ax-ai-ts-full-stack/install.sh
```

The script is idempotent — re-run it after a `git pull` to update. It:

1. Symlinks each skill into `~/.agents/skills/` (the cross-tool standard: Cursor
   2.4+, Codex, Gemini CLI) and `~/.cursor/skills/` (older Cursor). Symlinks mean a
   `git pull` in this clone updates every tool at once; pass `--copy` on machines
   that will not keep the clone.
2. Writes `standards-digest.md` into each tool's global memory file
   (`~/.cursor/AGENTS.md`, `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md`) as a managed
   marker block — created if absent, replaced in place on re-run, never touching
   anything outside the markers. If your Cursor predates global `AGENTS.md` support,
   paste the digest into Cursor's Rules for AI instead.

`./install.sh --uninstall` removes the symlinks and the marker blocks.

## The profile (optional, per repo)

Skills resolve every `<placeholder>` in this order: `STACK-PROFILE.md` at the
consuming repo's root → infer from the repo (root `package.json`, lockfile, workspace
globs, config files) → match the dominant convention already present → stated
default, written back to the profile.

Inference usually works, so the profile is optional — but where a repo's layout is
unusual, copy [STACK-PROFILE.template.md](STACK-PROFILE.template.md) to the repo root
as `STACK-PROFILE.md` and fill it in. The template carries its own guidance on which
rows matter and why a wrong row is worse than a missing one.

The frontend keys reward precision, because the wrong answer fails quietly rather
than loudly. `css-framework-version` decides whether a `tailwind.config.ts` is read
at all or is dead weight. `primitives-pkg` being vendored decides which files the
style and documentation rules reach — and makes `wrappers-pkg` mandatory, since a
vendored package is the one place a local change does not survive.

### Verifying an install

Ask the agent something that should route — *"add a rate limiter to the API"* ought
to load `ts-full-stack:backend-architecture` — and confirm it does. In Claude Code,
`/plugin` lists the installed plugin; in a JS/TS repo the session should show the
digest's rules applying without any skill being named.

---

# Changing the skills

Everything above is for a project *using* the set. This half is for anyone editing it.

The rules differ, and the distinction matters: the skills in `skills/` govern *other
people's* code. This section governs *this* repository.

## The skills here are content, not capability

`skills/<name>/SKILL.md` is a markdown file to edit like any other. Nothing in this
repository loads it. So:

- **Do not invoke a skill to edit itself.** `frontend-architecture` governs the
  application code that skill describes, not the document describing it. This section
  does.
- If a skill by one of these names appears in an agent's available-skills list, it
  came from an installed copy of this plugin or another project. Editing `skills/`
  changes what the *next* update installs, not what is currently loaded.

This repository keeps no editor memory file — no `AGENTS.md`, no `CLAUDE.md`. The
`.claude-plugin/` directory configures the plugin for consumers; it does not instruct
an agent working on this repo. An agent editing here may need pointing at this
section rather than picking it up automatically.

## Hard rules

### 1. Nothing project-specific

This is the rule the whole set exists to satisfy. Every project-specific value is a
`<placeholder>` resolved against `STACK-PROFILE.md` in the consuming repository.
`@acme/logger`, `apps/web`, and `localhost:3000` appear only as illustrations clearly
marked as such — a deliberate negative example carrying a project-specific value must
say `// wrong` on the same line, which is also what keeps it out of the leak check
below.

A skill that assumes a directory name, a package scope, a port, or a framework version
produces wrong instructions in the first project that differs — and produces them
confidently.

Adding a placeholder means adding it to
[STACK-PROFILE.template.md](STACK-PROFILE.template.md) in the same change. A key the
template does not define is a key nobody will ever set — and the converse holds too:
a template key no skill reads is dead weight that asserts things nothing checks.
Every key earns its row by being read.

### 2. Frontmatter is the matching surface

```yaml
---
name: <folder-name>          # must equal the directory name, exactly
description: "Use when …. Enforces …. Triggers on …."
metadata:
  version: "2.1"
---
```

The `description` decides whether the skill loads at all. Write it for retrieval: the
surface it applies to, the rules it carries, and the phrases a user would actually
type. A skill that never loads has no effect on anything.

### 3. Examples must be correct

Samples are read as reference implementations and copied.

- Every sample compiles under `strict`, with the imports it needs.
- Every sample obeys the rules this set imposes — arrow functions, export blocks,
  `import type`, constrained generics. A skill violating its sibling skill is the most
  damaging defect possible here, and it is how the predecessor set accumulated sixteen
  contradictions before anyone noticed.
- Framework-specific samples match the version the profile names. Tailwind v3 config in
  a v4 project is not a small error; the file is never read.

Before adding a sample, check what the other skills say about the same construct.

### 4. A rule states its reason

A rule with no stated reason gets deleted by the next person, who cannot tell a
deliberate constraint from an accident. Prefer the failure mode to the imperative: *"an
undefined token renders as nothing, in one mode only, and no build step reports it"*
survives an argument that *"define all tokens"* does not.

### 5. Cross-references resolve

Skills reference each other by bare name in backticks — `` `frontend-testing` `` —
and helpers by path-style name — `` `code-style/helpers/generics.md` ``. Renaming or
deleting one means updating every reference, plus this file and the digest.

### 6. Helpers carry depth, not rules

`SKILL.md` holds the rules and stays scannable; a helper holds reference material for
one topic and loads only when needed. When `SKILL.md` outgrows what someone will read
before starting work, move depth into a helper and leave the rule behind. Add the
helper to the parent's helper table.

## Naming

Skill names follow `<surface>-<concern>` in kebab-case. Surface is `backend`,
`frontend`, or `package`; concerns that apply everywhere take no prefix.

- No language or runtime prefixes — `js-` goes stale the moment the repo is
  TypeScript, and says nothing a description cannot.
- No methodology in the name — name the job, teach the technique inside.
- No filler nouns — `-guide`, `-helper`, `-rules` carry no signal. `-checklist`
  survives only where the artifact genuinely is one.
- No abbreviations or numeronyms — `accessibility`, not `a11y`.
- Name the tool when the tool genuinely is the subject, and only then.
- Symmetry is a feature — `backend-testing`/`frontend-testing` and
  `backend-architecture`/`frontend-architecture` let a reader predict a name.

The full rules, including the description convention, live in
[`code-style/helpers/naming-conventions.md`](skills/code-style/helpers/naming-conventions.md)
so the convention is enforced by a skill rather than only documented here.

## Before finishing

```bash
# Folder name matches the declared name
for d in skills/*/; do
  declared=$(grep -m1 "^name:" "$d/SKILL.md" | sed 's/name: *//')
  [ "$declared" = "$(basename "$d")" ] || echo "mismatch: $d declares $declared"
done

# Code fences balanced
for f in skills/*/SKILL.md skills/*/helpers/*.md; do
  n=$(grep -c '^```' "$f"); [ $((n % 2)) -eq 0 ] || echo "odd fences: $f"
done

# Every referenced skill exists
for n in $(grep -rhoE '`(backend|frontend|package|code)-[a-z-]+`' skills/ | tr -d '`' | sort -u); do
  [ -d "skills/$n" ] || echo "dangling reference: $n"
done

# Every path-style helper reference resolves to a file
for p in $(grep -rhoE '`[a-z-]+/helpers/[a-z-]+\.md`' skills/ | tr -d '`' | sort -u); do
  [ -f "skills/$p" ] || echo "dangling helper reference: $p"
done

# No project-specific values leaked in (negative examples carry // wrong on the line)
grep -rnE '@(acme|canopy|util)/|localhost:[0-9]+|/Users/' skills/ | grep -v '<' | grep -v '// wrong'

# Manifests are valid JSON
jq . .claude-plugin/plugin.json .claude-plugin/marketplace.json hooks/hooks.json > /dev/null
```

- [ ] Checks above pass
- [ ] New placeholders added to `STACK-PROFILE.template.md`
- [ ] New skill or helper added to the tables above and the parent's helper table
- [ ] Samples compile and obey the set's own rules
- [ ] `plugin.json` and `marketplace.json` versions bumped together
- [ ] `standards-digest.md` updated when a mandatory rule changes

---

## Provenance

Extracted from an earlier set of project-specific skills that lived beside the
codebase they described. The delivery and workflow tooling — `docker-guide`,
`commit-policy`, and four spec-driven-development skills with their own configuration
and scripts — was dropped as out of scope, and the surviving development guidance was
reorganized along surface boundaries rather than carried over one-to-one, yielding
the ten skills here. Two things came out of that:

**Sixteen internal contradictions were resolved.** The originals told an agent to use
role-based selectors and then demonstrated CSS ones; banned the `function` keyword and
then used it throughout every frontend example; forbade JSDOM component tests and then
presented one as the accessibility check; named two different end-to-end directories;
and shipped Tailwind utilities that could not fire. A rule contradicted by the example
beside it is worse than no rule, because it teaches that the rules are decorative.

**The skills were rewritten against a real stack.** They were originally written for a
generic React/Node project and then applied to one using Tailwind v4, Vite, and
generated component primitives — where several rules could not be followed as written.
The theming guidance imported a config object that did not exist; the component
documentation layout required renaming files a generator would recreate. Those are now
correct, and the vendored-code exemption exists so the remaining rules are enforceable
rather than routinely ignored.
