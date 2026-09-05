# ScreenTimeNext — Claude Code Instructions

## Mission
Build ScreenTimeNext, a Screen Time Transition Assistant + Parental Control for iOS/iPadOS.

Core promise: **Make screen time end peacefully.**

The product combines:
- a child-friendly transition experience
- Apple's FamilyControls
- Apple's DeviceActivity
- Apple's ManagedSettings

## Non-negotiable architecture rules
1. SwiftUI views must not directly call Screen Time frameworks.
2. Use service abstractions.
3. DeviceActivity is not a per-second timer.
4. Use absolute timestamps as the source of truth for countdown rendering.
5. Use App Groups for state shared with extensions.
6. Never indiscriminately clear ManagedSettings.
7. Treat FamilyActivitySelection as the source of truth for selected content.
8. Use the current installed SDK. Never invent or blindly copy deprecated Apple APIs.
9. Implement one task at a time.
10. Build and test after every task.

The only recorded exception to Rule 1 is the `FamilyActivityPicker` wrapper — see
`docs/DECISIONS.md` D-001. Any further exception needs its own decision entry.

## Definition of Done
V1 is not complete until supported Screen Time enforcement works through Apple's Screen Time APIs.
A UI-only timer is only a prototype.

## Product principles
- Transition, not punishment.
- Warn early.
- Give the child a next activity.
- Keep child UI simple.
- Keep parent controls explicit.
- V1 has no backend.

---

## How to work in this repository

### Start of every session
1. Read `docs/tasks/PROGRESS.md` — it says what is done, what is next, and what is blocked.
2. Read `docs/BLOCKERS.md` — do not re-attempt something already known to be entitlement-gated.
3. Open the single task file you are about to implement. Implement **only** that task (Rule 9).

### While working
- Xcode 26 synchronized folders: a `.swift` file written under `ScreenTimeNext/` or the package's
  `Sources/` is compiled automatically. Never put non-source files (README, .gitkeep) under
  `ScreenTimeNext/` — they would ship inside the app bundle.
- Run the package tests from Terminal: `cd Packages/ScreenTimeNextCore && swift test`.
- The task file's **PRD detail** section is authoritative for behavior; `docs/prd/` has the full text.
- Do not silently change architecture to work around an API limitation. If an Apple API is
  unavailable or entitlement-gated, mark the task **BLOCKED**, write the required manual step into
  `docs/BLOCKERS.md`, and stop.
- Never invent Apple API names. Verify against the installed SDK, not against tutorials.
- Prefer small, testable components over large SwiftUI views.
- Do not introduce a backend or analytics without an explicit product decision.

### End of every task
1. Build and run tests (Rule 10).
2. Fill in the **Completion report** in the task file with a verdict:
   `PASS` / `FAIL` / `BLOCKED` / `NEEDS MANUAL DEVICE TEST`.
3. Update `status:` in that task file's front-matter.
4. Update the row in `docs/tasks/PROGRESS.md`.
5. Log any non-obvious choice in `docs/DECISIONS.md`; log any manual-step dependency in
   `docs/BLOCKERS.md`.
6. Commit with the task number in the subject, e.g. `task 007: timestamp-based child countdown`.

## Where things are

| Path | What it is |
|---|---|
| `docs/prd/` | The PRD, split into readable markdown. **Read this, not the .docx.** |
| `docs/architecture.md` | Condensed architecture reference |
| `docs/tasks/PROGRESS.md` | Project status — read first, update last |
| `docs/tasks/0NN-*.md` | The 20 implementation tasks, in order |
| `docs/DECISIONS.md` | Why things are the way they are |
| `docs/BLOCKERS.md` | What code cannot fix (entitlements, approvals, device tests) |
| `docs/market-analysis.md` | Feasibility and market judgement (for humans, not the agent) |
| `docs/entitlement-request.md` | Family Controls entitlement: checklist + paste-ready form answers |
| `PRIVACY.md` | Privacy policy — DRAFT until Task 018 audits it |
| `docs/reference/` | The signed .docx PRD, archived |
| `ScreenTimeNext.xcodeproj` | Xcode project (synchronized folders — files on disk are picked up automatically) |
| `ScreenTimeNext/` | App target: SwiftUI + the `ScreenTime/` framework adapters. See `docs/source-layout.md`. |
| `Packages/ScreenTimeNextCore/` | Local Swift package: models, service protocols, state engine, constants — Foundation only. Its `Tests/` are the unit tests. |
| `DeviceActivityMonitorExtension/` | Extension target folder — empty until Phase 1 |

## The import boundary
`import FamilyControls`, `import DeviceActivity`, and `import ManagedSettings` may appear **only**
under `ScreenTimeNext/ScreenTime/` and `DeviceActivityMonitorExtension/`. `Packages/ScreenTimeNextCore/`
is Foundation-only by construction.

Everything under `Packages/ScreenTimeNextCore/` and `ScreenTimeNext/Features/` is framework-free and unit-testable without a
device or an entitlement. This is what keeps the project moving while the entitlement is pending.
