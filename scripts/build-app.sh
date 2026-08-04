#!/usr/bin/env bash
# build-app.sh — produce a launchable .app bundle from the SwiftPM build output.
#
# Usage:
#   ./scripts/build-app.sh                 # install to ~/Applications/ClipboardHistoryMac.app
#   ./scripts/build-app.sh --install       # same
#   ./scripts/build-app.sh /path/to/dest   # install to a custom absolute path
#
# After install:
#   open ~/Applications/ClipboardHistoryMac.app

set -euo pipefail

DEST="${HOME}/Applications/ClipboardHistoryMac.app"
if [[ "${1:-}" == "--install" || -z "${1:-}" ]]; then
    : # default destination
elif [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    sed -n '3,12p' "$0"
    exit 0
else
    DEST="${1}"
fi

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$PROJECT_DIR/.build/release/ClipboardHistoryMac"
PLIST_SRC="$PROJECT_DIR/Sources/ClipboardHistoryMac/Info.plist"

if [[ ! -x "$BIN" ]]; then
    echo "Building release binary..."
    (cd "$PROJECT_DIR" && swift build -c release)
fi

echo "Building .app bundle at $DEST ..."
rm -rf "$DEST"
mkdir -p "$DEST/Contents/MacOS" "$DEST/Contents/Resources"
cp "$BIN" "$DEST/Contents/MacOS/ClipboardHistoryMac"
chmod +x "$DEST/Contents/MacOS/ClipboardHistoryMac"
cp "$PLIST_SRC" "$DEST/Contents/Info.plist"

# Xcode-style build variables aren't substituted by `swift build`, so set them here.
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.sigco3111.clipboard-history-mac" "$DEST/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable ClipboardHistoryMac" "$DEST/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName ClipboardHistory" "$DEST/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Clipboard History" "$DEST/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :CFBundlePackageType" "$DEST/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$DEST/Contents/Info.plist"

xattr -cr "$DEST"
codesign --force --deep --sign - "$DEST"

echo "Done."
echo "Launch with: open '$DEST'"
echo "Or double-click in Finder."
