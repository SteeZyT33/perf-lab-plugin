#!/usr/bin/env bash
# fetch-papers.sh — Fetch PDFs from a paper list or Semantic Scholar
#
# Usage: ./scripts/fetch-papers.sh <papers-list.txt>
#
# Input format (tab-separated, one paper per line):
#   key\ttitle\t[optional-url]
#
# Examples:
#   vliw-scheduling\tVLIW Instruction Scheduling\thttps://example.com/paper.pdf
#   simd-hashing\tSIMD-Accelerated Hash Functions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PERF_LAB_PROJECT:-$(dirname "$SCRIPT_DIR")}"
CONFIG="$PROJECT_DIR/perf-lab.config.json"

PAPER_DIR="$PROJECT_DIR/shared/Research/papers"

# Read paper_dir from config if available
if [[ -f "$CONFIG" ]]; then
    DIR=$(jq -r '.research.paper_dir // ""' "$CONFIG")
    if [[ -n "$DIR" ]]; then
        # Anchor relative paths to PROJECT_DIR
        [[ "$DIR" != /* ]] && DIR="$PROJECT_DIR/$DIR"
        PAPER_DIR="$DIR"
    fi
fi

mkdir -p "$PAPER_DIR"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <papers-list.txt>"
    echo ""
    echo "File format (tab-separated):"
    echo "  key<TAB>title<TAB>[url]"
    exit 1
fi

INPUT_FILE="$1"
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: File not found: $INPUT_FILE"
    exit 1
fi

# Source Semantic Scholar API key
SS_KEY="${SEMANTIC_SCHOLAR_API_KEY:-}"
if [[ -z "$SS_KEY" && -f "$CONFIG" ]]; then
    SS_KEY=$(jq -r '.research.semantic_scholar_api_key // .semantic_scholar_api_key // ""' "$CONFIG")
fi

SS_HEADERS=()
[[ -n "$SS_KEY" ]] && SS_HEADERS=(-H "x-api-key: $SS_KEY")

FETCHED=0
SKIPPED=0
FAILED=0

while IFS=$'\t' read -r key title url; do
    # Skip blank lines and comments
    [[ -z "$key" || "$key" == \#* ]] && continue

    if [[ -f "$PAPER_DIR/$key.pdf" ]]; then
        echo "SKIP: $key.pdf already exists"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if [[ -n "${url:-}" ]]; then
        echo "FETCH: $key from $url"
        if curl -sL --fail -o "$PAPER_DIR/$key.pdf" "$url"; then
            echo "  -> $PAPER_DIR/$key.pdf"
            FETCHED=$((FETCHED + 1))
        else
            echo "  FAILED to download from URL"
            FAILED=$((FAILED + 1))
        fi
    else
        # Try Semantic Scholar open-access lookup
        echo "SEARCH: $key - $title"
        ENCODED=$(python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$title")
        RESULT=$(curl -s "${SS_HEADERS[@]+"${SS_HEADERS[@]}"}" \
            "https://api.semanticscholar.org/graph/v1/paper/search?query=${ENCODED}&limit=1&fields=openAccessPdf" \
            | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    pdf = d.get('data', [{}])[0].get('openAccessPdf') or {}
    print(pdf.get('url', ''))
except Exception:
    print('')
" 2>/dev/null)

        if [[ -n "$RESULT" ]]; then
            echo "  Found PDF via Semantic Scholar: $RESULT"
            if curl -sL --fail -o "$PAPER_DIR/$key.pdf" "$RESULT"; then
                echo "  -> $PAPER_DIR/$key.pdf"
                FETCHED=$((FETCHED + 1))
            else
                echo "  FAILED to download"
                RESULT=""  # fall through to ArXiv
            fi
        fi

        # ArXiv fallback if Semantic Scholar had no open-access PDF
        if [[ -z "$RESULT" ]]; then
            echo "  Trying ArXiv..."
            ARXIV_URL=$(curl -s "http://export.arxiv.org/api/query?search_query=all:$(echo "$title" | tr ' ' '+')" \
                | python3 -c "
import sys, xml.etree.ElementTree as ET
try:
    root = ET.parse(sys.stdin).getroot()
    ns = {'a': 'http://www.w3.org/2005/Atom'}
    for entry in root.findall('a:entry', ns):
        for link in entry.findall('a:link', ns):
            if link.get('title') == 'pdf':
                print(link.get('href'))
                sys.exit(0)
except Exception:
    pass
" 2>/dev/null || true)

            if [[ -n "$ARXIV_URL" ]]; then
                echo "  Found PDF via ArXiv: $ARXIV_URL"
                if curl -sL --fail -o "$PAPER_DIR/$key.pdf" "$ARXIV_URL"; then
                    echo "  -> $PAPER_DIR/$key.pdf"
                    FETCHED=$((FETCHED + 1))
                else
                    echo "  FAILED to download from ArXiv"
                    FAILED=$((FAILED + 1))
                fi
            else
                echo "  NO FREE PDF for $key (checked Semantic Scholar + ArXiv)"
                printf '%s\t%s\tNOT_FOUND\n' "$key" "$title" >> "$PAPER_DIR/paywalled.txt"
                FAILED=$((FAILED + 1))
            fi
        fi

        # Rate-limit politeness
        sleep 1
    fi
done < "$INPUT_FILE"

echo ""
echo "Done: $FETCHED fetched, $SKIPPED skipped, $FAILED failed"
