# Full-Stack Skill Set

Ten portable agent skills for JavaScript/TypeScript full-stack development.
They carry no project names, no package scopes, and no hardcoded paths — a
`STACK-PROFILE.md` at the consuming repo's root supplies those, and each skill falls
back to detecting them from the repo when the profile is absent.

Delivery concerns — container packaging and commit policy — are deliberately out of
scope. This set governs how code is written and verified, not how it ships.

Works with Claude Code and Cursor.

```
skills/                     the ten skills — the whole deliverable
STACK-PROFILE.template.md   what a consuming repo fills in
README.md                   this file: the set, how to install it, how to change it
```

There is no application here and no installed copy of the skills — no
`.claude/skills/`, no `.cursor/skills/`. That is deliberate: a skill that only works
where it was written is not portable, and a copy kept beside the source eventually
drifts from it.

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
| [`package-scaffold`](skills/package-scaffold/) | Creating a shared runtime package: folder layout, public-class pattern, config files, package documentation. |
| [`package-checklist`](skills/package-checklist/) | Validating a package — runtime or UI: naming, structure, scripts, exports that actually resolve, README completeness, pre-PR gate. |

### Frontend

| Skill | Governs |
| ----- | ------- |
| [`frontend-architecture`](skills/frontend-architecture/) | One-directional package tiers, component layering, state management, three-layer theming, mobile-first, reuse, performance, and the vendored-primitive exemption. |
| [`frontend-accessibility`](skills/frontend-accessibility/) | WCAG AA, semantic HTML, ARIA, keyboard navigation, focus management, contrast, target size, motion. |
| [`frontend-component-docs`](skills/frontend-component-docs/) | Which layer gets documented, component README, JSDoc props, Storybook stories, documented accessibility. |
| [`frontend-testing`](skills/frontend-testing/) | Playwright end-to-end against a running app. Role-based selectors, required coverage per flow, theming and design-system surfaces. |

---

## Installing

Three steps, run from the consuming project's root:

```bash
SKILLS_REPO=/path/to/this/repo

# 1. Copy the skills. Both editors discover them by the YAML frontmatter in each
#    SKILL.md, so there is no registration step.
mkdir -p .claude/skills .cursor/skills
cp -R "$SKILLS_REPO"/skills/* .claude/skills/
cp -R "$SKILLS_REPO"/skills/* .cursor/skills/

# 2. Write the profile. Every skill reads it before doing anything.
cp "$SKILLS_REPO"/STACK-PROFILE.template.md STACK-PROFILE.md
```

Fill the profile in — it is the whole portability mechanism, and its own instructions
explain which rows matter most and why a wrong row is worse than a missing one.

**3. Wire the routing rules.** Skills load when a task matches their description.
Explicit rules in the project's `AGENTS.md` or `CLAUDE.md` make that deterministic
rather than probabilistic:

```markdown
## Hard routing rules (apply before writing any code)

1. **Backend feature, endpoint, service, or module** → `backend-architecture`
2. **Creating a shared package** → `package-scaffold`, then `package-checklist`
3. **Any JavaScript or TypeScript file** → `code-style`
4. **Backend or package tests** → `backend-testing`
5. **Any UI code** → `frontend-architecture`
6. **UI tests** → `frontend-testing`
7. **Shared UI components** → `frontend-accessibility` and `frontend-component-docs`
8. **Reviews** → `code-review`

If a task touches one of these surfaces and the linked skill was not followed, the
change is incomplete.
```

Cursor applies `AGENTS.md` automatically; for Claude Code, `CLAUDE.md` should contain
`@AGENTS.md` so both editors share one source.

Then verify:

```bash
ls .claude/skills | wc -l                    # ten
diff -rq .claude/skills .cursor/skills       # the two copies agree

for d in .claude/skills/*/; do               # folder name matches declared name
  declared=$(grep -m1 "^name:" "$d/SKILL.md" | sed 's/name: *//')
  [ "$declared" = "$(basename "$d")" ] || echo "mismatch: $d declares $declared"
done
```

Finally, ask the agent something that should route — *"add a rate limiter to the
API"* ought to load `backend-architecture` — and confirm it does.

### Keeping the copies current

The two installed trees are duplicates, so an edit to one that is not mirrored gives
two editors different instructions for the same task — worse than either instruction
alone. Prefer fixing upstream in this repository and re-copying, so the fix reaches
every project rather than one.

Where a project's conventions genuinely differ: change `STACK-PROFILE.md` first, since
most differences are values rather than rules. If a rule truly does not fit, change the
rule and say why in the skill — a rule with no stated reason gets deleted by the next
person.

## Profile keys

Every `<placeholder>` in every skill resolves against `STACK-PROFILE.md`. Start from
[STACK-PROFILE.template.md](STACK-PROFILE.template.md), which carries its own guidance
on which rows matter and how to write the notes column.

Resolution order, identical in all ten skills: profile file → infer from repo
(root `package.json`, lockfile, workspace globs, config files) → match the dominant
convention already present → stated default, written back to the profile.

The frontend keys reward precision, because the wrong answer fails quietly rather than
loudly. `css-framework-version` decides whether a `tailwind.config.ts` is read at all
or is dead weight. `primitives-pkg` being vendored decides which files the style and
documentation rules reach — and makes `wrappers-pkg` mandatory, since a vendored
package is the one place a local change does not survive.

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
- If a skill by one of these names appears in an agent's available-skills list, it came
  from a global configuration or another project. Editing `skills/` will not change it.

This repository keeps no editor memory file — no `AGENTS.md`, no `CLAUDE.md` — so an
agent may need pointing at this section rather than picking it up automatically.

## Hard rules

### 1. Nothing project-specific

This is the rule the whole set exists to satisfy. Every project-specific value is a
`<placeholder>` resolved against `STACK-PROFILE.md` in the consuming repository.
`@acme/logger`, `apps/web`, and `localhost:3000` appear only as illustrations clearly
marked as such.

A skill that assumes a directory name, a package scope, a port, or a framework version
produces wrong instructions in the first project that differs — and produces them
confidently.

Adding a placeholder means adding it to
[STACK-PROFILE.template.md](STACK-PROFILE.template.md) in the same change. A key the
template does not define is a key nobody will ever set.

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

Skills reference each other by bare name in backticks — `` `frontend-testing` ``.
Renaming or deleting one means updating every reference, plus this file.

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

# No project-specific values leaked in
grep -rnE '@(acme|canopy|util)/|localhost:[0-9]+|/Users/' skills/ | grep -v '<'
```

- [ ] Checks above pass
- [ ] New placeholders added to `STACK-PROFILE.template.md`
- [ ] New skill or helper added to the tables above and the parent's helper table
- [ ] Samples compile and obey the set's own rules

---

## Provenance

Extracted from an earlier set of thirteen project-specific skills that lived beside
the codebase they described. Two things came out of that:

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

Dropped along the way: `docker-guide` and `commit-policy` — delivery concerns. How an
image is built and how a commit is worded are real problems, but they are not what
this set is for, and a skill that fires on every `git commit` earns its place only if
the repository asks for it. Also dropped: four spec-driven-development workflow skills
with their own configuration, templates, and Python scripts, which were tooling rather
than development guidance.
