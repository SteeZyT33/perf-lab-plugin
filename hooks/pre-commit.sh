#!/usr/bin/env bash
# pre-commit hook for perf-lab — blocks commits that break tests or modify test files

set -euo pipefail

CONFIG="perf-lab.config.json"

if [[ ! -f "$CONFIG" ]]; then
    # Not a perf-lab project, allow commit
    exit 0
fi

TEST_CMD=$(jq -r '.test_command' "$CONFIG")

# Block test file modifications
# Extract test directory from test command (may be empty for commands like "make test")
TESTS_DIR=$(echo "$TEST_CMD" | grep -oP '(tests|test)/\S*' | head -1 | cut -d/ -f1 || true)
if [[ -n "${TESTS_DIR:-}" ]]; then
    CHANGED_TESTS=$(git diff --cached --name-only -- "${TESTS_DIR}/" 2>/dev/null || true)
    if [[ -n "$CHANGED_TESTS" ]]; then
        echo "PRE-COMMIT BLOCKED: Test files must not be modified."
        echo ""
        echo "Changed test files:"
        echo "$CHANGED_TESTS" | sed 's/^/  /'
        echo ""
        echo "Revert test changes before committing."
        exit 1
    fi
fi

# Run tests
echo "Running tests..."
if eval "$TEST_CMD" >/dev/null 2>&1; then
    echo "Tests passed."
    exit 0
else
    echo "PRE-COMMIT BLOCKED: Tests are failing."
    echo ""
    echo "Command: $TEST_CMD"
    echo ""
    echo "Fix test failures before committing."
    exit 1
fi
