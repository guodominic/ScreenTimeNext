#!/bin/bash
# Privacy audit (PRD §16, Task 018, QA-15). Fails if the codebase grows anything that could send
# data off the device or log selection tokens. Run by scripts/test.sh.
#
# Allowed: nothing network-facing at all in V1 (no backend, no analytics, no ads).
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
report() { echo "PRIVACY AUDIT: $1"; echo "$2"; fail=1; }

# 1) No networking APIs anywhere (URLSession, sockets, Network.framework, WebKit).
net=$(grep -rnE 'URLSession|NWConnection|import Network\b|CFNetwork|import WebKit|NSURLConnection|Alamofire' \
      --include='*.swift' ScreenTimeNext Packages DeviceActivityMonitorExtension 2>/dev/null || true)
[ -n "$net" ] && report "networking API found — V1 has no backend (§16)" "$net"

# 2) No http(s) ENDPOINT literals in shipping source.
#
# What this rule is for: an address something could be sent to. It is not for the string "https://"
# on its own, which is a scheme prefix — D-033 strips one from a domain a parent typed, and there is
# no way to write that code without naming the thing being stripped. So the pattern now requires at
# least one character after the slashes, which is the difference between a prefix and a destination.
#
# Test sources are excluded, as they already are for logging (rule 3): they never ship, and website
# normalisation cannot be tested without example URLs to normalise. If a real endpoint ever appears
# in shipping code, rules 1 and 3 still catch the machinery around it.
urls=$(grep -rnE '"https?://[^"]' --include='*.swift' ScreenTimeNext Packages DeviceActivityMonitorExtension 2>/dev/null \
       | grep -v '/Tests/' || true)
[ -n "$urls" ] && report "URL endpoint literal found in shipping source" "$urls"

# 3) No logging calls in production sources (tests excluded). print/NSLog/os_log/Logger.
logs=$(grep -rnE '\bprint\(|NSLog\(|os_log\(|\bLogger\(|\.log\(' --include='*.swift' \
       ScreenTimeNext Packages/ScreenTimeNextCore/Sources DeviceActivityMonitorExtension 2>/dev/null || true)
[ -n "$logs" ] && report "logging call in production source — nothing may log selection tokens (§16)" "$logs"

# 4) No third-party SDKs: the only package dependency is the local core.
deps=$(grep -nE 'url:\s*"' Packages/ScreenTimeNextCore/Package.swift 2>/dev/null || true)
[ -n "$deps" ] && report "remote package dependency in Package.swift" "$deps"
remote=$(grep -c 'XCRemoteSwiftPackageReference' ScreenTimeNext.xcodeproj/project.pbxproj 2>/dev/null || true)
[ "${remote:-0}" != "0" ] && report "remote package reference in the Xcode project" "count=$remote"

# 5) Selection payload must stay opaque: nothing outside ScreenTime/Selection touches `.payload`.
payload=$(grep -rn '\.payload' --include='*.swift' ScreenTimeNext Packages/ScreenTimeNextCore/Sources 2>/dev/null \
          | grep -v '^ScreenTimeNext/ScreenTime/Selection/' | grep -v 'Services/ScreenTimeSelectionService.swift' || true)
[ -n "$payload" ] && report "SelectionSnapshot.payload read outside the selection adapter (§13/§16)" "$payload"

# 6) Analytics / ads / crash SDK names.
sdk=$(grep -rniE 'firebase|amplitude|mixpanel|segment\.|sentry|crashlytics|admob|appsflyer|adjust\.com' \
      --include='*.swift' --include='*.pbxproj' . 2>/dev/null | grep -v '^./.git/' || true)
[ -n "$sdk" ] && report "analytics/ads SDK reference" "$sdk"

if [ $fail -ne 0 ]; then exit 1; fi
echo "privacy audit OK (no networking, no logging, no third-party SDKs, payload opaque)"
