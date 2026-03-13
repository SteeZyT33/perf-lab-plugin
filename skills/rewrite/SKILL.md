---
name: rewrite
description: Implement a complete solution rewrite based on the architect's design — the one exception to small-change iteration. Use after /perf-lab:plateau has produced an architect-design.md, when the user says "implement the redesign", "do the rewrite", or "try the new architecture." Requires an existing architect design and evidence of plateau.
---

# Architecture Rewrite

Implements a fundamentally new solution architecture designed by the architect agent. This is the **one exception** to the "small change, fast iteration" rule.

## Prerequisites

Before proceeding, verify BOTH conditions:

1. `shared/Research/architect-design.md` exists and contains a complete design
2. Recent experiment history shows plateau (check last 10+ experiments in `shared/experiments.tsv` — if most are KEPT, there's no reason to rewrite)

If either check fails, refuse to proceed and explain why.

## Time Budget

Read `rewrite_time_budget_minutes` from `perf-lab.config.json` (default: 60). Track elapsed time from the start of Step 1.

If the rewrite has not produced a passing test within this time budget:
1. Stop implementing
2. Restore from backup
3. Log: `./scripts/track-experiment.sh rewrite "architecture rewrite - timed out" FAILED "exceeded time budget"`
4. Report what was completed and what blocked progress

## Step 1: Backup

1. Read `perf-lab.config.json` for `solution_file`
2. Copy the current solution file to `shared/pre-rewrite-backup.${ext}`
3. Record current best metric from `shared/best-metric.txt`
4. Git commit current state: `git add -A && git commit -m "checkpoint: pre-rewrite backup at [metric] [metric_name]"`

## Step 2: Implement

1. Read `shared/Research/architect-design.md` for the implementation plan
2. Follow the plan step-by-step
3. After EACH step in the plan:
   - Run the test command from config
   - If tests fail, fix before proceeding to next step
   - Log progress: `./scripts/track-experiment.sh rewrite "<step description>" <status>`

## Step 3: Evaluate

1. Run the full test suite
2. Parse the metric
3. Compare to pre-rewrite best:
   - **Improved**: Log as KEPT, update best-metric.txt, commit: `"feat: architecture rewrite — [new metric] [metric_name] (was [old])"`
   - **Worse or failed**: Go to Step 3b before restoring

## Step 3b: Partial success evaluation

If the rewrite is WORSE overall but CORRECT (tests pass):

1. Before restoring, analyze WHY it's worse
2. Check per-component metrics if available (e.g., which parts improved, which regressed)
3. If specific aspects improved while others regressed:
   - Save the rewritten solution as `shared/rewrite-attempt-[timestamp].${ext}`
   - Log detailed notes about what improved and what regressed
   - These notes feed back into the next architect design — a failed rewrite that produces diagnostic data is more valuable than a silent revert
4. Log: `./scripts/track-experiment.sh rewrite "architecture rewrite - partial" DISCARDED "<what improved> but <what regressed>"`
5. Restore from backup

## Step 4: Update constraints

If the rewrite succeeded:
1. Update `shared/learned-constraints.md` — especially the "Current Architecture" section
2. Archive the old architect design: move to `shared/Research/architect-design-[timestamp].md`
3. Clear any stale adversary/explorer research that referenced the old architecture
