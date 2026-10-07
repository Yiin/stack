#!/usr/bin/env bash
# Run one Codex lane: SCRATCH=<scratchpad> REPO=<repo> WT_ROOT=<worktree root> run-lane.sh <lane> <brief-file>
# Writes $SCRATCH/codex/<lane>.last.md (final report) and <lane>.log.
# The body is one function, so bash parses it whole before it runs. Editing this file
# while lanes run cannot break them.
# Example from a real project. Copy it to projects/<project>/codex/ and set your model.
main() {
  S="${SCRATCH:?set SCRATCH to the session scratchpad dir}"
  repo="${REPO:?set REPO to the main checkout}"
  wt_root="${WT_ROOT:?set WT_ROOT to the lane worktree root}"
  lane="${1:?lane}"; brief="${2:?brief file}"; mkdir -p "$S/codex"
  wt="${wt_root:?}/${lane:?}"
  # Never run a lane in the main checkout: create the worktree when it is missing.
  if [ ! -d "$wt" ]; then
    git -C "$repo" worktree add -b "wt/${lane}" "$wt" > "$S/codex/${lane}.prepare.log" 2>&1
    [ -d "$wt" ] || { echo "CODEX LANE $lane: worktree prepare failed, see ${lane}.prepare.log"; exit 1; }
  fi
  cat "$brief" "$(dirname "$0")/footer.md" | timeout 12h codex exec -m "${CODEX_MODEL:-gpt-6.1-sol}" -c model_reasoning_effort="high" \
    --dangerously-bypass-approvals-and-sandbox -C "$wt" -o "$S/codex/${lane}.last.md" - > "$S/codex/${lane}.log" 2>&1
  rc=$?
  echo "CODEX LANE $lane exit $rc"
  tail -c 6000 "$S/codex/${lane}.last.md" 2>/dev/null
}
main "$@"; exit $?
