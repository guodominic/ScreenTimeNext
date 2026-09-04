---
task: "011"
title: Managed Settings Shield
status: not_started        # not_started | in_progress | blocked | done
depends_on: ["005"]
qa_criteria: ["QA-10"]
prd_refs: ["§14", "§15", "§6.15"]
---

# Task 011 — Managed Settings Shield

## Objective
Implement scoped, idempotent shielding and unshielding of the selected content through `ScreenTimeShieldService`.

## In scope
- Concrete `ScreenTimeShieldService` in `ScreenTimeNext/ScreenTime/Shielding/`.
- Apply and remove shields for the persisted `FamilyActivitySelection` (apps, categories, web domains).
- A named/dedicated ManagedSettings store owned by ScreenTimeNext.
- Idempotency: applying or removing twice equals once.

## Out of scope
- Deciding *when* to shield (→ Task 012).
- The extension override flow (→ Task 013).

## PRD detail
§14: when the threshold is reached, the extension invokes the ManagedSettings shielding mechanism for the selected content.

§15 and §10 rule 5: **remove only ScreenTimeNext-managed shielding.** Never indiscriminately clear all settings.

§6.15: when a selected app is opened after time is exhausted, present the system shielding experience where applicable. The app's own experience should frame this as transition, not punishment.

## Implementation notes
- Use a **named** `ManagedSettingsStore` dedicated to ScreenTimeNext. Clearing that store must never touch settings written by Apple's own Screen Time or by another parental-control app on the same device.
- Verify the current `ManagedSettingsStore` / `ShieldSettings` API surface against the installed SDK.
- The service must be callable from **both** the app and the extension. Keep it free of any assumption that a UI exists.
- Shield configuration copy, where the platform allows customization, is child-facing — apply §7.
- Write the resulting `ProtectionState` to the App Group so the app can render it (Task 014) without re-querying.

## Architecture rules in force
- Rule 6 — never indiscriminately clear ManagedSettings.
- Rule 7 — shield exactly what the `FamilyActivitySelection` names.
- Rule 8 — installed SDK only.

## Definition of Done
- [ ] **QA-10** — selected content is shielded without clearing unrelated settings.
- [ ] Shield and unshield are idempotent and unit-tested at the service boundary.
- [ ] The store is named and owned by ScreenTimeNext; no global clear exists anywhere in the codebase.
- [ ] The service runs correctly when called from the extension with no app process.
- [ ] `ProtectionState` is written to shared storage after every change.

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
