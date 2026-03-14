#!/usr/bin/env bash
# track-experiment.sh — Log an experiment result to shared/experiments.tsv
#
# Usage: ./scripts/track-experiment.sh <agent> "<hypothesis>" <KEPT|DISCARDED|FAILED|EXPLORING> ["notes"] ["technique"]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PERF_LAB_PROJECT:-$(dirname "$SCRIPT_DIR")}"
CONFIG="$PROJECT_DIR/perf-lab.config.json"
METRIC_NAME=$(jq -r '.metric_name' "$CONFIG")
TEST_CMD=$(jq -r '.test_command' "$CONFIG")
PARSE_CMD=$(jq -r '.parse_metric' "$CONFIG")
DIRECTION=$(jq -r '.direction // "lower"' "$CONFIG")
SOLUTION_FILE=$(jq -r '.solution_file' "$CONFIG")
VERIFICATION_RUNS=$(jq -r '.verification_runs // 1' "$CONFIG")

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
    echo "Usage: $0 <agent> <hypothesis> <KEPT|DISCARDED|FAILED|EXPLORING> [notes] [technique]"
    exit 1
fi

AGENT="$1"; HYPOTHESIS="$2"; STATUS="$3"; NOTES="${4:-}"; TECHNIQUE="${5:-}"

if [[ "$STATUS" != "KEPT" && "$STATUS" != "DISCARDED" && "$STATUS" != "FAILED" && "$STATUS" != "EXPLORING" ]]; then
    echo "Error: status must be KEPT, DISCARDED, FAILED, or EXPLORING (got: $STATUS)"
    exit 1
fi

if [[ ! -f "$TSV" ]]; then
    echo -e "timestamp\tagent\titeration\thypothesis\t${METRIC_NAME}_before\t${METRIC_NAME}_after\tstatus\tnotes\tduration_seconds\ttechnique" > "$TSV"
fi

METRIC_BEFORE="-"
if [[ -f "$BEST_FILE" ]]; then METRIC_BEFORE=$(cat "$BEST_FILE" | tr -d '[:space:]'); fi

TIMESTAMP=$(date -Iseconds)
START_EPOCH=$(date +%s)

if [[ "$STATUS" == "FAILED" ]]; then
    METRIC_AFTER="-"
    [[ -z "$NOTES" ]] && NOTES="correctness check failed"
else
    # For KEPT experiments with verification_runs > 1, run multiple times and take worst
    RUNS_NEEDED=1
    if [[ "$STATUS" == "KEPT" && "$VERIFICATION_RUNS" -gt 1 ]]; then
        RUNS_NEEDED="$VERIFICATION_RUNS"
        echo "Running ${RUNS_NEEDED} verification runs (reporting worst)..."
    else
        echo "Running tests to capture ${METRIC_NAME}..."
    fi

    METRIC_AFTER="-"
    ALL_RESULTS=""
    for (( RUN=1; RUN<=RUNS_NEEDED; RUN++ )); do
        TEST_OUTPUT=$(cd "$PROJECT_DIR" && eval "$TEST_CMD" 2>&1) || true
        RUN_METRIC=$(echo "$TEST_OUTPUT" | eval "$PARSE_CMD" | head -1)
        if [[ -z "$RUN_METRIC" ]]; then
            echo "Warning: Could not parse ${METRIC_NAME} from test output (run $RUN)."
            echo "$TEST_OUTPUT" | tail -20
            continue
        fi

        if (( RUNS_NEEDED > 1 )); then
            echo "  Run ${RUN}/${RUNS_NEEDED}: ${RUN_METRIC} ${METRIC_NAME}"
        fi

        ALL_RESULTS="${ALL_RESULTS}${ALL_RESULTS:+ }${RUN_METRIC}"

        # Take worst result: for "lower is better" → take the highest (worst)
        #                     for "higher is better" → take the lowest (worst)
        if [[ "$METRIC_AFTER" == "-" ]]; then
            METRIC_AFTER="$RUN_METRIC"
        elif [[ "$DIRECTION" == "lower" ]]; then
            # Worst = highest value when lower is better
            if awk "BEGIN{exit(!($RUN_METRIC>$METRIC_AFTER))}"; then
                METRIC_AFTER="$RUN_METRIC"
            fi
        else
            # Worst = lowest value when higher is better
            if awk "BEGIN{exit(!($RUN_METRIC<$METRIC_AFTER))}"; then
                METRIC_AFTER="$RUN_METRIC"
            fi
        fi
    done

    if [[ "$METRIC_AFTER" == "-" ]]; then
        echo "Warning: Could not parse ${METRIC_NAME} from any test run."
    elif (( RUNS_NEEDED > 1 )); then
        echo "${METRIC_NAME} (worst of ${RUNS_NEEDED}): $METRIC_AFTER [all: ${ALL_RESULTS}]"
        NOTES="${NOTES:+${NOTES}; }verified ${RUNS_NEEDED}x [${ALL_RESULTS}] worst=${METRIC_AFTER}"
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
    echo -e "${TIMESTAMP}\t${AGENT}\t${ITER}\t${HYPOTHESIS}\t${METRIC_BEFORE}\t${METRIC_AFTER}\t${STATUS}\t${NOTES}\t${DURATION}\t${TECHNIQUE}" >> "$TSV"
) 200>"$TSV.lock"

# Read back the iteration number we just wrote
ITER=$(tail -n 1 "$TSV" | cut -f3)
echo "Logged experiment #${ITER} by ${AGENT}: ${STATUS} — ${HYPOTHESIS} (${DURATION}s)"

