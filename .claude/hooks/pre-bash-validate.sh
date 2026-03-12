#!/bin/bash
# ABOUTME: Pre-bash validation hook for git and deployment safety.
# ABOUTME: Blocks dangerous git operations and validates test status before deploy.

# Claude Code passes tool input as JSON on stdin, not env vars.
HOOK_INPUT=""
if [ ! -t 0 ]; then
    HOOK_INPUT="$(cat)"
fi

COMMAND=""
if [ -n "$HOOK_INPUT" ] && command -v jq &> /dev/null; then
    COMMAND="$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
fi

# Exit if no command
if [ -z "$COMMAND" ]; then
    exit 0
fi

# Source config reader
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/_config-reader.sh" ]; then
    source "$SCRIPT_DIR/_config-reader.sh"
fi

# ============================================
# GIT COMMIT VALIDATION (No --no-verify)
# ============================================

if echo "$COMMAND" | grep -qE "git\s+commit.*--no-verify"; then
    echo "BLOCKED: git commit --no-verify is not allowed!" >&2
    echo "" >&2
    echo "The --no-verify flag bypasses pre-commit hooks which enforce code quality." >&2
    echo "If pre-commit hooks are failing, fix the underlying issues instead." >&2
    echo "" >&2
    exit 2
fi

# Also catch the short form -n
if echo "$COMMAND" | grep -qE "git\s+commit.*\s-n(\s|$)"; then
    echo "BLOCKED: git commit -n (--no-verify) is not allowed!" >&2
    echo "" >&2
    echo "Pre-commit hooks must run to ensure code quality." >&2
    echo "" >&2
    exit 2
fi

# ============================================
# PRE-COMMIT DOCUMENTATION REMINDER
# ============================================

