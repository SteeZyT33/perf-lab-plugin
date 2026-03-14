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

# Install Python dependency for paper parsing
if ! python3 -c "import llama_parse" 2>/dev/null; then
    echo "Installing llama-parse for paper processing..."
    pip install llama-parse --break-system-packages --quiet 2>/dev/null || \
        pip install llama-parse --quiet 2>/dev/null || \
        echo "  Warning: Could not install llama-parse. Paper parsing will be unavailable."
fi

if ! python3 -c "from google import genai" 2>/dev/null; then
    echo "Installing google-genai for diagram generation..."
    pip install google-genai --break-system-packages --quiet 2>/dev/null || \
        pip install google-genai --quiet 2>/dev/null || \
        echo "  Warning: Could not install google-genai. Diagram generation will be unavailable."
fi

echo "Installing perf-lab-plugin into: $TARGET"
echo ""

# Configure local plugin as a directory-based marketplace for instant updates
mkdir -p "$TARGET/.claude"
SETTINGS_FILE="$TARGET/.claude/settings.local.json"
MARKETPLACE_KEY="perf-lab"
if [[ -f "$SETTINGS_FILE" ]]; then
    # Add marketplace entry if not already present
    if ! jq -e ".extraKnownMarketplaces.\"${MARKETPLACE_KEY}\"" "$SETTINGS_FILE" &>/dev/null; then
        jq --arg path "$PLUGIN_DIR" '.extraKnownMarketplaces["perf-lab"] = {"source": {"source": "directory", "path": $path}}' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"
        mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
        echo "  Added local plugin marketplace to .claude/settings.local.json"
    else
        echo "  Local plugin marketplace already in .claude/settings.local.json"
    fi
else
    jq -n --arg path "$PLUGIN_DIR" '{"extraKnownMarketplaces": {"perf-lab": {"source": {"source": "directory", "path": $path}}}}' > "$SETTINGS_FILE"
    echo "  Created .claude/settings.local.json with local plugin marketplace"
fi
echo "  Run '/plugin install perf-lab@perf-lab' in the target project to activate"

# Scripts
mkdir -p "$TARGET/scripts"
cp -a "$PLUGIN_DIR/scripts/." "$TARGET/scripts/"
chmod +x "$TARGET/scripts/"*.sh
echo "  Copied scripts → scripts/ (chmod +x)"

# Shared directory
mkdir -p "$TARGET/shared/Research/papers" "$TARGET/shared/Research/findings" "$TARGET/shared/agent-pulse" "$TARGET/shared/agent-journal" "$TARGET/shared/jarvis-inbox" "$TARGET/shared/knowledge/notebooks"
if [[ ! -f "$TARGET/shared/experiments.tsv" ]]; then
    CONFIG="$TARGET/perf-lab.config.json"
    if [[ -f "$CONFIG" ]]; then
        METRIC=$(jq -r '.metric_name' "$CONFIG")
    else
        METRIC="metric"
    fi
    echo -e "timestamp\tagent\titeration\thypothesis\t${METRIC}_before\t${METRIC}_after\tstatus\tnotes\tduration_seconds\ttechnique" > "$TARGET/shared/experiments.tsv"
fi
if [[ ! -f "$TARGET/shared/technique-index.tsv" ]]; then
    echo -e "technique\tattempts\tkept\tdiscarded\tfailed\tbest_result\tlast_agent\tlast_updated" > "$TARGET/shared/technique-index.tsv"
fi
echo "  Created shared/ with experiments.tsv and technique-index.tsv"

# Learned constraints
if [[ ! -f "$TARGET/shared/learned-constraints.md" ]]; then
    cp "$PLUGIN_DIR/templates/learned-constraints.md" "$TARGET/shared/"
fi
echo "  Copied learned-constraints.md template"

# Architecture changelog
if [[ ! -f "$TARGET/shared/architecture-changelog.md" ]]; then
    cp "$PLUGIN_DIR/templates/architecture-changelog.md" "$TARGET/shared/"
fi
echo "  Created architecture-changelog.md"

# Prompt templates
mkdir -p "$TARGET/prompts"
cp "$PLUGIN_DIR/templates/prompts/agent-template.md" "$TARGET/prompts/"
echo "  Copied agent-template.md → prompts/"

# Config
if [[ ! -f "$TARGET/perf-lab.config.json" ]]; then
    cp "$PLUGIN_DIR/templates/perf-lab.config.json" "$TARGET/"
    echo "  Created perf-lab.config.json (EDIT THIS for your project)"
else
    echo "  perf-lab.config.json already exists, skipping"
fi

# Git hooks
"$PLUGIN_DIR/scripts/install-hooks.sh" "$TARGET" "$PLUGIN_DIR"

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

# API key warnings
echo ""
if [[ -z "${LLAMA_CLOUD_API_KEY:-}" ]]; then
    echo "  Note: LLAMA_CLOUD_API_KEY not set. Paper parsing (LlamaParse) will be unavailable."
    echo "        Set it or add to perf-lab.config.json at research.llama_cloud_api_key"
fi
if [[ -z "${SEMANTIC_SCHOLAR_API_KEY:-}" ]]; then
    echo "  Note: SEMANTIC_SCHOLAR_API_KEY not set. Paper search will use free tier (low rate limits)."
    echo "        Get a key at https://www.semanticscholar.org/product/api#api-key-form"
fi
if [[ -z "${GEMINI_API_KEY:-}" ]]; then
    echo "  Note: GEMINI_API_KEY not set. Diagram generation (Nano Banana 2) will be unavailable."
fi

echo ""
echo "Done! Plugin installed via local reference (instant updates, no marketplace)."
echo ""
echo "Next steps:"
echo "  1. Edit perf-lab.config.json with your metric, test command, and targets"
echo "  2. Edit prompts/*.md with agent-specific strategies"
echo "  3. Run /perf-lab:jarvis to launch research teams (Jarvis5A orchestrator)"
echo "  4. Or run /perf-lab:experiment for single iterations"
