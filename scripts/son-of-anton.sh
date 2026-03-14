#!/usr/bin/env bash
# son-of-anton.sh — "Son of Anton" heartbeat monitor and Jarvis reporter
#
# Monitors all research teams via pulse files. Detects stale teams and
# breakthroughs. Reports to Jarvis via shared/jarvis-inbox/ and broadcasts
# alerts to all teams via shared/messages/.
#
# Run in its own tmux session:
#   tmux new-session -d -s son-of-anton -c "$(pwd)" "./scripts/son-of-anton.sh"
#
# Usage: ./scripts/son-of-anton.sh [interval_seconds] [stale_threshold_seconds]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PERF_LAB_PROJECT:-$(dirname "$SCRIPT_DIR")}"
CONFIG="$PROJECT_DIR/perf-lab.config.json"
DIRECTION=$(jq -r '.direction // "lower"' "$CONFIG")

SHARED_DIR="$PROJECT_DIR/shared"
PULSE_DIR="$SHARED_DIR/agent-pulse"
BEST_FILE="$SHARED_DIR/best-metric.txt"
INBOX_DIR="$SHARED_DIR/jarvis-inbox"

mkdir -p "$PULSE_DIR" "$INBOX_DIR"

INTERVAL="${1:-60}"
STALE_THRESHOLD="${2:-600}"

LAST_KNOWN_BEST=""
if [[ -f "$BEST_FILE" ]]; then
    LAST_KNOWN_BEST=$(cat "$BEST_FILE" | tr -d '[:space:]')
fi

# Track which agents we've already alerted as stale (avoid spam)
declare -A STALE_ALERTED

is_better() { # $1=new $2=old
    if [[ "$DIRECTION" == "lower" ]]; then
        awk "BEGIN{exit(!($1<$2))}"
    else
        awk "BEGIN{exit(!($1>$2))}"
    fi
}

write_jarvis_report() {
    local TYPE="$1" BODY="$2"
    local TS
    TS=$(date -Iseconds)
    local SAFE_TS
    SAFE_TS=$(echo "$TS" | tr ':' '-')
    cat > "$INBOX_DIR/${SAFE_TS}-${TYPE}.md" <<EOF
# Son of Anton Report
# Type: ${TYPE}
# Timestamp: ${TS}

${BODY}
EOF
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          SON OF ANTON — Fleet Monitor v3                    ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Interval:  ${INTERVAL}s                                          ║"
echo "║  Stale:     ${STALE_THRESHOLD}s                                        ║"
echo "║  Watching:  ${PULSE_DIR}"
echo "║  Inbox:     ${INBOX_DIR}"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

CYCLE=0
while true; do
    NOW=$(date +%s)
    CYCLE=$((CYCLE + 1))
    ACTIVE_COUNT=0
    STALE_COUNT=0
    TOTAL_EXPERIMENTS=0
    TOTAL_KEPT=0

    # Check each agent's pulse
    if [[ -d "$PULSE_DIR" ]]; then
        for PULSE in "$PULSE_DIR"/*.json; do
            [[ ! -f "$PULSE" ]] && continue
            AGENT=$(basename "$PULSE" .json)
            LAST_TS=$(jq -r '.last_activity // ""' "$PULSE" 2>/dev/null || true)
            P_TOTAL=$(jq -r '.experiments_total // 0' "$PULSE" 2>/dev/null || echo 0)
            P_KEPT=$(jq -r '.experiments_kept // 0' "$PULSE" 2>/dev/null || echo 0)

            TOTAL_EXPERIMENTS=$((TOTAL_EXPERIMENTS + P_TOTAL))
            TOTAL_KEPT=$((TOTAL_KEPT + P_KEPT))

            if [[ -z "$LAST_TS" ]]; then
                continue
            fi

            LAST_EPOCH=$(date -d "$LAST_TS" +%s 2>/dev/null || echo 0)
            AGE_SECS=$(( NOW - LAST_EPOCH ))

            if (( AGE_SECS > STALE_THRESHOLD )); then
                STALE_COUNT=$((STALE_COUNT + 1))
                # Only alert once per stale agent (reset if they come back)
                if [[ -z "${STALE_ALERTED[$AGENT]:-}" ]]; then
                    echo "[son-of-anton] $(date '+%H:%M:%S') STALE: $AGENT — ${AGE_SECS}s since last pulse"
                    if [[ -x "$SCRIPT_DIR/messages.sh" ]]; then
                        "$SCRIPT_DIR/messages.sh" send son-of-anton all stale-agent \
                            "Agent $AGENT has not reported in ${AGE_SECS}s. May be stuck or finished." || true
                    fi
                    write_jarvis_report "stale-agent" "Agent $AGENT has not reported in ${AGE_SECS}s."
                    STALE_ALERTED[$AGENT]=1
                fi
            else
                ACTIVE_COUNT=$((ACTIVE_COUNT + 1))
                # Clear stale alert if agent comes back
                unset "STALE_ALERTED[$AGENT]" 2>/dev/null || true
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
            echo "[son-of-anton] $(date '+%H:%M:%S') FIRST BEST: $CURRENT_BEST"
            write_jarvis_report "first-best" "First best metric established: $CURRENT_BEST"
            LAST_KNOWN_BEST="$CURRENT_BEST"
        elif is_better "$CURRENT_BEST" "$LAST_KNOWN_BEST"; then
            echo "[son-of-anton] $(date '+%H:%M:%S') BREAKTHROUGH: $CURRENT_BEST (was $LAST_KNOWN_BEST)"
            if [[ -x "$SCRIPT_DIR/messages.sh" ]]; then
                "$SCRIPT_DIR/messages.sh" send son-of-anton all breakthrough \
                    "NEW BEST: $CURRENT_BEST (was $LAST_KNOWN_BEST)" || true
            fi
            write_jarvis_report "breakthrough" \
                "NEW BEST: $CURRENT_BEST (was $LAST_KNOWN_BEST). Check experiments.tsv for the winning strategy."
            LAST_KNOWN_BEST="$CURRENT_BEST"
        else
            LAST_KNOWN_BEST="$CURRENT_BEST"
        fi
    fi

    # Periodic status line (every 5 cycles)
    if (( CYCLE % 5 == 0 )); then
        echo "[son-of-anton] $(date '+%H:%M:%S') cycle=$CYCLE active=$ACTIVE_COUNT stale=$STALE_COUNT experiments=$TOTAL_EXPERIMENTS kept=$TOTAL_KEPT best=${CURRENT_BEST:-?}"
    fi

    sleep "$INTERVAL"
done
