---
task: "004"
title: Family Controls Authorization
status: not_started        # not_started | in_progress | blocked | done
depends_on: ["002", "003"]
qa_criteria: ["QA-02"]
prd_refs: ["§6.3", "§8", "§18"]
---

# Task 004 — Family Controls Authorization

## Objective
Implement the real `AuthorizationCenter` flow behind `ScreenTimeAuthorizationService`, including every authorization state. Do not invent APIs.

## In scope
- Concrete `ScreenTimeAuthorizationService` in `ScreenTimeNext/ScreenTime/Authorization/`.
- Mapping Apple's authorization status into the app's own domain enum.
- Graceful handling of: not determined, approved, denied, and revoked-while-running.
- UI states in the §6.3 screen for each of the above, with a recovery path (open Settings / retry).

## Out of scope
- Selection (→ Task 005) and monitoring (→ Task 010).
- Revocation *during an active session* (→ Task 017 covers the runtime edge case; this task covers the state model).

## PRD detail
§6.3 requires explaining why authorization is needed — monitor selected content, warn before time ends, enforce the end — and then triggering the current SDK-supported `AuthorizationCenter` request.

§18: Family Controls is entitlement-gated. On a development account without the entitlement, this request will not succeed. That is a **BLOCKED** verdict with a documented manual step, not a reason to fake the flow.

## Implementation notes
- Verify the exact `AuthorizationCenter` request API against the **installed SDK** before writing it. Signatures in older tutorials are not reliable.
- Authorization is requested for a child on the device; the semantics differ from a parent-managed remote flow. Confirm against current Apple documentation which one V1 targets, and record the answer in `docs/DECISIONS.md`.
- A denial must never leave the app in a dead end. §7 rule 6 — the child experience must not expose authorization details, so denial UI belongs on the parent side only.
- Do not log authorization tokens or identifiers (§16).

## Architecture rules in force
- Rule 1 / 2 — the `AuthorizationCenter` call lives only in `ScreenTime/Authorization/`.
- Rule 8 — current installed SDK only; never invent or copy deprecated API names.

## Definition of Done
- [ ] **QA-02** — authorization failure is handled gracefully, with a clear parent-facing recovery path.
- [ ] All four states (not determined / approved / denied / revoked) are represented and rendered.
- [ ] The real service satisfies the same protocol as the Task 002 mock, with no signature change.
- [ ] No authorization identifiers appear in logs.
- [ ] If the entitlement is unavailable, the task is reported **BLOCKED** with the required manual step written into `docs/BLOCKERS.md`.

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
