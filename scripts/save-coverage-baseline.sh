#!/bin/bash
# ABOUTME: Save current test coverage as a baseline for regression detection.
# ABOUTME: Stores coverage-summary.json snapshot and test file count in .coverage-baseline.json.

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
BASELINE_FILE="$PROJECT_ROOT/.coverage-baseline.json"
CONFIG_FILE="$PROJECT_ROOT/ff.config.json"

# Read test file patterns from config if available
if command -v jq &>/dev/null && [ -f "$CONFIG_FILE" ]; then
    COVERAGE_CMD=$(jq -r '.testing.coverageCommand // "npm run test:coverage"' "$CONFIG_FILE")
else
    COVERAGE_CMD="npm run test:coverage"
fi

echo "Running tests with coverage..."
cd "$PROJECT_ROOT"
eval "$COVERAGE_CMD" -- --coverageReporters=json-summary --silent 2>/dev/null || \
    npm test -- --coverage --coverageReporters=json-summary --silent 2>/dev/null

SUMMARY="$PROJECT_ROOT/coverage/coverage-summary.json"
if [ ! -f "$SUMMARY" ]; then
    echo "ERROR: Coverage summary not generated at $SUMMARY" >&2
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "ERROR: jq required. Install: brew install jq" >&2
    exit 1
fi

# Count test files using patterns from config or defaults
TEST_COUNT=0
if [ -f "$CONFIG_FILE" ]; then
    # Use testFilePatterns from ff.config.json
    PATTERN_COUNT=$(jq -r '.testing.testFilePatterns | length // 0' "$CONFIG_FILE" 2>/dev/null)
    if [ "$PATTERN_COUNT" -gt 0 ] 2>/dev/null; then
        for i in $(seq 0 $((PATTERN_COUNT - 1))); do
            PATTERN=$(jq -r ".testing.testFilePatterns[$i]" "$CONFIG_FILE")
            COUNT=$(find "$PROJECT_ROOT" -path "*/node_modules" -prune -o -path "$PATTERN" -print 2>/dev/null | wc -l | tr -d ' ')
            TEST_COUNT=$((TEST_COUNT + COUNT))
        done
    fi
fi

# Fallback: search common test patterns
if [ "$TEST_COUNT" -eq 0 ]; then
    TEST_COUNT=$(find "$PROJECT_ROOT" -path "*/node_modules" -prune -o \( -name "*.test.js" -o -name "*.test.ts" -o -name "*.spec.js" -o -name "*.spec.ts" \) -print 2>/dev/null | wc -l | tr -d ' ')
fi

# Extract coverage metrics
STATEMENTS=$(jq -r '.total.statements.pct // 0' "$SUMMARY")
BRANCHES=$(jq -r '.total.branches.pct // 0' "$SUMMARY")
FUNCTIONS=$(jq -r '.total.functions.pct // 0' "$SUMMARY")
LINES=$(jq -r '.total.lines.pct // 0' "$SUMMARY")

# Save baseline
jq -n \
    --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg commit "$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')" \
    --argjson test_count "$TEST_COUNT" \
    --argjson statements "$STATEMENTS" \
    --argjson branches "$BRANCHES" \
    --argjson functions "$FUNCTIONS" \
    --argjson lines "$LINES" \
    '{
        saved_at: $date,
        commit: $commit,
        test_file_count: $test_count,
        coverage: {
            statements: $statements,
            branches: $branches,
            functions: $functions,
            lines: $lines
        }
    }' > "$BASELINE_FILE"

echo ""
echo "Coverage baseline saved to .coverage-baseline.json:"
echo "  Test files: $TEST_COUNT"
echo "  Statements: ${STATEMENTS}%"
echo "  Branches:   ${BRANCHES}%"
echo "  Functions:  ${FUNCTIONS}%"
echo "  Lines:      ${LINES}%"
echo "  Commit:     $(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
