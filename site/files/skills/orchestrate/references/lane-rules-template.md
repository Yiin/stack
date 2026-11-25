# Lane rules template

Each project keeps its lane rules in `$ORCHESTRATE_HOME/projects/<project>/lane-rules.md`. Every brief points to this file, and the lane reads it first. It holds the rules every lane follows ("Rules for every lane", copied unchanged from below), then what is specific to the project. Briefs do not repeat these rules, so each lane reads them once.

Keep the file short. Add a rule each time an efficiency review or an owner correction finds a repeat problem in this project, and date owner rules. When this template's "Rules for every lane" block changes, copy the new block into each project's lane rules.

```
# <project> lane rules (coordinator, <date>)
Every lane agent follows these rules, together with the rules in its brief.

## Rules for every lane
- You run unattended. Nobody answers questions mid-run. Decide inside your brief and these rules. Write any open question, with your recommendation, into your final report.
- Do not stop early. Work until the scope is done and landed (or READY-TO-LAND, when the runner lands), or until a real blocker.
- Context costs on every turn: each turn rereads the whole conversation. Read only the doc sections your brief names. Load only the skills your brief names. Read files in parts when you need only parts.
- Command output goes to a file, not into the conversation: `cmd > <scratch>/<name>.log 2>&1`. Then read a summary of at most 30 lines plus the failures (`tail -n 30`, `grep -n -m 20 -E 'FAIL|Error'`). The same holds for test runs, e2e logs, builds and long diffs (use `git diff --stat` first).
- Waiting: do not end your turn to wait for a run. Wait inside one shell call on a PID or a log marker, with `timeout` (at most 10 min per call), and print nothing while you wait. Never wait with `until ! pgrep -f "<pattern>"`.
- Gates: run the gates your brief lists, each once. A failure gets a fix and one rerun. Do not add repeats, variants or extra matrices unless a failure points to them. Take in main at most twice: at the start and before you land. A main intake that does not touch your files needs no new gate round. Once your gates pass, land the work at once (or end with READY-TO-LAND).
- A gate fails only for a real regression or a failed measurement. When a gate cannot run for a reason outside your scope, or compares the wrong things, apply the closest sound bar, say so plainly in the log and the report, land the work, and file a bead for the gap.
- Landing: when your brief says the runner lands, do not run the land command and do not push. Commit, then end your report with the line READY-TO-LAND. The runner lands with no model watching and starts a fix agent if a gate fails.
- Subagents: a read-only search helper (an Explore-type subagent) is fine for wide searches and log triage; give it a narrow question and take its conclusion. Never start a subagent that edits files.
- Jobs on other machines: when your brief gives a host and a slot, run each job with `dev-hosts lease <host> --slot <slot>` and run `dev-hosts unlease <slot>` when you finish. Otherwise get a host from `dev-hosts pick --size <light|cpu|ram>` and lease each job (skill `use-dev-hosts`). Never hard-code host names.
- The main checkout holds other agents' uncommitted files and unpushed commits. Never edit, stash, reset, commit or push there. If you push, push only from your worktree: `git rebase origin/<trunk>`, then `git push origin HEAD:<trunk>`. When these rules enforce the release lock, take it first and push with `RELEASE_LOCK_HOLDER=<name> RELEASE_LOCK_LANE=<lane>` on the push line. Never write in another lane's worktree. Do not kill processes you did not start.
- No destructive git: no reset --hard, checkout --, restore, clean, stash, branch -D, force push. Never `git add -A` or `git add .`; add your files by name.
- Guard and quote every variable in rm, mv, cp -f, rsync, find -delete, chmod/chown -R: "${dir:?}/${name:?}".
- Never print tokens. Never commit .env files.
- bd: claim your beads, close them with the commit SHA, file one bead per real follow-up.
- Commit early and often. Keep the lane log current: a fresh agent (after a relay at the context ceiling, or a fix agent after a failed land) continues from it.
- Relay: when a hook message that starts with "SIMMER RELAY:" arrives, follow the relay rule simmer added to your brief.

## Where you work
- Repo: <path>, main branch <name>. Worktrees: ~/.local/share/agent-worktrees/<repo>/<lane>, branch wt/<lane>, made with the skill's `bin/worktree new <repo> <lane>` if the brief's worktree is missing. Then: <setup, e.g. bun install>.
- Read <repo AGENTS.md / CLAUDE.md>, the sections your brief names. They apply in full.
- Protected paths (never write): <list>.

## Gates
- Per commit: <fast checks>.
- Before you land: <full gate>.
- Known failures on main: <test and bead>; not yours.

## Landing
- <the land command, and whether lanes run it or end with READY-TO-LAND> OR <commit only; never push; the release lane lands>.
- Only release lanes deploy, and only with <deploy tool>.

## Tools and machines
- Run heavy tools only through <wrappers>. <Which machine runs what.> Never open a window on the owner's desktops.

## Product rules
- <licenses, i18n, style, budgets; owner rules with dates>

## Routing adjustments
- <date, role: change. Evidence: ledger lines. Owner rules marked "owner", with their words.> (SKILL.md section 4; leave the section out while there are none)
```
