# Lane rules template

Each project keeps its lane rules in `$ORCHESTRATE_HOME/projects/<project>/lane-rules.md`. They hold only what is specific to the project. The rules every lane follows (waiting, gates, git safety, subagents, reports) are in the brief template; do not repeat them here.

Keep the file short. Add a rule each time an efficiency review or an owner correction finds a repeat problem in this project, and date owner rules.

```
# <project> lane rules (coordinator, <date>)
Every lane agent follows these rules, together with the rules in its brief.

## Where you work
- Repo: <path>, main branch <name>. Worktrees: ~/.local/share/agent-worktrees/<repo>/<lane>, branch wt/<lane>, made with the skill's `bin/worktree new <repo> <lane>` if the brief's worktree is missing. Then: <setup, e.g. bun install>.
- Read <repo AGENTS.md / CLAUDE.md>. They apply in full.
- Protected paths (never write): <list>.

## Gates
- Per commit: <fast checks>.
- Before you land: <full gate>.
- Known failures on main: <test and bead>; not yours.

## Landing
- <merge with <tool> after the gates pass> OR <commit only; never push; the release lane lands>.
- Only release lanes deploy, and only with <deploy tool>.

## Tools and machines
- Run heavy tools only through <wrappers>. <Which machine runs what.> Never open a window on the owner's desktops.

## Product rules
- <licenses, i18n, style, budgets; owner rules with dates>

## Routing adjustments
- <date, role: change. Evidence: ledger lines. Owner rules marked "owner", with their words.> (SKILL.md section 4; leave the section out while there are none)
```
