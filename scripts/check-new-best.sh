#!/usr/bin/env bash
# check-new-best.sh — Check if another agent posted a new best score (via messages)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PERF_LAB_PROJECT:-$(dirname "$SCRIPT_DIR")}"
CONFIG="$PROJECT_DIR/perf-lab.config.json"
METRIC_NAME=$(jq -r '.metric_name' "$CONFIG")

SHARED_DIR="$PROJECT_DIR/shared"
BEST_FILE="$SHARED_DIR/best-metric.txt"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <my-agent-name>"
    exit 1
fi

MY_AGENT="$1"

# Read unread messages and filter for new-best type
UNREAD=$("$SCRIPT_DIR/messages.sh" read "$MY_AGENT" 2>/dev/null)

if echo "$UNREAD" | grep -q "Type: new-best"; then
    # Extract the message body (lines after the header block)
    BEST_MSG=$(echo "$UNREAD" | grep -A1 "Type: new-best" | grep -v "Type: new-best" | grep -v "^--$" | head -5)
    FROM_AGENT=$(echo "$UNREAD" | grep -B2 "Type: new-best" | grep "From:" | tail -1 | sed 's/# From: //')

    if [[ "$FROM_AGENT" == "$MY_AGENT" ]]; then
        echo "Latest best is yours. No action needed."
        exit 0
    fi

    echo ""
    echo "*** ALERT: Another agent achieved a new best! ***"
    echo "$BEST_MSG"
    echo ""
    echo "Current best ${METRIC_NAME}: $(cat "$BEST_FILE" 2>/dev/null || echo 'unknown')"
    echo "Best solution available at: $SHARED_DIR/best-solution.*"
    echo ""
    echo "Consider: rebase on the new best or continue your own approach."
else
    echo "No new-best alerts for ${MY_AGENT}."
fi
