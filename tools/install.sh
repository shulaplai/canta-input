#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
APP="$ROOT/build/app/Cantainput.app"
DEST="$HOME/Library/Input Methods/Cantainput.app"

[ -d "$APP" ] || { echo "build first: tools/build.sh" >&2; exit 1; }
mkdir -p "$HOME/Library/Input Methods"
killall Cantainput 2>/dev/null || true
rm -rf "$DEST"
ditto "$APP" "$DEST"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$ROOT/build/Cantainput.app" >/dev/null 2>&1 || true
lsregister -f "$DEST" 2>/dev/null || true
echo "installed $DEST"
echo "log out/in once if it does not appear under Input Sources, then add '粵拼 Cantainput'."
