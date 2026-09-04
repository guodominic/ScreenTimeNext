# 06 — Data Model & Persistence

PRD sections: §12 Data Model, §13 Persistence.

## §12 Data model

### ChildProfile
| Field | Type |
|---|---|
| `id` | `UUID` |
| `name` | `String` |

### ScreenTimeConfiguration
| Field | Type |
|---|---|
| `dailyBudgetSeconds` | `Int` |
| `warning10Enabled` | `Bool` |
| `warning5Enabled` | `Bool` |
| `warning1Enabled` | `Bool` |
| `selectedActivities` | `[TransitionActivity]` |

### DailyUsage
| Field | Type |
|---|---|
| `date` | `Date` |
| `budgetSeconds` | `Int` |
| `usedSeconds` | `Int` |

### TransitionActivity
Fixed set: `LEGO`, `Drawing`, `Reading`, `Outside`, `Snack`, `Bath`, `Homework`, `Family Time`

### ScreenTimeState
`idle`, `active`, `warning10`, `warning5`, `warning1`, `finished`, `extended`

### ProtectionState
`unshielded`, `shielded`, `temporarilyExtended`

> **Note:** §11's state machine names a `shielded` state; §12's `ScreenTimeState` enum does not
> include it, because shielding is tracked separately in `ProtectionState`. Session state and
> protection state are two axes — keep them separate. See `docs/DECISIONS.md` D-002.

## §13 Persistence
- Use an **App Group shared container** for state that must be reachable by both the main app and
  the extension.
- A dedicated storage abstraction (`ScreenTimeStorageService`) hides the persistence mechanism.
- The Apple `FamilyActivitySelection` remains the **source of truth for selected content**.
- **Do not** replace privacy-preserving Apple tokens with invented app-name identifiers.
- **Do not** build a manual database mapping arbitrary app names to bundle IDs.

## What must survive a relaunch / restart
- Child profile
- Screen time configuration (budget, warning toggles, activities)
- Persisted `FamilyActivitySelection`
- Today's `DailyUsage`
- Current `ProtectionState` and any active extension window

## What must NOT be persisted or logged
- Raw FamilyActivity tokens in logs (see §16)
- Detailed app-usage history intended for a server
