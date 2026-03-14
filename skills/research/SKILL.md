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
3. If direct download fails, use Playwright (see below).
4. If all methods fail, note it in findings as "paywalled" and work from the abstract + TLDR.

## 7b. Browser-Based Paper Download (Playwright)

When direct curl/fetch fails (403, paywall, JS-rendered sites), use the Playwright MCP tools to download papers through browser automation. This is the primary approach — Chrome integration is NOT available on WSL2.

### When to use
- `search-papers.sh --pdf` returns 403 or an empty file
- The paper is behind a JavaScript-rendered download page
- The publisher requires cookie consent or CAPTCHA before serving the PDF

### Workflow

1. **Navigate** to the paper URL:
   ```
   browser_navigate → "<paper_url>"
   ```
2. **Snapshot** the page to find the PDF link:
   ```
   browser_snapshot → look for download/PDF links
   ```
3. **Click** the PDF download link:
   ```
   browser_click → "<pdf_link_ref>"
   ```
4. **Save** the downloaded PDF to `shared/Research/papers/<title>.pdf`
5. **Process** the PDF:
   ```bash
   ./scripts/process-papers.sh
   ```

### Fallback
If Playwright cannot access the paper (hard paywall, institutional login required), log it as "paywalled" in `shared/Research/papers/paywalled.txt` and work from the abstract. Do not spend more than 2 minutes per paper on download attempts.

## 8. Deep Paper Research Pipeline

For systematic paper collection beyond individual searches. Use when you need multiple papers on a topic, or when plateau-breaking requires deep literature review.

### Automated sources (Steps A-C)

#### Step A: Search Semantic Scholar + ArXiv

Use `./scripts/search-papers.sh` for targeted queries. Follow citation graphs for high-relevance papers. For each paper worth reading, add it to `shared/Research/paper-list.txt`.

#### Step B: Fetch PDFs

```bash
./scripts/fetch-papers.sh shared/Research/paper-list.txt
```

Downloads open-access PDFs via direct URLs, Semantic Scholar, or ArXiv fallback. Paywalled papers are logged to `shared/Research/papers/paywalled.txt`.

#### Step C: Web search

Use web search for practical techniques, blog posts, and guides that complement the academic papers. Save findings to `shared/Research/findings/`.

### Manual source (Step D) — Undermind

Generate a targeted Undermind query:

```bash
./scripts/generate-undermind-prompt.sh ["optional topic"]
```

This reads current constraints and recent failures to generate a specific query. Tell the user:
> "Paste this into undermind.ai, save results to `shared/Research/undermind-results.txt`"

This is the one human-in-the-loop step — Undermind has no API. After the user provides results, parse them into `shared/Research/paper-list.txt` and run Step B.

### Processing (Step E)

```bash
./scripts/process-papers.sh
```

Converts all PDFs in `shared/Research/papers/` to markdown via LlamaParse. Skips already-converted files. Requires `LLAMA_CLOUD_API_KEY` (env var or in `perf-lab.config.json` at `research.llama_cloud_api_key`).

Free tier: 1,000 pages/day — enough for ~70-100 papers.

### Loading (Step F) — NotebookLM

If `notebook_name` is configured and the NotebookLM MCP server is available:

```
Use mcp__notebooklm-mcp__source_add(type="file") to add each markdown file.
```

If MCP is unavailable, tell the user to manually add files to NotebookLM.

### Querying (Step G) — Synthesis

Use `mcp__notebooklm-mcp__notebook_query` with targeted questions about techniques found across the papers. Save findings to `shared/Research/findings/`.

### When to use the full pipeline vs. individual searches

- **Individual search** (Steps 2-7): You need one or two specific papers or techniques
- **Full pipeline** (Steps A-G): You're stuck at a plateau, exploring a new optimization domain, or the architect needs broad literature backing for a design

## 9. Save findings

Research outputs go in `shared/Research/findings/` — short, actionable summaries that experiment agents can safely read without blowing context. Full paper text lives in `shared/Research/papers/` and should never be read directly by experiment agents.

### Directory structure

```
shared/Research/
├── findings/          ← short summaries, safe for agents to read
│   ├── semantic-scholar-list-scheduling.md
│   ├── web-search-ti-c7000-guide.md
│   └── notebooklm-hash-pipeline-interleaving.md
├── papers/            ← full-text PDFs and markdown conversions (DO NOT read in experiment loop)
│   ├── vliw-scheduling.pdf
│   ├── vliw-scheduling.md
│   └── paywalled.txt
├── paper-list.txt     ← input for fetch-papers.sh
├── undermind-prompt.txt
├── system-exploits.md       ← from @explorer
├── adversary-challenges.md  ← from @adversary
└── architect-design.md      ← from @architect
```

### Findings format

**Naming convention**: `shared/Research/findings/<source>-<topic-slug>.md`

Each file contains:
- **Source**: which source and the query/URL used
- **Key findings** — specific techniques, not general advice
- **Actionable ideas** — concrete next experiments to try, ranked by estimated impact
- **Relevant papers** (if Semantic Scholar) — title, year, citation count, and why it's relevant

Keep findings files **short** (under 100 lines). They're meant to be read by experiment agents between iterations. If a paper needs deeper analysis, put the full notes in `papers/` and only the actionable takeaways in `findings/`.

Before researching, check `shared/Research/findings/` for existing files on the same topic — don't duplicate work.

Update `shared/learned-constraints.md` if research reveals new theoretical limits or disproves existing assumptions.
