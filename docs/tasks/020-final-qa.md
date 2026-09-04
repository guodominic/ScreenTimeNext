---
task: "020"
title: Final QA
status: not_started        # not_started | in_progress | blocked | done
depends_on: ["019"]
qa_criteria: ["QA-01…QA-15"]
prd_refs: ["§19", "§22"]
---

# Task 020 — Final QA

## Objective
Run the full QA audit across all 15 §19 acceptance criteria and report PASS / FAIL / BLOCKED / NEEDS MANUAL DEVICE TEST for each.

## In scope
- Execution of all 15 criteria in `docs/prd/09-qa-and-done.md`.
- A written verdict per criterion with evidence.
- An explicit §22 Definition-of-Done judgement on both halves: transition experience **and** real enforcement.
- A consolidated list of everything still BLOCKED or needing device testing.

## Out of scope
- Fixing what is found — file follow-up tasks instead of expanding this one (Rule 9).

## PRD detail
The 15 criteria and their owning tasks are tabulated in `docs/prd/09-qa-and-done.md`.

§22 Definition of Done — V1 is complete only when the app provides a coherent transition experience
**AND** reliably uses Apple's Screen Time APIs to enforce the configured limit under supported
platform conditions. **A polished timer without actual enforcement is a prototype, not the V1 product.**

Report each criterion as exactly one of: **PASS / FAIL / BLOCKED / NEEDS MANUAL DEVICE TEST.**

## Implementation notes
- Enforcement criteria (QA-09, QA-10, QA-11) must be verified on a **physical device with the app force-quit**. A simulator result is not evidence.
- Do not soften a verdict. A BLOCKED entitlement is a BLOCKED verdict — it is information the project needs, not a failure to hide.
- Judge the two halves of §22 separately and state both. Passing the experience half while the enforcement half is blocked means V1 is not done, and the report should say so plainly.
- Record the results table in `docs/tasks/PROGRESS.md` so the state survives into the next session.

## Architecture rules in force
- Rule 9 — audit only; do not start fixing inside this task.
- Rule 10 — full build and test run before reporting.

## Definition of Done
- [ ] All 15 criteria have a verdict with evidence.
- [ ] QA-09/10/11 were verified on a physical device with the app force-quit, or are explicitly marked NEEDS MANUAL DEVICE TEST.
- [ ] The §22 judgement names both halves separately.
- [ ] All outstanding BLOCKED items are consolidated in `docs/BLOCKERS.md`.
- [ ] Follow-up tasks are filed for every FAIL rather than fixed inline.
- [ ] `docs/tasks/PROGRESS.md` reflects the final state.

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
