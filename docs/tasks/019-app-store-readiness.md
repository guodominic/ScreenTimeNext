---
task: "019"
title: App Store Readiness
status: not_started        # not_started | in_progress | blocked | done
depends_on: ["018"]
qa_criteria: []
prd_refs: ["§18", "§17"]
---

# Task 019 — App Store Readiness

## Objective
Produce the entitlement, privacy, review, and submission checklist, and confirm the Family Controls entitlement status.

## In scope
- Family Controls entitlement request status and the written justification of legitimate parental-control purpose.
- Documentation of how FamilyControls, DeviceActivity, and ManagedSettings are each used.
- App Store privacy questionnaire answers (from Task 018).
- A submission checklist: capabilities, entitlements, privacy strings, review notes, demo instructions for a reviewer without a child device.
- A copy review confirming no claim exceeds what the platform actually enforces (§17).

## Out of scope
- Subscription/pricing infrastructure — a V1 non-goal (§4), even though §21 asks the $30/year question.

## PRD detail
§18: Family Controls distribution requires the appropriate Apple entitlement and approval process. **Request the entitlement as early as possible.** Maintain documentation explaining the legitimate parental-control purpose and how each framework is used. Verify exact entitlement names, SDK APIs, and review requirements against **current Apple developer documentation** before submission.

## Implementation notes
- The entitlement is **calendar time, not engineering time** — it is the largest schedule risk in V1 and should already have been raised in Task 001. If it has not been requested yet, that is the single most urgent action in the project.
- Verify entitlement names and review requirements against current Apple documentation at the time of submission. Do not trust this file or the PRD for those specifics.
- Reviewers cannot easily reproduce a real child screen-time scenario. Write explicit demo instructions and, if useful, a reviewer-facing test path.
- Cross-check every user-facing and store-facing claim against Task 017's findings — §17 forbids claiming bypass-proof enforcement the platform does not deliver.

## Architecture rules in force
- Rule 8 — verify against current Apple documentation and the installed SDK.

## Definition of Done
- [ ] Entitlement status is recorded in `docs/BLOCKERS.md` with a date and an owner.
- [ ] Written justification and per-framework usage documentation exist.
- [ ] Privacy questionnaire answers are complete.
- [ ] A submission checklist exists, including reviewer demo instructions.
- [ ] No user-facing or store-facing claim exceeds verified platform capability.

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
