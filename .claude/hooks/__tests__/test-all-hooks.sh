#!/bin/bash
# ABOUTME: Functional test suite for all Feature Factory hooks.
# ABOUTME: Tests config-driven behavior, meta-mode isolation, session tracking, and quality gates.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# FF_SOURCE_ROOT is the real feature-factory project root (never overwritten)
FF_SOURCE_ROOT="$(cd "$HOOKS_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0
TOTAL=0

# Create a temporary test directory
# Use cd + pwd to resolve macOS /var → /private/var symlinks for path consistency
TEST_DIR=$(mktemp -d)
TEST_DIR=$(cd "$TEST_DIR" && pwd -P)
trap "rm -rf $TEST_DIR" EXIT

setup_test_project() {
    # Clean everything including dotfiles (except the dir itself)
    rm -rf "$TEST_DIR"/{*,.[!.]*} 2>/dev/null || true
    mkdir -p "$TEST_DIR/.claude/hooks"
    mkdir -p "$TEST_DIR/.claude/logs"

    # Copy hooks from the REAL source (not from PROJECT_ROOT which may be overridden)
    cp "$HOOKS_DIR"/*.sh "$TEST_DIR/.claude/hooks/" 2>/dev/null || true
    chmod +x "$TEST_DIR/.claude/hooks/"*.sh

    # Copy config from the REAL source root
    cp "$FF_SOURCE_ROOT/ff.config.json" "$TEST_DIR/" 2>/dev/null || true

    # Initialize git (isolated from feature-factory repo)
    cd "$TEST_DIR"
    git init -q
    git add -A 2>/dev/null || true
    git commit -q -m "init" --allow-empty 2>/dev/null || true

    # CRITICAL: Override PROJECT_ROOT so hooks don't resolve back to the
    # real feature-factory repo via git rev-parse --show-toplevel
    export PROJECT_ROOT="$TEST_DIR"

    # Clear any stale meta-mode exports from previous tests
    unset CLAUDE_META_MODE CLAUDE_META_DIR CLAUDE_PENDING_ACTIONS
    unset CLAUDE_LEARNINGS CLAUDE_LOGS_DIR CLAUDE_PLANS_DIR CLAUDE_LEARNING_DIR
}

run_test() {
    local name="$1"
    TOTAL=$((TOTAL + 1))
    echo -n "  $name... "
}

pass() {
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
}

fail() {
    local reason="${1:-}"
    echo -e "${RED}FAIL${NC}"
    if [ -n "$reason" ]; then
        echo "    $reason"
    fi
    FAIL=$((FAIL + 1))
}

skip() {
    local reason="${1:-}"
    echo -e "${YELLOW}SKIP${NC} $reason"
    SKIP=$((SKIP + 1))
}

echo "Feature Factory Hook Tests"
echo "=========================="
echo ""

# ============================================
# Settings.json Consistency
# ============================================

echo "Settings Consistency:"

run_test "TC-SETTINGS-01: All hooks in settings.json exist as files"
SETTINGS_FILE="$FF_SOURCE_ROOT/.claude/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    # Extract hook file references
    HOOK_REFS=$(grep -oE '[a-z-]+\.sh' "$SETTINGS_FILE" | sort -u)
    ALL_EXIST=true
    MISSING=""
    for ref in $HOOK_REFS; do
        if [ ! -f "$HOOKS_DIR/$ref" ]; then
            ALL_EXIST=false
            MISSING="$MISSING $ref"
        fi
    done
    if [ "$ALL_EXIST" = true ]; then
        pass
    else
        fail "Missing hook files:$MISSING"
    fi
else
    fail "settings.json not found"
fi

run_test "TC-SETTINGS-02: All hook files are executable"
NON_EXEC=""
for hook in "$HOOKS_DIR"/*.sh; do
    [ -f "$hook" ] || continue
    if [ ! -x "$hook" ]; then
        NON_EXEC="$NON_EXEC $(basename "$hook")"
    fi
done
if [ -z "$NON_EXEC" ]; then
    pass
else
    fail "Not executable:$NON_EXEC"
fi

run_test "TC-SETTINGS-03: All hook files have ABOUTME comments"
MISSING_ABOUTME=""
for hook in "$HOOKS_DIR"/*.sh; do
    [ -f "$hook" ] || continue
    basename_hook=$(basename "$hook")
    # Skip test files
    [[ "$basename_hook" == test-* ]] && continue
    if ! head -5 "$hook" | grep -q "ABOUTME:"; then
        MISSING_ABOUTME="$MISSING_ABOUTME $basename_hook"
    fi
done
if [ -z "$MISSING_ABOUTME" ]; then
    pass
else
    fail "Missing ABOUTME:$MISSING_ABOUTME"
fi
echo ""

# ============================================
# Meta-Mode Isolation
# ============================================

echo "Meta-Mode Isolation:"

run_test "TC-META-01: Meta-mode detects .meta/ directory"
setup_test_project
mkdir -p "$TEST_DIR/.meta"
cd "$TEST_DIR"
source "$TEST_DIR/.claude/hooks/_meta-mode.sh"
if [ "$CLAUDE_META_MODE" = "true" ]; then
    pass
else
    fail "CLAUDE_META_MODE was '$CLAUDE_META_MODE', expected 'true'"
fi

run_test "TC-META-02: Non-meta-mode when .meta/ absent"
setup_test_project
cd "$TEST_DIR"
source "$TEST_DIR/.claude/hooks/_meta-mode.sh"
if [ "$CLAUDE_META_MODE" = "false" ]; then
    pass
else
    fail "CLAUDE_META_MODE was '$CLAUDE_META_MODE', expected 'false'"
fi

run_test "TC-META-03: Meta-mode routes pending-actions to .meta/"
setup_test_project
mkdir -p "$TEST_DIR/.meta"
cd "$TEST_DIR"
source "$TEST_DIR/.claude/hooks/_meta-mode.sh"
if [[ "$CLAUDE_PENDING_ACTIONS" == *".meta/pending-actions.md" ]]; then
    pass
else
    fail "Path was '$CLAUDE_PENDING_ACTIONS'"
fi

run_test "TC-META-04: Non-meta routes pending-actions to .claude/"
setup_test_project
cd "$TEST_DIR"
source "$TEST_DIR/.claude/hooks/_meta-mode.sh"
if [[ "$CLAUDE_PENDING_ACTIONS" == *".claude/pending-actions.md" ]]; then
    pass
else
    fail "Path was '$CLAUDE_PENDING_ACTIONS'"
fi
echo ""

# ============================================
# Config Reader
# ============================================

echo "Config Reader:"

run_test "TC-CONFIG-01: ff_config reads simple values"
setup_test_project
cd "$TEST_DIR"
source "$TEST_DIR/.claude/hooks/_config-reader.sh"
RESULT=$(ff_config ".testing.coverageThreshold" "0")
if [ "$RESULT" = "80" ]; then
    pass
else
    fail "Got '$RESULT', expected '80'"
fi

run_test "TC-CONFIG-02: ff_config returns default for missing keys"
setup_test_project
cd "$TEST_DIR"
source "$TEST_DIR/.claude/hooks/_config-reader.sh"
RESULT=$(ff_config ".nonexistent.key" "fallback")
if [ "$RESULT" = "fallback" ]; then
    pass
else
    fail "Got '$RESULT', expected 'fallback'"
fi

run_test "TC-CONFIG-03: ff_config_array reads arrays"
setup_test_project
cd "$TEST_DIR"
source "$TEST_DIR/.claude/hooks/_config-reader.sh"
RESULT=$(ff_config_array ".fileHeaders.fileExtensions" | head -1)
if [ -n "$RESULT" ]; then
    pass
else
    fail "Array was empty"
fi

run_test "TC-CONFIG-04: ff_credential_patterns returns tab-separated data"
setup_test_project
cd "$TEST_DIR"
source "$TEST_DIR/.claude/hooks/_config-reader.sh"
PATTERN_COUNT=$(ff_credential_patterns | wc -l | tr -d ' ')
if [ "$PATTERN_COUNT" -gt 0 ]; then
    pass
else
    fail "No credential patterns found (got $PATTERN_COUNT)"
fi

run_test "TC-CONFIG-05: ff_config works when config file missing"
setup_test_project
rm -f "$TEST_DIR/ff.config.json"
cd "$TEST_DIR"
source "$TEST_DIR/.claude/hooks/_config-reader.sh"
RESULT=$(ff_config ".testing.command" "default-cmd")
if [ "$RESULT" = "default-cmd" ]; then
    pass
else
    fail "Got '$RESULT', expected 'default-cmd'"
fi
echo ""

# ============================================
# Pre-Write Validate
# ============================================

echo "Pre-Write Validate:"

run_test "TC-PREWRITE-01: Passes clean content"
setup_test_project
cd "$TEST_DIR"
# Create corresponding test file so pipeline gate passes
mkdir -p "$TEST_DIR/test"
echo "// test" > "$TEST_DIR/test/app.test.js"
# Include ABOUTME so the new-file header check passes
INPUT='{"tool_input":{"file_path":"'$TEST_DIR'/src/app.js","content":"// ABOUTME: Test file for validation.\n// ABOUTME: Contains simple test content.\nconst x = 1;"}}'
EXIT_CODE=0
RESULT=$(echo "$INPUT" | "$TEST_DIR/.claude/hooks/pre-write-validate.sh" 2>&1) || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
    pass
else
    fail "Exit code was $EXIT_CODE"
fi

run_test "TC-PREWRITE-02: Blocks configured credential patterns (AWS key)"
setup_test_project
cd "$TEST_DIR"
INPUT='{"tool_input":{"file_path":"'$TEST_DIR'/src/app.js","content":"const key = \"AKIAIOSFODNN7EXAMPLE\";"}}'
EXIT_CODE=0
RESULT=$(echo "$INPUT" | "$TEST_DIR/.claude/hooks/pre-write-validate.sh" 2>&1) || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 2 ]; then
    pass
else
    fail "Exit code was $EXIT_CODE (expected 2)"
fi

run_test "TC-PREWRITE-03: Allows credential patterns in test files"
setup_test_project
cd "$TEST_DIR"
INPUT='{"tool_input":{"file_path":"'$TEST_DIR'/__tests__/app.test.js","content":"const key = \"AKIAIOSFODNN7EXAMPLE\";"}}'
EXIT_CODE=0
RESULT=$(echo "$INPUT" | "$TEST_DIR/.claude/hooks/pre-write-validate.sh" 2>&1) || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
    pass
else
    fail "Exit code was $EXIT_CODE (expected 0 for test files)"
fi

run_test "TC-PREWRITE-04: Meta-mode blocks production writes"
setup_test_project
mkdir -p "$TEST_DIR/.meta"
cd "$TEST_DIR"
INPUT='{"tool_input":{"file_path":"'$TEST_DIR'/src/production-code.js","content":"const x = 1;"}}'
EXIT_CODE=0
RESULT=$(echo "$INPUT" | "$TEST_DIR/.claude/hooks/pre-write-validate.sh" 2>&1) || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 2 ]; then
    pass
else
    fail "Exit code was $EXIT_CODE (expected 2 for meta-mode production write)"
fi

run_test "TC-PREWRITE-05: Meta-mode allows .claude/ writes"
setup_test_project
mkdir -p "$TEST_DIR/.meta"
cd "$TEST_DIR"
INPUT='{"tool_input":{"file_path":"'$TEST_DIR'/.claude/commands/test.md","content":"# Test"}}'
EXIT_CODE=0
RESULT=$(echo "$INPUT" | "$TEST_DIR/.claude/hooks/pre-write-validate.sh" 2>&1) || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
    pass
else
    fail "Exit code was $EXIT_CODE (expected 0 for .claude/ in meta-mode)"
fi

run_test "TC-PREWRITE-06: Non-evergreen naming warning fires"
setup_test_project
cd "$TEST_DIR"
# Use Edit tool (old_string/new_string) to avoid ABOUTME new-file check, and create the file first
mkdir -p "$TEST_DIR/src"
echo "// ABOUTME: Test.\n// ABOUTME: Test." > "$TEST_DIR/src/app.js"
INPUT='{"tool_input":{"file_path":"'$TEST_DIR'/src/app.js","new_string":"const ImprovedHandler = {};"}}'
EXIT_CODE=0
RESULT=$(echo "$INPUT" | "$TEST_DIR/.claude/hooks/pre-write-validate.sh" 2>&1) || EXIT_CODE=$?
if echo "$RESULT" | grep -q "NON-EVERGREEN"; then
    pass
else
    fail "Expected NON-EVERGREEN warning"
fi

run_test "TC-PREWRITE-07: Empty content passes without error"
setup_test_project
cd "$TEST_DIR"
INPUT='{"tool_input":{"file_path":"'$TEST_DIR'/src/app.js"}}'
EXIT_CODE=0
RESULT=$(echo "$INPUT" | "$TEST_DIR/.claude/hooks/pre-write-validate.sh" 2>&1) || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
    pass
else
    fail "Exit code was $EXIT_CODE"
fi
echo ""

# ============================================
# Pre-Bash Validate
# ============================================

echo "Pre-Bash Validate:"

run_test "TC-PREBASH-01: Blocks git commit --no-verify"
setup_test_project
cd "$TEST_DIR"
INPUT='{"tool_input":{"command":"git commit --no-verify -m test"}}'
EXIT_CODE=0
RESULT=$(echo "$INPUT" | "$TEST_DIR/.claude/hooks/pre-bash-validate.sh" 2>&1) || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 2 ]; then
    pass
else
    fail "Exit code was $EXIT_CODE (expected 2)"
fi

run_test "TC-PREBASH-02: Blocks force push to main"
setup_test_project
cd "$TEST_DIR"
INPUT='{"tool_input":{"command":"git push --force origin main"}}'
EXIT_CODE=0
RESULT=$(echo "$INPUT" | "$TEST_DIR/.claude/hooks/pre-bash-validate.sh" 2>&1) || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 2 ]; then
    pass
else
    fail "Exit code was $EXIT_CODE (expected 2)"
fi

run_test "TC-PREBASH-03: Allows normal git commands"
setup_test_project
cd "$TEST_DIR"
INPUT='{"tool_input":{"command":"git status"}}'
EXIT_CODE=0
RESULT=$(echo "$INPUT" | "$TEST_DIR/.claude/hooks/pre-bash-validate.sh" 2>&1) || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
    pass
else
    fail "Exit code was $EXIT_CODE (expected 0)"
fi

run_test "TC-PREBASH-04: Allows force push to feature branch"
setup_test_project
cd "$TEST_DIR"
INPUT='{"tool_input":{"command":"git push --force origin feature/my-branch"}}'
EXIT_CODE=0
RESULT=$(echo "$INPUT" | "$TEST_DIR/.claude/hooks/pre-bash-validate.sh" 2>&1) || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
    pass
else
    fail "Exit code was $EXIT_CODE (expected 0)"
fi
echo ""

# ============================================
# Flywheel Doc Check
# ============================================

echo "Flywheel Doc Check:"

run_test "TC-FLYWHEEL-01: Generates suggestions from config-driven mappings"
setup_test_project
cd "$TEST_DIR"
# Create a tracked source file
mkdir -p "$TEST_DIR/src"
echo "const x = 1;" > "$TEST_DIR/src/app.js"
git add src/app.js
# Set up session tracking
mkdir -p "$TEST_DIR/.claude"
echo "$(date +%s)|src/app.js" > "$TEST_DIR/.claude/.session-files"
date +%s > "$TEST_DIR/.claude/.session-start"
# Force run the flywheel
"$TEST_DIR/.claude/hooks/flywheel-doc-check.sh" --force 2>/dev/null || true
if [ -f "$TEST_DIR/.claude/pending-actions.md" ]; then
    CONTENT=$(cat "$TEST_DIR/.claude/pending-actions.md")
    if echo "$CONTENT" | grep -q "CLAUDE.md"; then
        pass
    else
        fail "No CLAUDE.md suggestion generated"
    fi
else
    fail "pending-actions.md not created"
fi

run_test "TC-FLYWHEEL-02: Debounce prevents rapid re-firing"
setup_test_project
cd "$TEST_DIR"
mkdir -p "$TEST_DIR/.claude"
date +%s > "$TEST_DIR/.claude/.last-doc-check"
# Run without --force — should be debounced
RESULT=$("$TEST_DIR/.claude/hooks/flywheel-doc-check.sh" 2>&1) || true
# The flywheel should exit silently when debounced
if [ -z "$RESULT" ] || ! echo "$RESULT" | grep -q "Doc flywheel:"; then
    pass
else
    fail "Flywheel ran despite debounce"
fi
echo ""

# ============================================
# Session Tracking
# ============================================

echo "Session Tracking:"

run_test "TC-SESSION-01: Post-write tracks files to .session-files"
setup_test_project
cd "$TEST_DIR"
mkdir -p "$TEST_DIR/src"
touch "$TEST_DIR/src/tracked.txt"
# Use .txt to avoid triggering linter (no package.json in temp dir)
INPUT='{"tool_input":{"file_path":"'$TEST_DIR'/src/tracked.txt"}}'
echo "$INPUT" | "$TEST_DIR/.claude/hooks/post-write.sh" 2>/dev/null || true
SESSION_DIR="$TEST_DIR/.claude"
if [ -f "$SESSION_DIR/.session-files" ] && grep -q "src/tracked.txt" "$SESSION_DIR/.session-files"; then
    pass
else
    fail "File not tracked in .session-files"
fi

run_test "TC-SESSION-02: Session-start creates .session-start"
setup_test_project
cd "$TEST_DIR"
INPUT='{"session_id":"test","source":"test","model":"test"}'
echo "$INPUT" | "$TEST_DIR/.claude/hooks/session-start-log.sh" 2>/dev/null || true
if [ -f "$TEST_DIR/.claude/.session-start" ]; then
    pass
else
    fail ".session-start not created"
fi
echo ""

# ============================================
# Summary
# ============================================

echo "=============================="
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped (out of $TOTAL)"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}FAILED: $FAIL test(s) failed.${NC}"
    exit 1
else
    echo -e "${GREEN}ALL TESTS PASSED.${NC}"
    exit 0
fi
