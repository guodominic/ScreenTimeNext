# Architecture

Condensed reference. Full detail is in `docs/prd/05-architecture.md` (§8–§11),
`docs/prd/06-data-model.md` (§12–§13) and `docs/prd/07-enforcement.md` (§14–§15).

## High level

```text
SwiftUI App
 ├── Parent UI
 ├── Child UI
 ├── ViewModels
 └── Application Services
      ├── ScreenTimeAuthorizationService
      ├── ScreenTimeSelectionService
      ├── ScreenTimeMonitoringService
      ├── ScreenTimeShieldService
      └── ScreenTimeStorageService
             │
             ▼
       App Group Storage
             ▲
             │
DeviceActivityMonitor Extension
 └── threshold callbacks
       │
       ▼
 ManagedSettings
 └── shield selected content
```

The App Group container is the **only** channel between the app and the extension. The extension
must never assume the app is running, and the app must never assume its in-memory protection state
is current.

## Framework responsibilities

### FamilyControls
- Authorization
- `FamilyActivityPicker`
- Privacy-preserving activity selection

### DeviceActivity
- System-managed usage monitoring
- Threshold callbacks
- Monitoring schedules

### ManagedSettings
- Shield selected applications / categories / web domains
- Remove **only** Transition-managed restrictions

## The import boundary

`import FamilyControls`, `import DeviceActivity`, `import ManagedSettings` may appear only under:

- `Transition/ScreenTime/`
- `Transition/DeviceActivityMonitorExtension/`

One documented exception: the `FamilyActivityPicker` wrapper view (`docs/DECISIONS.md` D-001).

Everything under `Core/`, `Features/`, `Shared/` is framework-free — which means it builds, runs and
tests without an entitlement or a device.

## State machine

```text
idle → active → warning10 → warning5 → warning1 → finished → shielded
                                                       │  ▲
                                                       ▼  │
                                                   extended
```

Extension flow may transition `finished / shielded → extended → active`.

Two separate axes (`docs/DECISIONS.md` D-002):
- **`ScreenTimeState`** — where the child is in the session (`idle … finished, extended`)
- **`ProtectionState`** — whether content is enforced (`unshielded / shielded / temporarilyExtended`)

The extension writes `ProtectionState` while the app may not be running.

## Persistence

Use an App Group shared container. Keep persistence behind `ScreenTimeStorageService`.

Do not create a manual database mapping arbitrary app names to bundle IDs. Use Apple's selection
model — `FamilyActivitySelection` is the source of truth for selected content.

## Countdown

Never make `Timer` the source of truth. Persist absolute timestamps and derive remaining time from
current time. A `Timer` may drive redraws only.

## Extension constraints

Do not assume the extension executes continuously or that the main app is alive. Enforcement must be
designed around system callbacks and supported APIs. Inside the extension: read, act, write, return —
nothing more.
