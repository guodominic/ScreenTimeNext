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

**Current state (2026-09-05).** No paid Apple Developer Program membership, by decision: D-007
puts the $99 behind a validation gate at the end of Phase 0. Nothing here is actionable until
that gate passes. No company is required — an individual account's Account Holder can request
it. Full material package, paste-ready form answers and the ordered checklist are in
`docs/entitlement-request.md`.

**Free-account limits that apply until then:** no Family Controls, no App Groups, 3 devices,
10 App IDs, 7-day expiry (reinstall from Xcode weekly).

**Required manual steps, in order.**
1. Enroll in the Apple Developer Program as an individual ($99/yr) **via the Apple Developer app on
   iPhone/iPad** — that route is an App Store subscription, so a refund goes through
   reportaproblem.apple.com rather than Apple's discretionary process (there is no advertised refund
   window). Turn auto-renew off afterwards. ID verification is usually within 48 h.
   The **development** entitlement is available the moment the membership is active — Tasks 004,
   005, 010, 011, 012 can all be built and device-tested without waiting for Apple's review of the
   distribution request.
2. Push the repository to GitHub (used as the "developer website").
3. Register two App IDs + one App Group ID (`docs/entitlement-request.md` §三).
4. Create the App Store Connect record; point its privacy policy URL at `PRIVACY.md`.
5. Submit the distribution request **four times** — main app, DeviceActivityMonitor,
   ShieldConfiguration and ShieldAction extensions (the last two are the D-012 transition
   interstitial, the mechanism that actually makes a child stop and look).
6. Record submission date and case ID below; check Capability Requests weekly.

**Meanwhile.** Tasks 001–003, 006–009, 014, 015 need no entitlement; Tasks 004–013 can proceed on
a physical device with the development entitlement. Remember §22: the experience half alone is a
prototype.

**Enrollment date:** —
**Request submitted (main app):** —
**Request submitted (extension):** —
**Response date:** —

---

## B-002 — App Groups capability (needs the paid membership)
**Status:** open — behind the D-007 gate · **Owner:** Dominic · **Raised:** 2026-09-04 · **Blocks:** 006 (App Group impl), 012

The App Group identifier is now fixed at `group.io.github.guodominic.screentimenext`
(`Packages/ScreenTimeNextCore/Sources/ScreenTimeNextCore/Constants/AppGroup.swift`), but the
App Groups capability cannot be enabled on a free Personal Team, so the container cannot be
resolved in Phase 0.

**Required manual step.** After the paid membership exists: enable App Groups on the app target
(and the extension target) in Signing & Capabilities with that identifier. Task 006's
`ScreenTimeStorageService` then gets its App Group implementation behind the same protocol.

---

## B-003 — Physical-device testing for the enforcement path
**Status:** open · **Owner:** — · **Raised:** 2026-09-04 · **Blocks:** 010, 012, 013, 017, 020

The simulator does not accrue real Screen Time usage, so DeviceActivity thresholds and ManagedSettings
shielding cannot be verified there. QA-09, QA-10, and QA-11 require a physical device — and must be
tested **with the app force-quit**, since §14 requires enforcement to work with the app closed.

**Required manual step.** Arrange a test device with an appropriate account configuration. Document
the setup so results are reproducible.

---

## B-004 — Time Sensitive Notifications capability
**Status:** RESOLVED 2026-09-06 · **Owner:** Dominic · **Raised:** 2026-09-05 · **Blocks:** notification prominence (D-012)

Warnings are marked `.timeSensitive` in code. iOS honors that only when the target carries the
Time Sensitive Notifications capability, which a free Personal Team cannot add.

**Required manual step.** After the paid membership exists: Signing & Capabilities → + Capability
→ Time Sensitive Notifications on the app target.

**RESOLVED 2026-09-06.** The capability is on the App ID and
`com.apple.developer.usernotifications.time-sensitive` is in the signed entitlements, so
`.timeSensitive` reminders now break through Focus and the scheduled summary for real. Verify on
device: set a Focus, start a short session, and check the reminder still arrives.

---

## B-005 — An app cannot count, or enumerate, the apps inside a category
**Status:** accepted limitation
**Owner:** Apple · **Raised:** 2026-09-06 · **Blocks:** nothing — this is a permanent platform limit

Dominic asked whether the app can show, for a category the parent ticks, how many apps on this
device belong to it. It cannot, and this is by design rather than a missing API.

