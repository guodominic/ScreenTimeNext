---
task: "007"
title: Child Timer UI
status: not_started        # not_started | in_progress | blocked | done
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
