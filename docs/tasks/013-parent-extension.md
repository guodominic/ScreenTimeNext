---
task: "013"
title: Parent Extension (+10 / +20 / Allow Once)
status: not_started        # not_started | in_progress | blocked | done
depends_on: ["012"]
qa_criteria: ["QA-11"]
prd_refs: ["§6.16", "§15"]
---

# Task 013 — Parent Extension (+10 / +20 / Allow Once)

## Objective
Implement the parent-controlled temporary extension: +10 minutes, +20 minutes, and Allow Once, with safe monitoring and shield updates.

## In scope
- The §6.16 parent UI with the three options.
- The §15 flow: update allowance → adjust monitoring → remove only Transition-managed shielding → resume active → reapply on expiry.
- The `finished | shielded → extended → active` transitions from §11.
- Reliable reapplication of protection when the extension window expires.

## Out of scope
- Remote/cross-device granting — explicitly a V1 non-goal (§4).

## PRD detail
§6.16: offer **+10 minutes**, **+20 minutes**, and **Allow Once**. Extension must only modify
Transition-managed protection and monitoring state.

§15 flow:
```text
+10 / +20 / Allow Once
  → update local allowance / configuration
    → adjust monitoring as supported by the current SDK
      → remove ONLY Transition-managed shielding
        → resume active state
          → reapply protection when the extension expires
```

## Implementation notes
- Define **Allow Once** precisely before implementing it — one app launch, or until the end of the day? It is the least-specified option in the PRD. Decide, document in `docs/DECISIONS.md`, and make the parent-facing copy say exactly what it does.
- Reapplication on expiry is the hard half. The app may not be running when the window ends, so reapplication must ride on a supported mechanism (a monitoring schedule/event), not on an in-app timer. Rule 3 applies.
- Granting an extension must never clear unrelated ManagedSettings (Rule 6) — reuse Task 011's scoped service.
- Stacked extensions (+10 then +10 again) must be defined and tested, not left to emerge.
- This is a **parent** surface. §7 rule 5 — make it deliberate; do not put it one tap from the child timer.

## Architecture rules in force
- Rule 6 — remove only Transition-managed shielding.
- Rule 3 — expiry cannot depend on a per-second process.
- Rule 5 — allowance state is shared with the extension.

## Definition of Done
- [ ] **QA-11** — the parent extension works after expiration.
- [ ] All three options behave as documented, and Allow Once has a written definition.
- [ ] Protection is reapplied on expiry with the app closed.
- [ ] Stacked extensions have defined, tested behavior.
- [ ] No unrelated ManagedSettings are touched.
- [ ] The control is not reachable from the child UI.

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