# Update agent pulse file for heartbeat monitoring
PULSE_DIR="$SHARED_DIR/agent-pulse"
mkdir -p "$PULSE_DIR"
PULSE_FILE="$PULSE_DIR/${AGENT}.json"

KEPT_COUNT=$(awk -F'\t' -v a="$AGENT" '$2==a && $7=="KEPT"' "$TSV" | wc -l)
TOTAL_COUNT=$(awk -F'\t' -v a="$AGENT" '$2==a' "$TSV" | wc -l)
AGENT_ITER=$(awk -F'\t' -v a="$AGENT" '$2==a {n++} END{print n+0}' "$TSV")
BEST_VAL=$(cat "$SHARED_DIR/best-metric.txt" 2>/dev/null | tr -d '[:space:]')
[[ -z "$BEST_VAL" || ! "$BEST_VAL" =~ ^[0-9.eE+-]+$ ]] && BEST_VAL=-1

jq -n \
  --arg agent "$AGENT" \
  --argjson iter "$AGENT_ITER" \
  --arg phase "idle" \
  --arg last "$(date -Iseconds)" \
  --arg hyp "$HYPOTHESIS" \
  --argjson best "$BEST_VAL" \
  --argjson kept "$KEPT_COUNT" \
  --argjson total "$TOTAL_COUNT" \
  '{agent: $agent, iteration: $iter, phase: $phase, last_activity: $last, current_hypothesis: $hyp, best_metric: $best, experiments_kept: $kept, experiments_total: $total}' \
  > "$PULSE_FILE"

# Git branch advancement: auto-commit KEPT, auto-revert DISCARDED on perf-lab/* branches
CURRENT_BRANCH=$(cd "$PROJECT_DIR" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ "$CURRENT_BRANCH" == perf-lab/* ]]; then
    if [[ "$STATUS" == "KEPT" ]]; then
        (
            cd "$PROJECT_DIR"
            git add -A && git commit -m "exp(${AGENT}): ${HYPOTHESIS} -- ${METRIC_AFTER}" 2>/dev/null
        ) || echo "Warning: git commit failed for KEPT experiment (non-fatal)"
    elif [[ "$STATUS" == "DISCARDED" ]]; then
        (
            cd "$PROJECT_DIR"
            git reset --hard HEAD 2>/dev/null
        ) || echo "Warning: git reset failed for DISCARDED experiment (non-fatal)"
    fi
fi

# Agent Journal: auto-write recent experiments for relaunch context
JOURNAL_DIR="$SHARED_DIR/agent-journal"
mkdir -p "$JOURNAL_DIR"
JOURNAL="$JOURNAL_DIR/${AGENT}.md"

# Write/update recent experiments table (keep last 10 by this agent)
RECENT=$(awk -F'\t' -v a="$AGENT" '$2==a && $1!="timestamp" {print "| " $4 " | " $7 " | " $6 " | " $10 " |"}' "$TSV" | tail -10)
# Write factual section (agent writes strategy sections manually)
cat > "${JOURNAL}.tmp" <<JEOF
# Journal: ${AGENT}
## Last Updated: $(date -Iseconds)
## Current Best: $(cat "$BEST_FILE" 2>/dev/null || echo "none")

## Recent Experiments (auto-generated, last 10)
| Hypothesis | Status | Metric | Technique |
|---|---|---|---|
${RECENT}

JEOF

# Preserve agent-written sections if they exist
if [[ -f "$JOURNAL" ]]; then
    sed -n '/^## Strategy$/,$ p' "$JOURNAL" >> "${JOURNAL}.tmp" 2>/dev/null || true
fi
mv "${JOURNAL}.tmp" "$JOURNAL"

# Technique Index: update fleet-wide technique lookup
if [[ -n "$TECHNIQUE" ]]; then
    TECH_INDEX="$SHARED_DIR/technique-index.tsv"
    if [[ ! -f "$TECH_INDEX" ]]; then
        echo -e "technique\tattempts\tkept\tdiscarded\tfailed\tbest_result\tlast_agent\tlast_updated" > "$TECH_INDEX"
    fi
    (
        flock -x 201
        if grep -q "^${TECHNIQUE}	" "$TECH_INDEX"; then
            # Update existing row
            awk -F'\t' -v OFS='\t' -v tech="$TECHNIQUE" -v st="$STATUS" -v val="$METRIC_AFTER" \
                -v agent="$AGENT" -v ts="$TIMESTAMP" -v dir="$DIRECTION" '
                $1==tech {
                    $2++
                    if(st=="KEPT") { $3++; if($6=="-" || (dir=="lower" && val<$6) || (dir!="lower" && val>$6)) $6=val }
                    else if(st=="DISCARDED") $4++
                    else if(st=="FAILED") $5++
                    $7=agent; $8=ts
                }
                {print}
            ' "$TECH_INDEX" > "${TECH_INDEX}.tmp"
            mv "${TECH_INDEX}.tmp" "$TECH_INDEX"
        else
            # New technique row
            KEPT_N=0; DISC_N=0; FAIL_N=0; BEST="-"
            [[ "$STATUS" == "KEPT" ]] && KEPT_N=1 && BEST="$METRIC_AFTER"
            [[ "$STATUS" == "DISCARDED" ]] && DISC_N=1
            [[ "$STATUS" == "FAILED" ]] && FAIL_N=1
            echo -e "${TECHNIQUE}\t1\t${KEPT_N}\t${DISC_N}\t${FAIL_N}\t${BEST}\t${AGENT}\t${TIMESTAMP}" >> "$TECH_INDEX"
        fi
    ) 201>"${TECH_INDEX}.lock"
fi

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
