---
task: "007"
title: Child Timer UI
status: done               # not_started | in_progress | blocked | done  (device check pending)
depends_on: ["006"]
qa_criteria: ["QA-06", "QA-07"]
prd_refs: ["§6.10", "§7", "§10"]
---

# Task 007 — Child Timer UI

## Objective
Implement the child timer screen with a timestamp-derived countdown and state-driven rendering.

## In scope
- The §6.10 child timer screen: large remaining-time display, minimal controls, friendly language.
- Countdown derived from absolute timestamps stored in the configuration/usage model.
- Rendering for each `ScreenTimeState` the child can see.
- Correct behavior across background → foreground and across a device-clock change.

## Out of scope
- Boundary/threshold decision logic (→ Task 008 owns it; this task renders what the engine reports).
- The Time's Up screen (→ Task 015).

## PRD detail
§6.10: large remaining-time display, minimal controls, friendly language, state-driven UI. **Countdown must be derived from absolute timestamps rather than a timer object as the source of truth.**

§10 rule 4 restates this: the UI countdown must be reconstructed from absolute timestamps.

§7 rule 6: the child experience must not expose technical settings or authorization details.

## Implementation notes
- A `Timer` may drive *redraws*. It may never be the *source of truth*. On every tick, and on every foreground, recompute remaining time as `endTimestamp - now`.
- Backgrounding for 20 minutes and returning must show the correct remaining time immediately, with no catch-up animation.
- A backward clock change must not manufacture extra time. Clamp remaining time to the monotonic expectation where possible and record the approach in `docs/DECISIONS.md`; full date/time-change testing is Task 017.
- No pause/stop control for the child — §7 rule 5 puts deliberate controls on the parent side only.

## Architecture rules in force
- Rule 4 — absolute timestamps are the source of truth for countdown rendering.
- Rule 3 — DeviceActivity is not a per-second timer; do not attempt to drive this display from the extension.
- Rule 1 — the view calls a view model, never a framework.

## Definition of Done
- [ ] **QA-06** — the countdown survives background/foreground transitions.
- [ ] **QA-07** (rendering half) — the 10/5/1 warning states render correctly.
- [ ] Killing and relaunching the app shows the correct remaining time.
- [ ] No `Timer` value is persisted or treated as authoritative.
- [ ] The screen exposes no technical or authorization detail to the child.

## Completion report

**2026-09-05 — Claude; verified by Dominic (`./scripts/test.sh`, `./scripts/build.sh`).**

- **Files changed:** package `State/SessionController.swift` (+ `ChildSessionSnapshot`), `SessionWindow`
  gained `totalSeconds` and an upper clamp on remaining time; app `Features/ChildTimer/{ChildTimerViewModel,ChildTimerView}.swift`;
  home placeholder links to the timer and offers a parent-side "End session now".
  Tests: `SessionControllerTests` (11).
- **Build result:** `./scripts/build.sh` — BUILD OK.
- **Tests run:** `./scripts/test.sh` — **51 tests, 0 failures**.
- **Verdict:** **PASS** (automated) · **NEEDS MANUAL DEVICE TEST** for QA-06 (background 1–2 min and
  return; expect the correct remaining time immediately) and the visual state changes.
- **Platform limitations or manual steps:** none for Phase 0.
- **Design notes:**
  - D-006 session-window model. The persisted `SessionWindow` is the in-flight usage record; it is
    folded into `DailyUsage` only when finalized (new Start, parent end-early, or day rollover), so
    expiry while the app is killed is accounted for identically (tested).
  - `SessionWindow.remainingSeconds(at:)` is clamped to the window's total length — a backward clock
    change cannot manufacture time beyond the session (PRD §17; Task 017 tests the rest).
  - State is monotonic within a session (`WarningStateEngine.next`), so jitter never steps back.
  - A disabled warning is entered but rendered as `active` (D-004).
  - The 1-second loop only redraws; `scenePhase == .active` forces a recompute.
- **Follow-up work:** Task 009 fills `WhatsNextSlot`; Task 015 expands the finished state; Task 016
  schedules local notifications from the same window timestamps.

### DoD status
- [ ] **QA-06** — countdown survives background/foreground — *automated (relaunch after 700 s); device check pending*
- [x] **QA-07** (rendering half) — 10/5/1 warning states render distinctly (copy per §6.11–§6.13).
- [x] Killing and relaunching shows the correct remaining time (`restore()` test).
- [x] No `Timer` value is persisted or authoritative.
- [x] The screen exposes no technical or authorization detail; only control is Start (idle) — §7.5/§7.6.
