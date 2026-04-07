#!/bin/bash
# ABOUTME: Bootstraps Feature Factory into an existing or new project.
# ABOUTME: Copies hooks, commands, skills, settings, and config into the target directory.

set -euo pipefail

# ============================================
# CONFIGURATION
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FF_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="0.1.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# USAGE
# ============================================

usage() {
    cat <<EOF
Feature Factory v${VERSION} - Self-documenting, TDD-enforcing development toolkit

Usage:
  $(basename "$0") [TARGET_DIR] [OPTIONS]

Arguments:
  TARGET_DIR    Directory to install into (default: current directory)

Options:
  --overlay DIR    Apply a platform overlay after base install
  --force          Overwrite existing files without prompting
  --no-meta        Skip creating .meta/ directory
  --dry-run        Show what would be done without doing it
  --help           Show this help message

Examples:
  # Install into current project
  $(basename "$0") .

  # Install into a specific project
  $(basename "$0") ~/my-project

  # Install with a platform overlay
  $(basename "$0") ~/my-project --overlay ~/my-platform-overlay

  # Preview what would be installed
  $(basename "$0") . --dry-run
EOF
    exit 0
}

# ============================================
# ARGUMENT PARSING
# ============================================

TARGET_DIR="."
OVERLAY_DIR=""
FORCE=false
NO_META=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --overlay)
            OVERLAY_DIR="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --no-meta)
            NO_META=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}" >&2
            usage
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

# Resolve absolute path
TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd || echo "$TARGET_DIR")"

# ============================================
# PREREQUISITES CHECK
# ============================================

echo -e "${BLUE}Feature Factory v${VERSION}${NC}"
echo ""

check_prereq() {
    local cmd="$1"
    local name="$2"
    local required="$3"
    if command -v "$cmd" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $name"
        return 0
    else
        if [ "$required" = "required" ]; then
            echo -e "  ${RED}✗${NC} $name (required)"
            return 1
        else
            echo -e "  ${YELLOW}?${NC} $name (optional)"
            return 0
        fi
    fi
}

echo "Checking prerequisites..."
PREREQS_OK=true
check_prereq git "git" required || PREREQS_OK=false
check_prereq jq "jq (for config-driven hooks)" required || PREREQS_OK=false
check_prereq node "Node.js" optional
check_prereq python3 "Python 3" optional
check_prereq go "Go" optional
echo ""

if [ "$PREREQS_OK" = false ]; then
    echo -e "${RED}Missing required prerequisites. Install them and try again.${NC}"
    exit 1
fi

# ============================================
# PROJECT DETECTION
# ============================================

echo "Detecting project type..."

detect_language() {
    if [ -f "$TARGET_DIR/package.json" ]; then
        echo "javascript"
    elif [ -f "$TARGET_DIR/pyproject.toml" ] || [ -f "$TARGET_DIR/setup.py" ] || [ -f "$TARGET_DIR/requirements.txt" ]; then
        echo "python"
    elif [ -f "$TARGET_DIR/go.mod" ]; then
        echo "go"
    elif [ -f "$TARGET_DIR/Cargo.toml" ]; then
        echo "rust"
    elif [ -f "$TARGET_DIR/pom.xml" ] || [ -f "$TARGET_DIR/build.gradle" ]; then
        echo "java"
    elif [ -f "$TARGET_DIR/Gemfile" ]; then
        echo "ruby"
    elif [ -f "$TARGET_DIR/composer.json" ]; then
        echo "php"
    else
        echo "unknown"
    fi
}

detect_test_command() {
    local lang="$1"
    case "$lang" in
        javascript)
            if [ -f "$TARGET_DIR/package.json" ]; then
                # Check for test script in package.json
                local test_script
                test_script=$(jq -r '.scripts.test // empty' "$TARGET_DIR/package.json" 2>/dev/null)
                if [ -n "$test_script" ] && [ "$test_script" != "echo \"Error: no test specified\" && exit 1" ]; then
                    echo "npm test"
                    return
                fi
            fi
            echo "npm test"
            ;;
        python) echo "pytest" ;;
        go) echo "go test ./..." ;;
        rust) echo "cargo test" ;;
        java) echo "./gradlew test" ;;
        ruby) echo "bundle exec rspec" ;;
        php) echo "vendor/bin/phpunit" ;;
        *) echo "" ;;
    esac
}

