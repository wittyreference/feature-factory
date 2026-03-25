#!/bin/bash
# ABOUTME: Verifies zero platform-specific references in the Feature Factory codebase.
# ABOUTME: Run on every commit to prevent Twilio (or any platform) coupling from leaking in.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0
TOTAL=0

run_check() {
    local name="$1"
    local pattern="$2"
    local exclude_pattern="${3:-}"
    TOTAL=$((TOTAL + 1))

    local matches
    if [ -n "$exclude_pattern" ]; then
        matches=$(grep -rnE "$pattern" "$PROJECT_ROOT" \
            --include='*.sh' --include='*.md' --include='*.json' --include='*.js' --include='*.ts' \
            --exclude-dir='.git' --exclude-dir='node_modules' --exclude-dir='.meta' --exclude-dir='twilio-overlay' --exclude-dir='blog' --exclude-dir='validation' \
            --exclude='test-no-leakage.sh' --exclude='ff-sync-map.json' --exclude='ff-sync-state.json' --exclude='ff-sync.md' \
            2>/dev/null | grep -vE "$exclude_pattern" || true)
    else
        matches=$(grep -rnE "$pattern" "$PROJECT_ROOT" \
            --include='*.sh' --include='*.md' --include='*.json' --include='*.js' --include='*.ts' \
            --exclude-dir='.git' --exclude-dir='node_modules' --exclude-dir='.meta' --exclude-dir='twilio-overlay' --exclude-dir='blog' --exclude-dir='validation' \
            --exclude='test-no-leakage.sh' --exclude='ff-sync-map.json' --exclude='ff-sync-state.json' --exclude='ff-sync.md' \
            2>/dev/null || true)
    fi

    if [ -z "$matches" ]; then
        echo -e "  ${GREEN}PASS${NC} $name"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $name"
        echo "$matches" | head -5 | while IFS= read -r line; do
            echo "    $line"
        done
        local match_count
        match_count=$(echo "$matches" | wc -l | tr -d ' ')
        if [ "$match_count" -gt 5 ]; then
            echo "    ... and $((match_count - 5)) more"
        fi
        FAIL=$((FAIL + 1))
    fi
}

echo "Feature Factory Leakage Check"
echo "=============================="
echo ""
echo "Scanning for platform-specific references..."
echo ""

# TC-LEAK-01: No Twilio Account SID patterns
run_check "TC-LEAK-01: No Twilio Account SID patterns (AC...)" \
    "AC[a-f0-9]{32}"

# TC-LEAK-02: No Twilio brand references in operational code
# Allowed: origin story (blog/README), overlay examples, changelog
run_check "TC-LEAK-02: No Twilio brand references" \
    "(twilio|Twilio|TWILIO)" \
    "(e\.g\.,.*Twilio|example|overlay|Overlay|CHANGELOG|Origin|origin|770\+|prototyping platform|battle-test|upstream|twilio-cli|twilio-docs|twilio-logs|twilio-api|Shipped Overlay)"

# TC-LEAK-03: No Twilio API Key SID patterns
run_check "TC-LEAK-03: No Twilio API Key SID patterns (SK...)" \
    "SK[a-f0-9]{32}"

# TC-LEAK-04: No Twilio-specific env vars
run_check "TC-LEAK-04: No Twilio-specific env vars" \
    "TWILIO_ACCOUNT_SID|TWILIO_AUTH_TOKEN|TWILIO_PHONE_NUMBER"

# TC-LEAK-05: No TwiML/SDK references
run_check "TC-LEAK-05: No TwiML/SDK references" \
    "twiml|TwiML|VoiceResponse|MessagingResponse" \
    "test-no-leakage"

# TC-LEAK-06: No Twilio magic test numbers
run_check "TC-LEAK-06: No Twilio magic test numbers" \
    "\+?1?5005550[0-9]{3}"

# TC-LEAK-07: No Twilio client references
run_check "TC-LEAK-07: No getTwilioClient references" \
    "getTwilioClient|context\.getTwilio"

# TC-LEAK-08: No Twilio serverless deploy
run_check "TC-LEAK-08: No Twilio serverless deploy references" \
    "twilio serverless|twilioserverless"

# TC-LEAK-09: No Twilio-specific file patterns
run_check "TC-LEAK-09: No .protected.js/.private.js access patterns" \
    "\.protected\.js|\.private\.js" \
    "test-no-leakage"

# TC-LEAK-10: No Twilio function paths
run_check "TC-LEAK-10: No functions/voice or functions/messaging paths" \
    "functions/(voice|messaging|verify|sync|taskrouter|conversation-relay|callbacks)"

# TC-LEAK-11: No MCP server references
run_check "TC-LEAK-11: No Twilio MCP server references" \
    "agents/mcp-servers/twilio|mcp__twilio__"

echo ""
echo "=============================="
echo "Results: $PASS passed, $FAIL failed (out of $TOTAL checks)"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}FAILED: Platform-specific references found!${NC}"
    echo "Fix the above leakage before committing."
    exit 1
else
    echo -e "${GREEN}PASSED: No platform-specific references found.${NC}"
    exit 0
fi
