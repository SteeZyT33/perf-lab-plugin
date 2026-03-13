## Experiment Protocol (perf-lab)

**Config**: `perf-lab.config.json` — all metric names, test commands, targets
**Log**: `shared/experiments.tsv` — append-only, never edit/delete rows
**Best**: `shared/best-metric.txt` — current best metric value

### Rules
1. ONE change per experiment. Test. Log. Keep or revert.
2. Never modify test files — validate with `git diff origin/main tests/`
3. Read `shared/learned-constraints.md` before proposing changes
4. Run `./scripts/show-progress.sh` before each iteration
5. Never re-attempt DISCARDED strategies from experiments.tsv
6. Log ALL results: `./scripts/track-experiment.sh <agent> "<hypothesis>" <status> ["notes"]`
7. Check for new bests: `./scripts/check-new-best.sh <agent>`

### Commands
- `/perf-lab:experiment` — run one iteration
- `/perf-lab:status` — show dashboard
- `/perf-lab:research` — query NotebookLM for ideas
- `/perf-lab:sweep` — autonomous optimization loop
- `/perf-lab:plateau` — detect plateau, trigger breakthrough sequence (explorer → adversary → architect)
- `/perf-lab:rewrite` — implement architect's redesign (backup → rewrite → evaluate)

### Plateau Agents
- `@explorer` — exhaustive source-code reader, finds exploitable behaviors
- `@adversary` — challenges impossibility claims and constraint assumptions
- `@architect` — designs fundamentally new approaches when incremental optimization stalls
