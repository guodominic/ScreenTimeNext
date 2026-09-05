---
task: "009"
title: What's Next (Transition Activities)
status: done               # not_started | in_progress | blocked | done
depends_on: ["003", "006"]
qa_criteria: ["QA-08"]
prd_refs: ["§6.7", "§6.11", "§6.12", "§6.14"]
---

# Task 009 — What's Next (Transition Activities)

## Objective
Implement parent-side transition-activity selection and the child-side choice shown during the warning states.

## In scope
- Parent selection of allowed activities in onboarding and settings (§6.7).
- Child selection of one activity at the 10-minute warning (§6.11).
- Persisting both, and surfacing the child's choice in §6.12 and §6.14.

## Out of scope
- Custom or free-text activities — the set is fixed in V1.
- The Time's Up screen itself (→ Task 015).

## PRD detail
§6.7 fixed activity set: **LEGO, Drawing, Reading, Outside, Snack, Bath, Homework, Family Time.**

§6.11 — at the 10-minute warning the child is asked "What do you want to do next?" and picks one.
§6.12 — the five-minute warning shows the selected activity.
§6.14 — Time's Up names it: "You chose LEGO. Let's go build!"

This is the product's actual differentiator (§2): the child choosing the next activity is the
mechanism that is supposed to reduce conflict, and §21 lists it as an explicit validation question.

## Implementation notes
- The child chooses only from the parent-approved subset. If the parent approved none, define and document the fallback rather than showing an empty list.
- The child's choice must persist through to Time's Up even if the app is backgrounded in between.
- One tap to choose. §7 rule 4 — minimize interaction complexity in the final five minutes, so the choice happens at 10 minutes, not later.
- Activity labels are child-facing copy — run them through the §7 checklist.

## Architecture rules in force
- Rule 2 — selection logic in a view model, not the view.
- Rule 5 — the choice is shared state; store it where the rest of the session state lives.

## Definition of Done
- [ ] **QA-08** — the child can select a next activity.
- [ ] The parent-approved set gates the child's options.
- [ ] The choice persists to the five-minute warning and the Time's Up screen.
- [ ] The empty-approved-set case has defined, tested behavior.

## Completion report

**2026-09-05 — Claude. Verified in the batched run with 008/014/015 (see PROGRESS).**

- **Files changed:** package `TransitionActivity` (+`invitation`, `symbolName`), `SessionWindow.chosenActivity`,
  `SessionController.choose(_:)` / `availableActivities()`, `ChildSessionSnapshot.chosenActivity`;
  app `ChildTimerView` — `WhatsNextChooser` in `warning10`, `ChosenActivityBadge` in `warning5`;
  `ChildTimerViewModel.choose`. Tests: `WhatsNextTests` (8). Decision D-009.
- **Verdict:** **PASS** (automated; device check with the rest of the batch).
- **Design notes:** the choice is a field on the session window — persists through
  background/relaunch, reaches Time's Up, clears on the next Start. Empty parent set → all eight
  offered (D-009). Chooser only in `warning10` (§7.4). Parent onboarding was already gating the set.
- **Follow-up work:** Task 015 renders `invitation` on Time's Up (done in the same batch).

### DoD status
- [x] **QA-08** — the child can select a next activity (automated; device check pending in batch).
- [x] The parent-approved set gates the child's options (or all eight when none approved — D-009).
- [x] The choice persists to the five-minute warning and the Time's Up screen.
- [x] The empty-approved-set case has defined, tested behavior.
