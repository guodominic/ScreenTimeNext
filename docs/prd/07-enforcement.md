# 07 — Enforcement Strategy & Parent Extension

PRD sections: §14 Enforcement Strategy, §15 Parent Extension Flow.
This is the part that makes V1 a product instead of a prototype.

## §14 Enforcement strategy

The daily budget is configured as a **DeviceActivity monitoring threshold**. When the system
reports that the configured threshold has been reached, the `DeviceActivityMonitor` extension
invokes ManagedSettings shielding for the selected content.

**The main app does not need to remain open for the enforcement path to work.**

```text
Parent sets budget
   → ScreenTimeMonitoringService registers a DeviceActivity schedule + threshold
       → (child uses selected apps; system accrues usage)
           → system fires threshold callback into DeviceActivityMonitorExtension
               → extension reads shared state from App Group
                   → ScreenTimeShieldService applies ManagedSettings shield
                       → extension writes ProtectionState = .shielded to App Group
                           → main app reflects it on next foreground
```

### Critical limitation
DeviceActivity extension execution **must not** be treated as a continuous per-second process.
Therefore:
- Warning presentation and exact countdown rendering use **local state / timestamp calculations**,
  and where appropriate **system notification mechanisms**.
- Never architect a feature that requires the extension to be alive at a specific second.
- Never assume the main app is running when a callback fires.

## §15 Parent extension flow

```text
+10 minutes / +20 minutes / Allow Once
   → update local allowance / configuration
       → adjust monitoring as supported by the current SDK
           → remove ONLY ScreenTimeNext-managed shielding
               → resume active state
                   → reapply protection when the extension expires
```

### Non-negotiables for this flow
- Only ScreenTimeNext-managed restrictions are removed. Never clear the whole ManagedSettings store —
  other parental-control software and Apple's own Screen Time settings may coexist on the device.
- Shield/unshield operations must be **idempotent**: applying twice equals applying once.
- Reapplication on expiry must be reliable even if the app was never reopened.
