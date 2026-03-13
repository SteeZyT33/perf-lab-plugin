#!/usr/bin/env bash
# replay-candidates.sh — Find DISCARDED experiments worth retrying after architecture changes
#
# Usage: ./scripts/replay-candidates.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PERF_LAB_PROJECT:-$(dirname "$SCRIPT_DIR")}"
CONFIG="$PROJECT_DIR/perf-lab.config.json"
METRIC_NAME=$(jq -r '.metric_name' "$CONFIG")

SHARED_DIR="$PROJECT_DIR/shared"
TSV="$SHARED_DIR/experiments.tsv"
CONSTRAINTS="$SHARED_DIR/learned-constraints.md"
CHANGELOG="$SHARED_DIR/architecture-changelog.md"

if [[ ! -f "$TSV" ]]; then
    echo "No experiments found."
    exit 0
fi

# Get current architecture signature from learned-constraints.md
# Hash the "Current Architecture" section or full file if no section exists
ARCH_SIG=""
if [[ -f "$CONSTRAINTS" ]]; then
    ARCH_SECTION=$(sed -n '/^## Current Architecture/,/^## /p' "$CONSTRAINTS" | head -n -1)
    if [[ -n "$ARCH_SECTION" ]]; then
        ARCH_SIG=$(echo "$ARCH_SECTION" | md5sum | cut -d' ' -f1)
    else
        ARCH_SIG=$(md5sum "$CONSTRAINTS" | cut -d' ' -f1)
    fi
fi

# Get the last architecture change date from changelog
LAST_CHANGE_DATE=""
if [[ -f "$CHANGELOG" ]]; then
    # Entries are prepended (newest first), so head -1 gets the most recent
    LAST_CHANGE_DATE=$(grep -oP '(?<=Date: )\S+' "$CHANGELOG" | head -1)
fi

if [[ -z "$LAST_CHANGE_DATE" ]]; then
    echo "No architecture changes recorded in $CHANGELOG"
    echo "Run this after a successful rewrite (via /perf-lab:plateau) that updates the changelog."
    exit 0
fi

echo "Architecture last changed: $LAST_CHANGE_DATE"
echo "Current architecture signature: ${ARCH_SIG:0:8}..."
echo ""
echo "=== RETRY CANDIDATES ==="
echo "(DISCARDED experiments from before the last architecture change)"
echo ""

FOUND=0
printf "%-5s  %-10s  %-8s  %-8s  %s\n" "ITER" "AGENT" "BEFORE" "AFTER" "HYPOTHESIS"
printf "%-5s  %-10s  %-8s  %-8s  %s\n" "-----" "----------" "--------" "--------" "-------------------------------------------"

# Find DISCARDED experiments from before the last architecture change
# Handle TSV with or without duration_seconds column
while IFS=$'\t' read -r ts agent iter hyp before after status notes _rest; do
    [[ "$status" != "DISCARDED" ]] && continue
    # Compare dates (ISO format sorts lexicographically)
    EXP_DATE=$(echo "$ts" | cut -dT -f1)
    if [[ "$EXP_DATE" < "$LAST_CHANGE_DATE" ]]; then
        printf "%-5s  %-10s  %-8s  %-8s  %s\n" "$iter" "$agent" "$before" "$after" "$hyp"
        if [[ -n "$notes" ]]; then
            printf "       %s\n" "Reason: $notes"
        fi
        FOUND=$((FOUND + 1))
    fi
done < <(tail -n +2 "$TSV")

echo ""
if [[ $FOUND -eq 0 ]]; then
    echo "No retry candidates found (all discarded experiments are from the current architecture)."
else
    echo "$FOUND candidate(s) found. These were discarded under a different architecture and may work now."
fi
