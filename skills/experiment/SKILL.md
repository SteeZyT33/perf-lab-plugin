---
name: experiment
description: Run one optimization iteration — implement change, test, log result
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
