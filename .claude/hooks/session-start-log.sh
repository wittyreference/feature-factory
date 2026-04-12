#!/bin/bash
# ABOUTME: Logs all SessionStart events and runs bootstrap checks.
# ABOUTME: Captures source, session ID, and validates environment on session start.

INPUT=$(cat)

# Extract fields from hook input
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
SOURCE=$(echo "$INPUT" | jq -r '.source // "unknown"' 2>/dev/null)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null)
MODEL=$(echo "$INPUT" | jq -r '.model // "unknown"' 2>/dev/null)

# Source meta-mode detection for environment-aware paths
HOOK_DIR="$(dirname "$0")"
if [ -f "$HOOK_DIR/_meta-mode.sh" ]; then
    source "$HOOK_DIR/_meta-mode.sh"
fi

# Source config reader
if [ -f "$HOOK_DIR/_config-reader.sh" ]; then
    source "$HOOK_DIR/_config-reader.sh"
fi

# Set up paths
if [ "$CLAUDE_META_MODE" = "true" ]; then
    LOGS_DIR=".meta/logs"
else
    LOGS_DIR=".claude/logs"
fi
mkdir -p "$LOGS_DIR"

TIMESTAMP=$(date -Iseconds)

# Log every SessionStart event (this is the diagnostic value)
echo "SessionStart: source=$SOURCE session=$SESSION_ID model=$MODEL timestamp=$TIMESTAMP" >> "$LOGS_DIR/session-events.log"

# Structured event emission (observability)
source "$HOOK_DIR/_emit-event.sh"
EMIT_SESSION_ID="$SESSION_ID"
emit_event "session_start" "$(jq -nc --arg src "$SOURCE" --arg mdl "$MODEL" '{source: $src, model: $mdl}')"

# For compaction-like events, attempt to extract the compaction summary
if [ "$SOURCE" = "compact" ] || [ "$SOURCE" = "clear" ] || [ "$SOURCE" = "plan" ]; then
    if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
        SUMMARY_FILE="$LOGS_DIR/compaction-summary-$(date +%Y%m%d-%H%M%S).md"
        SUMMARY=$(jq -rs '[.[] | select(.isCompactSummary == true)] | last | .message.content' "$TRANSCRIPT_PATH" 2>/dev/null)
        if [ -n "$SUMMARY" ] && [ "$SUMMARY" != "null" ]; then
            {
                echo "# Compaction Summary"
                echo ""
                echo "**Captured:** $TIMESTAMP"
                echo "**Source:** $SOURCE"
                echo "**Session:** $SESSION_ID"
                echo "**Transcript:** $TRANSCRIPT_PATH"
                echo ""
                echo "---"
                echo ""
                echo "$SUMMARY"
            } > "$SUMMARY_FILE"
            echo "Compaction summary saved (source=$SOURCE): $SUMMARY_FILE" >&2
        fi
    fi
fi

# --- Session Bootstrap Checks ---
# Local-only checks (no API calls, <500ms). Warnings to stderr so Claude sees them.

# 0. First-run name check: detect if CLAUDE.md still has the placeholder
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if grep -q '\[Your name here\]' "$PROJECT_ROOT/CLAUDE.md" 2>/dev/null; then
    echo "FIRST_RUN: Preferred name not set. Ask the user for their preferred name and update CLAUDE.md." >&2
fi

# Determine session dir early for stale check
if [ "$CLAUDE_META_MODE" = "true" ]; then
    SESSION_DIR="$PROJECT_ROOT/.meta"
else
    SESSION_DIR="$PROJECT_ROOT/.claude"
fi

# Session-scoped state directory (isolates per-session files for concurrent sessions)
SESSIONS_DIR="$SESSION_DIR/.sessions"
mkdir -p "$SESSIONS_DIR"

# Cleanup stale per-session files (older than 48h)
find "$SESSIONS_DIR" -type f -mmin +2880 -delete 2>/dev/null || true

