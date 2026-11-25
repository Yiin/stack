# Lane brief template

A lane rereads its whole conversation on every turn, so every line in the brief, every file it reads and every command output it keeps costs again on each later turn. Keep the brief lean: give the lane what only this lane needs, and point to the rest.

Fill every section. An agent with no memory of the conversation, on any engine, must be able to do the right thing from this text plus the project lane rules. Delete a section only when it truly does not apply.

- The rules every lane follows live once in the project lane rules ("Rules for every lane", from `references/lane-rules-template.md`). Do not paste them into the brief. If the project's lane rules lack that block, copy it there first.
- "Read first" names the two or three doc sections this task needs, by heading or line range, not whole design folders.
- "Skills" names only the skills this task needs. Say "none" when it needs none.
- The Goal section is the paragraph a fix agent gets when landing fails (`bin/lane --land-cmd`). Write it so it stands alone.
- Pick one of the two Delivery lines: the lane lands its own work, or the runner lands it (when you start the lane with `bin/lane --land-cmd`).

```
You are lane <CODE> (<short title>) for <project>. Read the project lane rules first: <path to projects/<project>/lane-rules.md>. They apply in full, with their "Rules for every lane".

Beads: claim <id> (and <id>). Parent epic: <id>.

## Owner's words (verbatim)
"<exact quote, with the date>"
Screenshot: <repo path, if any>

## Goal
<one paragraph: the outcome the owner will see or feel, and the bar. It must stand alone.>

## Read first
- <doc>, section "<heading>" (or lines <a>-<b>): <what to take from it>
- <earlier lane log: what to take from it>
- <code area: path and what it does>
Skills: <only the ones this task needs, or "none">

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
- <the gates that must pass, each named once>

## Other lanes running now
- <LANE>: edits <files>. Do not touch them. Take in main often.

## Delivery
- Worktree <path> (under ~/.local/share/agent-worktrees/, made with the skill's `bin/worktree new`), branch wt/<lane>. Lane log <path>, with timestamps. Work only there.
- EITHER: Land the work as the project lane rules say.
- OR: The runner lands the work. Do not run the land command and do not push. When your gates pass and your work is committed, end your report with the line READY-TO-LAND. If landing then fails, a fresh fix agent gets your lane log and the land summary, so keep the log current.
- Review page: a self-contained `index.html` (images beside it, relative paths) in a NEW folder <path>/<lane>-review/. If your harness can publish pages, publish it and give the link. Otherwise the coordinator publishes it.
- Do not deploy. Remove your worktree when done, unless the lane rules say the coordinator does.

## Lane-specific rules
- <only rules that differ from or add to the project lane rules; leave the section out when there are none>

## Report
Your final message is your report. Line 1: one sentence in product words that says what changed for the user or player, with no IDs. The coordinator shows this line to the owner. Then, in short sentences, verdict first, no hype: before/after numbers, gates and their results, commit SHAs, review page path or link, beads closed and filed, and any decision you need from the coordinator with your recommendation. When the runner lands the work, the last line is READY-TO-LAND, alone on its line, and only when the work is committed and its gates pass.
```
