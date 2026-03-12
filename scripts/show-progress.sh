#!/usr/bin/env bash
# show-progress.sh — Dashboard for multi-agent experiment tracking

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PERF_LAB_PROJECT:-$(dirname "$SCRIPT_DIR")}"
CONFIG="$PROJECT_DIR/perf-lab.config.json"
METRIC_NAME=$(jq -r '.metric_name' "$CONFIG")
DIRECTION=$(jq -r '.direction // "lower"' "$CONFIG")

SHARED_DIR="$PROJECT_DIR/shared"
TSV="$SHARED_DIR/experiments.tsv"
BEST_FILE="$SHARED_DIR/best-metric.txt"
ALERT_FILE="$SHARED_DIR/new-best-alert.txt"

is_better() {
  if [[ "$DIRECTION" == "lower" ]]; then
    awk "BEGIN{exit(!($1<$2))}"
  else
    awk "BEGIN{exit(!($1>$2))}"
  fi
}

if [[ ! -f "$TSV" ]]; then
    echo "No experiments logged yet. Run ./scripts/track-experiment.sh first."
    exit 1
fi

BEST="-"
if [[ -f "$BEST_FILE" ]]; then BEST=$(cat "$BEST_FILE" | tr -d '[:space:]'); fi

BEST_AGENT=$(grep "KEPT" "$TSV" | awk -F'\t' -v best="$BEST" '$6 == best {print $2; exit}')

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              MULTI-AGENT EXPERIMENT DASHBOARD                   ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
printf "║  Current best:  %-8s %-6s  (agent: %-20.20s) ║\n" "$BEST" "$METRIC_NAME" "${BEST_AGENT:-unknown}"
echo "║                                                                  ║"

echo "║  Agent stats:                                                    ║"
AGENTS=$(tail -n +2 "$TSV" | cut -f2 | sort -u)
for AGENT in $AGENTS; do
    TOTAL=$(grep -c "	${AGENT}	" "$TSV" || true)
    KEPT=$(awk -F'\t' -v a="$AGENT" '$2==a && $7=="KEPT"' "$TSV" | wc -l)
    DISC=$(awk -F'\t' -v a="$AGENT" '$2==a && $7=="DISCARDED"' "$TSV" | wc -l)
    FAIL=$(awk -F'\t' -v a="$AGENT" '$2==a && $7=="FAILED"' "$TSV" | wc -l)
    printf "║    %-10s  %3d tried, %3d kept, %3d discarded, %3d failed    ║\n" "$AGENT" "$TOTAL" "$KEPT" "$DISC" "$FAIL"
done

echo "║                                                                  ║"
echo "║  Targets:                                                        ║"
jq -r '.targets | to_entries | sort_by(.key | tonumber) | reverse[] | "\(.key)\t\(.value)"' "$CONFIG" | \
while IFS=$'\t' read -r TARGET_VAL LABEL; do
    if [[ "$BEST" != "-" ]] && is_better "$BEST" "$TARGET_VAL"; then
        MARK="[x]"
    else
        MARK="[ ]"
    fi
    printf "║    %s  %-8s  %-48.48s ║\n" "$MARK" "$TARGET_VAL" "$LABEL"
done

echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  LAST 15 EXPERIMENTS                                            ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
printf "║  %-8s %-4s %-8s %-8s %-8s %-26.26s ║\n" "AGENT" "ITER" "STATUS" "BEFORE" "AFTER" "HYPOTHESIS"
echo "║  -------- ---- -------- -------- -------- -------------------------- ║"

tail -n +2 "$TSV" | tail -15 | while IFS=$'\t' read -r ts agent iter hyp before after status notes; do
    printf "║  %-8s %-4s %-8s %-8s %-8s %-26.26s ║\n" "$agent" "$iter" "$status" "$before" "$after" "$hyp"
done

echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  DISCARDED STRATEGIES (DO NOT RE-ATTEMPT)                       ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
DISCARDED_LINES=$(grep "DISCARDED" "$TSV" || true)
if [[ -z "$DISCARDED_LINES" ]]; then
    echo "║  (none)                                                          ║"
else
    echo "$DISCARDED_LINES" | while IFS=$'\t' read -r ts agent iter hyp before after status notes; do
        printf "║  [%-8s] #%-3s %-52.52s ║\n" "$agent" "$iter" "$hyp"
        [[ -n "$notes" ]] && printf "║               Reason: %-44.44s ║\n" "$notes"
    done
fi

echo "╚══════════════════════════════════════════════════════════════════╝"

if [[ -f "$ALERT_FILE" ]]; then
    echo ""
    echo "*** NEW BEST ALERT ***"
    cat "$ALERT_FILE"
fi

echo ""
echo "See shared/learned-constraints.md for known optimization constraints."
