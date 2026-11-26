#!/usr/bin/env bash
# Tests for bin/worktree retire/clean and the retire step in bin/lane. Uses temporary repos only.
#   bash ~/.agents/skills/orchestrate/tests/worktree.test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# Through bash, as bin/lane and bin/hygiene call them: a file sync tool can drop the executable bit.
wt() { bash "$here/../bin/worktree" "$@"; }
lane() { bash "$here/../bin/lane" "$@"; }
work="$(mktemp -d)"
sleepers=()
cleanup() { for p in "${sleepers[@]}"; do kill "$p" 2>/dev/null; done; rm -rf "${work:?}"; }
trap cleanup EXIT

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_CONFIG_GLOBAL=/dev/null
git init --quiet --bare -b main "$work/origin.git"
git clone --quiet "$work/origin.git" "$work/repo" 2>/dev/null
printf 'node_modules/\n.env\n*.log\n.beads/*\n!.beads/config.yaml\n' > "$work/repo/.gitignore"
git -C "$work/repo" add .gitignore && git -C "$work/repo" commit --quiet -m init && git -C "$work/repo" push --quiet origin main
git -C "$work/repo" remote set-head origin main

# The root is a symlink to the real folder, as on a host that keeps worktrees on another disk.
mkdir -p "$work/real-root"
ln -s "$work/real-root" "$work/root"
export ORCHESTRATE_WT_ROOT="$work/root"

failures=0
check() { # name expected actual
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$2', got '$3'"; failures=$((failures + 1)); fi
}
new() { wt new "$work/repo" "$1" >/dev/null 2>&1; echo "$work/real-root/repo/$1"; }
outcome() { wt retire "$1" | awk '{print $1}'; } # removed | kept
land() { # commits a file in the worktree and pushes it to the trunk
  echo "$2" > "$1/$2" && git -C "$1" add "$2" && git -C "$1" commit --quiet -m "$2" && git -C "$1" push --quiet origin HEAD:main 2>/dev/null
}

d="$(new landed)"; land "$d" a.txt
check "landed and clean: removed" removed "$(outcome "$d")"
check "landed and clean: folder gone" no "$([ -e "$d" ] && echo yes || echo no)"
check "landed and clean: branch deleted" "" "$(git -C "$work/repo" branch --list wt/landed)"

d="$(new fresh)"
check "fresh worktree with no changes: removed" removed "$(outcome "$d")"

d="$(new unlanded)"; echo x > "$d/b.txt"; git -C "$d" add b.txt; git -C "$d" commit --quiet -m b
check "unlanded commit: kept" kept "$(outcome "$d")"

d="$(new modified)"; land "$d" c.txt; echo changed > "$d/c.txt"
check "modified tracked file: kept" kept "$(outcome "$d")"

d="$(new untracked)"; land "$d" d.txt; echo new > "$d/notes.md"
check "untracked file: kept" kept "$(outcome "$d")"

d="$(new dotenv)"; land "$d" e.txt; echo SECRET=1 > "$d/.env"
check "ignored .env: kept" kept "$(outcome "$d")"
check "ignored .env: reason names it" yes "$(wt retire "$d" | grep -q '\.env' && echo yes || echo no)"

d="$(new deps)"; land "$d" f.txt; mkdir -p "$d/node_modules/x" "$d/apps/web/node_modules"; echo 1 > "$d/node_modules/x/i.js"; echo 1 > "$d/debug.log"
mkdir -p "$d/tools/gen/node_modules/y"; echo 1 > "$d/tools/gen/node_modules/y/i.js"
check "only node_modules and logs ignored: removed" removed "$(outcome "$d")"

d="$(new beads)"; land "$d" o.txt; mkdir -p "$d/.beads"; touch "$d/.beads/last-touched" "$d/.beads/.sync-head" "$d/.beads/.beads.gate.lock"
check "only bd runtime files ignored: removed" removed "$(outcome "$d")"
d="$(new beadsdb)"; land "$d" p.txt; mkdir -p "$d/.beads/embeddeddolt"; echo db > "$d/.beads/embeddeddolt/data"
check "embedded beads database ignored: kept" kept "$(outcome "$d")"

d="$(new folded)"; land "$d" n.txt; mkdir -p "$d/scratch/node_modules"; echo 1 > "$d/scratch/node_modules/i.js"; echo K=1 > "$d/scratch/.env"
check "ignored .env inside a folded folder: kept" kept "$(outcome "$d")"

# Repos ignore the bd gate files and husky hooks at the root; this repo does so through info/exclude.
printf '/.beads.gate.lock\n/.sync-head\n/.husky/_/\n' >> "$work/repo/.git/info/exclude"
d="$(new rootbd)"; land "$d" q.txt
mkdir -p "$d/.husky/_"; touch "$d/.beads.gate.lock" "$d/.sync-head" "$d/.husky/_/husky.sh" "$d/.husky/_/h"
check "only root bd gate files and husky hooks ignored: removed" removed "$(outcome "$d")"

d="$(new busy)"; land "$d" g.txt; mkdir -p "$d/sub"
(cd "$d/sub" && exec sleep 300) & sleepers+=($!)
sleep 0.2
check "process working inside: kept" kept "$(outcome "$d")"
check "process working inside via symlinked path: kept" kept "$(outcome "$work/root/repo/busy")"

