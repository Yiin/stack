
## How you run (Codex lane)
- You run unattended through `codex exec`. Nobody answers questions mid-run. Decide inside the brief and the lane rules; write any open question with your recommendation into the final report.
- Do not stop early. Work until the scope is done and merged, or until a real blocker. Long runs: wait inside one shell call with `timeout` (PID or log-marker loop). Never `until ! pgrep -f`.
- The lane rules file is in the coordinator scratchpad; read it first. Ignore its line about Artifacts: you cannot publish them. Instead write your review page as a self-contained `index.html` (images beside it, relative paths) in a NEW folder `<coordinator scratchpad>/<lane>-review/` (the brief names the path). The coordinator publishes it.
- Do not spawn subagents.
- Your final message is your report: Simplified Technical English, verdict first, short sentences, no hype. Include merge SHAs, gates with results, beads closed and filed, the review folder path, and decisions you need with your recommendation.
- Gates: block a merge only for a real regression or a failed measurement. When a gate cannot be checked because outside reference data does not exist, or the gate as written compares the wrong things, apply the closest sound bar, say so plainly in the log and the report, merge, and file a bead for the missing data. Do not leave finished work unmerged waiting for a decision you can reason out.
