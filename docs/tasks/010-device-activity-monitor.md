---
task: "010"
title: Device Activity Monitor Extension
status: done               # not_started | in_progress | blocked | done
depends_on: ["005", "006"]
qa_criteria: []
prd_refs: ["§14", "§8"]
---

# Task 010 — Device Activity Monitor Extension

## Objective
Implement the DeviceActivity schedule and the daily-budget threshold, and the extension that receives the callback — using the current SDK only.

## In scope
- Concrete `ScreenTimeMonitoringService` in `ScreenTimeNext/ScreenTime/Monitoring/`.
- A daily monitoring schedule and a threshold derived from `dailyBudgetSeconds`.
- The `DeviceActivityMonitor` subclass in the extension target, receiving threshold and interval callbacks.
- Start/stop/restart of monitoring when configuration or selection changes.

## Out of scope
- Shielding (→ Task 011) — this task only proves the callback arrives.
- Connecting the callback to shielding (→ Task 012).

## PRD detail
§14: the daily budget is configured as a DeviceActivity monitoring threshold. When the system reports the threshold is reached, the extension is invoked. **The main app does not need to remain open.**

**Critical limitation:** extension execution must not be treated as a continuous per-second process. Do not design anything that requires the extension to be alive at a specific second, or that assumes the main app is running.

## Implementation notes
- **D-006 decided (Option A, session window):** the countdown and the 10/5/1 warnings come from `SessionWindow` timestamps; DeviceActivity is the enforcement backstop only.
- Verify `DeviceActivitySchedule`, `DeviceActivityName`, `DeviceActivityEvent`, and the monitor's callback signatures against the **installed SDK**. This is the area where outdated tutorials are most likely to be wrong.
- There are documented platform limits on the number of concurrent activities and events. Look up the current limits before designing around them, and record what you find in `docs/DECISIONS.md`.
- The schedule must cover a **daily** window and repeat. Decide how the window boundary relates to midnight and note it — Task 017 tests day rollover against this decision.
- Restarting monitoring on every trivial config change can lose accrued usage. Decide when a restart is warranted and document it.
- Prove the callback fires before building anything on top of it: log to shared storage (never to a place that leaks tokens) and read it from the app.
- This task very likely ends as **NEEDS MANUAL DEVICE TEST** — the simulator does not accrue real usage.

## Architecture rules in force
- Rule 3 — DeviceActivity is not a per-second timer.
- Rule 8 — installed SDK only; never invent API names.
- Rule 5 — the extension communicates through the App Group, not through the app.

## Definition of Done
- [x] Monitoring starts with a schedule and a threshold derived from the configured budget.
- [x] The extension receives and records the threshold callback with the app closed. — **proven
      on device 2026-09-06 18:03.**
- [x] Monitoring restarts correctly after a configuration or selection change.
- [x] No code path assumes the extension runs continuously or that the app is alive.
- [x] Platform limits and the schedule/midnight decision are recorded in `docs/DECISIONS.md` (D-037).
- [x] Verdict states clearly whether device testing is still required.

## Completion report

- **Files changed:**
  - `DeviceActivityMonitorExtension/` — new target (created in Xcode). Entitlements now carry the
    App Group *and* `family-controls`; `ScreenTimeNextCore` linked so both targets share the
    identifier and the journal (Rule 5). Deployment target corrected 27.0 → 18.0 so the embedded
    extension does not silently restrict the app to iOS 27 devices.
  - `DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` — five callbacks, each
    recording one journal entry. No async work, no UI, no notifications (Rule 3).
  - `ScreenTimeNext/ScreenTime/Monitoring/DeviceActivityMonitoringService.swift` — the real
    `ScreenTimeMonitoringService`: one daily schedule, one threshold, restart-only-if-different.
  - `ScreenTimeNext/ScreenTime/Monitoring/MonitoringCoordinator.swift` — decides *when* to
    register: launch and `.configurationDidChange`. Never polls.
  - `Packages/.../Models/MonitorReport.swift`, `Packages/.../Services/MonitorJournal.swift` — the
    extension's one-way channel to the app.
  - `ScreenTimeNextApp.swift` — real monitoring service wired in; coordinator started once.
  - `ParentDashboardView/ViewModel` — an "Enforcement" section: is iOS holding the registration,
    and what was the last check-in.
- **Build result:** Build Succeeded. Two warnings, both "Family Controls (Development)" — the
  distribution entitlement is still with Apple (B-006 / `docs/entitlement-request.md`).
- **Tests run:** `MonitorJournalTests` — trimming, suite round-trip, `latest`, today-vs-yesterday,
  and a §16 shape test asserting an entry carries only `event` / `activity` / `at`.
- **Verdict:** **PASS** (device-verified 2026-09-06)
- **Platform limitations or manual steps:** 20 activities max (counting the extension's), interval
  15 minutes to one week — all recorded in D-037. The threshold callback cannot be proven in the
  simulator: it needs real accrued usage on a real device.
- **Device test — RUN AND PASSED, 2026-09-06.** Budget set to 1 minute, 3 categories and 2 apps
  selected, ScreenTimeNext force-quit, a covered app used, dashboard reopened: the Enforcement
  section showed a `thresholdReached` check-in timestamped 18:03. So the whole chain works with the
  app not running — `DeviceActivityCenter` registration → system accounting → extension wake →
  App Group write → app read. **Tasks 011 and 012 are unblocked.**

  One thing the test caught that the code did not: the check-in line read
  "Last check-in the budget ran out · Sep 6, 2026 at 18:03" — every word true, and unreadable,
  because the label ran straight into the event. Dominic looked at a working check-in and could not
  tell it had worked, which for a status row is the same as it not working. Now two lines: the
  event as a heading, the timestamp beneath it.
- **Follow-up work:** Task 011 raises the shield inside `eventDidReachThreshold`; Task 012 connects
  it to the session and to `ProtectionState`.

> After finishing: update `status:` in this file's front-matter, update
> `docs/tasks/PROGRESS.md`, and log any new decision in `docs/DECISIONS.md`
> or new blocker in `docs/BLOCKERS.md`.
