# Family Controls Entitlement — 申请材料包

状态:**待 Dominic 完成 Apple Developer Program 注册**(2026-09-04)· 对应 `docs/BLOCKERS.md` B-001

> 这份文档是给人看的操作清单 + 可直接粘贴的表单答案。Apple 的表单在登录墙后,字段名可能与下文略有出入 —— 以表单实际显示为准,答案按意思对应即可。

---

## 一、事实核对

- **不需要注册公司。** Apple 官方文档只要求 "your Apple Developer Account Holder must request permission"。个人账户的 Account Holder 就是本人。
- **开发用 entitlement 即时可用**(`com.apple.developer.family-controls.development`),真机调试不受阻。**分发用**(`com.apple.developer.family-controls`)需要人工审批,TestFlight 也需要分发版。
- **每个 Bundle ID 单独申请一次。** Apple 原话:"If your app includes a Screen Time API app extension such as Device Activity Monitor … submit the same request for the extension." ScreenTimeNext 有两个:主 app + DeviceActivityMonitor extension。
- 审批时长:开发者报告从 4 个工作日到数周不等;extension 的申请通常比主 app 快。
- 通过后在 Certificates, Identifiers & Profiles → Capability Requests 里看到 **Assigned** 状态即可。

## 二、顺序清单

| # | 步骤 | 谁 | 备注 |
|---|---|---|---|
| 1 | 加入 Apple Developer Program(个人) | Dominic | 用 Apple Developer app(iPhone/iPad/Mac)注册;需要开启双重认证的 Apple ID、政府签发的带照片证件、$99/年。身份验证通常 48 小时内。 |
| 2 | 决定 GitHub 仓库地址并推送 | Dominic + Claude | 作为"开发者网站"字段。README 已经能独立说明产品。仓库可以 public,里面没有任何密钥。 |
| 3 | 决定 Bundle ID 前缀 | Dominic | 见第三节。定下后我更新 `AppGroup.swift` 和 Task 001。 |
| 4 | 在 Certificates, Identifiers & Profiles 注册两个 App ID | Claude 可用内置浏览器代填,Dominic 确认 | 两个 ID 都勾上 **Family Controls** 和 **App Groups** capability;同时注册 App Group ID。 |
| 5 | 在 App Store Connect 建 app 记录 | 同上 | 不传构建。名称、副标题、隐私政策 URL(指向仓库里的 `PRIVACY.md`)、年龄分级先填上 —— 通过者的经验是"除了构建什么都先填好"。 |
| 6 | 提交表单 ×2 | Claude 代填,**Dominic 点提交** | 表单:https://developer.apple.com/contact/request/family-controls-distribution 。或者走 Capability Requests 页签。 |
| 7 | 记录提交日期到 `BLOCKERS.md` B-001 | Claude | 之后每周查一次状态。10 个工作日无回复可以在 developer forums 发帖并附 case ID。 |
| 8 | 通过后:在两个 App ID 上启用 Family Controls (Distribution),完全重启 Xcode | Dominic | Xcode 自动签名会自动切到分发版。 |

## 三、Bundle ID 建议

没有自有域名时的两种做法(Apple 不验证域名所有权,但用自己控制的命名空间更干净):

| 方案 | 主 app | Extension | App Group |
|---|---|---|---|
| **A · GitHub 命名空间(推荐)** | `io.github.guodominic.screentimenext` | `io.github.guodominic.screentimenext.monitor` | `group.io.github.guodominic.screentimenext` |
| B · 个人名 | `com.xiachenguo.screentimenext` | `com.xiachenguo.screentimenext.monitor` | `group.com.xiachenguo.screentimenext` |

Bundle ID 注册后**不可更改**,而且它与 App Store 展示名无关 —— 所以即便展示名以后改掉 "ScreenTimeNext",Bundle ID 保持不变没有问题。

## 四、表单答案(英文,可直接粘贴)

以下按开发者报告的字段组织。两次提交内容基本相同,只有 Bundle ID 和"这个 Bundle 的角色"一段不同。

### App name
```
ScreenTimeNext
```

### Developer / company website
```
https://github.com/guodominic/ScreenTimeNext
```

### Bundle ID — 第一次提交(主 app)
```
io.github.guodominic.screentimenext
```

### Bundle ID — 第二次提交(extension)
```
io.github.guodominic.screentimenext.monitor
```

### Which Screen Time frameworks does your app use?
```
FamilyControls, DeviceActivity, ManagedSettings
```

