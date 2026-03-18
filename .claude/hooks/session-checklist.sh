#!/bin/bash
# ABOUTME: Stop hook that checks for open session hygiene items.
# ABOUTME: Reminds about learnings, docs, uncommitted work, unpushed commits, and test runs.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_meta-mode.sh"

# Source config reader
if [ -f "$SCRIPT_DIR/_config-reader.sh" ]; then
    source "$SCRIPT_DIR/_config-reader.sh"
fi

# ============================================
# Collect checklist items
# ============================================
ITEMS=()

# --- 1. Uncommitted changes ---
UNCOMMITTED=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [[ "$UNCOMMITTED" -gt 0 ]]; then
    ITEMS+=("UNCOMMITTED: $UNCOMMITTED file(s) with uncommitted changes")
fi

# --- 2. Unpushed commits ---
UNPUSHED=$(git -C "$PROJECT_ROOT" log --oneline '@{upstream}..HEAD' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$UNPUSHED" -gt 0 ]]; then
    ITEMS+=("UNPUSHED: $UNPUSHED commit(s) not pushed to remote")
fi

# --- 3. Learnings freshness ---
if [[ -f "$CLAUDE_LEARNINGS" ]]; then
    LEARN_MTIME=$(stat -f %m "$CLAUDE_LEARNINGS" 2>/dev/null || stat -c %Y "$CLAUDE_LEARNINGS" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    LEARN_AGE=$(( NOW - LEARN_MTIME ))
    if [[ $LEARN_AGE -gt 14400 ]]; then
        ITEMS+=("LEARNINGS: Learnings file not updated this session — capture any discoveries to $CLAUDE_LEARNINGS")
    fi
else
    ITEMS+=("LEARNINGS: No learnings file found — consider creating $CLAUDE_LEARNINGS")
fi

# --- 4. Pending doc actions ---
if [[ -f "$CLAUDE_PENDING_ACTIONS" ]]; then
    UNCHECKED=$(grep -c '^\- \[ \]' "$CLAUDE_PENDING_ACTIONS" 2>/dev/null) || UNCHECKED=0
    if [[ "$UNCHECKED" -gt 0 ]]; then
        ITEMS+=("DOCS: $UNCHECKED unchecked pending doc action(s) in $(basename "$CLAUDE_PENDING_ACTIONS")")
    fi
fi

# --- 5. Test recency ---
LAST_TEST_COMMIT=$(git -C "$PROJECT_ROOT" log --oneline --all --grep="test" -1 --format="%H" 2>/dev/null || echo "")
if [[ -n "$LAST_TEST_COMMIT" ]]; then
    CHANGED_SINCE_TEST=$(git -C "$PROJECT_ROOT" diff --name-only "$LAST_TEST_COMMIT" -- '*.ts' '*.js' '*.py' '*.go' '*.rs' '*.json' 2>/dev/null | grep -v node_modules | grep -v dist | wc -l | tr -d ' ')
    if [[ "$CHANGED_SINCE_TEST" -gt 5 ]]; then
        TEST_CMD=$(ff_config ".testing.command" "npm test" 2>/dev/null)
        ITEMS+=("TESTS: $CHANGED_SINCE_TEST source files changed since last test commit — consider running $TEST_CMD")
    fi
fi

# --- 6. Source code change reminder (config-driven tracked directories) ---
TRACKED_DIRS=$(ff_config_array ".trackedDirectories" 2>/dev/null)
if [ -n "$TRACKED_DIRS" ]; then
    TOTAL_TRACKED_CHANGES=0
    while IFS= read -r dir; do
        DIR_CHANGES=$(git -C "$PROJECT_ROOT" diff --name-only HEAD 2>/dev/null | grep -c "^${dir}" 2>/dev/null) || DIR_CHANGES=0
        TOTAL_TRACKED_CHANGES=$((TOTAL_TRACKED_CHANGES + DIR_CHANGES))
    done <<< "$TRACKED_DIRS"
    if [[ "$TOTAL_TRACKED_CHANGES" -gt 0 ]]; then
        TEST_CMD=$(ff_config ".testing.command" "npm test" 2>/dev/null)
        ITEMS+=("E2E: $TOTAL_TRACKED_CHANGES source file(s) modified — consider running tests")
    fi
fi

# --- 7. MEMORY.md size check ---
MEMORY_FILE="$HOME/.claude/projects/$(echo "$PROJECT_ROOT" | sed 's|/|-|g')/memory/MEMORY.md"
if [[ -f "$MEMORY_FILE" ]]; then
    MEMORY_LINES=$(wc -l < "$MEMORY_FILE" | tr -d ' ')
    if [[ "$MEMORY_LINES" -gt 100 ]]; then
        ITEMS+=("MEMORY: ${MEMORY_LINES}/200 lines — run /wrap-up to prune stale entries")
    fi
fi

# --- 8. README drift check ---
README_DRIFT_SCRIPT="$PROJECT_ROOT/scripts/check-readme-drift.sh"
if [[ -x "$README_DRIFT_SCRIPT" ]]; then
    DRIFT_OUTPUT=$("$README_DRIFT_SCRIPT" --quiet 2>/dev/null) || true
    if [[ -n "$DRIFT_OUTPUT" ]]; then
        ITEMS+=("README: $DRIFT_OUTPUT")
    fi
fi

# --- 9. Pending learning exercises ---
if [ "$CLAUDE_META_MODE" = "true" ] && [ -n "${CLAUDE_LEARNING_DIR:-}" ] && [ -d "${CLAUDE_LEARNING_DIR:-}" ]; then
    EXERCISE_FILE="$CLAUDE_LEARNING_DIR/exercises.md"
    if [ -f "$EXERCISE_FILE" ]; then
        EXERCISE_COUNT=$(grep -c '^## ' "$EXERCISE_FILE" 2>/dev/null) || EXERCISE_COUNT=0
        if [[ "$EXERCISE_COUNT" -gt 0 ]]; then
            ITEMS+=("LEARNING: $EXERCISE_COUNT exercise(s) pending — use /learn to build comprehension of autonomous work")
        fi
    fi
fi

# ============================================
# Output checklist (only if there are items)
# ============================================
if [[ ${#ITEMS[@]} -gt 0 ]]; then
    echo ""
    echo "SESSION CHECKLIST"
    echo "----------------------------------------"
    for item in "${ITEMS[@]}"; do
        echo "  - $item"
    done
    echo "----------------------------------------"
    echo ""
fi

exit 0
