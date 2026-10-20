#!/bin/bash
# Build a double-clickable installer that puts the input method in
# /Library/Input Methods, which is where macOS actually looks for third-party
# input methods (same place Squirrel lives).
#
# Produces dist/Cantainput-<version>.pkg
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Cantainput.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
    "$ROOT/Sources/Cantainput/Info.plist")
IDENTIFIER="local.cantainput.inputmethod"
DIST="$ROOT/dist"
STAGE="$DIST/root"
SCRIPTS="$DIST/scripts"
PKG="$DIST/Cantainput-$VERSION.pkg"

"$ROOT/tools/build.sh" >/dev/null

rm -rf "$STAGE" "$SCRIPTS"
mkdir -p "$STAGE/Library/Input Methods" "$SCRIPTS"
ditto "$APP" "$STAGE/Library/Input Methods/Cantainput.app"

cat > "$SCRIPTS/postinstall" <<'POSTINSTALL'
#!/bin/bash
# Runs as root after the payload lands in /Library/Input Methods.
set -e
APP="/Library/Input Methods/Cantainput.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

# Stop a stale copy so the new binary is what the user session talks to.
/usr/bin/killall Cantainput 2>/dev/null || true

# Make the bundle visible to LaunchServices. Text Input Services picks it up
# from there; a brand new bundle identifier still needs a logout/login before it
# shows up under Input Sources (macOS only snapshots installed input methods
# when a login session starts).
"$LSREGISTER" -f "$APP" || true
/usr/bin/xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

exit 0
POSTINSTALL
chmod +x "$SCRIPTS/postinstall"

rm -f "$PKG"
pkgbuild \
    --root "$STAGE" \
    --scripts "$SCRIPTS" \
    --identifier "$IDENTIFIER.pkg" \
    --version "$VERSION" \
    --install-location / \
    "$PKG" >/dev/null

rm -rf "$STAGE" "$SCRIPTS"
echo "built $PKG"
echo "install: double-click it, or  sudo installer -pkg \"$PKG\" -target /"
echo "then log out and back in, and add '粵拼 Cantainput' under Input Sources"
