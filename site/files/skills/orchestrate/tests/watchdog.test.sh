#!/usr/bin/env bash
# Tests for bin/watchdog's PEAK_CONTEXT flag. Uses temporary folders only; no lane worktrees, no network.
#   bash ~/.agents/skills/orchestrate/tests/watchdog.test.sh
# WATCHDOG_BIN=<file> tests another copy of bin/watchdog.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
watchdog_bin="${WATCHDOG_BIN:-$here/../bin/watchdog}"
work="$(mktemp -d)"
trap 'rm -rf "${work:?}"' EXIT
mkdir -p "$work/state" "$work/logs" "$work/wt" "$work/home"

failures=0
check() { # name expected actual
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$2', got '$3'"; failures=$((failures + 1)); fi
}
usage() { printf '{\n  "running": true,\n  "turns": 40,\n  "peakContext": %s,\n  "lastContext": 1\n}\n' "$2" > "$work/logs/$1.usage.json"; }
# One watchdog loop: the report when it fires, or "silent" when it would sleep (timeout ends it).
watch() {
  local out
  out=$(env STATE="$work/state" LANES="$LANES" WT_ROOT="$work/wt" LOG_DIR="$work/logs" RAM_MIN_GB=0 \
    ORCHESTRATE_HOME="$work/home" "$@" timeout 5 bash "$watchdog_bin" 2>&1)
  [ -n "$out" ] && printf '%s\n' "$out" | grep -v '^WATCHDOG' || echo silent
}

LANES="a b c"
usage a 200000; usage hq-b 50000; usage hq-c 300000
check "off by default" silent "$(watch)"
first="$(watch PEAK_CONTEXT=150000)"
check "lane over the threshold reported" yes "$(grep -qx 'lane a: peak context 200000 tok, over 150000' <<< "$first" && echo yes || echo no)"
check "prefixed usage file found" yes "$(grep -qx 'lane c: peak context 300000 tok, over 150000' <<< "$first" && echo yes || echo no)"
check "lane under the threshold not reported" no "$(grep -q 'lane b' <<< "$first" && echo yes || echo no)"
usage a 260000
check "same lane once, even when its peak grows" silent "$(watch PEAK_CONTEXT=150000)"
usage hq-b 170000
check "a new lane over the threshold" "lane b: peak context 170000 tok, over 150000" "$(watch PEAK_CONTEXT=150000 | grep 'lane b')"
check "bad threshold refused" "watchdog: PEAK_CONTEXT must be a token count" "$(watch PEAK_CONTEXT=lots)"

echo
if [ "$failures" -eq 0 ]; then echo "all passed"; else echo "$failures failed"; exit 1; fi
