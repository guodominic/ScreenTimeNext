#!/bin/bash
# Run the ScreenTimeNextCore unit tests from Terminal.
#
# Why this exists: the Xcode 27 beta does not surface a local package's test targets in the
# app project's schemes (Product > Test is greyed out), and the Command Line Tools' `swift`
# has no XCTest. So tests run via SwiftPM using Xcode's own toolchain.
#
# Usage:  ./scripts/test.sh            (from the repo root)

set -euo pipefail
cd "$(dirname "$0")/../Packages/ScreenTimeNextCore"

# Locate Xcode: known location first, Spotlight as fallback.
XCODE="/Users/apple/Downloads/Xcode-beta.app"
if [ ! -d "$XCODE" ]; then
  XCODE="$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" | head -1)"
fi
if [ -z "$XCODE" ] || [ ! -d "$XCODE" ]; then
  echo "error: could not find Xcode.app" >&2; exit 1
fi
echo "Using $XCODE"
# Strip Finder/provenance extended attributes: codesign refuses bundles that carry them
# ("resource fork, Finder information, or similar detritus not allowed"). Files written
# through the Claude desktop mount tend to pick these up.
xattr -cr . 2>/dev/null || true
DEVELOPER_DIR="$XCODE/Contents/Developer" swift test "$@" 2>&1 | tail -40