detect_lint_command() {
    local lang="$1"
    case "$lang" in
        javascript)
            if [ -f "$TARGET_DIR/package.json" ]; then
                local lint_script
                lint_script=$(jq -r '.scripts.lint // empty' "$TARGET_DIR/package.json" 2>/dev/null)
                if [ -n "$lint_script" ]; then
                    echo "npm run lint"
                    return
                fi
            fi
            echo ""
            ;;
        python) echo "ruff check ." ;;
        go) echo "golangci-lint run" ;;
        rust) echo "cargo clippy" ;;
        *) echo "" ;;
    esac
}

detect_lint_fix_command() {
    local lang="$1"
    case "$lang" in
        javascript)
            if [ -f "$TARGET_DIR/package.json" ]; then
                local fix_script
                fix_script=$(jq -r '.scripts["lint:fix"] // empty' "$TARGET_DIR/package.json" 2>/dev/null)
                if [ -n "$fix_script" ]; then
                    echo "npm run lint:fix"
                    return
                fi
            fi
            echo ""
            ;;
        python) echo "ruff check --fix ." ;;
        go) echo "" ;;
        rust) echo "cargo clippy --fix" ;;
        *) echo "" ;;
    esac
}

detect_coverage_command() {
    local lang="$1"
    case "$lang" in
        javascript)
            if [ -f "$TARGET_DIR/package.json" ]; then
                local cov_script
                cov_script=$(jq -r '.scripts["test:coverage"] // empty' "$TARGET_DIR/package.json" 2>/dev/null)
                if [ -n "$cov_script" ]; then
                    echo "npm run test:coverage"
                    return
                fi
            fi
            echo ""
            ;;
        python) echo "pytest --cov" ;;
        go) echo "go test -cover ./..." ;;
        rust) echo "" ;;
        *) echo "" ;;
    esac
}

