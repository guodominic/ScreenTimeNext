# Decision Log

Architecture and product decisions that are **not** derivable from the code, plus the reasoning
behind them. Append only — supersede an entry rather than editing it, so the history survives.

Log a decision when you: deviate from an obvious default, resolve an ambiguity in the PRD, choose
between two workable approaches, or discover a platform constraint that shapes the design.

**Format:** `D-NNN` · title · date · status (`proposed` / `accepted` / `superseded by D-NNN`)

---

## D-001 — `FamilyActivityPicker` is the one allowed exception to Rule 1
**Date:** 2026-09-04 · **Status:** proposed — confirm during Task 005

**Context.** Rule 1 says SwiftUI views must not directly call Screen Time frameworks. But
`FamilyActivityPicker` *is* an Apple SwiftUI view and binds directly to a `FamilyActivitySelection`.
Honoring Rule 1 literally would mean not using Apple's picker, which §6.4 requires and Rule 7 makes
the source of truth.

**Decision.** Confine the framework import to a single thin wrapper view under
`ScreenTimeNext/ScreenTime/Selection/`. That wrapper is the only view in the codebase permitted to
import FamilyControls. Everything in `Features/` receives an opaque, serializable selection snapshot
plus display-safe summary counts.

**Consequences.** The import-boundary check (Task 002) must allow this one path explicitly rather
than being weakened globally. If a second such exception is ever proposed, it needs its own entry
here — the value of the rule is that exceptions are visible.

---

## D-002 — Session state and protection state are two separate axes
**Date:** 2026-09-04 · **Status:** accepted

**Context.** §11's state machine names a `shielded` state, but §12's `ScreenTimeState` enum does not
contain one — it has `idle, active, warning10, warning5, warning1, finished, extended`. Shielding
appears instead in `ProtectionState` (`unshielded / shielded / temporarilyExtended`).

**Decision.** Treat this as deliberate rather than as an inconsistency to reconcile. `ScreenTimeState`
answers "where is the child in the session?"; `ProtectionState` answers "is content currently
enforced?". They change at different times, from different processes: the extension can write
`ProtectionState` while the app is not running (§14).

**Consequences.** Never collapse them into one enum. The parent dashboard (§6.9) renders
`ProtectionState`; the child timer (§6.10) renders `ScreenTimeState`. Both are persisted, and the app
re-reads `ProtectionState` on foreground rather than trusting memory.

---

## D-003 — The .docx PRD is archived; `docs/prd/` is the working copy
**Date:** 2026-09-04 · **Status:** accepted

**Context.** The signed PRD is a Word document, which a coding agent cannot read without conversion,
and which cannot be diffed or reviewed in a pull request.

**Decision.** `docs/prd/` holds the split markdown and is what everyone reads. The original stays at
`docs/reference/` as the signed record.

**Consequences.** If the .docx is revised, re-split it and note the revision here. The markdown must
never drift silently from the archived original.

---

## D-004 — Warning toggles control presentation, not the state machine
**Date:** 2026-09-04 · **Status:** proposed — confirm during Task 008

**Context.** PRD §6.6 lets a parent disable any of the 10/5/1-minute warnings. That leaves an
ambiguity the PRD does not settle: when `warning5` is disabled, does the session *skip* that state,
or *enter it without showing anything*? Skipping makes the state machine depend on configuration,
which makes it much harder to test exhaustively and creates config-dependent transition paths.

**Decision.** The state machine is configuration-independent. `WarningStateEngine.stage(remainingSeconds:)`
computes the stage from remaining time alone; `shouldPresent(_:configuration:)` is a separate query
that gates presentation. A disabled warning is **entered but not shown**.

**Consequences.** Transition coverage is a function of time only, so Task 008's tests do not need to
cross every transition with every toggle combination — they test transitions once and presentation
separately. Task 007 and Task 016 must both consult `shouldPresent` before rendering or scheduling a
notification; entering `warning5` is not by itself permission to show or notify.

---

## D-005 — Product renamed from "Transition" to "ScreenTimeNext"
**Date:** 2026-09-04 · **Status:** accepted

**Context.** The PRD was signed under the working name "Transition". The product name was changed
to **ScreenTimeNext** after the repository was restructured.

