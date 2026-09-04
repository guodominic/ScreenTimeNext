---
task: "010"
title: Device Activity Monitor Extension
status: not_started        # not_started | in_progress | blocked | done
depends_on: ["005", "006"]
qa_criteria: []
prd_refs: ["§14", "§8"]
---

# Task 010 — Device Activity Monitor Extension

## Objective
Implement the DeviceActivity schedule and the daily-budget threshold, and the extension that receives the callback — using the current SDK only.

## In scope
- Concrete `ScreenTimeMonitoringService` in `Transition/ScreenTime/Monitoring/`.
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
- [ ] Monitoring starts with a schedule and a threshold derived from the configured budget.
- [ ] The extension receives and records the threshold callback with the app closed.
- [ ] Monitoring restarts correctly after a configuration or selection change.
- [ ] No code path assumes the extension runs continuously or that the app is alive.
- [ ] Platform limits and the schedule/midnight decision are recorded in `docs/DECISIONS.md`.
- [ ] Verdict states clearly whether device testing is still required.

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
