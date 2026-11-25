#!/usr/bin/env python3
"""Daily sweep: delete project-map proof media older than 30 days on this machine.

    sweep.py [--dry-run] [root ...]      default root: $HOME

Finds every .project-map/<slug>/ under the roots.
- A map with data.json: render.py prunes expired shots, marks them expired and
  re-renders, so the page shows "Expired" instead of a broken image.
- An older map without data.json: deletes media files under its evidence/ and
  proof/ folders whose modification time is older than 30 days.
It never touches the published artifact. The next map run removes expired files
there, and the page hides an expired shot by its date anyway.
"""
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import render  # noqa: E402

MEDIA = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".avif", ".mp4", ".webm", ".mov", ".mkv"}
SKIP = {"node_modules", ".git", ".cache", ".local", ".npm", ".bun", ".cargo", ".rustup", ".steam",
        ".mozilla", ".var", "go", ".venv", "venv", "__pycache__", "target", "dist", "build",
        ".next", ".turbo", "snap", "Downloads", "Videos", "Pictures", "Music"}
MAX_DEPTH = 7


def find_maps(root):
    root = Path(root)
    visited = set()
    for dirpath, dirnames, _ in os.walk(root, followlinks=True):
        real = os.path.realpath(dirpath)
        if real in visited:
            dirnames[:] = []
            continue
        visited.add(real)
        depth = len(Path(dirpath).relative_to(root).parts)
        if ".project-map" in dirnames:
            pm = Path(dirpath) / ".project-map"
            for slug in sorted(pm.iterdir()):
                if slug.is_dir() and not slug.name.startswith("."):
                    yield slug
            # a legacy single map sits straight in .project-map
            if (pm / "evidence").is_dir():
                yield pm
        dirnames[:] = [d for d in dirnames if d not in SKIP and d != ".project-map"
                       and not (d.startswith(".") and d not in {".agents", ".claude", ".config"})
                       and depth < MAX_DEPTH]


def sweep_legacy(map_dir, dry):
    cutoff = time.time() - render.LIFE_DAYS * 86400
    freed = n = 0
    for sub in ("evidence", "proof"):
        base = map_dir / sub
        if not base.is_dir():
            continue
        for f in base.rglob("*"):
            if f.is_file() and f.suffix.lower() in MEDIA and f.stat().st_mtime < cutoff:
                freed += f.stat().st_size
                n += 1
                if not dry:
                    f.unlink()
    return n, freed


def main(argv):
    dry = "--dry-run" in argv
    roots = [a for a in argv[1:] if not a.startswith("--")] or [os.environ.get("HOME", "/")]
    total_n = total_b = 0
    seen = set()
    for root in roots:
        for m in find_maps(root):
            real = m.resolve()
            if real in seen:
                continue
            seen.add(real)
            if (m / "data.json").is_file():
                import json
                d = json.loads((m / "data.json").read_text())
                gone = render.prune_media(m, d, dry=True)
                if gone and not dry:
                    render.render_map(m)
                if gone:
                    print(f"{m}: {len(gone)} expired shots{' (dry run)' if dry else ' deleted, map re-rendered'}")
                total_n += len(gone)
            else:
                n, b = sweep_legacy(m, dry)
                if n:
                    print(f"{m}: {n} old media files, {b / 1048576:.1f} MB{' (dry run)' if dry else ' deleted'}")
                total_n += n
                total_b += b
    print(f"sweep done: {len(seen)} maps, {total_n} files{' would be' if dry else ''} removed, "
          f"{total_b / 1048576:.1f} MB from older maps")


if __name__ == "__main__":
    main(sys.argv)
