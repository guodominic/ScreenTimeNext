# Device QA checklist

The QA criteria in §19 that **cannot** be answered by `./scripts/test.sh`, written as steps.
The simulator accrues no real Screen Time usage (B-003), so every one of these needs the phone.

Record the result in `PROGRESS.md` — date, verdict, and anything surprising.

**Before you start**
- Build and run on the device from Xcode.
- Settings ▸ *Enforcement log* (D-054) is the record of what the background processes did. Open it
  after anything involving a shield; screenshot it if something looks wrong.
- §14 means several of these must be re-run **with ScreenTimeNext force-quit** (swipe it away from
  the app switcher). That is not optional polish — it is the case that matters most, because the
  app is normally not running when a child's time runs out.

---

## QA-02 — Authorization failure handled gracefully

1. Settings ▸ Screen Time ▸ turn Screen Time **off** on the device.
2. Launch ScreenTimeNext. → The dashboard shows the access row, not a crash or a blank screen.
3. Tap the request button. → A clear error, no spinner left running.
4. Turn Screen Time back on, reopen the app, tap request again. → Approved, the row disappears.

**Pass** = every state is a sentence a parent could act on. No dead ends.

## QA-03 — Parent can select protected content

1. Settings ▸ *Pick apps and categories*.
2. Tick one whole category (e.g. Entertainment) **and** one individual app (e.g. YouTube), and add
   one website by typing it.
3. Close the picker. → The dashboard's summary counts match what you ticked.

**Pass** = the counts are right and no app or category you did not tick appears.
**Note** the count of apps INSIDE a category is impossible to show (B-005) — "apps picked" means
apps you picked individually. That is not a bug.

## QA-04 — Selection survives relaunch

1. Straight after QA-03, force-quit the app and reopen it.
2. → The same summary. Then **restart the phone** and reopen. → Still the same.

**Pass** = identical counts all three times.

## QA-09 — Time expiration triggers enforcement

Run this one **twice**: once with the app open, once with it force-quit.

1. Set the budget to 16 minutes (the alarm interval minimum is 16, so anything shorter cannot be
   scheduled — D-037), reminders 5 and 1.
2. Start the timer, then open a covered app and use it normally.
3. At 5 minutes left → a transition screen with the chooser. Pick one. Tap through, keep using it.
4. At 1 minute left → a transition screen saying **1 minute left**, with an OK that lets you back in.
5. At 0 → a transition screen that does **not** let you back in.
6. Open Settings ▸ Enforcement log. → Read it top to bottom; the order should be
   `Reminder alarm` → `Child saw: pick what's next` → `Reminder alarm` → `Child saw: minutes left`
   → `Time's up` → `Child saw: screen time finished`.

**Pass** = all three screens appear at the right times, and the log agrees with what you saw.
**A missing `Child saw: …` line is the finding**, not a gap: it means iOS drew its own "Restricted"
screen instead of asking us.

## QA-10 — Shielded without clearing unrelated settings

1. Before starting: set up **something in Apple's own Screen Time** — a Downtime schedule or an App
   Limit on any app.
2. Run QA-09 through to the end so our shield goes up.
3. Settings ▸ Screen Time → your Downtime / App Limit is still exactly as you left it.
4. Slide *App restriction removed* on the dashboard → covered apps open again, and Apple's own
   limits are STILL there.

**Pass** = nothing of Apple's, or of any other parental-control app, was touched. This is Rule 6 and
it is the one that would get the app rejected — or lose a family their own settings.

---

## Already passing automatically — confirm once on the phone

| # | What to do | Looking for |
|---|---|---|
| QA-05 | Set a budget, force-quit, reopen | Same budget |
| QA-06 | Start a timer, background 3 min, reopen | Countdown lost exactly 3 minutes, not more, not less |
| QA-07 | Watch the ring through both reminders | Colour and copy change at the right moments |
| QA-08 | Pick an activity, let the timer finish | Time's Up names the activity the child chose |
| QA-12 | Start a session, restart the phone mid-session | Session still running with the right time left |
| QA-13 | Start a session near midnight | Rolls over without ending the running session |
| QA-14 | Revoke Screen Time access mid-session | App explains it; no silent failure |

---

## Regression checks for the recent fixes

| Fix | How to check |
|---|---|
| D-053 timer | Let time run out, add 3 minutes on the dashboard → both the in-app timer AND the Dynamic Island show 3:00 counting down |
| D-053 take back | Mid-session, take back more minutes than are left → ends at zero, Dynamic Island does not go blank |
| D-053 second ask | Ignore the first transition screen's chooser → the second one must not let you back in without picking |
| D-054 PIN | Set a PIN, Start over, enter the timer → **no** PIN prompt |
