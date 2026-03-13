## Experiment Protocol (perf-lab)

**Config**: `perf-lab.config.json` — all metric names, test commands, targets
**Log**: `shared/experiments.tsv` — append-only, never edit/delete rows
**Best**: `shared/best-metric.txt` — current best metric value

### Rules
1. ONE change per experiment. Test. Log. Keep or revert.
2. Never modify test files
3. Read `shared/learned-constraints.md` before proposing changes
4. Never re-attempt DISCARDED strategies from experiments.tsv
5. Log ALL results: `./scripts/track-experiment.sh <agent> "<hypothesis>" <status> ["notes"]`

### Commands
- `/perf-lab:init` — initialize perf-lab in a new project (guided setup)
- `/perf-lab:experiment` — run one iteration
- `/perf-lab:status` — show dashboard
- `/perf-lab:research` — search papers, web, NotebookLM
- `/perf-lab:sweep` — autonomous optimization loop (with auto-resume)
- `/perf-lab:plateau` — detect plateau, run full breakthrough → rewrite pipeline
- `/perf-lab:swarm [N]` — launch N parallel agents with differentiated strategies
- `/perf-lab:analyze` — trace analysis, identify resource bottlenecks
- `/perf-lab:replay` — after architecture change, retry previously discarded experiments