**Decision.** Rename the *product* everywhere — targets, source tree (`ScreenTimeNext/`), test target,
App Group identifier and storage keys (`group.PLACEHOLDER.screentimenext`, `screentimenext.*`), and
every sentence where "Transition" was the subject. Keep every use of "transition" as a *concept*:
the `TransitionActivity` type, the "Transition, not punishment" principle, the "Screen Time
Transition Assistant" category, the §11 transition table, and the "transition experience" half of
the Definition of Done. The archived `.docx` in `docs/reference/` still says "Transition" and is
not edited — it is the signed record.

**Consequences.** The App Store listing name is a separate decision (see
`docs/market-analysis.md` on the "Screen Time" naming risk). If the App Group identifier has
already been registered under the old name, B-002 covers re-registering it.

---

## D-006 — Session-window vs. usage-accrual budget model
**Date:** 2026-09-04 · **Status:** accepted 2026-09-05 — **Option A (session window)** chosen by Dominic

**Context.** The PRD defines the daily budget as a DeviceActivity *usage threshold* (§14), but
requires the child's countdown to be derived from *absolute timestamps* (§6.10, Rule 4). These are
two different clocks. The host app cannot read accrued usage — it only learns about it when a
threshold callback fires in the extension, and those callbacks are documented by third-party
developers as throttled, delayed or dropped without error (see `docs/market-analysis.md` §三.2).
So the "7 minutes left" the child sees and the moment the system actually shields can diverge.

**Options.**
- **A — Session window.** The child taps Start; the budget is a wall-clock window from that
  instant (`SessionWindow`). Countdown and 10/5/1 notifications are exact and local. DeviceActivity
  is the enforcement backstop only. Cost: "budget" becomes "one session"; putting the iPad down
  mid-session still burns time.
- **B — Multi-threshold events.** Register DeviceActivity events at budget−600, budget−300,
  budget−60 and budget; the extension writes a timestamp to the App Group and posts a local
  notification on each. Faithful to the PRD, but stakes all three warnings on unreliable callbacks.

**Decision.** Option A for V1: it makes the core experience controllable and confines the
unreliable part to final enforcement. `SessionWindow` (absolute start/end timestamps) is the source
of truth for the countdown; `DailyUsage.usedSeconds` is derived from completed session windows, not
from DeviceActivity. Revisit once real-device data on callback latency exists (Phase 1).

**Consequences.** Task 006's `DailyUsage` semantics, Task 007's countdown source, Task 010's event
design and Task 016's notification scheduling all depend on this. Record the choice here before
starting any of them.

---

## D-007 — Phase 0 on a free Apple account; the $99 membership is a gated decision
**Date:** 2026-09-05 · **Status:** accepted

**Context.** Dominic does not want to pay the $99/yr Apple Developer Program fee before the idea
is validated. A free Personal Team can run apps on up to 3 of his own devices (10 App IDs, 7-day
expiry, reinstall from Xcode weekly) — but Apple's membership comparison and a DTS engineer on the
forums both confirm that **Family Controls and App Groups are not available to free accounts**,
with "no supported way" around it. So Tasks 004–013 cannot run on a device without paying.

**Decision.** Split V1 into two phases with an explicit gate between them.

- **Phase 0 — free.** Tasks 001, 002, 003, 006 (local storage only), 007, 008, 009, 014, 015,
  all against mock services, running on Dominic's own device. Then a small human validation:
  a few families use the prototype for a week while the parent enforces manually. The question
  is PRD §21's second one — does a child who chooses the next activity transition more calmly?
- **Gate.** Pay the $99 and submit the entitlement request (`docs/entitlement-request.md`) only
  if Phase 0's answer is yes. If it is no, stop, with almost nothing spent.
- **Phase 1 — paid.** Tasks 004, 005, 010–013, 016–020: real authorization, picker, monitoring,
  shielding, extension, then distribution.

**Consequences.**
- `ScreenTimeStorageService` needs a *local-container* implementation for Phase 0, since App
  Groups are unavailable; the App Group implementation is added in Phase 1 behind the same
  protocol. This is exactly what Rule 2 is for.
- Task 001 on a free account: no Family Controls capability, no App Group capability, and the
  extension target can be created but not signed for a device. Mark those parts BLOCKED-by-gate,
  not failed.
- PRD §22 still stands: Phase 0's output is a prototype, not V1. Nobody should mistake a working
  Phase 0 for a shippable product.
- Free provisioning expires every 7 days, so validation families need the app reinstalled weekly
  — or the validation runs on Dominic's own devices only.

---

## D-008 — Project layout: local package for the core, extension folder beside the app, iOS 18+
**Date:** 2026-09-05 · **Status:** accepted (Task 001)

