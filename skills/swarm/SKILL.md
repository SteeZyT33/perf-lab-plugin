---
name: swarm
description: Launch a coordinated team of differentiated agents using Claude Code Agent Teams. Use when the user wants parallel optimization with multiple agents, says "launch agents", "run in parallel", "swarm", "multi-agent", or specifies a number of agents to run.
---

# Multi-Agent Swarm (Agent Teams)

Launch a coordinated team of **differentiated** agents for optimization. Each agent has a distinct role — research, analysis, adversarial challenge, exploration, or experimentation — coordinated via Agent Teams' native task list and messaging.

User can specify count: `/perf-lab:swarm 5` to launch 5 agents. Default: number of agents in config (typically 3-5).

## Naming Convention: Parent-Child

All agents follow the **Parent-Child** naming pattern:

```
{ParentName}-{Role}
```

The parent name comes from the user's session or the first name in config's `agents` array. Examples:
- `Alpha-Research`, `Alpha-Adversary`, `Alpha-Explorer`
- `Storm-Analyst`, `Storm-Scout`, `Storm-Experiment`

This tells you **at a glance** what each agent is doing.

## Step 1: Read config and current state

1. Read `perf-lab.config.json` for agent count, metric, targets
2. Parse agent count from arguments if provided (overrides config)
3. Run `./scripts/show-progress.sh` to understand current state
4. Read `shared/learned-constraints.md` and `shared/experiments.tsv`
5. Determine the parent name:
   - Use first name from config `agents` array, OR
   - Ask the user for a callsign (e.g., "Alpha", "Storm")

## Step 2: Create the team

Use **TeamCreate** to create the team:

```
TeamCreate:
  team_name: "perf-lab-{parent}"
  description: "Performance optimization swarm for {metric_name} targeting {target}"
```

## Step 3: Design team composition

The key to effective parallel agents is **role diversity**, not duplicated effort. The team composition depends on N (total agents):

### Default compositions

| N | Composition |
|---|---|
| 3 | 1 Experiment + 1 Research + 1 Adversary |
| 4 | 1 Experiment + 1 Research + 1 Adversary + 1 Explorer |
| 5 | 2 Experiment (different strategies) + 1 Research + 1 Adversary + 1 Explorer |
| 6 | 2 Experiment + 1 Research + 1 Adversary + 1 Explorer + 1 Analyst |
| 7 | 3 Experiment + 1 Research + 1 Adversary + 1 Explorer + 1 Analyst |

**Never** spawn more than half the team as experimenters. Research/adversary/explorer agents provide the insights that make experiments successful.

### Role definitions

Each role maps to an agent definition in `.claude/agents/`:

| Role suffix | Agent file | Purpose | Subagent type |
|---|---|---|---|
| `-Experiment` | (custom prompt) | Implements and tests optimization changes | `general-purpose` |
| `-Research` | (custom prompt) | Queries NotebookLM, reads findings, searches papers | `general-purpose` |
| `-Adversary` | `adversary.md` | Challenges constraints, attacks impossibility claims | `Explore` |
| `-Explorer` | `explorer.md` | Deep-reads system source code for exploitable behaviors | `Explore` |
| `-Analyst` | `analyst.md` | Analyzes experiment history, identifies bottleneck patterns | `Explore` |
| `-Architect` | `architect.md` | Designs breakthrough architectures (spawn on plateau) | `Explore` |
| `-Scout` | `scout.md` | Tests speculative changes in isolated worktree | `general-purpose` with `isolation: "worktree"` |

## Step 4: Create tasks

Use **TaskCreate** for each agent's work. Tasks should have clear deliverables:

Example tasks for a 5-agent team `Alpha`:

1. **Alpha-Research**: "Query NotebookLM notebook '{notebook_name}' for techniques to reduce {metric}. Search shared/Research/findings/ for existing work. Write new findings to shared/Research/findings/. Focus on approaches not yet tried (check shared/experiments.tsv)."

2. **Alpha-Adversary**: "Read shared/learned-constraints.md and shared/experiments.tsv. Challenge the top 3 most impactful DISCARDED constraints. Write results to shared/Research/adversary-challenges.md. Message Alpha-Experiment with any DISPROVEN constraints."

3. **Alpha-Explorer**: "Read all system_files from perf-lab.config.json. Find exploitable behaviors, edge cases, undocumented features. Write findings to shared/Research/system-exploits.md. Message Alpha-Experiment with HIGH-impact discoveries."

