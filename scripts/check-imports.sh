#!/bin/bash
# Import-boundary check (CLAUDE.md Rule 1, docs/source-layout.md).
#
# `import FamilyControls` / `import DeviceActivity` / `import ManagedSettings` are allowed ONLY in:
#   ScreenTimeNext/ScreenTime/            (framework adapters; includes the D-001 picker wrapper)
#   DeviceActivityMonitorExtension/       (the extension)
# Everywhere else — Features/, ScreenTimeNextApp/, Packages/ — is framework-free.
#
# Usage: ./scripts/check-imports.sh   (from the repo root; exits 1 on a violation)

set -uo pipefail
cd "$(dirname "$0")/.."

violations=$(grep -rnE '^\s*(@testable\s+)?import\s+(FamilyControls|DeviceActivity|ManagedSettings)\b' \
  --include='*.swift' ScreenTimeNext Packages DeviceActivityMonitorExtension 2>/dev/null \
  | grep -vE '^(ScreenTimeNext/ScreenTime/|DeviceActivityMonitorExtension/)' || true)

if [ -n "$violations" ]; then
  echo "IMPORT BOUNDARY VIOLATION — Screen Time frameworks imported outside the adapter layer:"
  echo "$violations"
  exit 1
fi
echo "import boundary OK"
