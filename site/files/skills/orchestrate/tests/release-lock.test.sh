#!/usr/bin/env bash
# Tests for bin/release-lock. Runs against a temporary lock dir and a fake gh; touches no real lock.
#   bash ~/.agents/skills/orchestrate/tests/release-lock.test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
lock="$here/../bin/release-lock"
work="$(mktemp -d)"
trap 'rm -rf "${work:?}"' EXIT

mkdir -p "$work/projects/demo" "$work/state"
printf 'repo=example/demo\nbranch=main\nci_workflow=ci.yml\ndeploy_workflow=deploy.yml\n' > "$work/projects/demo/release-lock.conf"
cat > "$work/gh" <<'GH'
#!/usr/bin/env bash
# Fake gh: prints the run line the test set for the workflow named after --workflow.
while [ $# -gt 0 ]; do [ "$1" = --workflow ] && workflow="$2"; shift; done
case "$workflow" in
  ci.yml) echo "${FAKE_CI:-completed 2026-01-01T00:00:00Z 11 abcdef1234}" ;;
  deploy.yml) echo "${FAKE_DEPLOY:-completed 2026-01-01T00:05:00Z 22}" ;;
esac
GH
chmod +x "$work/gh"

export RELEASE_LOCK_HOST="$(hostname)" RELEASE_LOCK_DIR="$work/state" RELEASE_LOCK_PROJECTS="$work/projects" \
  RELEASE_LOCK_GH="$work/gh" RELEASE_LOCK_POLL=1
# Session pids come only from RELEASE_LOCK_PID in these tests, never from the session that runs them.
unset CLAUDE_PID RELEASE_LOCK_PID RELEASE_LOCK_CLIENT RELEASE_LOCK_CLIENT_PID RELEASE_LOCK_CLIENT_PID_START

failures=0
check() { # name expected actual
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected $2, got $3"; failures=$((failures + 1)); fi
}
run() { "$lock" "$@" >/dev/null 2>&1; echo $?; }

# Free lock: the first acquirer gets it, a second holder is refused while it is fresh.
check "acquire free lock" 0 "$(run acquire demo --holder a --lane REL1 --sha abc1234)"
check "second holder refused while fresh" 2 "$(run acquire demo --holder b --lane REL2)"
check "same holder re-acquire refreshes" 0 "$(run acquire demo --holder a --lane REL1)"
check "same holder, other lane refused" 2 "$(run acquire demo --holder a --lane REL9)"
check "refresh by holder" 0 "$(run refresh demo --holder a --lane REL1 --sha def5678)"
check "refresh by non-holder refused" 5 "$(run refresh demo --holder b --lane REL2)"
check "release by non-holder refused" 5 "$(run release demo --holder b --lane REL2)"
check "lock still held after refused release" 2 "$(run acquire demo --holder b --lane REL2)"
check "release by holder" 0 "$(run release demo --holder a --lane REL1)"
check "free after release" "free" "$("$lock" status demo | head -1)"

# Concurrent acquirers: in each of 10 rounds, 8 start at once and exactly one wins.
for round in $(seq 1 10); do
  pids=()
  for contender in $(seq 1 8); do
    "$lock" acquire demo --holder "h$contender" --lane "L$round" > "$work/out.$contender" 2>&1 &
    pids+=($!)
  done
  winners=0
  for pid in "${pids[@]}"; do wait "$pid" && winners=$((winners + 1)); done
  check "round $round: one of 8 concurrent acquirers wins" 1 "$winners"
  holder_line="$("$lock" status demo | head -1)"
  winner="$(echo "$holder_line" | sed -E 's/^held: (h[0-9]+)\/.*/\1/')"
  check "round $round: winner releases" 0 "$(run release demo --holder "$winner" --lane "L$round")"
done

