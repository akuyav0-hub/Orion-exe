#!/usr/bin/env bash
# Orion integrity check — run before every deploy.
#   ./verify.sh                (checks ./index.html if present; otherwise
#                                auto-detects a single orion_ver_*.html here)
#   ./verify.sh other.html      (explicit filename always wins)
#
# Static only: no browser, no dependencies. Catches the failure classes that
# have actually bitten this project — merged script tags, missing systems,
# stale cache names, ambiguous version stamps.

set -uo pipefail

if [ -n "${1:-}" ]; then
  FILE="$1"
elif [ -f index.html ]; then
  FILE="index.html"
else
  # Not yet renamed to index.html — look for the one versioned build in this dir.
  mapfile -t CANDIDATES < <(find . -maxdepth 1 -name 'orion_ver_*.html' -printf '%f\n' 2>/dev/null | sort)
  if [ "${#CANDIDATES[@]}" -eq 1 ]; then
    FILE="${CANDIDATES[0]}"
    echo "No index.html yet — auto-detected ${FILE} (rename to index.html before deploying)"
    echo
  elif [ "${#CANDIDATES[@]}" -eq 0 ]; then
    echo "No index.html and no orion_ver_*.html found in this directory."
    echo "Run: ./verify.sh <filename>"
    exit 2
  else
    echo "Multiple candidates found — specify which one:"
    printf '  %s\n' "${CANDIDATES[@]}"
    exit 2
  fi
fi

FAIL=0
pass(){ printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail(){ printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=1; }
info(){ printf '  ----  %s\n' "$1"; }

[ -f "$FILE" ] || { echo "No such file: $FILE"; exit 2; }
echo "Orion integrity check — $FILE"
echo

# --- 1. script tag balance (a dropped </script> merges blocks and breaks JS) ---
OPEN=$(grep -c '<script' "$FILE" || true)
CLOSE=$(grep -c '</script>' "$FILE" || true)
if [ "$OPEN" -eq "$CLOSE" ]; then pass "script tags balanced ($OPEN/$CLOSE)"
else fail "script tags UNBALANCED — open=$OPEN close=$CLOSE (a merged block will throw 'Unexpected token <')"; fi

# --- 2. canonical body must be SVG, never PNG figures ---
if grep -q '<svg id="avatar-stage"' "$FILE"; then pass "canonical SVG body present"
else fail "SVG avatar-stage MISSING — is this the vector canon?"; fi
if grep -q 'figbox-standard' "$FILE"; then fail "PNG figbox markup found — this looks like the retired fork body"
else pass "no PNG figure markup (fork body absent)"; fi

# --- 3. required systems ---
check(){ if grep -q "$1" "$FILE"; then pass "$2"; else fail "$2 — MISSING"; fi; }
check 'dawnfull:'                'full power: dawnfull form'
check 'enterFullPower'           'full power: activation'
check 'gracefulRevert'           'full power: graceful revert'
check 'FULL_POWER'               'full power: marker parse'
check 'key-toggle'               'API key visibility toggle'
check 'claude-sonnet-5'          'current model IDs'
check 'rel="manifest"'           'PWA manifest link'
check 'serviceWorker.register'   'PWA service worker registration'
check 'pet-orb'                  'Pet Mode orbs'
check 'getScreenCTM'             'Pet Mode core tracking'
check 'orion_mc_state_pending'   'Moon Core offline queue'
check 'visualViewport'           'iOS keyboard handling'
check 'reduced-fx'               'reduced-effects mode'

# --- 4. agency lock: full power must NOT be operator-triggerable ---
if grep -qE 'return \{[^}]*enterFullPower' "$FILE"; then
  fail "AGENCY LOCK BROKEN — enterFullPower is exposed on the public API"
else pass "agency lock intact (enterFullPower not exported)"; fi
if grep -qiE 'data-action="full.?power"|id="full-power' "$FILE"; then
  fail "AGENCY LOCK BROKEN — an operator full-power control exists"
else pass "agency lock intact (no operator full-power control)"; fi

# --- 5. version stamp should be single and unambiguous ---
VERS=$(grep -oE 'v0\.[0-9][a-z]?' "$FILE" | sort -u | tr '\n' ' ')
info "version strings present: ${VERS:-none}"
TITLE=$(grep -oE '<title>[^<]*' "$FILE" | head -1)
info "title: ${TITLE#<title>}"

# --- 6. service worker cache name (stale cache serves old code) ---
if [ -f sw.js ]; then
  CACHE=$(grep -oE "const CACHE = '[^']*'" sw.js | head -1)
  info "sw.js $CACHE  — bump this on every deploy"
else info "sw.js not found in this directory (skipped)"; fi

echo
if [ "$FAIL" -eq 0 ]; then echo "All checks passed."; else echo "FAILURES PRESENT — do not deploy."; fi
exit $FAIL
