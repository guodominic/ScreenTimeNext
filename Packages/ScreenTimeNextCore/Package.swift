// swift-tools-version: 5.9
//
// ScreenTimeNextCore — the framework-free core of ScreenTimeNext.
//
// Everything in this package imports Foundation only. It is shared by the app target and,
// in Phase 1, by the DeviceActivityMonitor extension. It builds and tests with `swift test`
// from the command line, with no entitlement, no device and no Xcode UI.
//
// Rule: this package must NEVER import FamilyControls, DeviceActivity or ManagedSettings.
// Those adapters live in ScreenTimeNext/ScreenTime/ and DeviceActivityMonitorExtension/.

import PackageDescription

let package = Package(
    name: "ScreenTimeNextCore",
    platforms: [
        .iOS("18.0"),
        .macOS("14.0"),   // host platform for `swift test`; NSLock.withLock needs 13+
    ],
    products: [
        .library(name: "ScreenTimeNextCore", targets: ["ScreenTimeNextCore"]),
    ],
    targets: [
        .target(
            name: "ScreenTimeNextCore",
            path: "Sources/ScreenTimeNextCore"
        ),
        .testTarget(
            name: "ScreenTimeNextCoreTests",
            dependencies: ["ScreenTimeNextCore"],
            path: "Tests/ScreenTimeNextCoreTests"
        ),
    ]
)
