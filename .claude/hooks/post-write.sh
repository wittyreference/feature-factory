#!/bin/bash
# ABOUTME: Post-write hook for auto-linting and session file tracking.
# ABOUTME: Environment-aware: tracks files to .meta/ (meta) or .claude/ (shipped).

# ============================================
# PARSE TOOL INPUT FROM STDIN
# ============================================
# Claude Code passes tool input as JSON on stdin, not env vars.
# Capture it before anything else consumes stdin.
HOOK_INPUT=""
if [ ! -t 0 ]; then
    HOOK_INPUT="$(cat)"
fi

# Extract file path from JSON input (Write: .tool_input.file_path, Edit: .tool_input.file_path)
FILE_PATH=""
if [ -n "$HOOK_INPUT" ] && command -v jq &> /dev/null; then
    FILE_PATH="$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
fi

# ============================================
# COMPACT-PENDING MARKER CHECK
# ============================================
# After auto-compaction, PreCompact leaves a marker file. Pick it up here
# to run the compaction summary extraction (since SessionStart only fires
# for manual /compact, not auto-compaction).
_check_compact_pending() {
    local HOOK_DIR="$(dirname "${BASH_SOURCE[0]}")"
    source "$HOOK_DIR/_meta-mode.sh"
    local MARKER
    if [ "$CLAUDE_META_MODE" = "true" ]; then
        MARKER="$PROJECT_ROOT/.meta/.compact-pending"
    else
        MARKER="$PROJECT_ROOT/.claude/.compact-pending"
    fi
    if [ -f "$MARKER" ]; then
        "$HOOK_DIR/post-compact-summary.sh" < "$MARKER"
        rm -f "$MARKER"
    fi
}
_check_compact_pending

# Exit early if no file path
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# ============================================
# SESSION FILE TRACKING (for doc flywheel)
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source environment detection for meta-aware paths
source "$SCRIPT_DIR/_meta-mode.sh"

# Source config reader
if [ -f "$SCRIPT_DIR/_config-reader.sh" ]; then
    source "$SCRIPT_DIR/_config-reader.sh"
fi

# Use environment-aware paths (routes to .meta/ or .claude/ based on context)
SESSION_DIR="$(dirname "$CLAUDE_PENDING_ACTIONS")"
SESSION_FILE="$SESSION_DIR/.session-files"
SESSION_START="$SESSION_DIR/.session-start"

# Initialize session start time if not set
if [ ! -f "$SESSION_START" ]; then
    date +%s > "$SESSION_START"
fi

# Track this file (append if not already present)
# Make path relative to project root for consistency
REL_PATH="${FILE_PATH#$PROJECT_ROOT/}"
if [ -n "$REL_PATH" ]; then
    # Create session file if it doesn't exist
    touch "$SESSION_FILE" 2>/dev/null
    # Add file if not already tracked (with timestamp)
    if ! grep -qF "$REL_PATH" "$SESSION_FILE" 2>/dev/null; then
        echo "$(date +%s)|$REL_PATH" >> "$SESSION_FILE"
    fi
fi

# ============================================
# AUTONOMOUS EVENT LOGGING (for learning exercises)
# ============================================
# Log file events during autonomous work for retrospective exercise generation.
# Only fires when running headless, as a subagent, or in a team workflow.

