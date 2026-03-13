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

The script returns titles, authors, citation counts, TLDRs, abstracts, and paper IDs.

For high-relevance papers (>50 citations or directly applicable technique), follow the citation graph:

```bash
./scripts/search-papers.sh --citations "<paper_id>" 5   # papers that cite this one
./scripts/search-papers.sh --references "<paper_id>" 5   # papers this one cites
```

This finds related techniques that keyword search misses — the citation graph is how you go from one good paper to ten.

## 3. ArXiv — bleeding-edge preprints (optional)

Semantic Scholar indexes ArXiv but with a delay. For cutting-edge work published in the last 30 days, query ArXiv directly:

```bash
curl -s "http://export.arxiv.org/api/query?search_query=all:<query>&max_results=5"
```

Use sparingly — most research needs are covered by Semantic Scholar. Only reach for ArXiv when you specifically need very recent results.

## 4. Web search — blogs, docs, Stack Overflow

Use web search for practical techniques, implementation guides, and recent discussions that wouldn't be in academic papers:
- Optimization blog posts and case studies
- CPU architecture manuals and ISA references
- Stack Overflow answers about specific techniques

## 5. NotebookLM — project-specific research notebook

If `notebook_name` is configured in `perf-lab.config.json`:
- Use `mcp__notebooklm-mcp__notebook_query` with the configured notebook
- Best for questions specific to the project's domain where you've already collected sources

## 6. Pick the right source

Don't blindly query all three. Match the source to the question:
- **Semantic Scholar** — algorithmic techniques, data structures, theoretical bounds, prior art. Not for "how do I use tool X" or current events.
- **Web search** — practical guides, architecture manuals, recent blog posts, Stack Overflow. Not for formal proofs or theoretical limits.
- **NotebookLM** — project-specific context from sources you've already curated. Not for general knowledge.

## 7. Acquire full text (when needed)

If a paper's technique needs deeper reading than the abstract provides:

1. Try downloading the open-access PDF:
   ```bash
   ./scripts/search-papers.sh --pdf "<paper_id>"
   ```
   This saves to `shared/Research/papers/<title>.pdf` if open-access is available.
2. If the project has NotebookLM configured, add the PDF as a source for future queries.
3. If paywalled, note it in findings as "full text unavailable" and work from the abstract + TLDR.

## 8. Save findings

File name encodes the source so other agents and future sessions know what's been researched and where it came from — no re-querying.

**Naming convention**: `shared/Research/<source>-<topic-slug>.md`

Examples:
- `shared/Research/semantic-scholar-list-scheduling.md`
- `shared/Research/web-search-ti-c7000-guide.md`
- `shared/Research/notebooklm-hash-pipeline-interleaving.md`

Each file contains:
- **Source**: which source and the query/URL used
- **Key findings** — specific techniques, not general advice
- **Actionable ideas** — concrete next experiments to try, ranked by estimated impact
- **Relevant papers** (if Semantic Scholar) — title, year, citation count, and why it's relevant

Before researching, check `shared/Research/` for existing files on the same topic — don't duplicate work.

Update `shared/learned-constraints.md` if research reveals new theoretical limits or disproves existing assumptions.