- `FamilyActivitySelection` returns **opaque tokens**. An Apple Frameworks Engineer states it
  directly: a picker returns application tokens when the user selects specific applications, and
  "There is no way to extract application tokens from a category token."
  (developer.apple.com/forums/thread/726298)
- There is no API to list installed applications at all, so even outside Screen Time the
  denominator is not available.
- An `ActivityCategoryToken` also cannot be constructed from a name — only Apple's
  `FamilyActivityPicker` produces real ones.

**What the app shows instead.** Counts of what the parent *picked* — categories, websites, apps —
which is information the picker does give us, updated live as they tick rows (D-018). If Apple ever
exposes a per-category count, it drops into `SelectionSummary` without touching the UI.

**Required manual step.** None. Do not spend time looking for a workaround; a bundle-ID map built
by hand is explicitly ruled out by PRD §13.

---

## B-006 — Xcode still offers only the Personal Team, which cannot carry the entitlements
**Status:** RESOLVED 2026-09-06
**Owner:** Dominic / Apple · **Raised:** 2026-09-06 · **Blocks:** 004, 005, 010, 011, 012

The membership was approved, but on 2026-09-06 the project's Team dropdown still listed only
"XIACHEN GUO (Personal Team)". Pointing the targets at the new entitlements produced:

```
Cannot create a iOS App Development provisioning profile for "io.github.guodominic.screentimenext".
Personal development teams, including "XIACHEN GUO", do not support the Family Controls
(Development) and Time Sensitive Notifications capabilities.
```

plus four profile errors (App Groups, Family Controls, Time Sensitive Notifications, and the
group.io.github.guodominic.screentimenext group). Refreshing Xcode ▸ Settings ▸ Accounts showed the
account with role **Admin**, but the paid team still did not appear in the project dropdown — a new
membership can take up to a day to reach Xcode after the confirmation email.

`CODE_SIGN_ENTITLEMENTS` was therefore REMOVED again: leaving it in makes the app unbuildable, and a
project that cannot build is worse than one without the entitlement. The entitlements files stay in
`Config/` with the exact steps in `Config/README.md`.

### Update, later the same day — the team is live; Family Controls is not

Signing out and back in made the paid team appear, and it is selected on both targets. The four
`CODE_SIGN_ENTITLEMENTS` lines are restored. Where it stands now, established by bisecting the
entitlements one at a time:

| Entitlement | Result |
|---|---|
| `com.apple.security.application-groups` | **signs cleanly** |
| `com.apple.developer.family-controls` | `The capability associated with "FAMILY_CONTROLS" could not be determined.` |
| `com.apple.developer.usernotifications.time-sensitive` | `…"USERNOTIFICATIONS_TIMESENSITIVE" could not be determined.` |

**App Groups signing on its own is the important fact**: it rules out the team, the App ID, the
certificate and the whole automatic-signing path. Only the two restricted capabilities fail, and
"could not be determined" is Xcode reporting that the portal returned nothing for that capability
key — not a permission refusal.

Already tried, without effect: Try Again; toggling automatic signing off and on; clearing the team
and reselecting it (a full profile re-fetch); enabling Family Controls on the App ID in the portal.
Xcode does now show a **Family Controls (Development)** capability row and the expected warning
("Bundle identifier is using development only version of Family Controls (Development)…"), so it
recognises the entitlement — the portal simply does not confirm it.

**Most likely remaining cause: an unaccepted licence agreement.** A fresh enrolment almost always
has an updated Apple Developer Program License Agreement waiting, and until it is accepted the
portal serves incomplete capability data — basic capabilities resolve, restricted ones do not. This
matches the symptom exactly.

**Required manual step, in order.**
1. developer.apple.com/account — accept any pending agreement banner. Also check
   App Store Connect ▸ Agreements, Tax, and Banking.
2. Confirm the capability is ticked AND SAVED on the identifier `io.github.guodominic.screentimenext`
   itself (Identifiers ▸ that App ID ▸ Capabilities ▸ Family Controls ▸ Save, then confirm the
   modal). Check there is only one identifier with that bundle ID.
3. Back in Xcode: Signing ▸ Try Again.
4. If it still fails, Xcode ▸ Settings ▸ Accounts, remove the Apple ID with `−` and re-add it, then
   delete DerivedData and reopen.
5. If it survives all of that it is an Xcode 27 beta bug: file it at feedbackassistant.apple.com
   with the **Update Signing** report from the Report navigator, which is what the error text asks
   for, and try a release Xcode.

### Update — after re-signing in, and after letting Xcode own the entitlements file

