# ScreenTimeNext

**Screen Time Transition Assistant + Parental Control** · iOS / iPadOS

> Make screen time end peacefully.

## What it does
ScreenTimeNext helps parents set a screen-time budget, select protected content, warn a child before
time expires, guide the child toward a next activity, and enforce the end of selected screen time
using Apple's Screen Time frameworks.

It is not another countdown timer. The product thesis is that a child who **chooses what happens
next** transitions with less conflict — and that enforcement has to be real for a parent to trust it.

## V1 scope
- Family Controls authorization
- `FamilyActivityPicker` content selection — apps, categories and typed websites
- A session budget of 1–90 minutes, set a minute at a time (default 15)
- Two configurable reminders before the end (default 5 and 1 minute)
- Child-selected next activity, offered on the transition screen itself
- DeviceActivity wall-clock monitoring, with the app closed
- ManagedSettings shielding, with a transition screen of our own at each moment
- Parent adjustment of a running session — add or take back minutes (default 3), counted from now
- A slide that clears every restriction for the rest of the day, and puts them back
- Parent gate: a PIN, optionally unlocked with Face ID
- Live Activity / Dynamic Island countdown
- Local persistence via App Group
- **No backend**

Out of scope in V1: multi-child, cross-device, cloud accounts, Android, AI recommendations, social
features, ads, complex scheduling, subscriptions. See `docs/prd/01-vision-and-goals.md` §4.

## What a child actually sees

The shield is the product, so it is worth saying plainly what it does. When a covered app is opened
during a session, iOS draws a screen we configure — up to three times:

1. **A reminder.** "5 minutes left." A button acknowledges it and returns them to the app.
2. **The ask.** "Which one?" — a menu of what the parent put on the list. Choosing returns them to
   the app; on the second ask, choosing is the only way back in.
3. **The end.** The button closes, and does not let them back in. §17 — a child can never grant
   themselves more time; more time comes from a parent, on the parent's device.

The clock stops while a transition screen is up: a child is not charged screen time for our own
interruption.

## Repository layout

```text
CLAUDE.md                 agent instructions + workflow — read first
docs/
├── prd/                  the PRD as readable markdown (READ THIS)
├── architecture.md       condensed architecture reference
├── tasks/
│   ├── PROGRESS.md       project status — read first, update last
│   └── 001…020-*.md      the 20 implementation tasks, in order
├── DECISIONS.md          why things are the way they are
├── BLOCKERS.md           what code cannot fix
├── market-analysis.md    feasibility & market judgement
├── entitlement-request.md  Family Controls entitlement checklist + form answers
└── reference/            the signed .docx PRD, archived
PRIVACY.md                privacy policy (DRAFT until Task 018)
ScreenTimeNext.xcodeproj  Xcode project
ScreenTimeNext/           app target (SwiftUI + Screen Time adapters)
Packages/ScreenTimeNextCore/  framework-free core package + its tests
DeviceActivityMonitorExtension/   wakes on the clock and raises the shield
ShieldConfigurationExtension/     draws the transition screen
ShieldActionExtension/            decides what its buttons do
ScreenTimeNextWidgets/            Live Activity / Dynamic Island
```

Four processes, three of which the app never sees running. `docs/DECISIONS.md` is where the
reasoning lives; `MonitorJournal` (Settings ▸ Enforcement log) is the only evidence they leave.

## Run it on your own iPhone or iPad (preview build)

There is no App Store or TestFlight build yet (see `docs/BLOCKERS.md`). To run the preview you need
a Mac with Xcode 26 or newer and a free Apple ID:

1. Clone this repository and open `ScreenTimeNext.xcodeproj`.
2. Xcode › Settings › Accounts › add your Apple ID (free "Personal Team" is enough).
3. Select the `ScreenTimeNext` target › Signing & Capabilities › choose your Personal Team.
   Do the same for the `ScreenTimeNextWidgetsExtension` target.
4. Plug in your iPhone/iPad, unlock it, trust the computer, and turn on
   Settings › Privacy & Security › Developer Mode (the device restarts).
5. Pick your device at the top of Xcode and press ⌘R. On the device, trust the developer
   certificate under Settings › General › VPN & Device Management the first time.

Free-account limits: the app expires after 7 days (re-run from Xcode), and one Apple ID can install
on at most 3 devices. The preview has no Screen Time enforcement — it is the transition experience
only (timer, reminders, "what's next", Live Activity). Enforcement needs the Family Controls
entitlement, which a free account cannot carry; the **development** entitlement comes with a paid
membership and is enough to run the whole thing on your own device.

## Getting started (contributors)
1. Read `CLAUDE.md`.
2. Read `docs/tasks/PROGRESS.md` to see where the project stands.
3. Check `docs/BLOCKERS.md` before starting anything entitlement-dependent.
4. Open the next task file and implement **only** that task.
5. Build and test, then fill in the task's completion report and update `PROGRESS.md`.

## Definition of Done
V1 is complete only when the app provides a coherent transition experience **and** reliably enforces
the configured limit through Apple's Screen Time APIs, with the app closed.

A polished timer without actual enforcement is a prototype, not the V1 product.

## Important platform note
Family Controls distribution requires the appropriate Apple entitlement and approval. This is
**calendar time, not engineering time** — request it as early as possible and track it in
`docs/BLOCKERS.md` (B-001). Verify current Apple documentation and installed SDK behavior before
implementation or App Store submission.
