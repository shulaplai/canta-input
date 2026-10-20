#!/bin/bash
# Fetch the raw corpora used to build the character language model.
# Everything lands in Data/ which is gitignored: only the built model is committed.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p Data

# Cantonese Wikipedia (粵文維基百科) — CC BY-SA 4.0 + GFDL.
# 129 MB bz2, ~54M Han characters, marker density 45/1000 (genuine written Cantonese).
URL="https://dumps.wikimedia.org/zh_yuewiki/latest/zh_yuewiki-latest-pages-articles.xml.bz2"
OUT="Data/zh_yuewiki.xml.bz2"

if [ -f "$OUT" ] && [ "$(stat -f%z "$OUT")" -gt 100000000 ]; then
  echo "already have $OUT ($(stat -f%z "$OUT") bytes)"
else
  echo "downloading $URL"
  curl -L --retry 3 --progress-bar -o "$OUT" "$URL"
fi

echo
echo "next: python3 tools/build_lm.py"
