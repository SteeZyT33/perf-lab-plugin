---
name: experiment
description: Run one optimization iteration — implement a single change, test it, log the result. Use this skill whenever the user wants to try something, make an improvement, test a hypothesis, optimize, or do "one more iteration." Also triggers on "try X", "what if we changed Y", or "make it faster/smaller/better."
---

# Experiment Iteration

1. Read `perf-lab.config.json` for metric, test command, and solution file
2. Read `shared/learned-constraints.md` — never violate known boundaries
3. Run `./scripts/show-progress.sh` — review past experiments, never re-attempt DISCARDED strategies
4. Read `shared/best-metric.txt` for current baseline

## Execute ONE change

5. Form a hypothesis (single, testable change)
6. Implement the change in the solution file
7. Run the test command from config — verify correctness first
8. Log the result:
   ```bash
   ./scripts/track-experiment.sh <agent> "<hypothesis>" <KEPT|DISCARDED|FAILED> ["notes"]
   ```
   - **KEPT**: tests pass AND metric improved
   - **DISCARDED**: tests pass but metric worse/same — revert the change
   - **FAILED**: tests fail — revert the change

9. If KEPT: check if you beat any targets, update `shared/learned-constraints.md` with what you learned
10. Run `./scripts/check-new-best.sh <agent>` — if another agent found something better, consider rebasing

Never modify test files. Never make multiple changes at once.

## Auto-Plateau Detection

After logging each experiment result, check for plateau:

1. Read the last `plateau_threshold` entries from `shared/experiments.tsv` (default: 10 from config)
2. If ALL are DISCARDED or FAILED (zero KEPT):
   - Read `shared/breakthrough-count.txt` (default: 0)
   - If count < `max_breakthrough_cycles` from config (default: 3):
     - Increment `shared/breakthrough-count.txt`
     - Auto-invoke `/perf-lab:plateau`
   - If count >= `max_breakthrough_cycles`:
     - STOP. Report to user: "Hit max breakthrough cycles (N). The system has tried N architectural rewrites without reaching target. Human review recommended."
3. If not all failures, continue normal iteration
