#!/bin/bash
# ABOUTME: Shared configuration reader for Feature Factory hooks.
# ABOUTME: Provides ff_config() and ff_config_array() to read ff.config.json via jq.

# Get project root (caller can override if already set)
export PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# Config file path
FF_CONFIG="$PROJECT_ROOT/ff.config.json"

# Read a single value from ff.config.json
# Usage: ff_config ".testing.command" "npm test"
#   $1 = jq path (e.g., ".testing.command")
#   $2 = default value if key missing or file not found
ff_config() {
    local key="$1"
    local default="$2"
    if [ -f "$FF_CONFIG" ] && command -v jq &>/dev/null; then
        local result
        result=$(jq -r "$key // empty" "$FF_CONFIG" 2>/dev/null)
        if [ -n "$result" ] && [ "$result" != "null" ]; then
            echo "$result"
        else
            echo "$default"
        fi
    else
        echo "$default"
    fi
}

# Read an array from ff.config.json, one element per line
# Usage: ff_config_array ".project.sourceDirectories"
ff_config_array() {
    local key="$1"
    if [ -f "$FF_CONFIG" ] && command -v jq &>/dev/null; then
        jq -r "$key[]? // empty" "$FF_CONFIG" 2>/dev/null
    fi
}

# Read credential patterns as tab-separated: pattern\tname\texcludePattern
# Usage: while IFS=$'\t' read -r pattern name exclude; do ... done < <(ff_credential_patterns)
ff_credential_patterns() {
    if [ -f "$FF_CONFIG" ] && command -v jq &>/dev/null; then
        jq -r '.credentialPatterns[]? | [.pattern, .name, (.excludePattern // "")] | join("\t")' "$FF_CONFIG" 2>/dev/null
    fi
}

# Read doc mappings as tab-separated: sourcePattern\tdocTarget
# Usage: while IFS=$'\t' read -r source doc; do ... done < <(ff_doc_mappings)
ff_doc_mappings() {
    if [ -f "$FF_CONFIG" ] && command -v jq &>/dev/null; then
        jq -r '.docMappings | to_entries[]? | [.key, .value] | join("\t")' "$FF_CONFIG" 2>/dev/null
    fi
}

# Check if a file path matches any tracked directory
# Usage: if ff_is_tracked_file "src/main.js"; then ...
ff_is_tracked_file() {
    local filepath="$1"
    # Normalize: strip leading ./ for consistent prefix matching
    filepath="${filepath#./}"
    local tracked_dirs
    tracked_dirs=$(ff_config_array ".trackedDirectories")
    if [ -z "$tracked_dirs" ]; then
        # No tracked directories configured, track everything
        return 0
    fi
    while IFS= read -r dir; do
        # Normalize: strip leading ./ and treat empty/. as root (match all)
        dir="${dir#./}"
        if [ -z "$dir" ] || [ "$dir" = "." ]; then
            return 0
        fi
        if [[ "$filepath" == "$dir"* ]]; then
            return 0
        fi
    done <<< "$tracked_dirs"
    return 1
}

# Check if a file should have ABOUTME headers based on config
# Usage: if ff_requires_header "src/main.js"; then ...
ff_requires_header() {
    local filepath="$1"
    local enabled
    enabled=$(ff_config ".fileHeaders.enabled" "true")
    if [ "$enabled" != "true" ]; then
        return 1
    fi

    local source_only
    source_only=$(ff_config ".fileHeaders.sourceOnly" "true")
    if [ "$source_only" = "true" ]; then
        if ! ff_is_tracked_file "$filepath"; then
            return 1
        fi
    fi

    # Check file extension
    local ext="${filepath##*.}"
    local extensions
    extensions=$(ff_config_array ".fileHeaders.fileExtensions")
    if [ -z "$extensions" ]; then
        return 1
    fi
    while IFS= read -r expected_ext; do
        # Strip leading dot for comparison
        expected_ext="${expected_ext#.}"
        if [ "$ext" = "$expected_ext" ]; then
            return 0
        fi
    done <<< "$extensions"
    return 1
}
