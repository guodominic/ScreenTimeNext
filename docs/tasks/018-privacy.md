---
task: "018"
title: Privacy Audit
status: done               # not_started | in_progress | blocked | done  (re-audit at Phase 1)
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

**2026-09-05 — Claude. Verified in the batched run with 017.**

- **Audit method:** `scripts/privacy-audit.sh`, run by `test.sh` on every verification. Greps all
  Swift sources (app, package, extension folder) and the project file for: networking APIs, URL
  literals, logging calls in production code, remote package dependencies, analytics/ads/crash SDK
  names, and any read of `SelectionSnapshot.payload` outside the selection adapter.
- **Findings (2026-09-05):** none. No networking, no logging, no third-party code, no backend.
  Notification content contains the child's first name and the chosen activity only — never app
  names or selection detail. The only child data stored is a first name, in the app container.
- **Files changed:** `scripts/privacy-audit.sh`; `PRIVACY.md` status → audited for Phase 0;
  `scripts/test.sh` runs the audit.
- **Verdict:** **PASS** (Phase 0). Re-run at Phase 1 when the Screen Time adapters exist.
- **App Store privacy questionnaire (draft answers):** Data collected — none. Data linked to user —
  none. Tracking — none. (The child's first name never leaves the device.)

### DoD status
- [x] **QA-15** — no child usage data is unintentionally sent to a backend (audited, and enforced on every test run).
- [x] A documented sweep of all logging and networking call sites exists (the script is the sweep; it covers the extension folder).
- [x] No FamilyActivity token or selection content appears in any log (no logging exists; payload access is fenced).
- [x] `PRIVACY.md` exists at the repository root and covers App Group and all three Screen Time frameworks.
- [x] App Store privacy questionnaire answers are drafted (above).
