#!/usr/bin/env bash
# launch-agent.sh — Launch a parallel optimization agent in a tmux session

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PERF_LAB_PROJECT:-$(dirname "$SCRIPT_DIR")}"
CONFIG="$PROJECT_DIR/perf-lab.config.json"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <agent-name>"
    exit 1
fi

AGENT="$1"
WORKTREE_DIR="$PROJECT_DIR/worktrees/${AGENT}"
PROMPT_SRC="$PROJECT_DIR/prompts/${AGENT}.md"
TEMPLATE_SRC="$PROJECT_DIR/prompts/agent-template.md"
PROMPT_DST="$WORKTREE_DIR/${AGENT}-prompt.md"

# Validate agent is in config
if ! jq -e --arg a "$AGENT" '.agents | index($a)' "$CONFIG" &>/dev/null; then
    echo -e "${YELLOW}Warning: '$AGENT' not in config agents list${NC}"
fi

if [[ ! -d "$WORKTREE_DIR" ]]; then
    echo -e "${RED}Error: Worktree not found at $WORKTREE_DIR${NC}"
    echo "Run ./scripts/setup-worktrees.sh first."
    exit 1
fi

# Generate prompt: use per-agent file if it exists, otherwise generate from template
if [[ -f "$PROMPT_SRC" ]]; then
    cp "$PROMPT_SRC" "$PROMPT_DST"
    echo -e "${GREEN}Prompt copied from: $PROMPT_SRC${NC}"
elif [[ -f "$TEMPLATE_SRC" ]]; then
    # Capitalize first letter of agent name for display
    DISPLAY_NAME="$(echo "${AGENT:0:1}" | tr '[:lower:]' '[:upper:]')${AGENT:1}"
    TARGET=$(jq -r '.target // ""' "$CONFIG")
    METRIC=$(jq -r '.metric_name // "metric"' "$CONFIG")
    sed -e "s/{{AGENT_NAME}}/${DISPLAY_NAME}/g" \
        -e "s/{{AGENT_ID}}/${AGENT}/g" \
        -e "s/{{TARGET}}/${TARGET}/g" \
        -e "s/{{METRIC_NAME}}/${METRIC}/g" \
        -e "s/{{STRATEGY_DESCRIPTION}}/General optimization — explore any viable approach/g" \
        "$TEMPLATE_SRC" > "$PROMPT_DST"
    echo -e "${GREEN}Prompt generated from template for: $AGENT${NC}"
else
    echo -e "${RED}Error: No prompt found at $PROMPT_SRC and no template at $TEMPLATE_SRC${NC}"
    exit 1
fi

if tmux has-session -t "$AGENT" 2>/dev/null; then
    echo -e "${YELLOW}tmux session '$AGENT' already exists. Attach with: tmux attach -t $AGENT${NC}"
    exit 0
fi

echo -e "${CYAN}Creating tmux session: $AGENT${NC}"

# Write a launcher script that passes the prompt as a positional argument to claude.
# This avoids tmux send-keys timing issues and eliminates manual prompt pasting.
# The prompt is passed via "$(cat <file>)" so claude receives it as its initial message
# and starts working immediately. After claude exits, drop into bash so the tmux
# session stays alive for inspection.
LAUNCHER="$WORKTREE_DIR/.perf-lab-launch.sh"
cat > "$LAUNCHER" <<LAUNCHER_EOF
#!/usr/bin/env bash
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000
claude --dangerously-skip-permissions "\$(cat '${PROMPT_DST}')"
exec bash
LAUNCHER_EOF
chmod +x "$LAUNCHER"

tmux new-session -d -s "$AGENT" -c "$WORKTREE_DIR" "$LAUNCHER"

echo ""
echo -e "${BOLD}${GREEN}Agent $AGENT launched.${NC}"
echo "  Worktree:  $WORKTREE_DIR"
echo "  Branch:    perf-lab/$AGENT"
echo "  Session:   tmux attach -t $AGENT"
echo "  Prompt:    $PROMPT_DST"
echo ""
echo -e "${GREEN}Prompt was passed directly to claude — agent is already working.${NC}"
