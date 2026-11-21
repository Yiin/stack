# project-map tools

The `project-map` agent draws one map per epic or orchestration from one file, `data.json`. These tools turn it into the page.

| File | What it does |
|---|---|
| `template.html` | The page: milestones, Needs you, number tiles, proof viewer, parts list, side panel. Light and dark. Never edit a rendered copy. |
| `render.py map <map dir>` | Checks `data.json`, deletes expired proof media, writes `index.html`, `artifact.html` (inline copy for a chat), `state.json` and `publish.json`. |
| `render.py hub <.project-map dir> [--out maps.html]` | Writes the hub that links every map in the repo. |
| `media.py <file> <map dir>/proof/<part id> [--name x] [--captured YYYY-MM-DD]` | Screenshot to AVIF (1600 px wide at most, AV1 CRF 24, 4:4:4), video to AV1 WebM (1280 px wide at most, CRF 38, no sound). Prints the shot entry for `data.json`. |
| `sweep.py [--dry-run] [root]` | Daily timer: deletes proof media older than 30 days in every map on the machine. |
| `project-map-sweep.{service,timer}` | The systemd user units for the sweep. |

## data.json

```jsonc
{
  "project": "Acme Shop",                // page heading
  "page_title": "Acme Shop Map",         // <title>, 2 to 4 words
  "title": "Checkout rebuild",
  "epic": "shop-12ab",
  "slug": "shop-12ab",
  "artifact_url": "https://claude.ai/artifact/…",
  "artifact_slug": "4ad097d4-…",          // UUID, for publish and the answers database
  "updated_at": "2026-11-21T03:07:06Z",
  "commit": "d4e75c9",
  "headline": null,                      // optional one-sentence verdict; null = the page writes it from the numbers
  "claude_on": "Wire live keys into checkout. It starts once the keys arrive.",
  "proof_days": 30,
  "milestones": [
    {"code": "M0", "name": "Setup", "exit": "main deploys to staging on push", "exit_met": "Nov 16"},
    {"code": "M1", "name": "Payments", "exit": "a real card payment goes through", "exit_met": null}
  ],
  "parts": [
    {
      "id": "invoices", "m": "M1", "name": "Invoices",
      "status": "prog",                  // done | prog | idle (not started) | stuck
      "d": 30, "t": 40, "running": 0,    // items done and total; leave out when there is no count
      "done_on": null,                   // "Nov 16" for a done part
      "waiting_on": null,                // required when stuck: a person, an issue id, a service or a part
      "left": "PDF export and the phone layout.",
      "summary": "Invoices list, detail page and email …",
      "changed": true,                   // status or count changed since the last map
      "proof": {
        "tests": "Load test p95 19 ms, budget 150 ms",   // one line, kept forever
        "links": [{"label": "staging", "url": "https://…"}],
        "shots": [{"src": "proof/invoices/desktop-dark.avif", "caption": "Desktop, dark", "captured": "2026-11-16", "kind": "image"}]
      }
    }
  ],
  "needs_you": [
    {"id": "live-server-size", "question": "Which server size for live?", "context": "One line on why it matters.",
     "options": ["CX32", "CX42", "CCX23"], "default": "CX42", "meanwhile": "the release checklist"}
  ],
  "answered": [{"q": "Tax provider", "a": "You picked Stripe Tax.", "d": "Nov 21"}],
  "panels": [{"title": "Open issues per part", "items": ["Invoices: 4", "Checkout: 2"]}]
}
```

Rules the renderer enforces: every part names a milestone that exists, ids are unique, a stuck part names `waiting_on`, `d` is never above `t`, every live shot has a `captured` date and a file on disk.

## Answers

A call in `needs_you` renders as buttons. A click writes `answers/<call id>` in the artifact's database: `{question, choice, answered_at}`. The artifact must declare `{"db": {"rules": [{"path": "answers", "read": "view", "write": "admin"}]}, "user": {}}`. Claude reads answers with `db_list` (collection `answers`) and marks one read with `db_write` merge `{seen_at, note}`. The page then locks that call and shows the note.
