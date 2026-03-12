---
name: sweep
description: Autonomous optimization loop — runs /perf-lab:experiment repeatedly via ralph-loop
---

# Autonomous Sweep

Launch an autonomous optimization loop that runs `/perf-lab:experiment` repeatedly.

1. Read `perf-lab.config.json` for `max_iterations` and `target`
2. Run `./scripts/show-progress.sh` for current state
3. Start the ralph loop:

```
/ralph-loop "Run /perf-lab:experiment each iteration. Run ./scripts/show-progress.sh before each iteration. Never re-attempt DISCARDED experiments. If stuck for 5 iterations, use /perf-lab:research to find new approaches. Target: {{TARGET}} {{METRIC_NAME}}." --max-iterations {{MAX_ITERATIONS}}
```

Replace `{{TARGET}}`, `{{METRIC_NAME}}`, and `{{MAX_ITERATIONS}}` from config.

The loop will autonomously iterate until the target is hit or max iterations reached.
