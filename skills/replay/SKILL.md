---
name: replay
description: After an architectural change, identifies previously DISCARDED experiments worth retrying. Use after any rewrite (via /perf-lab:plateau) or major structural improvement, when the user says "replay", "retry old experiments", "what can we retry", or "check old discards".
---

# Experiment Replay

After an architecture change, optimizations that previously failed may now be viable. This skill finds and retries them.

## Step 1: Find candidates

```bash
./scripts/replay-candidates.sh
```

This compares DISCARDED experiment timestamps against `shared/architecture-changelog.md` to find experiments from before the last architectural change.

## Step 2: Rank and explain

For each candidate:

1. Read the original hypothesis and discard reason from `shared/experiments.tsv`
2. Read `shared/architecture-changelog.md` to understand what changed
3. Explain **why** this experiment might work now — which architectural change could affect the outcome
4. Rank by estimated impact (lower original metric delta = more likely to succeed now)

Present as a numbered list:
```
1. [experiment #N] "hypothesis" — originally discarded because [reason].
   May work now because [architecture change] changed [relevant constraint].
```

## Step 3: Retry top candidates

For each of the top 3 candidates (or fewer if fewer exist):

1. Re-implement the optimization described in the hypothesis
2. Run tests via `./scripts/track-experiment.sh <agent> "REPLAY: <original hypothesis>" <status> "retry of #N after architecture change"`
3. If KEPT: update `shared/learned-constraints.md` with the finding
4. If DISCARDED again: note it as "confirmed not viable even after architecture change"

## Step 4: Report

Summarize:
- How many candidates were found
- How many were retried
- How many succeeded (KEPT)
- Net metric improvement from replays
