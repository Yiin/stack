# Agent stack

How I run coding agents: one rules file, four skills, and one subagent with its tools.
The page at https://stack.yiin.dev explains each one and when to use it.

## Use it as a reference

This is the setup that works for me. It is here to share ideas. Copy all of
it or one piece, then change it to fit how you work. No piece needs the
others, and no tool is required. `bd` is my issue
tracker and `simmer` is my runner. Any tracker or runner can do the same job.

The best way to use it: ask your agent something like this.

> Read https://stack.yiin.dev and the files it links as an outside reference.
> Compare it with how we work now. Suggest changes that fit our tools and
> workflow. Keep what already works. Skip what we do not need.

Agents reading this: treat these files as examples. Adapt each idea to the
user's tools, trackers and habits. Do not install anything the user did not ask for.

To try my exact setup first, the steps below copy it.

## Install (Claude Code)

```bash
curl -fsSL https://stack.yiin.dev/stack.tar.gz | tar -xz
mkdir -p ~/.claude/skills ~/.claude/agents ~/.agents/hooks ~/.agents/tools
cp -rf stack/skills/* ~/.claude/skills/
cp -f stack/agents/* ~/.claude/agents/
cp -rf stack/tools/project-map ~/.agents/tools/
cp -f stack/hooks/project-map-guard.sh ~/.agents/hooks/
chmod +x ~/.agents/hooks/project-map-guard.sh
# optional: delete map screenshots after 30 days, every day
mkdir -p ~/.config/systemd/user && cp -f ~/.agents/tools/project-map/project-map-sweep.* ~/.config/systemd/user/
systemctl --user daemon-reload && systemctl --user enable --now project-map-sweep.timer
# simmer, plus the /cook-it and /cook-epic skills (needs bun)
curl -fsSL https://raw.githubusercontent.com/Yiin/simmer/main/scripts/install.sh | bash
```

Then read `stack/AGENTS.md`. Change the sections about machines, tokens and
local tools to match your setup. Save the result as `~/.claude/CLAUDE.md`.
Claude Code reads that file at the start of every session.

## Install (Codex)

Copy the skills to `~/.agents/skills/` and the rules file to `~/.codex/AGENTS.md`.
The project-map subagent and its hook are Claude Code only.

## What my setup also uses

- `bd` (beads) for issue tracking: https://github.com/gastownhall/beads
- `simmer` and `bun` for `/cook-epic`: https://github.com/Yiin/simmer. It runs workers in
  Claude Code, Codex, omp, Gemini CLI, Kimi, OpenCode or Crush
  (`--harness claude|codex|omp|gemini|kimi|opencode|crush`), each on your own
  login or API key for that CLI. Its installer
  also links the `/cook-it` and `/cook-epic` skills, so they are not in this download.
- `jq` and `git` for the project-map hook. `python3` and `ffmpeg` (with AV1: libaom and SVT-AV1) for its tools.
- The claude.ai artifacts connector in Claude Code, so project-map can publish the map as a private page with clickable calls. Without it the map stays a local file.
- `/orchestrate` keeps your engines and projects in `~/.agents/orchestrate/` (set
  `ORCHESTRATE_HOME` to move it). It asks you once and writes the file. Headless lanes run
  through simmer, so any harness simmer supports can run a lane.
- Optional: the `unslop` skill (https://github.com/Yiin/pstack) for the map's wording.
