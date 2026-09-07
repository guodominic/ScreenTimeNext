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
**Date:** 2026-09-05 · **Status:** accepted · **Superseded by D-031**

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

## D-029 — "What's next" belongs to the family
**Date:** 2026-09-06 · **Status:** accepted · **Task:** 009 (revisited)

**Context.** `TransitionActivity` was a fixed enum of eight, and the PRD said so: "V1 does not
support custom or free-text activities." That was the wrong call. §6.11's whole premise is that the
child picks something they actually want to do, and a fixed list undercuts it the moment the real
answer is piano, or the dog, or Nana's house.

**Decision.** A struct with an id, name, invitation and symbol. The eight ship as built-ins; a
parent adds their own in Settings, and they live on the device.

**Consequences and the traps inside them.**
- **Identity is the id alone**, not the whole value. A rename must not orphan a choice already
  stored on a running session — the child picked THAT activity, whatever it is called now. Custom
  ids are UUIDs, so two families' "Piano" never collide.
- **Codable decodes a bare string.** Everything written while this was an enum encoded as its raw
  value, and real devices are full of those in sessions, windows and configurations. An id we no
  longer recognise decodes to a readable placeholder rather than throwing: a deleted custom
  activity must not take a running session down with it.
- **A built-in is re-resolved from its id**, not restored from disk, so improving its copy in a
  later version reaches families who already have it saved.
- **The Live Activity carries the name and icon, not just the id.** The widget is a separate
  process and cannot read the parent's list, so an id alone would render a family's "Piano" as
  nothing at all.
- **`Theme.color(for:)` maps by id** with a hand-rolled stable hash for customs. `hashValue` would
  have been the obvious choice and is wrong: Swift seeds it per process, so an activity would
  change colour every time the app relaunched.
- **A near-miss worth recording.** `ContentPickerModel.preferences` built a fresh
  `ParentPickerPreferences`, so the next row drag would have silently deleted every custom activity.
  It merges now. Any screen that owns part of a shared record must merge into it, never replace it.

## D-030 — Saved selection sets, because a website can only be typed once
**Date:** 2026-09-06 · **Status:** accepted · **Task:** 005

**Context.** The request was to type a website into the app and have it remembered as an option for
next time. The first half cannot be built: there is no public API that turns a string into a
`WebDomainToken`. A domain becomes real only when a person types it inside Apple's
`FamilyActivityPicker`.

**Decision.** Remember the whole SELECTION instead, under a name the parent chooses — "School
nights", "Weekend". Re-applying it brings back every app, category and website in one tap, so a
domain is typed once in its lifetime rather than once per use. That is the outcome the request was
actually after.

**Consequences.**
- Sets live in `ParentPickerPreferences`, so a reset keeps them (D-024) — they are the parent's
  work, not the child's setup.
- The snapshot stays opaque here as everywhere: a set carries it, never reads it. The subtitle is
  counts only (§16).
- Saving under an existing name replaces that set rather than making a second one with the same
  name, because two identical labels in a menu help nobody.

## D-031 — The parent gate is a PIN (supersedes D-011)
**Date:** 2026-09-06 · **Status:** accepted · **Supersedes:** D-011

**Context.** D-011 gated the way out of the child timer behind a one-second press-and-hold. That
was never a gate. A child who watches a parent do it once can repeat it, and what is behind it is
the screen that grants more screen time — the single thing a child has the most reason to reach.

**Decision.** A four-digit parent PIN. Tapping "Parents" opens a keypad; the dashboard is behind it.

**The details that matter.**
- **The PIN is never stored** — only a salted, iterated SHA-256 verifier, with a fresh random salt
  per PIN so two families choosing 1234 do not share stored bytes. 120k rounds is imperceptible for
  one entry and turns an offline sweep of all 10,000 PINs from instant into tedious.
- **This is not strong security and must never be described as such.** A four-digit PIN has ten
  thousand possibilities; no hashing changes that. It is sized for the actual threat — a child on
  the family's own device, with no file access — and §17's "not tamper-proof" still stands.
- **Wrong guesses cost time.** Three free, then a doubling delay capped at five minutes. The cap is
  deliberate: the counter must inconvenience a guessing child without locking out a parent who
  genuinely forgot. And only a CORRECT PIN clears the counter — if sitting out one wait reset it, a
  child with an afternoon would get unlimited guesses in batches of three.
- **A custom keypad, not a `TextField`.** The system keyboard brings autocorrect, a paste bar,
  dictation and a predictive row onto a screen whose whole job is to be hard to leave. Twelve
  buttons have no such doors.
- **With no PIN set, press-and-hold still works.** A parent must never be shut out of their own
  device by a feature they have not set up yet. Settings leads with the PIN row, and says plainly
  what the absence of one means.
- **"Start over" clears the PIN**, unlike the parent's preferences (D-024). A forgotten PIN that
  survived a reset would be an unrecoverable lockout on the family's own iPad.
- **The PIN is written the moment it is set**, not on Save — the D-022 rule. A gate a parent thinks
  they set and did not is worse than no gate, because they stop watching.

## D-032 — Remote parent control: what it would actually cost (not yet built)
**Date:** 2026-09-06 · **Status:** proposed — deliberately not started

**Context.** The wish: a parent, on their own iPhone, extends time or changes the categories on the
child's iPad without touching it. This is the most requested feature in every app of this kind, and
it is the one that changes what ScreenTimeNext *is*.

**Why it is not a small feature.**
1. **It breaks §16, which is currently a promise.** "No backend, no analytics, nothing leaves the
   device" is enforced on every test run by `scripts/privacy-audit.sh`, which fails the build on the
   sight of `URLSession`. Remote control needs a channel between two devices. That is not a rule to
   quietly delete; it is the app's stated position, and reversing it is a product decision, not an
   implementation detail.
2. **CloudKit is the least-bad channel.** A private CloudKit database keeps data in the family's own
   iCloud account rather than on a server we run: no accounts to build, no data we hold, nothing to
   breach. The privacy claim would become "your data stays in your iCloud" instead of "nothing
   leaves the device" — weaker, but still true and still unusual. A server of our own would mean
   accounts, a privacy policy with real teeth, and a running cost per family, for no benefit
   CloudKit does not give.
3. **The tokens do not travel.** `FamilyActivitySelection` tokens are device-scoped and meaningless
   elsewhere, so "change the categories from my phone" cannot be a remote picker. The parent's phone
   can send an INSTRUCTION ("use the set called School nights"); the child's device resolves it
   against its own stored selections. D-030's saved sets, which exist for a different reason, turn
   out to be the mechanism that makes this possible at all.
