---
task: "014"
title: Parent Dashboard
status: not_started        # not_started | in_progress | blocked | done
depends_on: ["006", "011"]
qa_criteria: []
prd_refs: ["§6.9"]
---

# Task 014 — Parent Dashboard

## Objective
Implement the parent dashboard showing budget, remaining time, protection status, selected content, and selected transition activities.

## In scope
- The §6.9 dashboard screen.
- Live-ish remaining time derived from timestamps (reusing Task 007's computation, not duplicating it).
- A display-safe summary of selected content — counts and categories, never raw tokens.
- Entry points to settings and to the parent extension flow.

## Out of scope
- Usage history or charts — not in V1 (§4, §16).

## PRD detail
§6.9 displays:
- today's budget
- remaining time
- protection status (`unshielded` / `shielded` / `temporarilyExtended`)
- selected content
- selected transition activities

## Implementation notes
- Read `ProtectionState` from shared storage on every appearance — the extension may have changed it while the app was closed (§14).
- Selected content must be summarized without rendering privacy-preserving tokens (§16). Apple provides label views for selected content; verify what the installed SDK offers rather than reconstructing names.
- Reuse the Task 007 remaining-time computation. Two implementations of the countdown will drift.
- Protection status is the parent's trust signal (§21: 'Do parents perceive the enforcement as reliable enough to trust?'). Make it unambiguous — never show a stale or optimistic state.

## Architecture rules in force
- Rule 1 — the dashboard reads view models, not frameworks.
- Rule 4 — remaining time from timestamps.

## Definition of Done
- [ ] All five §6.9 elements render.
- [ ] Protection status is re-read from shared storage on appearance and is never stale.
- [ ] Selected content is summarized with no token leakage in UI or logs.
- [ ] Remaining-time logic is shared with the child timer, not duplicated.

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
