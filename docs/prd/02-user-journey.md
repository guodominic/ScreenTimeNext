# 02 — Core User Journey

PRD section: §5.

## End-to-end flow

```text
PARENT SETUP
  Welcome
    → Child profile
    → Family Controls authorization
    → Content selection (FamilyActivityPicker)
    → Daily budget
    → Warning settings
    → Transition activities ("What's Next")
    → Ready

CHILD SESSION
  Child starts screen time
    → 10-minute warning   (child picks next activity)
    → 5-minute warning    (shows chosen activity)
    → 1-minute warning    (simple 01:00 countdown)
    → time expires
    → selected content is SHIELDED
    → child is directed to the chosen next activity

PARENT OVERRIDE (optional, any time after expiry)
  Parent may temporarily extend time  (+10 / +20 / Allow Once)
    → shielding lifted for Transition-managed content only
    → protection reapplied when the extension expires
```

## Mapping to screens and tasks

| Journey step | Screen spec | Task |
|---|---|---|
| Welcome | §6.1 | 003 |
| Child profile | §6.2 | 003 |
| Authorization | §6.3 | 003 (mock) → 004 (real) |
| Content selection | §6.4 | 003 (mock) → 005 (real) |
| Daily budget | §6.5 | 003 → 006 |
| Warning settings | §6.6 | 003 → 008 |
| What's Next | §6.7 | 003 → 009 |
| Ready | §6.8 | 003 |
| Parent dashboard | §6.9 | 014 |
| Child timer | §6.10 | 007 |
| 10/5/1 warnings | §6.11–§6.13 | 007 + 008 |
| Time's Up | §6.14 | 015 |
| Shield state | §6.15 | 011 + 012 |
| Parent extension | §6.16 | 013 |