4. **The child's device has to be listening.** Push and CloudKit subscriptions can wake an app, but
   nothing guarantees delivery while it is force-quit or offline. "Extend by 10 minutes" must
   therefore be a request the child's device applies when it next runs, with the parent's phone
   showing what has actually been applied rather than what was sent. A control that silently does
   nothing is worse than no control.

**Order of work when it is taken on.** Finish enforcement first (010, 011, 012) — remote control
over an app that cannot yet hold a limit is a feature on top of nothing. Then D-030 sets should be
addressable by name, then the CloudKit record and the §16 rewrite, then the parent app.

## D-033 — Websites are blocked by name, not by token (correcting D-030)
**Date:** 2026-09-06 · **Status:** accepted · **Corrects:** D-030

**Context.** D-030 concluded that a parent cannot type a website into this app, because there is no
public API that turns a string into a `WebDomainToken`. That part is true, and it was the wrong
conclusion — I had only looked at the selection route.

**`ManagedSettings` blocks a domain from a plain string, with no token and no picker:**

```swift
store.webContent.blockedByFilter = .specific([WebDomain(domain: "youtube.com")])
```

`WebDomain(domain:)` is a public initialiser, and `FilterPolicy.specific(_:)` blocks exactly the
domains given. It even covers private browsing. Nothing about tokens applies here at all.

**Decision.** The parent types websites into a list of their own, stored as plain strings in
`ParentPickerPreferences`, applied by Task 011 through `blockedByFilter`. Typed domains are
normalised — trimmed, lowercased, scheme / `www.` / path stripped — so `youtube.com`,
`https://WWW.YouTube.com/feed` and a trailing space are one entry rather than three that each block
the same thing.

**Consequences.**
- The websites count on the picker screen now comes from THIS list, not from the selection
  snapshot. Two sources on one row, and the difference is real: apps and categories are tokens the
  parent picked, websites are text the parent wrote.
- The list lives with the parent's other work and survives "Start over" (D-024). A family's blocked
  sites are theirs.
- D-030's saved sets keep their value for apps and categories; websites no longer need them.
- **The lesson worth keeping:** "there is no API for X" was established by checking one framework.
  The answer lived in a different one. A negative finding about Apple's APIs is only as good as the
  breadth of the search behind it, and mine was one framework wide.

**Also in this pass:** "what's next" activities are drag-reorderable, with the same
never-hide-a-row contract as the category order — the parent's arrangement first, anything the
saved order has not heard of appended.

## D-034 — One minute, everywhere, up to ninety
**Date:** 2026-09-05 · **Status:** accepted

**Context.** The budget dial moved in 1-minute steps below fifteen and 2-minute steps above it, and
ran to 120. Both halves of that were wrong. A parent saying "twenty-three minutes, then dinner"
could not set twenty-three, because the dial skipped it — and the compromise bought nothing anyone
asked for, since a two-hour session is a different decision, not a longer version of this one. The
`+`/`−` buttons made it worse: they stepped by the same variable amount, so pressing `+` sometimes
moved one minute and sometimes two, with nothing on screen to explain why.

**Decision.** One step, one minute, every dial in the app — budget, reminders, extend. Range
1–90 minutes; default 15. `budgetStep(near:)`, `fineBudgetStepSeconds` and
`fineStepThresholdSeconds` are gone rather than set to constants, so there is no place left for a second step size to reappear.

**Consequences.**
- 90 rather than 120 shortens the drag, which is what made the variable step tempting in the first
  place.
- The `+`/`−` buttons and the drag now agree by construction, not by matching arithmetic.
- Every new dial gets this for free through `MinuteDial.budget(_:)` / `.reminder(_:upperBound:)`;
  a raw `MinuteDial(step:)` with anything but 1 is now the thing to catch in review.
- **This departs from the PRD.** §6.5 specifies a 60-minute default. Sixty is a number a parent had
  to dial DOWN from every single time, and "fifteen minutes, then dinner" is the sentence this app
  exists to answer. `OnboardingDraftTests.testDefaultsMatchThePRDExceptTheBudget` is named for the
  departure so nobody quietly "fixes" it back to match the document.

## D-035 — Delete the category tiles
**Date:** 2026-09-06 · **Status:** accepted · supersedes the picker half of D-019 and D-028

**Context.** "Pick apps and categories" had two halves that looked alike and were not. Thirteen
category tiles we drew ourselves — tap to include, drag to reorder, save three as "my usual" — and
one row that opened Apple's `FamilyActivityPicker`. Only the second one could shield anything.
B-005 is permanent: there is no API that turns a category name into a token, so a ticked tile was a
record of an intention and nothing else. The counts row added them together, which made the screen
say "3 categories" when the answer to "what will actually be blocked?" was "nothing".

Two ways to fix it: teach the tiles to drive Apple's picker (impossible — B-005), or delete them.

**Decision.** Delete them. The screen is now Apple's picker, a list of websites the parent typed
(D-033), and the counts, which come from the two things that are real. `ContentCategory` is gone
from the codebase; `ScreenTimeConfiguration.selectedCategories` and the
`categoryOrder` / `favourites` / `favouritesAreCustom` fields of `ParentPickerPreferences` went with
it.

**Consequences.**
- Both records keep hand-written decoders, so a file written by a build that had those keys still
  decodes — the keys are ignored, never a throw. A throw here would reset a family's whole setup.
- "My usual" is gone as a concept; D-030's saved SETS replace it and are strictly better, because a
  saved set holds real apps, real categories and real websites rather than three of our tile names.
- The drag-to-reorder work from D-019 survives only on the "what's next" activity list, which is
  ours to define and therefore can be reordered honestly.
- To reverse this, Apple would have to publish a way to build an `ActivityCategoryToken` from
  something other than their own picker. Until then, a control that promises what it cannot deliver
  is worse than no control.

## D-036 — The PIN is set on the way in, not in Settings
**Date:** 2026-09-06 · **Status:** accepted · supersedes D-031's press-and-hold fallback

**Context.** D-031 replaced the press-and-hold parent gate with a PIN, but left the PIN optional:
no PIN meant the gate fell back to a long press, so a family that never opened Settings had the old
non-gate. That is exactly backwards — the families least likely to go looking for a security
setting are the ones whose child will find the Parents button first.

Separately, the welcome screen ended in a "Let's go" button that agreed with a screen nobody
disagrees with, and ending a session asked "are you sure?" behind a gate that had already asked.

**Decision.** Three changes, all removing a step:
- The first time the timer screen appears with no PIN stored, the create pad opens immediately,
  with no Cancel and no swipe-to-dismiss. Setting it returns straight to the dashboard. Every later
  trip back to the dashboard needs that PIN; Settings still changes it.
- The welcome screen animates itself into the time dial after ~2.4s. A tap anywhere skips ahead.
- "End" ends. The confirmation is gone; the PIN was the confirmation. "Start over" keeps its
  dialog, because that one erases the child's setup.

