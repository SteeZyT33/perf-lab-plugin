#!/usr/bin/env bash
# process-papers.sh — Convert PDFs to markdown via LlamaParse
#
# Usage: ./scripts/process-papers.sh [paper-dir]
#        Default: shared/Research/papers
#
# Requires: LLAMA_CLOUD_API_KEY env var (or in perf-lab.config.json research.llama_cloud_api_key)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PERF_LAB_PROJECT:-$(dirname "$SCRIPT_DIR")}"
CONFIG="$PROJECT_DIR/perf-lab.config.json"

PAPER_DIR="${1:-shared/Research/papers}"

# Source API key from config if not already in environment
if [[ -z "${LLAMA_CLOUD_API_KEY:-}" && -f "$CONFIG" ]]; then
    KEY=$(jq -r '.research.llama_cloud_api_key // ""' "$CONFIG")
    if [[ -n "$KEY" ]]; then
        export LLAMA_CLOUD_API_KEY="$KEY"
    fi
fi

if [[ -z "${LLAMA_CLOUD_API_KEY:-}" ]]; then
    echo "Error: Set LLAMA_CLOUD_API_KEY or configure research.llama_cloud_api_key in perf-lab.config.json"
    exit 1
fi

if [[ ! -d "$PAPER_DIR" ]]; then
    echo "No papers directory at $PAPER_DIR"
    exit 0
fi

PDF_COUNT=$(find "$PAPER_DIR" -maxdepth 1 -name '*.pdf' | wc -l)
if [[ "$PDF_COUNT" -eq 0 ]]; then
    echo "No PDFs found in $PAPER_DIR"
    exit 0
fi

echo "Processing $PDF_COUNT PDF(s) in $PAPER_DIR/"
python3 "$SCRIPT_DIR/llamaparse_convert.py" "$PAPER_DIR"
echo "Done. Markdown files in $PAPER_DIR/"
