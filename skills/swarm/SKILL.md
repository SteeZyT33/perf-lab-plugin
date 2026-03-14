---
name: swarm
description: "Launch a coordinated fleet of research TEAMS via Jarvis5A. Use when the user wants parallel optimization with multiple agents, says 'launch agents', 'run in parallel', 'swarm', 'multi-agent', 'launch teams', or specifies a number of teams to run. This is the v3 team-based architecture."
---

# Multi-Agent Swarm v3 — Research Teams via Jarvis5A

**This skill delegates to Jarvis5A.** The swarm is now a fleet of research TEAMS, not individual agents. Each team runs in its own tmux session with its own internal Agent Team.

User can specify count: `/perf-lab:swarm 5` to launch 5 teams. Default: 3.

## How it works

1. Invoke `/perf-lab:jarvis` with the team count
2. Jarvis launches Son of Anton (monitor daemon)
3. Jarvis launches N tmux sessions using Greek alphabet names
4. Each session creates its own Agent Team internally (via agent-template mandate)
5. Son of Anton monitors all teams and reports to Jarvis

## Quick Launch

The swarm skill is a thin wrapper. When invoked, it delegates entirely to `/perf-lab:jarvis launch [N]`.

**Do NOT duplicate Jarvis logic here.** Invoke the Jarvis skill directly:

```
/perf-lab:jarvis launch [N]
```

Where N is the team count from arguments (default: `team_count` from config).

Jarvis handles everything: command team creation, Son of Anton launch, worktree setup, team launches, and Bookworm initialization.

## Team Structure (per session)

Each tmux session runs ONE Claude instance that creates an Agent Team:

```
tmux:alpha → Claude (team lead "Alpha")
  ├── Alpha-Experiment  (general-purpose — runs optimization loop)
  ├── Alpha-Research    (general-purpose — papers, NotebookLM, web)
  ├── Alpha-Adversary   (Explore — challenges constraints)
  └── ...additional roles from team_roles config
```

The team lead coordinates its teammates. Teammates can spawn their own subagents.

## Cross-Team Communication

Teams coordinate via shared/ directory:
- `experiments.tsv` — append-only experiment log (flock-locked)
- `best-metric.txt` — current best metric value
- `learned-constraints.md` — growing knowledge base
- `messages/` — cross-team message files (via ./scripts/messages.sh)
- `agent-pulse/` — heartbeat files for Son of Anton
- `jarvis-inbox/` — Son of Anton reports for Jarvis
- `Research/findings/` — research summaries (safe for context)

Agent Teams messaging (SendMessage/TaskList) works WITHIN a team session only.
Cross-session communication goes through shared/ files.

## Monitoring

- **Son of Anton** (tmux: son-of-anton) — automated monitoring, breakthrough detection
- **Jarvis** (`/perf-lab:jarvis`) — on-demand fleet status from user's session
- **Dashboard** (`./scripts/show-progress.sh`) — experiment stats + agent health

## Teardown

When the user says "stop", "merge", or "done":

1. Run `./scripts/show-progress.sh` for final results
2. Identify best result and which team achieved it
3. Show per-team contribution summary
4. Confirm with user before killing sessions
5. `tmux kill-session -t <name>` for each team + son-of-anton