**Consequences.**
- `ParentGateButton` no longer takes `hasPIN` and has no long-press path: there is no longer a
  state in which no PIN exists after the first visit.
- The forced pad is the one moment the app insists on something. It insists exactly once, and only
  after the parent has already chosen a length — never before they have seen what the app does.
- A parent who forgets the PIN still has "Start over" on the dashboard, which clears it (D-031).

**Bug this caused, fixed 2026-09-06.** The greeting can be advanced two ways — the timer and a tap
— so a flag stopped it happening twice. But the greeting is the ROOT of the navigation stack, and
SwiftUI keeps a root alive while a destination sits on top of it, so the flag survived the trip
back: a parent who tapped Back landed on a greeting where nothing worked and had no way forward at
all. It is reset from `.onChange(of: viewModel.path)` rather than `.task` or `.onAppear`, because
neither is guaranteed to run again for a view that never actually went away. Coming back shows the
greeting settled and waits for a tap — it does NOT replay and walk the parent forward again, which
would make it a screen they cannot choose to stay on.

## D-037 — One daily schedule, midnight to midnight, restarted only when it would differ
**Date:** 2026-09-06 · **Status:** accepted

**Context.** Task 010 had four open questions: what the schedule's window is, how it relates to
midnight, what the platform limits are, and when a restart is warranted. All four were left open
deliberately, because getting one wrong is the kind of bug that only shows up on a real device on a
real evening.

**Platform limits, verified against Apple's own error documentation (2026-09-06):**
- **20** activities at a time per app *and its extensions* — `MonitoringError.excessiveActivities`.
- A schedule interval must be at least **15 minutes** (`.intervalTooShort`) and at most
  **one week** (`.intervalTooLong`).

We register exactly one activity with exactly one event, so none of these constrain the design. The
limit worth remembering is the first one: it counts the extension's registrations too, so anything
that registers per-session rather than per-app would climb toward twenty over a day.

**Decision — the schedule.** One `DeviceActivityName` (`screentimenext.daily`), one event
(`screentimenext.budgetReached`), interval **00:00 → 23:59, repeating**. Midnight, because the
app's own idea of "today" is `Calendar.startOfDay` (Rule 4) and two different day boundaries would
hand a child a second budget at whatever other hour we picked. 23:59 rather than 24:00 because
`intervalEnd` is a time of day and 24:00 is not one. Task 017 tests rollover against this.

**Decision — `includesPastActivity: true`.** The event counts usage from the start of the interval,
not from the moment we registered. Without it, a parent who edits the budget at 4pm silently hands
back a full budget, and so does every app launch that re-registers.

**Decision — when to restart.** `restartMonitoring` compares the registration it would write
against the one `DeviceActivityCenter` already holds — same applications, categories, web domains
and threshold — and does nothing when they match. Re-registering is not free: it discards the
system's own accounting for the event, and `includesPastActivity` is what keeps that from costing
the child their spent minutes. Cheap to check, so it is checked every time.

**Decision — a threshold over an empty selection is refused.** `startMonitoring` throws rather than
registering an event with no tokens. Such an event can never fire, so registering one would leave
the app looking armed while nothing could ever trigger — the failure mode this whole task exists to
rule out.

**Consequences.**
- `MonitorJournal` (App Group `UserDefaults`, 20 entries, self-trimming) is the extension's ONLY
  channel to the app: a callback name, our own activity name and a timestamp. §16 — the extension
  knows which apps tripped the threshold and must never write that down.
- The dashboard shows whether iOS currently holds the registration, and the last check-in. A parent
  cannot discover this any other way, because the extension does its work while the app is closed.
- **Still unproven:** that `eventDidReachThreshold` actually arrives. The simulator accrues no real
  usage, so this is a device test, and it is the reason Task 010 ends as
  NEEDS MANUAL DEVICE TEST rather than PASS.

## D-038 — Either order, and an honest label on the app count
**Date:** 2026-09-06 · **Status:** accepted

**Context.** Two complaints, one screen apart.

First: "what's covered" was reachable only *after* the time dial. The two decisions have nothing to
do with each other — a parent who already knows which apps they want covered was being made to
answer "how long?" first to get at it.

Second, and more interesting: with a whole category ticked, the counts row read **"0 apps"**. That
is technically accurate (`applicationTokens` holds only apps ticked one by one) and completely
misleading, since the category covers every app inside it. Dominic asked the obvious next question
— can we just count the apps in the category and show that?

**We cannot, and this is B-005, confirmed again rather than assumed.** Two independent walls:
- A category token is opaque. An Apple Frameworks Engineer states it directly: "There is no way to
  extract application tokens from a category token."
- There is no API to list installed applications at all, so even the denominator does not exist.

`DeviceActivityReport` was worth checking, because it *does* see per-application and per-category
activity. It does not help: it is a SwiftUI view that renders inside its own sandboxed extension,
which Apple's documentation says "prevents your extension from ... moving sensitive content outside
the extension's address space". It could show, inside its own view, how many apps in a category the
child actually *used* — usage, not coverage, and never a number the app itself can read. Filed as a
possible future feature, not as an answer to this question.

**Decision.**
- ~~The picker opens from the time step as well as being the step after it.~~ **Reverted the same
  day.** The screen immediately after the time step *is* the picker, so the row was a second door
  onto the room you were already walking into — and two entries to one place read as two places.
  The original complaint was real but I answered it in the wrong place: the fix that mattered is
  that the picker is one "Next" away and always reachable from Settings, not that it has two doors.
  Recorded rather than quietly undone, so nobody re-adds it in three months.
- The pill is labelled **"apps picked"**, not "apps", and a footer under the counts says plainly
  that each category covers every app in it and that iOS does not tell us which or how many.

**Consequences.** The app never displays a fabricated coverage number. The one place a parent can
see what a category actually covers stays Apple's own picker, which is where the tokens live. If
Apple ever exposes a per-category count it drops into `SelectionSummary` and the footer comes out.

## D-039 — Every "what's next" activity belongs to the family, ours included
**Date:** 2026-09-06 · **Status:** accepted · extends D-029

**Context.** D-029 let a parent add their own activities and edit or delete *those*. The built-in
eight stayed fixed, on the reasoning that they are ours. That reasoning does not survive contact
with a real family: "Bath" is a suggestion about someone's evening, not a fact about it, and a
household where nobody does homework has a row that will never be tapped taking up a tile.

**Decision.** Swipe any row — built-in or not — to rename or remove it.

- **Remove a custom one** deletes it.
- **Remove a built-in** adds its id to `hiddenActivityIDs`. Hidden, not deleted: a built-in is a
  `static let` in code, and a family that drops "Bath" and later wants it back should get it back
  rather than retype it. "Bring back the ones I removed" appears in Settings once anything is
  hidden, and only then.
