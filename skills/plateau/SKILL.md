---
name: plateau
description: Detect optimization plateau and trigger the breakthrough sequence (explorer -> adversary -> architect). Use when the user says "we're stuck", "nothing is working", "plateau", "no progress", "need a new approach", or when you notice many consecutive DISCARDED/FAILED experiments. Also use proactively if /perf-lab:experiment has failed to improve the metric for several iterations.
---

# Plateau Detection & Breakthrough

Detects when all agents are stuck and orchestrates the breakthrough sequence.

## Step 1: Detect plateau

1. Read `perf-lab.config.json` for `plateau_threshold` (default: 10)
2. Read `shared/experiments.tsv`
3. Check the last N experiments across ALL agents (where N = plateau_threshold)
4. Plateau is confirmed if ALL of the last N experiments are DISCARDED or FAILED (zero KEPT)

If no plateau detected, report current status and exit.

## Step 2: Trigger breakthrough sequence

If plateau confirmed:

1. **Announce**: "Plateau detected — last {{N}} experiments produced no improvement. Launching breakthrough sequence."

2. **Spawn explorer agent** (`@explorer`):
   - Reads system files from config `system_files`
   - Writes `shared/Research/system-exploits.md`

3. **Spawn adversary agent** (`@adversary`):
   - Reads DISCARDED experiments and constraints
   - Reads source files from config `source_files`
   - Writes `shared/Research/adversary-challenges.md`

   Explorer and adversary can run in parallel — they don't depend on each other.

4. **Wait** for both to complete, then **spawn architect agent** (`@architect`):
   - Reads both research files + experiment history
   - Writes `shared/Research/architect-design.md`

5. **Report** to the user:
   - Summary of exploits found
   - Summary of constraints challenged
   - Architecture design overview
   - "Run `/perf-lab:rewrite` to implement the new architecture."
