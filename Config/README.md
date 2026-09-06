# Entitlements — staged, not yet switched on

These two files are the Phase 1 entitlements. They are **written and correct**, but the Xcode
project does not point at them yet, because on 2026-09-06 Xcode still offered only the **Personal
Team** for this project, and a Personal Team cannot carry any of them:

```
Cannot create a iOS App Development provisioning profile for "io.github.guodominic.screentimenext".
Personal development teams, including "XIACHEN GUO", do not support the Family Controls
(Development) and Time Sensitive Notifications capabilities.
```

Pointing the project at them before a paid team is selectable makes the app **unbuildable**, so the
build setting was removed again rather than left broken.

## Turning them on

1. In Xcode ▸ project ▸ target ▸ Signing & Capabilities, open the **Team** dropdown. Wait until the
   paid team appears alongside "XIACHEN GUO (Personal Team)" — a fresh membership can take up to a
   day to reach Xcode even after the confirmation email. Select it (on both targets).
2. Add the build setting back to all four configurations:

```
CODE_SIGN_ENTITLEMENTS = Config/ScreenTimeNext.entitlements;          # app, Debug + Release
CODE_SIGN_ENTITLEMENTS = Config/ScreenTimeNextWidgets.entitlements;   # widget, Debug + Release
```

3. Build. Automatic signing registers the App ID capabilities and the App Group on the portal.

## What each key buys

| Key | Task | Without it |
|---|---|---|
| `com.apple.developer.family-controls` | 004, 005, 010, 011 | No authorization, no picker, no shield — the whole enforcement half |
| `com.apple.security.application-groups` | 006 | The extensions run in a separate container and see no configuration |
| `com.apple.developer.usernotifications.time-sensitive` | 016 (B-004) | iOS silently downgrades every reminder to `.active` |

`FileStorageService.shared()` already prefers the App Group and falls back to the app's own
container, copying existing records across once. So the day the entitlement lands, storage moves
without the parent losing their setup — and until then nothing breaks.
