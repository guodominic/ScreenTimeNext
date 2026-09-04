# Transition — source layout

This tree follows PRD Appendix A. The layout exists to enforce one rule.

## The import boundary

`import FamilyControls`, `import DeviceActivity`, and `import ManagedSettings` may appear **only** in:

- `ScreenTime/` — the four adapter directories
- `../Transition/DeviceActivityMonitorExtension/` — the monitor extension

Everything else is framework-free. That is not stylistic: it is what lets `Core/`, `Features/` and
`Shared/` build, run and unit-test **without an entitlement and without a device**, while the Family
Controls entitlement request is pending (`docs/BLOCKERS.md` B-001).

One documented exception: the `FamilyActivityPicker` wrapper view under `ScreenTime/Selection/`
(`docs/DECISIONS.md` D-001).

## Directories

| Path | Contains | Imports |
|---|---|---|
| `TransitionApp/` | App entry point, root navigation | SwiftUI |
| `Core/Models/` | Pure data models (§12) | Foundation |
| `Core/Services/` | Service **protocols** and domain enums | Foundation |
| `Core/Repositories/` | Persistence-facing abstractions | Foundation |
| `Core/State/` | State machine, warning engine — pure logic | Foundation |
| `Features/Onboarding/` | §6.1–§6.8 | SwiftUI |
| `Features/ParentDashboard/` | §6.9 | SwiftUI |
| `Features/ChildTimer/` | §6.10 | SwiftUI |
| `Features/Warnings/` | §6.11–§6.13 | SwiftUI |
| `Features/WhatsNext/` | §6.7 + child choice | SwiftUI |
| `Features/Settings/` | Parent settings, §6.16 entry | SwiftUI |
| `ScreenTime/Authorization/` | `AuthorizationCenter` adapter | FamilyControls |
| `ScreenTime/Selection/` | Picker wrapper + selection adapter | FamilyControls |
| `ScreenTime/Monitoring/` | Schedule + threshold adapter | DeviceActivity |
| `ScreenTime/Shielding/` | Scoped shield adapter | ManagedSettings |
| `Shared/Storage/` | App Group container access | Foundation |
| `Shared/Constants/` | App Group ID, keys, activity names | Foundation |
| `DeviceActivityMonitorExtension/` | `DeviceActivityMonitor` subclass | DeviceActivity, ManagedSettings |

## Status of the files here

The `.swift` files currently in `Core/` and `Shared/` are **framework-free starting points** written
ahead of Task 001, so that Tasks 002, 006 and 008 begin from a shared vocabulary rather than an empty
folder. They compile against Foundation alone and are not yet members of an Xcode target — Task 001
creates the project and adds them.

Nothing under `ScreenTime/` or `DeviceActivityMonitorExtension/` is pre-written: those files call
Apple APIs, and Rule 8 says they must be written against the installed SDK, not guessed in advance.
