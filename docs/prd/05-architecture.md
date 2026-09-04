# 05 — Platform Architecture, Rules & State Machine

PRD sections: §8 Apple Platform Architecture, §9 High-Level Architecture, §10 Architectural Rules,
§11 State Machine. See also `docs/architecture.md`.

## §8 Framework responsibilities

| Framework | Owns |
|---|---|
| **FamilyControls** | Authorization; `FamilyActivityPicker` selection |
| **DeviceActivity** | System-managed activity monitoring; threshold callbacks; schedules |
| **ManagedSettings** | Shielding selected applications / categories / web domains |
| **App Groups** | Shared persistence between the main app and extensions |

SwiftUI is the presentation layer. All Apple Screen Time integrations sit **behind service
abstractions**.

## §9 High-level architecture

```text
ScreenTimeNextApp
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
      App Group shared container
              ▲
              │
DeviceActivityMonitorExtension
└── DeviceActivityMonitor
```

## §10 Architectural rules
1. SwiftUI views must not directly call FamilyControls, DeviceActivity, or ManagedSettings APIs.
2. Business logic belongs in services / state engines / view models — **not** in views.
3. DeviceActivity is **not** a per-second countdown engine.
4. The UI countdown must be reconstructed from **absolute timestamps**.
5. ManagedSettings operations must be **scoped to ScreenTimeNext-managed settings**; never
   indiscriminately clear all settings.
6. The extension must **not** assume the main application is running.
7. Apple framework API usage must match the **installed/current SDK**, never copied from outdated
   tutorials.

## §11 State machine

```text
idle ──▶ active ──▶ warning10 ──▶ warning5 ──▶ warning1 ──▶ finished ──▶ shielded
                                                                │  ▲
                                                                ▼  │
                                                            extended
                                                        (parent override)
```

- Normal path: `idle → active → warning10 → warning5 → warning1 → finished → shielded`
- Override path: `finished | shielded → extended → active`
- When an extension expires, protection is reapplied (back toward `finished → shielded`).

### Transition table

| From | Trigger | To |
|---|---|---|
| `idle` | child session starts | `active` |
| `active` | remaining ≤ 10 min | `warning10` |
| `warning10` | remaining ≤ 5 min | `warning5` |
| `warning5` | remaining ≤ 1 min | `warning1` |
| `warning1` | remaining ≤ 0 | `finished` |
| `finished` | DeviceActivity threshold / protected app opened | `shielded` |
| `finished` \| `shielded` | parent grants +10 / +20 / Allow Once | `extended` |
| `extended` | allowance applied | `active` |
| `extended` | allowance expires | `finished` → `shielded` |
| any | day rollover (midnight) | `idle` |

**Note:** a disabled warning (§6.6) is skipped as a *presentation* step, but the boundary logic must
still be deterministic — see Task 008.