- **Rename a built-in** creates a real custom activity with a fresh id, hides ours, and drops the
  new one into the slot the old one occupied. It does NOT edit the built-in in place, because
  `TransitionActivity.init(from:)` deliberately re-resolves a built-in from its id on every decode
  (so improving our wording reaches families who already have it saved) — which would silently
  undo the rename on the next launch. An id nothing else owns is what makes the new name theirs.
- **Removal stops one short of empty.** `canRemoveActivity(_:)` refuses the last row. A chooser
  with nothing in it is not a configuration, it is a broken §6.11.

**Consequences.**
- A child mid-session who already chose an activity that has since been renamed keeps seeing the
  old name, because the choice stored on the window is the old id. That is correct: they chose that
  thing, and the window is a record of what happened, not of what the list looks like now.
- `hiddenActivityIDs` lives in `ParentPickerPreferences`, so it survives "Start over" along with
  everything else the parent made (D-024).

## D-040 — The shield is real: one named store, and two rules the audit now enforces
**Date:** 2026-09-06 · **Status:** accepted · implements D-012

**Context.** Task 011 turns the interstitial from a preview into the thing a child actually meets.
Three decisions were load-bearing enough to write down.

**Decision 1 — one named store, and no wholesale clear, ever.** `ManagedSettingsStore` is a SHARED
system surface: Apple's own Screen Time writes to it, and so does every other parental-control app
on the device. `clearAllSettings()` on the default store would erase all of it. A family could lose
months of Screen Time rules because our fifteen-minute timer ended. So ScreenTimeNext owns exactly
one named store (`screentimenext`), never touches the default one, and removal sets our own four
keys to nil by name. We never shield `.all(except:)` either — a phone call, Messages and the camera
are never covered by us (§15).

Both of those are now **enforced by `scripts/privacy-audit.sh`** (rules 7 and 8), which runs on
every test run, rather than being a promise in a comment. Each was verified by planting a violation
and watching the audit fail. A rule nothing checks is a rule that survives exactly as long as the
person who remembers it.

**Decision 2 — the copy stays in the core package.** `ShieldConfigurationExtension` computes
nothing and writes nothing: it reads the App Group, works out which `ShieldMoment` applies, and
hands it to `ShieldPresentation.make(for:childName:)` — the same call the in-app preview makes. The
screen a parent demonstrates to their child and the screen the child later meets cannot drift,
because there is one copy of the words.

**Decision 3 — the button continues mid-session and closes at the end, and there is no second
button.** `primaryButtonContinues` already encoded this for the preview; the action extension now
reads the same flag from the clock. §17 — a child can never grant themselves more time. The
template's `fatalError()` on an unknown action was replaced with `.close`: an unrecognised control
must never become a way through, and crashing in a child's face is not error handling.

**Also settled here.** Renaming a built-in shield string is safe; the typed-website filter (D-033)
is deliberately NOT lifted when the reminder button is pressed, because those are sites a parent
blocked outright rather than part of the budget — a heads-up is not permission to visit them.

**Consequences.** Both extension targets carry the App Group and `family-controls` entitlements and
link `ScreenTimeNextCore`. Xcode created them at iOS 27.0, which would have silently restricted the
whole app to iOS 27 devices — corrected to 18.0, the same trap as the monitor extension, and now
worth checking on every new target.

**Still unproven:** that the shield renders and that its button behaves, on a device. Everything
here compiles and is reasoned from the installed SDK; none of it has met a child yet.

## D-041 — The notification delegate is `@MainActor`, and that is load-bearing
**Date:** 2026-09-06 · **Status:** accepted · fixes a crash introduced by D-018's notification tap

**Context.** The first real device test of the shield never got as far as the shield. A reminder
fired, Dominic tapped it, and the app died:

```
*** Terminating app due to uncaught exception 'NSInternalInconsistencyException',
    reason: 'Call must be made on main thread'
    -[UIApplication _performBlockAfterCATransactionCommitSynchronizes:], UIApplication.m:3470
    ...
    @objc closure #1 in UserNotificationScheduler.userNotificationCenter(_:didReceive:)
```

**What was actually wrong.** The `async` form of `UNUserNotificationCenterDelegate`'s methods is
Swift's bridge over an ObjC method with a completion handler, and UIKit invokes that completion
handler on **whatever thread the async function finishes on**. Ours was declared `nonisolated`, so
it always resumed off the main actor. The `await MainActor.run { post }` at the end made this worse
rather than better: it hopped to main, posted, and hopped straight back OFF main before returning —
so the completion handler ran on a cooperative-pool thread, UIKit did its state-restoration work
there, and asserted.

`nonisolated` was put there for a real reason — the app module defaults to main-actor isolation and
this type has to satisfy nonisolated `NotificationScheduling` requirements — but it was applied to
the whole type's members by habit, including the two where it is exactly wrong.

**Decision.** Both delegate methods are `@MainActor`. The class stays `nonisolated` for the
scheduling half. The inner `MainActor.run` is deleted, because the method now already runs there.
(Apple DTS gives this same fix: developer.apple.com/forums/thread/709563.)

**Consequences.**
- The crash was in the one path a CHILD triggers — tapping a reminder we sent them — so it was
  invisible to every test that launches the app and drives the UI, which is every test we have. It
  took a real reminder on a real device, which is exactly what the Task 010/011 device tests are
  for and exactly why they are worth the interruption.
- `ShieldActionExtension` uses the completion-handler form and calls back synchronously on the
  system's own thread, which is correct for that API and has no equivalent trap. Checked, not
  assumed.
- **The general lesson:** an `async` method bridged from an ObjC completion-handler API finishes
  wherever its isolation says, and the caller may have thread requirements the compiler cannot see.
  `nonisolated` is not a neutral default there — it is a decision about which thread the framework's
  completion handler runs on.

## D-042 — One sentence decides when the shield is up
**Date:** 2026-09-06 · **Status:** accepted · Task 012

**Context.** Task 010 proved the system wakes us when the budget is spent. Task 011 built what the
child then sees. Dominic tested, the timer hit zero, and nothing happened — correctly, because
nothing in the codebase yet connected the two. That gap is this task.

The temptation was to sprinkle `applyShield` / `removeShield` at each of the eight or so moments
that could matter: session start, session end, expiry, extend, midnight, config change, launch,
threshold callback. That is how you get a device that is shielded when it should not be, in a way
nobody can reproduce, because the answer depends on which of eight call sites ran last.

**Decision.** One function, `Enforcement.reconcile`, and one sentence:

> **Covered apps are shielded exactly when today's budget is gone.**