detect_source_dirs() {
    local lang="$1"
    local dirs=""
    case "$lang" in
        javascript)
            [ -d "$TARGET_DIR/src" ] && dirs="src/"
            [ -d "$TARGET_DIR/lib" ] && dirs="$dirs lib/"
            [ -d "$TARGET_DIR/app" ] && dirs="$dirs app/"
            ;;
        python)
            [ -d "$TARGET_DIR/src" ] && dirs="src/"
            # Check for package directory matching project name
            local proj_name
            proj_name=$(basename "$TARGET_DIR")
            [ -d "$TARGET_DIR/$proj_name" ] && dirs="$dirs $proj_name/"
            ;;
        go)
            [ -d "$TARGET_DIR/cmd" ] && dirs="cmd/"
            [ -d "$TARGET_DIR/internal" ] && dirs="$dirs internal/"
            [ -d "$TARGET_DIR/pkg" ] && dirs="$dirs pkg/"
            # Also include root if .go files exist there (e.g., gin has both internal/ and root .go files)
            if ls "$TARGET_DIR"/*.go &>/dev/null; then
                dirs="$dirs ./"
            fi
            # Fallback: if nothing found at all, default will kick in below
            ;;
        rust)
            if [ -f "$TARGET_DIR/Cargo.toml" ] && grep -q '\[workspace\]' "$TARGET_DIR/Cargo.toml"; then
                # Extract workspace member directories from Cargo.toml
                members=$(sed -n '/^members/,/\]/p' "$TARGET_DIR/Cargo.toml" | grep -o '"[^"]*"' | tr -d '"' | head -10)
                for m in $members; do
                    [ -d "$TARGET_DIR/$m" ] && dirs="$dirs $m/"
                done
            fi
            # Default to src/ if nothing found
            dirs=$(echo "$dirs" | xargs)
            [ -z "$dirs" ] && dirs="src/"
            ;;
        *)
            [ -d "$TARGET_DIR/src" ] && dirs="src/"
            [ -d "$TARGET_DIR/lib" ] && dirs="$dirs lib/"
            ;;
    esac
    # Trim and default
    dirs=$(echo "$dirs" | xargs)
    [ -z "$dirs" ] && dirs="src/"
    echo "$dirs"
}

detect_test_dirs() {
    local lang="$1"
    local dirs=""
    case "$lang" in
        javascript)
            [ -d "$TARGET_DIR/__tests__" ] && dirs="__tests__/"
            [ -d "$TARGET_DIR/test" ] && dirs="$dirs test/"
            [ -d "$TARGET_DIR/tests" ] && dirs="$dirs tests/"
            ;;
        python)
            [ -d "$TARGET_DIR/tests" ] && dirs="tests/"
            [ -d "$TARGET_DIR/test" ] && dirs="$dirs test/"
            ;;
        go)
            # Go tests are alongside source
            dirs=""
            ;;
        rust)
            [ -d "$TARGET_DIR/tests" ] && dirs="tests/"
            ;;
        *)
            [ -d "$TARGET_DIR/test" ] && dirs="test/"
            [ -d "$TARGET_DIR/tests" ] && dirs="$dirs tests/"
            [ -d "$TARGET_DIR/__tests__" ] && dirs="$dirs __tests__/"
            ;;
    esac
    dirs=$(echo "$dirs" | xargs)
    echo "$dirs"
}

detect_test_file_patterns() {
    local lang="$1"
    case "$lang" in
        javascript) echo '["**/*.test.*", "**/*.spec.*", "__tests__/**", "tests/**"]' ;;
        python) echo '["**/test_*.py", "**/*_test.py", "tests/**", "test/**"]' ;;
        go) echo '["**/*_test.go"]' ;;
        rust) echo '["**/tests/**", "**/*_test.rs"]' ;;
        java) echo '["**/*Test.java", "**/*Spec.java", "**/test/**"]' ;;
        ruby) echo '["**/*_test.rb", "**/*_spec.rb", "test/**", "spec/**"]' ;;
        *) echo '["**/*.test.*", "**/*.spec.*", "**/*_test.*", "tests/**", "__tests__/**"]' ;;
    esac
}

detect_file_extensions() {
    local lang="$1"
    case "$lang" in
        javascript) echo '[".js", ".ts", ".mjs", ".cjs"]' ;;
        python) echo '[".py"]' ;;
        go) echo '[".go"]' ;;
        rust) echo '[".rs"]' ;;
        java) echo '[".java", ".kt"]' ;;
        ruby) echo '[".rb"]' ;;
        php) echo '[".php"]' ;;
        *) echo '[".js", ".ts", ".py", ".go", ".rs"]' ;;
    esac
}

detect_comment_syntax() {
    local lang="$1"
    case "$lang" in
        javascript|go|rust|java|php) echo "//" ;;
        python|ruby) echo "#" ;;
        *) echo "//" ;;
    esac
}

LANG=$(detect_language)
echo -e "  Language: ${GREEN}$LANG${NC}"

TEST_CMD=$(detect_test_command "$LANG")
LINT_CMD=$(detect_lint_command "$LANG")
LINT_FIX_CMD=$(detect_lint_fix_command "$LANG")
COVERAGE_CMD=$(detect_coverage_command "$LANG")
SOURCE_DIRS=$(detect_source_dirs "$LANG")
TEST_FILE_PATTERNS=$(detect_test_file_patterns "$LANG")
TEST_DIRS=$(detect_test_dirs "$LANG")
FILE_EXTS=$(detect_file_extensions "$LANG")
COMMENT_SYN=$(detect_comment_syntax "$LANG")

echo -e "  Test command: ${GREEN}${TEST_CMD:-none detected}${NC}"
echo -e "  Lint command: ${GREEN}${LINT_CMD:-none detected}${NC}"
echo -e "  Source dirs: ${GREEN}${SOURCE_DIRS}${NC}"
echo ""

