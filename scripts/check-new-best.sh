#!/usr/bin/env bash
# check-new-best.sh — Check if another agent posted a new best score

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PERF_LAB_PROJECT:-$(dirname "$SCRIPT_DIR")}"
CONFIG="$PROJECT_DIR/perf-lab.config.json"
METRIC_NAME=$(jq -r '.metric_name' "$CONFIG")

SHARED_DIR="$PROJECT_DIR/shared"
ALERT_FILE="$SHARED_DIR/new-best-alert.txt"
BEST_FILE="$SHARED_DIR/best-metric.txt"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <my-agent-name>"
    exit 1
fi

MY_AGENT="$1"
SEEN_FILE="$SHARED_DIR/.alert-seen-${MY_AGENT}"

if [[ ! -f "$ALERT_FILE" ]]; then
    echo "No new best alerts."
    exit 0
fi

ALERT_CONTENT=$(cat "$ALERT_FILE")

if [[ -f "$SEEN_FILE" ]]; then
    SEEN_CONTENT=$(cat "$SEEN_FILE")
    if [[ "$SEEN_CONTENT" == "$ALERT_CONTENT" ]]; then
        echo "No new alerts (already seen current best)."
        exit 0
    fi
fi

if echo "$ALERT_CONTENT" | grep -q "AGENT ${MY_AGENT} "; then
    echo "Latest best is yours. No action needed."
    echo "$ALERT_CONTENT" > "$SEEN_FILE"
    exit 0
fi

echo ""
echo "*** ALERT: Another agent achieved a new best! ***"
echo "$ALERT_CONTENT"
echo ""
echo "Current best ${METRIC_NAME}: $(cat "$BEST_FILE" 2>/dev/null || echo 'unknown')"
echo "Best solution available at: $SHARED_DIR/best-solution.*"
echo ""
echo "Consider: rebase on the new best or continue your own approach."
echo "$ALERT_CONTENT" > "$SEEN_FILE"
