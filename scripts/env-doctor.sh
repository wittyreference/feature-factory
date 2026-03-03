#!/usr/bin/env bash
# ABOUTME: Config-driven environment diagnostic that detects shell vs .env conflicts.
# ABOUTME: Reads variable names from ff.config.json. Run after cloning to catch auth failures.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_DIR/.env"
CONFIG_FILE="$PROJECT_DIR/ff.config.json"

PASS=0
FAIL=0
WARN=0

check() {
    local name="$1"
    local result="$2"  # 0=pass, 1=fail, 2=warn
    local msg="${3:-}"

    if [ "$result" -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} $name"
        PASS=$((PASS + 1))
    elif [ "$result" -eq 2 ]; then
        echo -e "  ${YELLOW}⚠${NC} $name — $msg"
        WARN=$((WARN + 1))
    else
        echo -e "  ${RED}✗${NC} $name — $msg"
        FAIL=$((FAIL + 1))
    fi
}

# Read a value from the .env file (ignores comments and blank lines)
# Always returns exit 0 — outputs empty string if key not found.
env_file_value() {
    local key="$1"
    local val
    val=$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | head -1 | sed "s/^${key}=//" | sed 's/^"//' | sed 's/"$//' | sed "s/^'//" | sed "s/'$//") || true
    echo "$val"
}

# Mask a value for display (first 6, last 4)
mask() {
    local val="$1"
    local len=${#val}
    if [ "$len" -gt 10 ]; then
        echo "${val:0:6}...${val: -4}"
    else
        echo "$val"
    fi
}

# Read arrays from ff.config.json
config_array() {
    local key="$1"
    if [ -f "$CONFIG_FILE" ] && command -v jq &>/dev/null; then
        jq -r "${key}[]? // empty" "$CONFIG_FILE" 2>/dev/null
    fi
}

echo -e "${BOLD}Environment Doctor${NC}"
echo ""

# ─── Check 1: .env file exists ────────────────────────────────────────────
echo -e "${BOLD}1. Project .env${NC}"
if [ -f "$ENV_FILE" ]; then
    check ".env file exists" 0
else
    check ".env file exists" 1 "not found — create .env with your credentials"
    echo ""
    echo -e "${RED}Cannot continue without .env file.${NC}"
    exit 1
fi
echo ""

# ─── Check 2: Critical var conflicts (shell vs .env) ──────────────────────
CRITICAL_VARS=()
while IFS= read -r var; do
    [ -n "$var" ] && CRITICAL_VARS+=("$var")
done < <(config_array ".envDoctor.criticalVars")

if [ ${#CRITICAL_VARS[@]} -gt 0 ]; then
    echo -e "${BOLD}2. Credential Conflicts${NC}"
    echo -e "   ${DIM}Compares your current shell env vars against .env file values${NC}"
    echo ""

    for var in "${CRITICAL_VARS[@]}"; do
        shell_val="${!var:-}"
        file_val=$(env_file_value "$var")

        if [ -n "$shell_val" ] && [ -n "$file_val" ]; then
            if [ "$shell_val" != "$file_val" ]; then
                check "$var MISMATCH" 1 "shell=$(mask "$shell_val") .env=$(mask "$file_val")"
                echo -e "    ${DIM}Shell value will override .env in MCP server and Claude Code${NC}"
                echo -e "    ${DIM}Fix: unset $var${NC}"
            else
                check "$var" 0
            fi
        elif [ -n "$shell_val" ] && [ -z "$file_val" ]; then
            check "$var" 2 "set in shell ($(mask "$shell_val")) but not in .env — shell value will be used"
        elif [ -z "$shell_val" ] && [ -n "$file_val" ]; then
            check "$var" 0
        else
            check "$var" 1 "not set anywhere — add to .env"
        fi
    done
    echo ""
else
    echo -e "${BOLD}2. Credential Conflicts${NC}"
    echo -e "   ${DIM}No criticalVars configured in ff.config.json — skipping${NC}"
    echo ""
fi

# ─── Check 3: Dangerous orphaned vars ─────────────────────────────────────
DANGEROUS_VARS=()
while IFS= read -r var; do
    [ -n "$var" ] && DANGEROUS_VARS+=("$var")
done < <(config_array ".envDoctor.dangerousVars")

if [ ${#DANGEROUS_VARS[@]} -gt 0 ]; then
    echo -e "${BOLD}3. Dangerous Inherited Vars${NC}"
    echo -e "   ${DIM}Vars that cause silent failures when leaked from parent shell${NC}"
    echo ""

    for var in "${DANGEROUS_VARS[@]}"; do
        shell_val="${!var:-}"
        file_val=$(env_file_value "$var")

        if [ -n "$shell_val" ] && [ -z "$file_val" ]; then
            check "$var" 1 "set to '$shell_val' in shell but NOT in .env — may cause silent routing/auth issues"
            echo -e "    ${DIM}Fix: unset $var${NC}"
        elif [ -n "$shell_val" ] && [ -n "$file_val" ] && [ "$shell_val" != "$file_val" ]; then
            check "$var" 1 "shell='$shell_val' .env='$file_val' — mismatch"
        elif [ -n "$shell_val" ]; then
            check "$var" 2 "set to '$shell_val' — verify this is intentional"
        else
            check "$var" 0
        fi
    done
    echo ""
else
    echo -e "${BOLD}3. Dangerous Inherited Vars${NC}"
    echo -e "   ${DIM}No dangerousVars configured in ff.config.json — skipping${NC}"
    echo ""
fi

# ─── Check 4: direnv status ──────────────────────────────────────────────
echo -e "${BOLD}4. Environment Isolation${NC}"

if command -v direnv &>/dev/null; then
    if [ -f "$PROJECT_DIR/.envrc" ]; then
        if direnv status 2>/dev/null | grep -q "Found RC allowed true"; then
            check "direnv active" 0
        else
            check "direnv" 2 ".envrc exists but not allowed — run: direnv allow"
        fi
    else
        check "direnv" 2 ".envrc not found — copy scripts/envrc.template to .envrc for environment isolation"
    fi
else
    check "direnv" 2 "not installed — shell vars can leak between projects"
    echo -e "    ${DIM}Install: brew install direnv${NC}"
fi
echo ""

# ─── Summary ──────────────────────────────────────────────────────────────
echo -e "${BOLD}Summary${NC}"
TOTAL=$((PASS + FAIL + WARN))
echo -e "  ${GREEN}$PASS passed${NC}  ${RED}$FAIL failed${NC}  ${YELLOW}$WARN warnings${NC}  (${TOTAL} checks)"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}Environment has conflicts that will cause failures.${NC}"
    echo ""
    # Build unset command from all critical + dangerous vars
    ALL_VARS=("${CRITICAL_VARS[@]}" "${DANGEROUS_VARS[@]}")
    if [ ${#ALL_VARS[@]} -gt 0 ]; then
        echo -e "Quick fix (unset all inherited vars):"
        echo -e "  ${CYAN}unset ${ALL_VARS[*]}${NC}"
        echo ""
    fi
    echo -e "Permanent fix (direnv auto-isolates per project):"
    echo -e "  ${CYAN}brew install direnv && echo 'eval \"\$(direnv hook zsh)\"' >> ~/.zshrc && direnv allow${NC}"
    echo ""
    exit 1
elif [ "$WARN" -gt 0 ]; then
    echo -e "${YELLOW}Environment mostly clean — review warnings above.${NC}"
    exit 0
else
    echo -e "${GREEN}Environment clean!${NC}"
    exit 0
fi
