# Lane rules template

Start a project's lane rules file from this list. Keep it short. Add a rule each time an efficiency review or an owner correction finds a repeat problem, and date owner rules.

```
# <project> lane rules (coordinator, <date>)
Every lane agent follows these rules. Read them before you act.

- Repo: <path>. Work only in your own worktree under <wt-root>/<lane>.
- Run heavy tools only through the project wrappers: <list>. Never open a window on the owner's desktops.
- Wrap long runs in `timeout`. Wait on PIDs or log markers. Never wait with `until ! pgrep -f "<pattern>"`.
- Guard and quote every variable in rm, mv, cp -f, rsync, find -delete, chmod/chown -R: "${dir:?}/${name:?}".
- No destructive git: no reset --hard, checkout --, restore, clean, stash, branch -D, force push. Never `git add -A`. Never print tokens. Never commit .env files.
- Never write in protected worktrees (<list>) or in another running lane's worktree. Do not kill processes you did not start.
- The main checkout holds other agents' uncommitted files. Do not touch them.
- Commit early and often. Keep a timestamped lane log. Merge to the main branch with <merge tool> after your gates pass.
- Licenses: <owner policy>. Record every outside source with URL and license in <files>.
- Use bd for tracking: claim your bead, close it when done, file beads for follow-ups.
- Only release lanes deploy, and only with <deploy tool>.
- Review pages: an HTML Artifact built from a NEW scratchpad folder named for your lane. Never overwrite another lane's review folder.
- Report in Simplified Technical English, verdict first. Keep interim stop messages to one line.
- Waiting: do not end your turn to wait for a run. Wait inside one Bash call (PID or log-marker loop with timeout, up to 10 min per call). End your turn only with the final report or a real blocker.
- Subagents: do not spawn your own subagents. The coordinator shares a limit of 20 running agents. Do research and checks yourself, in sequence.
- <owner quality rules, dated>
```