Every caller does the same thing: recompute from stored state and make the device match. It is
idempotent, so a repeated call changes nothing; it derives everything from absolute timestamps, so a
missed call costs nothing and the next one repairs it. Callers: app launch and configuration change
(`MonitoringCoordinator`), every child-timer state change, the parent's start / end / extend, and —
the one that actually matters — the DeviceActivity extension's threshold callback, which is usually
the only process of ours running at that moment.

**What this rule deliberately leaves open.** A parent who presses "End" with budget still on the
clock stops the session but does **not** block the device. They ended a round, not the day. Making
"End" shield would need a second concept — "the day is over" as distinct from "the budget is
gone" — and that concept does not exist yet. Worth revisiting if a family wants a hard stop; noted
here so it is a choice rather than an oversight.

**Consequences.**
- `Enforcement`, `ManagedSettingsShieldService`, `FamilyActivitySelectionCoding` and
  `AppGroupSelectionService` are now compiled into the DeviceActivity extension as well as the app.
  Shared rather than duplicated on purpose: rules 6 and 7 are security-critical, and code that must
  never call `clearAllSettings()` should exist once, not once per process.
- `ShieldActionExtension.liftShield()` stays its own small implementation. It is NOT a duplicate of
  `removeShield()`: it deliberately leaves the typed-website filter (D-033) in place, because those
  are sites a parent blocked outright rather than part of the budget, and a reminder is not
  permission to visit them.
- **Not yet built:** D-012's other half — the shield as the mid-session REMINDER. That needs extra
  `DeviceActivityEvent` thresholds at (budget − reminder) so the system wakes us early too. Today's
  reminders are notifications only.

## D-043 — A threshold per reminder, so the system wakes us inside the app
**Date:** 2026-09-06 · **Status:** accepted · completes D-012 · extends D-037

**Context.** The budget-spent shield works on device. But Dominic reported the thing that actually
matters: when the timer ran out **while he was using a covered app**, nothing happened. The shield
only appeared when he left that app and went back into it.

Two explanations, and they call for different fixes, so it is worth being precise about which:

- **A — the callback arrived on time, and iOS did not re-evaluate the app already in the
  foreground.** Then this is a platform behaviour and no amount of our code changes it.
- **B — the callback arrived LATE**, at the moment he re-entered the app. `DeviceActivityEvent`
  thresholds are usage-accounted, not clock-accounted, and the system decides when to reconcile
  that accounting. Then the shield went up exactly when we asked; we just asked late.

`MonitorJournal` already timestamps every callback and the dashboard shows the last one, so the two
are told apart by comparing that time against when the timer hit zero. Recorded here because the
temptation was to guess, and the guesses lead to opposite fixes.

**Decision (useful under either explanation).** Register a `DeviceActivityEvent` for **each
reminder** as well as for the budget, at `budget − offset`. Still one `DeviceActivityName`, so the
20-activity limit (D-037) is nowhere near.

Why this is the right thing regardless of A or B:
- It is what D-012 promised and Task 011 was built for. A reminder that only posts a notification is
  a reminder a child can swipe away without looking up; the shield is the version they cannot.
- The threshold fires *because usage accrued*, which means the child is very likely inside a covered
  app at that moment — exactly where the heads-up is worth something.
- It gives the system three or four chances to wake us during a session instead of one at the very
  end, so under explanation B the child is interrupted before the end even if the final callback
  drifts.

**How the two kinds are told apart.** By event name (`MonitoringName.isWarningThreshold`), because a
name is all the system hands the extension and opening storage to ask "which one was that" is work
in a process that may be killed the moment it returns.

**A reminder shield must NOT go through `Enforcement.reconcile`.** There is time left, so the rule
would correctly say "unshielded" and take the reminder straight back down. `raiseReminderShield`
exists for that one case. The child gets their remaining minutes back by pressing the button, which
is what makes it a pause rather than a punishment.

**Consequences.** `ScreenTimeMonitoringService` now takes `warningOffsetsSeconds`, and
`sameRegistration` compares the whole event map rather than a single event — otherwise changing a
reminder would not trigger a re-registration and the parent's change would silently not take.

## D-044 — Three shields, two dials, and the last one asks
**Date:** 2026-09-06 · **Status:** accepted · supersedes D-016's chooser placement

**Context.** Once the reminder became a full-screen shield (D-043) rather than a notification,
"how many reminders" stopped being a preference and became the shape of the experience. Dominic
described what a child should actually meet, in order:

1. **Heads-up** — "5 minutes left". OK, carry on.
2. **Decide** — "1 minute left". Pick what's next, then carry on.
3. **The end** — time's up; this one does not let you carry on.

Three interruptions in one session. A fourth is nagging.

**Decision.**
- `maxWarnings` 3 → **2**. Two dials in Settings and in setup; the third shield is the end itself,
  which is not a dial and never was.
- The chooser moves to the **last** reminder. D-016 put it second-to-last so a child would not be
  choosing under pressure in the final minute — but that reasoning was about a notification, and
  with two reminders "second-to-last" IS the first one, the earliest possible moment. Asking before
  they have felt the time running out gets an answer that means nothing by the end.
- `ShieldMomentResolver` (framework-free, in the package) decides which of the three a child is
  looking at. Both extensions call it: the configuration extension draws the screen, the action
  extension acts on the buttons, and if they computed this separately a child could tap "LEGO" and
  get "Bath".

**What made this possible — and what it cost.** `ShieldConfiguration` has a secondary button with
`secondaryButtonSubmenuItems`, and `ShieldAction` has `first`/`second`/`thirdSecondarySubmenuItemPressed`
to report which was tapped. That is the only list a system shield can show, so:
- **Three options, maximum.** The child is offered the first three in the PARENT's order, which is
  what the drag-to-reorder in Settings is for (D-039). The order they chose decides what their
  child sees.
- **iOS 26.4+.** The submenu and those action cases are brand new. The app supports iOS 18, so on
  anything older `supportsChooserMenu` is false, the second reminder is an ordinary heads-up, and
  the child picks inside ScreenTimeNext as before. Less good, still whole — and the guard and the
  `#available` branch that renders it agree by construction rather than by comment.

**Consequences.**
- The preview a parent can show their child now has all three shields, including the one that asks,
  and draws the submenu as the plain list it amounts to. A preview that omitted it would let a
  parent sign off on a screen their child never sees.
- On the chooser shield the primary button is "Not yet" and does NOT take the child's remaining
  minutes away. Declining a menu is a UI decision, not a reason to end screen time early.
- A child who has already chosen gets the plain reminder instead: re-asking reads as "that wasn't
  good enough", and costs a tap for nothing.

## D-045 — Face ID is a shortcut past the PIN, and it is off by default
**Date:** 2026-09-06 · **Status:** accepted · extends D-031/D-036

**Context.** Dominic asked whether the parent gate could be Face ID — defaulting to Face ID with
the PIN as a fallback. It is the right instinct everywhere else and the wrong default here, for one
reason that is specific to this app:

