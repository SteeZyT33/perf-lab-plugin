---
name: sweep
description: Autonomous optimization loop — runs /perf-lab:experiment repeatedly via ralph-loop until the target is hit or max iterations reached. Use this instead of /perf-lab:experiment when the user wants hands-off autonomous iteration, says "keep going", "run until done", "optimize on your own", or "don't stop until we hit the target."
---

# Autonomous Sweep

Launch an autonomous optimization loop that runs `/perf-lab:experiment` repeatedly. The experiment skill has built-in plateau detection — when it triggers, the breakthrough sequence runs automatically and the sweep resumes.

1. Read `perf-lab.config.json` for `max_total_iterations`, `target`, and `max_breakthrough_cycles`
2. Run `./scripts/show-progress.sh` for current state
3. Reset `shared/breakthrough-count.txt` to 0 (fresh sweep = fresh budget)
4. Start the ralph loop:

```
/ralph-loop "Run /perf-lab:experiment each iteration. Run ./scripts/show-progress.sh before each iteration. Never re-attempt DISCARDED experiments. Log everything with ./scripts/track-experiment.sh. Target: {{TARGET}} {{METRIC_NAME}}." --max-iterations {{MAX_TOTAL_ITERATIONS}}
```

Replace `{{TARGET}}`, `{{METRIC_NAME}}`, and `{{MAX_TOTAL_ITERATIONS}}` from config.

## Sweep with Autonomous Breakthroughs

The sweep runs `/perf-lab:experiment` in a loop. When a plateau is detected, the experiment skill auto-triggers `/perf-lab:plateau`, which runs the breakthrough sequence. After breakthrough completes:

1. If `/perf-lab:rewrite` produced an improvement: the sweep continues on the new architecture. The plateau counter stays incremented but the consecutive-failure count resets.
2. If `/perf-lab:rewrite` did NOT improve: the breakthrough count is still incremented, the rewrite is reverted, and the sweep continues with the existing code.
3. If `max_breakthrough_cycles` reached: exit the sweep and report to the user.

The full autonomous loop:

```
sweep → experiment → experiment → ... → plateau detected →
  research refresh → explore/challenge → architect → rewrite →
  sweep resumes → experiment → experiment → ...
```

This continues until either:
- Target metric is reached
- `max_total_iterations` hit (budget exhausted)
- `max_breakthrough_cycles` hit (system needs human guidance)
