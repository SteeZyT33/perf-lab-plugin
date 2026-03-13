#!/usr/bin/env bash
# install.sh — Install perf-lab-plugin into a target project
#
# Usage: ./install.sh [target-dir]  (defaults to current directory)

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-$(pwd)}"
TARGET="$(cd "$TARGET" && pwd)"

if ! command -v jq &>/dev/null; then
    echo "Error: jq is required. Install with: sudo apt install jq"
    exit 1
fi

echo "Installing perf-lab-plugin into: $TARGET"
echo ""

# Skills (merge into existing directory; remove placeholder file if present)
[[ -f "$TARGET/.claude/skills" ]] && rm "$TARGET/.claude/skills"
mkdir -p "$TARGET/.claude/skills"
cp -a "$PLUGIN_DIR/skills/." "$TARGET/.claude/skills/"
echo "  Copied skills → .claude/skills/"

# Agents
[[ -f "$TARGET/.claude/agents" ]] && rm "$TARGET/.claude/agents"
mkdir -p "$TARGET/.claude/agents"
cp -a "$PLUGIN_DIR/agents/." "$TARGET/.claude/agents/"
echo "  Copied agents → .claude/agents/"

# Scripts
mkdir -p "$TARGET/scripts"
cp -a "$PLUGIN_DIR/scripts/." "$TARGET/scripts/"
chmod +x "$TARGET/scripts/"*.sh
echo "  Copied scripts → scripts/ (chmod +x)"

# Shared directory
mkdir -p "$TARGET/shared/Research"
if [[ ! -f "$TARGET/shared/experiments.tsv" ]]; then
    CONFIG="$TARGET/perf-lab.config.json"
    if [[ -f "$CONFIG" ]]; then
        METRIC=$(jq -r '.metric_name' "$CONFIG")
    else
        METRIC="metric"
    fi
    echo -e "timestamp\tagent\titeration\thypothesis\t${METRIC}_before\t${METRIC}_after\tstatus\tnotes" > "$TARGET/shared/experiments.tsv"
fi
echo "  Created shared/ with experiments.tsv"

# Learned constraints
if [[ ! -f "$TARGET/shared/learned-constraints.md" ]]; then
    cp "$PLUGIN_DIR/templates/learned-constraints.md" "$TARGET/shared/"
fi
echo "  Copied learned-constraints.md template"

# Prompt templates
mkdir -p "$TARGET/prompts"
cp "$PLUGIN_DIR/templates/prompts/"*.md "$TARGET/prompts/"
echo "  Copied prompt templates → prompts/"

# Config
if [[ ! -f "$TARGET/perf-lab.config.json" ]]; then
    cp "$PLUGIN_DIR/templates/perf-lab.config.json" "$TARGET/"
    echo "  Created perf-lab.config.json (EDIT THIS for your project)"
else
    echo "  perf-lab.config.json already exists, skipping"
fi

# CLAUDE.md
SECTION_MARKER="## Experiment Protocol (perf-lab)"
if [[ -f "$TARGET/CLAUDE.md" ]]; then
    if ! grep -q "$SECTION_MARKER" "$TARGET/CLAUDE.md"; then
        echo "" >> "$TARGET/CLAUDE.md"
        cat "$PLUGIN_DIR/templates/claude-md-section.md" >> "$TARGET/CLAUDE.md"
        echo "  Appended experiment protocol to CLAUDE.md"
    else
        echo "  CLAUDE.md already has experiment protocol section"
    fi
else
    cp "$PLUGIN_DIR/templates/claude-md-section.md" "$TARGET/CLAUDE.md"
    echo "  Created CLAUDE.md from template"
fi

echo ""
echo "Done! Next steps:"
echo "  1. Edit perf-lab.config.json with your metric, test command, and targets"
echo "  2. Edit prompts/*.md with agent-specific strategies"
echo "  3. Run: ./scripts/setup-worktrees.sh"
echo "  4. Run: ./scripts/launch-agent.sh <agent-name>"
echo "  5. Or use: /perf-lab:experiment for single iterations"
