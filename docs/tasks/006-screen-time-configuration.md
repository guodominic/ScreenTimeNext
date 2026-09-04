---
task: "006"
title: Screen Time Configuration
status: not_started        # not_started | in_progress | blocked | done
depends_on: ["002"]
qa_criteria: ["QA-05"]
prd_refs: ["§12", "§13", "§6.5", "§6.6"]
---

# Task 006 — Screen Time Configuration

## Objective
Implement the configuration models, App Group persistence behind `ScreenTimeStorageService`, and unit tests for both.

## In scope
- Models in `ScreenTimeNext/Core/Models/`: `ChildProfile`, `ScreenTimeConfiguration`, `DailyUsage`, `TransitionActivity`, `ScreenTimeState`, `ProtectionState`.
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
- **Prerequisite:** `docs/DECISIONS.md` D-006 (session-window vs. usage-accrual model) must be decided before this task starts. It changes what this task builds.
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
