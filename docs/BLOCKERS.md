# Blockers

Things that **cannot be solved by writing code**: Apple entitlements, account/team setup, approvals,
physical-device testing, and platform capabilities that do not exist.

Per `CLAUDE.md` and Appendix B rule 5: when an Apple API is unavailable or entitlement-gated, mark
the task **BLOCKED**, write the required manual step here, and move on. Do **not** invent a
workaround or silently change the architecture around it.

**Status values:** `open` · `in progress` · `resolved` · `accepted limitation`

---

## B-001 — Family Controls entitlement
**Status:** open · **Owner:** — · **Raised:** 2026-09-04 · **Blocks:** 004, 005, 010, 011, 012, 019

Family Controls distribution requires an Apple entitlement and approval process (§18). Without it,
authorization, the picker, monitoring, and shielding cannot be exercised on a real build.

**This is calendar time, not engineering time, and it is the largest schedule risk in V1.**

**Required manual step.** Submit the entitlement request to Apple with a written justification of
the legitimate parental-control purpose and a description of how FamilyControls, DeviceActivity, and
ManagedSettings are each used. Verify the exact entitlement name against current Apple developer
documentation before submitting.

**Meanwhile.** Tasks 003, 006, 007, 008, 009, 014, 015 do not need the entitlement. Keep the
experience half moving — while remembering §22: that half alone is a prototype.

**Request date:** —
**Response date:** —

---

## B-002 — Apple Developer Team ID for the App Group identifier
**Status:** open · **Owner:** — · **Raised:** 2026-09-04 · **Blocks:** 001, 006, 012

The App Group identifier shared by the app and the extension requires a real Team ID. Until one is
configured, Task 001 defines the constant with a marked placeholder.

**Required manual step.** Configure the Apple Developer team in Xcode and register the App Group;
replace the placeholder in `ScreenTimeNext/Shared/Constants/`.

---

## B-003 — Physical-device testing for the enforcement path
**Status:** open · **Owner:** — · **Raised:** 2026-09-04 · **Blocks:** 010, 012, 013, 017, 020

The simulator does not accrue real Screen Time usage, so DeviceActivity thresholds and ManagedSettings
shielding cannot be verified there. QA-09, QA-10, and QA-11 require a physical device — and must be
tested **with the app force-quit**, since §14 requires enforcement to work with the app closed.

**Required manual step.** Arrange a test device with an appropriate account configuration. Document
the setup so results are reproducible.

---

<!-- Template for new entries:

## B-NNN — <short title>
**Status:** open | in progress | resolved | accepted limitation
**Owner:** — · **Raised:** YYYY-MM-DD · **Blocks:** <task numbers>

<What is blocked and why code cannot fix it.>

**Required manual step.** <The concrete human action needed.>

-->
