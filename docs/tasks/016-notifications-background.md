---
task: "016"
title: Notifications & Background Behavior
status: not_started        # not_started | in_progress | blocked | done
depends_on: ["008", "012"]
qa_criteria: []
prd_refs: ["§14", "§7"]
---

# Task 016 — Notifications & Background Behavior

## Objective
Implement notification and background behavior supported by the current SDK, so warnings still reach the child when the app is not in the foreground.

## In scope
- Local notifications for the 10/5/1-minute warnings and for time expiry.
- Notification permission request, placed in the parent flow, with graceful denial handling.
- Correct scheduling from absolute timestamps, and cancellation when configuration changes or an extension is granted.

## Out of scope
- Push notifications or any server — V1 has no backend (§4, §16).

## PRD detail
§14: warning presentation and exact countdown rendering need to use appropriate local state / timestamp calculations and, **where appropriate, system notification mechanisms**, because the DeviceActivity extension is not a continuous per-second process.

§7: notification copy is child-facing and must follow the same language rules as the in-app warnings (§6.11–§6.14).

## Implementation notes
- Schedule notifications from the same absolute timestamps that drive the countdown (Rule 4). Never schedule from a relative offset computed at an arbitrary moment.
- Cancel and reschedule whenever the budget changes, an extension is granted, or the day rolls over. Stale notifications firing after an extension was granted would badly undermine parent trust (§21).
- A denied notification permission must degrade cleanly — the in-app experience still works; log it as a documented limitation rather than blocking the flow.
- Verify the current notification APIs against the installed SDK.
- Do not include app names or selection details in notification text (§16).

## Architecture rules in force
- Rule 3 — notifications compensate for the fact that the extension is not a timer.
- Rule 4 — schedule from absolute timestamps.

## Definition of Done
- [ ] Warnings and expiry reach the child with the app backgrounded.
- [ ] Notifications are cancelled/rescheduled on budget change, extension grant, and day rollover.
- [ ] No stale notification can fire after an extension is granted.
- [ ] Denied permission degrades gracefully and is documented.
- [ ] Notification copy passes the §7 checklist and leaks no selection detail.

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
