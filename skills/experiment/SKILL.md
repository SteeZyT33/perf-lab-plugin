---
name: experiment
description: Run one optimization iteration — implement a single change, test it, log the result. Use this skill whenever the user wants to try something, make an improvement, test a hypothesis, optimize, or do "one more iteration." Also triggers on "try X", "what if we changed Y", or "make it faster/smaller/better."
---

# Experiment Iteration

## Core loop (do this every time)

1. Read `perf-lab.config.json` for metric, test command, solution file
2. Read `shared/learned-constraints.md` — never violate known boundaries
3. Read `shared/best-metric.txt` for current baseline
4. If a work queue item is assigned to you, implement that. Otherwise, form your own hypothesis (single, testable change). Never re-attempt DISCARDED strategies from `shared/experiments.tsv`.
5. Implement the change in the solution file
6. Run the test command — verify correctness
7. Log the result:
   ```bash
   ./scripts/track-experiment.sh <agent> "<hypothesis>" <KEPT|DISCARDED|FAILED> ["notes"]
   ```
   - **KEPT**: tests pass AND metric improved
   - **DISCARDED**: tests pass but metric worse/same — revert
   - **FAILED**: tests fail — revert
8. If KEPT: update `shared/learned-constraints.md` with what you learned

Never modify test files. Never make multiple changes at once.

## Parallel work (pipeline, don't block)

After logging a result, spawn a background sub-agent for ONE of these (rotate through them each iteration):
- Research the next hypothesis via `/perf-lab:research`
- Analyze the experiment trace for new bottleneck patterns
- Read `shared/Research/findings/` for unread summaries from other agents or research runs
- Query NotebookLM for techniques related to the current bottleneck

Don't wait for the sub-agent to finish. Start your next experiment. Read the sub-agent's findings when they appear in `shared/Research/findings/`.

**IMPORTANT**: Never read files in `shared/Research/papers/` directly — those are full-text paper conversions that will overwhelm your context. Only read the short summaries in `shared/Research/findings/`. If you need details from a specific paper, query NotebookLM or spawn a sub-agent to extract the relevant section.

## Housekeeping (between experiments, not instead of them)

**Every 5th iteration** — update `shared/agent-pulse/<agent>.md`:
```markdown
# Agent: <name>
## Last Updated: <timestamp>
## Current Metric: <value>
## Current Strategy: <one-line>
## What I'm Working On: <focus>
## What I've Learned This Session:
- <findings>
## Next Thing To Try: <planned>
```

**Every 10th iteration** — check messages: `./scripts/messages.sh read <agent>`

**After every experiment** — plateau check: if last `plateau_threshold` experiments (default 10) are ALL DISCARDED/FAILED, auto-invoke `/perf-lab:plateau`.
