# plugin-ax-ai-ts-full-stack

Aatmix's TypeScript/JS full-stack coding skills, packaged as a native coding-CLI plugin for **both** Claude Code and
Codex. Consumed by the Aatmix platform via `aatmix/config/plugins.yaml` (fetched from this repo by `url` + `ref`).

Layout (per-CLI folder, as the platform's plugin fetcher expects):

- `claude/.claude-plugin/plugin.json` + `claude/skills/` — the Claude Code plugin
- `codex/.codex-plugin/plugin.json`   + `codex/skills/`  — the Codex plugin

Ten skills: backend/frontend architecture, zero-mock backend/frontend testing, code-style, code-review,
frontend-accessibility, frontend-component-docs, package-scaffold, package-checklist.

> No hooks / MCP servers / symlinks — the Aatmix platform rejects plugins that declare any of those. (The former
> SessionStart standards-digest hook was removed for platform compliance.)
