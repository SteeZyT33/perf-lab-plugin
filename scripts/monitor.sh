#!/usr/bin/env bash
# monitor.sh — Background heartbeat monitor with breakthrough detection
#
# Polls agent pulse files for staleness and detects metric breakthroughs.
# Run in its own tmux session: tmux new-session -d -s monitor ./scripts/monitor.sh
#
# Usage: ./scripts/monitor.sh [interval_seconds] [stale_threshold_seconds]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PERF_LAB_PROJECT:-$(dirname "$SCRIPT_DIR")}"
CONFIG="$PROJECT_DIR/perf-lab.config.json"
DIRECTION=$(jq -r '.direction // "lower"' "$CONFIG")

SHARED_DIR="$PROJECT_DIR/shared"
PULSE_DIR="$SHARED_DIR/agent-pulse"
BEST_FILE="$SHARED_DIR/best-metric.txt"

INTERVAL="${1:-60}"
STALE_THRESHOLD="${2:-600}"

LAST_KNOWN_BEST=""
if [[ -f "$BEST_FILE" ]]; then
    LAST_KNOWN_BEST=$(cat "$BEST_FILE" | tr -d '[:space:]')
fi

is_better() { # $1=new $2=old
    if [[ "$DIRECTION" == "lower" ]]; then
        awk "BEGIN{exit(!($1<$2))}"
    else
        awk "BEGIN{exit(!($1>$2))}"
    fi
}

echo "[monitor] Started — checking every ${INTERVAL}s, stale threshold ${STALE_THRESHOLD}s"
echo "[monitor] Watching: $PULSE_DIR"
echo "[monitor] Best file: $BEST_FILE"
echo ""

while true; do
    NOW=$(date +%s)

    # Check each agent's pulse
    if [[ -d "$PULSE_DIR" ]]; then
        for PULSE in "$PULSE_DIR"/*.json; do
            [[ ! -f "$PULSE" ]] && continue
            AGENT=$(basename "$PULSE" .json)
            LAST_TS=$(jq -r '.last_activity // ""' "$PULSE" 2>/dev/null || true)

            if [[ -z "$LAST_TS" ]]; then
                continue
            fi

            LAST_EPOCH=$(date -d "$LAST_TS" +%s 2>/dev/null || echo 0)
            AGE_SECS=$(( NOW - LAST_EPOCH ))

            if (( AGE_SECS > STALE_THRESHOLD )); then
                echo "[monitor] $(date -Iseconds) STALE: $AGENT — no pulse in ${AGE_SECS}s"
                if [[ -x "$SCRIPT_DIR/messages.sh" ]]; then
                    "$SCRIPT_DIR/messages.sh" send monitor all stale-agent \
                        "Agent $AGENT has not reported in ${AGE_SECS}s. May be stuck or finished." || true
                fi
            fi
        done
    fi

    # Detect breakthrough (best-metric.txt changed)
    CURRENT_BEST=""
    if [[ -f "$BEST_FILE" ]]; then
        CURRENT_BEST=$(cat "$BEST_FILE" | tr -d '[:space:]')
    fi

    if [[ -n "$CURRENT_BEST" && "$CURRENT_BEST" != "$LAST_KNOWN_BEST" ]]; then
        if [[ -z "$LAST_KNOWN_BEST" ]]; then
            # First best established
            echo "[monitor] $(date -Iseconds) FIRST BEST: $CURRENT_BEST"
            LAST_KNOWN_BEST="$CURRENT_BEST"
        elif is_better "$CURRENT_BEST" "$LAST_KNOWN_BEST"; then
            echo "[monitor] $(date -Iseconds) BREAKTHROUGH: $CURRENT_BEST (was $LAST_KNOWN_BEST)"
            if [[ -x "$SCRIPT_DIR/messages.sh" ]]; then
                "$SCRIPT_DIR/messages.sh" send monitor all breakthrough \
                    "NEW BEST: $CURRENT_BEST (was $LAST_KNOWN_BEST)"
            fi
            LAST_KNOWN_BEST="$CURRENT_BEST"
        else
            # Value changed but isn't better — track it anyway
            LAST_KNOWN_BEST="$CURRENT_BEST"
        fi
    fi

    sleep "$INTERVAL"
done
