---
task: "015"
title: Time's Up Experience
status: not_started        # not_started | in_progress | blocked | done
depends_on: ["009"]
qa_criteria: []
prd_refs: ["§6.14", "§6.15", "§7"]
---

# Task 015 — Time's Up Experience

## Objective
Implement the child-facing completion screen naming the activity the child chose.

## In scope
- The §6.14 screen: "Screen time is finished ❤️" plus the chosen next activity.
- The transition framing for the shield state described in §6.15.

## Out of scope
- The system shield UI itself (→ Task 011).
- Notifications (→ Task 016).

## PRD detail
§6.14 — show **"Screen time is finished ❤️"** plus the child-selected next activity, e.g.
**"You chose LEGO. Let's go build!"**

§6.15 — when a selected app is opened after time is exhausted, the system shielding experience is
presented where applicable; the app's own experience should frame the event as **transition rather
than punishment**.

§7 — avoid **"TIME'S UP!"** as the primary emotional framing. This screen is the single place where
that rule is most likely to be violated, and it is the emotional payoff of the whole product (§2).

## Implementation notes
- This screen is the product thesis in one view. If it reads as a penalty box, V1 has failed §2 regardless of whether enforcement works.
- Name the chosen activity explicitly and warmly; do not fall back to a generic 'time is over' message when a choice exists.
- Define the no-choice fallback (child never picked one) and keep it equally warm.
- No dismissal that returns the child to the shielded app — the exit is toward the activity, not back to the screen.
- Every string here goes through the §7 copy checklist.

## Architecture rules in force
- Rule 1 — presentation only; enforcement lives elsewhere.

## Definition of Done
- [ ] The screen renders the §6.14 copy and the chosen activity.
- [ ] The no-choice fallback is defined and warm.
- [ ] Nothing on the screen uses punitive framing; the §7 checklist is applied to every string.
- [ ] The screen exposes no technical detail to the child.

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
