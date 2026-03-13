---
name: status
description: Show the multi-agent experiment dashboard with current best metric, per-agent stats, and target progress. Use this whenever the user asks about progress, results, "how are we doing", "what's the score", "show me the dashboard", or wants a summary of experiments so far.
---

# Status Dashboard

1. Run `./scripts/show-progress.sh`
2. Summarize:
   - Current best metric and which agent achieved it
   - Per-agent hit rates (kept vs tried)
   - Which targets have been hit
   - Any new-best alerts pending
3. If patterns emerge (e.g., one agent's strategy consistently works), call that out
4. Plateau warning: if last 5+ experiments are all DISCARDED/FAILED, flag it:
   "Approaching plateau — N consecutive failures. Consider /perf-lab:plateau"
5. Budget check: if `shared/breakthrough-count.txt` exists, show:
   "Breakthrough cycles used: N / max_breakthrough_cycles"

Keep output concise. This is a glance, not an analysis. Under 20 lines.
