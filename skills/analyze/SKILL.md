---
name: analyze
description: Analyze performance trace data and identify bottlenecks. Use when stuck, after a major change, when the user says "analyze", "profile", "trace", "where are cycles spent", "bottleneck", or to understand resource utilization.
---

# Trace Analysis

Analyze performance data to identify where cycles are spent and what resources are underutilized.

## Step 1: Run trace

Run the test command from `perf-lab.config.json` and capture full output:

```bash
TEST_CMD=$(jq -r '.test_command' perf-lab.config.json)
eval "$TEST_CMD" 2>&1 | tee shared/Research/trace-output-latest.txt
```

If the config has a `trace_command` field, use that instead (it may enable more detailed output).

## Step 2: Parse resource utilization

From the trace output, extract:
- **Per-resource utilization percentage** — what fraction of cycles each resource is active
- **Cycles with zero activity** per resource
- **Longest continuous idle stretch** per resource
- **What other resources are doing** during each resource's idle stretches
- **Periodic patterns** in idle cycles (fixed stride = scheduling artifact)

Present as a table:
```
Resource     Active%   Idle Cycles   Longest Idle   Pattern
--------     -------   -----------   ------------   -------
VALU         87%       130           12             none
Load/Store   62%       380           45             stride-8
Branch       15%       850           200            sparse
```

## Step 3: Identify bottleneck

The binding constraint is the resource with the highest utilization. Report:
- Current binding resource and its utilization
- Second-highest resource (what becomes binding if we optimize the first)
- Specific idle stretches where the binding resource is active but others are idle (parallelism opportunity)
- Any resources that are **never** idle when the binding resource is idle (true dependencies)

## Step 4: Compare to previous analysis

If `shared/Research/trace-analysis-previous.md` exists:
- What changed since last analysis?
- Did the binding constraint shift?
- Are idle patterns different?
- Quantify improvement/regression per resource

## Step 5: Save analysis

1. If `shared/Research/trace-analysis-latest.md` exists, move it to `shared/Research/trace-analysis-previous.md`
2. Write new analysis to `shared/Research/trace-analysis-latest.md`:
   - Resource utilization table
   - Binding constraint identification
   - Top 3 optimization opportunities with estimated cycle savings
   - Comparison to previous (if available)
3. Update `shared/learned-constraints.md` if the binding constraint has changed
