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

<!-- Template for new entries:

## D-NNN — <short imperative title>
**Date:** YYYY-MM-DD · **Status:** proposed | accepted | superseded by D-NNN

**Context.** What forced a choice.

**Decision.** What was chosen.

**Consequences.** What this now constrains, and what would have to change to reverse it.

-->
