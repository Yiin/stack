#!/usr/bin/env bash
# Tests for bin/lane's container mode (--host on a host with lane-host.env) and bin/lane-container.
# A fake host (ssh runs here with another HOME), a fake systemd, a fake docker (it maps mount targets to
# their sources), a fake dev-hosts and a fake simmer. Nothing leaves this machine.
#   bash ~/.agents/skills/orchestrate/tests/lane-container.test.sh
# LANE_BIN=<file> tests another copy of bin/lane; its folder must hold lane-container too.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
lane_bin="${LANE_BIN:-$here/../bin/lane}"
helper="$(dirname "$(readlink -f "$lane_bin")")/lane-container"
work="$(mktemp -d)"
cleanup() {
  local f
  for f in "$work"/fake/units/*.pid; do [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null; done
  rm -rf "${work:?}"
}
trap cleanup EXIT

failures=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$2', got '$3'"; failures=$((failures + 1)); fi; }
has() { grep -qF -- "$2" "$1" 2>/dev/null && echo yes || echo no; }

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_CONFIG_GLOBAL=/dev/null
export FAKE_DIR="$work/fake" FAKE_HOST_HOME="$work/hosthome" LANE_POLL_SECONDS=1
mkdir -p "$FAKE_DIR/units" "$FAKE_HOST_HOME/.config/orchestrate" "$work/bin" "$work/lanes" "$work/notes"
echo "LANE_IMAGE=fake-image:1" > "$FAKE_HOST_HOME/.config/orchestrate/lane-host.env"
echo "rules for lanes" > "$work/notes/rules.md"

git init --quiet --bare -b main "$work/origin.git"
git clone --quiet "$work/origin.git" "$work/wt" 2>/dev/null
echo base > "$work/wt/base.txt"; git -C "$work/wt" add base.txt; git -C "$work/wt" commit --quiet -m base
git -C "$work/wt" push --quiet origin main 2>/dev/null; git -C "$work/wt" remote set-head origin main
git -C "$work/wt" checkout --quiet -b wt/L

# ssh <options> <host> <command>: runs the command here with the host's HOME. A -N -R forward prints its port.
cat > "$work/bin/ssh" <<'EOF'
#!/usr/bin/env bash
fwd=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o|-i|-p|-l|-L) shift 2 ;;
    -R) fwd="$2"; shift 2 ;;
    -*) shift ;;
    *) break ;;
  esac
done
shift # the host
if [ -n "$fwd" ]; then echo "Allocated port 45678 for remote forward to ${fwd#*:0:}" >&2; exec sleep 600; fi
cmd="$*"; cmd="${cmd//bash -lc/bash -c}"
cd "$FAKE_HOST_HOME" && HOME="$FAKE_HOST_HOME" exec bash -c "$cmd"
EOF
# systemd-run: runs the unit in the background, in its own process group like a unit's cgroup, and keeps its PID. systemctl: is-active, stop; no user session.
cat > "$work/bin/systemd-run" <<'EOF'
#!/usr/bin/env bash
unit="" wd="."
while [ $# -gt 0 ]; do
  case "$1" in
    --unit=*) unit="${1#--unit=}" ;; --working-directory=*) wd="${1#--working-directory=}" ;;
    --setenv=*) export "${1#--setenv=}" ;; --*) ;; *) break ;;
  esac
  shift
done
setsid bash -c 'cd "$1" && shift && exec "$@"' _ "$wd" "$@" > /dev/null 2>&1 &
echo $! > "$FAKE_DIR/units/$unit.pid"
EOF
cat > "$work/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
[ "$1" = --user ] && shift
case "$1" in
  is-active) pid="$(cat "$FAKE_DIR/units/${!#}.pid" 2>/dev/null)"; [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null ;;
  stop) pid="$(cat "$FAKE_DIR/units/$2.pid" 2>/dev/null)"; [ -n "$pid" ] && kill -TERM -- "-$pid" 2>/dev/null
        for _ in $(seq 50); do kill -0 "$pid" 2>/dev/null || exit 0; sleep 0.1; done ;;
  *) exit 1 ;;
esac
EOF
# docker run: maps every argument under a mount target to its source, then runs the command here.
cat > "$work/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$FAKE_DIR/docker.argv"
if [ "$1" = stop ]; then pid="$(cat "$FAKE_DIR/box-${!#}.pid" 2>/dev/null)"; [ -n "$pid" ] && kill -TERM "$pid"; exit 0; fi
shift
maps=() name="" wd="" entry=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rm) shift ;;
    -v) src="${2%%:*}"; rest="${2#*:}"; maps+=("${rest%%:*}=$src"); shift 2 ;;
    -w) wd="$2"; shift 2 ;;
    --name) name="$2"; shift 2 ;;
    --entrypoint) entry="$2"; shift 2 ;;
    -e) export "$2"; shift 2 ;;
    -*) shift 2 ;;
    *) break ;;
  esac
done
echo "$*" >> "$FAKE_DIR/docker.args"
shift # the image
printf '%s\n' "${maps[@]}" > "$FAKE_DIR/mounts.now"
map() {
  local a="$1" m best="" src
  for m in "${maps[@]}"; do case "$a" in "${m%%=*}"|"${m%%=*}"/*) [ ${#m} -gt ${#best} ] && best="$m" ;; esac; done
  [ -n "$best" ] && a="${best#*=}${a#"${best%%=*}"}"
  printf '%s' "$a"
}
args=(); [ -n "$entry" ] && args+=("$entry")
for a in "$@"; do args+=("$(map "$a")"); done
[ -n "$name" ] && echo $$ > "$FAKE_DIR/box-$name.pid"
export FAKE_MAPS="$(printf '%s\n' "${maps[@]}")"
cd "$(map "${wd:-.}")" && exec "${args[@]}"
EOF
cat > "$work/bin/stat" <<'EOF'
#!/usr/bin/env bash
if [ "${!#}" = /var/run/docker.sock ]; then echo 992; else exec /usr/bin/stat "$@"; fi
EOF
cat > "$work/bin/mise" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  reshim) exit 0 ;;
  'run check')
    printf '#!/bin/bash\nprintf "%%s\\n" "hook ran" >> "$FAKE_DIR/hook"\nexit "${FAKE_HOOK_RC:-0}"\n' > .git/hooks/pre-push
    chmod +x .git/hooks/pre-push
    ;;
  *) exit 1 ;;
esac
EOF
cat > "$work/bin/dev-hosts" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  pick) printf 'hosts[1]{host,arch,free}:\n  fakespark,arm64,1000\n' ;;
  lease) echo "$*" >> "$FAKE_DIR/leases"; echo 'lease: "L1"' ;;
  check) if [ -f "$FAKE_DIR/revoked" ]; then echo 'state: revoked'; exit 1; fi; echo 'state: active' ;;
  unlease) echo "unlease $2" >> "$FAKE_DIR/leases" ;;
esac
EOF
# simmer: --help; or a lane: commits box.txt, appends to the lane log, waits for the coordinator's note.
cat > "$work/bin/simmer" <<'EOF'
#!/usr/bin/env bash
if [ "$2" = --help ]; then echo '  --harness <name>            claude or agy'; echo '  --usage-out <file>'; exit 0; fi
map() { local m; while IFS= read -r m; do case "$1" in "${m%%=*}"/*) printf '%s' "${m#*=}${1#"${m%%=*}"}"; return ;; esac; done <<< "$FAKE_MAPS"; printf '%s' "$1"; }
brief="$2"; shift 2
while [ $# -gt 0 ]; do case "$1" in --out) out="$2"; shift ;; --usage-out) usage="$2"; shift ;; esac; shift; done
log="$(map "$FAKE_LANE_LOG")"
if [ "${FAKE_MODE:-}" = conflict ]; then
  case "$brief" in
    *.fix1.brief.md) git rebase -X theirs origin/main || exit 1 ;;
    *) echo lane > conflict.txt; git add conflict.txt; git commit -q -m "lane conflict" ;;
  esac
else
  echo work > box.txt; git add box.txt; git commit -q -m "lane work"
fi
echo "- lane line" >> "$log"
[ "${FAKE_MODE:-}" = sleep ] && { sleep 60; exit 0; }
for _ in $(seq 100); do grep -q "coordinator note" "$log" && break; sleep 0.1; done
rules="$(map "$FAKE_RULES")"
{ echo "done"; echo "saw-note=$(grep -q 'coordinator note' "$log" && echo yes || echo no)"
  echo "saw-rules=$(grep -q 'rules for lanes' "$rules" 2>/dev/null && echo yes || echo no)"
  echo "saw-where=$(grep -q 'Where you run' "$brief" && echo yes || echo no)"
  echo "READY-TO-LAND"; } > "$out"
printf '{"outputTokens": 1000, "cacheReadTokens": 2000000, "turns": 5, "peakContext": 90000, "relays": 0}\n' > "$usage"
EOF
chmod +x "$work/bin"/*
export PATH="$work/bin:$PATH" DOCKER="$work/bin/docker"
export FAKE_LANE_LOG="$work/lanes/L.log.md" FAKE_RULES="$work/notes/rules.md"

printf '# L\n- start\n' > "$work/lanes/L.log.md"
printf '## Goal\nTiny lane.\n\nRead %s first. Lane log: %s.\n' "$work/notes/rules.md" "$work/lanes/L.log.md" > "$work/brief.md"
(sleep 3; echo "- coordinator note" >> "$work/lanes/L.log.md") &
bash "$lane_bin" L "$work/brief.md" --host spark --worktree "$work/wt" --out-dir "$work/lanes" --harness claude \
  --lane-log "$work/lanes/L.log.md" --keep-worktree \
  --land-cmd 'test -f box.txt && echo "LAND-RESULT landed none"' > "$work/out.txt" 2> "$work/err.txt"
check "container lane exits 0" 0 $?
check "dev-hosts picks the host" yes "$(has "$work/err.txt" "dev-hosts picked fakespark")"
check "the lane leases its unit" yes "$(has "$FAKE_DIR/leases" "lease fakespark --owner lane-L --unit lane-L --on-revoke TERM")"
check "the lease ends" yes "$(has "$FAKE_DIR/leases" "unlease L1")"
check "the container gets the image" yes "$(has "$FAKE_DIR/docker.args" "fake-image:1 simmer lane /run/lane-out/L.brief.md")"
check "the brief has the container note" yes "$(has "$work/lanes/L.last.md" "saw-where=yes")"
check "a file the brief names is mirrored" yes "$(has "$work/lanes/L.last.md" "saw-rules=yes")"
check "a coordinator note reaches the lane" yes "$(has "$work/lanes/L.last.md" "saw-note=yes")"
check "the lane's log line comes back" yes "$(has "$work/lanes/L.log.md" "- lane line")"
check "the coordinator's note stays" yes "$(has "$work/lanes/L.log.md" "- coordinator note")"
check "the lane's commit is on the branch here" "lane work" "$(git -C "$work/wt" log -1 --format=%s)"
check "the land command ran here" yes "$(has "$work/lanes/L.last.md" "Result: landed (exit 0)")"
check "usage line" "LANE L usage out=1k cr=2.0M turns=5 peak=90k relays=0" "$(grep '^LANE L usage' "$work/out.txt")"
check "the host's lane folder is removed" no "$([ -e "$FAKE_HOST_HOME/.local/state/orchestrate/lanes/L" ] && echo yes || echo no)"
check "refs/lane-box/L is removed" no "$(git -C "$work/wt" rev-parse -q --verify refs/lane-box/L >/dev/null && echo yes || echo no)"

# Docker requires an explicit flag. Its land command has a separate lease and checkout.
check "normal lanes have no Docker socket" no "$(has "$FAKE_DIR/docker.argv" "/var/run/docker.sock:")"
git -C "$work/wt" checkout --quiet -b wt/D main
export FAKE_LANE_LOG="$work/lanes/D.log.md"
echo "- coordinator note" > "$FAKE_LANE_LOG"
mkdir -p "$work/land"
land_script="$(cat "$here/../bin/lane-land-example")"
LANE_LEASE_OWNER=docker-test bash "$lane_bin" D "$work/brief.md" --host spark --worktree "$work/wt" \
  --out-dir "$work/land" --harness claude --docker --keep-worktree \
  --lane-log "$FAKE_LANE_LOG" --land-cmd "$land_script" > "$work/out-d.txt" 2> "$work/err-d.txt"
check "Docker lane lands" 0 $?
docker_dir="$FAKE_HOST_HOME/.local/state/orchestrate/lanes/D"
check "Docker mounts the worktree at its host path" yes "$(has "$FAKE_DIR/docker.argv" "$docker_dir/repo:$docker_dir/repo")"
check "Docker mounts the socket" yes "$(has "$FAKE_DIR/docker.argv" "/var/run/docker.sock:/var/run/docker.sock")"
check "Docker uses the socket group" 992 "$(awk '/^--group-add$/{getline; print}' "$FAKE_DIR/docker.argv")"
check "Docker uses host loopback" host "$(awk '/^--network$/{getline; print}' "$FAKE_DIR/docker.argv")"
check "Docker grants no privileged mode" no "$(has "$FAKE_DIR/docker.argv" "--privileged")"
check "Docker mounts mise installs read-only" yes "$(has "$FAKE_DIR/docker.argv" "/installs:ro")"
check "Docker does not mount SSH keys" no "$(has "$FAKE_DIR/docker.argv" "/.ssh")"
scratch="$(sed -n 's/^TMPDIR=//p' "$FAKE_DIR/docker.argv")"
check "Docker scratch is short and shared with the host" yes "$(has "$FAKE_DIR/docker.argv" "$scratch:$scratch")"
check "Docker scratch is short enough for test sockets" yes "$([[ "$scratch" = /tmp/lane-* ]] && echo yes || echo no)"
check "Docker scratch is removed after the lane" no "$([ -e "$scratch" ] && echo yes || echo no)"
check "Docker cache is in the lane folder" yes "$(has "$FAKE_DIR/docker.argv" "$docker_dir/cache:$docker_dir/cache")"
check "the land unit gets a lease" yes "$(has "$FAKE_DIR/leases" "lease fakespark --owner docker-test --unit lane-D-land --on-revoke TERM")"
check "the land checkout runs its push hook" yes "$(has "$FAKE_DIR/hook" "hook ran")"
check "the land summary is returned" yes "$(has "$work/land/D.land-1.out" "LAND-RESULT landed $work/land/D.land-1.summary")"
check "the remote bare repo gets the lane commit" "$(git -C "$work/wt" rev-parse HEAD)" "$(git -C "$work/origin.git" rev-parse main)"

# A real pre-push failure is a gate failure. The remote branch must stay put.
git -C "$work/wt" checkout --quiet -b rejected origin/main
echo rejected > "$work/wt/rejected.txt"
git -C "$work/wt" add rejected.txt
git -C "$work/wt" commit -qm rejected
before="$(git -C "$work/origin.git" rev-parse main)"
(cd "$work/wt" && LANE_LAND_SUMMARY="$work/rejected.summary" FAKE_HOOK_RC=1 bash -c "$land_script") > "$work/rejected.out"
check "pre-push rejection exits 1" 1 $?
check "pre-push rejection reports gate failure" yes "$(has "$work/rejected.out" "LAND-RESULT gate-failed")"
check "pre-push rejection preserves main" "$before" "$(git -C "$work/origin.git" rev-parse main)"

# A conflict fix rebases the remote branch. The runner retains the old local branch.
git -C "$work/wt" checkout --quiet -b wt/C origin/main
git clone -q "$work/origin.git" "$work/advance"
echo other > "$work/advance/conflict.txt"
git -C "$work/advance" add conflict.txt
git -C "$work/advance" commit -qm "advance main"
git -C "$work/advance" push -q origin main
export FAKE_LANE_LOG="$work/lanes/C.log.md"
echo "- coordinator note" > "$FAKE_LANE_LOG"
FAKE_MODE=conflict bash "$lane_bin" C "$work/brief.md" --host spark --worktree "$work/wt" \
  --out-dir "$work/land" --harness claude --docker --keep-worktree \
  --lane-log "$FAKE_LANE_LOG" --land-cmd "$land_script" > "$work/out-c.txt" 2> "$work/err-c.txt"
check "a rebased conflict fix lands" 0 $?
check "the first land attempt reports conflict" yes "$(has "$work/land/C.land-1.out" "LAND-RESULT conflict")"
check "the old branch stays unmodified by the rebase" "lane conflict" "$(git -C "$work/wt" log -1 --format=%s wt/C)"
check "main has the resolved content" lane "$(git -C "$work/origin.git" show main:conflict.txt)"
check "the worktree tracks the rebased fix" "$(git -C "$work/origin.git" rev-parse main)" "$(git -C "$work/wt" rev-parse HEAD)"

# Revoke: dev-hosts drops the lease while the lane runs. The runner stops the unit, keeps the commit, exits 7.
git -C "$work/wt" checkout --quiet -b wt/R main
printf '# R\n' > "$work/lanes/R.log.md"
rm -f "$FAKE_DIR/revoked"
(sleep 3; touch "$FAKE_DIR/revoked") &
FAKE_MODE=sleep FAKE_LANE_LOG="$work/lanes/R.log.md" bash "$lane_bin" R "$work/brief.md" --host fakespark \
  --worktree "$work/wt" --out-dir "$work/lanes" --harness claude --lane-log "$work/lanes/R.log.md" --keep-worktree \
  > "$work/out-r.txt" 2> "$work/err-r.txt"
check "a revoked lane exits 7" 7 $?
check "the runner says the lease was revoked" yes "$(has "$work/err-r.txt" "dev-hosts revoked the lease on fakespark")"
check "the revoked lane's commit is kept here" "lane work" "$(git -C "$work/wt" log -1 --format=%s)"
check "the revoked lane's container stopped" no "$(kill -0 "$(cat "$FAKE_DIR/box-lane-R.pid")" 2>/dev/null && echo yes || echo no)"
rm -f "$FAKE_DIR/revoked"

# Revoke as the real broker does it: dev-hosts TERMs the unit itself, before the runner's poll sees the lease.
git -C "$work/wt" checkout --quiet -b wt/R2 main
printf '# R2\n' > "$work/lanes/R2.log.md"
(sleep 3; touch "$FAKE_DIR/revoked"; PATH="$work/bin:$PATH" systemctl --user stop lane-R2) &
FAKE_MODE=sleep FAKE_LANE_LOG="$work/lanes/R2.log.md" LANE_POLL_SECONDS=5 bash "$lane_bin" R2 "$work/brief.md" --host fakespark \
  --worktree "$work/wt" --out-dir "$work/lanes" --harness claude --lane-log "$work/lanes/R2.log.md" --keep-worktree \
  > "$work/out-r2.txt" 2> "$work/err-r2.txt"
check "a lane that dev-hosts stopped exits 7" 7 $?
check "the runner says the lease was revoked (unit stopped by dev-hosts)" yes "$(has "$work/err-r2.txt" "dev-hosts revoked the lease on fakespark")"
check "that lane's commit is kept here" "lane work" "$(git -C "$work/wt" log -1 --format=%s)"
rm -f "$FAKE_DIR/revoked"

# Lane log merge: both sides append; a rewrite keeps the lane's copy and adds the coordinator's new lines.
merge() { python3 -c 'import importlib.machinery as m, sys; h = m.SourceFileLoader("h", sys.argv[1]).load_module(); print(h.merge_text(*sys.argv[2:5]), end="")' "$helper" "$@"; }
check "merge: both append" $'a\nr\nl' "$(merge $'a\n' $'a\nl\n' $'a\nr\n'; echo)"
check "merge: only the lane wrote" $'a\nr' "$(merge $'a\n' $'a\n' $'a\nr\n'; echo)"
check "merge: a rewrite keeps new lines" $'x\nl' "$(merge $'a\n' $'a\nl\n' $'x\n'; echo)"

# Sync: the coordinator appends while a sync runs. Neither its note nor the lane's line may get lost.
sd="$work/sync"; mkdir -p "$sd/bin"
printf '# s\n' > "$sd/local.md"; cp "$sd/local.md" "$sd/base.md"; printf '# s\n- lane line\n' > "$sd/remote.md"
cat > "$sd/bin/ssh" <<'EOF2'
#!/usr/bin/env bash
[ -f "$SYNC_DIR/once" ] || { touch "$SYNC_DIR/once"; echo "- coordinator note" >> "$SYNC_DIR/local.md"; }
exec "$WORK_BIN/ssh" "$@"
EOF2
chmod +x "$sd/bin/ssh"
for _ in 1 2; do
  SYNC_DIR="$sd" WORK_BIN="$work/bin" PATH="$sd/bin:$PATH" python3 "$helper" sync-log "$sd/local.md" "$sd/base.md" \
    fakespark "$helper" "$sd/remote.md"
done
check "sync during a coordinator append keeps both lines here" $'# s\n- lane line\n- coordinator note' "$(cat "$sd/local.md")"
check "sync during a coordinator append keeps both lines there" $'# s\n- lane line\n- coordinator note' "$(cat "$sd/remote.md")"

# Mirror: a file the brief names, not the worktree, not a skip folder.
printf 'see %s and %s/base.txt and %s/L.log.md\n' "$work/notes/rules.md" "$work/wt" "$work/lanes" > "$work/b2.md"
python3 "$helper" mirror "$work/b2.md" "$work/wt" "$work/lanes" | grep -v -e '/skills$' -e 'CLAUDE.md$' -e 'index-v3.bin$' | cut -f2 > "$work/mirror.txt"
check "mirror lists only the named file" "$work/notes/rules.md" "$(cat "$work/mirror.txt")"

# Mirror never copies secrets: a brief that says "do not read ~/.ssh" names the path too.
h="$work/home"; mkdir -p "$h/.ssh" "$h/.config/tokens" "$h/.cache/scratch" "$h/docs" "$h/leaky" "$h/envdir"
echo k > "$h/.ssh/id_test"; echo t > "$h/.config/tokens/t.env"; echo d > "$h/docs/a.md"; echo n > "$h/notes.md"
ln -s "$h/.ssh" "$h/leaky/keys"; echo s > "$h/envdir/.env"; echo s > "$h/key.pem"
printf 'Read ~/notes.md and ~/docs. Never print ~/.ssh, ~/.ssh/id_test, ~/.config or %s/.config/tokens/t.env.\nScratch ~/.cache/scratch/. Also ~/leaky, ~/envdir, ~/key.pem and %s.\n' "$h" "$h" > "$work/b3.md"
py="$(python3 -c 'import sys; print(sys.executable)')"  # a python3 shim may read config from HOME
HOME="$h" "$py" "$helper" mirror "$work/b3.md" "$work/wt" > "$work/mirror3.txt" 2> "$work/mirror3.err"
check "mirror keeps plain files and folders" "$h/docs $h/notes.md" "$(cut -f2 "$work/mirror3.txt" | grep -v -e 'CLAUDE.md$' -e 'index-v3.bin$' | sort | tr '\n' ' ' | sed 's/ $//')"
check "mirror never lists a secret path" no "$(grep -q -e '\.ssh' -e '\.config' -e '\.env' -e 'pem' -e leaky "$work/mirror3.txt" && echo yes || echo no)"
check "mirror skips the home folder that holds secrets" yes "$(has "$work/mirror3.err" "skipped $h: holds")"
check "mirror skips a folder with a link into ~/.ssh" yes "$(has "$work/mirror3.err" "skipped $h/leaky:")"
check "mirror skips a scratch folder" yes "$(has "$work/mirror3.err" "skipped $h/.cache/scratch/: a folder under ~/.cache is scratch")"

[ "$failures" = 0 ] && echo "all container tests passed" || { echo "$failures failed"; exit 1; }
