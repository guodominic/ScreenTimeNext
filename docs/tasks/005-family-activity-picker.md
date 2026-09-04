---
task: "005"
title: Family Activity Picker
status: not_started        # not_started | in_progress | blocked | done
depends_on: ["004"]
qa_criteria: ["QA-03", "QA-04"]
prd_refs: ["§6.4", "§13"]
---

# Task 005 — Family Activity Picker

## Objective
Present Apple's `FamilyActivityPicker` and persist the resulting `FamilyActivitySelection` as the source of truth for protected content.

## In scope
- A thin wrapper view in `Transition/ScreenTime/Selection/` that hosts `FamilyActivityPicker`.
- Concrete `ScreenTimeSelectionService` that serializes and restores the selection.
- Replacing the Task 003 mocked selection step with the real one.
- A display-safe summary (counts of apps / categories / web domains) for the parent dashboard.

## Out of scope
- Applying the selection to monitoring (→ Task 010) or shielding (→ Task 011).

## PRD detail
§6.4: the parent selects applications, categories, and supported web domains. Persist the Apple `FamilyActivitySelection`. **Do not build a manual app database.**

§13: the `FamilyActivitySelection` remains the source of truth. Do not replace privacy-preserving Apple tokens with invented app-name identifiers.

## Implementation notes
- `FamilyActivityPicker` is an Apple SwiftUI view and must bind to a `FamilyActivitySelection`. This is the **one documented exception** to Rule 1 — see `docs/DECISIONS.md` D-001. Keep the exception in a single wrapper view; the rest of the feature layer sees only the opaque snapshot.
- Verify the current serialization approach for `FamilyActivitySelection` against the installed SDK. Do not assume a specific encoding is stable across OS versions — handle a decode failure by treating the selection as empty and prompting the parent to reselect, never by crashing.
- The selection must be written to the App Group container, because the extension needs it (Task 012).
- Never log the selection contents or its tokens (§16).

## Architecture rules in force
- Rule 7 — `FamilyActivitySelection` is the source of truth for selected content.
- Rule 5 — the selection lives in the App Group container.
- Rule 8 — verify the picker and selection APIs against the installed SDK.

## Definition of Done
- [ ] **QA-03** — a parent can select protected content.
- [ ] **QA-04** — the selection survives a relaunch.
- [ ] The selection is readable from the extension's side of the App Group.
- [ ] No app-name-to-bundle-ID mapping exists anywhere in the codebase.
- [ ] Decode failure degrades gracefully with a reselect prompt.
- [ ] The framework import is confined to the wrapper in `ScreenTime/Selection/`.

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
