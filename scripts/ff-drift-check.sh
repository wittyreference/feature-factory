#!/bin/bash
# ABOUTME: Detects drift between upstream twilio-feature-factory and this generic feature-factory.
# ABOUTME: Reads ff-sync-map.json and reports which mapped source files changed since last sync.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SYNC_MAP="$PROJECT_ROOT/ff-sync-map.json"
SYNC_STATE="$PROJECT_ROOT/ff-sync-state.json"

# Require jq
if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required for drift detection" >&2
    exit 0
fi

# Require sync map
if [[ ! -f "$SYNC_MAP" ]]; then
    echo "ERROR: Sync map not found at $SYNC_MAP" >&2
    exit 0
fi

# Read source repo path
SOURCE_REPO=$(jq -r '.sourceRepo // empty' "$SYNC_MAP" 2>/dev/null)
if [[ -z "$SOURCE_REPO" ]]; then
    echo "ERROR: No sourceRepo defined in sync map" >&2
    exit 0
fi

# Resolve source repo path (relative to project root)
if [[ "$SOURCE_REPO" == ../* || "$SOURCE_REPO" == ./* ]]; then
    SOURCE_REPO="$PROJECT_ROOT/$SOURCE_REPO"
fi
SOURCE_REPO=$(cd "$SOURCE_REPO" 2>/dev/null && pwd -P || echo "")

if [[ -z "$SOURCE_REPO" || ! -d "$SOURCE_REPO/.git" ]]; then
    echo "ERROR: Source repo not found or not a git repo: $SOURCE_REPO" >&2
    exit 0
fi

# Read last sync commit
LAST_SYNC_COMMIT=""
if [[ -f "$SYNC_STATE" ]]; then
    LAST_SYNC_COMMIT=$(jq -r '.lastSyncCommit // empty' "$SYNC_STATE" 2>/dev/null)
fi

# Validate last sync commit exists in source repo
if [[ -n "$LAST_SYNC_COMMIT" ]]; then
    if ! git -C "$SOURCE_REPO" cat-file -t "$LAST_SYNC_COMMIT" &>/dev/null; then
        echo "WARNING: Last sync commit $LAST_SYNC_COMMIT not found in source repo" >&2
        LAST_SYNC_COMMIT=""
    fi
fi

# Extract all source paths from sync map (all categories)
SOURCE_PATHS=$(jq -r '.mappings | to_entries[] | .value[] | .source' "$SYNC_MAP" 2>/dev/null)

if [[ -z "$SOURCE_PATHS" ]]; then
    echo "No mappings found in sync map" >&2
    exit 0
fi

# Check which mapped files have changed since last sync
DRIFTED_FILES=()
DRIFTED_DETAILS=()

while IFS= read -r source_path; do
    [[ -z "$source_path" ]] && continue

    if [[ -n "$LAST_SYNC_COMMIT" ]]; then
        CHANGES=$(git -C "$SOURCE_REPO" log --oneline "${LAST_SYNC_COMMIT}..HEAD" -- "$source_path" 2>/dev/null | wc -l | tr -d ' ')
    else
        # No sync state — treat all existing mapped files as potentially drifted
        if [[ -f "$SOURCE_REPO/$source_path" ]]; then
            CHANGES=1
        else
            CHANGES=0
        fi
    fi

    if [[ "$CHANGES" -gt 0 ]]; then
        DRIFTED_FILES+=("$source_path")

        # Look up the target and adaptations for this file
        TARGET=$(jq -r --arg sp "$source_path" \
            '.mappings | to_entries[] | .value[] | select(.source == $sp) | .target' \
            "$SYNC_MAP" 2>/dev/null)
        ADAPTATIONS=$(jq -r --arg sp "$source_path" \
            '.mappings | to_entries[] | .value[] | select(.source == $sp) | .adaptations | join(", ")' \
            "$SYNC_MAP" 2>/dev/null)

        DRIFTED_DETAILS+=("$source_path -> $TARGET [$ADAPTATIONS] ($CHANGES commit(s))")
    fi
done <<< "$SOURCE_PATHS"

DRIFT_COUNT=${#DRIFTED_FILES[@]}

# Output mode
MODE="${1:---report}"

case "$MODE" in
    --count)
        echo "$DRIFT_COUNT"
        ;;
    --files)
        for f in "${DRIFTED_FILES[@]}"; do
            echo "$f"
        done
        ;;
    --report|*)
        if [[ "$DRIFT_COUNT" -eq 0 ]]; then
            echo "Feature Factory sync: No drift detected. Source and target are in sync."
        else
            echo ""
            echo "FEATURE FACTORY DRIFT REPORT"
            echo "============================"
            echo ""
            echo "$DRIFT_COUNT source file(s) changed since last sync"
            if [[ -n "$LAST_SYNC_COMMIT" ]]; then
                LAST_SYNC_DATE=$(jq -r '.lastSyncTimestamp // "unknown"' "$SYNC_STATE" 2>/dev/null)
                echo "Last sync: $LAST_SYNC_DATE (${LAST_SYNC_COMMIT:0:7})"
            else
                echo "Last sync: never (no sync state found)"
            fi
            echo "Source: $SOURCE_REPO"
            echo ""
            echo "Drifted files:"
            for detail in "${DRIFTED_DETAILS[@]}"; do
                echo "  - $detail"
            done
            echo ""
            echo "Run /ff-sync to review and apply changes."
        fi
        ;;
esac

exit 0
