---
name: init
description: Initialize perf-lab in a project — inspects the codebase, asks questions, generates perf-lab.config.json, and runs install. Use this when setting up perf-lab for the first time in a project, when the user says "set up perf-lab", "initialize", "install perf-lab", or "configure perf-lab for this project."
---

# Initialize perf-lab

Guide the user through configuring perf-lab for their project. Inspect the codebase first to make smart suggestions, then ask only what you can't infer.

## Step 1: Locate the plugin

Find the perf-lab-plugin install.sh. Check these locations in order:
1. `~/perf-lab-plugin/install.sh`
2. Any path the user provided
3. Ask if not found

## Step 2: Inspect the project

Before asking the user anything, gather context silently:

1. **Test files** — look for test directories and files:
   - `tests/`, `test/`, `spec/`, `__tests__/`
   - Files matching `*test*`, `*spec*`
   - Look inside for test runner clues: `pytest`, `vitest`, `jest`, `cargo test`, `go test`, `make test`
   - Check `package.json` scripts, `Makefile`, `pyproject.toml`, `Cargo.toml` for test commands

2. **Source files** — identify:
   - The main file being optimized (the "solution file") — often the largest non-test source file, or the one the user has been editing most recently (`git log --oneline -5 --diff-filter=M`)
   - System/framework files the solution depends on — imports, config files, simulator files
   - Constraint files — anything like `constraints.md`, `rules.md`, `BOUNDARIES.md`

3. **Metric clues** — look at test output format:
   - Run the test command if one is obvious and safe (e.g., `pytest`, `python tests/`)
   - Look at test files for metric-printing patterns (cycles, ms, ops/sec, score, etc.)
   - Check for existing benchmark scripts

4. **Git history** — check for existing experiment patterns:
   - `shared/` directory, `experiments.tsv`, `best-*.txt`
   - Recent commit messages mentioning metrics or optimization

## Step 3: Present findings and ask questions

Show the user what you found, then ask about what you couldn't infer. Present as a draft config with your best guesses filled in and blanks marked.

Questions to ask (skip any you already know):

1. **"What metric are you optimizing?"** — suggest based on test output (e.g., "I see your tests print `CYCLES: 2146` — is the metric `cycles`?")
2. **"Lower is better or higher is better?"** — suggest based on metric name (latency/cycles = lower, throughput/score = higher)
3. **"What's the target?"** — and any milestone targets along the way
4. **"What's your team callsign and how many agents?"** — default: "Alpha" with 3 agents. Teams use **Parent-Child** naming where children are named by role:
   > "Pick a callsign for your team (e.g., Alpha, Storm, Viper). Default: **Alpha**. With 3 agents, your team would be: **Alpha-Experiment**, **Alpha-Research**, **Alpha-Adversary**. Want more agents? With 5: add **Alpha-Explorer** and a second **Alpha-Experiment-2**."

   Available roles: `experiment` (modifies code), `research` (queries NotebookLM/papers), `adversary` (challenges constraints), `explorer` (deep code reading), `analyst` (bottleneck patterns), `scout` (isolated worktree testing).

   Write `"parent_agent"`, `"team_roles"`, and `"naming_convention": "parent-child"` to config.
5. **"Do you have a NotebookLM notebook for research?"** — optional, can skip
6. **"Do you have a Semantic Scholar API key?"** — optional. The free tier works but has low rate limits. Users can get a key at https://www.semanticscholar.org/product/api#api-key-form for higher limits. Leave blank if none.

Don't ask about things you can confidently infer (test command, solution file, parse command).

## Step 4: Generate config

Write `perf-lab.config.json` to the project root with all values filled in. Show the user the final config for confirmation before writing.

The `parse_metric` field should be a shell command that extracts the numeric metric value from test output. Examples:
- `grep -oP '\d+(?= cycles)'` for "CYCLES: 2146"
- `grep -oP '[\d.]+(?=ms)'` for "latency: 23.5ms"
- `grep -oP 'score: \K[\d.]+'` for "score: 98.7"

## Step 5: Run install

After the config is written, run:
```bash
<plugin-path>/install.sh <project-root>
```

This copies skills, agents, scripts, and templates into the project.

## Step 6: Confirm setup

Run `./scripts/show-progress.sh` to verify everything works. If it fails, diagnose and fix.

Tell the user:
- What was installed
- How to start: `/perf-lab:experiment` for single iterations, `/perf-lab:sweep` for autonomous mode
- How to set up parallel agents: `./scripts/setup-worktrees.sh`
