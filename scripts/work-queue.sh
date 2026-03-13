#!/usr/bin/env bash
# work-queue.sh — Simple append-only work queue for agent task assignment
#
# Usage:
#   ./scripts/work-queue.sh add "description" [priority] [assigned_to]
#   ./scripts/work-queue.sh claim <agent-name>
#   ./scripts/work-queue.sh complete <id> <done|abandoned>
#   ./scripts/work-queue.sh list

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${PERF_LAB_PROJECT:-$(dirname "$SCRIPT_DIR")}"
QUEUE="$PROJECT_DIR/shared/work-queue.tsv"

if [[ ! -f "$QUEUE" ]]; then
    echo -e "id\tstatus\tassigned_to\tdescription\tpriority\tcreated\tstarted\tcompleted" > "$QUEUE"
fi

next_id() { tail -n 1 "$QUEUE" | cut -f1; }

case "${1:-}" in
    add)
        [[ $# -lt 2 ]] && { echo "Usage: $0 add \"description\" [high|medium|low] [agent]"; exit 1; }
        DESC="$2"; PRIO="${3:-medium}"; ASSIGN="${4:--}"
        LAST=$(next_id)
        [[ "$LAST" == "id" || -z "$LAST" ]] && ID=1 || ID=$((LAST + 1))
        echo -e "${ID}\tqueued\t${ASSIGN}\t${DESC}\t${PRIO}\t$(date -Iseconds)\t-\t-" >> "$QUEUE"
        echo "Added work item #${ID}: ${DESC} [${PRIO}]"
        ;;

    claim)
        [[ $# -lt 2 ]] && { echo "Usage: $0 claim <agent-name>"; exit 1; }
        AGENT="$2"
        # Find highest-priority queued item (high > medium > low)
        ITEM=$(awk -F'\t' '$2=="queued" && ($3=="-" || $3=="'"$AGENT"'")' "$QUEUE" | \
            awk -F'\t' '{p=3; if($5=="high")p=1; if($5=="medium")p=2; print p"\t"$0}' | \
            sort -t$'\t' -k1,1n | head -1 | cut -f2-)
        if [[ -z "$ITEM" ]]; then
            echo "No queued items available."
            exit 0
        fi
        ITEM_ID=$(echo "$ITEM" | cut -f1)
        ITEM_DESC=$(echo "$ITEM" | cut -f4)
        # Update status to running
        sed -i "s/^${ITEM_ID}\tqueued\t[^\t]*/&/" "$QUEUE"
        awk -F'\t' -v OFS='\t' -v id="$ITEM_ID" -v agent="$AGENT" -v ts="$(date -Iseconds)" \
            '$1==id && $2=="queued" {$2="running"; $3=agent; $6=ts} 1' "$QUEUE" > "${QUEUE}.tmp" && mv "${QUEUE}.tmp" "$QUEUE"
        echo "Claimed #${ITEM_ID}: ${ITEM_DESC}"
        echo "$ITEM_DESC"
        ;;

    complete)
        [[ $# -lt 3 ]] && { echo "Usage: $0 complete <id> <done|abandoned>"; exit 1; }
        ITEM_ID="$2"; NEW_STATUS="$3"
        [[ "$NEW_STATUS" != "done" && "$NEW_STATUS" != "abandoned" ]] && { echo "Status must be done or abandoned"; exit 1; }
        awk -F'\t' -v OFS='\t' -v id="$ITEM_ID" -v s="$NEW_STATUS" -v ts="$(date -Iseconds)" \
            '$1==id && $2=="running" {$2=s; $8=ts} 1' "$QUEUE" > "${QUEUE}.tmp" && mv "${QUEUE}.tmp" "$QUEUE"
        echo "Marked #${ITEM_ID} as ${NEW_STATUS}"
        ;;

    list)
        if [[ $(wc -l < "$QUEUE") -le 1 ]]; then
            echo "Work queue is empty."
            exit 0
        fi
        echo "=== Work Queue ==="
        echo ""
        QUEUED=$(awk -F'\t' '$2=="queued"' "$QUEUE" | wc -l)
        RUNNING=$(awk -F'\t' '$2=="running"' "$QUEUE" | wc -l)
        echo "Queued: $QUEUED  Running: $RUNNING"
        echo ""
        awk -F'\t' '$2=="queued" || $2=="running" {printf "#%-3s [%-7s] %-8s %s (%s)\n", $1, $2, $3, $4, $5}' "$QUEUE"
        ;;

    *)
        echo "Usage: $0 {add|claim|complete|list}"
        exit 1
        ;;
esac
