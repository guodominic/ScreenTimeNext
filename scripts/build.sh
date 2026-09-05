#!/bin/bash
# Build the app for the iOS Simulator from Terminal (no signing needed).
# Prints compiler errors and warnings, not the build log.
# Usage:  ./scripts/build.sh            (from the repo root)
set -uo pipefail
cd "$(dirname "$0")/.."
XCODE="/Users/apple/Downloads/Xcode-beta.app"
[ -d "$XCODE" ] || XCODE="$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" | head -1)"
echo "Using $XCODE"
xattr -cr ScreenTimeNext ScreenTimeNextWidgets Packages 2>/dev/null || true

LOG="$(mktemp)"
DEVELOPER_DIR="$XCODE/Contents/Developer" xcodebuild \
  -project ScreenTimeNext.xcodeproj -scheme ScreenTimeNext \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$HOME/Library/Caches/ScreenTimeNext.derived" \
  -quiet build > "$LOG" 2>&1
STATUS=$?

# Surface only what a human needs: errors first, then warnings.
if grep -qE "error:|error;" "$LOG"; then
  echo "───────────── ERRORS ─────────────"
  grep -E "error:" "$LOG" | grep -v "^note:" | sort -u | head -40
fi
WARN=$(grep -E "warning:" "$LOG" | grep -v "Removed stale file" | sort -u | head -15)
[ -n "$WARN" ] && { echo "───────────── WARNINGS ─────────────"; echo "$WARN"; }

if [ $STATUS -eq 0 ]; then
  echo "BUILD OK"
else
  echo "BUILD FAILED (full log: $LOG)"
fi
exit $STATUS
