# 09 — QA Acceptance Criteria & Definition of Done

PRD sections: §19 QA Acceptance Criteria, §22 V1 Definition of Done.

## §19 QA acceptance criteria

Each criterion is owned by a task. A task is not done until its owned criteria pass.

| # | Criterion | Owning task |
|---|---|---|
| QA-01 | Parent can complete onboarding | 003 |
| QA-02 | Family Controls authorization failure is handled gracefully | 004 |
| QA-03 | Parent can select protected content | 005 |
| QA-04 | Selection survives relaunch | 005 |
| QA-05 | Daily budget survives relaunch | 006 |
| QA-06 | Countdown survives background/foreground transitions | 007 |
| QA-07 | 10/5/1 minute warning states render correctly | 008 (logic) / 007 (render) |
| QA-08 | Child can select a next activity | 009 |
| QA-09 | Time expiration triggers the enforcement path | 012 |
| QA-10 | Selected content is shielded without clearing unrelated settings | 011 |
| QA-11 | Parent extension works after expiration | 013 |
| QA-12 | Device restart does not silently destroy configuration | 017 |
| QA-13 | Midnight / day rollover is handled | 017 |
| QA-14 | Authorization revocation is handled | 017 |
| QA-15 | No child usage data is unintentionally sent to a backend | 018 |

Final audit of all 15 happens in Task 020.

## §22 V1 Definition of Done

> V1 is complete only when the app provides a coherent transition experience **AND** reliably uses
> Apple's Screen Time APIs to enforce the configured limit under supported platform conditions.
> A polished timer without actual enforcement is a prototype, not the V1 product.

### The two halves
| Half | Complete when |
|---|---|
| **Transition experience** | Onboarding, child timer, 10/5/1 warnings, next-activity selection, and the Time's Up screen all work coherently with child-appropriate copy (§7). |
| **Real enforcement** | DeviceActivity threshold fires → extension shields selected content → parent extension can safely lift and reapply it, all with the app closed. |

Neither half alone is V1.

## Test result vocabulary
Every task's completion report and the final QA audit use exactly these four verdicts:

- **PASS** — implemented and verified.
- **FAIL** — implemented but does not meet criteria.
- **BLOCKED** — cannot proceed; an entitlement, approval, or platform capability is missing.
  State the required manual step.
- **NEEDS MANUAL DEVICE TEST** — implemented, but correctness can only be confirmed on a physical
  device with a real child account / real Screen Time authorization.
