---
task: "003"
title: Parent Onboarding
status: not_started        # not_started | in_progress | blocked | done
depends_on: ["002"]
qa_criteria: ["QA-01"]
prd_refs: ["§6.1–§6.8", "§5", "§7"]
---

# Task 003 — Parent Onboarding

## Objective
Implement the full onboarding flow — Welcome → Child → Permission → App Selection → Budget → Warnings → What's Next → Ready — against **mocked** services.

## In scope
- Eight screens per §6.1–§6.8, with the exact copy and defaults specified there.
- Navigation and state flow, including back navigation and resuming a partially-completed setup.
- An onboarding view model holding draft configuration until the final step commits it.

## Out of scope
- Real authorization (→ Task 004) and real picker (→ Task 005) — both are mocked here.
- Persistence to the App Group (→ Task 006); an in-memory store is acceptable for this task.

## PRD detail
### §6.1 Welcome
Headline **"Make screen time end peacefully."** Explain that ScreenTimeNext helps a child move from screen time to what's next. CTA: **Get Started**.

### §6.2 Child Profile
Single child. First name only. Keep it lightweight — no age, no avatar, no account.

### §6.3 Family Controls Permission
Explain why authorization is required, in three points: monitor selected content, warn before time ends, enforce the end.

### §6.4 App Selection
Mocked picker in this task. Parent selects applications, categories, and supported web domains.

### §6.5 Daily Budget
Default **60 minutes**. Presets: **15 / 30 / 45 / 60 / 90 / 120**.

### §6.6 Warning Settings
Defaults **10 / 5 / 1 minutes, all enabled**, each independently toggleable. No custom intervals in V1.

### §6.7 What's Next
Fixed activity set: LEGO, Drawing, Reading, Outside, Snack, Bath, Homework, Family Time.

### §6.8 Ready
Show the child's name and the configured daily budget. Explain that the app will give gentle warnings before time ends.

## Implementation notes
- Copy is a deliverable here, not a placeholder. Run every string through the §7 copy checklist in `docs/prd/04-ux-principles.md`.
- The permission screen must explain *why* before triggering anything — do not surface a system prompt on screen entry.
- Onboarding is parent-facing, so it may use adult language; everything after it is not.

## Architecture rules in force
- Rule 1 / Rule 2 — screens talk to mocked protocols only.
- Rule 9 — implement onboarding only; do not start wiring real frameworks because the flow 'feels incomplete'.

## Definition of Done
- [ ] **QA-01** — a parent can complete onboarding end to end.
- [ ] All eight screens match §6.1–§6.8 defaults and copy.
- [ ] Back navigation preserves entered data.
- [ ] Flow works with mock services only — no entitlement required to run it.
- [ ] No view imports a Screen Time framework.

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
