#!/usr/bin/env bash
# search-papers.sh — Search Semantic Scholar for academic papers
#
# Usage:
#   ./scripts/search-papers.sh "<query>" [limit]            # keyword search
#   ./scripts/search-papers.sh --citations "<paper_id>" [limit]  # papers that cite this one
#   ./scripts/search-papers.sh --references "<paper_id>" [limit] # papers this one cites
#   ./scripts/search-papers.sh --pdf "<paper_id>"            # download open-access PDF
#
# Examples:
#   ./scripts/search-papers.sh "VLIW pipeline scheduling optimization"
#   ./scripts/search-papers.sh --citations "649def34f8be52c8b66281af98ae884c09aef38b" 5
#   ./scripts/search-papers.sh --pdf "649def34f8be52c8b66281af98ae884c09aef38b"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PERF_LAB_PROJECT:-$(dirname "$SCRIPT_DIR")}"
CONFIG="$PROJECT_DIR/perf-lab.config.json"

# Use API key if configured (higher rate limits)
CURL_HEADERS=()
if [[ -f "$CONFIG" ]]; then
    API_KEY=$(jq -r '.semantic_scholar_api_key // ""' "$CONFIG")
    [[ -n "$API_KEY" ]] && CURL_HEADERS=(-H "x-api-key: $API_KEY")
fi

s2_curl() {
    local RESPONSE
    RESPONSE=$(curl -s --retry 2 --retry-delay 3 "${CURL_HEADERS[@]+"${CURL_HEADERS[@]}"}" "$1")

    # Rate limit retry
    if echo "$RESPONSE" | jq -e '.code == "429"' &>/dev/null; then
        echo "Rate limited. Retrying in 5s..." >&2
        sleep 5
        RESPONSE=$(curl -s "${CURL_HEADERS[@]+"${CURL_HEADERS[@]}"}" "$1")
    fi

    # Check for errors
    if echo "$RESPONSE" | jq -e '.error // .message' &>/dev/null; then
        echo "Error: $(echo "$RESPONSE" | jq -r '.error // .message')" >&2
        return 1
    fi

    echo "$RESPONSE"
}

format_papers() {
    jq -r '.[] | [
      "### \(.citingPaper // . | .title // "Unknown") (\(.citingPaper // . | .year // "n/a"))",
      "- **Paper ID**: \(.citingPaper // . | .paperId // "n/a")",
      "- **Authors**: \([ (.citingPaper // . | .authors[]?.name) ] | join(", "))",
      "- **Citations**: \(.citingPaper // . | .citationCount // 0)",
      "- **URL**: \(.citingPaper // . | .url // "n/a")",
      (if (.citingPaper // . | .tldr.text) then "- **TLDR**: \(.citingPaper // . | .tldr.text)" else "" end),
      (if (.citingPaper // . | .openAccessPdf.url) then "- **PDF**: \(.citingPaper // . | .openAccessPdf.url)" else "" end),
      (if (.citingPaper // . | .abstract) then "- **Abstract**: \(.citingPaper // . | .abstract[:300])..." else "" end),
      ""
    ] | map(select(. != "")) | join("\n")'
}

FIELDS="title,abstract,year,citationCount,url,tldr,authors,openAccessPdf,paperId"

if [[ $# -lt 1 ]]; then
    echo "Usage:"
    echo "  $0 \"<query>\" [limit]              # keyword search"
    echo "  $0 --citations \"<paper_id>\" [limit] # papers citing this one"
    echo "  $0 --references \"<paper_id>\" [limit] # papers this one cites"
    echo "  $0 --pdf \"<paper_id>\"               # download open-access PDF"
    exit 1
fi

MODE="search"
if [[ "$1" == "--citations" ]]; then
    MODE="citations"; shift
elif [[ "$1" == "--references" ]]; then
    MODE="references"; shift
elif [[ "$1" == "--pdf" ]]; then
    MODE="pdf"; shift
fi

case "$MODE" in
    search)
        QUERY="$1"
        LIMIT="${2:-5}"
        ENCODED=$(python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")
        RESPONSE=$(s2_curl "https://api.semanticscholar.org/graph/v1/paper/search?query=${ENCODED}&limit=${LIMIT}&fields=${FIELDS}")
        TOTAL=$(echo "$RESPONSE" | jq -r '.total // 0')
        echo "Found $TOTAL papers (showing top $LIMIT)"
        echo ""
        echo "$RESPONSE" | jq -r '.data // []' | format_papers
        ;;

    citations)
        PAPER_ID="$1"
        LIMIT="${2:-5}"
        echo "Papers citing $PAPER_ID (top $LIMIT):"
        echo ""
        RESPONSE=$(s2_curl "https://api.semanticscholar.org/graph/v1/paper/${PAPER_ID}/citations?fields=${FIELDS}&limit=${LIMIT}")
        echo "$RESPONSE" | jq -r '.data // []' | format_papers
        ;;

    references)
        PAPER_ID="$1"
        LIMIT="${2:-5}"
        echo "References from $PAPER_ID (top $LIMIT):"
        echo ""
        RESPONSE=$(s2_curl "https://api.semanticscholar.org/graph/v1/paper/${PAPER_ID}/references?fields=${FIELDS}&limit=${LIMIT}")
        # References use .citedPaper instead of .citingPaper
        echo "$RESPONSE" | jq '[.data[]? | {citingPaper: .citedPaper}]' | format_papers
        ;;

    pdf)
        PAPER_ID="$1"
        PAPER_INFO=$(s2_curl "https://api.semanticscholar.org/graph/v1/paper/${PAPER_ID}?fields=title,openAccessPdf")
        PDF_URL=$(echo "$PAPER_INFO" | jq -r '.openAccessPdf.url // empty')
        TITLE=$(echo "$PAPER_INFO" | jq -r '.title // "unknown"')

        if [[ -z "$PDF_URL" ]]; then
            echo "No open-access PDF available for: $TITLE"
            exit 1
        fi

        mkdir -p "$PROJECT_DIR/shared/Research/papers"
        SAFE_NAME=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | head -c 80)
        DEST="$PROJECT_DIR/shared/Research/papers/${SAFE_NAME}.pdf"

        echo "Downloading: $TITLE"
        echo "From: $PDF_URL"
        curl -sL -o "$DEST" "$PDF_URL"
        echo "Saved to: $DEST"
        ;;
esac
