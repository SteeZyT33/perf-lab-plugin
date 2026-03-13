---
name: resume
description: Resume optimization after a session restart by reading agent state to restore context. Use when relaunching after a crash, token limit, or machine sleep — "resume alpha", "pick up where I left off", "continue as alpha."
---

# Resume Agent Session

Restore context after a session restart without re-reading everything from scratch.

1. Identify the agent name from arguments or ask the user
2. Read `shared/agent-state/{agent-name}.md` for:
   - Current strategy and what the agent was working on
   - What was learned this session
   - Next planned experiment
3. Read `shared/experiments.tsv` — last 10 entries for this agent
4. Read `shared/learned-constraints.md` for current constraints
5. Check `./scripts/messages.sh read {agent-name}` for anything missed
6. Check `./scripts/work-queue.sh list` for assigned or queued items

Report: "Resuming as {agent}. Last working on: {strategy}. Metric at {current}. Next planned: {next thing}."

Then continue from where the agent left off — either the next planned experiment from the state file, a queued work item, or self-directed work.
