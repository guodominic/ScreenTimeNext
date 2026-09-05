---
task: "017"
title: Edge Cases
status: in_progress        # not_started | in_progress | blocked | done  (Phase 0 scope done; shield/bypass scenarios at Phase 1 gate)
depends_on: ["012", "013", "016"]
qa_criteria: ["QA-12", "QA-13", "QA-14"]
prd_refs: ["§17"]
---

# Task 017 — Edge Cases

## Objective
Test and harden the failure modes listed in §17: termination, restart, authorization changes, midnight rollover, timezone and date/time changes, and configuration changes.

## In scope
- App termination mid-session, and relaunch.
- Device restart with an active session and with an active shield.
- Authorization revoked while a session is running.
- Midnight / day rollover, including a session that spans it.
- Timezone change and manual date/time change (forward and backward).
- Configuration changed mid-session (budget, warnings, selection).
- Child reopening protected content after expiry.

## Out of scope
- Claiming to defeat every device-level bypass — explicitly out of bounds (§17).

## PRD detail
§17 requires V1 to be tested against app termination, device restart, authorization revocation,
configuration changes, date/time changes, and the child attempting to reopen protected content.

> **Honesty constraint:** the product must not claim to block every possible device-level bypass
> unless Apple's platform actually provides that capability. Whatever this task finds, the finding
> goes into `docs/BLOCKERS.md` and constrains the marketing and in-app copy — it does not get
> engineered around with an unsupported hack.

## Implementation notes
- **Backward clock change** is the sharpest case: a child setting the clock back must not manufacture screen time. Test it explicitly and record the mitigation and its limits.
- **Day rollover** must reset `DailyUsage` and return the state machine to `idle` (§11) — and must do so correctly for a session that is running at midnight. Check this against the schedule decision made in Task 010.
- **Authorization revoked mid-session:** decide what happens to an active shield. Document it; §7 rule 6 says the child must not be shown authorization details either way.
- **Restart with an active shield:** confirm the shield persists, or that it is re-established, and that configuration survives (QA-12).
- Write regression tests for everything reproducible without a device; mark the rest **NEEDS MANUAL DEVICE TEST** with a written manual procedure.

## Architecture rules in force
- Rule 4 — timestamp-derived time is what makes most of these cases tractable.
- Rule 10 — build and test after every change here; this task is where silent regressions hide.

## Definition of Done
- [ ] **QA-12** — device restart does not silently destroy configuration.
- [ ] **QA-13** — midnight / day rollover is handled.
- [ ] **QA-14** — authorization revocation is handled.
- [ ] Backward clock change cannot manufacture screen time, and any residual limit is documented.
- [ ] Every §17 scenario has either an automated test or a written manual test procedure.
- [ ] Bypass limitations discovered are recorded in `docs/BLOCKERS.md` and flagged as copy constraints.

## Completion report

**2026-09-05 — Claude, Phase 0 scope. Verified in the batched run with 018.**

- **Files changed:** `SessionController.currentWindowLocked` — a window is current while it started
  today OR is still running (a 23:50 session is not cut at midnight; a timezone change cannot end a
  running session; only an ended window from another day is finalized, onto the day it started).
  Dashboard shows "Screen Time access" status (revocation surfaces to the parent, never the child).
  Tests: `EdgeCaseTests` (10) on REAL file storage: restart mid-session and in every stage,
  midnight span, yesterday's finished window, timezone flip, forward/backward clock jumps,
  budget/activity changes mid-session, revocation.
- **Verdict:** **PASS** (Phase 0) · **BLOCKED (by gate)**: restart with an active shield, child
  reopening protected content, revocation's effect on enforcement.
- **Decisions:** budget changes apply to the next session; a running window is never discarded by
  a clock or calendar change; backward clock is clamped to the window length (residual limit: a
  child who sets the clock back *before* Start gets a normal session — acceptable, documented).
- **Honesty constraint (§17):** nothing in copy claims bypass-proof enforcement; `docs/BLOCKERS.md`
  B-003 carries the device-test list.
- **Follow-up work:** Phase 1 — shield persistence across restart, reopen-after-expiry, notification
  delivery latency measured on device (Task 016 note).

### DoD status
- [x] **QA-12** — restart does not silently destroy configuration (file storage, every stage).
- [x] **QA-13** — midnight / day rollover handled (span + finalize-on-its-day).
- [x] **QA-14** — authorization revocation handled (timer continues; parent sees it; child does not) — enforcement half at gate.
- [x] Backward clock change cannot manufacture screen time; residual limit documented.
- [x] Every §17 scenario reproducible without a device has an automated test; device-only ones listed in B-003.
- [x] Bypass limitations recorded as copy constraints (B-003, PRIVACY.md "What we cannot promise").
