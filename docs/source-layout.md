# Source layout

Set by Task 001 (D-008). Deviates from PRD Appendix A in two deliberate ways: the framework-free
code is a local Swift package, and the extension folder sits beside the app folder rather than
inside it. Everything else follows Appendix A.

```text
ScreenTimeNext.xcodeproj            Xcode 26 project (synchronized folders — files on disk are
                                    picked up automatically; no manual "add to target")
ScreenTimeNext/                     app target — SwiftUI only
├── ScreenTimeNextApp/              entry point, root navigation
├── Features/
│   ├── Onboarding/                 §6.1–§6.8
│   ├── ParentDashboard/            §6.9
│   ├── ChildTimer/                 §6.10
│   ├── Warnings/                   §6.11–§6.13
│   ├── WhatsNext/                  §6.7 + child choice
│   └── Settings/                   parent settings, §6.16 entry
├── ScreenTime/                     the ONLY app code that imports Apple Screen Time frameworks
│   ├── Authorization/              FamilyControls          (Task 004)
│   ├── Selection/                  FamilyControls, picker  (Task 005)
│   ├── Monitoring/                 DeviceActivity          (Task 010)
│   └── Shielding/                  ManagedSettings         (Task 011)
└── Resources/                      Assets.xcassets
Packages/ScreenTimeNextCore/        local Swift package — Foundation only, shared by app + extension
├── Package.swift
├── Sources/ScreenTimeNextCore/
│   ├── Models/                     §12 models, SessionWindow
│   ├── Services/                   the five service PROTOCOLS + domain enums
│   ├── State/                      WarningStateEngine (pure logic)
│   └── Constants/                  App Group id, storage keys, monitoring names
└── Tests/ScreenTimeNextCoreTests/  unit tests — `swift test` from the package dir, or ⌘U in Xcode
DeviceActivityMonitorExtension/     extension target folder — EMPTY until Phase 1 (D-007)
```

## The import boundary

`import FamilyControls`, `import DeviceActivity` and `import ManagedSettings` may appear **only** in
`ScreenTimeNext/ScreenTime/` and `DeviceActivityMonitorExtension/`.

`Packages/ScreenTimeNextCore/` must never import them — it is the code that builds and tests with
no entitlement, no device and no Xcode UI, which is what keeps Phase 0 moving on a free account.
`ScreenTimeNext/Features/` must not import them either: views talk to view models, view models talk
to the protocols in the package. One documented exception: the `FamilyActivityPicker` wrapper view
under `ScreenTime/Selection/` (D-001).

## Why the extension folder is outside the app folder
Xcode 26 synchronized folders compile everything under `ScreenTimeNext/` into the app target,
recursively. An extension folder nested there would be compiled into the app. So it lives beside it.

## Why a package instead of plain folders
- Both the app and the extension need the models, protocols and storage — a package is how two
  targets share code without duplicating files.
- Tests come with the package; no separate test target surgery in the project file.
- The boundary is structural: the package simply has no way to reach the app's frameworks.
- `swift build` / `swift test` work from Terminal with no Xcode UI.

## Running the tests
```bash
cd Packages/ScreenTimeNextCore && swift test
```
