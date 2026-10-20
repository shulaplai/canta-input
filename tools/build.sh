#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

if [ ! -f "$ROOT/Resources/jyutping.tsv" ]; then
  echo "Resources/jyutping.tsv missing; run tools/fetch_data.sh then python3 tools/build_lexicon.py" >&2
  exit 1
fi
if [ ! -f "$ROOT/Resources/icon.tiff" ]; then
  swift "$ROOT/tools/makeicon.swift" "$ROOT/Resources/icon.tiff"
fi

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Cantainput"

APP="$ROOT/build/Cantainput.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Cantainput"
cp "$ROOT/Sources/Cantainput/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/jyutping.tsv" "$APP/Contents/Resources/jyutping.tsv"
cp "$ROOT/Resources/icon.tiff" "$APP/Contents/Resources/icon.tiff"
if [ -f "$ROOT/Resources/zh_char_bigram.bin" ]; then
  cp "$ROOT/Resources/zh_char_bigram.bin" "$APP/Contents/Resources/zh_char_bigram.bin"
fi

xattr -cr "$APP"
codesign --force --sign - --timestamp=none "$APP"
echo "built $APP"
