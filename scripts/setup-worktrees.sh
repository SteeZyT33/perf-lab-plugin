#!/usr/bin/env bash
# setup-worktrees.sh — Create worktrees for parallel agents

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PERF_LAB_PROJECT:-$(dirname "$SCRIPT_DIR")}"
CONFIG="$PROJECT_DIR/perf-lab.config.json"
SHARED_DIR="$PROJECT_DIR/shared"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

readarray -t AGENTS < <(jq -r '.agents[]' "$CONFIG")

echo -e "${BOLD}${CYAN}Setting up parallel agent worktrees...${NC}"
echo ""

cd "$PROJECT_DIR"

for AGENT in "${AGENTS[@]}"; do
    BRANCH="perf-lab/${AGENT}"
    WORKTREE_DIR="$HOME/${AGENT}"

    echo -e "${BOLD}--- Agent: ${AGENT} ---${NC}"

    if ! git rev-parse --verify "$BRANCH" &>/dev/null; then
        echo -e "  ${YELLOW}Creating branch${NC} $BRANCH from HEAD..."
        git branch "$BRANCH" HEAD
    else
        echo -e "  Branch ${GREEN}$BRANCH${NC} already exists."
    fi

    if [[ ! -d "$WORKTREE_DIR" ]]; then
        echo -e "  ${YELLOW}Creating worktree${NC} at $WORKTREE_DIR..."
        git worktree add "$WORKTREE_DIR" "$BRANCH"
    else
        echo -e "  Worktree ${GREEN}$WORKTREE_DIR${NC} already exists."
        CURRENT=$(cd "$WORKTREE_DIR" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        [[ "$CURRENT" != "$BRANCH" ]] && echo -e "  ${YELLOW}Warning: worktree is on $CURRENT, expected $BRANCH${NC}"
    fi

    if [[ -L "$WORKTREE_DIR/shared" ]]; then
        echo -e "  Symlink shared/ ${GREEN}already exists${NC}."
    elif [[ -d "$WORKTREE_DIR/shared" ]]; then
        rm -rf "$WORKTREE_DIR/shared"
        ln -s "$SHARED_DIR" "$WORKTREE_DIR/shared"
    else
        ln -s "$SHARED_DIR" "$WORKTREE_DIR/shared"
    fi

    [[ -f "$PROJECT_DIR/CLAUDE.md" ]] && cp "$PROJECT_DIR/CLAUDE.md" "$WORKTREE_DIR/CLAUDE.md" && echo -e "  ${GREEN}Copied CLAUDE.md${NC}"
    echo ""
done

echo -e "${BOLD}${GREEN}Worktree setup complete.${NC}"
echo ""
for AGENT in "${AGENTS[@]}"; do echo "  ~/${AGENT}  (branch: perf-lab/${AGENT})"; done
echo ""
echo "All worktrees share: $SHARED_DIR"
echo ""
echo "Next: ./scripts/launch-agent.sh <agent-name>"
