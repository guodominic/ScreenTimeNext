---
task: "008"
title: Warning State Engine
status: not_started        # not_started | in_progress | blocked | done
depends_on: ["006"]
qa_criteria: ["QA-07"]
prd_refs: ["§11", "§6.6", "§6.11–§6.13"]
---

# Task 008 — Warning State Engine

## Objective
Implement deterministic 10/5/1-minute boundary logic as pure, fully-tested code in `Transition/Core/State/`.

## In scope
- A pure function/engine: given `(remainingSeconds, configuration, currentState)` → next `ScreenTimeState`.
- The §11 transition table, including the extension override path.
- Correct handling when one or more warnings are disabled per §6.6.
- Exhaustive unit tests, including exact-boundary and negative-remaining cases.

## Out of scope
- Presentation (→ Task 007) and notification delivery (→ Task 016).
- Enforcement side effects (→ Task 012).

## PRD detail
The state machine and full transition table are in `docs/prd/05-architecture.md` (§11):

`idle → active → warning10 → warning5 → warning1 → finished → shielded`, with
`finished | shielded → extended → active`.

Warning copy the engine's states drive:
- **warning10** (§6.11) — "10 minutes left 👋 You're almost done. What do you want to do next?" (child picks an activity)
- **warning5** (§6.12) — show the selected activity, encourage finishing
- **warning1** (§6.13) — "One more minute! Finish your game." with a simple `01:00` countdown

## Implementation notes
- Define boundaries once and unambiguously: 600 s, 300 s, 60 s. Decide `<=` vs `<` and test the exact-boundary second in both directions.
- The engine must be **monotonic within a session** — never step backward from `warning5` to `warning10` because of a one-second jitter. Only the extension path may move backward, and only via an explicit transition.
- A disabled warning (§6.6) is skipped as a presentation step, but the engine must still pass through or past its boundary deterministically. Decide and test whether the state is skipped or entered-and-not-shown.
- This file must have **zero imports** beyond Foundation. That is what makes it testable without a device.

## Architecture rules in force
- Rule 2 — logic lives in the state engine, not in views.
- Rule 3 — the engine is driven by computed remaining time, not by extension callbacks.

## Definition of Done
- [ ] **QA-07** (logic half) — 10/5/1 minute warning states are computed correctly.
- [ ] Every transition in the §11 table has a passing test.
- [ ] Exact-boundary seconds (600/300/60) and negative remaining are tested.
- [ ] Every combination of enabled/disabled warnings is tested.
- [ ] The engine imports nothing but Foundation.

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
