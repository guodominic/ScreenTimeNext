---
task: "013"
title: Parent Extension (+10 / +20 / Allow Once)
status: in_progress        # not_started | in_progress | blocked | done  (session half done in Phase 0; shield half at Phase 1 gate)
depends_on: ["012"]
qa_criteria: ["QA-11"]
prd_refs: ["§6.16", "§15"]
---

# Task 013 — Parent Extension (+10 / +20 / Allow Once)

## Objective
Implement the parent-controlled temporary extension: +10 minutes, +20 minutes, and Allow Once, with safe monitoring and shield updates.

## In scope
- The §6.16 parent UI with the three options.
- The §15 flow: update allowance → adjust monitoring → remove only ScreenTimeNext-managed shielding → resume active → reapply on expiry.
- The `finished | shielded → extended → active` transitions from §11.
- Reliable reapplication of protection when the extension window expires.

## Out of scope
- Remote/cross-device granting — explicitly a V1 non-goal (§4).

## PRD detail
§6.16: offer **+10 minutes**, **+20 minutes**, and **Allow Once**. Extension must only modify
ScreenTimeNext-managed protection and monitoring state.

§15 flow:
```text
+10 / +20 / Allow Once
  → update local allowance / configuration
    → adjust monitoring as supported by the current SDK
      → remove ONLY ScreenTimeNext-managed shielding
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
- Rule 6 — remove only ScreenTimeNext-managed shielding.
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

**2026-09-05 — Claude, session half only (D-010). Verified in the batched run with 016.**

- **Files changed:** package `SessionController.extend(bySeconds:)` (stacking, `.extended` → natural
  stage, notifications re-derived); app dashboard "Extend time" menu (+10 / +20) behind a
  confirmation, mock shield released and `ProtectionState.temporarilyExtended` recorded; child timer
  copy for `.extended`. Tests: `ParentExtensionTests` (7). Decision D-010.
- **Verdict:** **PASS** for the session half · **BLOCKED (by gate)** for: removing the real
  ScreenTimeNext-managed shield, adjusting monitoring, reapplying protection on expiry, Allow Once.
- **Design notes:** extensions are beyond the budget; "Remaining today" stays 0 while the child
  timer shows the extra minutes. Extending a finished session reopens it. Not reachable from the
  child UI (§7.5).
- **Follow-up work (Phase 1):** wire `services.shield` / `services.monitoring` for real; define and
  build Allow Once; reapply on expiry via a DeviceActivity schedule (Rule 3), not an in-app timer.

### DoD status
- [x] **QA-11** — the parent extension works after expiration (session half; shield half at gate).
- [ ] All three options behave as documented, and Allow Once has a written definition — **+10/+20 done; Allow Once deferred with a proposed definition (D-010)**.
- [ ] Protection is reapplied on expiry with the app closed — **Phase 1**.
- [x] Stacked extensions have defined, tested behavior.
- [x] No unrelated ManagedSettings are touched (mock; Task 011 enforces for real).
- [x] The control is not reachable from the child UI.