if [ -n "${CLAUDE_HEADLESS:-}" ] || [ -n "${CLAUDE_SUBAGENT:-}" ] || [ -n "${CLAUDE_TEAM_NAME:-}" ]; then
    if [ -n "$CLAUDE_LEARNING_DIR" ] && [ -d "$CLAUDE_LEARNING_DIR" ]; then
        # Only log files in tracked directories (config-driven)
        IS_TRACKED=false
        TRACKED_DIRS=$(ff_config_array ".trackedDirectories" 2>/dev/null)
        if [ -z "$TRACKED_DIRS" ]; then
            # Default: track common directories
            IS_TRACKED=true
        else
            while IFS= read -r dir; do
                if [[ "$REL_PATH" == "$dir"* ]]; then
                    IS_TRACKED=true
                    break
                fi
            done <<< "$TRACKED_DIRS"
        fi

        if [ "$IS_TRACKED" = true ]; then
            EVENT_TS=$(date +%s)
            EVENT_SESSION="${CLAUDE_TEAM_NAME:-${CLAUDE_SUBAGENT:-headless}}"
            # Determine if file is new or modified
            if git -C "$PROJECT_ROOT" ls-files --error-unmatch "$REL_PATH" &>/dev/null 2>&1; then
                EVENT_TYPE="file_modified"
            else
                EVENT_TYPE="file_created"
            fi
            # Extract ABOUTME context if present
            EVENT_CONTEXT=""
            HEADER_PATTERN=$(ff_config ".fileHeaders.pattern" "ABOUTME:" 2>/dev/null)
            if [ -f "$FILE_PATH" ]; then
                EVENT_CONTEXT=$(head -5 "$FILE_PATH" | grep "$HEADER_PATTERN" | head -1 | sed "s/.*${HEADER_PATTERN} *//" || true)
            fi
            # Append event as JSON line
            printf '{"ts":%d,"type":"%s","path":"%s","session":"%s","context":"%s"}\n' \
                "$EVENT_TS" "$EVENT_TYPE" "$REL_PATH" "$EVENT_SESSION" "$EVENT_CONTEXT" \
                >> "$CLAUDE_LEARNING_DIR/session-log.jsonl"
        fi
    fi
fi

# ============================================
# AUTO-LINT (CONFIG-DRIVEN)
# ============================================

# Get lint fix command from config
LINT_FIX_CMD=$(ff_config ".linting.fixCommand" "" 2>/dev/null)

if [ -n "$LINT_FIX_CMD" ] && [ -f "$FILE_PATH" ]; then
    # Skip node_modules and other excluded paths
    if [[ ! "$FILE_PATH" =~ node_modules|\.min\.|dist/|build/ ]]; then
        # Run lint fix command with the file path
        LINT_OUTPUT=$($LINT_FIX_CMD "$FILE_PATH" 2>&1)
        LINT_EXIT=$?

        if [ $LINT_EXIT -ne 0 ] && [ -n "$LINT_OUTPUT" ]; then
            echo "Linter found issues in $(basename "$FILE_PATH"):"
            echo "$LINT_OUTPUT" | head -20
        fi
    fi
fi

# ============================================
# ABOUTME WARNING (non-blocking, config-driven)
# ============================================

if [ -f "$FILE_PATH" ] && [ -f "$HOOK_DIR/_config-reader.sh" ]; then
    REL_CHECK="${FILE_PATH#$PROJECT_ROOT/}"
    HEADER_PATTERN=$(ff_config ".fileHeaders.pattern" "ABOUTME:" 2>/dev/null)

    # Only check source files that require headers (skip tests)
    if ff_requires_header "$REL_CHECK" 2>/dev/null && [[ ! "$REL_CHECK" =~ (\.test\.|\.spec\.|__tests__|/tests?/) ]]; then
        HEADER_COUNT=$(head -5 "$FILE_PATH" | grep -c "$HEADER_PATTERN" || true)
        REQUIRED_LINES=$(ff_config ".fileHeaders.requiredLines" "2" 2>/dev/null)
        if [ "$HEADER_COUNT" -eq 0 ]; then
            echo ""
            echo "Note: $(basename "$FILE_PATH") is missing $HEADER_PATTERN comment."
            echo "Consider adding at the top of the file:"
            echo "  // $HEADER_PATTERN [What this file does]"
            echo "  // $HEADER_PATTERN [Additional context]"
        elif [ "$HEADER_COUNT" -lt "$REQUIRED_LINES" ]; then
            echo ""
            echo "Note: $(basename "$FILE_PATH") has only $HEADER_COUNT $HEADER_PATTERN line(s) ($REQUIRED_LINES recommended)."
        fi
    fi
fi

exit 0
