#!/usr/bin/env bash
# messages.sh — Lightweight agent messaging via markdown files
#
# Usage:
#   ./scripts/messages.sh send <from> <to|all> <type> "message body"
#   ./scripts/messages.sh read <agent-name>
#   ./scripts/messages.sh list

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PERF_LAB_PROJECT:-$(dirname "$SCRIPT_DIR")}"
MSG_DIR="$PROJECT_DIR/shared/messages"
mkdir -p "$MSG_DIR"

case "${1:-}" in
    send)
        [[ $# -lt 5 ]] && { echo "Usage: $0 send <from> <to|all> <type> \"message\""; exit 1; }
        FROM="$2"; TO="$3"; TYPE="$4"; BODY="$5"
        TS=$(date -Iseconds)
        SAFE_TS=$(echo "$TS" | tr ':' '-')
        FILE="$MSG_DIR/${SAFE_TS}-${FROM}-${TO}.md"
        cat > "$FILE" <<EOF
# From: ${FROM}
# To: ${TO}
# Type: ${TYPE}
# Timestamp: ${TS}

${BODY}
EOF
        echo "Message sent: ${TYPE} from ${FROM} to ${TO}"
        ;;

    read)
        [[ $# -lt 2 ]] && { echo "Usage: $0 read <agent-name>"; exit 1; }
        AGENT="$2"
        FOUND=0
        for MSG in "$MSG_DIR"/*.md; do
            [[ ! -f "$MSG" ]] && continue
            BASENAME=$(basename "$MSG")
            # Check if message is to this agent or to all
            TO=$(grep '^# To:' "$MSG" | sed 's/# To: //')
            [[ "$TO" != "$AGENT" && "$TO" != "all" ]] && continue
            # Check if already read
            READ_FILE="${MSG}.read"
            if [[ -f "$READ_FILE" ]] && { grep -q "^${AGENT}$" "$READ_FILE" 2>/dev/null || false; }; then
                continue
            fi
            # Show unread message
            FOUND=$((FOUND + 1))
            echo "--- Unread: $BASENAME ---"
            cat "$MSG"
            echo ""
            # Mark as read
            echo "$AGENT" >> "$READ_FILE"
        done
        if [[ $FOUND -eq 0 ]]; then echo "No unread messages for ${AGENT}."; fi
        ;;

    list)
        COUNT=0
        for MSG in "$MSG_DIR"/*.md; do
            [[ ! -f "$MSG" ]] && continue
            COUNT=$((COUNT + 1))
            FROM=$(grep '^# From:' "$MSG" | sed 's/# From: //')
            TO=$(grep '^# To:' "$MSG" | sed 's/# To: //')
            TYPE=$(grep '^# Type:' "$MSG" | sed 's/# Type: //')
            TS=$(grep '^# Timestamp:' "$MSG" | sed 's/# Timestamp: //')
            printf "[%-9s] %s → %-8s %s\n" "$TYPE" "$FROM" "$TO" "$TS"
        done
        [[ $COUNT -eq 0 ]] && echo "No messages."
        ;;

    *)
        echo "Usage: $0 {send|read|list}"
        exit 1
        ;;
esac
