# Lane brief template

Fill every section. An agent with no memory of the conversation, on any engine, must be able to do the right thing from this text alone. Delete a section only when it truly does not apply. Copy the "Rules for every lane" block unchanged.

```
You are lane <CODE> (<short title>) for <project>. Read the project lane rules first: <path to projects/<project>/lane-rules.md>. They apply in full, together with the rules at the end of this brief.

Beads: claim <id> (and <id>). Parent epic: <id>.

## Owner's words (verbatim)
"<exact quote, with the date>"
Screenshot: <repo path, if any>

## Goal
<one paragraph: the outcome the owner will see or feel, and the bar>

## Read first
- <design doc>
- <earlier lane log and what to take from it>
- <code area: path and what it does>

## What we already know
- <facts with numbers, so you do not re-measure them>
- <likely cause, marked "likely"; confirm it before you fix it>

## Coordinator decisions (already made, do not reopen)
- <decision and its reason>

## Scope
1. <first item; if a tool missed the owner's case, fix the tool first>
2. <next item>
Out of scope: <what not to touch; file beads for it instead>

## Proof and gates
- <before/after at the owner's camera spot or input>
- <measurements and their bars>
- <tests and gates that must pass before you land the work>

## Other lanes running now
- <LANE>: edits <files>. Do not touch them. Take in main often.

## Delivery
- Worktree <path>, branch wt/<lane>. Lane log <path>, with timestamps.
- Land the work as the project lane rules say (merge, or commit only and leave landing to the release lane).
- Review page: a self-contained `index.html` (images beside it, relative paths) in a NEW folder <path>/<lane>-review/. If your harness can publish pages, publish it and give the link. Otherwise the coordinator publishes it.
- Do not deploy. Remove your worktree when done, unless the lane rules say the coordinator does.

## Rules for every lane
- You run unattended. Nobody answers questions mid-run. Decide inside this brief and the lane rules. Write any open question, with your recommendation, into your final report.
- Do not stop early. Work until the scope is done and landed, or until a real blocker.
- Waiting: do not end your turn to wait for a run. Wait inside one shell call on a PID or a log marker, with `timeout` (at most 10 min per call). Never wait with `until ! pgrep -f "<pattern>"`.
- Gates: run the gates this brief lists, each once. A failure gets a fix and one rerun. Do not add repeats, variants or extra matrices unless a failure points to them. Take in main at most twice: at the start and before you land. A main intake that does not touch your files needs no new gate round. Once your gates pass, land the work at once.
- A gate fails only for a real regression or a failed measurement. When a gate cannot run for a reason outside your scope, or compares the wrong things, apply the closest sound bar, say so plainly in the log and the report, land the work, and file a bead for the gap.
- Do not spawn subagents.
- The main checkout holds other agents' uncommitted files. Never edit, stash, reset or commit there. Never write in another lane's worktree. Do not kill processes you did not start.
- No destructive git: no reset --hard, checkout --, restore, clean, stash, branch -D, force push. Never `git add -A` or `git add .`; add your files by name.
- Guard and quote every variable in rm, mv, cp -f, rsync, find -delete, chmod/chown -R: "${dir:?}/${name:?}".
- Never print tokens. Never commit .env files.
- bd: claim your beads, close them with the commit SHA, file one bead per real follow-up.
- Commit early and often. Keep the lane log current.

## Report
Your final message is your report. Line 1: one sentence in product words that says what changed for the user or player, with no IDs. The coordinator shows this line to the owner. Then, in short sentences, verdict first, no hype: before/after numbers, gates and their results, commit SHAs, review page path or link, beads closed and filed, and any decision you need from the coordinator with your recommendation.
```
