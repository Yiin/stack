#!/usr/bin/env python3
"""Compress proof media for a project map.

    media.py <input> <output dir> [--name <base>] [--captured YYYY-MM-DD]

Screenshots (png, jpg, webp) become AVIF: at most 1600 px wide, AV1 CRF 24, full
color (4:4:4) so small text stays sharp. Videos (mp4, webm, mov, mkv) become AV1 in
WebM: at most 1280 px wide, no sound, CRF 38. Prints one JSON line with src (relative
to the map dir, if the output dir sits in one), bytes, kind and captured: paste it
into the part's proof.shots in data.json and add a caption.
Needs only ffmpeg with libaom-av1 and libsvtav1.
"""
import datetime as dt
import json
import shutil
import subprocess
import sys
from pathlib import Path

IMAGES = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".avif"}
VIDEOS = {".mp4", ".webm", ".mov", ".mkv"}


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"media.py: {' '.join(cmd[:2])} failed:\n{r.stderr[-2000:]}")


def main(argv):
    if len(argv) < 3:
        sys.exit(__doc__)
    src, out_dir = Path(argv[1]), Path(argv[2])
    name = argv[argv.index("--name") + 1] if "--name" in argv else src.stem
    captured = argv[argv.index("--captured") + 1] if "--captured" in argv else dt.date.today().isoformat()
    out_dir.mkdir(parents=True, exist_ok=True)
    ext = src.suffix.lower()
    if ext in IMAGES:
        out, kind = out_dir / f"{name}.avif", "image"
        run(["ffmpeg", "-v", "error", "-y", "-i", str(src), "-frames:v", "1", "-vf", "scale=w='min(1600,iw)':h=-2",
             "-c:v", "libaom-av1", "-still-picture", "1", "-crf", "24", "-cpu-used", "6",
             "-pix_fmt", "yuv444p", str(out)])
    elif ext in VIDEOS:
        out, kind = out_dir / f"{name}.webm", "video"
        run(["ffmpeg", "-v", "error", "-y", "-i", str(src), "-vf", "scale='min(1280,iw)':-2",
             "-c:v", "libsvtav1", "-preset", "8", "-crf", "38", "-an", str(out)])
    else:
        sys.exit(f"media.py: {ext} is not a screenshot or video type")
    # an already compressed WebP or AVIF can grow when encoded again: keep the original then
    if kind == "image" and ext in {".webp", ".avif"} and out.stat().st_size >= src.stat().st_size:
        out.unlink()
        out = out_dir / f"{name}{ext}"
        shutil.copyfile(src, out)
    # src relative to the map dir: the first parent that holds data.json or sits under .project-map/<slug>
    rel = out
    for parent in out.resolve().parents:
        if (parent / "data.json").is_file() or parent.parent.name == ".project-map":
            rel = out.resolve().relative_to(parent)
            break
    print(json.dumps({"src": str(rel), "kind": kind, "captured": captured,
                      "bytes": out.stat().st_size, "in_bytes": src.stat().st_size}))


if __name__ == "__main__":
    main(sys.argv)
