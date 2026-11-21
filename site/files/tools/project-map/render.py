#!/usr/bin/env python3
"""Render a project map from its data.json, and the hub that links every map.

    render.py map <map dir>          writes index.html, artifact.html, state.json, publish.json
    render.py hub <.project-map dir> [--out index.html]

data.json is the one source of a map. The schema is in README.md beside this file.
Each render deletes proof media older than the proof life (30 days) and marks it expired,
so a map never ships stale screenshots.
"""
import datetime as dt
import html
import json
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TEMPLATE = HERE / "template.html"
LIFE_DAYS = 30
STATUSES = {"done", "prog", "idle", "stuck"}


def today():
    return dt.datetime.now(dt.timezone.utc).date()


def expired(shot, life=LIFE_DAYS):
    if shot.get("expired"):
        return True
    captured = dt.date.fromisoformat(str(shot["captured"])[:10])
    return today() >= captured + dt.timedelta(days=life)


def fail(msg):
    sys.exit(f"render.py: {msg}")


def validate(d):
    for key in ("project", "updated_at", "milestones", "parts"):
        if key not in d:
            fail(f"data.json has no '{key}'")
    codes = {m["code"] for m in d["milestones"]}
    ids = set()
    for p in d["parts"]:
        for key in ("id", "m", "name", "status", "summary"):
            if key not in p:
                fail(f"part {p.get('id', '?')} has no '{key}'")
        if p["id"] in ids:
            fail(f"part id {p['id']} is used twice")
        ids.add(p["id"])
        if p["m"] not in codes:
            fail(f"part {p['id']} names milestone {p['m']}, which is not in milestones")
        if p["status"] not in STATUSES:
            fail(f"part {p['id']} has status {p['status']}; use one of {sorted(STATUSES)}")
        if p["status"] == "stuck" and not p.get("waiting_on"):
            fail(f"part {p['id']} is stuck but names nothing in waiting_on")
        if p.get("t") and p.get("d", 0) > p["t"]:
            fail(f"part {p['id']} has d > t")
    for c in d.get("needs_you", []):
        for key in ("id", "question", "options", "default"):
            if key not in c:
                fail(f"call {c.get('id', '?')} has no '{key}'")


def prune_media(map_dir, d, dry=False):
    """Delete expired proof files and mark them expired. Returns the removed paths."""
    life = d.get("proof_days", LIFE_DAYS)
    removed = []
    for p in d["parts"]:
        for s in (p.get("proof") or {}).get("shots", []):
            if s.get("expired"):
                continue
            if expired(s, life):
                f = map_dir / s["src"]
                if not dry and f.is_file():
                    f.unlink()
                removed.append(s["src"])
                if not dry:
                    s["expired"] = True
                    s.pop("bytes", None)
    return removed


def check_media(map_dir, d):
    for p in d["parts"]:
        for s in (p.get("proof") or {}).get("shots", []):
            if s.get("expired"):
                continue
            if "captured" not in s:
                fail(f"shot {s.get('src')} in part {p['id']} has no captured date")
            f = map_dir / s["src"]
            if not f.is_file():
                fail(f"shot {s['src']} in part {p['id']} is missing on disk")
            s["bytes"] = f.stat().st_size


def page(d, inline=False):
    data = dict(d, inline=inline)
    blob = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    title = d.get("page_title") or f"{d['project']} Map"
    return TEMPLATE.read_text().replace("__TITLE__", html.escape(title)).replace("__MAP_DATA__", blob)


def state_of(d, old):
    parts = d["parts"]
    nxt = next((m for m in d["milestones"] if not m.get("exit_met")), None)
    left = [p for p in parts if nxt and p["m"] == nxt["code"] and p["status"] != "done"]
    keep = {k: old[k] for k in ("artifact_url",) if k in old}
    return {
        **keep,
        "slug": d.get("slug"),
        "epic": d.get("epic"),
        "title": d.get("title") or d["project"],
        "project": d["project"],
        "updated_at": d["updated_at"],
        "artifact_url": d.get("artifact_url") or keep.get("artifact_url"),
        "artifact_slug": d.get("artifact_slug"),
        "commit": d.get("commit"),
        "next_milestone": f"{nxt['code']} {nxt['name']}" if nxt else None,
        "left_count": len(left),
        "next_step": d.get("claude_on"),
        "open_calls": [c["id"] for c in d.get("needs_you", [])],
        "parts": [
            {k: p.get(k) for k in ("id", "name", "m", "status", "d", "t", "waiting_on", "summary")}
            | {"proof": bool((p.get("proof") or {}).get("tests") or (p.get("proof") or {}).get("shots"))}
            for p in parts
        ],
    }


