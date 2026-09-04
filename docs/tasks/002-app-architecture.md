---
task: "002"
title: App Architecture
status: not_started        # not_started | in_progress | blocked | done
depends_on: ["001"]
qa_criteria: []
prd_refs: ["§9", "§10", "§12"]
---

# Task 002 — App Architecture

## Objective
Define the service protocols and dependency boundaries so that views never touch Apple Screen Time frameworks.

**Acceptance:** views contain no direct Screen Time framework calls.

## In scope
- Five protocols in `Transition/Core/Services/`, all **framework-free**: `ScreenTimeAuthorizationService`, `ScreenTimeSelectionService`, `ScreenTimeMonitoringService`, `ScreenTimeShieldService`, `ScreenTimeStorageService`.
- Domain-level enums the protocols speak in (e.g. an authorization status enum owned by this app, not re-exported from FamilyControls).
- Mock implementations of all five, so Task 003 can build the whole onboarding flow without entitlements.
- A dependency container / environment injection point so views resolve services rather than constructing them.

## Out of scope
- Real framework implementations (→ Tasks 004, 005, 010, 011).
- Persistence internals (→ Task 006).

## PRD detail
§9 names the five services. §10 rules 1 and 2 are what this task exists to enforce: views call view models, view models call protocols, and only `Transition/ScreenTime/` implements those protocols against Apple frameworks.

The protocol surface must not leak framework types. A protocol returning `FamilyActivitySelection` would force `import FamilyControls` into the core layer and defeat the boundary — see `docs/DECISIONS.md` D-001 for how selection crosses this line.

## Implementation notes
- Design the selection protocol around an **opaque, serializable snapshot** plus display-safe summary counts. The concrete implementation in `ScreenTime/Selection/` owns the real `FamilyActivitySelection`.
- Prefer `async`/`await` on protocol methods that will be async in their real implementation, so adopting the real service later is not a signature change.
- Mocks must be able to simulate failure states, not only happy paths — Task 004 needs a denied-authorization mock and Task 017 needs a revoked one.
- Add a build-time or CI check (script or test) that greps for framework imports outside the allowed directories. This rule is worth automating once.

## Architecture rules in force
- Rule 1 — SwiftUI views must not directly call Screen Time frameworks.
- Rule 2 — use service abstractions.
- Rule 7 — `FamilyActivitySelection` remains the source of truth for selected content; the abstraction wraps it, never replaces it.

## Definition of Done
- [ ] All five protocols exist and compile with no Screen Time framework imports.
- [ ] Mock implementations exist for all five, including failure modes.
- [ ] No file under `Core/`, `Features/`, or `Shared/` imports FamilyControls, DeviceActivity, or ManagedSettings.
- [ ] A test or script enforces the previous line automatically.
- [ ] Dependency injection point exists and is used by at least one view.

## Completion report
Append the result here when the task finishes. Do not edit earlier tasks' reports.

- **Files changed:**
- **Build result:**
- **Tests run:**
- **Verdict:** PASS / FAIL / BLOCKED / NEEDS MANUAL DEVICE TEST
- **Platform limitations or manual steps:**
- **Follow-up work:**

> After finishing: update `status:` in this file's front-matter, update
> `docs/tasks/PROGRESS.md`, and log any new decision in `docs/DECISIONS.md`
> or new blocker in `docs/BLOCKERS.md`.
