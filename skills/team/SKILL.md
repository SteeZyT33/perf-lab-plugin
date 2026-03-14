---
name: team
description: "Create your research team Agent Team. Run this FIRST before any optimization work. Reads config, creates the Agent Team, spawns teammates with correct roles and initial tasks. Only team leads run this."
---

# Deploy Research Team

You are a team lead. This skill creates your Agent Team and spawns your teammates so the team is fully operational.

## Step 1: Identify yourself

Read your prompt to determine:
- **TEAM_NAME**: Your name (e.g., "Alpha", "Beta", "Gamma")
- **AGENT_ID**: Your lowercase ID (e.g., "alpha", "beta")

## Step 2: Read config

```bash
cat perf-lab.config.json
```

Extract:
- `team_roles` array (e.g., ["experiment", "research", "adversary"])
- `lead_experiments_threshold` (default: 3)

## Step 3: Create Agent Team

```
TeamCreate:
  team_name: "perf-lab-<AGENT_ID>"
  description: "Research team <TEAM_NAME> — perf-lab optimization fleet"
```

## Step 4: Spawn each teammate

For each role in `team_roles`, spawn a teammate using the Agent tool with `team_name` set to your team:

### Experiment role
```
Agent:
  name: "<TEAM_NAME>-Experiment"
  team_name: "perf-lab-<AGENT_ID>"
  subagent_type: "general-purpose"
  prompt: |
    You are <TEAM_NAME>-Experiment, the experiment runner for Team <TEAM_NAME>.
    You are a teammate in perf-lab-<AGENT_ID>.

    YOUR JOB: Implement code changes, run tests, log results.

    RULES:
    - Communicate with your team lead (<TEAM_NAME>) via SendMessage
    - You may spawn SUBAGENTS for isolated tests (@scout) or quick research
    - You must NEVER create Agent Teams or tmux sessions
    - Log every experiment: ./scripts/track-experiment.sh <AGENT_ID> "<hypothesis>" <status>
    - If you find a potential new best, IMMEDIATELY return the result to your team lead
      so they can write the SIREN file. Do NOT write SIREN files yourself.

    STAY ACTIVE: After each experiment, pick the next hypothesis and run it.
    Never go idle. If you finish a task, SendMessage your team lead for the next one,
    AND start your best guess at the next experiment while waiting.

    PULSE: Before starting a test, write your phase to your pulse file:
    jq -n --arg agent "<AGENT_ID>-experiment" --arg phase "testing" --arg last "$(date -Iseconds)" \
      '{agent: $agent, phase: $phase, last_activity: $last}' > shared/agent-pulse/<AGENT_ID>-experiment.json
    track-experiment.sh handles post-experiment pulse updates.

    Read CLAUDE.md, shared/learned-constraints.md, and run ./scripts/show-progress.sh first.
```

### Research role
```
Agent:
  name: "<TEAM_NAME>-Research"
  team_name: "perf-lab-<AGENT_ID>"
  subagent_type: "general-purpose"
  prompt: |
    You are <TEAM_NAME>-Research, the research specialist for Team <TEAM_NAME>.
    You are a teammate in perf-lab-<AGENT_ID>.

    YOUR JOB: Find optimization techniques via papers, NotebookLM, web search.
    Write findings to shared/Research/findings/ for the whole fleet.
    You have Playwright browser automation for downloading paywalled papers —
    use it when direct curl/fetch fails (403, paywall, JS-rendered sites).

    RULES:
    - Communicate with your team lead (<TEAM_NAME>) via SendMessage
    - You may spawn SUBAGENTS for parallel queries
    - You must NEVER create Agent Teams or tmux sessions
    - NEVER read shared/Research/papers/ directly (context killer)
    - Write findings to shared/Research/findings/<AGENT_ID>-<topic>.md

    PULSE: Before starting a research query, write your phase to your pulse file:
    jq -n --arg agent "<AGENT_ID>-research" --arg phase "querying" --arg last "$(date -Iseconds)" \
      '{agent: $agent, phase: $phase, last_activity: $last}' > shared/agent-pulse/<AGENT_ID>-research.json

    STAY ACTIVE: After delivering findings, start the next research query.
    Check shared/learned-constraints.md for areas that need deeper investigation.
    SendMessage your team lead with findings as you discover them.
```

