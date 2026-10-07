# Lane brief template

Fill every section. An agent with no memory of the conversation must be able to do the right thing from this text alone. Delete a section only when it truly does not apply.

```
You are lane <CODE> (<short title>) for <project>. Read the shared lane rules first: <path to lane-rules.md>. They apply in full.

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
- <tests and gates that must pass before merge>

## Other lanes running now
- <LANE>: edits <files>. Do not touch them. Merge master often.

## Delivery
- Worktree /<wt-root>/<lane>, branch wt/<lane>. Log docs/<area>/progress/<CODE>.md with timestamps.
- Commit early. Merge with the project's merge tool after the gates pass.
- Close your beads. File beads for follow-ups.
- Review page: an HTML Artifact built from a NEW scratchpad folder `<lane>-review/`.
- Do not deploy. Remove your worktree and editor when done.
- Do not end your turn to wait. Do not spawn subagents.

## Report
Simplified Technical English, verdict first. Include: what changed for the player, before/after numbers, gates and their results, merge SHA, review link, follow-up beads, and any decision you need from the coordinator, with your recommendation.
```
