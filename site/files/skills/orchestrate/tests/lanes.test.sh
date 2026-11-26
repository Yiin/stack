#!/usr/bin/env bash
# Tests for bin/lanes prune. Uses a temporary lane root only.
#   bash ~/.agents/skills/orchestrate/tests/lanes.test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
lanes() { python3 "$here/../bin/lanes" "$@"; }
work="$(mktemp -d)"
trap 'rm -rf "${work:?}"' EXIT

failures=0
check() { # name expected actual
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$2', got '$3'"; failures=$((failures + 1)); fi
}
exists() { [ -e "$1" ] && echo yes || echo no; }

r="$work/lanes/proj"
mkdir -p "$r/A-review/shots" "$r/A-review/pairs" "$r/B-review/raw" "$r/C-review/shots"
cat > "$r/A-review/index.html" <<'HTML'
<img src="pairs/one.png"><img src='pairs/two%20b.png'><img src=pairs/three.png>
<img srcset="pairs/four.png 1x, pairs/five.png 2x"><a href="https://example.com/x.png">x</a>
HTML
for f in pairs/one.png "pairs/two b.png" pairs/three.png pairs/four.png pairs/five.png shots/raw1.png shots/clip.webm; do
  echo x > "$r/A-review/$f"
done
echo '![shot](raw/linked.png)' > "$r/B-review/report.md"
echo x > "$r/B-review/raw/linked.png"; echo x > "$r/B-review/raw/unlinked.jpg"
echo '<script>show("shots/" + n + ".png")</script>' > "$r/C-review/index.html"
echo x > "$r/C-review/shots/1.png"
echo x > "$r/A-review/shots/new.png"
head -c 2000000 /dev/zero > "$r/big.log"; echo small > "$r/small.log"; echo notes > "$r/brief.md"
find "$r" -type f ! -name new.png -exec touch -d '30 days ago' {} +

export ORCHESTRATE_LANE_ROOTS="$work/lanes"
lanes prune >/dev/null
check "dry run deletes nothing" yes "$(exists "$r/A-review/shots/raw1.png")"
check "dry run gzips nothing" yes "$(exists "$r/big.log")"

lanes prune --apply >/dev/null
for f in pairs/one.png "pairs/two b.png" pairs/three.png pairs/four.png pairs/five.png; do
  check "linked media stays: $f" yes "$(exists "$r/A-review/$f")"
done
check "unlinked old screenshot: deleted" no "$(exists "$r/A-review/shots/raw1.png")"
check "unlinked old video: deleted" no "$(exists "$r/A-review/shots/clip.webm")"
check "recent unlinked screenshot: stays" yes "$(exists "$r/A-review/shots/new.png")"
check "markdown-linked media stays" yes "$(exists "$r/B-review/raw/linked.png")"
check "unlinked media next to markdown: deleted" no "$(exists "$r/B-review/raw/unlinked.jpg")"
check "media under a script page with no links: stays" yes "$(exists "$r/C-review/shots/1.png")"
check "pages stay" yes "$(exists "$r/A-review/index.html")"
check "big old log: gzipped" yes "$(exists "$r/big.log.gz")"
check "big old log: original gone" no "$(exists "$r/big.log")"
check "gzipped log holds the data" 2000000 "$(gzip -dc "$r/big.log.gz" | wc -c | tr -d ' ')"
check "small log stays as is" yes "$(exists "$r/small.log")"
check "brief stays" yes "$(exists "$r/brief.md")"
check "bad option exits 2" 2 "$(lanes prune --older-than x >/dev/null 2>&1; echo $?)"

echo
if [ "$failures" -eq 0 ]; then echo "all passed"; else echo "$failures failed"; exit 1; fi