# 1. Stale session check (BEFORE reset — checks THIS session's previous timestamp)
PREV_START_FILE="$SESSIONS_DIR/${SESSION_ID}.start"
# Fall back to legacy shared file if per-session file doesn't exist
if [ ! -f "$PREV_START_FILE" ] && [ -f "$SESSION_DIR/.session-start" ]; then
    PREV_START_FILE="$SESSION_DIR/.session-start"
fi
if [ -f "$PREV_START_FILE" ]; then
    PREV_START=$(cat "$PREV_START_FILE" 2>/dev/null)
    NOW=$(date +%s)
    if [ -n "$PREV_START" ] && [ "$PREV_START" -gt 0 ] 2>/dev/null; then
        AGE_HOURS=$(( (NOW - PREV_START) / 3600 ))
        if [ "$AGE_HOURS" -gt 48 ]; then
            echo "WARNING: Previous session started ${AGE_HOURS}h ago. Flywheel 'recent commits' may return excessive results." >&2
        fi
    fi
fi


# 1b. Warn if main working directory is not on 'main' branch
# A previous session may have left the main tree on a feature branch.
# Only applies to the main tree - worktrees are expected to be on other branches.
if git rev-parse --is-inside-work-tree &>/dev/null; then
    GIT_COMMON="$(git rev-parse --git-common-dir 2>/dev/null)"
    # In a worktree, --git-common-dir contains "/worktrees/". In main tree it's just ".git".
    if ! echo "$GIT_COMMON" | grep -q '/worktrees/'; then
        BRANCH=$(git branch --show-current 2>/dev/null)
        if [ -n "$BRANCH" ] && [ "$BRANCH" != "main" ]; then
            echo "" >&2
            echo "WARNING: Main working directory is on branch '$BRANCH', not 'main'." >&2
            echo "A previous session may have left it here." >&2
            echo "Consider: git checkout main" >&2
            echo "" >&2
        fi
    fi
fi

# 1c. Worktree advisory for write sessions
# Non-blocking — just sets expectations early so the agent knows writes will be blocked.
if git rev-parse --is-inside-work-tree &>/dev/null; then
    _SS_GIT_COMMON="$(git rev-parse --git-common-dir 2>/dev/null)"
    if ! echo "$_SS_GIT_COMMON" | grep -q '/worktrees/'; then
        echo "" >&2
        echo "NOTE: This session is on the main tree. If you plan to write code" >&2
        echo "or commit, run /worktree-start first. Writes to repo files and" >&2
        echo "git commit are blocked on the main tree (worktree isolation enforced)." >&2
        echo "" >&2
    fi
fi

