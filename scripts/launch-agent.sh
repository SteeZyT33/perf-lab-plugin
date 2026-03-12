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
WORKTREE_DIR="$HOME/${AGENT}"
PROMPT_SRC="$PROJECT_DIR/prompts/${AGENT}.md"
PROMPT_DST="$HOME/${AGENT}-prompt.md"

# Validate agent is in config
if ! jq -e --arg a "$AGENT" '.agents | index($a)' "$CONFIG" &>/dev/null; then
    echo -e "${YELLOW}Warning: '$AGENT' not in config agents list${NC}"
fi

if [[ ! -d "$WORKTREE_DIR" ]]; then
    echo -e "${RED}Error: Worktree not found at $WORKTREE_DIR${NC}"
    echo "Run ./scripts/setup-worktrees.sh first."
    exit 1
fi

if [[ ! -f "$PROMPT_SRC" ]]; then
    echo -e "${RED}Error: Prompt not found at $PROMPT_SRC${NC}"
    exit 1
fi

cp "$PROMPT_SRC" "$PROMPT_DST"
echo -e "${GREEN}Prompt copied to: $PROMPT_DST${NC}"

if tmux has-session -t "$AGENT" 2>/dev/null; then
    echo -e "${YELLOW}tmux session '$AGENT' already exists. Attach with: tmux attach -t $AGENT${NC}"
    exit 0
fi

echo -e "${CYAN}Creating tmux session: $AGENT${NC}"
tmux new-session -d -s "$AGENT" -c "$WORKTREE_DIR"
tmux send-keys -t "$AGENT" "export CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000" Enter
tmux send-keys -t "$AGENT" "claude" Enter

echo ""
echo -e "${BOLD}${GREEN}Agent $AGENT launched.${NC}"
echo "  Worktree:  $WORKTREE_DIR"
echo "  Branch:    perf-lab/$AGENT"
echo "  Session:   tmux attach -t $AGENT"
echo "  Prompt:    $PROMPT_DST"
echo ""
echo -e "${YELLOW}Paste the prompt from $PROMPT_DST into the claude session.${NC}"