4. **Alpha-Experiment-1**: "Focus on {strategy_1}. Read CLAUDE.md and shared/learned-constraints.md. Run experiment loop: implement ONE change, test, log with ./scripts/track-experiment.sh alpha-experiment-1 '<hypothesis>' <status>. Check messages from research/adversary/explorer agents for new ideas."

5. **Alpha-Experiment-2**: "Focus on {strategy_2}. Same protocol as Experiment-1 but explore different optimization axis. Avoid overlapping with Experiment-1's strategy."

## Step 5: Spawn teammates

For each agent in the team, use the **Agent** tool:

```
Agent:
  name: "{Parent}-{Role}"
  team_name: "perf-lab-{parent}"
  subagent_type: (see role table above)
  prompt: |
    You are {Parent}-{Role}, part of the perf-lab optimization team "perf-lab-{parent}".

    Read CLAUDE.md and shared/learned-constraints.md first.
    Current best: [read shared/best-metric.txt]. Target: {target} {metric}.

    YOUR TASK: {task description from Step 4}

    COORDINATION:
    - Check your task list periodically with TaskList
    - Message teammates by name when you have findings they need
    - Log ALL experiment results via ./scripts/track-experiment.sh
    - Read shared/Research/findings/ for research summaries
    - NEVER read shared/Research/papers/ (full texts kill context)

    When done, mark your task complete and check for new tasks.
```

**For Experiment agents**, also include:
- The specific strategy to focus on
- What other agents are doing (so they don't overlap)
- `/perf-lab:sweep` command for autonomous experiment loops

**For Research agents**, also include:
- NotebookLM notebook name from config
- Instructions to query for specific bottleneck topics
- Where to write findings (shared/Research/findings/)

Spawn **read-only agents first** (Research, Explorer, Adversary, Analyst), then experiment agents. This lets research agents start gathering insights while experimenters set up.

## Step 6: Assign tasks

Use **TaskUpdate** to assign each task to its owner:

```
TaskUpdate:
  task_id: <task_id>
  owner: "{Parent}-{Role}"
```

## Step 7: Monitor and coordinate

As the lead agent:

- **Ctrl+T** to view the task list
- **Shift+Down** to cycle through teammates
- Read messages from teammates (delivered automatically)
- When a research/adversary agent finds something, relay it to experimenters
- When experimenters plateau, spawn an `{Parent}-Architect` agent
- Track progress via `./scripts/show-progress.sh`

## Step 8: Report launch status

After all agents are spawned, report:
- Team name and parent callsign
- Agent names and their assigned roles (one-line summary each)
- Number of agents by type
- "Use Ctrl+T to view task list, Shift+Down to cycle between agents"
- "Run `./scripts/show-progress.sh` to monitor experiment progress"

## Coordination

All agents coordinate via TWO systems:

### 1. Agent Teams (native)
- **Task list**: shared tasks with status tracking and dependencies
- **SendMessage**: direct inter-agent messaging for discoveries, alerts, requests

### 2. Shared directory (perf-lab)
- `experiments.tsv` — append-only experiment log (flock-locked)
- `best-metric.txt` — current best metric value
- `learned-constraints.md` — growing knowledge base
- `Research/findings/` — research summaries (safe for context)
- `Research/papers/` — full paper texts (DO NOT read directly)
- `messages/` — cross-agent message files (via ./scripts/messages.sh)

Experiment agents follow the experiment protocol:
- Log ALL results via `./scripts/track-experiment.sh <name> ...`
- Check `./scripts/check-new-best.sh <name>` periodically
- Read messages from research/adversary agents for new ideas

## Teardown

When the user says "stop", "merge", or "done":

1. Send shutdown requests: `SendMessage` with `type: "shutdown_request"` to each teammate
2. Wait for teammates to finish current work
3. Identify the best result via `./scripts/show-progress.sh`
4. Show per-agent contribution summary (experiments tried, kept, best metric achieved)
5. Clean up: `TeamDelete` to remove team and task directories
6. Report final results

## Fallback: tmux mode

If Agent Teams are not available (no `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`), fall back to tmux-based launch:

1. Run `./scripts/setup-worktrees.sh` to create worktrees
2. Run `./scripts/launch-agent.sh <name>` for each agent
3. Each agent gets its own tmux session + worktree + prompt
4. Coordination via shared/ directory only (no task list or messaging)
