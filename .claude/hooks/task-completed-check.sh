#!/bin/bash
# ABOUTME: Quality gate hook for TaskCompleted events in agent teams.
# ABOUTME: Verifies TDD compliance, coverage, and credential safety on task completion.

# TaskCompleted fires when a task in the shared task list is marked complete.
# Exit code 2 = block completion with feedback message.
# Exit code 0 = allow task completion.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Source meta-mode detection
if [ -f "$SCRIPT_DIR/_meta-mode.sh" ]; then
    source "$SCRIPT_DIR/_meta-mode.sh"
fi

# Source config reader
if [ -f "$SCRIPT_DIR/_config-reader.sh" ]; then
    source "$SCRIPT_DIR/_config-reader.sh"
fi

# Read task metadata from environment
TASK_SUBJECT="${CLAUDE_TASK_SUBJECT:-}"
TASK_DESCRIPTION="${CLAUDE_TASK_DESCRIPTION:-}"

# ============================================
# TDD VERIFICATION
# ============================================

# Check if this task involves code implementation
IS_CODE_TASK=false
TASK_TEXT=$(echo "$TASK_SUBJECT $TASK_DESCRIPTION" | tr '[:upper:]' '[:lower:]')

if echo "$TASK_TEXT" | grep -qE "(implement|dev|code|function|handler|feature|fix|bug)"; then
    IS_CODE_TASK=true
fi

if [ "$IS_CODE_TASK" = true ]; then
    # Verify tests exist
    STAGED_FILES=$(cd "$PROJECT_ROOT" && git diff --cached --name-only 2>/dev/null || true)
    UNSTAGED_FILES=$(cd "$PROJECT_ROOT" && git diff --name-only 2>/dev/null || true)
    ALL_CHANGED="$STAGED_FILES $UNSTAGED_FILES"

    # Check if any implementation files changed without corresponding tests
    HAS_IMPL=false
    HAS_TESTS=false

    # Build source file pattern from tracked directories
    TRACKED_DIRS=$(ff_config_array ".trackedDirectories" 2>/dev/null)

    for f in $ALL_CHANGED; do
        # Check if file is in tracked source directories
        if [ -n "$TRACKED_DIRS" ]; then
            while IFS= read -r dir; do
                if [[ "$f" == "$dir"* ]] && [[ ! "$f" =~ (\.test\.|\.spec\.|__tests__|/tests?/) ]]; then
                    HAS_IMPL=true
                    break
                fi
            done <<< "$TRACKED_DIRS"
        fi
        if echo "$f" | grep -qE "(\.test\.|\.spec\.|__tests__|/tests?/)"; then
            HAS_TESTS=true
        fi
    done

    if [ "$HAS_IMPL" = true ] && [ "$HAS_TESTS" = false ]; then
        echo "QUALITY GATE: Implementation changes detected without test changes." >&2
        echo "" >&2
        echo "TDD requires tests to accompany implementation changes." >&2
        echo "Add or update tests for the modified files." >&2
        exit 2
    fi

    # Verify tests pass (config-driven)
    TEST_CMD=$(ff_config ".testing.command" "npm test" 2>/dev/null)
    TEST_OUTPUT=$(cd "$PROJECT_ROOT" && $TEST_CMD 2>&1)
    TEST_EXIT=$?

    if [ "$TEST_EXIT" -ne 0 ]; then
        echo "QUALITY GATE: Tests are failing." >&2
        echo "" >&2
        echo "All tests must pass before completing a task." >&2
        echo "" >&2
        echo "Failing tests (last 15 lines):" >&2
        echo "$TEST_OUTPUT" | tail -15 >&2
        exit 2
    fi
fi

# ============================================
# COVERAGE THRESHOLD (CONFIG-DRIVEN)
# ============================================

if [ "$IS_CODE_TASK" = true ]; then
    COVERAGE_CMD=$(ff_config ".testing.coverageCommand" "" 2>/dev/null)
    COVERAGE_MIN=$(ff_config ".testing.coverageThreshold" "80" 2>/dev/null)

    if [ -n "$COVERAGE_CMD" ]; then
        COVERAGE_OUTPUT=$(cd "$PROJECT_ROOT" && $COVERAGE_CMD 2>&1)

        STMT_COVERAGE=$(echo "$COVERAGE_OUTPUT" | grep -E "^All files" | awk '{print $4}' | sed 's/%//')
        BRANCH_COVERAGE=$(echo "$COVERAGE_OUTPUT" | grep -E "^All files" | awk '{print $6}' | sed 's/%//')

        if [ -n "$STMT_COVERAGE" ]; then
            STMT_INT=${STMT_COVERAGE%.*}
            if [ "$STMT_INT" -lt "$COVERAGE_MIN" ]; then
                echo "QUALITY GATE: Statement coverage ${STMT_COVERAGE}% below ${COVERAGE_MIN}% threshold." >&2
                echo "" >&2
                echo "Improve test coverage before completing this task." >&2
                exit 2
            fi
        fi

        if [ -n "$BRANCH_COVERAGE" ]; then
            BRANCH_INT=${BRANCH_COVERAGE%.*}
            if [ "$BRANCH_INT" -lt "$COVERAGE_MIN" ]; then
                echo "QUALITY GATE: Branch coverage ${BRANCH_COVERAGE}% below ${COVERAGE_MIN}% threshold." >&2
                echo "" >&2
                echo "Improve branch coverage before completing this task." >&2
                exit 2
            fi
        fi
    fi
fi

# ============================================
# CREDENTIAL SAFETY (CONFIG-DRIVEN)
# ============================================

# Check staged files for hardcoded credentials
STAGED_FILES=$(cd "$PROJECT_ROOT" && git diff --cached --name-only 2>/dev/null || true)

for f in $STAGED_FILES; do
    FULL_PATH="$PROJECT_ROOT/$f"
    [ -f "$FULL_PATH" ] || continue

    # Skip test files and docs
    if [[ "$f" =~ (\.test\.|\.spec\.|__tests__|/tests?/|\.md$) ]]; then
        continue
    fi

    FILE_CONTENT=$(cat "$FULL_PATH")

    while IFS=$'\t' read -r PATTERN NAME EXCLUDE; do
        [ -z "$PATTERN" ] && continue

        if echo "$FILE_CONTENT" | grep -qE "$PATTERN"; then
            if [ -n "$EXCLUDE" ]; then
                if echo "$FILE_CONTENT" | grep -E "$PATTERN" | grep -vqE "$EXCLUDE"; then
                    echo "QUALITY GATE: Hardcoded $NAME in $f" >&2
                    echo "" >&2
                    echo "Use environment variables instead." >&2
                    exit 2
                fi
            else
                echo "QUALITY GATE: Hardcoded $NAME in $f" >&2
                echo "" >&2
                echo "Use environment variables instead." >&2
                exit 2
            fi
        fi
    done < <(ff_credential_patterns)
done

exit 0
