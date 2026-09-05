#!/bin/bash
# Build the app for the iOS Simulator from Terminal (no signing needed).
# Usage:  ./scripts/build.sh            (from the repo root)
set -euo pipefail
cd "$(dirname "$0")/.."
XCODE="/Users/apple/Downloads/Xcode-beta.app"
[ -d "$XCODE" ] || XCODE="$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" | head -1)"
echo "Using $XCODE"
DEVELOPER_DIR="$XCODE/Contents/Developer" xcodebuild \
  -project ScreenTimeNext.xcodeproj -scheme ScreenTimeNext \
  -destination 'generic/platform=iOS Simulator' \
  -quiet build 2>&1 | tail -40 && echo "BUILD OK"
