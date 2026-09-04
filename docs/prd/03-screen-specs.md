# 03 — Screen Specifications

PRD section: §6.1–§6.16. This is the reference for **copy, defaults, and controls** on every screen.

---

## Parent onboarding

### §6.1 Welcome
- **Headline:** "Make screen time end peacefully."
- Explain that ScreenTimeNext helps a child move from screen time to what's next.
- **CTA:** "Get Started"

### §6.2 Child Profile
- Single-child setup in V1.
- Ask for the child's **first name only**.
- Keep it lightweight — no age, no avatar, no account.

### §6.3 Family Controls Permission
Explain **why** authorization is required, in three plain-language points:
1. monitor selected content
2. warn before time ends
3. enforce the end

Then trigger the current SDK-supported `AuthorizationCenter` request.

### §6.4 App Selection
- Use Apple's `FamilyActivityPicker`.
- Parent selects **applications, categories, and supported web domains**.
- Persist the Apple `FamilyActivitySelection`.
- **Do not build a manual app database** mapping app names to bundle IDs.

### §6.5 Daily Budget
- **Default: 60 minutes.**
- Presets: **15, 30, 45, 60, 90, 120** minutes.

### §6.6 Warning Settings
- Defaults: **10 min, 5 min, 1 min — all enabled.**
- Each is independently toggleable.
- Keep the default experience simple; do not add custom warning intervals in V1.

### §6.7 What's Next
Parent chooses preferred transition activities from a fixed set:

`LEGO` · `Drawing` · `Reading` · `Outside` · `Snack` · `Bath` · `Homework` · `Family Time`

### §6.8 Ready
- Show the child's name and the configured daily budget.
- Explain that the app will provide gentle warnings before time ends.

---

## Parent runtime

### §6.9 Parent Dashboard
Displays:
- today's budget
- remaining time
- protection status (`unshielded` / `shielded` / `temporarilyExtended`)
- selected content (summary — never raw tokens)
- selected transition activities

### §6.16 Parent Extension
- Offers **+10 minutes**, **+20 minutes**, and **Allow Once**.
- Extension must **only** modify ScreenTimeNext-managed protection and monitoring state.

---

## Child runtime

### §6.10 Child Timer
- Large remaining-time display, minimal controls, friendly language, state-driven UI.
- Countdown **must** be derived from absolute timestamps, never from a `Timer` object as the
  source of truth.

### §6.11 Ten-Minute Warning
> "10 minutes left 👋 You're almost done. What do you want to do next?"

Child selects an activity here (from the parent-approved set in §6.7).

### §6.12 Five-Minute Warning
Show the selected activity and encourage finishing the current activity.

### §6.13 One-Minute Warning
> "One more minute! Finish your game."

Show a simple `01:00` countdown.

### §6.14 Time's Up
> "Screen time is finished ❤️"

Plus the child-selected next activity, e.g. "You chose LEGO. Let's go build!"

### §6.15 Shield State
When a selected app is opened after time is exhausted, present the system shielding experience
where applicable. The app's own experience should frame the event as **transition, not punishment**.