# Check if this is a git commit (but not the --no-verify checks above which already exited)
if echo "$COMMAND" | grep -qE "^git\s+commit"; then
    # Determine project root and source environment detection
    source "$SCRIPT_DIR/_meta-mode.sh"

    # ============================================
    # EPHEMERAL BRANCH WARNING
    # ============================================
    # Warn when committing to branches that look like validation/headless runs.
    # These branches should not accumulate feature work — commit to main instead.
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if echo "$CURRENT_BRANCH" | grep -qE "^(validation-|headless-|uber-val-|fresh-install-)"; then
        echo "" >&2
        echo "EPHEMERAL BRANCH: $CURRENT_BRANCH" >&2
        echo "" >&2
        echo "You are committing to what looks like a validation/test branch." >&2
        echo "If this is feature work, switch to main first:" >&2
        echo "" >&2
        echo "  git stash && git checkout main && git stash pop" >&2
        echo "" >&2
        echo "If this commit is intentionally on this branch, proceed." >&2
        echo "" >&2
    fi

    # ============================================
    # META REFERENCE LEAKAGE WARNING
    # ============================================
    # Warn if staged files contain .meta/ references (potential leakage)
    if git diff --staged 2>/dev/null | grep -qE '\.meta/'; then
        echo "" >&2
        echo "WARNING: Staged changes reference .meta/" >&2
        echo "" >&2
        echo "This may indicate meta-development content leaking into shipped code." >&2
        echo "Review with: git diff --staged | grep '.meta/'" >&2
        echo "" >&2
        echo "If this is intentional documentation about the separation, proceed." >&2
        echo "" >&2
    fi

    # Call the consolidated flywheel-doc-check (environment-aware)
    FLYWHEEL_HOOK="$SCRIPT_DIR/flywheel-doc-check.sh"
    if [ -x "$FLYWHEEL_HOOK" ]; then
        "$FLYWHEEL_HOOK" --force
    fi

    # ============================================
    # AUTO-CLEAR ADDRESSED PENDING ACTIONS
    # ============================================
    PENDING_ACTIONS="$CLAUDE_PENDING_ACTIONS"
    if [ -f "$PENDING_ACTIONS" ]; then
        STAGED_FILES=$(git diff --staged --name-only 2>/dev/null)
        if [ -n "$STAGED_FILES" ]; then
            CLEARED_COUNT=0
            TEMP_FILE=$(mktemp)
            while IFS= read -r line; do
                if echo "$line" | grep -q "^\- \["; then
                    # Extract doc path: text between bullet and " - "
                    DOC_PATH=$(echo "$line" | sed -n 's/.*• \(.*\) - .*/\1/p')
                    # Resolve aliases
                    case "$DOC_PATH" in
                        "Root CLAUDE.md") RESOLVED="CLAUDE.md" ;;
                        "Verify doc-map.md"*) RESOLVED=".claude/references/doc-map.md" ;;
                        ".meta/"*) RESOLVED="" ;;  # gitignored, skip
                        "Relevant "*) RESOLVED="" ;;  # too vague, skip
                        *) RESOLVED="$DOC_PATH" ;;
                    esac
                    # Check if resolved path is in staged files
                    if [ -n "$RESOLVED" ] && echo "$STAGED_FILES" | grep -qF "$RESOLVED"; then
                        TIMESTAMP=$(echo "$line" | sed -n 's/.*\[\(.*\)\].*/\1/p')
                        echo "*Auto-cleared [$TIMESTAMP]: $DOC_PATH - staged in this commit*" >> "$TEMP_FILE"
                        CLEARED_COUNT=$((CLEARED_COUNT + 1))
                    else
                        echo "$line" >> "$TEMP_FILE"
                    fi
                else
                    echo "$line" >> "$TEMP_FILE"
                fi
            done < "$PENDING_ACTIONS"
            mv "$TEMP_FILE" "$PENDING_ACTIONS"
            if [ "$CLEARED_COUNT" -gt 0 ]; then
                echo "" >&2
                echo "Doc flywheel: Auto-cleared $CLEARED_COUNT pending action(s) addressed in this commit." >&2
            fi
        fi
    fi

    # ============================================
    # COMMIT CHECKLIST PROMPT (Non-blocking)
    # ============================================
    echo "" >&2
    echo "COMMIT CHECKLIST" >&2
    echo "  [ ] Updated todo if applicable?" >&2
    echo "  [ ] Captured learnings?" >&2
    echo "  [ ] Design decision documented if architectural?" >&2
    echo "" >&2

    # ============================================
    # PENDING DOCUMENTATION ACTIONS (BLOCKING)
    # ============================================
    if [ -f "$PENDING_ACTIONS" ]; then
        ACTION_COUNT=$(grep -c "^\- \[" "$PENDING_ACTIONS" 2>/dev/null || echo "0")
        if [ "$ACTION_COUNT" -gt 0 ]; then
            echo "" >&2
            echo "PENDING DOCUMENTATION ACTIONS ($ACTION_COUNT items)" >&2
            echo "" >&2
            grep "^\- \[" "$PENDING_ACTIONS" >&2
            echo "" >&2

            # Check for escape hatch (environment variable)
            if [ "$SKIP_PENDING_ACTIONS" = "true" ] || [ "$SKIP_PENDING_ACTIONS" = "1" ]; then
                echo "Skipping pending-actions check (SKIP_PENDING_ACTIONS set)" >&2
                echo "" >&2
            else
                echo "BLOCKED: Pending documentation actions must be addressed!" >&2
                echo "" >&2
                echo "Options:" >&2
                echo "  1. Address the pending actions and clear the file" >&2
                echo "  2. Override: SKIP_PENDING_ACTIONS=true git commit ..." >&2
                echo "" >&2
                echo "To clear after addressing:" >&2
                echo "  rm $PENDING_ACTIONS" >&2
                echo "" >&2
                exit 2
            fi
        fi
    fi
fi

# ============================================
# FORCE PUSH PROTECTION
# ============================================

if echo "$COMMAND" | grep -qE "git\s+push.*--force"; then
    if echo "$COMMAND" | grep -qE "\s(main|master)(\s|$)"; then
        echo "BLOCKED: Force push to main/master is not allowed!" >&2
        echo "" >&2
        echo "Force pushing to protected branches can cause data loss." >&2
        echo "If you need to revert changes, use 'git revert' instead." >&2
        echo "" >&2
        exit 2
    fi