**ScreenTimeNext is usually installed on the child's own iPad, and the face enrolled on a child's
iPad is the child's.** Face ID there is not a gate, it is a door held open: the child glances at the
screen, lands on the parent dashboard, and gives themselves more time. On a shared family iPad with
the parent's face enrolled it is genuinely better than typing — but the app cannot tell the two
situations apart, and guessing wrong fails silently and in the child's favour.

**Decision.** The PIN stays the gate. Face ID is an opt-in shortcut, off until a parent turns it on
in Settings, with the reason written next to the switch rather than in a help page: *"Only if this
iPad recognises YOUR face. If it recognises your child's, this lets them straight through."*

**The line that matters most.**

```swift
.deviceOwnerAuthenticationWithBiometrics   // biometrics only              ← what we use
.deviceOwnerAuthentication                 // biometrics, then the DEVICE PASSCODE
```

The second is the usual choice and would defeat the whole feature: the device passcode is the one a
child types to unlock their own iPad every day. When Face ID fails our fallback is our own PIN — the
one thing in this app the child has never been told. For the same reason `biometryLockout` is
treated as *unavailable* rather than as a failure: clearing a lockout needs the device passcode, and
that is exactly the door we are refusing to open.

**Consequences.**
- Offered only on the unlock pad — the gate a parent passes several times a day. Changing the PIN
  still requires the keypad: proving who you are in order to set a new PIN is the one moment a face
  cannot stand in for typing.
- Offered once per appearance. A parent who dismissed the sheet wants the keypad, and re-presenting
  it would be an argument.
- A fresh `LAContext` every time: `canEvaluatePolicy` caches for the life of the context, so a
  reused one keeps reporting "enrolled" after a parent removes their face.
- The preference lives with the parent's other work and survives "Start over" (D-024). The PIN does
  not (D-031) — a forgotten PIN must always have a way out, and this must not become one.
- `NSFaceIDUsageDescription` is set on the app target; without it iOS terminates the app the first
  time it asks.

## D-046 — Unlocking lands you on the dashboard, and the face asks before the keypad does
**Date:** 2026-09-06 · **Status:** accepted · fixes two things D-045 exposed

**Context.** Two reports from the first run with Face ID on, and they are worth separating because
only one of them is really about Face ID.

**1. Unlocking bounced the parent straight back to the timer.** `RootView` re-presents the child
timer whenever the scene becomes active and a session exists — which is right when a CHILD opens
the app mid-session, and wrong the moment a parent has just proved they are a parent. Face ID made
it obvious rather than causing it: its system sheet takes the scene inactive and hands it back
active, so the unlock and the bounce happened in the same breath. The PIN had the identical bug,
quieter — glance at a notification, come back, and the dashboard is gone.

**Decision.** `RootView` remembers that a parent came through the gate (the timer cover closing IS
that event, since the gate is the only way out of it — D-036) and stops auto-presenting until one
of three things happens: they open the timer themselves, they start a session, or **the app goes to
the `.background`**. That last one is the whole design: `.background` means the app really went
away and the device may be back in the child's hands, while `.inactive` is a system sheet, the app
switcher or the notification shade — the parent never left. Distinguishing those two scene phases
is what makes "stay where I put you" and "protect the session from the child" both true.

**2. The keypad was on screen underneath the Face ID sheet.** It asked a parent to do two things
at once and made the shortcut look like extra work.

**Decision.** One at a time. The pad opens in a "deciding" state (nothing offered while we ask the
device what it has — a keypad that appears and then vanishes is worse than a short wait), then
shows the face and "Looking for you…", and reveals the keypad only when the face does not work
out: cancelled, unrecognised, or unavailable. "Use your PIN instead" is always there for the parent
who would rather type.

**Consequences.**
- The subtitle changes with the stage. "Enter your PIN" printed under a Face ID sheet is an
  instruction for a screen that is not on screen.
- A failed match still says so, on the keypad, where the next attempt happens.

## D-047 — A session's moments are wall-clock schedules, not usage thresholds
**Date:** 2026-09-07 · **Status:** accepted · **supersedes D-043**

**Context.** The first real session with reminders on produced four symptoms, and they turned out
to be one mistake:

- opening YouTube seconds after starting a 15-minute session showed a shield reading "5 minutes
  left", with the first reminder set to 3 minutes and no time elapsed;
- the 3-minute notification fired with no shield;
- the 1-minute notification fired with no shield;
- when the time ran out YouTube still opened, and the finished shield only appeared after opening
  ScreenTimeNext and going back.

**What was wrong.** D-043 registered a `DeviceActivityEvent` threshold per reminder. A threshold
measures **usage**, and this app's timer is a **clock**. Three consequences, all of them observed:

1. `includesPastActivity: true` (correct for a daily budget, D-037) makes a threshold count usage
   since **midnight**. A session started after any earlier use is already past its reminder
   thresholds, so they fire the instant monitoring registers — the shield at second one. The "5
   minutes left" came from the session window, which had barely started; the two numbers had
   nothing to do with each other, which is exactly what Dominic saw.
2. **An event fires at most once per interval**, and our interval is a day. The first session
   spends every reminder; every later session that day gets none.
3. A child who puts the iPad down accrues no usage while the clock keeps running, so even
   correctly armed, a usage threshold cannot mean "three minutes before 8:15pm".

**Decision.** Each moment in a session gets its own `DeviceActivitySchedule` that simply **ends at
that moment**, with `repeats: false` and **no events at all** — the callback is the clock reaching a
time, so it needs no tokens and cannot be confused by usage. `intervalDidEnd` is now the callback
that matters: `screentimenext.session.end` reconciles (the shield goes up), `session.warn.N` raises
the reminder shield.

A schedule interval must be at least 15 minutes (D-037), so the interval's START is pushed 16
minutes before its end — usually into the past. That is fine and is the point: an interval already
running is a normal state, and all we care about is when it ENDS. It also means a 2-minute session
gets a working end alarm, which a usage threshold never could.

The daily budget keeps its threshold, because that one genuinely is a usage question.

**Consequences.**
- Alarms are re-set whenever the session changes — start, extend, end — through a new
  `.sessionDidChange` notification. A parent's settings and a child's session change for different
  reasons and now have different signals.
- Stale alarms are cleared before new ones are set: a name left behind counts against the
  20-activity limit forever, and would fire a shield over a child who has their device back.
- Seconds are included in the schedule's `DateComponents`; dropping them would make "time's up"
  arrive up to a minute late.
- **The lesson:** the API's unit was not the product's unit. "Fires when they have used 12 minutes"
  and "fires at 8:12pm" are different sentences, and I built three features on the assumption that
  they were the same one.

