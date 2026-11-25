#!/usr/bin/env bash
# Tests for bin/lane: usage line, flag pass-through, the harness check, and the land handoff (--land-cmd) for
# every land exit code.
# Uses a fake simmer, fake land commands and temporary repos only.
#   bash ~/.agents/skills/orchestrate/tests/lane.test.sh
# LANE_BIN=<file> tests another copy of bin/lane (a new version before it replaces the old one).
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
lane_bin="${LANE_BIN:-$here/../bin/lane}"
lane() { bash "$lane_bin" "$@"; }
work="$(mktemp -d)"
cleanup() { rm -rf "${work:?}"; }
trap cleanup EXIT

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_CONFIG_GLOBAL=/dev/null
git init --quiet --bare -b main "$work/origin.git"
git clone --quiet "$work/origin.git" "$work/wt" 2>/dev/null
echo base > "$work/wt/base.txt"; git -C "$work/wt" add base.txt; git -C "$work/wt" commit --quiet -m base
git -C "$work/wt" push --quiet origin main 2>/dev/null; git -C "$work/wt" remote set-head origin main
git -C "$work/wt" checkout --quiet -b wt/L
echo feature > "$work/wt/feature.txt"; git -C "$work/wt" add feature.txt; git -C "$work/wt" commit --quiet -m feature

failures=0
check() { # name expected actual
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$2', got '$3'"; failures=$((failures + 1)); fi
}
has() { grep -qF -- "$2" "$1" && echo yes || echo no; } # file text

# No systemd user session: the lane runs in this shell.
mkdir -p "$work/bin"
printf '#!/usr/bin/env bash\nexit 1\n' > "$work/bin/systemctl"
# Fake simmer: records its arguments, writes the report (FAKE_REPORT, or FAKE_FIX_REPORT for a fix agent's brief)
# and a usage file, and exits with FAKE_RC (FAKE_FIX_RC for a fix agent).
cat > "$work/bin/simmer" <<'SIM'
#!/usr/bin/env bash
[ -n "${FAKE_NO_SIMMER:-}" ] && exit 127
if [ "$2" = --help ]; then
  # An old simmer has neither --usage-out nor agy.
  if [ -n "${FAKE_OLD_SIMMER:-}" ]; then echo '  --harness <name>            claude, codex, or crush'
  else echo '  --harness <name>            claude, codex, crush, or agy'; echo '  --usage-out <file>'; fi
  exit 0
fi
shift; brief="$1"; shift
args="$*"
while [ $# -gt 0 ]; do
  case "$1" in --out) out="$2"; shift ;; --usage-out) usage="$2"; shift ;; esac; shift
done
name="$(basename "$out" .last.md)"
printf '%s\n' "$args" > "$FAKE_DIR/$name.args"
cp -f "$brief" "$FAKE_DIR/$name.brief-seen"
rc="${FAKE_RC:-0}"
case "$brief" in
  *.fix*) printf '%b' "${FAKE_FIX_REPORT:-fixed it\nREADY-TO-LAND}" > "$out"; rc="${FAKE_FIX_RC:-0}" ;;
  *) printf '%b' "${FAKE_REPORT:-done}" > "$out" ;;
