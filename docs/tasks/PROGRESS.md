# Progress

Single source of truth for **where the project stands**. Update this file at the end of every task,
in the same commit as the work. If this file and a task's front-matter disagree, fix both.

**Status values:** `not_started` · `in_progress` · `blocked` · `done`
**Verdicts:** `PASS` · `FAIL` · `BLOCKED` · `NEEDS MANUAL DEVICE TEST`

## Task board

| # | Task | Status | Depends on | QA owned | Verdict | Notes |
|---|---|---|---|---|---|---|
| 001 | [Project Foundation](001-project-foundation.md) | done | — | — | PASS (ext. target + capabilities blocked by gate) | build OK, 16/16 tests; `./scripts/test.sh` |
| 002 | [App Architecture](002-app-architecture.md) | done | 001 | — | PASS | 26/26 tests; import check automated |
| 003 | [Parent Onboarding](003-parent-onboarding.md) | done | 002 | QA-01 | PASS | 32/32; QA-01 verified on device |
| 004 | [Family Controls Authorization](004-family-controls-authorization.md) | not_started | 002, 003 | QA-02 | — | entitlement risk |
| 005 | [Family Activity Picker](005-family-activity-picker.md) | not_started | 004 | QA-03, QA-04 | — | |
| 006 | [Screen Time Configuration](006-screen-time-configuration.md) | done | 002 | QA-05 | PASS (App Group at gate) | 40/40; FileStorageService |
| 007 | [Child Timer UI](007-child-timer-ui.md) | done | 006 | QA-06, QA-07 | PASS / device check pending | 51/51; SessionController |
| 008 | [Warning State Engine](008-warning-state-engine.md) | done | 006 | QA-07 | PASS | transition-table tests; batched run |
| 009 | [What's Next](009-whats-next.md) | done | 003, 006 | QA-08 | PASS | choice on SessionWindow; D-009; batched run |
| 010 | [Device Activity Monitor](010-device-activity-monitor.md) | not_started | 005, 006 | — | — | likely device-test only |
| 011 | [Managed Settings Shield](011-managed-settings-shield.md) | not_started | 005 | QA-10 | — | |
| 012 | [Enforcement Integration](012-enforcement-integration.md) | not_started | 010, 011 | QA-09 | — | **the V1 make-or-break task** |
| 013 | [Parent Extension](013-parent-extension.md) | in_progress | 012 | QA-11 | PASS (session half) / BLOCKED by gate (shield half) | +10/+20 in Phase 0; Allow Once deferred (D-010) |
| 014 | [Parent Dashboard](014-parent-dashboard.md) | done | 006, 011 | — | PASS | + SettingsView; Extend row disabled until 013; batched run |
| 015 | [Time's Up Experience](015-times-up-experience.md) | done | 009 | — | PASS | TimesUpView; batched run |
| 016 | [Notifications & Background](016-notifications-background.md) | done | 008, 012 | — | PASS / device check pending | local notifications — needed in Phase 0 |
| 017 | [Edge Cases](017-edge-cases.md) | in_progress | 012, 013, 016 | QA-12, QA-13, QA-14 | PASS (Phase 0) / BLOCKED by gate (shield scenarios) | midnight-span rule; EdgeCaseTests on file storage |
| 018 | [Privacy Audit](018-privacy.md) | done | 017 | QA-15 | PASS (re-audit at Phase 1) | scripts/privacy-audit.sh on every test run |
| 019 | [App Store Readiness](019-app-store-readiness.md) | not_started | 018 | — | — | entitlement gate |
| 020 | [Final QA](020-final-qa.md) | not_started | 019 | QA-01…QA-15 | — | |

## QA acceptance criteria (§19)

| # | Criterion | Owning task | Result |
|---|---|---|---|
| QA-01 | Parent can complete onboarding | 003 | PASS (device, 2026-09-05) |
| QA-02 | Authorization failure handled gracefully | 004 | — |
| QA-03 | Parent can select protected content | 005 | — |
| QA-04 | Selection survives relaunch | 005 | — |
| QA-05 | Daily budget survives relaunch | 006 | PASS (automated); device relaunch check pending |
| QA-06 | Countdown survives background/foreground | 007 | PASS (automated); device check pending |
| QA-07 | 10/5/1 warning states render correctly | 008 / 007 | PASS (automated); device look pending |
| QA-08 | Child can select a next activity | 009 | PASS (automated); device check pending |
| QA-09 | Time expiration triggers enforcement path | 012 | — |
| QA-10 | Content shielded without clearing unrelated settings | 011 | — |
| QA-11 | Parent extension works after expiration | 013 | PASS session half; shield half at gate |
| QA-12 | Device restart does not destroy configuration | 017 | PASS (automated, file storage) |
| QA-13 | Midnight / day rollover handled | 017 | PASS (automated) |
| QA-14 | Authorization revocation handled | 017 | PASS Phase 0 scope; enforcement half at gate |
| QA-15 | No child usage data sent to a backend | 018 | PASS (audited + enforced) |

## Phases (D-007)

| Phase | Account | Tasks | Exit condition |
|---|---|---|---|
| **0 — experience half** | free Personal Team | 001, 002, 003, 006 (local storage), 007, 008, 009, 014, 015 | Prototype runs on Dominic's device; a few families used it for a week; §21 Q2 ("does choosing the next activity help?") has an answer |
| **Gate** | — | pay $99, submit entitlement request ×2 | Only if Phase 0 says yes |
| **1 — enforcement half** | paid | 004, 005, 010, 011, 012, 013, 016, 017, 018, 019, 020 | §22 Definition of Done |

## Batched verification note
Tasks 008, 009, 014, 015 were written and committed separately but verified in ONE
`test.sh` + `build.sh` run on 2026-09-05 (Dominic's call, low-risk Phase 0 work). Rule 9/10 stays the
default; batching is acceptable for mock-backed experience tasks when errors are file-attributable.

## Critical path

```text
001 → 002 → 004 → 005 → 010 ─┐
                             ├→ 012 → 013 → 017 → 018 → 019 → 020
              006 → 011 ─────┘
```

Tasks **003, 007, 008, 009, 014, 015** are experience work that can proceed in parallel and do
**not** require the Family Controls entitlement. If the entitlement is blocked, keep moving there —
but remember §22: that half alone is a prototype, not V1.

## §22 Definition of Done — running judgement

| Half | State |
|---|---|
| Coherent transition experience | **Phase 0 complete** (pending on-device checks): 001–003, 006–009, 013 (session half), 014–018 |
| Real Screen Time enforcement | not started |

Both must be complete. Neither alone is V1.
