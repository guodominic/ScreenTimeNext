# Blockers

Things that **cannot be solved by writing code**: Apple entitlements, account/team setup, approvals,
physical-device testing, and platform capabilities that do not exist.

Per `CLAUDE.md` and Appendix B rule 5: when an Apple API is unavailable or entitlement-gated, mark
the task **BLOCKED**, write the required manual step here, and move on. Do **not** invent a
workaround or silently change the architecture around it.

**Status values:** `open` · `in progress` · `resolved` · `accepted limitation`

---

## B-001 — Family Controls entitlement
**Status:** in progress · **Owner:** Dominic · **Raised:** 2026-09-04 · **Blocks:** 004, 005, 010, 011, 012, 019 (distribution/TestFlight only — development entitlement is immediate)

Family Controls distribution requires an Apple entitlement and approval process (§18). Without it,
TestFlight and App Store builds cannot ship. **Development entitlement is immediate** and unblocks
real-device work on Tasks 004–013.

**This is calendar time, not engineering time, and it is the largest schedule risk in V1.**

**Current state (2026-09-04).** No paid Apple Developer Program membership yet. No company is
required — an individual account's Account Holder can request it. Full material package,
paste-ready form answers and the ordered checklist are in `docs/entitlement-request.md`.

**Required manual steps, in order.**
1. Enroll in the Apple Developer Program as an individual ($99/yr, Apple Developer app, ID verification).
2. Push the repository to GitHub (used as the "developer website").
3. Register two App IDs + one App Group ID (`docs/entitlement-request.md` §三).
4. Create the App Store Connect record; point its privacy policy URL at `PRIVACY.md`.
5. Submit the distribution request **twice** — main app and DeviceActivityMonitor extension.
6. Record submission date and case ID below; check Capability Requests weekly.

**Meanwhile.** Tasks 001–003, 006–009, 014, 015 need no entitlement; Tasks 004–013 can proceed on
a physical device with the development entitlement. Remember §22: the experience half alone is a
prototype.

**Enrollment date:** —
**Request submitted (main app):** —
**Request submitted (extension):** —
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
