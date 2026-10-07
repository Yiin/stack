<!--
Shared copy. Machine names, IPs and personal tools are placeholders or examples.
Replace the This Machine, Issue Tracking, Tokens and Local Dev Tools sections with your own setup.
-->

## This Machine

This file is synced to every machine, so it never names the current one. Before doing anything machine-specific (SSH, rsync, deploys, paths under /var/www, systemd), establish where you are: run `hostname` and `tailscale status --self`. Never assume the machine from the working directory or from this file.

The machines are `<desktop>`, `<laptop>`, and `<vps>` (the server that hosts shared services). List yours here, with one line each.

<!-- BEGIN WRITING STYLE v:2 -->
## How to Report Back to Me (ASD-STE100 + Zinsser)

Always answer me in Simplified Technical English (ASD-STE100). This applies to every reply: summaries, findings, explanations, plans, status updates, and error reports. It never expires. Re-read your draft before you send it. If it breaks a rule below, rewrite it.

### ASD-STE100

- Write short sentences. 20 words or less. One fact per sentence.
- Use simple words with one meaning each. One word for one idea. Never cycle synonyms.
- Use active voice.
- Write short paragraphs. One topic per paragraph.
- Lead with the verdict. Order the rest by importance. STE100 flattens emphasis, so order must carry it.
- Keep file paths, commands, code, and numbers exact. Simplify only the prose around them.

### Zinsser's four principles

1. Simplicity: cut every word that does no work. Say the thing directly.
2. Brevity: give the shortest reply that is complete. Stop when the answer is done.
3. Clarity: one reading must be enough. Name the thing. Do not gesture at it.
4. Humanity: write like a person to a person. No hype, no filler, no apology loops.

### Session reports: bird's eye only

I run 5+ projects with 10+ sessions each. I must understand any session in 30 seconds. Give me the view from above, not the work log.

Answer four things, in this order:

1. What this session is about. One line.
2. What you did. Two or three lines. Outcomes, not steps.
3. Do I need to act? Say yes or no. If yes, name the decision you need from me.
4. What is next. One line, or "nothing".

Leave the technicalities out by default: no file-by-file lists, no command transcripts, no step replays, no tables of what changed. I will ask when I want them.

### Do not

- Do not repeat. One fact appears once. Do not add a summary that restates the body.
- Do not pad: "essentially", "basically", "it is worth noting", "as you can see", "in order to".
- Do not hype: "robust", "seamless", "powerful", "comprehensive", "significantly".
- Do not use em dashes for asides. Use a period or a comma.
- Do not write a preamble. The first sentence carries the verdict.
- Do not explain what you are about to explain. Explain it.
<!-- END WRITING STYLE -->

## Writing for Other Humans

For any prose that outlives the conversation — documentation, guides, PR descriptions, commit messages, error messages, UI copy, changelogs — follow the pstack `unslop` skill (`~/.agents/skills/unslop/SKILL.md`), and `technical-writing` for docs: plain casual words, lede first, active voice, no puffery, no em dashes. Its numbered rules are the full AI-tell catalog for editing existing text.

## Package Management

- Use `bun` as the default package manager unless a project explicitly uses something else (check for lockfiles).
- Never use `npm` in a bun project — it creates a conflicting `package-lock.json`.

## Core Principles

- Prefer clean, maintainable solutions over quick hacks. Flag any shortcuts with a plan to eliminate them.
- Don't ask for manual inputs — execute what you can yourself, only ask when you can't procure or reach something.
- Question vague requirements and propose alternatives when the requested approach has clear downsides.
- Clarity over cleverness, simplicity over shortcuts, structure over sprawl.
- Never add backwards compatibility unless explicitly asked. Just change the code.
- Keep implementation simple — no confusing abstractions. Code should be obvious in what it does and why.

## Never Estimate Effort or Time

Do not give time or effort estimates for tasks ("half a day", "a few hours", "small change", "quick fix"). The estimates are systematically wrong — typically off by an order of magnitude (guessed "half a day" for what was actually ~3 minutes of agent work). If size/scope context matters for a decision, describe the *scope* concretely (files touched, operations required) rather than guessing duration. Let the user decide whether that scope is worth doing.

## Git Safety — Multiple Agents in Parallel

Multiple Claude agents work concurrently in the same repos. Treat the working tree and stash as shared state, not as your own scratchpad.

- **Never run destructive git commands without explicit confirmation**, even when they seem safe in isolation: `git reset --hard`, `git checkout -- <files>`, `git restore`, `git clean -fd`, `git stash drop/clear`, `git push --force`, `git branch -D`, `git rebase -i`, force-deleting tags. Another agent's uncommitted edits could be silently destroyed.
- **Avoid `git stash` as a "let me check baseline" tool.** It captures other agents' uncommitted work too, and `git stash pop` can produce unrelated merge conflicts in files you never touched. If you need a clean checkout for comparison, use a separate worktree (`git worktree add`).
- **Commit your own work early** to lock it in before another agent's reset cycle wipes the working tree. Do not rely on uncommitted edits surviving across more than a few minutes.
- If you find yourself reaching for a destructive command to "clean up" a confusing state — stop and ask. The state may be another agent's work-in-progress.

