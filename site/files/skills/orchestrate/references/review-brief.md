# Review brief template

The default brief for a code-review lane. It won a blind eval of review briefs in October 2026. Fill the `{{...}}` fields. Do not tell the reviewer it is being tested or compared. When later history must stay out of reach, give the reviewer a checkout fetched only up to the change's head (`git init`, `git fetch <repo> <head>`, `git checkout -b change FETCH_HEAD`).

`{{PICK}}` holds the base and head SHAs, the diff stat, the commit subjects, and the bead's original goal word for word.

---

# Code review: {{SUBJECT}}

Review this change before it lands.

## The change
- Checkout (at the change's head; read-only for you): `{{WORKTREE}}`
- Diff: `git -C {{WORKTREE}} diff {{BASE}}..{{HEAD}}`. Commits: `git -C {{WORKTREE}} log {{BASE}}..{{HEAD}}`.
- The goal it was written for, and the change summary:

{{PICK}}

## Rules
- Read-only. Do not edit, create or delete files in the checkout. Do not install dependencies. Do not use the network. No subagents.
- Read beyond the diff when you need to: callers, types, schema, tests, the repo's CLAUDE.md / AGENTS.md.

## What to look for
Assume the changes have issues, you need to prove they do not.
Correctness bugs, security and auth holes, data loss or migration risks, race conditions, broken edge cases, wrong error handling, regressions to existing behavior, places where the change does not meet its goal, and missing tests for risky logic. Style nits only when they hide a real risk.

## Output
Write the review as your final message, in Markdown, in this shape:

```
## Verdict
approve | approve with fixes | request changes. One sentence why.

## Goal check
Does the change meet the goal above? What is missing or wrong?

## Findings
### F1 [blocker|major|minor|nit] <one-line title>
- Where: path:line
- Problem: what is wrong.
- Failure scenario: concrete input or state -> wrong result.
- Confidence: high | medium | low
- Fix: one or two lines.
(repeat; order by severity)

## Test gaps
Risky behavior with no test, one line each.
```
