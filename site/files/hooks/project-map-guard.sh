#!/bin/bash
# PreToolUse guard for the project-map agent. Allows Write/Edit only inside
# one map folder <repo root>/.project-map/<slug>/, the hub files
# <repo root>/.project-map/index.html and maps.html, and the agent's own
# memory folder. Top-level legacy-map paths (.work, evidence, state.json, ...)
# are blocked, so the old one-map-per-repo layout cannot come back.

input=$(cat)

file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')

root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")
target=$(realpath -m "$file_path")
memory=$(realpath -m "$HOME/.claude/agent-memory/project-map")
maps="$root/.project-map"

allow() { exit 0; }

case "$target" in
  "$memory"/*) allow ;;
  "$maps"/index.html|"$maps"/maps.html) allow ;;
  "$maps"/.work/*|"$maps"/evidence/*) ;;
  "$maps"/*/*) allow ;;
esac

cat <<JSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"project-map writes only to $maps/<slug>/, the hub ($maps/index.html or maps.html), and its memory folder. Blocked: $target"}}
JSON
exit 0
