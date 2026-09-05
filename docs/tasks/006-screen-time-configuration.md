---
task: "006"
title: Screen Time Configuration
status: done               # not_started | in_progress | blocked | done  (App Group impl at Phase 1 gate)
depends_on: ["002"]
qa_criteria: ["QA-05"]
prd_refs: ["§12", "§13", "§6.5", "§6.6"]
---

# Task 006 — Screen Time Configuration

## Objective
Implement the configuration models, App Group persistence behind `ScreenTimeStorageService`, and unit tests for both.

## In scope
- Models in `Packages/ScreenTimeNextCore/Sources/ScreenTimeNextCore/Models/`: `ChildProfile`, `ScreenTimeConfiguration`, `DailyUsage`, `TransitionActivity`, `ScreenTimeState`, `ProtectionState`.
- Concrete `ScreenTimeStorageService` writing to the App Group shared container.
- Schema versioning so a future model change does not silently destroy a parent's configuration.
- Unit tests for round-trip encode/decode, defaults, and migration of a missing/corrupt store.

## Out of scope
- The `FamilyActivitySelection` blob (→ Task 005 owns it, though it lives in the same container).
- Day-rollover logic (→ Task 017).

## PRD detail
Field-level definitions are in `docs/prd/06-data-model.md` (§12). Defaults come from §6.5 and §6.6:
`dailyBudgetSeconds` defaults to **3600** (60 minutes); all three warning flags default to **true**.

§13: use an App Group shared container; a dedicated storage abstraction hides the persistence mechanism.

Note the deliberate split — `ScreenTimeState` tracks the *session*, `ProtectionState` tracks
*enforcement*. They are two axes and must not be collapsed into one enum. See `docs/DECISIONS.md` D-002.

## Implementation notes
- **D-006 decided (Option A, session window):** the countdown and the 10/5/1 warnings come from `SessionWindow` timestamps; DeviceActivity is the enforcement backstop only.
- **Phase 0 / free account (D-007):** App Groups are unavailable, so ship a `LocalStorageService` (app container) first. The App Group implementation comes in Phase 1 behind the same `ScreenTimeStorageService` protocol — the switch must be a one-line DI change, nothing else.
- Both the app and the extension read this store. Assume concurrent access and write atomically.
- The extension may write `ProtectionState` while the app is not running (§14) — the app must re-read on foreground rather than trusting its in-memory copy.
- Store the budget in **seconds** as §12 specifies, and convert at the presentation layer only.
- Tests here are cheap and high-value: this is pure logic with no framework dependency.

## Architecture rules in force
- Rule 5 — App Groups for state shared with extensions.
- Rule 2 — persistence stays behind `ScreenTimeStorageService`.

## Definition of Done
- [ ] **QA-05** — the daily budget survives a relaunch.
- [ ] All six model types from §12 exist with the specified fields.
- [ ] Storage is in the App Group container and readable from the extension target.
- [ ] A corrupt or missing store yields documented defaults instead of a crash.
- [ ] Unit tests cover round-trip, defaults, and corrupt-store recovery.

## Completion report

**2026-09-05 — Claude; verified by Dominic (`./scripts/test.sh`, `./scripts/build.sh`).**

- **Files changed:** package `Storage/FileStorageService.swift` (one JSON file per record, atomic
  writes, schema manifest + migration hook, corrupt file → defaults/nil, usage bucketed by local
  day and pruned to 14 days, `appContainer()` / `appGroup(identifier:)` factories);
  `ScreenTimeStorageService` protocol gained `eraseAll()`; in-memory mock updated;
  `ServiceContainer.phase0()` (mocks + real file storage, `storageIsVolatile` fallback flag);
  app `ScreenTimeNextApp` now runs on `.phase0()`; `RootView.reset()` erases; home footer reports
  storage state. Tests: `FileStorageServiceTests` (8).
- **Build result:** `./scripts/build.sh` — BUILD OK.
- **Tests run:** `./scripts/test.sh` — **40 tests, 0 failures**.
- **Verdict:** **PASS** (Phase 0 scope). App Group container: **BLOCKED (by gate)** — same class,
  different directory, switched in `ServiceContainer.phase0()`'s successor at Phase 1.
- **Platform limitations or manual steps:** models from §12 already existed (Task 001). Budget is
  stored in seconds; presentation converts. D-006 (session window) decided — `SessionWindow` is
  persisted as its own record.
- **Follow-up work:** Phase 1 — `FileStorageService.appGroup()` becomes the container once the
  capability exists (B-002); extension reads the same files. QA-05 manual check: onboard, kill
  the app, relaunch → lands on home.

### DoD status
- [x] **QA-05** — daily budget survives a relaunch (automated: second instance on the same directory; manual relaunch pending with QA-01)
- [x] All six model types from §12 exist with the specified fields.
- [ ] Storage is in the App Group container and readable from the extension target — **blocked by gate (D-007 / B-002)**; app-container directory in Phase 0.
- [x] A corrupt or missing store yields documented defaults instead of a crash.
- [x] Unit tests cover round-trip, defaults, and corrupt-store recovery.
