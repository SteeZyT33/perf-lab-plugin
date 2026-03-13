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

# Session stats
TOTAL_EXPERIMENTS=$(( $(wc -l < "$TSV") - 1 ))
TOTAL_KEPT=$(awk -F'\t' '$7=="KEPT"' "$TSV" | wc -l)

# Duration stats (column 9, if present)
HAS_DURATION=false
if head -1 "$TSV" | grep -q "duration_seconds"; then
    HAS_DURATION=true
fi

AVG_DURATION="-"
TOTAL_DURATION=0
if $HAS_DURATION; then
    TOTAL_DURATION=$(awk -F'\t' 'NR>1 && $9 ~ /^[0-9]+$/ {s+=$9} END{print s+0}' "$TSV")
    if (( TOTAL_EXPERIMENTS > 0 )); then
        AVG_DURATION=$(( TOTAL_DURATION / TOTAL_EXPERIMENTS ))
    fi
fi

printf "║  Session: %3d experiments, %3d kept" "$TOTAL_EXPERIMENTS" "$TOTAL_KEPT"
if $HAS_DURATION && [[ "$AVG_DURATION" != "-" ]]; then
    printf ", avg %ss/exp" "$AVG_DURATION"
fi
printf "            ║\n"

# Cost efficiency: metric improvement per hour
if $HAS_DURATION && (( TOTAL_DURATION > 0 )); then
    FIRST_METRIC=$(awk -F'\t' 'NR==2 && $5 ~ /^[0-9]/ {print $5}' "$TSV")
    if [[ -n "$FIRST_METRIC" && "$BEST" != "-" ]]; then
        HOURS=$(awk "BEGIN{printf \"%.1f\", $TOTAL_DURATION/3600}")
        if [[ "$DIRECTION" == "lower" ]]; then
            SAVED=$(awk "BEGIN{printf \"%.0f\", $FIRST_METRIC - $BEST}")
        else
            SAVED=$(awk "BEGIN{printf \"%.0f\", $BEST - $FIRST_METRIC}")
        fi
        if (( TOTAL_DURATION > 60 )); then
            RATE=$(awk "BEGIN{printf \"%.1f\", $SAVED / ($TOTAL_DURATION/3600)}")
            printf "║  Efficiency: %s %s saved in %sh (%s %s/hr)          ║\n" \
                "$SAVED" "$METRIC_NAME" "$HOURS" "$RATE" "$METRIC_NAME"
        fi
    fi
fi

echo "║                                                                  ║"
echo "║  Agent stats:                                                    ║"
AGENTS=$(tail -n +2 "$TSV" | cut -f2 | sort -u)
for AGENT in $AGENTS; do
    TOTAL=$(awk -F'\t' -v a="$AGENT" '$2==a' "$TSV" | wc -l)
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

tail -n +2 "$TSV" | tail -15 | while IFS=$'\t' read -r ts agent iter hyp before after status notes rest; do
    printf "║  %-8s %-4s %-8s %-8s %-8s %-26.26s ║\n" "$agent" "$iter" "$status" "$before" "$after" "$hyp"
done

echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  DISCARDED STRATEGIES (DO NOT RE-ATTEMPT)                       ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
DISCARDED_LINES=$(grep "DISCARDED" "$TSV" || true)
if [[ -z "$DISCARDED_LINES" ]]; then
    echo "║  (none)                                                          ║"
else
    echo "$DISCARDED_LINES" | while IFS=$'\t' read -r ts agent iter hyp before after status notes rest; do
        printf "║  [%-8s] #%-3s %-52.52s ║\n" "$agent" "$iter" "$hyp"
        [[ -n "$notes" ]] && printf "║               Reason: %-44.44s ║\n" "$notes"
    done
fi

echo "╚══════════════════════════════════════════════════════════════════╝"

echo ""
echo "See shared/learned-constraints.md for known optimization constraints."
