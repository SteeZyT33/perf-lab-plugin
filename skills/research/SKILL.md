---
name: research
description: Research optimization techniques using Semantic Scholar, web search, and NotebookLM. Use when the user says "look up", "research", "find papers", "what do the papers say", "find techniques for", "search for", or when stuck and needing external knowledge to inform the next experiment.
---

# Research

Find optimization techniques and ideas from three sources. Use whichever combination is appropriate — you don't need all three every time.

## 1. Read current state first

1. Read `perf-lab.config.json` for metric name, notebook name, and current targets
2. Read `shared/learned-constraints.md` and recent experiments to understand the bottleneck
3. Formulate specific research questions based on what's actually blocking progress

## 2. Semantic Scholar — academic papers

Search for relevant papers using the helper script:

```bash
./scripts/search-papers.sh "<specific query>" [limit]
```

Good queries are specific to the technique you need, not the whole project. Examples:
- "SIMD hash function throughput optimization"
- "instruction-level parallelism pipeline scheduling"
- "branchless binary tree traversal"

The script returns titles, authors, citation counts, TLDRs, and abstracts. For promising papers, fetch the full text via the URL if needed.

## 3. Web search — blogs, docs, Stack Overflow

Use web search for practical techniques, implementation guides, and recent discussions that wouldn't be in academic papers:
- Optimization blog posts and case studies
- CPU architecture manuals and ISA references
- Stack Overflow answers about specific techniques

## 4. NotebookLM — project-specific research notebook

If `notebook_name` is configured in `perf-lab.config.json`:
- Use `mcp__notebooklm-mcp__notebook_query` with the configured notebook
- Best for questions specific to the project's domain where you've already collected sources

## 5. Save findings

Write results to `shared/Research/<topic>.md` with:
- **Sources used** (which of the three, with links/citations)
- **Key findings** — specific techniques, not general advice
- **Actionable ideas** — concrete next experiments to try, ranked by estimated impact
- **Relevant papers** — title, year, citation count, and why it's relevant

Update `shared/learned-constraints.md` if research reveals new theoretical limits or disproves existing assumptions.
