# 08 — Privacy, Security & App Store Readiness

PRD sections: §16 Privacy & Data Principles, §17 Security / Bypass Considerations,
§18 App Store / Entitlement Readiness.

## §16 Privacy & data principles
- **No backend required for V1.**
- Do not collect child identity beyond the minimum local profile (first name).
- Do not send detailed app-usage history to a server.
- **Do not log sensitive FamilyActivity tokens.**
- Keep Screen Time data local unless a future feature explicitly requires synchronization.
- Document App Group and Apple Screen Time API usage in project privacy documentation
  (`PRIVACY.md`, produced by Task 018).

## §17 Security / bypass considerations

V1 must be tested against:
- app termination
- device restart
- authorization revocation
- configuration changes
- **date/time changes** (child moving the clock)
- child attempts to reopen protected content

> **Honesty constraint:** the product must **not** claim to block every possible device-level
> bypass unless Apple's platform actually provides that capability. Marketing copy and in-app
> copy must both respect this.

## §18 App Store / entitlement readiness

Family Controls distribution requires the appropriate **Apple entitlement and approval process**.

Actions:
- Request the required entitlement **as early as possible** — this is a calendar-time dependency,
  not an engineering task, and it is the single largest schedule risk in V1.
- Maintain documentation explaining the legitimate parental-control purpose and how
  FamilyControls, DeviceActivity, and ManagedSettings are each used.
- Verify exact entitlement names, SDK APIs, and review requirements against **current Apple
  developer documentation** before submission. Do not rely on this document or on tutorials.

Track status in `docs/BLOCKERS.md`.