**Context.** Xcode 26.3 generated the project with synchronized folders (everything on disk under
the target folder is compiled — recursively), a multiplatform target (iOS/macOS/visionOS), a
placeholder bundle id, iOS 27 as deployment target, and no test target. Appendix A nests the
extension folder and the shared code inside the app folder, which synchronized folders make
impossible without per-file exceptions.

**Decision.**
- Framework-free code (`Core/`, `Shared/`) becomes a local Swift package, `Packages/ScreenTimeNextCore`,
  linked by the app target (and by the extension in Phase 1). Its tests are the package's tests.
- `DeviceActivityMonitorExtension/` sits beside `ScreenTimeNext/`, not inside it.
- Target is iOS/iPadOS only (`SUPPORTED_PLATFORMS = iphoneos iphonesimulator`, device family 1,2).
- Deployment target **iOS 18.0** — broad enough for a child's hand-me-down iPad, new enough for
  every API V1 needs. Raise only when a specific API requires it, and record why here.
- Bundle id `io.github.guodominic.screentimenext`; App Group `group.io.github.guodominic.screentimenext`.
- No `.gitkeep` or README inside the app's synchronized folder — they would ship as bundle resources.

**Consequences.** `docs/source-layout.md` is the layout of record; Appendix A stays as the PRD's
original suggestion. Task file paths updated. `@testable import ScreenTimeNextCore` in tests.
The package must stay Foundation-only; the import-boundary check (Task 002) covers it.

---

## D-009 — What's Next: choice lives on the session; an empty parent set means "all"
**Date:** 2026-09-05 · **Status:** accepted (Task 009)

**Context.** PRD §6.11 has the child choose a next activity at the 10-minute warning, §6.12 shows it
at five minutes, §6.14 names it at Time's Up. Two things the PRD leaves open: where the choice is
stored, and what the child sees if the parent approved no activities in §6.7.

**Decision.**
- The choice is a field on `SessionWindow`. It therefore persists across background/relaunch
  (QA-08 groundwork), survives to Time's Up, and is cleared automatically when the window is
  finalized — no separate lifecycle to manage.
- An empty parent selection is treated as "no preference": the child is offered the whole fixed
  set of eight. Onboarding hints but does not force a pick. Showing an empty chooser at the moment
  the product is supposed to help would be the worst outcome.
- The chooser is shown only in `warning10` (PRD §7.4 — minimal interaction in the last five minutes);
  later states display the choice, they do not offer to change it.

**Consequences.** `SessionController.choose(_:)` and `availableActivities()`. Task 015 renders
`activity.invitation`. If a future version wants the child to pick earlier (during `active`), that
is a UI change only.

---

## D-010 — Parent extension: +10/+20 in Phase 0 as window extensions; Allow Once deferred
**Date:** 2026-09-05 · **Status:** accepted (Task 013, session half)

**Context.** PRD §6.16 offers +10, +20 and Allow Once. Under the session-window model (D-006), +N
is simply "move the window's end forward" — pure logic, no entitlement, and exactly what a family in
Phase 0 validation will ask for. Allow Once, by contrast, only means something with a real shield
("let this shielded app open once"); it cannot be defined honestly without ManagedSettings.

**Decision.**
- Phase 0 implements **+10 / +20 minutes** via `SessionController.extend(bySeconds:)`. Stacking is
  allowed (each grant adds). The session state passes through `.extended` and resumes at the natural
  stage; notifications are re-derived from the new end. Extending a *finished* session reopens it —
  the child is told they've got extra time.
- Extensions count against nothing: they are explicitly parent-granted time beyond the budget.
  `remainingBudgetSeconds()` clamps at zero, so the dashboard shows "Remaining today: 0:00" while
  the child timer shows the extra minutes.
- **Allow Once is deferred to Phase 1** (Task 013's shield half). Proposed definition to confirm
  then: a single re-open of one shielded app, ending when that app is closed or after 5 minutes,
  whichever is first; once per day.
- Reapplying protection on expiry is Phase 1 (rides on DeviceActivity, Rule 3).

**Consequences.** The dashboard's "Extend time" row becomes a menu (+10 / +20) behind a
confirmation; the mock shield's state is set to `temporarilyExtended` for the duration so the
Phase 1 swap is a service change only.

<!-- Template for new entries:

## D-NNN — <short imperative title>
**Date:** YYYY-MM-DD · **Status:** proposed | accepted | superseded by D-NNN

**Context.** What forced a choice.

**Decision.** What was chosen.

**Consequences.** What this now constrains, and what would have to change to reverse it.

-->