# ============================================
# HELPER FUNCTIONS
# ============================================

copy_file() {
    local src="$1"
    local dst="$2"

    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${BLUE}[dry-run]${NC} Would copy: $dst"
        return
    fi

    # Check if destination exists
    if [ -f "$dst" ] && [ "$FORCE" = false ]; then
        echo -e "  ${YELLOW}skip${NC} $dst (already exists, use --force to overwrite)"
        return
    fi

    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo -e "  ${GREEN}✓${NC} $dst"
}

copy_dir() {
    local src="$1"
    local dst="$2"
    local count=0

    if [ ! -d "$src" ]; then
        echo -e "  ${RED}✗${NC} Source directory not found: $src"
        return
    fi

    for file in "$src"/*; do
        [ -f "$file" ] || continue
        local filename=$(basename "$file")
        copy_file "$file" "$dst/$filename"
        count=$((count + 1))
    done

    # Handle executable scripts
    if [ "$DRY_RUN" = false ]; then
        chmod +x "$dst"/*.sh 2>/dev/null || true
    fi
}

# ============================================
# INSTALL
# ============================================

echo "Installing Feature Factory into: $TARGET_DIR"
echo ""

# --- Hooks ---
echo "Installing hooks..."
copy_dir "$FF_ROOT/.claude/hooks" "$TARGET_DIR/.claude/hooks"

# Also copy the __tests__ directory if it exists
if [ -d "$FF_ROOT/.claude/hooks/__tests__" ]; then
    copy_dir "$FF_ROOT/.claude/hooks/__tests__" "$TARGET_DIR/.claude/hooks/__tests__"
fi
echo ""

# --- Commands ---
echo "Installing commands..."
# Commands that are maintainer-only and should not be copied to adopter projects
SKIP_COMMANDS=("ff-sync.md")
for file in "$FF_ROOT/.claude/commands"/*; do
    [ -f "$file" ] || continue
    filename=$(basename "$file")
    skip=false
    for s in "${SKIP_COMMANDS[@]}"; do
        if [ "$filename" = "$s" ]; then
            skip=true
            break
        fi
    done
    if [ "$skip" = true ]; then
        echo -e "  ${YELLOW}skip${NC} $filename (maintainer-only)"
        continue
    fi
    copy_file "$file" "$TARGET_DIR/.claude/commands/$filename"
done
echo ""

# --- Rules ---
if [ -d "$FF_ROOT/.claude/rules" ]; then
    echo "Installing rules..."
    copy_dir "$FF_ROOT/.claude/rules" "$TARGET_DIR/.claude/rules"
    echo ""
fi

# --- Skills ---
echo "Installing skills..."
copy_dir "$FF_ROOT/.claude/skills" "$TARGET_DIR/.claude/skills"
echo ""

# --- References ---
echo "Installing references..."
copy_dir "$FF_ROOT/.claude/references" "$TARGET_DIR/.claude/references"
echo ""

# --- Settings ---
echo "Installing settings..."
copy_file "$FF_ROOT/.claude/settings.json" "$TARGET_DIR/.claude/settings.json"
echo ""

# --- Generate ff.config.json ---
echo "Generating ff.config.json..."

# Build tracked directories array (source + test dirs)
TRACKED_JSON="["
first=true
for dir in $SOURCE_DIRS $TEST_DIRS; do
    if [ "$first" = true ]; then
        first=false
    else
        TRACKED_JSON="$TRACKED_JSON, "
    fi
    TRACKED_JSON="$TRACKED_JSON\"$dir\""
done
TRACKED_JSON="$TRACKED_JSON]"

# Build source directories array
SOURCE_JSON="["
first=true
for dir in $SOURCE_DIRS; do
    if [ "$first" = true ]; then
        first=false
    else
        SOURCE_JSON="$SOURCE_JSON, "
    fi
    SOURCE_JSON="$SOURCE_JSON\"$dir\""
done
SOURCE_JSON="$SOURCE_JSON]"

# Build doc mappings from source directories
DOC_MAPPINGS="{"
first=true
for dir in $SOURCE_DIRS; do
    if [ "$first" = true ]; then
        first=false
    else
        DOC_MAPPINGS="$DOC_MAPPINGS, "
    fi
    DOC_MAPPINGS="$DOC_MAPPINGS\"$dir\": \"CLAUDE.md\""
done
DOC_MAPPINGS="$DOC_MAPPINGS, \".claude/hooks/\": \"CLAUDE.md\""
DOC_MAPPINGS="$DOC_MAPPINGS}"

PROJECT_NAME=$(basename "$TARGET_DIR")
CONFIG_FILE="$TARGET_DIR/ff.config.json"

if [ "$DRY_RUN" = true ]; then
    echo -e "  ${BLUE}[dry-run]${NC} Would generate: ff.config.json"
elif [ -f "$CONFIG_FILE" ] && [ "$FORCE" = false ]; then
    echo -e "  ${YELLOW}skip${NC} ff.config.json (already exists, use --force to overwrite)"
else
    cat > "$CONFIG_FILE" <<CONFIGEOF
{
  "project": {
    "name": "$PROJECT_NAME",
    "language": "$LANG",
    "sourceDirectories": $SOURCE_JSON
  },
  "testing": {
    "command": "$TEST_CMD",
    "coverageCommand": "$COVERAGE_CMD",
    "coverageThreshold": 80,
    "testFilePatterns": $TEST_FILE_PATTERNS
  },
  "linting": {
    "command": "$LINT_CMD",
    "fixCommand": "$LINT_FIX_CMD"
  },
  "deployment": {
    "command": null,
    "preChecks": ["test", "lint", "coverage"]
  },
  "credentialPatterns": [
    {
      "pattern": "(?:password|passwd|pwd)\\\\s*[:=]\\\\s*[\"'][^\"']{8,}[\"']",
      "name": "Hardcoded password",
      "excludePattern": "(process\\\\.env|os\\\\.environ|env\\\\.|getenv)"
    },
    {
      "pattern": "(?:api[_-]?key|apikey)\\\\s*[:=]\\\\s*[\"'][^\"']{16,}[\"']",
      "name": "API key",
      "excludePattern": "(process\\\\.env|os\\\\.environ|env\\\\.|getenv)"
    },
    {
      "pattern": "(?:secret|token)\\\\s*[:=]\\\\s*[\"'][a-zA-Z0-9+/=]{20,}[\"']",
      "name": "Secret or token",
      "excludePattern": "(process\\\\.env|os\\\\.environ|env\\\\.|getenv)"
    },
    {
      "pattern": "AKIA[0-9A-Z]{16}",
      "name": "AWS Access Key ID",
      "excludePattern": "(process\\\\.env|os\\\\.environ|env\\\\.|getenv)"
    },
    {
      "pattern": "sk-[a-zA-Z0-9]{20,}",
      "name": "OpenAI/Anthropic API key",
      "excludePattern": "(process\\\\.env|os\\\\.environ|env\\\\.|getenv)"
    }
  ],
  "fileHeaders": {
    "enabled": true,
    "pattern": "ABOUTME:",
    "requiredLines": 2,
    "fileExtensions": $FILE_EXTS,
    "sourceOnly": true
  },
  "docMappings": $DOC_MAPPINGS,
  "requiredEnvVars": [],
  "trackedDirectories": $TRACKED_JSON
}
CONFIGEOF
    echo -e "  ${GREEN}✓${NC} ff.config.json (configured for $LANG)"
fi
echo ""

# --- CLAUDE.md ---
echo "Installing CLAUDE.md..."
if [ -f "$TARGET_DIR/CLAUDE.md" ] && [ "$FORCE" = false ]; then
    # Append Feature Factory section to existing CLAUDE.md
    if ! grep -q "Feature Factory" "$TARGET_DIR/CLAUDE.md" 2>/dev/null; then
        if [ "$DRY_RUN" = false ]; then
            echo "" >> "$TARGET_DIR/CLAUDE.md"
            echo "---" >> "$TARGET_DIR/CLAUDE.md"
            echo "" >> "$TARGET_DIR/CLAUDE.md"
            echo "## Feature Factory" >> "$TARGET_DIR/CLAUDE.md"
            echo "" >> "$TARGET_DIR/CLAUDE.md"
            echo "This project uses Feature Factory for self-documenting, TDD-enforcing development. See \`ff.config.json\` for configuration." >> "$TARGET_DIR/CLAUDE.md"
            echo "" >> "$TARGET_DIR/CLAUDE.md"
            echo "### Slash Commands" >> "$TARGET_DIR/CLAUDE.md"
            echo "" >> "$TARGET_DIR/CLAUDE.md"
            echo "| Command | Description |" >> "$TARGET_DIR/CLAUDE.md"
            echo "|---------|-------------|" >> "$TARGET_DIR/CLAUDE.md"
            echo "| \`/architect\` | Design review, pattern selection |" >> "$TARGET_DIR/CLAUDE.md"
            echo "| \`/spec\` | Technical specification writer |" >> "$TARGET_DIR/CLAUDE.md"
            echo "| \`/test-gen\` | TDD Red Phase - failing tests first |" >> "$TARGET_DIR/CLAUDE.md"
            echo "| \`/dev\` | TDD Green Phase - implement to pass |" >> "$TARGET_DIR/CLAUDE.md"
            echo "| \`/review\` | Code review with security audit |" >> "$TARGET_DIR/CLAUDE.md"
            echo "| \`/test\` | Run and validate test suites |" >> "$TARGET_DIR/CLAUDE.md"
            echo "| \`/docs\` | Documentation updates |" >> "$TARGET_DIR/CLAUDE.md"
            echo "| \`/commit\` | Git commit with validation |" >> "$TARGET_DIR/CLAUDE.md"
            echo "| \`/architect\` | Pipeline entry point — design review, then follow phases |" >> "$TARGET_DIR/CLAUDE.md"
            echo "| \`/team\` | Parallel multi-agent workflows |" >> "$TARGET_DIR/CLAUDE.md"
            echo "| \`/learn\` | Learning exercises from autonomous work |" >> "$TARGET_DIR/CLAUDE.md"
            echo -e "  ${GREEN}✓${NC} CLAUDE.md (appended Feature Factory section)"
        else
            echo -e "  ${BLUE}[dry-run]${NC} Would append Feature Factory section to existing CLAUDE.md"
        fi
    else
        echo -e "  ${YELLOW}skip${NC} CLAUDE.md (Feature Factory section already present)"
    fi
else
    copy_file "$FF_ROOT/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
fi
echo ""

# --- DESIGN_DECISIONS.md ---
echo "Installing DESIGN_DECISIONS.md..."
if [ ! -f "$TARGET_DIR/DESIGN_DECISIONS.md" ]; then
    copy_file "$FF_ROOT/DESIGN_DECISIONS.md" "$TARGET_DIR/DESIGN_DECISIONS.md"
else
    echo -e "  ${YELLOW}skip${NC} DESIGN_DECISIONS.md (already exists)"
fi
echo ""

# --- .meta/ directory ---
if [ "$NO_META" = false ]; then
    echo "Creating .meta/ directory..."
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$TARGET_DIR/.meta/plans" "$TARGET_DIR/.meta/logs" "$TARGET_DIR/.meta/learning"

        # Create initial meta files if they don't exist
        if [ ! -f "$TARGET_DIR/.meta/CLAUDE.md" ]; then
            copy_file "$FF_ROOT/.meta/CLAUDE.md" "$TARGET_DIR/.meta/CLAUDE.md"
        fi

        if [ ! -f "$TARGET_DIR/.meta/learnings.md" ]; then
            cat > "$TARGET_DIR/.meta/learnings.md" <<'LEARNEOF'
# Session Learnings

Capture discoveries during work sessions. Promote stable learnings to permanent docs, then clear.

---

LEARNEOF
            echo -e "  ${GREEN}✓${NC} .meta/learnings.md"
        fi

        if [ ! -f "$TARGET_DIR/.meta/pending-actions.md" ]; then
            cat > "$TARGET_DIR/.meta/pending-actions.md" <<'PENDEOF'
# Pending Documentation Actions

Actions detected by the documentation flywheel. Review before committing.

---

PENDEOF
            echo -e "  ${GREEN}✓${NC} .meta/pending-actions.md"
        fi

        if [ ! -f "$TARGET_DIR/.meta/todo.md" ]; then
            cat > "$TARGET_DIR/.meta/todo.md" <<'TODOEOF'
# Project Todo

## In Progress

## Planned

## Completed

TODOEOF
            echo -e "  ${GREEN}✓${NC} .meta/todo.md"
        fi
    else
        echo -e "  ${BLUE}[dry-run]${NC} Would create .meta/ directory structure"
    fi
    echo ""
fi

# --- Update .gitignore ---
echo "Updating .gitignore..."
if [ "$DRY_RUN" = false ]; then
    GITIGNORE="$TARGET_DIR/.gitignore"
    touch "$GITIGNORE"

    ENTRIES_TO_ADD=(
        ".meta/"
        ".claude/logs/"
        ".claude/.session-*"
        ".claude/.last-doc-check"
        ".claude/.compact-pending"
    )

    ADDED=0
    for entry in "${ENTRIES_TO_ADD[@]}"; do
        if ! grep -qF "$entry" "$GITIGNORE" 2>/dev/null; then
            echo "$entry" >> "$GITIGNORE"
            ADDED=$((ADDED + 1))
        fi
    done

    if [ "$ADDED" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} Added $ADDED entries to .gitignore"
    else
        echo -e "  ${YELLOW}skip${NC} .gitignore (entries already present)"
    fi
else
    echo -e "  ${BLUE}[dry-run]${NC} Would update .gitignore"
fi
echo ""

# --- Apply overlay ---
if [ -n "$OVERLAY_DIR" ]; then
    echo "Applying platform overlay from: $OVERLAY_DIR"

    if [ ! -d "$OVERLAY_DIR" ]; then
        echo -e "  ${RED}✗${NC} Overlay directory not found: $OVERLAY_DIR"
    else
        # Copy overlay commands (replace or add)
        if [ -d "$OVERLAY_DIR/commands" ]; then
            echo "  Overlay commands..."
            copy_dir "$OVERLAY_DIR/commands" "$TARGET_DIR/.claude/commands"
        fi

        # Copy overlay skills (replace or add)
        if [ -d "$OVERLAY_DIR/skills" ]; then
            echo "  Overlay skills..."
            copy_dir "$OVERLAY_DIR/skills" "$TARGET_DIR/.claude/skills"
        fi

        # Copy overlay references (replace or add)
        if [ -d "$OVERLAY_DIR/references" ]; then
            echo "  Overlay references..."
            copy_dir "$OVERLAY_DIR/references" "$TARGET_DIR/.claude/references"
        fi

        # Deep-merge overlay config if present
        if [ -f "$OVERLAY_DIR/ff.config.overlay.json" ] && command -v jq &>/dev/null; then
            echo "  Merging overlay config..."
            if [ "$DRY_RUN" = false ] && [ -f "$TARGET_DIR/ff.config.json" ]; then
                MERGED=$(jq -s '.[0] * .[1]' "$TARGET_DIR/ff.config.json" "$OVERLAY_DIR/ff.config.overlay.json")
                echo "$MERGED" > "$TARGET_DIR/ff.config.json"
                echo -e "  ${GREEN}✓${NC} ff.config.json (merged with overlay)"
            fi
        fi

        # Copy domain docs (recursive, preserving directory structure)
        if [ -d "$OVERLAY_DIR/domain-docs" ]; then
            echo "  Installing domain documentation..."
            DOC_COUNT=0
            while IFS= read -r doc_file; do
                [ -z "$doc_file" ] && continue
                # Strip the domain-docs/ prefix to get the relative target path
                REL_PATH="${doc_file#$OVERLAY_DIR/domain-docs/}"
                copy_file "$doc_file" "$TARGET_DIR/$REL_PATH"
                DOC_COUNT=$((DOC_COUNT + 1))
            done < <(find "$OVERLAY_DIR/domain-docs" -type f -name "*.md" 2>/dev/null)
            if [ "$DOC_COUNT" -gt 0 ]; then
                echo -e "  ${GREEN}✓${NC} $DOC_COUNT domain doc(s) installed"
            fi
        fi

        # Append overlay CLAUDE.md section (idempotent — checks for marker before appending)
        if [ -f "$OVERLAY_DIR/claude-md-section.md" ]; then
            echo "  Appending platform section to CLAUDE.md..."
            # Extract first heading from the section file for idempotency check
            SECTION_MARKER=$(grep -m1 '^#' "$OVERLAY_DIR/claude-md-section.md" 2>/dev/null || echo "")
            if [ "$DRY_RUN" = false ]; then
                if [ -n "$SECTION_MARKER" ] && grep -qF "$SECTION_MARKER" "$TARGET_DIR/CLAUDE.md" 2>/dev/null; then
                    echo -e "  ${YELLOW}skip${NC} CLAUDE.md (platform section already present)"
                else
                    echo "" >> "$TARGET_DIR/CLAUDE.md"
                    cat "$OVERLAY_DIR/claude-md-section.md" >> "$TARGET_DIR/CLAUDE.md"
                    echo -e "  ${GREEN}✓${NC} CLAUDE.md (platform section appended)"
                fi
            else
                echo -e "  ${BLUE}[dry-run]${NC} Would append platform section to CLAUDE.md"
            fi
        fi
    fi
    echo ""
fi

# ============================================
# SUMMARY
# ============================================

echo -e "${GREEN}Feature Factory installed successfully!${NC}"
echo ""
echo "What was installed:"
echo "  .claude/hooks/     - Event-driven quality gate hooks"
echo "  .claude/commands/  - Slash commands (/architect, /dev, /test-gen, etc.)"
echo "  .claude/skills/    - Knowledge documents (TDD, context, patterns)"
echo "  .claude/settings.json - Hook registrations"
echo "  ff.config.json     - Project configuration (edit this!)"
echo "  CLAUDE.md          - Root documentation"
if [ "$NO_META" = false ]; then
echo "  .meta/             - Meta-development state (gitignored)"
fi
if [ -n "$OVERLAY_DIR" ] && [ -d "$OVERLAY_DIR" ]; then
echo ""
echo "Overlay applied from: $OVERLAY_DIR"
[ -d "$OVERLAY_DIR/commands" ] && echo "  + Platform commands"
[ -d "$OVERLAY_DIR/skills" ] && echo "  + Platform skills"
[ -d "$OVERLAY_DIR/references" ] && echo "  + Platform references"
[ -d "$OVERLAY_DIR/domain-docs" ] && echo "  + Domain documentation"
[ -f "$OVERLAY_DIR/ff.config.overlay.json" ] && echo "  + Config merged (credential patterns, env vars, deploy command)"
[ -f "$OVERLAY_DIR/claude-md-section.md" ] && echo "  + CLAUDE.md platform section"
fi
echo ""
echo "Next steps:"
echo "  1. Review and customize ff.config.json for your project"
echo "  2. Start a Claude Code session in your project directory"
echo "  3. Try: /architect, /test-gen, /dev, /review, /commit"
echo ""
echo "Configuration tips:"
echo "  - Set deployment.command in ff.config.json to enable deploy validation"
echo "  - Add requiredEnvVars for session-start checks"
echo "  - Customize docMappings for your documentation structure"
echo "  - Add platform-specific credentialPatterns as needed"