### Describe your app and how it uses Family Controls(主 app 用)
```
ScreenTimeNext is a parental control app for iOS and iPadOS that helps a child end
screen time calmly. A parent sets a daily screen-time budget for one child on the
child's own device, selects which apps, categories and web domains the budget applies
to, and the app gives the child a 10-minute, 5-minute and 1-minute warning before the
budget ends. At the 10-minute warning the child chooses what they will do next (for
example drawing, reading or going outside). When the budget is exhausted, the selected
content is shielded until the next day, unless the parent explicitly grants a short
extension.

How each framework is used:

- FamilyControls: to request Screen Time authorization on the child's device, and to
  present Apple's FamilyActivityPicker so the parent can choose the content the budget
  applies to. We persist the resulting FamilyActivitySelection as-is. We do not build
  or maintain any mapping from app names to bundle identifiers, and we never log,
  display or transmit the selection's tokens.

- DeviceActivity: to register a daily monitoring schedule with a usage threshold equal
  to the configured budget. When the system reports the threshold has been reached,
  our DeviceActivityMonitor extension (bundle ID
  io.github.guodominic.screentimenext.monitor, submitted as a separate request) applies
  shielding. The app does not need to be running for enforcement to work.

- ManagedSettings: to shield the parent-selected applications, categories and web
  domains once the budget is exhausted, and to remove that shield when a parent grants
  an extension or when the next day begins. We use a named ManagedSettingsStore owned
  by our app and only ever modify settings we created; we never clear settings written
  by Apple's Screen Time or by other apps.

Data handling: everything is stored locally on the device in an App Group container
shared between the app and its monitor extension. The app has no backend, no account
system, no analytics SDK and no advertising. No usage data, no selection data and no
child information leaves the device. The only child information collected is a first
name, stored locally, so the app can address the child.

Screen Time functionality is the core of the product: without authorization, the
FamilyActivityPicker, DeviceActivity monitoring and ManagedSettings shielding, the app
cannot perform its function.
```

### Describe your app and how it uses Family Controls(extension 用)
```
This bundle is the DeviceActivityMonitor app extension of ScreenTimeNext
(main app bundle ID io.github.guodominic.screentimenext, submitted separately).

ScreenTimeNext is a parental control app that helps a child end screen time calmly:
a parent sets a daily budget for one child on the child's device and selects the
content it applies to; the child receives 10/5/1-minute warnings and chooses a next
activity; when the budget is exhausted the selected content is shielded.

This extension receives the DeviceActivity threshold callback when the configured
daily budget is reached. On that callback it reads the parent's persisted
FamilyActivitySelection and configuration from the shared App Group container and
applies ManagedSettings shielding to that selection, using a named ManagedSettingsStore
owned by our app. It also records the resulting protection state to the App Group so
the main app can reflect it. The extension performs no networking, uses no analytics,
and never logs or transmits selection tokens. It does not modify any settings it did
not create.
```

### 如有"Does your app collect data for advertising or profiling?"一类的问题
```
No. The app has no backend, no analytics, no advertising and no account system.
All data stays on the device.
```

### 如有"Target audience / age range"
```
Parents of children approximately 5 to 12 years old. The parent configures the app;
the child sees only the timer, warnings and activity choice.
```

## 五、常见拒绝原因对照

| Apple 常见拒绝理由 | 我们的应对 |
|---|---|
| Screen Time 不是 app 的核心功能 | 说明最后一段明确指出没有这三个框架 app 无法工作 |
| 用途描述含糊 | 逐框架说明,具体到 named store、threshold、picker |
| 漏了 extension 的 Bundle ID | 两次提交,互相引用对方的 Bundle ID |
| 数据用于广告/画像 | 无后端、无分析、无广告,写进说明 |
| 网站空白或无法访问 | GitHub README 已能独立说明产品和隐私 |

## 六、提交后

- 提交日期、case ID(如有)记到 `docs/BLOCKERS.md` B-001。
- 状态查询:Certificates, Identifiers & Profiles → Capability Requests → 搜 "Family Controls"。
- 期间不被卡的工作:Task 001–003、006–009、014、015(不需要分发 entitlement),以及用**开发** entitlement 在真机上做 Task 004–013。

## 来源

- Apple — [Requesting the Family Controls entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)
- Apple — [Program enrollment](https://developer.apple.com/help/account/membership/program-enrollment/)
- Itsuki — [Take Family Control To Production/Distribution](https://medium.com/@itsuki.enjoy/swift-ios-take-family-control-to-production-distribution-83da9b3346c6)(一次一个 Bundle ID、4 个工作日、GitHub 当网站)
- Newly — [How to Get the Apple Family Controls Entitlement](https://newly.app/how-to/family-controls-entitlement)(拒绝原因)
- Apple Forums — [Family Controls Request Form](https://developer.apple.com/forums/thread/735888)(TestFlight 同样需要分发版)