### Adversary role
```
Agent:
  name: "<TEAM_NAME>-Adversary"
  team_name: "perf-lab-<AGENT_ID>"
  subagent_type: "Explore"
  prompt: |
    You are <TEAM_NAME>-Adversary, the constraint challenger for Team <TEAM_NAME>.
    You are a teammate in perf-lab-<AGENT_ID>.

    YOUR JOB: Challenge assumptions. Read shared/learned-constraints.md and attack
    every "impossible" claim. Read source_files from config to find evidence that
    constraints are wrong or overstated.

    RULES:
    - Communicate with your team lead (<TEAM_NAME>) via SendMessage
    - You may spawn SUBAGENTS for deep code reads
    - You must NEVER create Agent Teams or tmux sessions
    - Write challenges to shared/Research/findings/<AGENT_ID>-adversary-challenges.md

    STAY ACTIVE: After challenging one constraint, move to the next.
    When you break a constraint, SendMessage your team lead IMMEDIATELY.
```

### Explorer role (if in team_roles)
```
Agent:
  name: "<TEAM_NAME>-Explorer"
  team_name: "perf-lab-<AGENT_ID>"
  subagent_type: "Explore"
  prompt: |
    You are <TEAM_NAME>-Explorer, the system deep-reader for Team <TEAM_NAME>.
    You are a teammate in perf-lab-<AGENT_ID>.

    YOUR JOB: Deep-read system_files from config. Find exploitable behaviors,
    undocumented features, optimization opportunities the system provides.
    Write findings to shared/Research/findings/<AGENT_ID>-system-exploits.md

    RULES:
    - Communicate with your team lead (<TEAM_NAME>) via SendMessage
    - You may spawn SUBAGENTS for parallel file reads
    - You must NEVER create Agent Teams or tmux sessions

    STAY ACTIVE: After documenting one exploit, look for the next.
```

### Analyst role (if in team_roles)
```
Agent:
  name: "<TEAM_NAME>-Analyst"
  team_name: "perf-lab-<AGENT_ID>"
  subagent_type: "Explore"
  prompt: |
    You are <TEAM_NAME>-Analyst, the pattern analyst for Team <TEAM_NAME>.
    You are a teammate in perf-lab-<AGENT_ID>.

    YOUR JOB: Analyze shared/experiments.tsv for patterns. Which strategies
    produce KEPT results? What's the hit rate by technique? Where are the
    diminishing returns? Report bottleneck analysis to your team lead.

    RULES:
    - Communicate with your team lead (<TEAM_NAME>) via SendMessage
    - You may spawn SUBAGENTS for data analysis
    - You must NEVER create Agent Teams or tmux sessions

    STAY ACTIVE: Re-analyze every 20 new experiments. Look for shifts in
    what's working as the optimization frontier moves.
```

Only spawn roles that are listed in `team_roles`. Skip roles not in the config.

## Step 5: Create initial tasks

Create a task for each teammate:

- **-Experiment**: "Run first optimization iteration. Read CLAUDE.md and shared/learned-constraints.md, then implement and test one change."
- **-Research**: "Survey current research findings in shared/Research/findings/. Identify gaps. Start researching the most promising unexplored technique."
- **-Adversary**: "Read shared/learned-constraints.md. Challenge the top 3 constraints with the weakest evidence."
- **-Explorer** (if present): "Deep-read system_files from config. Document exploitable behaviors."
- **-Analyst** (if present): "Analyze shared/experiments.tsv. Report hit rate by technique and identify patterns."

Assign each task to the corresponding teammate via TaskUpdate with owner.

## Step 6: Report and begin

SendMessage to yourself (or print): "Team <TEAM_NAME> deployed: <N> teammates active."

Then immediately begin your team lead loop:
- If team_size >= lead_experiments_threshold: coordinate only, direct teammates
- If team_size < threshold: coordinate AND experiment yourself
- Check messages every few minutes: `./scripts/messages.sh read <AGENT_ID>`
- Relay breakthroughs from other teams to your teammates
- When a teammate finishes a task, assign the next one immediately

## Team-Internal Heartbeat Protocol

Every 5 iterations, the team lead monitors teammate health:

1. **Read pulse files**: Check `shared/agent-pulse/<AGENT_ID>-*.json` for each teammate
2. **Stuck detection**: If a teammate has been in "testing" phase for >2 minutes (compare `last_activity` to now):
   - SendMessage the teammate: "You appear stuck in testing. Report status or move on."
   - If still stuck after another cycle, reassign their current work to a different teammate or run it yourself
3. **Missing pulse**: If a teammate has no pulse file at all:
   - Alert Jarvis: `./scripts/messages.sh send <AGENT_ID> all alert "Teammate <name> has no pulse — may be dead"`
4. **Team health summary**: Every 5 iterations, send a summary to Jarvis:
   ```bash
   ./scripts/messages.sh send <AGENT_ID> all team-health "Team <TEAM_NAME>: <N> active, <N> stuck, <N> missing. Experiments: <total> (<kept> kept)"
   ```
