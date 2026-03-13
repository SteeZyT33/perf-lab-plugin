#!/usr/bin/env bash
# generate-undermind-prompt.sh — Generate a research query for undermind.ai
#
# Usage: ./scripts/generate-undermind-prompt.sh [topic]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PERF_LAB_PROJECT:-$(dirname "$SCRIPT_DIR")}"
CONFIG="$PROJECT_DIR/perf-lab.config.json"

SHARED_DIR="$PROJECT_DIR/shared"
TSV="$SHARED_DIR/experiments.tsv"
CONSTRAINTS="$SHARED_DIR/learned-constraints.md"
OUTPUT="$SHARED_DIR/Research/undermind-prompt.txt"

TOPIC="${1:-}"

mkdir -p "$(dirname "$OUTPUT")"

# Find the most common recent failure reason
RECENT_FAILURES=""
if [[ -f "$TSV" ]]; then
    RECENT_FAILURES=$(tail -20 "$TSV" | awk -F'\t' '$7=="DISCARDED" || $7=="FAILED" {print $4}' | head -5)
fi

# Extract current bottleneck from constraints
BOTTLENECK=""
if [[ -f "$CONSTRAINTS" ]]; then
    BOTTLENECK=$(grep -i -A2 'binding\|bottleneck\|limiting' "$CONSTRAINTS" | head -5 || true)
fi

# Build the prompt
cat > "$OUTPUT" <<EOF
Find academic papers on the following optimization challenge:

## Context
Performance optimization of a computational kernel.
EOF

if [[ -n "$TOPIC" ]]; then
    echo "Topic: $TOPIC" >> "$OUTPUT"
fi

if [[ -n "$BOTTLENECK" ]]; then
    cat >> "$OUTPUT" <<EOF

## Current Bottleneck
$BOTTLENECK
EOF
fi

if [[ -n "$RECENT_FAILURES" ]]; then
    cat >> "$OUTPUT" <<EOF

## Recently Failed Approaches
$(echo "$RECENT_FAILURES" | sed 's/^/- /')
EOF
fi

cat >> "$OUTPUT" <<EOF

## What I Need
Papers describing techniques to overcome this specific bottleneck.
Prioritize:
- Papers with open-access PDFs
- High citation count (established techniques)
- Papers with pseudocode or algorithm descriptions
- Applied/practical results over purely theoretical
EOF

echo ""
echo "Undermind prompt saved to: $OUTPUT"
echo ""
echo "Next steps:"
echo "  1. Paste the contents of $OUTPUT into undermind.ai"
echo "  2. Save Undermind's results to shared/Research/undermind-results.txt"
echo "  3. Run: ./scripts/fetch-papers.sh shared/Research/paper-list.txt"
echo ""
cat "$OUTPUT"