# 2. Required env vars check (config-driven)
if [ -f "$PROJECT_ROOT/.env" ]; then
    MISSING_VARS=""
    while IFS= read -r VAR_NAME; do
        [ -z "$VAR_NAME" ] && continue
        VAR_VALUE=$(grep "^${VAR_NAME}=" "$PROJECT_ROOT/.env" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        if [ -z "$VAR_VALUE" ]; then
            MISSING_VARS="${MISSING_VARS} ${VAR_NAME}"
        elif echo "$VAR_VALUE" | grep -qE '^(xxx|placeholder|changeme|TODO|your_)'; then
            MISSING_VARS="${MISSING_VARS} ${VAR_NAME}(placeholder)"
        fi
    done < <(ff_config_array ".requiredEnvVars")
    if [ -n "$MISSING_VARS" ]; then
        echo "WARNING: .env issues:${MISSING_VARS}" >&2
    fi
elif [ -f "$PROJECT_ROOT/.env.example" ]; then
    echo "WARNING: No .env file found. Copy .env.example and configure." >&2
fi

# 3. Pending learning exercises check
if [ "$CLAUDE_META_MODE" = "true" ] && [ -n "$CLAUDE_LEARNING_DIR" ] && [ -d "$CLAUDE_LEARNING_DIR" ]; then
    EXERCISE_FILE="$CLAUDE_LEARNING_DIR/exercises.md"
    STATE_FILE="$CLAUDE_LEARNING_DIR/exercise-state.json"
    if [ -f "$EXERCISE_FILE" ]; then
        EXERCISE_COUNT=$(grep -c '^## ' "$EXERCISE_FILE" 2>/dev/null) || EXERCISE_COUNT=0
        if [ "$EXERCISE_COUNT" -gt 0 ]; then
            echo "LEARNING: $EXERCISE_COUNT exercise(s) pending — use /learn" >&2
        fi
    fi
    # Reset per-session exercise state
    if [ -f "$STATE_FILE" ]; then
        cat > "$STATE_FILE" <<STATEEOF
{
  "exercises_offered": 0,
  "exercises_completed": 0,
  "exercises_declined": false,
  "last_exercise_ts": 0,
  "topics_covered": []
}
STATEEOF
    fi
fi

# --- Skip expensive checks in CI (GitHub Actions, headless -p mode) ---
# CI sets CI=true. Headless mode can set CLAUDE_HEADLESS=true.
# These checks are for interactive sessions — CI has its own validation pipeline.
if [ "${CI:-}" = "true" ] || [ "${CLAUDE_HEADLESS:-}" = "true" ]; then
    echo "CI/headless mode — skipping update checks, smoke tests." >&2
    exit 0
fi

# 4. Update check (quiet mode — only prints if update available)
if [ -f "$PROJECT_ROOT/scripts/check-updates.sh" ]; then
    bash "$PROJECT_ROOT/scripts/check-updates.sh" --quiet 2>&1 || true
fi

# 4b. Changelog monitor (new features in Claude Code + Agent SDK)
if [ -f "$PROJECT_ROOT/scripts/check-changelog.sh" ]; then
    bash "$PROJECT_ROOT/scripts/check-changelog.sh" --quiet 2>&1 || true
fi


# 4c. Dependency freshness check (7-day cache)
if [ -f "$PROJECT_ROOT/scripts/check-deps.sh" ]; then
    bash "$PROJECT_ROOT/scripts/check-deps.sh" --quiet 2>&1 || true
fi

# 5. Context Hub availability
if command -v chub >/dev/null 2>&1; then
    echo "Context Hub (chub) available for external API docs." >&2
fi

# 5b. direnv status check — if direnv is installed but .envrc not allowed,
# the MCP server will get empty env vars and crash silently.
if command -v direnv >/dev/null 2>&1 && [ -f "$PROJECT_ROOT/.envrc" ]; then
    if ! direnv status 2>/dev/null | grep -q "Found RC allowed true"; then
        echo "WARNING: direnv installed but .envrc not allowed. Run: direnv allow" >&2
    fi
elif ! command -v direnv >/dev/null 2>&1 && [ -f "$PROJECT_ROOT/.envrc" ]; then
    echo "WARNING: direnv not installed. Shell env vars may override .env. Install: brew install direnv" >&2
fi

# 6. Codebase smoke test (syntax + deps, <200ms)
# Language-aware: only run checks relevant to the project's language.
SMOKE_FAILURES=""
PROJECT_LANG=$(ff_config ".project.language" "javascript" 2>/dev/null)

case "$PROJECT_LANG" in
    javascript|typescript)
        # Node.js: check node_modules, package.json, and JS syntax
        if [ ! -d "$PROJECT_ROOT/node_modules" ]; then
            SMOKE_FAILURES="${SMOKE_FAILURES} node_modules(missing)"
        fi
        if [ -f "$PROJECT_ROOT/package.json" ]; then
            if ! node -e "JSON.parse(require('fs').readFileSync('$PROJECT_ROOT/package.json','utf8'))" 2>/dev/null; then
                SMOKE_FAILURES="${SMOKE_FAILURES} package.json(invalid)"
            fi
        fi
        SOURCE_DIRS=$(ff_config_array ".project.sourceDirectories" 2>/dev/null)
        if [ -n "$SOURCE_DIRS" ]; then
            while IFS= read -r dir; do
                [ -z "$dir" ] && continue
                if [ -d "$PROJECT_ROOT/$dir" ]; then
                    SYNTAX_ERRORS=$(find "$PROJECT_ROOT/$dir" -name "*.js" -not -path "*/node_modules/*" -exec node -e "
const fs = require('fs');
const vm = require('vm');
const errors = [];
for (const f of process.argv.slice(1)) {
  try { new vm.Script(fs.readFileSync(f, 'utf8'), {filename: f}); }
  catch(e) { errors.push(f.replace('$PROJECT_ROOT/', '') + ': ' + e.message.split('\n')[0]); }
}
if (errors.length) { console.log(errors.length); console.error(errors.join('\n')); process.exit(1); }
" {} + 2>&1 || true)
                    if [ -n "$SYNTAX_ERRORS" ]; then
                        BAD_COUNT=$(echo "$SYNTAX_ERRORS" | head -1)
                        SMOKE_FAILURES="${SMOKE_FAILURES} ${dir}(${BAD_COUNT} syntax errors)"
                    fi
                fi
            done <<< "$SOURCE_DIRS"
        fi
        ;;
    go)
        if [ -f "$PROJECT_ROOT/go.mod" ]; then
            if ! command -v go &>/dev/null; then
                SMOKE_FAILURES="${SMOKE_FAILURES} go(not installed)"
            fi
        fi
        ;;
    python)
        if [ -f "$PROJECT_ROOT/requirements.txt" ] || [ -f "$PROJECT_ROOT/pyproject.toml" ] || [ -f "$PROJECT_ROOT/setup.py" ]; then
            if ! command -v python3 &>/dev/null && ! command -v python &>/dev/null; then
                SMOKE_FAILURES="${SMOKE_FAILURES} python(not installed)"
            fi
        fi
        ;;
    rust)
        if [ -f "$PROJECT_ROOT/Cargo.toml" ]; then
            if ! command -v cargo &>/dev/null; then
                SMOKE_FAILURES="${SMOKE_FAILURES} cargo(not installed)"
            fi
        fi
        ;;
