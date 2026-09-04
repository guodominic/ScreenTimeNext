---
task: "018"
title: Privacy Audit
status: not_started        # not_started | in_progress | blocked | done
depends_on: ["017"]
qa_criteria: ["QA-15"]
prd_refs: ["§16"]
---

# Task 018 — Privacy Audit

## Objective
Audit all logging and data collection, then produce `PRIVACY.md` at the repository root.

## In scope
- A full sweep of logging, analytics, crash reporting, and any network call in the codebase.
- Verification that no FamilyActivity tokens or selection contents are logged.
- Audit and finalize the existing **draft** `PRIVACY.md` (written 2026-09-04 for the entitlement request and App Store Connect) against the shipped code; every statement in it is a commitment to verify, not a description to trust.
- The data-collection answers needed for the App Store privacy questionnaire (used by Task 019).

## Out of scope
- Any backend or analytics integration — introducing one requires an explicit product decision (Appendix B rule 8).

## PRD detail
§16 principles:
- No backend required for V1.
- No child identity beyond the minimum local profile.
- No detailed app-usage history sent to a server.
- **Do not log sensitive FamilyActivity tokens.**
- Keep Screen Time data local unless a future feature explicitly requires synchronization.
- Document App Group and Apple Screen Time API usage in project privacy documentation.

## Implementation notes
- Audit by search, not by memory: grep the whole codebase for logging calls and for any networking symbol, and check each hit. Include the extension target — it is easy to forget.
- Verify that no third-party SDK was added that phones home.
- `PRIVACY.md` should state, per framework, what is accessed and why — this text is reused in the entitlement justification (§18, Task 019).
- The audit result is a QA criterion, so record the evidence (what was searched, what was found), not just the conclusion.

## Architecture rules in force
- Appendix B rule 8 — no backend or analytics without an explicit product decision.

## Definition of Done
- [ ] **QA-15** — no child usage data is unintentionally sent to a backend.
- [ ] A documented sweep of all logging and networking call sites exists, including the extension.
- [ ] No FamilyActivity token or selection content appears in any log.
- [ ] `PRIVACY.md` exists at the repository root and covers App Group and all three Screen Time frameworks.
- [ ] App Store privacy questionnaire answers are drafted and ready for Task 019.

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
