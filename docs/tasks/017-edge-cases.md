---
task: "017"
title: Edge Cases
status: not_started        # not_started | in_progress | blocked | done
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