def render_map(map_dir):
    map_dir = Path(map_dir).resolve()
    data_file = map_dir / "data.json"
    if not data_file.is_file():
        fail(f"{data_file} does not exist")
    d = json.loads(data_file.read_text())
    validate(d)
    removed = prune_media(map_dir, d)
    check_media(map_dir, d)
    data_file.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n")

    (map_dir / "index.html").write_text(page(d))
    (map_dir / "artifact.html").write_text(page(d, inline=True))

    state_file = map_dir / "state.json"
    old = json.loads(state_file.read_text()) if state_file.is_file() else {}
    state_file.write_text(json.dumps(state_of(d, old), ensure_ascii=False, indent=2) + "\n")

    files = ["index.html"] + [
        s["src"] for p in d["parts"] for s in (p.get("proof") or {}).get("shots", []) if not s.get("expired")
    ]
    pub_file = map_dir / "publish.json"
    before = json.loads(pub_file.read_text()).get("files", []) if pub_file.is_file() else []
    remove = sorted((set(before) - set(files)) | set(removed))
    pub = {"files": files, "remove": remove, "map_dir": str(map_dir)}
    pub_file.write_text(json.dumps(pub, indent=2) + "\n")

    size = sum((map_dir / f).stat().st_size for f in files)
    print(f"rendered {map_dir}/index.html: {len(d['parts'])} parts, {len(files) - 1} media files, "
          f"{size / 1024:.0f} KB to publish, {len(remove)} to remove, {len(removed)} expired now")
    return pub


HUB_CSS_KEYS = ("--bg", "--surface", "--line", "--text", "--muted", "--accent", "--track", "--ok")


def render_hub(maps_dir, out_name="index.html"):
    maps_dir = Path(maps_dir).resolve()
    rows = []
    for state_file in sorted(maps_dir.glob("*/state.json")):
        s = json.loads(state_file.read_text())
        data_file = state_file.parent / "data.json"
        pct = None
        if data_file.is_file():
            d = json.loads(data_file.read_text())
            tot = sum(p.get("t", 0) for p in d["parts"])
            pct = round(100 * sum(p.get("d", 0) for p in d["parts"] if p.get("t")) / tot) if tot else None
        rows.append((s.get("updated_at") or "", state_file.parent.name, s, pct))
    rows.sort(reverse=True)
    items = "".join(
        f'<a class="row" href="{html.escape(slug)}/index.html"><span class="t">{html.escape(s.get("title") or slug)}'
        f'<small>{html.escape(s.get("epic") or "")}</small></span>'
        f'<span class="bar"><i style="width:{pct or 0}%"></i></span><span class="pct">{"" if pct is None else str(pct) + "%"}</span>'
        f'<span class="nx">{html.escape(s.get("next_step") or "")}</span>'
        f'<span class="up">{html.escape((s.get("updated_at") or "")[:16].replace("T", " "))}</span></a>'
        for _, slug, s, pct in rows
    ) or '<p class="empty">No maps yet.</p>'
    doc = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Project Maps</title>
<link href="https://fonts.googleapis.com/css2?family=Instrument+Serif&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<style>
:root{{--bg:#f3f2ee;--surface:#fff;--line:#dcd9d0;--text:#17171a;--muted:#67666e;--accent:#5b46c9;--track:#e3e1da}}
@media (prefers-color-scheme:dark){{:root{{--bg:#0b0b0d;--surface:#131316;--line:#25252b;--text:#ededf0;--muted:#9393a0;--accent:#b9a6ff;--track:#232329}}}}
*{{box-sizing:border-box}}html,body{{margin:0;background:var(--bg);color:var(--text)}}
body{{font:14px/1.5 Inter,system-ui,sans-serif}}main{{max-width:1100px;margin:0 auto;padding:40px 20px}}
h1{{font:400 48px/1 "Instrument Serif",Georgia,serif;margin:0 0 24px}}
.list{{background:var(--surface);border:1px solid var(--line);border-radius:16px;overflow:hidden}}
.row{{display:grid;grid-template-columns:minmax(0,1.4fr) 120px 44px minmax(0,2fr) 120px;gap:14px;align-items:center;padding:14px 18px;border-top:1px solid var(--line);color:inherit;text-decoration:none}}
.row:first-child{{border-top:0}}.row:hover{{background:var(--bg)}}
.t{{font-weight:600}}.t small{{display:block;font-weight:400;color:var(--muted);font-size:12px}}
.bar{{height:6px;background:var(--track);border-radius:99px;overflow:hidden}}.bar i{{display:block;height:100%;background:var(--accent)}}
.pct,.up{{color:var(--muted);font-size:12.5px}}.nx{{color:var(--muted);font-size:13px}}.empty{{color:var(--muted)}}
@media (max-width:700px){{.row{{grid-template-columns:1fr 60px}}.bar,.nx,.up{{display:none}}}}
</style></head><body><main><h1>Project maps</h1><div class="list">{items}</div></main></body></html>
"""
    (maps_dir / out_name).write_text(doc)
    print(f"hub: {maps_dir / out_name}, {len(rows)} maps")


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "map":
        render_map(sys.argv[2])
    elif len(sys.argv) >= 3 and sys.argv[1] == "hub":
        out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "index.html"
        render_hub(sys.argv[2], out)
    else:
        sys.exit(__doc__)
