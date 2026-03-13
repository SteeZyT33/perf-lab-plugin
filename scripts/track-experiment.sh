#!/usr/bin/env bash
# track-experiment.sh — Log an experiment result to shared/experiments.tsv
#
# Usage: ./scripts/track-experiment.sh <agent> "<hypothesis>" <KEPT|DISCARDED|FAILED|EXPLORING> ["notes"]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PERF_LAB_PROJECT:-$(dirname "$SCRIPT_DIR")}"
CONFIG="$PROJECT_DIR/perf-lab.config.json"
METRIC_NAME=$(jq -r '.metric_name' "$CONFIG")
TEST_CMD=$(jq -r '.test_command' "$CONFIG")
PARSE_CMD=$(jq -r '.parse_metric' "$CONFIG")
DIRECTION=$(jq -r '.direction // "lower"' "$CONFIG")
SOLUTION_FILE=$(jq -r '.solution_file' "$CONFIG")

SHARED_DIR="$PROJECT_DIR/shared"
TSV="$SHARED_DIR/experiments.tsv"
BEST_FILE="$SHARED_DIR/best-metric.txt"
BEST_SOLUTION="$SHARED_DIR/best-solution.${SOLUTION_FILE##*.}"
CONSTRAINTS="$SHARED_DIR/learned-constraints.md"

is_better() { # $1=new $2=old
  if [[ "$DIRECTION" == "lower" ]]; then
    awk "BEGIN{exit(!($1<$2))}"
  else
    awk "BEGIN{exit(!($1>$2))}"
  fi
}

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <agent> <hypothesis> <KEPT|DISCARDED|FAILED|EXPLORING> [notes]"
    exit 1
fi

AGENT="$1"; HYPOTHESIS="$2"; STATUS="$3"; NOTES="${4:-}"

if [[ "$STATUS" != "KEPT" && "$STATUS" != "DISCARDED" && "$STATUS" != "FAILED" && "$STATUS" != "EXPLORING" ]]; then
    echo "Error: status must be KEPT, DISCARDED, FAILED, or EXPLORING (got: $STATUS)"
    exit 1
fi

if [[ ! -f "$TSV" ]]; then
    echo -e "timestamp\tagent\titeration\thypothesis\t${METRIC_NAME}_before\t${METRIC_NAME}_after\tstatus\tnotes\tduration_seconds" > "$TSV"
fi

METRIC_BEFORE="-"
if [[ -f "$BEST_FILE" ]]; then METRIC_BEFORE=$(cat "$BEST_FILE" | tr -d '[:space:]'); fi

TIMESTAMP=$(date -Iseconds)
START_EPOCH=$(date +%s)

if [[ "$STATUS" == "FAILED" ]]; then
    METRIC_AFTER="-"
    [[ -z "$NOTES" ]] && NOTES="correctness check failed"
else
    echo "Running tests to capture ${METRIC_NAME}..."
    TEST_OUTPUT=$(cd "$PROJECT_DIR" && eval "$TEST_CMD" 2>&1) || true
    METRIC_AFTER=$(echo "$TEST_OUTPUT" | eval "$PARSE_CMD" | head -1)
    if [[ -z "$METRIC_AFTER" ]]; then
        echo "Warning: Could not parse ${METRIC_NAME} from test output."
        echo "$TEST_OUTPUT" | tail -20
        METRIC_AFTER="-"
    else
        echo "${METRIC_NAME}: $METRIC_AFTER"
    fi
fi

END_EPOCH=$(date +%s)
DURATION=$((END_EPOCH - START_EPOCH))

# Compute wall-clock duration from previous experiment by this agent (if available)
PREV_TS=$(awk -F'\t' -v a="$AGENT" '$2==a {ts=$1} END{print ts}' "$TSV")
if [[ -n "$PREV_TS" && "$PREV_TS" != "timestamp" ]]; then
    PREV_EPOCH=$(date -d "$PREV_TS" +%s 2>/dev/null || echo "")
    if [[ -n "$PREV_EPOCH" ]]; then
        WALL_DURATION=$(( $(date -d "$TIMESTAMP" +%s) - PREV_EPOCH ))
        # Use wall-clock if test duration is trivially small
        if (( DURATION < 5 && WALL_DURATION > 5 )); then
            DURATION=$WALL_DURATION
        fi
    fi
fi

# Atomic TSV append with file locking for multi-agent safety
(
    flock -x 200
    LAST_ITER=$(tail -n 1 "$TSV" | cut -f3)
    if [[ "$LAST_ITER" == "iteration" || -z "$LAST_ITER" ]]; then ITER=1; else ITER=$((LAST_ITER + 1)); fi
    echo -e "${TIMESTAMP}\t${AGENT}\t${ITER}\t${HYPOTHESIS}\t${METRIC_BEFORE}\t${METRIC_AFTER}\t${STATUS}\t${NOTES}\t${DURATION}" >> "$TSV"
) 200>"$TSV.lock"

# Read back the iteration number we just wrote
ITER=$(tail -n 1 "$TSV" | cut -f3)
echo "Logged experiment #${ITER} by ${AGENT}: ${STATUS} — ${HYPOTHESIS} (${DURATION}s)"

# Bootstrap: first KEPT experiment establishes the baseline best
if [[ "$STATUS" == "KEPT" && "$METRIC_AFTER" != "-" ]]; then
    if [[ "$METRIC_BEFORE" == "-" ]]; then
        echo "$METRIC_AFTER" > "$BEST_FILE"
        cp "$PROJECT_DIR/$SOLUTION_FILE" "$BEST_SOLUTION"
        echo ""
        echo "*** FIRST BEST ESTABLISHED: ${METRIC_AFTER} ${METRIC_NAME} ***"
    elif is_better "$METRIC_AFTER" "$METRIC_BEFORE"; then
        echo "$METRIC_AFTER" > "$BEST_FILE"
        cp "$PROJECT_DIR/$SOLUTION_FILE" "$BEST_SOLUTION"
        # Send message to all agents
        if [[ -x "$SCRIPT_DIR/messages.sh" ]]; then
            "$SCRIPT_DIR/messages.sh" send "$AGENT" all new-best \
                "NEW BEST: ${METRIC_AFTER} ${METRIC_NAME} (was ${METRIC_BEFORE}). Strategy: ${HYPOTHESIS}"
        fi
        echo ""
        echo "*** NEW BEST: ${METRIC_AFTER} ${METRIC_NAME} (was ${METRIC_BEFORE}) ***"
    fi
fi

# Auto-extract constraints from DISCARDED experiments
if [[ "$STATUS" == "DISCARDED" && -n "$NOTES" && -f "$CONSTRAINTS" ]]; then
    # Check for constraint-like language in notes
    if echo "$NOTES" | grep -qiP 'impossible|overflow|blocked by|can.t because|limited by|no room|saturated|maxed|won.t fit|dependency|too (many|large|slow)'; then
        CONSTRAINT_LINE="- ${HYPOTHESIS}: ${NOTES} (experiment #${ITER}, $(date +%Y-%m-%d))"
        # Append under Auto-Extracted section, creating it if needed
        if grep -q "^## Auto-Extracted" "$CONSTRAINTS"; then
            echo "$CONSTRAINT_LINE" >> "$CONSTRAINTS"
        else
            printf '\n## Auto-Extracted\n\n%s\n' "$CONSTRAINT_LINE" >> "$CONSTRAINTS"
        fi
        echo "Auto-extracted constraint to learned-constraints.md"
    fi
fi
