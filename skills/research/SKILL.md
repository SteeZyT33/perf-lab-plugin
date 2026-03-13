---
name: research
description: Query NotebookLM for optimization research relevant to the current problem. Use when the user says "look up", "research", "what do the papers say", "find techniques for", or when stuck and needing external knowledge to inform the next experiment.
---

# Research Query

1. Read `perf-lab.config.json` for `notebook_name`
2. Read `shared/learned-constraints.md` and recent experiments to understand current state
3. Formulate a specific research question based on the current bottleneck
4. Query NotebookLM:
   - Use `mcp__notebooklm-mcp__notebook_query` with the configured notebook
   - Ask targeted questions (e.g., "What techniques reduce hash pipeline latency?")
5. Save findings to `shared/Research/<topic>.md` with:
   - Question asked
   - Key findings
   - Actionable ideas for next experiments
6. Update `shared/learned-constraints.md` if research reveals new boundaries
