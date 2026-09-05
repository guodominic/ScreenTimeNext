#!/bin/bash
# Run the ScreenTimeNextCore unit tests. Prints failures, not the whole run.
#
# Why this exists: the Xcode 27 beta does not surface a local package's test targets in the
# app project's schemes (Product > Test is greyed out), and the Command Line Tools' `swift`
# has no XCTest. So tests run via SwiftPM using Xcode's own toolchain.
#
# Usage:  ./scripts/test.sh            (from the repo root)

set -uo pipefail
"$(dirname "$0")/check-imports.sh" || exit 1
"$(dirname "$0")/privacy-audit.sh" || exit 1
cd "$(dirname "$0")/../Packages/ScreenTimeNextCore"

XCODE="/Users/apple/Downloads/Xcode-beta.app"
if [ ! -d "$XCODE" ]; then
  XCODE="$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" | head -1)"
fi
if [ -z "$XCODE" ] || [ ! -d "$XCODE" ]; then
  echo "error: could not find Xcode.app" >&2; exit 1
fi
echo "Using $XCODE"
# Strip Finder/provenance extended attributes: codesign refuses bundles that carry them.
xattr -cr . 2>/dev/null || true
# Build OUTSIDE the repo: anything under ~/Desktop (iCloud) or the Claude mount re-acquires them.
SCRATCH="$HOME/Library/Caches/ScreenTimeNextCore.build"
rm -rf .build

LOG="$(mktemp)"
DEVELOPER_DIR="$XCODE/Contents/Developer" swift test --scratch-path "$SCRATCH" "$@" > "$LOG" 2>&1
STATUS=$?

if grep -qE "error:" "$LOG"; then
  echo "───────────── COMPILE ERRORS ─────────────"
  grep -E "error:" "$LOG" | sort -u | head -40
fi

FAILURES=$(grep -E "^.*: error: -\[|XCTAssert.*failed|' failed \(" "$LOG" | sort -u | head -30)
if [ -n "$FAILURES" ]; then
  echo "───────────── TEST FAILURES ─────────────"
  echo "$FAILURES"
fi

grep -E "Executed [0-9]+ tests" "$LOG" | tail -2
[ $STATUS -eq 0 ] && echo "TESTS OK" || echo "TESTS FAILED (full log: $LOG)"
exit $STATUS
