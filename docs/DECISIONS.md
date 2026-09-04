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
`Transition/ScreenTime/Selection/`. That wrapper is the only view in the codebase permitted to
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

<!-- Template for new entries:

## D-NNN — <short imperative title>
**Date:** YYYY-MM-DD · **Status:** proposed | accepted | superseded by D-NNN

**Context.** What forced a choice.

**Decision.** What was chosen.

**Consequences.** What this now constrains, and what would have to change to reverse it.

-->