Signing out and back in did not change it. Neither did adding the capability the DOCUMENTED way:
Signing & Capabilities ▸ + Capability ▸ **Family Controls (Development)**. Xcode offered to
"Create Entitlements File", made its own `ScreenTimeNextRelease.entitlements` containing exactly the
same two keys, pointed the Release configuration at it — and produced the identical error.

That is the useful part. It rules out the hand-written entitlements file, the file's location, and
the possibility that Xcode's capability registration needed to happen through the UI. **Every
Xcode-side explanation is now eliminated.** What remains is Apple's side: the portal does not
return the FAMILY_CONTROLS capability for this account, and Xcode reports that as "could not be
determined".

(Xcode's generated file was removed afterwards and both configurations point back at
`Config/ScreenTimeNext.entitlements`. Leaving it would have split Debug and Release across two
entitlements files — a difference that shows up much later as "works in Debug, fails on device".)

### Update — the App ID does carry the capability

Screenshots of the portal settle the remaining doubt. On the App ID configuration page, with **Save
greyed out** (i.e. no unsaved changes — it is committed):

- **Family Controls (Development)** — ticked, marked "Development only."
- **Family Controls App and Website Usage** — ticked
- **Time Sensitive Notifications** — ticked

And under Capability Requests, **Family Controls (Distribution) — No Requests**, which is expected
and irrelevant here: distribution is a separate, reviewed entitlement (see
`docs/entitlement-request.md`), not something development needs.

So the App ID is configured correctly AND Xcode still reports "could not be determined". Every
explanation on both sides is now eliminated except one: **Xcode 27 beta cannot negotiate these two
capabilities with the portal.** App Groups, an older capability, works on the same App ID in the
same session.

**The way around it is manual signing**, which is Apple's own documented fallback in *Configuring
Family Controls*: "If you manually sign your app, enable the Family Controls capability for your
app's App ID … then regenerate your provisioning profile." The App ID half is already done, so what
remains is to generate a development profile on the portal — where the capability demonstrably
exists — and select it in Xcode, bypassing automatic signing's broken negotiation entirely.

**Trying a release Xcode is NOT an option here**: the test devices run iOS 27, and a released Xcode
cannot deploy to a device running an OS newer than it supports. The beta is not a choice.

### RESOLVED — installing a manual profile unstuck automatic signing

Generating **development provisioning profiles by hand** on the portal (Profiles ▸ + ▸ iOS App
Development, one for each of the two App IDs) and double-clicking the downloaded
`.mobileprovision` files fixed it. Their entitlement lists — visible by opening a profile in
Xcode — carried everything:

```
com.apple.developer.family-controls                      true
com.apple.developer.family-controls.app-and-website-usage true
com.apple.developer.usernotifications.time-sensitive     true
com.apple.security.application-groups                    group.io.github.guodominic.screentimenext
```

The twist: **automatic signing was never switched off.** Simply having a valid profile on disk was
enough — with one to read, Xcode stopped failing to "determine" the capabilities and produced a
working managed profile itself. So the bug is narrower than it looked: Xcode 27 beta cannot
NEGOTIATE these capabilities from nothing, but it can recognise them once a profile that contains
them exists locally.

Both targets now sign cleanly. The only remaining message is the expected warning that the bundle
identifier uses Family Controls (Development) and that distribution needs its own request — which
is B-006's successor, not a problem for development.

**If this recurs** (a new machine, a wiped profile directory, a new bundle ID for the extensions in
Tasks 010/011): generate the profile by hand first, double-click it, and leave automatic signing
alone. Do not spend another session on Try Again, account refreshes or capability toggles — all of
those were tried and none of them mattered.

Apple's own documentation confirms the expectation, so this is a fault and not a misunderstanding:
*Configuring Family Controls* says the development capability is available through the Apple
Developer Program and that with automatic signing "Xcode automatically enables Family Controls for
your app's App ID"; only DISTRIBUTION needs the request form. App Groups signing cleanly on the same
App ID proves the mechanism itself works.

Meanwhile `Config/ScreenTimeNext.entitlements` carries App Groups only, so the app builds and runs
and storage is genuinely in the shared container. Both parked keys are in that file's comment,
ready to paste back one at a time.

---

<!-- Template for new entries:

## B-NNN — <short title>
**Status:** open | in progress | resolved | accepted limitation
**Owner:** — · **Raised:** YYYY-MM-DD · **Blocks:** <task numbers>

<What is blocked and why code cannot fix it.>

**Required manual step.** <The concrete human action needed.>

-->