## D-048 — The shield preview shows what iOS actually draws
**Date:** 2026-09-07 · **Status:** accepted · corrects D-012's preview

**Context.** Dominic put the real shield beside the dashboard's preview and said they look nothing
alike. They cannot look alike, and that was my error, not a bug: **iOS draws the shield.** A
`ShieldConfiguration` gives us exactly five things — an icon, a title, a subtitle, a primary button
with a background colour, and a secondary button with up to three submenu items — and nothing else.
No mascot beside the text, no gradient, no layout, no typography, no animation.

The preview had all of those. It was the most polished screen in the app and every polished part of
it was unshippable.

**Decision.** The preview mirrors the system's layout: one centred column on a blur — icon, title,
subtitle, buttons — with no decoration of its own. Pip appears only where he genuinely can: **as
the icon**, because `ShieldConfiguration.icon` is a `UIImage` and we supply it. The primary button's
fill is flat, because `primaryButtonBackgroundColor` is a single `UIColor`; the finish's rainbow
gradient lived in the preview and could never have reached a child.

**Consequences.**
- This screen's whole job is to be accurate — it exists so a parent can show their child what will
  happen. A preview that flatters the design at the cost of being wrong is worse than none.
- Rendering Pip into the icon for the REAL shield (via `ImageRenderer`) is now the obvious next
  step, and the preview finally says truthfully what that would look like.

## D-049 — Name the options on the shield, and record what the child was shown
**Date:** 2026-09-07 · **Status:** accepted · fixes D-044's chooser

**Context.** Dominic reported that the transition screen appeared with no way to choose what's next.

**What the docs say, checked rather than assumed.** `secondaryButtonSubmenuItems` is a **menu**, not
a list on the screen: *"The submenu appears when tapping the secondary button."* So the three
activities were there — behind a button — and a child looking at the shield saw a time and two
buttons with no sign that anything could be chosen. Options a child cannot see are options a child
does not have.

**Decision.** Name them in the subtitle: *"LEGO, Outside or Snack — which one? Tap 'What's next?'
to pick, then keep playing."* The button is now the short label the sentence points at. The choice
still lives in the system menu, because that is the only list a shield can show, but the child
learns it exists from the screen itself.

**The second half, and the more important one.** The shield is drawn in a **third process** —
neither the app nor the monitor extension — and nothing could see into it. "The reminder fired" and
"the child saw the chooser" were two different claims and only the first was checkable, which is
why this took a round trip to diagnose at all.

The shield configuration extension now records which of the three it rendered, into the same
journal (§16-safe: a moment name and a time, never a token or an app). The dashboard reads it back
as "Your child saw: pick what's next". A process we cannot observe is a process we can only guess
about, and this session has already shown what guessing costs.

**Consequences.** If the subtitle turns out not to have been the problem, the journal now says so
directly instead of costing another round of speculation — which is the reason to build it either
way.

## D-050 — The clock stops while a transition screen is up, and the last ask insists
**Date:** 2026-09-07 · **Status:** accepted · extends D-044/D-049

**Three changes Dominic asked for, and the reasoning that shaped each.**

**1. The shield pauses the timer.** A child who cannot use the device is not spending screen time,
so charging them for our own interruption is simply wrong. `SessionWindow` gains `pausedSeconds`,
kept apart from `budgetSecondsAtStart` and from a parent's extension so all three stay answerable
separately: what the budget paid for, what a parent granted, and what the child was never charged
for.

**Capped at ten minutes.** An uncapped pause would let a session interrupted at 8pm still be
running at midnight, which is not what any parent meant by "fifteen minutes". A child who walks away
with the shield up has not been robbed of anything.

**Where it happens is the interesting part.** The shield action extension has no `DeviceActivity`,
so it can move the window but not the alarms. Rather than link four more files into it, the end
alarm now *asks a question instead of assuming an answer*: when it fires and finds time remaining,
it re-arms itself from the new end. An alarm that is early is self-correcting; a missing one ends a
session in silence.

**2. The chooser appears from the FIRST reminder.** D-044 asked only on the last one, so a child who
wanted to decide early could not, and one who missed that single screen was never asked. Asking
early is also the gentler version: the choice arrives while there is still time to enjoy making it.
A child who has already chosen gets a plain reminder — re-asking reads as "that wasn't good enough".

**3. The last ask has no "Not yet".** Its primary button says *"Pick one first 👆"* and does
nothing, so the submenu is the only way back into the app. There is still a real way out — the Home
Screen — and that is not ours to block. What we refuse is a way to carry on *without deciding*.

## D-051 — Pip on the real shield, rendered by the app
**Date:** 2026-09-07 · **Status:** accepted · completes D-048

**Context.** D-048 established that iOS draws the shield and gives us five slots. One of them is
`icon`, and it is a `UIImage` — which means the picture is genuinely ours, even though nothing
around it is.

**The obstacle.** The shield is drawn in an extension with none of our SwiftUI views and a few
milliseconds to answer. `ImageRenderer` needs a real view, and rendering one there would be both
impossible and too slow.

**Decision.** The APP renders Pip — once per `ShieldUrgency`, in that moment's colour and with that
moment's expression — into the App Group as PNGs. The shield extension loads a file. Nothing is
rendered twice, nothing is rendered in a process that cannot afford it, and the mascot a parent sees
in the preview is byte-for-byte the one their child meets.

Re-rendered only when a hand-bumped `version` changes or a file is missing: producing five identical
images on every launch is work for nothing. The SF Symbol stays as the fallback rather than being
deleted — an icon that fails to load must not leave a child looking at a shield with a hole in it.

**Consequences.** The colour and face already differ per moment (D-018), so this is what makes that
design finally reach the child: green and playing at the first reminder, red and excited at the
last, cheering at the finish.

## D-052 — The dashboard becomes the parent's one screen
**Date:** 2026-09-07 · **Status:** accepted · supersedes part of D-039, narrows D-029

**Context.** The dashboard had grown two panels that existed for us rather than for the parent:
*Preview the transition screen* and *Enforcement*. The preview was the one D-048 already convicted
of lying — it drew a screen we do not control. Enforcement printed the monitor's internal state,
which was a debugging aid I needed while the extensions were invisible, not something a parent has
any use for. Meanwhile the thing a parent actually reaches for mid-session — what's next — lived two
taps deep in Settings.

**Decision.** Five changes, all pulling the same way: the dashboard is where a parent acts, and
Settings is where they configure.

**1. The preview and Enforcement panels are gone.** `ShieldPreview/` is deleted; the only survivor
is `ShieldIconRenderer`, moved to `ScreenTime/Shielding/` where the thing it feeds lives.

**2. What's next moves to the dashboard**, as tappable toggles over the family's list. Settings
keeps only the editing a parent does once — add, rename, remove, reorder.

