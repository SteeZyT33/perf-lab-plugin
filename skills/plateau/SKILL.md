---
name: plateau
description: Detect optimization plateau and trigger the breakthrough sequence (explorer -> adversary -> architect). Use when the user says "we're stuck", "nothing is working", "plateau", "no progress", "need a new approach", or when you notice many consecutive DISCARDED/FAILED experiments. Also use proactively if /perf-lab:experiment has failed to improve the metric for several iterations.
---

# Plateau Detection & Breakthrough

Detects when all agents are stuck and orchestrates the breakthrough sequence.

**Manual override**: If the user explicitly requests a breakthrough sequence (e.g., "we're stuck", "need new approach"), skip the plateau threshold check and proceed directly to Step 2. The user's judgment overrides the numerical threshold.

## Step 1: Detect plateau

1. Read `perf-lab.config.json` for `plateau_threshold` (default: 10) and `max_breakthrough_cycles` (default: 3)
2. Read `shared/experiments.tsv`
3. Check the last N experiments across ALL agents (where N = plateau_threshold)
4. Plateau is confirmed if ALL of the last N experiments are DISCARDED or FAILED (zero KEPT)

If no plateau detected, report current status and exit.

5. Check `shared/breakthrough-count.txt` (default: 0)
   - If count >= `max_breakthrough_cycles`: STOP. Report to user: "Hit max breakthrough cycles (N). The system has tried N architectural rewrites without reaching target. Human review recommended."
   - Otherwise: increment the count and proceed

## Step 1.5: Research refresh

Before launching explorer/adversary, spawn a research sub-agent to pull fresh external knowledge:

1. Read the last N DISCARDED experiments and find the most common failure reason
2. Formulate a research query based on that bottleneck
3. Run `/perf-lab:research` with that query, limited to `breakthrough_research_budget` queries (default: 5)
4. Findings save to `shared/Research/` per the research skill's naming convention

This ensures the breakthrough sequence has fresh external ideas, not just internal re-analysis of the same problem.

## Step 2: Trigger breakthrough sequence

1. **Announce**: "Plateau detected — last {{N}} experiments produced no improvement. Breakthrough cycle {{count}}/{{max}}. Launching breakthrough sequence."

2. **Spawn explorer agent** (`@explorer`):
   - Reads system files from config `system_files`
   - Reads fresh research from Step 1.5
   - Writes `shared/Research/system-exploits.md`

3. **Spawn adversary agent** (`@adversary`):
   - Reads DISCARDED experiments and constraints
   - Reads source files from config `source_files`
   - Writes `shared/Research/adversary-challenges.md`

   Explorer and adversary can run in parallel — they don't depend on each other.

4. **Wait** for both to complete, then **spawn architect agent** (`@architect`):
   - Reads both research files + experiment history
   - Writes `shared/Research/architect-design.md`
   - Breaks the implementation plan into work queue items:
     ```bash
     ./scripts/work-queue.sh add "step 1: <description>" high
     ./scripts/work-queue.sh add "step 2: <description>" high
     ```
   - Each step becomes a claimable item so agents (or /perf-lab:rewrite) can execute them

5. **Notify** via messaging:
   ```bash
   ./scripts/messages.sh send architect all discovery "Breakthrough design ready. See shared/Research/architect-design.md. Run /perf-lab:rewrite to implement."
   ```

6. **Report** to the user:
   - Summary of exploits found
   - Summary of constraints challenged
   - Architecture design overview
   - Work queue items created
   - "Run `/perf-lab:rewrite` to implement the new architecture."
