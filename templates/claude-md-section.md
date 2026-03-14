## Experiment Protocol (perf-lab v3)

**Config**: `perf-lab.config.json` — all metric names, test commands, targets
**Log**: `shared/experiments.tsv` — append-only, never edit/delete rows
**Best**: `shared/best-metric.txt` — current best metric value
**Knowledge**: `shared/knowledge/` — human-readable research logs (maintained by Bookworm)

### Rules
1. ONE change per experiment. Test. Log. Keep or revert.
2. Never modify test files
3. Read `shared/learned-constraints.md` before proposing changes
4. Never re-attempt DISCARDED strategies from experiments.tsv
5. Log ALL results: `./scripts/track-experiment.sh <agent> "<hypothesis>" <status> ["notes"]`
6. KEPT experiments must survive `verification_runs` (default: 3) — worst result is recorded

### Commands

**Layer 1 — Experiment Discipline:**
- `/perf-lab:init` — initialize perf-lab in a new project (guided setup)
- `/perf-lab:experiment` — run one iteration
- `/perf-lab:status` — show dashboard
- `/perf-lab:research` — search papers, web, NotebookLM

**Layer 2 — Autonomous Iteration:**
- `/perf-lab:sweep` — autonomous optimization loop (with auto-resume)
- `/perf-lab:plateau` — detect plateau, run full breakthrough pipeline
- `/perf-lab:replay` — after architecture change, retry previously discarded experiments
- `/perf-lab:analyze` — trace analysis, identify resource bottlenecks

**Layer 3 — Fleet Orchestration:**
- `/perf-lab:jarvis launch [N]` — launch N research teams
- `/perf-lab:jarvis status` — fleet dashboard
- `/perf-lab:jarvis relay` — broadcast latest breakthrough to all teams
- `/perf-lab:jarvis expand [N]` — add more teams to running fleet
- `/perf-lab:jarvis teardown` — graceful shutdown, merge winner
- `/perf-lab:swarm [N]` — alias for jarvis launch

### Spawning Rules (IMPORTANT)
- **tmux sessions**: ONLY Jarvis creates these (new research teams via `launch-agent.sh`)
- **Agent Teams**: ONLY team leads create these (teammates within their session)
- **Subagents**: Anyone can spawn for quick one-off tasks (they do NOT join teams)
- Never create nested Agent Teams. Never create tmux sessions from a research team.

### Fleet Architecture (v3)
- **Jarvis5A**: orchestrator in user's session — Agent Team with Son of Anton + Bookworm
- **Son of Anton**: monitor (teammate + bash daemon) — heartbeats, breakthrough detection
- **Bookworm**: knowledge curator (teammate) — maintains shared/knowledge/
- **Research Teams**: each tmux session (alpha, beta, gamma...) runs its own Agent Team
  - Team lead coordinates teammates (Experiment, Research, Adversary, etc.)
  - Lead coordinates only when team has 3+ members; experiments on smaller teams
  - Cross-team communication via shared/ directory
  - Within-team communication via Agent Teams (SendMessage, TaskList)
- **Greek alphabet naming**: alpha through omega, as many as needed
- **Heartbeat pulses**: `shared/agent-pulse/` — automatic via track-experiment.sh
- **Metric verification**: KEPT experiments run N times, worst result recorded
