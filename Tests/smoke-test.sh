#!/bin/bash
#
# Smoke tests for iphonebase CLI.
# Requires: iPhone Mirroring active, Karabiner running, Screen Recording permission.
#
# Usage:
#   make test-device           # build + test
#   bash tests/smoke-test.sh   # test only (assumes binary built)
#
set -euo pipefail

BINARY="${IPHONEBASE_BIN:-.build/debug/iphonebase}"
PASS=0
FAIL=0
SKIP=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass() { PASS=$((PASS + 1)); echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} $1: $2"; }
skip() { SKIP=$((SKIP + 1)); echo -e "${YELLOW}[SKIP]${NC} $1"; }

# Check binary exists
if [ ! -f "$BINARY" ]; then
    echo "Binary not found at $BINARY. Run 'swift build' first."
    exit 1
fi

echo "=== iphonebase smoke tests ==="
echo "Binary: $BINARY"
echo ""

# --- Basic CLI ---
echo "--- basic CLI ---"

if $BINARY --version 2>/dev/null | grep -q "0\."; then
    pass "--version output"
else
    fail "--version output" "unexpected format"
fi

if $BINARY --help 2>/dev/null | grep -q "SUBCOMMANDS"; then
    pass "--help shows subcommands"
else
    fail "--help shows subcommands" "missing SUBCOMMANDS"
fi

# --- Status ---
echo ""
echo "--- status ---"

STATUS_OUT=$($BINARY status --json 2>/dev/null) || true
if echo "$STATUS_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['action']=='status'" 2>/dev/null; then
    pass "status --json valid structure"
else
    fail "status --json valid structure" "invalid JSON or missing action"
fi

# Check if mirroring is active for remaining tests
MIRRORING_ACTIVE=false
if echo "$STATUS_OUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d.get('success') == True
assert d.get('data', {}).get('iphone_mirroring') == True
" 2>/dev/null; then
    MIRRORING_ACTIVE=true
    pass "iPhone Mirroring is active"
else
    echo -e "${YELLOW}iPhone Mirroring not active. Skipping device tests.${NC}"
fi

if [ "$MIRRORING_ACTIVE" = false ]; then
    for cmd in doctor screenshot "screenshot --grid" describe tap swipe home key scroll; do
        skip "$cmd (no mirroring)"
    done
else
    # --- Doctor ---
    echo ""
    echo "--- doctor ---"

    if $BINARY doctor --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['success']==True" 2>/dev/null; then
        pass "doctor --json all checks pass"
    else
        fail "doctor --json" "one or more checks failed"
    fi

    # --- Screenshot ---
    echo ""
    echo "--- screenshot ---"

    TMPFILE=$(mktemp /tmp/iphonebase-test-XXXXXX.png)
    trap "rm -f $TMPFILE" EXIT

    if $BINARY screenshot -o "$TMPFILE" 2>/dev/null && [ -s "$TMPFILE" ]; then
        pass "screenshot to file"
    else
        fail "screenshot to file" "file empty or command failed"
    fi

    if $BINARY screenshot --json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['success'] == True
assert d['data']['format'] == 'png'
assert len(d['data']['data']) > 100
" 2>/dev/null; then
        pass "screenshot --json base64"
    else
        fail "screenshot --json base64" "invalid or empty data"
    fi

    # --- Screenshot with grid ---
    echo ""
    echo "--- screenshot --grid ---"

    if $BINARY screenshot --grid --json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['success'] == True
assert 'grid' in d['data']
assert d['data']['grid']['rows'] > 0
" 2>/dev/null; then
        pass "screenshot --grid --json"
    else
        fail "screenshot --grid --json" "missing grid data"
    fi

    # --- Describe (OCR) ---
    echo ""
    echo "--- describe ---"

    if $BINARY describe --json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['success'] == True
assert isinstance(d['data'], list)
" 2>/dev/null; then
        pass "describe --json"
    else
        fail "describe --json" "invalid structure"
    fi

    # --- Tap ---
    echo ""
    echo "--- tap ---"

    if $BINARY tap 200 400 --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['success']==True" 2>/dev/null; then
        pass "tap x y --json"
    else
        fail "tap x y --json" "tap failed"
    fi
    sleep 1

    # --- Swipe ---
    echo ""
    echo "--- swipe ---"

    if $BINARY swipe up --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['success']==True" 2>/dev/null; then
        pass "swipe up --json"
    else
        fail "swipe up --json" "swipe failed"
    fi
    sleep 1

    # --- Home ---
    echo ""
    echo "--- home ---"

    if $BINARY home --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['success']==True" 2>/dev/null; then
        pass "home --json"
    else
        fail "home --json" "home failed"
    fi
    sleep 2

    # --- Key ---
    echo ""
    echo "--- key ---"

    if $BINARY key return --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['success']==True" 2>/dev/null; then
        pass "key return --json"
    else
        fail "key return --json" "key press failed"
    fi

    # --- Scroll ---
    echo ""
    echo "--- scroll ---"

    if $BINARY scroll down --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['success']==True" 2>/dev/null; then
        pass "scroll down --json"
    else
        fail "scroll down --json" "scroll failed"
    fi
    sleep 1
fi

# --- Error handling (always runs) ---
echo ""
echo "--- error handling ---"

if ! $BINARY tap 2>/dev/null; then
    pass "tap with no args exits non-zero"
else
    fail "tap with no args" "should have failed"
fi

if ! $BINARY swipe diagonal 2>/dev/null; then
    pass "swipe invalid direction exits non-zero"
else
    fail "swipe invalid direction" "should have failed"
fi

if ! $BINARY key foobar 2>/dev/null; then
    pass "key invalid name exits non-zero"
else
    fail "key invalid name" "should have failed"
fi

if ! $BINARY scroll sideways 2>/dev/null; then
    pass "scroll invalid direction exits non-zero"
else
    fail "scroll invalid direction" "should have failed"
fi

# --- Summary ---
echo ""
echo "==========================="
echo -e "Passed: ${GREEN}${PASS}${NC}"
echo -e "Failed: ${RED}${FAIL}${NC}"
echo -e "Skipped: ${YELLOW}${SKIP}${NC}"
echo "==========================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
