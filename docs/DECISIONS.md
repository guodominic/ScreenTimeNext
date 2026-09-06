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

---

## D-011 — Leaving the child timer: a press-and-hold "Parents" control
**Date:** 2026-09-05 · **Status:** accepted

**Context.** Task 007 hid the back button during a session (§7.6: the child should not reach
parent screens). In practice the parent had no way back either, which is the wrong trade.

**Decision.** The timer hides the system back button and shows a "Parents" control in its place.
A tap shows "Hold to go back"; a one-second press-and-hold returns to the dashboard. Everything on
the dashboard that matters (End session, Extend) is additionally behind a confirmation.

**Consequences.** Enough friction for a young child, no friction for a parent. Not a security
boundary — the real boundary is the shield (Phase 1); this is UX only.

---

## D-012 — Making warnings unmissable: what iOS allows, and the Phase 1 shield interstitial
**Date:** 2026-09-05 · **Status:** accepted for Phase 0 items; **proposed** for the Phase 1 design

**Context.** A banner is easy to miss. Dominic asked whether the device can switch to the timer
screen at the 5-minute mark. It cannot: iOS has no API for an app to foreground itself, for anyone.

**Phase 0 (done).** Tapping a warning lands on the child timer, not the dashboard. While a session
exists, opening the app by any route shows the timer full-screen (Parents control to leave).
Notifications carry `.timeSensitive`, which becomes effective once the Time Sensitive Notifications
capability is on the target (ordinary capability; needs the paid membership — B-004).

**Optional (Phase 0-compatible).** A Live Activity via a Widget extension: a ticking countdown in
the Dynamic Island / status area on iPhone and on the Lock Screen on iPad. No entitlement. Worth it
if the validation devices are iPhones; low value on an iPad that is unlocked and in use.

**Cannot lock the screen — confirmed.** Dominic asked (2026-09-05) whether the device could be
locked at each reminder to force the child to stop. An Apple Frameworks engineer answers this
directly on the developer forums: *"Locking and unlocking the device is not possible via the Screen
Time API."* There is no other public API for it either; device lock is MDM-only (supervised devices,
an MDM server — a different product). Do not look for a workaround.

