# Agent stack

Five pieces for Claude Code: one rules file, four skills, and one subagent.
The page at https://stack.yiin.lt explains each one and when to use it.

## Install (Claude Code)

```bash
curl -fsSL https://stack.yiin.lt/stack.tar.gz | tar -xz
mkdir -p ~/.claude/skills ~/.claude/agents ~/.claude/hooks
cp -rf stack/skills/* ~/.claude/skills/
cp -f stack/agents/* ~/.claude/agents/
cp -f stack/hooks/project-map-guard.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/project-map-guard.sh
```

Then read `stack/AGENTS.md`. Change the sections about machines, tokens and
local tools to match your setup. Save the result as `~/.claude/CLAUDE.md`.
Claude Code reads that file at the start of every session.

## Install (Codex)

Copy the skills to `~/.agents/skills/` and the rules file to `~/.codex/AGENTS.md`.
The project-map subagent and its hook are Claude Code only.

## What you also need

- `bd` (beads) for issue tracking: https://github.com/gastownhall/beads
- `simmer` for `/cook-epic`. It is a private tool. Ask for access.
- `jq` and `git` for the project-map hook.
- Optional: the Codex CLI, for Codex lanes in `/orchestrate`.
- Optional: the `ui-ux-pro-max` skill (https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)
  and the `unslop` skill (https://github.com/Yiin/pstack) for project-map.