esac

if [ -n "$SMOKE_FAILURES" ]; then
    TEST_CMD=$(ff_config ".testing.command" "npm test" 2>/dev/null)
    echo "SMOKE TEST FAILED:${SMOKE_FAILURES}" >&2
    echo "  Fix these before starting work. Run '$TEST_CMD' for details." >&2
fi

echo "Run /preflight for full environment validation." >&2

# --- Session Context Loader ---
# Surface accumulated knowledge so Claude starts with relevant context.
# Fast reads only (grep, wc, ls). No jq on large files.

LEARNINGS_FILE="$SESSION_DIR/learnings.md"
PENDING_FILE="$SESSION_DIR/pending-actions.md"
DECISIONS_FILE="$PROJECT_ROOT/DESIGN_DECISIONS.md"
COMPACTION_DIR="$LOGS_DIR"

CONTEXT_LINES=""

# Recent learnings: count + last 3 topic headers
if [ -f "$LEARNINGS_FILE" ]; then
    LEARN_COUNT=$(grep -c '^## \[' "$LEARNINGS_FILE" 2>/dev/null) || LEARN_COUNT=0
    if [ "$LEARN_COUNT" -gt 0 ]; then
        RECENT_TOPICS=$(grep '^## \[' "$LEARNINGS_FILE" | tail -3 | sed 's/^## \[[0-9-]*\] //' | sed 's/^ *//' | tr '\n' '|' | sed 's/|$//;s/|/, /g')
        LEARN_MSG="Learnings: $LEARN_COUNT entries (latest: $RECENT_TOPICS)"
        if [ "$LEARN_COUNT" -gt 10 ]; then
            LEARN_MSG="$LEARN_MSG — consider pruning"
        fi
        CONTEXT_LINES="${CONTEXT_LINES}${LEARN_MSG}\n"
    fi
fi

