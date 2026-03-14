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

The swarm skill is a shortcut. When invoked:

### Step 0: Launch Son of Anton

```bash
if ! tmux has-session -t son-of-anton 2>/dev/null; then
    tmux new-session -d -s son-of-anton -c "$(pwd)" "./scripts/son-of-anton.sh"
    echo "Son of Anton launched (tmux: son-of-anton)"
fi
```

### Step 1: Read config and determine team count

1. Read `perf-lab.config.json` for metric, targets, `team_roles`, `team_count`
2. Parse team count from arguments if provided (overrides config)
3. Run `./scripts/show-progress.sh` if experiments.tsv exists
4. `mkdir -p shared/agent-pulse shared/jarvis-inbox`

### Step 2: Setup worktrees and launch teams

Greek alphabet order: alpha, beta, gamma, delta, epsilon, zeta, eta, theta, iota, kappa, lambda, mu, nu, xi, omicron, pi, rho, sigma, tau, upsilon, phi, chi, psi, omega

For each team (up to the requested count):

```bash
./scripts/setup-worktrees.sh   # idempotent — creates what's missing
./scripts/launch-agent.sh alpha
./scripts/launch-agent.sh beta
./scripts/launch-agent.sh gamma
# ... etc
```

Each team's tmux session receives the agent-template prompt which **mandates** creating an internal Agent Team with roles from `team_roles` config.

### Step 3: Report launch status

Report what was launched — team names, tmux session names, team roles.
Remind user: "Run `/perf-lab:jarvis` for fleet status and orchestration."

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
