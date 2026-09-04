# 10 — Appendices

## Appendix A — Suggested project structure

```text
ScreenTimeNext/
├── ScreenTimeNextApp/                     app entry point, root navigation
├── Core/
│   ├── Models/                        pure data models, no framework imports
│   ├── Services/                      service PROTOCOLS (framework-free)
│   ├── Repositories/                  persistence-facing abstractions
│   └── State/                         state machine + warning engine (pure logic)
├── Features/
│   ├── Onboarding/
│   ├── ParentDashboard/
│   ├── ChildTimer/
│   ├── Warnings/
│   ├── WhatsNext/
│   └── Settings/
├── ScreenTime/                        the ONLY place Apple Screen Time frameworks are imported
│   ├── Authorization/                 FamilyControls
│   ├── Selection/                     FamilyControls
│   ├── Monitoring/                    DeviceActivity
│   └── Shielding/                     ManagedSettings
├── Shared/
│   ├── Storage/                       App Group container access
│   └── Constants/                     App Group ID, activity names, keys
└── DeviceActivityMonitorExtension/
    └── DeviceActivityMonitor.swift
```

**The rule this layout encodes:** `import FamilyControls`, `import DeviceActivity`, and
`import ManagedSettings` may appear **only** under `ScreenTimeNext/ScreenTime/` and
`ScreenTimeNext/DeviceActivityMonitorExtension/`. Everywhere else is framework-free and unit-testable.
(One documented exception exists for the `FamilyActivityPicker` wrapper view — see
`docs/DECISIONS.md` D-001.)

## Appendix B — Claude Code operating principles

1. Read `CLAUDE.md` before changing code.
2. Implement **one task at a time**.
3. Run build/tests after each task.
4. Do **not** silently change architecture to work around an API limitation.
5. When an Apple API is unavailable or entitlement-gated, mark the task **BLOCKED** and explain the
   required manual step.
6. Prefer small, testable components over large SwiftUI views.
7. **Never invent Apple API names.**
8. Do not introduce a backend or analytics without an explicit product decision.