fi

# ============================================
# DEPLOYMENT VALIDATION (CONFIG-DRIVEN)
# ============================================

DEPLOY_CMD=$(ff_config ".deployment.command" "" 2>/dev/null)

if [ -n "$DEPLOY_CMD" ] && echo "$COMMAND" | grep -qF "$DEPLOY_CMD"; then
    echo "Deployment detected - running pre-deployment validation..."

    # Check for uncommitted changes
    if [ -d ".git" ]; then
        UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        if [ "$UNCOMMITTED" -gt 0 ]; then
            echo "WARNING: You have $UNCOMMITTED uncommitted change(s)."
            echo "Consider committing before deployment."
            echo ""
        fi
    fi

    # Run tests (config-driven)
    TEST_CMD=$(ff_config ".testing.command" "npm test" 2>/dev/null)
    echo "Running tests..."
    if ! $TEST_CMD --silent 2>/dev/null; then
        echo "" >&2
        echo "BLOCKED: Tests are failing!" >&2
        echo "" >&2
        echo "All tests must pass before deployment." >&2
        echo "Run '$TEST_CMD' to see failures and fix them." >&2
        echo "" >&2
        exit 2
    fi
    echo "Tests passed"

    # Check code coverage (config-driven threshold)
    COVERAGE_CMD=$(ff_config ".testing.coverageCommand" "" 2>/dev/null)
    COVERAGE_MIN=$(ff_config ".testing.coverageThreshold" "80" 2>/dev/null)

    if [ -n "$COVERAGE_CMD" ]; then
        echo "Checking code coverage..."
        COVERAGE_SUMMARY="coverage/coverage-summary.json"

        if [ ! -f "$COVERAGE_SUMMARY" ] || [ "package.json" -nt "$COVERAGE_SUMMARY" ]; then
            $COVERAGE_CMD 2>/dev/null || true
        fi

        if [ -f "$COVERAGE_SUMMARY" ] && command -v jq &> /dev/null; then
            STATEMENTS=$(jq -r '.total.statements.pct // 0' "$COVERAGE_SUMMARY" 2>/dev/null)
            BRANCHES=$(jq -r '.total.branches.pct // 0' "$COVERAGE_SUMMARY" 2>/dev/null)

            COVERAGE_FAILED=false
            FAILED_METRICS=""

            if [ "$(echo "$STATEMENTS < $COVERAGE_MIN" | bc -l 2>/dev/null || echo "0")" = "1" ]; then
                COVERAGE_FAILED=true
                FAILED_METRICS="${FAILED_METRICS}statements: ${STATEMENTS}%, "
            fi
            if [ "$(echo "$BRANCHES < $COVERAGE_MIN" | bc -l 2>/dev/null || echo "0")" = "1" ]; then
                COVERAGE_FAILED=true
                FAILED_METRICS="${FAILED_METRICS}branches: ${BRANCHES}%, "
            fi

            if [ "$COVERAGE_FAILED" = true ]; then
                FAILED_METRICS=$(echo "$FAILED_METRICS" | sed 's/, $//')
                echo "" >&2
                echo "BLOCKED: Code coverage below ${COVERAGE_MIN}% threshold!" >&2
                echo "" >&2
                echo "Failed metrics: $FAILED_METRICS" >&2
                echo "" >&2
                exit 2
            fi
            echo "Coverage check passed"
        fi
    fi

    # Run linting (config-driven)
    LINT_CMD=$(ff_config ".linting.command" "" 2>/dev/null)
    if [ -n "$LINT_CMD" ]; then
        echo "Running linter..."
        if ! $LINT_CMD --silent 2>/dev/null; then
            echo "" >&2
            echo "BLOCKED: Linting errors detected!" >&2
            echo "" >&2
            echo "Fix linting errors before deployment." >&2
            echo "" >&2
            exit 2
        fi
        echo "Linting passed"
    fi

    echo "Pre-deployment validation complete."
    echo ""
fi

exit 0
