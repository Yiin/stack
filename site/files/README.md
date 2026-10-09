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
# simmer, plus the /cook-it and /cook-epic skills (needs bun)
curl -fsSL https://raw.githubusercontent.com/Yiin/simmer/main/scripts/install.sh | bash
```

Then read `stack/AGENTS.md`. Change the sections about machines, tokens and
local tools to match your setup. Save the result as `~/.claude/CLAUDE.md`.
Claude Code reads that file at the start of every session.

## Install (Codex)

Copy the skills to `~/.agents/skills/` and the rules file to `~/.codex/AGENTS.md`.
The project-map subagent and its hook are Claude Code only.

## What you also need

- `bd` (beads) for issue tracking: https://github.com/gastownhall/beads
- `simmer` and `bun` for `/cook-epic`: https://github.com/Yiin/simmer. It runs workers in
  Claude Code, Codex, Pi, Gemini CLI, Kimi, OpenCode or Crush
  (`--harness claude|codex|pi|gemini|kimi|opencode|crush`), each on your own
  login or API key for that CLI. Its installer
  also links the `/cook-it` and `/cook-epic` skills, so they are not in this download.
- `jq` and `git` for the project-map hook.
- `/orchestrate` keeps your engines and projects in `~/.agents/orchestrate/` (set
  `ORCHESTRATE_HOME` to move it). It asks you once and writes the file. Headless lanes run
  through simmer, so any harness simmer supports can run a lane.
- Optional: the `ui-ux-pro-max` skill (https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)
  and the `unslop` skill (https://github.com/Yiin/pstack) for project-map.