## Context Management

Utilize sub-agents to preserve main thread context from redundant information.

## Use Skills for Context

Before working with code or research in a domain area, **always invoke the relevant skill first**. Do not rely on memory or guesswork when a skill exists.

## Issue Tracking

Projects use **bd** (beads) for issue tracking. Run `bd prime` for full workflow context.

> **Architecture in one line:** Issues live in one shared Dolt SQL server on
> `<vps>` at `<vps-tailnet-ip>:3306`, tailnet-only, one database per project.
> Reads and writes are live. A write on one machine is readable on every other
> machine at once. There is no push and no pull.
>
> A project joins the server through two files: `.beads/metadata.json`
> (`dolt_mode: server`, `dolt_database`, `project_id`, host, user) and
> `.beads/config.yaml` (the `dolt:` host/port/user block). A project missing
> those files falls back to embedded mode and syncs with nothing.
>
> Server mode needs the tailnet. Offline means no `bd`.

Run `bd dolt show` to see the database and mode of the current project. Check it
before you trust `bd list`.

Quick reference:

```bash
bd ready                # Find available work
bd show <id>            # View issue details
bd update <id> --claim  # Claim work
bd close <id>           # Complete work
bd prime                # Refresh Beads context
```

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists.
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files.

## Tokens

Centralized age-encrypted token store at `~/.config/tokens/tokens.env.age`, with the unlock key beside it. Never create a plaintext `tokens.env`. The `api-tokens` skill has the full workflow.

- **Read a token:** `get-token KEY` (outputs raw value, no newline)
- **Set a token:** `get-token --set KEY VALUE` (adds or updates)
- **List tokens:** `get-token --list`
- **Edit tokens:** `get-token --edit`
- **Sync:** Syncthing folder `tokens` shares the store between all machines. `token-sync status|push|pull` is a manual rsync fallback for when Syncthing is down.

## Local Dev Tools

### caddy-local

CLI/TUI for managing `.local` dev domains via Caddy reverse proxy.

- **Command:** `caddy-local` (at `~/.local/bin/caddy-local`)
- **Quick usage:** `caddy-local add myapp 3000` → proxies `myapp.local` to `:3000`
- **DNS:** `*.local` resolves to `127.0.0.1` via dnsmasq (port 5354), routed by systemd-resolved. Config: `/etc/dnsmasq.d/local.conf`. Do NOT add `.local` entries to `/etc/hosts`.
- **Details:** `~/.local/share/system-docs/dev-tools/caddy-local.md`, `~/.local/share/system-docs/network/dns.md`, system-management skill

## Git

`~/.config/git/config` wires difftastic in as a difftool. `git dft` shows structural diffs for humans. Plain `git diff` prints normal unified output, which is what tooling should parse. If a repo config sets `diff.external` and `git diff` prints structural output, pass `--no-ext-diff` to get unified output back.

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging on confirmation prompts.

Shell commands like `cp`, `mv`, and `rm` may be aliased to include `-i` (interactive) mode on some systems, causing the agent to hang indefinitely waiting for y/n input.

**Use these forms instead:**
```bash
# Force overwrite without prompting
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file

# For recursive operations
rm -rf directory            # NOT: rm -r directory
cp -rf source dest          # NOT: cp -r source dest
```

**Other commands that may prompt:**
- `scp` - use `-o BatchMode=yes` for non-interactive
- `ssh` - use `-o BatchMode=yes` to fail instead of prompting
- `apt-get` - use `-y` flag
- `brew` - use `HOMEBREW_NO_AUTO_UPDATE=1` env var

## Safe Variables in Destructive Commands

Never put a bare variable in a path given to `rm`, `mv`, `cp -f`, `rsync --delete`, `find -delete`, or `chmod/chown -R`. An empty variable turns `rm -rf $DIR/$name` into `rm -rf /`. Guard every variable with `${VAR:?}` and quote it:

```bash
rm -rf "${dir:?}/${name:?}"   # NOT: rm -rf $dir/$name
rm -f "${tmp:?}"              # NOT: rm -f $tmp
```

Prefer a literal path when you know it. This applies to scripts you write too.

## Wait Loops

Never wait with `until ! pgrep -f "<pattern>"`. The loop's own shell command line contains the pattern, so `pgrep -f` matches the loop itself and it never ends. Wait on a PID (`while kill -0 "$pid"; do sleep 15; done`), on a marker line in a log file, or on the background task's completion notice. Give every wait loop a `timeout`.

## Project Map

The `project-map` agent draws `.project-map/index.html` in the project. The map is the shared answer to "where are we?".

- Before you work alone for a long stretch, start `project-map` in the background. If `~/.claude/agent-memory/project-map/MEMORY.md` has no `style:` line, run it in the foreground instead, so it can ask me.
- After each milestone, run `project-map` again to update the map.
- When I ask "where are we?", answer from `.project-map/state.json` and the map. If the map is older than the last commit, update it first.
- Do the map's suggested next step, unless I gave a different order.
- When a choice needs me, send it to `project-map` with the options, a default, and what you will work on meanwhile. It goes in the map under "Needs your call". Do not wait for my answer. Continue with the default. If I answer later, change course.
