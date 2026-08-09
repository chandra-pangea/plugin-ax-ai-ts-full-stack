#!/bin/sh
# Global install of the ts-full-stack skill set for tools that read the open
# Agent Skills standard (Cursor 2.4+, Codex, Gemini CLI) — no per-repo files.
#
# Claude Code users do NOT need this script; they install the repo as a plugin:
#   claude plugin marketplace add <path-or-url-of-this-repo>
#   /plugin install ts-full-stack@ax-ai-skills
#
# Usage:
#   ./install.sh              symlink skills + inject digest (idempotent; re-run to update)
#   ./install.sh --copy       copy instead of symlink (for machines that drop the clone)
#   ./install.sh --force      replace existing non-symlink skill dirs
#   ./install.sh --uninstall  remove symlinks/copies and digest blocks

set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILLS_SRC="$REPO_DIR/skills"
DIGEST_SRC="$REPO_DIR/standards-digest.md"
MARKER_BEGIN="<!-- ts-full-stack:begin -->"
MARKER_END="<!-- ts-full-stack:end -->"

SKILL_DIRS="$HOME/.agents/skills $HOME/.cursor/skills"
MEMORY_FILES="$HOME/.cursor/AGENTS.md $HOME/.codex/AGENTS.md $HOME/.gemini/GEMINI.md"

MODE="link"
FORCE="no"
for arg in "$@"; do
  case "$arg" in
    --copy) MODE="copy" ;;
    --force) FORCE="yes" ;;
    --uninstall) MODE="uninstall" ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

# Removes the managed digest block from one memory file, in place.
strip_block() {
  file="$1"
  [ -f "$file" ] || return 0
  tmp="$file.ts-full-stack.tmp"
  awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

if [ "$MODE" = "uninstall" ]; then
  for dir in $SKILL_DIRS; do
    for src in "$SKILLS_SRC"/*/; do
      name=$(basename "$src")
      target="$dir/$name"
      if [ -L "$target" ]; then
        rm "$target"; echo "removed link $target"
      elif [ -d "$target" ]; then
        rm -rf "$target"; echo "removed copy $target"
      fi
    done
  done
  for file in $MEMORY_FILES; do
    if [ -f "$file" ] && grep -qF "$MARKER_BEGIN" "$file"; then
      strip_block "$file"; echo "removed digest block from $file"
    fi
  done
  echo "uninstalled."
  exit 0
fi

# 1. Skills — one entry per skill, symlinked (or copied) from this clone.
for dir in $SKILL_DIRS; do
  mkdir -p "$dir"
  for src in "$SKILLS_SRC"/*/; do
    name=$(basename "$src")
    target="$dir/$name"
    if [ -e "$target" ] && [ ! -L "$target" ] && [ "$FORCE" != "yes" ]; then
      echo "skip $target: exists and is not a symlink (use --force to replace)" >&2
      continue
    fi
    rm -rf "$target"
    if [ "$MODE" = "copy" ]; then
      cp -R "$SKILLS_SRC/$name" "$target"
    else
      ln -s "$SKILLS_SRC/$name" "$target"
    fi
  done
  echo "installed skills into $dir ($MODE)"
done

# 2. Digest — managed marker block in each tool's global memory file, replaced on re-run.
for file in $MEMORY_FILES; do
  mkdir -p "$(dirname "$file")"
  [ -f "$file" ] && strip_block "$file"
  {
    [ -f "$file" ] && cat "$file"
    echo "$MARKER_BEGIN"
    cat "$DIGEST_SRC"
    echo "$MARKER_END"
  } > "$file.ts-full-stack.new"
  mv "$file.ts-full-stack.new" "$file"
  echo "wrote digest block into $file"
done

echo
echo "done. update later with: git -C \"$REPO_DIR\" pull && \"$REPO_DIR/install.sh\"$([ "$MODE" = "copy" ] && echo ' --copy')"
echo "if your Cursor version predates global AGENTS.md support, paste the digest"
echo "($DIGEST_SRC) into Cursor Settings > Rules for AI instead."
