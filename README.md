# perf-lab-plugin

Autonomous multi-agent performance optimization plugin for Claude Code. Generalizes the experiment-loop pattern: multiple agents explore different optimization strategies in parallel, logging to a shared append-only TSV, coordinating via best-metric alerts.

Inspired by Karpathy's autoresearch pattern: single metric, autonomous iteration, never-stop loop.

## Install

```bash
cd /path/to/your/project
/path/to/perf-lab-plugin/install.sh .
```

Requires: `jq`, `git`, `tmux` (for parallel agents).

## Configure

Edit `perf-lab.config.json` in your project root:

```json
{
  "metric_name": "latency_ms",
  "direction": "lower",
  "test_command": "pytest tests/ -x",
  "parse_metric": "grep -oP '\\d+(?=ms)'",
  "solution_file": "src/engine.py",
  "target": 50,
  "targets": { "200": "Baseline", "100": "v1 goal", "50": "stretch" },
  "agents": ["alpha", "beta"],
  "max_iterations": 30,
  "notebook_name": "My Research Notebook"
}
```

- `direction`: `"lower"` = smaller is better, `"higher"` = bigger is better
- `parse_metric`: shell command piped test output to extract the metric value

## Usage

| Command | What it does |
|---|---|
| `/perf-lab:experiment` | Run one optimization iteration |
| `/perf-lab:status` | Show experiment dashboard |
| `/perf-lab:research` | Query NotebookLM for ideas |
| `/perf-lab:sweep` | Autonomous ralph-loop optimization |

### Multi-agent parallel mode

```bash
./scripts/setup-worktrees.sh   # Create git worktrees per agent
./scripts/launch-agent.sh alpha # Launch in tmux
./scripts/launch-agent.sh beta
```

## Architecture

- **`shared/experiments.tsv`** — append-only experiment log (never edit rows)
- **`shared/best-metric.txt`** — current best value
- **`shared/learned-constraints.md`** — what works and what doesn't
- **`shared/new-best-alert.txt`** — cross-agent coordination
- **`scripts/`** — config-driven bash scripts (all read `perf-lab.config.json`)
- **`@analyst`** — read-only bottleneck analysis agent
- **`@scout`** — isolated exploratory testing agent
