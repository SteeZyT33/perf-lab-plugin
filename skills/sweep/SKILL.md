---
name: sweep
description: Autonomous optimization loop — runs /perf-lab:experiment repeatedly via ralph-loop until the target is hit or max iterations reached. Use this instead of /perf-lab:experiment when the user wants hands-off autonomous iteration, says "keep going", "run until done", "optimize on your own", or "don't stop until we hit the target."
---

# Autonomous Sweep

Launch an autonomous optimization loop. The experiment skill has built-in plateau detection — breakthroughs run automatically.

## Startup

1. Read `perf-lab.config.json` for `max_total_iterations` (default: 200), `target`
2. **Resume check**: if `shared/agent-pulse/<agent>.md` exists, read it to restore context (strategy, learnings, next planned experiment) instead of starting fresh
3. Run `./scripts/show-progress.sh` for current state
4. Reset `shared/breakthrough-count.txt` to 0
5. Start the ralph loop:

```
/ralph-loop "Run /perf-lab:experiment each iteration. Never re-attempt DISCARDED experiments. Target: {{TARGET}} {{METRIC_NAME}}." --max-iterations {{MAX_TOTAL_ITERATIONS}}
```

## How breakthroughs work during a sweep

When plateau is detected, the experiment skill auto-triggers `/perf-lab:plateau` which runs the full breakthrough-to-rewrite pipeline. After it completes:

1. **Rewrite improved**: sweep continues on new architecture
2. **Rewrite failed**: sweep continues with existing code, breakthrough count incremented
3. **Max breakthroughs hit**: sweep exits, reports to user

Exits when: target reached, `max_total_iterations` hit, or `max_breakthrough_cycles` exhausted.
