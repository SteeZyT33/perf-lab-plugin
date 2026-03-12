---
name: status
description: Show the multi-agent experiment dashboard
---

# Status Dashboard

1. Run `./scripts/show-progress.sh`
2. Summarize:
   - Current best metric and which agent achieved it
   - Per-agent hit rates (kept vs tried)
   - Which targets have been hit
   - Any new-best alerts pending
3. If patterns emerge (e.g., one agent's strategy consistently works), call that out