# Recent design decisions: last 2 titles
if [ -f "$DECISIONS_FILE" ]; then
    RECENT_DECISIONS=$(grep '^## Decision [0-9]' "$DECISIONS_FILE" | tail -2 | sed 's/^## //' | tr '\n' '|' | sed 's/|$//;s/|/, /g')
    if [ -n "$RECENT_DECISIONS" ]; then
        CONTEXT_LINES="${CONTEXT_LINES}Decisions: $RECENT_DECISIONS\n"
    fi
fi


# Branch-aware plan matching: surface relevant plans based on current branch name
PLAN_INDEX="$HOME/.claude/plans/INDEX.md"
if [ -f "$PLAN_INDEX" ]; then
    BRANCH_NAME=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [ -n "$BRANCH_NAME" ] && [ "$BRANCH_NAME" != "main" ] && [ "$BRANCH_NAME" != "HEAD" ]; then
        # Extract keywords from branch name (split on -, filter short/stop words)
        BRANCH_KEYWORDS=$(echo "$BRANCH_NAME" | tr '-' '\n' | tr '_' '\n' | awk 'length > 3 && !/^(worktree|feat|fix|chore|docs|test|main|HEAD)$/' | head -3)
        if [ -n "$BRANCH_KEYWORDS" ]; then
            PLAN_MATCHES=""
            for kw in $BRANCH_KEYWORDS; do
                MATCH=$(grep -i "$kw" "$PLAN_INDEX" | head -1 | awk -F'|' '{gsub(/^ +| +$/, "", $3); print $3}')
                if [ -n "$MATCH" ] && [ -z "$(echo "$PLAN_MATCHES" | grep -F "$MATCH")" ]; then
                    PLAN_MATCHES="${PLAN_MATCHES}${MATCH}, "
                fi
            done
            PLAN_MATCHES="${PLAN_MATCHES%, }"
            if [ -n "$PLAN_MATCHES" ]; then
                CONTEXT_LINES="${CONTEXT_LINES}Related plans: $PLAN_MATCHES\n"
            fi
        fi
    fi
fi