**3. The built-in eight become five**: Family Time, Outside, Clean up, Meal time, Sleep. Eight was
our guess; five is the list Dominic's family uses. Short enough to read at a glance, and still more
than the shield's three-item menu can show, so the menu stays a choice rather than the whole list.
The three surviving ids are unchanged; a window that stored a retired id decodes as a readable
placeholder rather than losing the child's choice.

**4. Extend counts from now, not from the expired end, and can subtract.** Default 3 minutes.
`SessionController.adjust(bySeconds:)` adds to `max(now, endsAt)`, so "+3" ten minutes after time
ran out means three minutes from this moment — which is what a parent standing there means. The
same control takes time back. Never below `now`: a session cannot end in the past.

**5. Free time is a switch, not a button, and it is dead while the clock runs.** It clears every
restriction for the rest of the day, and it is greyed out until the budget is spent — so it can
only ever be a decision made at the end, never a way to skip the middle.

**Consequences.** `ScreenTimeConfiguration.selectedActivities` and every stored `TransitionActivity`
keep working untouched; only the offered list shrank. Reversing (3) means restoring the statics —
the ids were never reused, so nothing would collide. (4) makes `endsAt` the single source of truth
for "when does this end", which the wall-clock alarms of D-050 already assumed.

## D-053 — The ratchet let go of a window that had moved
**Date:** 2026-09-07 · **Status:** accepted · fixes D-052, revises D-050

**Context.** Device test: a parent adds three minutes to a finished session. The child's timer goes
on saying Time's Up, and the Dynamic Island shows either the wrong number or nothing at all.

**Three separate causes, all of them the same mistake — trusting a remembered answer over the fact
it was derived from.**

**1. The state latch (`SessionController`).** `WarningStateEngine.next` is a ratchet: it refuses to
move a session backward, which is what stops clock jitter flipping a child between "5 minutes left"
and "1 minute left". `.finished` is the top of that ratchet. But moving the window's END is not
jitter, and every `SessionController` keeps its OWN latch in memory — the dashboard's and the
timer's are different objects over one storage, so the dashboard recovering told the timer nothing.
Fixed by remembering the `endsAt` each latch was derived from: when the end moves, re-derive from
scratch. The ratchet still holds second to second, and lets go the moment the fact under it changes.
This covers the paused clock (D-050) for free, which moves the end for the same reason.

**2. `Activity.end` is one-way (`LiveActivityPresenter`).** D-021 ends the Live Activity when the
session finishes and lets iOS retire the card ten minutes later. During those ten minutes the
activity is still in `Activity.activities` — and `update()` on it is a **silent no-op**. So adding
time updated a card that had stopped listening. Now only an `.active` activity is updated; anything
else is retired immediately and replaced with a fresh one.

**3. `ClosedRange` traps (`ScreenTimeActivityAttributes`).** The widget renders
`Text(timerInterval: startedAt...endsAt)`. A range whose lower bound is above its upper bound is a
crash, and a crash in a widget extension is not an error message — it is a Dynamic Island with
nothing in it. `timerRange` clamps it once, in the state, rather than being trusted five times in
the layout. `adjust` also refuses to move `endsAt` before now, so both ends of that are closed.

**Also decided, from the same round of device use:**

**What's next goes back to Settings.** D-052 moved the ticks to the dashboard. That was wrong twice:
choosing which activities are offered is configuration done once, not a weekly decision, and a
tappable list beside the ring turned the evening screen into a settings page. The dashboard now
SHOWS the answer — the offered list, in order, with the first three marked as the ones a system
shield can fit — and Settings owns the choosing, beside the same rows a parent renames and reorders.

**Sleep becomes Free time**, and the built-in order is Family Time, Outside, Free time, Clean up,
Meal time. The order is not cosmetic: a shield shows three and takes them off the front. Free time
also gives a child who does not want to commit to a specific plan something true to pick, which
matters more now that the last transition screen insists on an answer.

**The second transition screen insists.** `mustChoose` was "is this the last reminder". It is now
"is this anything but the first". The first ask is an invitation; a child who let it go by has
already had the gentle version.

**Free time became a slide, and lost the name.** "Free time" is an activity now, so the control that
clears every restriction is labelled by what is true: *App restriction applied* in orange, *App
restriction removed* in green, with the destination colour and words revealed under the thumb as it
travels. Slide rather than switch because one stray tap should not unblock a child's whole device —
the deliberate drag IS the confirmation, which is why there is no sheet behind it.

**Consequences.** `lastWindowEnd` makes `SessionController` state derivable from storage alone,
which is what let two controllers stop disagreeing; any future in-memory latch has to answer the
same question. `timerRange` is now the only thing the widget may pass to a timer view.

## D-054 — The PIN is the parent's, and the enforcement log comes back
**Date:** 2026-09-07 · **Status:** accepted · reverses D-031's erase rule, partly reverses D-052

**1. "Start over" no longer erases the parent PIN.**

D-031 put the PIN in `eraseAll()` on the reasoning that a forgotten PIN surviving a reset would
lock a parent out with no way back. That protection was never real: **Start over sits behind the
gate**, so a parent who can reach it already knows the PIN. What the rule actually did was collide
with D-036 — which will not open the timer without a PIN — so every Start over demanded a new one.
A parent reported exactly that. The PIN now sits on the same side of the line as
`pickerPreferences`: the parent's own things, not the child's setup. Changing it is one row in
Settings for anyone who wants to.

**2. The enforcement log returns, in Settings.**

D-052 deleted the dashboard's Enforcement panel, and deleting it from the dashboard was right — a
parent has no use for the monitor's internal state. Deleting it outright was wrong, and the cost
arrived within a day: a transition screen misbehaved and the only evidence about it was
unreachable.

The monitor extension, the shield's configuration extension and the shield's action extension each
run in their own process, woken for a moment, with no console, no breakpoint, and no way to be
asked anything afterwards. `MonitorJournal` is the only record that exists — in particular the four
`shieldShown…` events, which are the difference between "the reminder fired" and "the child saw the
reminder", and whose ABSENCE is itself the finding: no line means iOS never asked us and drew its
own "Restricted" screen instead.

So the readout lives in Settings now, collapsed behind a disclosure. Out of a parent's way, one tap
from the person debugging it.

**The general rule this is the second instance of.** An invisible process cannot be reasoned about,
only instrumented — and its instrument is part of the feature, not scaffolding to tidy away once it
works. Removing one is removing the ability to answer the next question.

<!-- Template for new entries:

## D-NNN — <short imperative title>
**Date:** YYYY-MM-DD · **Status:** proposed | accepted | superseded by D-NNN

**Context.** What forced a choice.

**Decision.** What was chosen.

**Consequences.** What this now constrains, and what would have to change to reverse it.

-->
