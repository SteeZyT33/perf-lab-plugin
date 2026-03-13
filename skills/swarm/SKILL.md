---
name: swarm
description: Launch multiple parallel agents, each in its own worktree, running /perf-lab:sweep independently with shared experiment tracking. Use when the user wants parallel optimization with multiple agents, says "launch agents", "run in parallel", "swarm", "multi-agent", or specifies a number of agents to run.
---

# Multi-Agent Swarm

Launch N parallel agents for autonomous optimization. Each agent gets a genuinely different strategy and its own worktree, sharing experiment tracking and coordination files.

User can specify count: `/perf-lab:swarm 5` to launch 5 agents. Default: number of agents in config (typically 3).

## Step 1: Read config and current state

1. Read `perf-lab.config.json` for agent count, metric, targets
2. Parse agent count from arguments if provided (overrides config)
3. Run `./scripts/show-progress.sh` to understand current state
4. Read `shared/learned-constraints.md` and `shared/experiments.tsv`

## Step 2: Generate differentiated strategies

The key to effective parallel agents is DIFFERENT strategies, not duplicated effort. Before launching, spawn an `@architect` sub-agent to:

1. Read the current solution file, experiment history, and constraints
2. Propose N distinct optimization strategies — each must attack a different bottleneck or use a different technique
3. Write each strategy to `prompts/agent-{i}.md` using the prompt template format:
   - Agent identity and strategy description
   - Specific techniques to explore
   - What to avoid (other agents' strategies, to prevent overlap)

If the architect can't find N genuinely distinct strategies, reduce agent count to however many it can differentiate. 2 agents with different strategies beats 5 agents doing the same thing. Report the reduction to the user.

## Step 3: Set up worktrees

For each agent (1 to N):

1. Create worktree:
   ```bash
   git worktree add "$HOME/agent-${i}" -b "perf-lab/agent-${i}" HEAD
   ```

2. Symlink shared resources so all agents coordinate:
   ```bash
   ln -sf "$(pwd)/shared" "$HOME/agent-${i}/shared"
   cp "$(pwd)/CLAUDE.md" "$HOME/agent-${i}/CLAUDE.md"
   cp "$(pwd)/perf-lab.config.json" "$HOME/agent-${i}/perf-lab.config.json"
   ```

## Step 4: Launch agents

For each agent:

1. Create tmux session:
   ```bash
   tmux new-session -d -s "agent-${i}" -c "$HOME/agent-${i}"
   tmux send-keys -t "agent-${i}" "export CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000" Enter
   tmux send-keys -t "agent-${i}" "claude" Enter
   ```

2. Copy prompt for easy pasting:
   ```bash
   cp "prompts/agent-${i}.md" "$HOME/agent-${i}-prompt.md"
   ```

## Step 5: Report launch status

After all agents are launched, report:
- Number of agents launched
- Strategy assigned to each (one-line summary)
- tmux session names: `tmux attach -t agent-1`, etc.
- Prompt locations for pasting
- "All agents share `shared/` — run `./scripts/show-progress.sh` to monitor"

## Coordination

All agents share via symlinked `shared/`:
- `experiments.tsv` — append-only, no conflicts (one row per experiment)
- `best-metric.txt` — updated atomically by `track-experiment.sh`
- `learned-constraints.md` — any agent can append findings
- `Research/` — shared research findings
- `messages/` — cross-agent messaging (discoveries, new-best alerts, warnings)
- `agent-state/` — per-agent checkpoints for session recovery
- `work-queue.tsv` — shared task queue for coordinated work

Each agent follows the experiment protocol:
- Log ALL results via `./scripts/track-experiment.sh agent-{i} ...`
- Check `./scripts/check-new-best.sh agent-{i}` periodically
- When another agent posts a new best, consider rebasing onto it
- Auto-plateau detection runs per-agent via the experiment skill

## Teardown

When the user says "stop", "merge", or "done":

1. Identify the best result across all agent branches
2. Show per-agent contribution summary (experiments tried, kept, best metric achieved)
3. Ask user to confirm merge strategy:
   - Merge the winning branch to main
   - Or cherry-pick specific improvements from multiple branches
4. Kill tmux sessions: `tmux kill-session -t agent-{i}`
5. Remove worktrees: `git worktree remove "$HOME/agent-${i}"`
6. Report final results
