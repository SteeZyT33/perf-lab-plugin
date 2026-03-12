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
ALERT_FILE="$SHARED_DIR/new-best-alert.txt"

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
    echo -e "timestamp\tagent\titeration\thypothesis\t${METRIC_NAME}_before\t${METRIC_NAME}_after\tstatus\tnotes" > "$TSV"
fi

LAST_ITER=$(tail -n 1 "$TSV" | cut -f3)
if [[ "$LAST_ITER" == "iteration" || -z "$LAST_ITER" ]]; then ITER=1; else ITER=$((LAST_ITER + 1)); fi

METRIC_BEFORE="-"
if [[ -f "$BEST_FILE" ]]; then METRIC_BEFORE=$(cat "$BEST_FILE" | tr -d '[:space:]'); fi

TIMESTAMP=$(date -Iseconds)

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

echo -e "${TIMESTAMP}\t${AGENT}\t${ITER}\t${HYPOTHESIS}\t${METRIC_BEFORE}\t${METRIC_AFTER}\t${STATUS}\t${NOTES}" >> "$TSV"
echo "Logged experiment #${ITER} by ${AGENT}: ${STATUS} — ${HYPOTHESIS}"

if [[ "$STATUS" == "KEPT" && "$METRIC_AFTER" != "-" && "$METRIC_BEFORE" != "-" ]]; then
    if is_better "$METRIC_AFTER" "$METRIC_BEFORE"; then
        echo "$METRIC_AFTER" > "$BEST_FILE"
        cp "$PROJECT_DIR/$SOLUTION_FILE" "$BEST_SOLUTION"
        echo "AGENT ${AGENT} achieved ${METRIC_AFTER} ${METRIC_NAME} at ${TIMESTAMP}. Strategy: ${HYPOTHESIS}" > "$ALERT_FILE"
        echo ""
        echo "*** NEW BEST: ${METRIC_AFTER} ${METRIC_NAME} (was ${METRIC_BEFORE}) ***"
    fi
fi
