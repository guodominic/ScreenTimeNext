---
task: "012"
title: Enforcement Integration
status: not_started        # not_started | in_progress | blocked | done
depends_on: ["010", "011"]
qa_criteria: ["QA-09"]
prd_refs: ["§14", "§22"]
---

# Task 012 — Enforcement Integration

## Objective
Connect the DeviceActivity threshold callback to shielding and to shared protection state — the path that turns V1 from a prototype into the product.

## In scope
- Wire the extension's threshold callback to `ScreenTimeShieldService`.
- Read the persisted selection and configuration from the App Group inside the extension.
- Write `ProtectionState = .shielded` and the session outcome back to shared storage.
- Reconcile state when the app next comes to the foreground.

## Out of scope
- Parent override (→ Task 013).
- Notifications (→ Task 016).

## PRD detail
§14's enforcement chain, end to end:

```text
threshold reached (system)
  → DeviceActivityMonitorExtension callback
    → read selection + config from App Group
      → ScreenTimeShieldService applies shield
        → write ProtectionState = .shielded to App Group
          → main app reconciles on next foreground
```

§22: V1 is complete only when the app **reliably uses Apple's Screen Time APIs to enforce the
configured limit**. This task is where that claim is either earned or not.

## Implementation notes
- The whole chain must work **with the app closed**. Test it that way, not with the app in the foreground.
- The extension has a tight execution budget. Do the minimum: read, shield, write, return. No networking, no heavy decoding, no waiting.
- If reading shared state fails inside the extension, fail **safe** — decide explicitly whether that means shielding or not shielding, document the choice in `docs/DECISIONS.md`, and make it deliberate rather than accidental.
- The app must never assume its in-memory `ProtectionState` is current; re-read from the App Group on foreground (§14).
- Do not log tokens or selection contents from the extension (§16).

## Architecture rules in force
- Rule 3 — the callback is an event, not a tick.
- Rule 5 — App Group is the only channel between extension and app.
- Rule 6 — scoped shielding only.

## Definition of Done
- [ ] **QA-09** — time expiration triggers the enforcement path.
- [ ] The full chain works with the main app force-quit.
- [ ] The extension does the minimum work and returns promptly.
- [ ] The failure-to-read-state behavior is deliberate and documented.
- [ ] The app reflects the extension-written state on next foreground.
- [ ] Verdict states clearly whether this was verified on a physical device.

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