check "main checkout: kept" kept "$(outcome "$work/repo")"

d="$(new nofetch)"; land "$d" h.txt
git -C "$d" remote set-url origin "$work/missing.git"
check "failed fetch: kept" kept "$(outcome "$d")"
git -C "$d" remote set-url origin "$work/origin.git"

# clean walks the symlinked root, removes only the landed worktree, and keeps the rest.
d="$(new sweep)"; land "$d" i.txt
dry="$(wt clean)"
check "clean dry run sees worktrees under a symlinked root" yes "$(grep -q "^remove  $d " <<<"$dry" && echo yes || echo no)"
check "clean dry run removes nothing" yes "$([ -d "$d" ] && echo yes || echo no)"
applied="$(wt clean --apply)"
check "clean --apply removes the landed worktree" no "$([ -e "$d" ] && echo yes || echo no)"
check "clean --apply removes the failed-fetch worktree once fetch works" no "$([ -e "$work/real-root/repo/nofetch" ] && echo yes || echo no)"
for kept in unlanded modified untracked dotenv folded busy; do
  check "clean --apply keeps $kept" yes "$([ -d "$work/real-root/repo/$kept" ] && echo yes || echo no)"
done

# salvage saves ignored files that a build does not recreate, and never overwrites an earlier salvage.
export ORCHESTRATE_SALVAGE="$work/salvage"
out1="$(wt salvage "$work/real-root/repo/dotenv")"
check "salvage removes the worktree" no "$([ -e "$work/real-root/repo/dotenv" ] && echo yes || echo no)"
check "salvage keeps the branch" wt/dotenv "$(git -C "$work/repo" branch --list wt/dotenv | tr -d ' *')"
check "salvage tars the ignored secret file" yes "$(tar -tzf "$out1/untracked.tgz" 2>/dev/null | grep -qx '.env' && echo yes || echo no)"
git -C "$work/repo" worktree add --quiet -b wt/dotenv-again "$work/real-root/other/dotenv" main
out2="$(wt salvage "$work/real-root/other/dotenv")"
check "second salvage of one lane name on one day gets its own folder" "$out1-2" "$out2"

git -C "$work/repo" worktree add --quiet --detach "$work/real-root/repo/detached" main
echo y > "$work/real-root/repo/detached/y.txt"; git -C "$work/real-root/repo/detached" add y.txt
git -C "$work/real-root/repo/detached" commit --quiet -m detached-work
head="$(git -C "$work/real-root/repo/detached" rev-parse HEAD)"
out3="$(wt salvage "$work/real-root/repo/detached")"
check "salvage of a detached HEAD keeps its commit on a branch" "$head" "$(git -C "$work/repo" rev-parse "salvage/$(basename "$out3")" 2>/dev/null)"

# salvage-idle skips worktrees with recent activity and checks its argument.
check "salvage-idle skips recent worktrees" 0 "$(wt salvage-idle 1 | grep -c .)"
check "salvage-idle rejects a missing day count" 2 "$(wt salvage-idle >/dev/null 2>&1; echo $?)"

# bin/lane: fake simmer and a systemctl that has no user session, so the lane runs in this shell.
mkdir -p "$work/bin" "$work/out"
printf '#!/usr/bin/env bash\nexit 1\n' > "$work/bin/systemctl"
cat > "$work/bin/simmer" <<'SIM'
#!/usr/bin/env bash
# Fake simmer: writes a report next to --out and exits with $FAKE_RC.
# bin/lane probes `simmer lane --help` first.
[ "$*" = "lane --help" ] && { echo "  --harness <name>  claude or codex"; exit 0; }
while [ $# -gt 0 ]; do [ "$1" = --out ] && out="$2"; shift; done
echo report > "$out"; exit "${FAKE_RC:-0}"
SIM
chmod +x "$work/bin/systemctl" "$work/bin/simmer"
echo brief > "$work/brief.md"
run_lane() { # lane-name worktree rc [extra args]
  local name="$1" dir="$2" rc="$3"; shift 3
  PATH="$work/bin:$PATH" FAKE_RC="$rc" lane "$name" "$work/brief.md" --worktree "$dir" --out-dir "$work/out" --harness claude "$@" >/dev/null 2>&1
}
d="$(new lane-ok)"; land "$d" j.txt; run_lane L1 "$d" 0
check "lane exit 0, landed: worktree removed" no "$([ -e "$d" ] && echo yes || echo no)"
d="$(new lane-fail)"; land "$d" k.txt; run_lane L2 "$d" 1
check "lane exit 1: worktree kept" yes "$([ -d "$d" ] && echo yes || echo no)"
d="$(new lane-keep)"; land "$d" l.txt; run_lane L3 "$d" 0 --keep-worktree
check "lane --keep-worktree: worktree kept" yes "$([ -d "$d" ] && echo yes || echo no)"
d="$(new lane-dirty)"; land "$d" m.txt; echo wip > "$d/m.txt"; run_lane L4 "$d" 0
check "lane exit 0 with uncommitted work: worktree kept" yes "$([ -d "$d" ] && echo yes || echo no)"
check "lane exit 0 with uncommitted work: work intact" wip "$(cat "$d/m.txt")"

echo
if [ "$failures" -eq 0 ]; then echo "all passed"; else echo "$failures failed"; exit 1; fi