esac
[ -n "${usage:-}" ] && printf '{\n  "outputTokens": 1000,\n  "cacheReadTokens": 2000000,\n  "turns": 5,\n  "peakContext": 90000,\n  "relays": 0\n}\n' > "$usage"
echo "simmer lane: usage: input 1, output 1000, cache read 2000000, cache write 0" >&2
exit "$rc"
SIM
chmod +x "$work/bin/simmer" "$work/bin/systemctl"
# Fake land command: exit codes come from LAND_CODES, one per attempt.
cat > "$work/land.sh" <<'LAND'
#!/usr/bin/env bash
n=$(( $(cat "$FAKE_DIR/land.count" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$FAKE_DIR/land.count"
read -r -a codes <<< "$LAND_CODES"; code="${codes[$((n - 1))]:-0}"
words=(landed gate-failed conflict infra nothing)
summary="$FAKE_DIR/summary-$n.md"
printf 'result: %s\nexit: %s\ngate: unit\n\nunit test foo failed: expected 1, got 2\n' "${words[$code]}" "$code" > "$summary"
echo "landing from $(basename "$PWD")"
echo "warning on stderr" >&2
echo "LAND-RESULT ${words[$code]} $summary"
exit "$code"
LAND
cat > "$work/brief.md" <<'BRIEF'
You are lane L for a test project.

## Goal
Make the feature work for the owner.
The bar is high.

## Scope
1. Everything.
BRIEF

# run_lane <name> [env assignments...] -- [lane options...]: runs bin/lane; stdout in $work/<name>.stdout. Prints the exit code.
# The lane runs on $harness (default claude).
harness=claude
run_lane() {
  local name="$1"; shift; local envs=()
  while [ "$1" != -- ]; do envs+=("$1"); shift; done; shift
  rm -rf "${work:?}/fake" "${work:?}/out"; mkdir -p "$work/fake" "$work/out"
  echo "- 10:00 started" > "$work/out/$name.log.md"
  env PATH="$work/bin:$PATH" FAKE_DIR="$work/fake" "${envs[@]}" \
    bash "$lane_bin" "$name" "$work/brief.md" --worktree "$work/wt" --out-dir "$work/out" --harness "$harness" --keep-worktree "$@" \
    > "$work/$name.stdout" 2> "$work/$name.stderr"
  echo $?
}
report() { echo "$work/out/$1.last.md"; }
attempts() { cat "$work/fake/land.count" 2>/dev/null || echo 0; }

# Without --land-cmd: today's behaviour, plus usage.
check "no land: exit 0" 0 "$(run_lane L -- --context-ceiling 70000 --max-relays 2)"
check "no land: ceiling and relays go to simmer" yes "$(has "$work/fake/L.args" '--context-ceiling 70000 --max-relays 2')"
check "no land: simmer writes usage next to the report" yes "$(has "$work/fake/L.args" "--usage-out $work/out/L.usage.json")"
check "no land: usage line for the ledger" "LANE L usage out=1k cr=2.0M turns=5 peak=90k relays=0" "$(grep '^LANE L usage' "$work/L.stdout")"
check "no land: report printed" yes "$(has "$work/L.stdout" done)"
check "no land: no land section" no "$(has "$(report L)" '## Land')"
check "old simmer: exit 0" 0 "$(run_lane L FAKE_OLD_SIMMER=1 --)"
check "old simmer: no --usage-out" no "$(has "$work/fake/L.args" '--usage-out')"
check "old simmer: no usage line" "" "$(grep '^LANE L usage' "$work/L.stdout")"
check "agent failure: its exit code" 7 "$(run_lane L FAKE_RC=7 -- --land-cmd "bash $work/land.sh")"
check "agent failure: land not run" 0 "$(attempts)"

# Exit 0: landed.
check "land 0: exit 0" 0 "$(run_lane L 'FAKE_REPORT=work done\nREADY-TO-LAND\n' LAND_CODES=0 -- --land-cmd "bash $work/land.sh")"
check "land 0: one attempt" 1 "$(attempts)"
check "land 0: result in the report" yes "$(has "$(report L)" 'Result: landed (exit 0) after 1 attempt(s) and 0 fix round(s).')"
check "land 0: agent report kept above" yes "$(sed -n 1p "$(report L)" | grep -qx 'work done' && echo yes || echo no)"
check "land 0: land stdout in the report" yes "$(has "$(report L)" 'landing from wt')"
check "land 0: land stderr kept apart" yes "$(has "$work/out/L.land-1.err" 'warning on stderr')"
check "land 0: stderr not in the report" no "$(has "$(report L)" 'warning on stderr')"
check "land 0: ran in the worktree" yes "$(has "$work/out/L.land-1.out" 'landing from wt')"

# A report with READY-TO-LAND in markdown marks still counts; one without it never lands.
check "ready marker in backticks: lands" 0 "$(run_lane L 'FAKE_REPORT=ok\n`READY-TO-LAND`\n' LAND_CODES=0 -- --land-cmd "bash $work/land.sh")"
check "no READY-TO-LAND: exit 6" 6 "$(run_lane L 'FAKE_REPORT=blocked on X\nnot READY-TO-LAND yet\n' LAND_CODES=0 -- --land-cmd "bash $work/land.sh")"
check "no READY-TO-LAND: land not run" 0 "$(attempts)"
check "no READY-TO-LAND: said in the report" yes "$(has "$(report L)" 'Not run: the report has no READY-TO-LAND line')"

# Exit 4: nothing to land counts as done.
check "land 4: exit 0" 0 "$(run_lane L 'FAKE_REPORT=x\nREADY-TO-LAND' LAND_CODES=4 -- --land-cmd "bash $work/land.sh")"
check "land 4: result nothing" yes "$(has "$(report L)" 'Result: nothing (exit 4)')"

# Exit 1 then 0: one fix agent with a short brief.
check "land 1,0: exit 0" 0 "$(run_lane L 'FAKE_REPORT=x\nREADY-TO-LAND' 'LAND_CODES=1 0' -- --land-cmd "bash $work/land.sh")"
check "land 1,0: two attempts" 2 "$(attempts)"
fb="$work/fake/L.fix1.brief-seen"
check "fix brief: round" yes "$(has "$fb" 'You are fix agent 1 of at most 2 for lane L.')"
check "fix brief: failure named" yes "$(has "$fb" 'failed: gate-failed (exit 1')"
check "fix brief: goal paragraph" yes "$(has "$fb" 'Make the feature work for the owner.')"
check "fix brief: goal stops at the next section" no "$(has "$fb" 'Everything.')"
check "fix brief: lane log path" yes "$(has "$fb" "$work/out/L.log.md")"
check "fix brief: summary path" yes "$(has "$fb" "$work/fake/summary-1.md")"
check "fix brief: land output" yes "$(has "$fb" 'LAND-RESULT gate-failed')"
check "fix brief: diff stat against the trunk" yes "$(has "$fb" 'feature.txt | 1 +')"
check "fix brief: READY-TO-LAND rule" yes "$(grep -qx 'READY-TO-LAND' "$fb" && echo yes || echo no)"
check "fix brief: short" yes "$([ "$(wc -l < "$fb")" -le 60 ] && echo yes || echo no)"
check "fix agent: same engine flags" yes "$(has "$work/fake/L.fix1.args" '--harness claude')"
check "land 1,0: fix report in the lane report" yes "$(has "$(report L)" '### Fix agent 1 report')"
check "land 1,0: result" yes "$(has "$(report L)" 'Result: landed (exit 0) after 2 attempt(s) and 1 fix round(s).')"
check "land 1,0: usage sums the fix agent" "LANE L usage out=2k cr=4.0M turns=10 peak=90k relays=0 fixes=1" "$(grep '^LANE L usage' "$work/L.stdout")"

# Exit 2 three times: two fix rounds, then the conflict is reported.
check "land 2,2,2: exit 2" 2 "$(run_lane L 'FAKE_REPORT=x\nREADY-TO-LAND' 'LAND_CODES=2 2 2' -- --land-cmd "bash $work/land.sh")"
check "land 2,2,2: three attempts" 3 "$(attempts)"
check "land 2,2,2: no third fix agent" no "$([ -e "$work/fake/L.fix3.args" ] && echo yes || echo no)"
check "land 2,2,2: said in the report" yes "$(has "$(report L)" 'No fix rounds left (2 used).')"

# A fix agent that cannot fix it stops the loop.
check "fix without READY-TO-LAND: exit 6" 6 "$(run_lane L 'FAKE_REPORT=x\nREADY-TO-LAND' 'FAKE_FIX_REPORT=main is broken, not this branch' 'LAND_CODES=1 0' -- --land-cmd "bash $work/land.sh")"
check "fix without READY-TO-LAND: one attempt" 1 "$(attempts)"
check "fix agent failure: its exit code" 9 "$(run_lane L 'FAKE_REPORT=x\nREADY-TO-LAND' 'LAND_CODES=1 0' FAKE_FIX_RC=9 -- --land-cmd "bash $work/land.sh")"

# Exit 3: one retry after the pause.
check "land 3,0: exit 0" 0 "$(run_lane L 'FAKE_REPORT=x\nREADY-TO-LAND' 'LAND_CODES=3 0' -- --land-cmd "bash $work/land.sh" --land-retry-pause 0)"
check "land 3,0: two attempts, no fix agent" "2 no" "$(attempts) $([ -e "$work/fake/L.fix1.args" ] && echo yes || echo no)"
check "land 3,3: exit 3" 3 "$(run_lane L 'FAKE_REPORT=x\nREADY-TO-LAND' 'LAND_CODES=3 3 0' -- --land-cmd "bash $work/land.sh" --land-retry-pause 0)"
check "land 3,3: two attempts" 2 "$(attempts)"
check "land 3,3: said in the report" yes "$(has "$(report L)" 'Infrastructure failed twice')"

# A land command with shell variables and quotes reaches bash unchanged.
check "land command keeps \$VARS" 0 "$(run_lane L 'FAKE_REPORT=x\nREADY-TO-LAND' LAND_CODES=0 -- --land-cmd 'f="$FAKE_DIR/marker"; echo "${HOME:+home}" > "$f"; bash '"$work"'/land.sh')"
check "land command keeps \$VARS: output" home "$(cat "$work/fake/marker" 2>/dev/null)"

# --harness agy: simmer must list it; the lane and its fix agents run on agy with the lane's model.
harness=agy
check "agy: exit 0" 0 "$(run_lane L 'FAKE_REPORT=x\nREADY-TO-LAND' 'LAND_CODES=1 0' -- --model gemini-4-neon-high --context-ceiling 90000 --land-cmd "bash $work/land.sh")"
check "agy: harness and model go to simmer" yes "$(has "$work/fake/L.args" '--harness agy --model gemini-4-neon-high --context-ceiling 90000')"
check "agy: fix agent on the same harness and model" yes "$(has "$work/fake/L.fix1.args" '--harness agy --model gemini-4-neon-high')"
check "agy: usage line" "LANE L usage out=2k cr=4.0M turns=10 peak=90k relays=0 fixes=1" "$(grep '^LANE L usage' "$work/L.stdout")"
check "agy on an old simmer: exit 2" 2 "$(run_lane L FAKE_OLD_SIMMER=1 --)"
check "agy on an old simmer: no agent started" no "$([ -e "$work/fake/L.args" ] && echo yes || echo no)"
check "agy on an old simmer: said why" yes "$(has "$work/L.stderr" 'simmer does not know harness agy')"
harness=claude
check "broken simmer: exit 2" 2 "$(run_lane L FAKE_NO_SIMMER=1 --)"
check "broken simmer: said why" yes "$(has "$work/L.stderr" 'no simmer')"

check "bad retry pause refused" 2 "$(run_lane L -- --land-cmd true --land-retry-pause soon)"

echo
if [ "$failures" -eq 0 ]; then echo "all passed"; else echo "$failures failed"; exit 1; fi