# Recent memory file updates: last 3 modified memory files
MEMORY_PROJECT_DIR="$HOME/.claude/projects/$(echo "$PROJECT_ROOT" | sed 's|/|-|g')/memory"
if [ -d "$MEMORY_PROJECT_DIR" ]; then
    RECENT_MEMORY=$(ls -t "$MEMORY_PROJECT_DIR"/*.md 2>/dev/null | grep -v 'MEMORY.md' | head -3 | xargs -I{} basename {} .md | tr '\n' '|' | sed 's/|$//;s/|/, /g')
    if [ -n "$RECENT_MEMORY" ]; then
        CONTEXT_LINES="${CONTEXT_LINES}Recent memory: $RECENT_MEMORY\n"
    fi
fi

# Knowledge miss summary: count from last 7 days
if [ -d "$PROJECT_ROOT/.meta" ]; then
    KM_EVENTS="$PROJECT_ROOT/.meta/logs/events.jsonl"
else
    KM_EVENTS="$PROJECT_ROOT/.claude/logs/events.jsonl"
fi
if [ -f "$KM_EVENTS" ] && command -v jq &>/dev/null; then
    WEEK_AGO=$(date -u -v-7d +%Y-%m-%dT 2>/dev/null || date -u -d '7 days ago' +%Y-%m-%dT 2>/dev/null || echo "")
    if [ -n "$WEEK_AGO" ]; then
        KM_COUNT=$(jq --arg since "$WEEK_AGO" '[.[] | select(.event_type == "knowledge_miss" and .timestamp >= $since)] | length' "$KM_EVENTS" 2>/dev/null) || KM_COUNT=0
        if [ "$KM_COUNT" -gt 0 ]; then
            KM_TOP=$(jq -s --arg since "$WEEK_AGO" '[.[] | select(.event_type == "knowledge_miss" and .timestamp >= $since)] | group_by(.category) | sort_by(-length) | .[0][0].category' "$KM_EVENTS" 2>/dev/null | tr -d '"') || KM_TOP="unknown"
            CONTEXT_LINES="${CONTEXT_LINES}Knowledge misses (7d): $KM_COUNT (top: $KM_TOP)\n"
        fi
    fi
fi

# Last compaction summary: filename + age
LATEST_COMPACTION=$(ls -t "$COMPACTION_DIR"/compaction-summary-*.md 2>/dev/null | head -1)
if [ -n "$LATEST_COMPACTION" ]; then
    COMP_NAME=$(basename "$LATEST_COMPACTION" .md | sed 's/compaction-summary-//')
    COMP_MTIME=$(stat -f '%m' "$LATEST_COMPACTION" 2>/dev/null || stat -c '%Y' "$LATEST_COMPACTION" 2>/dev/null)
    if [ -n "$COMP_MTIME" ]; then
        COMP_AGE_DAYS=$(( ($(date +%s) - COMP_MTIME) / 86400 ))
        COMP_MSG="Last compaction: $COMP_NAME (${COMP_AGE_DAYS}d ago)"
        if [ "$COMP_AGE_DAYS" -gt 7 ]; then
            COMP_MSG="$COMP_MSG — stale, hook may have stopped firing"
        fi
        CONTEXT_LINES="${CONTEXT_LINES}${COMP_MSG}\n"
    fi
fi

# Pending actions count (non-auto-cleared entries)
if [ -f "$PENDING_FILE" ]; then
    PENDING_COUNT=$(grep -c '^- ' "$PENDING_FILE" 2>/dev/null) || PENDING_COUNT=0
    if [ "$PENDING_COUNT" -gt 0 ]; then
        CONTEXT_LINES="${CONTEXT_LINES}Pending actions: $PENDING_COUNT\n"
    fi
fi

# Output context block if anything was found
if [ -n "$CONTEXT_LINES" ]; then
    echo "--- Session Context ---" >&2
    printf "$CONTEXT_LINES" >&2
    echo "Use /recall <topic> to search accumulated knowledge." >&2
    echo "---" >&2
fi

# --- MEMORY.md auto-prune ---
# Remove sections tagged with <!-- prune --> markers from previous wrap-up
MEMORY_DIR="$HOME/.claude/projects/$(echo "$PROJECT_ROOT" | sed 's|/|-|g')/memory"
MEMORY_FILE="$MEMORY_DIR/MEMORY.md"
if [ -f "$MEMORY_FILE" ]; then
    if grep -q '<!-- prune -->' "$MEMORY_FILE"; then
        PRUNE_COUNT=$(grep -c '<!-- prune -->' "$MEMORY_FILE")
        # Remove sections: from <!-- prune --> through its ## header and content, stopping at next ## heading
        # Uses skip==0 instead of !skip for BSD awk (macOS) compatibility
        awk '/<!-- prune -->/{skip=1;seen_header=0;next} /^## /{if(skip){if(seen_header){skip=0;print;next}else{seen_header=1;next}}} skip==0' "$MEMORY_FILE" > "${MEMORY_FILE}.tmp"
        mv "${MEMORY_FILE}.tmp" "$MEMORY_FILE"
        echo "MEMORY: Auto-pruned $PRUNE_COUNT stale entries from MEMORY.md" >&2
    fi
    MEMORY_LINES=$(wc -l < "$MEMORY_FILE" | tr -d ' ')
    if [ "$MEMORY_LINES" -gt 100 ]; then
        echo "MEMORY: ${MEMORY_LINES}/200 lines (entries after 200 are truncated). Run /wrap-up to review." >&2
    fi
fi

# --- Reset Session Tracking ---
# Write to per-session state files (concurrent session support)
date +%s > "$SESSIONS_DIR/${SESSION_ID}.start"
rm -f "$SESSIONS_DIR/${SESSION_ID}.files"
rm -f "$SESSIONS_DIR/${SESSION_ID}.tool-calls"

# Also write legacy shared files for backward compat (wrap-up, tests)
date +%s > "$SESSION_DIR/.session-start"
rm -f "$SESSION_DIR/.session-files"

exit 0
