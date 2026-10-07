#!/usr/bin/env bash
# Rebuild site/stack.tar.gz from site/files. Run after any change to the files.
set -euo pipefail
cd "$(dirname "$0")/site"
tar --transform 's,^files,stack,' --sort=name --owner=0 --group=0 -czf stack.tar.gz files
echo "built site/stack.tar.gz"
