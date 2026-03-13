---
name: plateau
description: Detect optimization plateau and trigger the full breakthrough sequence — research, explore, challenge, architect, then rewrite. Use when the user says "we're stuck", "nothing is working", "plateau", "no progress", "need a new approach", or when auto-triggered by the experiment skill after consecutive failures.
---

# Plateau Detection & Breakthrough

Detects when optimization has stalled and runs the full breakthrough-to-rewrite pipeline.

**Manual override**: If the user explicitly says "we're stuck" or "need new approach", skip the threshold check and go directly to Step 2.

## Step 1: Detect plateau

1. Read `perf-lab.config.json` for `plateau_threshold` (default: 10), `max_breakthrough_cycles` (default: 3)
2. Check last N experiments in `shared/experiments.tsv` — plateau confirmed if ALL are DISCARDED or FAILED
3. If no plateau: report current status and exit
4. Check `shared/breakthrough-count.txt` — if >= max, STOP and report: "Hit max breakthrough cycles. Human review recommended."
5. Otherwise increment and proceed

## Step 2: Research refresh

1. Find the most common failure reason in last N DISCARDED experiments
2. Run `/perf-lab:research` with a query based on that bottleneck (limit: `breakthrough_research_budget`, default: 5)

## Step 3: Explore and challenge (parallel)

Spawn in parallel:
- **`@explorer`** — reads `system_files`, writes `shared/Research/system-exploits.md`
- **`@adversary`** — reads `source_files` and constraints, writes `shared/Research/adversary-challenges.md`

## Step 4: Architect

After both complete, spawn **`@architect`**:
- Reads exploits, challenges, experiment history, constraints
- Writes `shared/Research/architect-design.md`
- Breaks plan into work queue items: `./scripts/work-queue.sh add "step: <desc>" high`
- Sends message: `./scripts/messages.sh send architect all discovery "Breakthrough design ready."`

## Step 5: Rewrite

Implement the architect's design. This is the one exception to "small change, fast iteration."

### Backup
1. Copy solution file to `shared/pre-rewrite-backup.${ext}`
2. Record current best from `shared/best-metric.txt`
3. Git commit: `"checkpoint: pre-rewrite backup at [metric]"`

### Implement
1. Follow `shared/Research/architect-design.md` step-by-step
2. After EACH step: run tests, fix if broken, log with `./scripts/track-experiment.sh rewrite "<step>" <status>`
3. Time budget: `rewrite_time_budget_minutes` (default: 60). If exceeded: restore, log FAILED.

### Evaluate
- **Improved**: log KEPT, update best-metric.txt, commit
- **Worse but correct**: analyze what improved vs regressed, save attempt as `shared/rewrite-attempt-[timestamp].*`, log detailed DISCARDED notes, then restore from backup
- **Failed**: restore from backup, log FAILED

### If rewrite succeeded
1. Update `shared/learned-constraints.md` — especially "Current Architecture"
2. Archive old design to `shared/Research/architect-design-[timestamp].md`

## Step 6: Report

- Summary of exploits, challenges, and design
- Rewrite result (improved / partial / failed)
- If improved: "New architecture active. Resuming optimization."
- If failed: "Rewrite did not improve. Diagnostic data saved for next breakthrough cycle."
