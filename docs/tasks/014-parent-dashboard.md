---
task: "014"
title: Parent Dashboard
status: done               # not_started | in_progress | blocked | done
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

**2026-09-05 — Claude. Verified in the batched run with 008/009/015 (see PROGRESS).**

- **Files changed:** app `Features/ParentDashboard/{ParentDashboardViewModel,ParentDashboardView}.swift`
  (replaces the Task 003 placeholder), `Features/Settings/SettingsView.swift`; `RootView` routes to
  the dashboard. Dashboard shows §6.9's five items plus session status; "End session now" is behind
  a confirmation; "Extend time" is a visible, disabled row until Task 013. Settings edits name,
  budget presets, warnings, activities, protected content (mock picker), and "Start over".
- **Verdict:** **PASS** (automated build; device look with the batch).
- **Design notes:** protection state is re-read from storage on appear and on foreground (§14);
  remaining time comes from `SessionController` (shared with the child timer — one implementation).
  Settings note: budget changes apply from the next session (Task 017 owns mid-session config
  changes).
- **Follow-up work:** Task 005 replaces the mock picker in Settings too; Task 013 enables Extend.

### DoD status
- [x] All five §6.9 elements render (budget, remaining, protection, selected content, activities).
- [x] Protection status is re-read from shared storage on appearance and is never stale.
- [x] Selected content is summarized with no token leakage in UI or logs (counts only).
- [x] Remaining-time logic is shared with the child timer, not duplicated.