# Stale holder: a holder whose shell died stops refreshing; after ttl the lock is taken, never before.
check "holder with short ttl" 0 "$(run acquire demo --holder dead --lane REL3 --ttl 2)"
check "fresh lock not stolen" 2 "$(run acquire demo --holder c --lane REL4)"
sleep 3
check "stale lock taken" 0 "$(run acquire demo --holder c --lane REL4)"
check "stale log line" 1 "$(command grep -c 'STALE dead/REL3' "$work/state/demo.release.log")"
check "dead holder cannot release the taken lock" 5 "$(run release demo --holder dead --lane REL3)"
check "dead holder cannot refresh the taken lock" 5 "$(run refresh demo --holder dead --lane REL3)"
check "new holder releases" 0 "$(run release demo --holder c --lane REL4)"

# Trunk busy: a push from a session that ignores the lock still blocks the grant.
check "CI in progress refuses" 3 "$(FAKE_CI='in_progress 2026-01-01T00:00:00Z 11 abcdef1234' run acquire demo --holder d --lane REL5)"
check "CI queued refuses" 3 "$(FAKE_CI='queued 2026-01-01T00:00:00Z 11 abcdef1234' run acquire demo --holder d --lane REL5)"
check "deploy in progress refuses" 3 "$(FAKE_DEPLOY='in_progress 2026-01-01T00:05:00Z 22' run acquire demo --holder d --lane REL5)"
just_now="$(date -u -d '-20 seconds' +%FT%TZ)"
check "CI just finished, deploy not started, refuses" 3 \
  "$(FAKE_CI="completed $just_now 11 abcdef1234" run acquire demo --holder d --lane REL5)"
check "nothing left behind by refusals" "free" "$("$lock" status demo | head -1)"
check "wait times out while busy" 4 \
  "$(FAKE_CI='in_progress 2026-01-01T00:00:00Z 11 abcdef1234' run wait demo --holder d --lane REL5 --timeout 2)"

# wait: gets the lock once the holder releases.
check "holder for wait test" 0 "$(run acquire demo --holder e --lane REL6)"
( sleep 2; "$lock" release demo --holder e --lane REL6 >/dev/null 2>&1 ) &
check "wait gets the lock after release" 0 "$(run wait demo --holder f --lane REL7 --timeout 20)"
wait
check "waiter holds it" "f/REL7" "$("$lock" status demo | head -1 | sed -E 's/^held: ([^ ]+) .*/\1/')"
check "bad sha rejected" 1 "$(run acquire demo --holder g --lane REL8 --sha 'not-a-sha')"
check "waiter releases" 0 "$(run release demo --holder f --lane REL7)"

# Dead holder: a holder on this host whose session process is gone loses a fresh lock at once.
sleep 300 & session_a=$!
sleep 300 & session_b=$!
check "holder with a live session" 0 "$(RELEASE_LOCK_PID=$session_a run acquire demo --holder live --lane REL10 --ttl 7200)"
check "status names the live session" 1 \
  "$("$lock" status demo | head -1 | command grep -c "session pid $session_a alive")"
check "live session keeps its fresh lock" 2 "$(run acquire demo --holder other --lane REL11)"
kill "$session_a"; wait "$session_a" 2>/dev/null
check "status shows the session gone" 1 "$("$lock" status demo | head -1 | command grep -c 'gone')"
check "dead holder refused while CI runs" 3 \
  "$(FAKE_CI='in_progress 2026-01-01T00:00:00Z 11 abcdef1234' run acquire demo --holder other --lane REL11)"
check "dead holder's fresh lock taken" 0 "$(run acquire demo --holder other --lane REL11)"
check "dead log line" 1 "$(command grep -c "DEAD live/REL10 .*session pid $session_a" "$work/state/demo.release.log")"
check "release after dead take" 0 "$(run release demo --holder other --lane REL11)"

# A pid reused by a newer process does not keep a dead holder alive.
check "holder for pid reuse" 0 "$(RELEASE_LOCK_PID=$session_b run acquire demo --holder reused --lane REL12)"
sed -i 's/^pid_start=.*/pid_start=1/' "$work/state/demo.release.lock"
check "pid with another start time counts as gone" 0 "$(run acquire demo --holder other --lane REL11)"
check "release after reuse take" 0 "$(run release demo --holder other --lane REL11)"

