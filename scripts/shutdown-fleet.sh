#!/usr/bin/env bash
# shutdown-fleet.sh — Kill all perf-lab tmux sessions and clean up
#
# Usage: ./scripts/shutdown-fleet.sh [--force]
#   Without --force: lists sessions and asks for confirmation
#   With --force: kills immediately (for scripted use)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PERF_LAB_PROJECT:-$(dirname "$SCRIPT_DIR")}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

GREEK_NAMES="alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega"
FORCE="${1:-}"

# Find all perf-lab related tmux sessions
SESSIONS=()
for name in $GREEK_NAMES son-of-anton; do
    if tmux has-session -t "$name" 2>/dev/null; then
        SESSIONS+=("$name")
    fi
done

if [[ ${#SESSIONS[@]} -eq 0 ]]; then
    echo -e "${GREEN}No perf-lab sessions running.${NC}"
    exit 0
fi

echo -e "${BOLD}Active perf-lab sessions:${NC}"
for s in "${SESSIONS[@]}"; do
    echo -e "  ${YELLOW}$s${NC}"
done
echo ""

if [[ "$FORCE" != "--force" ]]; then
    echo -n "Kill all ${#SESSIONS[@]} sessions? [y/N] "
    read -r REPLY
    if [[ "$REPLY" != "y" && "$REPLY" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi
fi

for s in "${SESSIONS[@]}"; do
    tmux kill-session -t "$s" 2>/dev/null && echo -e "  ${RED}Killed${NC} $s" || echo "  $s already dead"
done

echo ""
echo -e "${GREEN}Fleet shutdown complete. ${#SESSIONS[@]} sessions killed.${NC}"
echo "Run /perf-lab:jarvis launch to restart."