**Phase 1 design direction — the real answer.** Use the ManagedSettings shield *as the warning*:
at the 5-minute mark apply the shield to the selected content with a custom `ShieldConfiguration`
("5 minutes left, {name}. Time to finish up." + a primary button), and have the ShieldAction
extension lift it on the button so the final minutes proceed. The shield is system-level, full
screen, and appears inside the app the child is using — the one surface iOS lets a third party
take over. Repeat at 1 minute; at 0 the shield stays. This is the mechanism that makes a
"transition assistant" different from a timer. Timing depends on DeviceActivity events at the
warning marks, whose reliability Phase 1 must measure on device (D-006's known limitation).

**What the shield API actually allows (verified against current docs, 2026-09-05).**
`ShieldConfiguration` takes `backgroundBlurStyle`, `backgroundColor`, `icon`, `title`, `subtitle`,
`primaryButtonLabel`, `primaryButtonBackgroundColor`, `secondaryButtonLabel` (and submenu items);
anything left `nil` uses the system default. `ShieldActionDelegate.handle(action:for:completionHandler:)`
receives the button press and answers with a `ShieldActionResponse`. So the interstitial is:
custom icon + "5 minutes left, {name}" + "Next: LEGO" + a primary button; pressing it lifts the
shield for the remaining minutes. Functionally stronger than a screen lock — a lock is dismissed by
unlocking, whereas the shield requires acknowledging the message before the app is usable again.

Scope it to the parent-selected content, not `.all()`: during screen time the child is by definition
inside selected content, so shielding that is both sufficient and proportionate (shielding
everything would interrupt a phone call or a homework app for no reason).

**Built in Phase 0 (2026-09-05):** the interstitial's copy and design, as
`ShieldPresentation.make(for:childName:)` in the package plus an in-app preview a parent can show
to a real child. Verified: a free Personal Team cannot even see the Family Controls capability in
Xcode (Apple DTS), and adding the entitlement would break installation — so the preview is the only
way to work on this before the gate, and it is the half that most needs iterating with children.

**Consequences.** `NotificationKind` gains no new cases now. Task 010/011/012 scope grows: a
`ShieldConfigurationExtension` and a `ShieldActionExtension` target — **two more bundle IDs in the
entitlement request** (`docs/entitlement-request.md` lists them). Copy for the shield goes through
the §7 checklist. Timing rides on DeviceActivity events at the warning marks, whose reliability is
D-006's known limitation: the shield is more forceful than a banner but may arrive late. Keep the
local notification as well — belt and braces.

---

## D-013 — Configurable reminders and dial controls (deviates from PRD §6.6)
**Date:** 2026-09-05 · **Status:** accepted (Dominic)

**Context.** PRD §6.6 fixed the warnings at 10/5/1 minutes with toggles and said "no custom
intervals in V1". Dominic wants dials: budget and extensions 2–120 minutes in 2-minute steps,
and up to three reminders each 0–15 minutes before the end (0 = off), 1-minute steps.

**Decision.**
- `ScreenTimeConfiguration.warningOffsetsSeconds: [Int]` replaces the three toggles: normalized
  (unique, clamped 60…900, earliest-first, ≤ 3). Legacy JSON with the toggle shape still decodes.
- `ScreenTimeState` warning cases are now ROLES — `firstWarning` (earliest; carries the activity
  chooser), `secondWarning` (middle, skipped with two reminders), `finalWarning` (last). One reminder
  is `firstWarning`. No reminders → `active` straight to `finished`.
- `WarningStateEngine` is offsets-driven; D-004's "entered but not shown" is superseded — a
  reminder the parent turned off does not exist as a stage.
- Notification identifiers are per slot (`screentimenext.warning.0/1/2`) + finished.
- `MinuteDial` is the shared control (drag around the ring, snaps to step, haptics, ± buttons,
  VoiceOver adjustable). Budget: 2–120 step 2 (the 1-minute floor was not adopted — say so if it
  should be). Extension: same dial, default 10. Reminders: three 0–15 dials.

**Rule added 2026-09-05 (Dominic):** a reminder must be strictly shorter than the window it runs
in. `ScreenTimeConfiguration.effectiveWarningOffsets(forWindowSeconds:)` is the single source: the
engine, notifications and every summary use it; the dials are bounded by `maxWarningOffset` (budget
− 1 min). A short remaining budget later in the day drops reminders that no longer fit and the
earliest fitting one carries the chooser. Timer copy shows the actual remaining minutes (rounded
up), not the reminder's nominal offset.

**Consequences.** PRD §6.6 / §6.11–§6.13 copy is now computed from the configured minutes.
Task 008 tests rewritten around offsets and roles. Docs that say "10/5/1" describe the defaults.

---

## D-014 — Live Activity for the countdown (Widget extension)
**Date:** 2026-09-05 · **Status:** accepted; target creation pending in Xcode

**Context.** Banners are missable and iOS cannot foreground the app (D-012). A Live Activity is
the one always-visible surface Apple offers: Dynamic Island / status area on iPhone, Lock Screen
on iPhone and iPad. No entitlement; a free Personal Team can ship a widget extension.

**Decision.** `SessionPresenting` (package protocol) is driven by `SessionController` exactly like
notifications; the app implements it on ActivityKit (`LiveActivityPresenter`); the widget renders
`ScreenTimeActivityAttributes` (package, `#if canImport(ActivityKit)`) with `Text(timerInterval:)`
so the countdown ticks without any process. Content (state line, chosen activity) updates when the
app updates the activity — start, choose, extend, and any tick while the app is open.

**Limits.** On an unlocked iPad in use, nothing is visible until the lock screen. The state line
does not advance while the app is closed (the timer does). Phase 1 can update the activity from
the DeviceActivity extension at warning marks.

**Consequences.** New target `ScreenTimeNextWidgets` (folder beside the app), linking the package;
`NSSupportsLiveActivities = YES` on the app target. Two more bundle IDs are NOT needed for the
entitlement request (no Screen Time API in the widget).

---

## D-015 — Blocklist vs. allowlist for protected content: category-first, not `.all(except:)`
**Date:** 2026-09-05 · **Status:** accepted (design); implementation is Task 005/011, Phase 1

**Context.** Dominic proposed inverting PRD §6.4: instead of the parent picking what to limit,
limit everything potentially entertaining (browser included) and let the parent pick exceptions.
The instinct is right — **the blocklist leaks**. Limit YouTube and the child opens TikTok; limit
both and the child opens Safari → youtube.com. PRD §17 already notes shielding an app does not
shield its web version. A budget with holes in it teaches a child to find the holes.

**What the platform actually allows (verified 2026-09-05).**
1. **The app cannot pre-select anything.** `ApplicationToken`s exist only once a human picks apps in
   `FamilyActivityPicker`; there is no API to enumerate installed apps or construct a category token.
   So "default to all entertainment apps" cannot be a default *the app sets* — it can only be a
   default *the parent taps*.
2. **`.all()` works** — it shields nearly everything (Messages and friends depend on the system's
   "Always Allowed" list).
3. **`.all(except:)` is broken.** Documented as an allowlist, but exempted apps are still shielded,
   with a *generic* shield — `ShieldConfigurationDataSource` is not consulted, so our transition
   interstitial (D-012) would not even render. An Apple Frameworks Engineer: *"There are known
   issues in this area."* Radar FB15500605, filed Oct 2024, unresolved as of the reports we found.
   Building V1's core model on a broken API would be a bad bet.

**Decision — category-first selection.** Keep the blocklist shape (§6.4), but stop steering parents
toward individual apps. `FamilyActivityPicker` lets a parent select whole **categories** in a few
taps, and it exposes **web domain categories** separately. So the recommended setup becomes:

- Entertainment + Games + Social Networking categories, and
- the matching **web categories**, which is what closes the browser hole.

Onboarding says this in plain language and treats picking individual apps as the exception, not the
norm. This gets most of the coverage Dominic wants, using APIs that work, and keeps our custom
interstitial rendering.

**Not adopted, and why.**
- `.all(except:)` — broken, and it would silence D-012's interstitial. Revisit if Apple fixes
  FB15500605; the storage model (an opaque `SelectionSnapshot`) already allows the swap.
- `.all()` at the end of the budget ("the device is done for today") — coherent, and it *works*,
  but it would also shield a homework app or a dictionary, which contradicts "Transition, not
  punishment". Closer to a Downtime feature, and §4 puts scheduling out of V1.

**Consequences.** Task 005 gains the category-first onboarding design (copy done in Phase 0, real
picker in Phase 1). Task 011 shields exactly what the selection names, still never `.all()`.
Honesty constraint (§17) unchanged: even category coverage is not airtight, and no copy may claim
it is.

---

## D-016 — Setup collapses to two screens; the child picks the activity, not the parent
**Date:** 2026-09-05 · **Status:** accepted (Dominic) · supersedes parts of PRD §6.1–§6.8

**Context.** The eight-step onboarding was built straight from the PRD, and it is wrong for the
scene the product actually lives in: a child wants the iPad *now*, a parent says "fifteen minutes"
and picks the device up. Anything that is not that decision is friction at exactly the wrong moment.
Dominic's rule: **the app should reach its purpose with as few taps as possible.**

**Decision.**
- **Two screens.** Welcome (Pip, one line, one button — a greeting, not a manual) → Quick Setup
  (a minutes dial and "what counts") → **a running timer**. The parent hands over a live session;
  there is no summary step to acknowledge.
- **The child's name is optional**, moved to Settings. Every greeting has a name-less form
  ("Hi!", "Nice job!"). "Is the app set up" is now `hasStoredConfiguration()`, not "is there a
  profile" — the old proxy stopped being true the moment the name became optional.
- **Reminders move to Settings**, with defaults derived from the budget (D-013 already does this).
- **The child chooses what's next, not the parent** — at the **second-to-last** reminder
  (`WarningStateEngine.chooserIndex`: with 10/5/1 that is the 5-minute one; with one reminder, that
  one). Early enough to prepare, late enough to feel real. If they ignore it, the chooser stays
  available through the final reminder. The parent's activity pre-approval screen is gone; D-009's
  "empty set means offer all eight" is now the normal case, not the fallback.
- **The dashboard's idle state is an instant-start surface**: minutes ± and "Start now", seeded
  from the saved budget, so a repeat "fifteen minutes" is two taps from launch.

**Tension acknowledged.** §7.4 asks for minimal interaction in the final five minutes, and with the
default reminders the chooser now lands exactly at five. Judged worth it: at ten minutes the choice
is abstract and forgotten by the time it matters. Watch this in validation — if children ignore the
chooser at five, move it back one slot.

**Consequences.** `OnboardingDraft.childProfile` is optional and `commit` no longer throws on a
missing name; `ChildSessionSnapshot.isChoosingMoment` drives the chooser; the Warnings, What's Next,
Child Profile and Ready steps are deleted. PRD §6.2/§6.6/§6.7/§6.8 are superseded — the *content*
of those screens survives in Settings and in the child flow, the *sequence* does not.

---

## D-017 — Urgency is carried by colour, never by Pip's face
**Date:** 2026-09-05 · **Status:** accepted (Dominic)

**Context.** Pip had an anxious mood (`.hurrying`: knitted brows, wide eyes) for the final minute.
Dominic: every expression should be positive; convey urgency with colour instead.

**Why he's right.** A worried face at the one-minute mark teaches the child that the ending is
something to dread — precisely the association this product exists to break (§7: transition, not
punishment). Colour carries the same information without any emotional charge: it is a signal, not
a judgement.

**Decision.**
- `.hurrying` becomes **`.excited`** — big grin, raised brows, arms swinging up. Every mood is now
  positive: happy, playing, thinking (curious), excited, cheering, sleepy (peaceful).
- The state ramp is **green → amber → orange → red**, and the finish is a **rainbow**
  (`Theme.celebration`, `CelebrationBackdrop`, `CelebrationRing`) rather than one more hue —
  the ending should look like the best moment on the screen, not the most alarming.

**Also in this pass (Dominic's list).**
- The dashboard hero **is** the session: it shows state and is the tap target for the child timer;
  the separate "Session" list section is gone, with End/Extend as chips on the hero.
- The transition interstitial is **full-bleed** — no card inside a box. That is also how the real
  ManagedSettings shield looks, so the preview got more faithful, not just cleaner.
- Tapping a warning notification opens the timer even on a cold launch (a pending request is
  honoured once routing settles).
- Setup splits: **time + reminders** on one screen (no headline — the dial says what it is), then
  **what counts** on its own, skippable. The budget dial steps by **one minute under fifteen**,
  two above, and the range now starts at one minute — "seven more minutes" is a real answer.

## D-018 — Colour means time, not activity; the picker is the screen; no per-category app counts
**Date:** 2026-09-06 · **Status:** accepted

**Context.** Four things Dominic hit on the device:
1. Every reminder interstitial came up a different colour. The card was tinted by the activity the
   child had chosen (`Theme.color(for: activity)`), so the colour said "you picked LEGO", not "you
   have two minutes left" — and Pip only ever had two faces across the whole sequence.
2. The dashboard hero carried labels for things a parent already knows or does not need: an
   "Open timer" caption on a tappable clock, "In progress"/"Not shielded" chips, a "your child"
   stand-in where a name was missing, and a "Status" section that mostly reported that everything
   was fine.
3. "What counts?" was a coy title on a screen whose real content was one button that opened
   something else.
4. Open question: can the app show how many installed apps a chosen category contains?

**Decision.**
- **`ShieldUrgency` (calm / soon / last / finished / spent) is carried on `ShieldPresentation`** and
  is the only thing that picks colour and expression: green → orange → red across the reminders,
  the rainbow reserved for the finish, lavender for "already spent today". A distinct mascot mood
  per step (playing / thinking / excited / cheering / sleepy). `forWarning(index:count:)` treats a
  lone reminder as the LAST one — `WarningStateEngine.role(ofWarningAt:count:)` calls index 0
  `.firstWarning` for state-machine reasons, and colour must not inherit that. The chosen activity
  still shapes the words and the badge; it no longer shapes the colour.
- **The dashboard keeps only what a parent acts on.** Hero = name (or "Today"), Pip, the ring, and
  End / Extend. No caption, no chips, no Status section. The one status line that survives is
  "Notifications are off", shown only when it is true, because that one means the app is not doing
  its job. Fixing this also fixed a real bug: End and Extend were `Button`s nested inside the
  hero's own `Button`, so the outer one swallowed their taps — the hero is now a plain view with
  `onTapGesture`.
- **The picker IS the setup screen.** Title: "Pick apps and categories". A scrollable, multi-select
  list of category tiles with a Websites section for browsers, running counts above it and a Start
  button pinned to the bottom. `ContentPickerModel` owns the picks so the step, the draft and the
  counts cannot disagree; the same view serves Settings as `ContentPickerScreen`.
- **Notification taps route through a latch** (`TimerRoutingLatch`) as well as the in-process
  broadcast, because on a cold launch `didReceive` runs before `RootView` is listening.

**Consequences.**
- The Phase 1 `ShieldConfiguration` extension reads `presentation.urgency` for its background
  colour; nothing else about that extension changes.
- `ContentCategory` is a **Phase 0 stand-in and can never be the real thing**: an
  `ActivityCategoryToken` cannot be constructed from a name, so these rows shield nothing. Phase 1
  replaces the rows inside `ContentPickerView` with `FamilyActivityPicker` inline — it is a SwiftUI
  view, not only a sheet — and everything around it (counts, Start button, `SelectionSummary`)
  survives unchanged. See B-005.
- Settings cannot pre-tick the picker from a saved selection, because the stored summary is counts
  only (§16). Reopening it starts empty until Phase 1, where Apple's picker holds its own state.

## D-019 — Settings reach the running session; reminders can only descend; the picker is the parent's
**Date:** 2026-09-06 · **Status:** accepted

**Context.** Five things Dominic found on the device:
1. Changing the next-activity list, the daily budget or the reminders in Settings did not show up
   in a session that was already running.
2. Nothing stopped reminder 1 being *smaller* than reminder 2 — 5 / 10 / 2 was settable, and the
   configuration silently re-sorted it afterwards, so the dials lied about what was saved.
3. The category rows were in our order, not the parent's.
4. "The usual three" were three categories **we** picked.
5. The Dynamic Island showed an SF Symbol, not the app's mascot.

**Decision.**
- **`SessionController.applyConfigurationChange()`.** Reminders and activities were already
  re-read from storage on every tick — those followed on their own, though the child timer read
  activities through a *computed* property, which touches no observable state, so SwiftUI never
  redrew the chooser; that is now a stored property refreshed on demand. The budget is the real
  bug: a window is a wall-clock window (D-006) whose end is fixed at Start. The fix keeps
  `startedAt` (elapsed time is spent and stays spent) and moves `endsAt` to
  `now + (newBudget − recorded − elapsed) + granted`. `lastState` is reset so the stage is
  re-derived: `WarningStateEngine.next` is monotonic, so without that a session at "one minute
  left" would stay red after the parent granted twenty more.
- **`SessionWindow.budgetSecondsAtStart`** records what the window was worth at Start, so a parent
  extension (§15) can be told apart from budget and is never clawed back by a settings save. Absent
  in windows written earlier, where it decodes as the full length — granted time zero, the honest
  answer when we cannot know.
- **Reminders strictly descend.** Two mechanisms, so the illegal state is unreachable rather than
  corrected behind the parent's back: each dial's range stops one minute short of the dial before
  it, and moving a dial pushes the later ones down (`clampedDescendingMinutes`). A dial set to 0
  turns off every later one — "reminder 3" with no reminder 2 is a numbering lie.
- **The picker is the parent's.** Rows are drag-reorderable and the order persists in the
  configuration; browsers sit first by default (the one row covering something no app category
  does, and the easiest to overlook); "My usual" is a set the parent saves from whatever is ticked,
  not three categories we chose.
- **Pip in the Dynamic Island**, drawn a second time as a compact `PipMark` in the widget target.
  Sharing `Mascot.swift` would mean either putting SwiftUI into the deliberately framework-free
  package or adding the file to two targets; a widget mark also has different needs (16–24pt,
  inside a black pill, sometimes drawn in a single tint).

**Consequences.**
- `applyConfigurationChange()` is now the call after any settings save — it subsumes
  `rescheduleNotifications()`, which could not move the window's end.
- A saved category order is always completed against the catalogue, so a category added in a later
  version can never be stranded off the bottom of an old saved list.
- `PipMark` must be kept in step with `Mascot.swift` by hand. Both are pure SwiftUI shapes, so the
  cost is a few lines when Pip's face changes.

## D-020 — One dial configuration, and buttons that survive a Form row
**Date:** 2026-09-06 · **Status:** accepted

**Context.** Two things Dominic hit in Settings:
1. The budget dial there stepped differently from the one in setup — Settings had its own
   hand-written `2...120, step: 2`, so it could not express a one-minute budget and jumped two at a
   time where setup moved one.
2. The +/− buttons under the dials did nothing in Settings — the budget dial's and the reminder
   dials' alike — while the identical control worked during setup.

**Decision.**
- **`MinuteDial.budget(_:)` and `MinuteDial.reminder(_:upperBound:…)`** are now the only way a dial
  gets built. Both read their range and steps from `ScreenTimeConfiguration`, so setup, Settings
  and the Extend sheet cannot drift apart again. Extra time gets the fine steps too — "five more
  minutes" is the common grant.
- **`.buttonStyle(.borderless)` on the +/− buttons.** This was not cosmetic. Inside a `Form` or
  `List` row, a `Button` with the default style makes the WHOLE ROW the tap target, and two of them
  in one row collapse into a single ambiguous target — which is exactly why they worked in setup (a
  `ScrollView`) and were dead in Settings (a `Form`). Each button also gets a real 44pt circular
  hit area rather than the glyph's outline.
- **The middle of the dial is the readout, not a control.** A tap on the number used to fling the
  value to whatever angle the finger happened to be at; the drag now ignores touches inside the
  inner 30%.

**Consequences.**
- Any new dial goes through a factory. A raw `MinuteDial(...)` outside `MinuteDial.swift` is a
  smell — it means someone is re-deciding the steps locally.
- The rule generalises: any row in a `Form`/`List` holding more than one button needs an explicit
  button style. `ContentPickerView`'s "My usual" row already carries `.bordered` for this reason.

## D-021 — The picker remembers; the Live Activity does not outlive its session
**Date:** 2026-09-06 · **Status:** accepted

**Context.** Two reports from the device:
1. Categories ticked in the picker were gone on the next launch. D-019 persisted the row ORDER and
   "my usual" but deliberately not the ticks, on a reading of §16 that turned out to be too broad.
2. After force-quitting the app, the Live Activity was still on screen and the reminders still
   fired — "why is it still running?"

**Decision.**
- **`ScreenTimeConfiguration.selectedCategories`** persists the ticks. §16 forbids storing or
  surfacing Apple's opaque `FamilyActivitySelection` TOKENS; our own catalogue rows are not tokens,
  and treating them as such cost the parent their setup on every launch. Stored in row order, so
  the list reads back the way they arranged it. In Phase 1 the real selection lives in Apple's
  picker (which persists its own state) and this remains the record of which rows were chosen.
- **Continuing after a force-quit is correct and stays.** Reminders are handed to iOS as calendar
  triggers, and the countdown is drawn from absolute dates by `Text(timerInterval:)` with no
  process (Rule 4). If swiping the app away stopped either, the app would be defeated by the most
  obvious action a child could take (§17). The budget is wall-clock time (D-006): it keeps being
  spent whether or not the app is open. None of that changes.
- **What WAS broken is the ending.** Nothing retired the Live Activity when the window ran out —
  only `finalizeLocked` ended it, which needs a new Start, a parent ending the session, or day
  rollover. So a finished session left a card sitting there claiming to be live. Now:
  · `SessionPresenting.finish(_:)` — distinct from `hide()`, because "time is up" is worth seeing
    for a few minutes whereas a session the parent ended should just go. It ends the activity with
    `dismissalPolicy: .after(now + 10 minutes)`.
  · The controller fires it on the transition INTO `.finished`, exactly once — `finish` restarts
    the dismissal timer, so calling it on every one-second tick would keep the card alive forever,
    which is the very bug being fixed.
  · `restore()` with no window calls `hide()`. This is what clears a card stranded by a force-quit:
    the app could not end it while it was not running, so the next launch does.
  · The widget treats `context.isStale` as finished. A force-quit partway through means no update
    ever arrives, so without this a dead card would keep claiming a session is running.

**Consequences.**
- A card can still linger if the app is force-quit AND never reopened — iOS gives no way to
  schedule an end without a process. The stale rendering makes it honest in the meantime, and the
  system retires it at its own limit.
- `finish` is one-way: `end(_:dismissalPolicy:)` stops the activity being updatable. That is fine
  for a session that is over, but it means an extension granted afterwards starts a fresh activity.

## D-022 — "Save as my usual" writes when it is pressed
**Date:** 2026-09-06 · **Status:** accepted

**Context.** D-021 stored `favouriteCategories` in the configuration, and it still did not survive a
relaunch. The value was right; the timing was wrong. `saveCurrentAsFavourites()` only changed
memory — the write happened when the parent went on to press Settings' own Save. "Done" on the
picker reads as "saved and finished", so pressing Done and leaving lost what had just been saved.
There was no feedback either: the button disappears the moment it works (the selection now matches
the set), so nothing distinguished "saved" from "did nothing".

**Decision.**
- The picker model takes an optional `autosave` storage target. "Save as my usual" and a drag both
  write **immediately**, independent of any surrounding screen's Save. A button labelled Save must
  save.
- Only the arrangement (order + "my usual") autosaves. The ticks stay with the selection the
  surrounding screen commits — Start in setup, Save in Settings — because that is the thing the
  parent is deciding on that screen.
- A short "Saved" replaces the button so the press is visibly acknowledged; it clears on the next
  change.
- Saving an empty set is refused: with nothing ticked, "my usual" would be an empty set the button
  could never usefully apply.

**Consequences.**
- **Setup passes no autosave target, deliberately.** `loadConfiguration()` returns defaults rather
  than throwing when nothing is stored, so an autosave during first-run setup would CREATE a
  configuration — and a stored configuration is what marks the app as set up (D-016). A parent who
  dragged one row and quit would come back to a skipped onboarding. The arrangement is written with
  everything else when they press Start.
- The general lesson for this codebase: a control whose label is a verb ("Save", "Apply") must
  complete that verb by itself. Deferring it to a parent screen's Save is a correctness bug, not a
  refactor detail.

## D-023 — Phase 1 storage moves to the App Group, with a migration and a fallback
**Date:** 2026-09-06 · **Status:** accepted (entitlements staged, see B-006)

**Context.** The paid membership exists, so the enforcement half can begin. Storage has to move from
the app's own container to the App Group, because that is the only directory the DeviceActivityMonitor
and Shield extensions can read. Two hazards: a parent already using the Phase 0 build has their
configuration in the app container, and a build whose provisioning is not ready must not crash.

**Decision.**
- `FileStorageService.shared()` prefers the App Group and falls back to the app container when the
  group cannot be resolved. A signing problem therefore degrades to "the extensions see nothing"
  rather than a launch crash.
- It migrates on first use: every record is copied into the group container, **only when the group
  container is empty**, and the originals are never deleted. Without this, switching directories
  would look exactly like a factory reset to anyone already using the app.
- `ServiceContainer.live(...)` replaces `.phase0(...)` at the app entry point. The four Screen Time
  services are still parameters, defaulting to their mocks, so Tasks 004/005/010/011 can swap in one
  real adapter at a time without the app ever being unbuildable.
- `ServiceContainer.storageIsShared` reports whether storage is actually in the group — the honest
  signal for "enforcement can work", which a healthy-looking app does not otherwise give.

**Consequences.**
- The copy is one-way and one-time. If a parent runs an old build after migrating, it reads the
  stale app-container copy. Acceptable: the old build is not something they can get back to.
- `Config/*.entitlements` are written but NOT referenced by the project yet — see B-006.

## D-024 — "Start over" erases the child's setup, not the parent's arrangement
**Date:** 2026-09-06 · **Status:** accepted

**Context.** D-021/D-022 put `categoryOrder` and `favouriteCategories` in `ScreenTimeConfiguration`.
That made "Start over" wipe them, so a parent who had dragged thirteen rows into their own order and
saved a "my usual" set lost both on every reset. Dominic asked for the saved default to survive both
a reset and a kill.

**Decision.**
- A separate record, `ParentPickerPreferences` (order + favourites + `favouritesAreCustom`), in its
  own file, which `eraseAll()` deliberately leaves alone. The configuration is the CHILD's setup —
  budget, reminders, what is covered — and that is exactly what a reset should take. The row order
  and "my usual" are the parent's own working arrangement and are not part of what is being reset.
- The ticks (`selectedCategories`) stay in the configuration and DO reset, because they are part of
  the setup being redone. What replaces them is better: a fresh picker opens pre-ticked with the
  parent's own saved "usual", so starting over lands them one tap from where they were.
- `favouritesAreCustom` gates that pre-tick. Offering back a set the parent saved is helpful;
  silently ticking three categories WE chose for them is presumptuous, and the flag is the only
  thing that can tell those two apart.
- The confirmation copy now names what is kept. A dialog that says "erases all settings" while
  quietly keeping some is a smaller lie than losing the data, but still a lie.

**Consequences.**
- `ScreenTimeStorageService` gains `loadPickerPreferences()` / `save(_:)`. Any future preference
  that belongs to the parent rather than the child's setup belongs in this record, not in the
  configuration — that is the line to check against when adding one.
- `eraseAll()` is no longer "erase everything ScreenTimeNext stored". If a full wipe is ever needed
  (an App Store privacy request, say), it needs its own method rather than a quiet re-widening of
  this one.

## D-025 — Enrol as `.individual`, not `.child`
**Date:** 2026-09-06 · **Status:** accepted · **Task:** 004

**Context.** `AuthorizationCenter.requestAuthorization(for:)` takes a `FamilyControlsMember`.
`.child` authenticates against a parent's Apple Account, so the child cannot undo it from Settings —
the stronger gate by far. It also requires the device to be signed into a child account inside a
Family Sharing group, and fails with `invalidAccountType` otherwise.

**Decision.** `.individual`.

The failure mode decides it. D-016's whole scene is a parent picking up the device with a child
already waiting; `.child` on the very common "family iPad signed in with a parent's account" is a
dead end at exactly that moment, and the error it gives ("not signed into a valid iCloud account")
does not tell the parent what to do about it. `.individual` enrols whoever is on the device behind
Face ID / Touch ID and works everywhere.

**Consequences.**
- The child can revoke access in Settings. That is a real loss, and it is one §17 already accepts:
  ScreenTimeNext is not tamper-proof, D-011's press-and-hold "Parents" control is the in-app gate,
  and revocation is DETECTED rather than prevented — hence the `.revoked` state below.
- Apple exposes three states (`notDetermined` / `denied` / `approved`); the app renders four. The
  difference is a latch in the adapter recording that approval once happened, so a later `denied`
  is reported as "was turned off" — a different situation for a parent, with a different fix.
- `.child` remains a genuine upgrade for households that do have Family Sharing configured. Worth
  revisiting as a choice once real families have used it (§21), not before.

**Also from Task 004:** `AuthorizationStatus` has a case the published documentation does not list —
`.approvedWithDataAccess`, which only the compiler revealed. It is treated as approved. This is
precisely what Rule 8 ("verify against the installed SDK") is for; the docs were not enough.

## D-026 — The picker wrapper is Rule 1's only exception, and it stays one file
**Date:** 2026-09-06 · **Status:** accepted · **Task:** 005

**Context.** `FamilyActivityPicker` is an Apple SwiftUI view that must bind to a live
`FamilyActivitySelection`, so the framework type and the view layer have to meet somewhere. D-001
allowed this as the single documented exception to Rule 1.

**Decision.** `ScreenTimeNext/ScreenTime/Selection/` holds all three pieces and nothing else does:
- `FamilyActivityPickerScreen` — hosts Apple's picker, hands back an opaque `SelectionSnapshot`.
- `FamilyActivitySelectionCoding` — the only place the two representations are both in scope.
- `AppGroupSelectionService` — persists the snapshot into the App Group so the extensions can read
  it (Rule 5), without ever looking inside the payload.

**Consequences.**
- The category tiles from D-018 cannot select anything enforceable — only a human tapping in
  Apple's picker produces tokens (B-005). Where Screen Time access exists, the real selection now
  OUTRANKS the tiles and the screen says so; where it does not, the tiles remain the Phase 0
  preview. The green shield on that row is deliberately gated on access being granted as well as a
  selection existing: a badge claiming enforcement while nothing is enforced would be the worst
  kind of lie this app could tell.
- A record that fails to decode is reported (`decodingFailed`), never silently treated as "nothing
  picked" — §6.4. "You picked nothing" and "we lost what you picked" need different screens.
- Still open for the next pass: "My usual" saves category tiles, not a real selection. Once it
  saves the snapshot instead, one tap re-applies a real, enforceable choice — which is the version
  of that feature actually worth having.

## D-027 — The picker saves itself, and a revoke reads as `.notDetermined`
**Date:** 2026-09-06 · **Status:** accepted · **Task:** 004, 005 (device findings)

**Context.** Two failures on the device, from the first real run of Tasks 004/005.

**QA-04 failed: the selection did not survive a relaunch.** The chain was: pick in Apple's picker →
Done → Done again on the wrapper screen → Save in Settings → disk. Four steps, and three of them
are labelled as if the work is already finished. Anyone who picked and walked away lost their
choice.

This is D-022 for the second time. That decision said "a control whose label is a verb must
complete that verb by itself", and I then built a new four-step chain anyway. So the rule is
restated here with teeth: **a save that depends on a later screen's save is a bug, not a design.**

**Decision.** `ContentPickerModel` takes the selection service and `applyRealSelection(_:)` writes
the moment Apple's picker returns. `loaded(from:selection:)` reads it back, so the picker opens on
the parent's last choice by whichever route they arrive. Settings' own Save no longer overwrites a
real selection with its older `@State` copy — that would have quietly undone the newest choice —
and "Clear selection" clears the stored one rather than just the screen's.

Writing a selection does not mark the app as set up (`hasStoredConfiguration()` is a different
record), so this is safe during first-run setup too.

**QA-14 wrong: revoking showed "Screen Time access needed".** Turning access off in iOS Settings
resets the status to `.notDetermined`, not `.denied` — so the latch that turns "denied after having
been approved" into `.revoked` never fired, and the parent was shown the first-run message as if
they had never been asked. It hid the only thing that mattered: it used to be on, and nothing is
being enforced now.

**Decision.** The latch applies to `.notDetermined` too (and to any future case). And because the
underlying status really is `.notDetermined` after a revoke, the recovery path changed: `.revoked`
now offers "Turn it back on", which genuinely brings the system sheet back, with Settings beside it
as the fallback. `.denied` keeps Settings only — after a decline in the sheet, iOS will not show it
again, so a "try again" button there would do nothing at all.

**Consequences.** Apple's status is not a state machine you can read literally; `.notDetermined`
means "no answer right now", not "never asked". Any future authorization logic should assume the
same, and any new save button should be checked against the D-022 rule before it ships.

## D-028 — Show what's covered; a browser is a category; no per-category app counts, ever
**Date:** 2026-09-06 · **Status:** accepted · **Task:** 005

**Context.** Four requests about the selection screen, one of which cannot be built.

**The one that cannot.** "After picking a category, show how many apps on this device belong to
it." This is B-005 and it is permanent, not a gap: an Apple Frameworks Engineer states outright
that there is no way to extract application tokens from a category token, and there is no API to
list installed apps at all, so even the denominator is unavailable. The honest replacement is to
say what a category MEANS — the "What's covered" sheet now tells the parent that a category covers
every app of that kind on the device and that iOS does not let apps list them. A number we cannot
know is worse than a sentence we can stand behind.

**The three that can.**
- **Tap the counts to see the contents.** `Label(token)` is Apple's own view: it draws the app's
  name and icon inside the system's process, so the app never learns the identity, cannot copy it
  into a string, and nothing is logged or persisted. That keeps §16 intact while answering the
  question a count cannot. Rendering goes through `FamilyControlAgent` on the main thread and can
  freeze the UI when many labels appear at once (FB12332927), so every list here is a `List`, which
  builds rows lazily.
  Offered only when a REAL selection exists: tile counts have nothing behind them to show.
- **A web browser is a category, not a website.** Ticking "Web browsers" means "the apps people
  browse with" — an app category like any other. Counting it on the websites line made the summary
  claim a website had been picked when none had, and only Apple's picker can produce one.
- **The dashboard hears about a new selection immediately.** The picker writes when it closes
  (D-027), so it now posts `configurationDidChange` as well; the dashboard was waiting for
  Settings' Save, which the parent no longer has to press.

**Consequences.**
- `ContentCategory.summary` can never report a web domain. A tile is a shortcut for making a
  selection, never a selection itself — the type now says so.
- Every place showing counts should offer the sheet. A number the parent cannot check is a number
  they have to take on trust, and this app asks for enough trust already.

<!-- Template for new entries:

## D-NNN — <short imperative title>
**Date:** YYYY-MM-DD · **Status:** proposed | accepted | superseded by D-NNN

**Context.** What forced a choice.

**Decision.** What was chosen.

**Consequences.** What this now constrains, and what would have to change to reverse it.

-->