# A holder on another host cannot be checked here; it keeps the lock until the ttl.
check "remote holder" 0 \
  "$(RELEASE_LOCK_CLIENT=elsewhere RELEASE_LOCK_CLIENT_PID=999999 RELEASE_LOCK_CLIENT_PID_START=1 run acquire demo --holder remote --lane REL13)"
check "remote holder unchecked, not taken" 2 "$(run acquire demo --holder other --lane REL11)"
check "remote holder releases" 0 \
  "$(RELEASE_LOCK_CLIENT=elsewhere RELEASE_LOCK_CLIENT_PID=999999 RELEASE_LOCK_CLIENT_PID_START=1 run release demo --holder remote --lane REL13)"

# A holder without a session (no CLAUDE_PID) keeps the lock until the ttl.
check "holder without a session" 0 "$(run acquire demo --holder nosession --lane REL14)"
check "no session, not taken while fresh" 2 "$(run acquire demo --holder other --lane REL11)"

# push: the pre-push hook's check. Only the holder of a fresh lock, from its own session.
check "push by the holder (no session recorded)" 0 "$(run push demo --holder nosession --lane REL14 --sha 1234abc)"
check "push records the sha" 1 "$(command grep -c '^sha=1234abc$' "$work/state/demo.release.lock")"
check "push log line" 1 "$(command grep -c 'PUSH nosession/REL14 sha=1234abc' "$work/state/demo.release.log")"
check "push by another holder refused" 5 "$(run push demo --holder other --lane REL11 --sha 1234abc)"
check "push without sha is an error" 1 "$(run push demo --holder nosession --lane REL14)"
check "release no-session holder" 0 "$(run release demo --holder nosession --lane REL14)"
check "push with no lock refused" 5 "$(run push demo --holder other --lane REL11 --sha 1234abc)"
check "holder with session b" 0 "$(RELEASE_LOCK_PID=$session_b run acquire demo --holder sess --lane REL15)"
check "push from the holder's session" 0 "$(RELEASE_LOCK_PID=$session_b run push demo --holder sess --lane REL15 --sha 5678def)"
check "push with copied names from another session refused" 5 \
  "$(RELEASE_LOCK_PID=$$ run push demo --holder sess --lane REL15 --sha 5678def)"
check "push with copied names and no session refused" 5 "$(run push demo --holder sess --lane REL15 --sha 5678def)"
check "push from another host refused" 5 \
  "$(RELEASE_LOCK_CLIENT=elsewhere RELEASE_LOCK_CLIENT_PID=$session_b RELEASE_LOCK_CLIENT_PID_START=1 run push demo --holder sess --lane REL15 --sha 5678def)"
check "refused pushes logged" 3 "$(command grep -c 'REFUSED push by sess/REL15' "$work/state/demo.release.log")"
check "release session holder" 0 "$(RELEASE_LOCK_PID=$session_b run release demo --holder sess --lane REL15)"
check "holder with short ttl for stale push" 0 "$(run acquire demo --holder short --lane REL16 --ttl 1)"
sleep 2
check "push on a stale lock refused" 5 "$(run push demo --holder short --lane REL16 --sha 5678def)"
check "release stale holder" 0 "$(run release demo --holder short --lane REL16)"
kill "$session_b"; wait "$session_b" 2>/dev/null

# bypass: an emergency push without the lock is logged with its reason.
check "bypass without reason is an error" 1 "$(run bypass demo --sha 1234abc)"
check "bypass logged" 0 "$(run bypass demo --sha 1234abc --reason $'prod down\nhotfix')"
check "bypass line keeps the reason on one line" 1 \
  "$(command grep -c 'BYPASS unknown/unknown sha=1234abc .* reason: prod down hotfix$' "$work/state/demo.release.log")"
check "status shows the last bypass" 1 "$("$lock" status demo | command grep -c '^last bypass: .*prod down hotfix')"

echo
if [ "$failures" -eq 0 ]; then echo "all passed"; else echo "$failures failed"; exit 1; fi
