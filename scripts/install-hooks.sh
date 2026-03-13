#!/usr/bin/env bash
# install-hooks.sh — Install perf-lab git hooks (opt-in via config)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${1:-$(dirname "$SCRIPT_DIR")}"
PLUGIN_DIR="${2:-$SCRIPT_DIR/..}"
CONFIG="$PROJECT_DIR/perf-lab.config.json"

# Check if pre-commit hook is enabled in config (default: false)
HOOK_ENABLED=false
if [[ -f "$CONFIG" ]]; then
    HOOK_ENABLED=$(jq -r '.pre_commit_hook // false' "$CONFIG")
fi

if [[ "$HOOK_ENABLED" != "true" ]]; then
    echo "  Pre-commit hook disabled (set \"pre_commit_hook\": true in config to enable)"
    exit 0
fi

HOOKS_DIR="$PROJECT_DIR/.git/hooks"

if [[ ! -d "$PROJECT_DIR/.git" ]]; then
    echo "  Skipping git hooks (not a git repository)"
    exit 0
fi

mkdir -p "$HOOKS_DIR"

HOOK_SRC="$PLUGIN_DIR/hooks/pre-commit.sh"
HOOK_DST="$HOOKS_DIR/pre-commit"

if [[ -f "$HOOK_SRC" ]]; then
    if [[ -f "$HOOK_DST" ]] && ! grep -q "perf-lab" "$HOOK_DST"; then
        echo "  Warning: Existing pre-commit hook found, not overwriting"
        echo "  Merge manually from: $HOOK_SRC"
    else
        cp "$HOOK_SRC" "$HOOK_DST"
        chmod +x "$HOOK_DST"
        echo "  Installed pre-commit hook"
    fi
else
    echo "  Warning: pre-commit.sh not found at $HOOK_SRC"
fi
