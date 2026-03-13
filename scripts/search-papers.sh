#!/usr/bin/env bash
# search-papers.sh — Search Semantic Scholar for academic papers
#
# Usage: ./scripts/search-papers.sh "<query>" [limit]
#
# Examples:
#   ./scripts/search-papers.sh "VLIW pipeline scheduling optimization"
#   ./scripts/search-papers.sh "hash function SIMD vectorization" 10

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 \"<query>\" [limit]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PERF_LAB_PROJECT:-$(dirname "$SCRIPT_DIR")}"
CONFIG="$PROJECT_DIR/perf-lab.config.json"

QUERY="$1"
LIMIT="${2:-5}"
ENCODED=$(python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")
FIELDS="title,abstract,year,citationCount,url,tldr,authors"

# Use API key if configured (higher rate limits)
CURL_HEADERS=()
if [[ -f "$CONFIG" ]]; then
    API_KEY=$(jq -r '.semantic_scholar_api_key // ""' "$CONFIG")
    [[ -n "$API_KEY" ]] && CURL_HEADERS=(-H "x-api-key: $API_KEY")
fi

RESPONSE=$(curl -s --retry 2 --retry-delay 3 "${CURL_HEADERS[@]+"${CURL_HEADERS[@]}"}" "https://api.semanticscholar.org/graph/v1/paper/search?query=${ENCODED}&limit=${LIMIT}&fields=${FIELDS}")

# Check for rate limiting
if echo "$RESPONSE" | jq -e '.code == "429"' &>/dev/null; then
    echo "Rate limited. Retrying in 5s..."
    sleep 5
    RESPONSE=$(curl -s "https://api.semanticscholar.org/graph/v1/paper/search?query=${ENCODED}&limit=${LIMIT}&fields=${FIELDS}")
fi

# Check for errors
if echo "$RESPONSE" | jq -e '.error // .message' &>/dev/null; then
    echo "Error: $(echo "$RESPONSE" | jq -r '.error // .message')"
    exit 1
fi

TOTAL=$(echo "$RESPONSE" | jq -r '.total // 0')
echo "Found $TOTAL papers (showing top $LIMIT)"
echo ""

echo "$RESPONSE" | jq -r '.data[]? | [
  "### \(.title) (\(.year // "n/a"))",
  "- **Authors**: \([ .authors[]?.name ] | join(", "))",
  "- **Citations**: \(.citationCount // 0)",
  "- **URL**: \(.url // "n/a")",
  (if .tldr.text then "- **TLDR**: \(.tldr.text)" else "" end),
  (if .abstract then "- **Abstract**: \(.abstract[:300])..." else "" end),
  ""
] | join("\n")'
