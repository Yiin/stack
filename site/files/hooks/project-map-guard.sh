#!/bin/bash
# PreToolUse guard for the project-map agent. Allows Write/Edit only inside
# <repo root>/.project-map/ and the agent's own memory folder.

input=$(cat)

file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')

root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")
target=$(realpath -m "$file_path")

case "$target" in
  "$root"/.project-map/*|"$HOME"/.claude/agent-memory/project-map/*) exit 0 ;;
esac

cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"project-map writes only to $root/.project-map/ and its memory folder. Blocked: $target"}}
EOF
exit 0
