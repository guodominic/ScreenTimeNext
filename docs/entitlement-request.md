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

## 一点五、关于退款和注册方式(2026-09-05 核实)

**Apple 没有公开承诺的退款窗口。** 费用页面只讲付款和税,不提退款条件;实际是个案裁量,走
Developer Support,2–3 个工作日答复,批不批看账号年龄和理由。欧盟/英国的 14 天法定撤回权对
纽约不适用。

**因此:用 iPhone/iPad 上的 Apple Developer app 注册,不要用网页。** app 注册产生的是一笔
**App Store 自动续订订阅**,退款走 `reportaproblem.apple.com` 的常规流程,比人工裁量宽松得多。
注册完成后到订阅设置里**关掉自动续订**,否则一年后会再扣 $99。

**真正的风险控制是顺序,不是退款。** 开发用 entitlement 在付费当天即时可用(Apple DTS 确认:
capability 只对付费团队显示,付费后即可开发调试)。这意味着几天内就能在自己设备上回答项目最大的
未知数 —— DeviceActivity 回调是否可靠、D-012 的过渡插页在真实 app 里是什么效果、孩子的反应如何。
上架用的分发 entitlement 要等几周,但**不需要它就能拿到上面全部答案**。

## 二、顺序清单

| # | 步骤 | 谁 | 备注 |
|---|---|---|---|
| 1 | 加入 Apple Developer Program(个人) | Dominic | **用 iPhone/iPad 上的 Apple Developer app 注册**(退款路径更好,见上节);需要开启双重认证的 Apple ID、政府签发的带照片证件、$99/年。身份验证通常 48 小时内。完成后关掉自动续订。 |
| 2 | 决定 GitHub 仓库地址并推送 | Dominic + Claude | 作为"开发者网站"字段。README 已经能独立说明产品。仓库可以 public,里面没有任何密钥。 |
| 3 | 决定 Bundle ID 前缀 | Dominic | 见第三节。定下后我更新 `AppGroup.swift` 和 Task 001。 |
| 4 | 在 Certificates, Identifiers & Profiles 注册两个 App ID | Claude 可用内置浏览器代填,Dominic 确认 | 两个 ID 都勾上 **Family Controls** 和 **App Groups** capability;同时注册 App Group ID。 |
| 5 | 在 App Store Connect 建 app 记录 | 同上 | 不传构建。名称、副标题、隐私政策 URL(指向仓库里的 `PRIVACY.md`)、年龄分级先填上 —— 通过者的经验是"除了构建什么都先填好"。 |
| 6 | 提交表单 ×2 | Claude 代填,**Dominic 点提交** | 表单:https://developer.apple.com/contact/request/family-controls-distribution 。或者走 Capability Requests 页签。 |
| 7 | 记录提交日期到 `BLOCKERS.md` B-001 | Claude | 之后每周查一次状态。10 个工作日无回复可以在 developer forums 发帖并附 case ID。 |
| 8 | 通过后:在两个 App ID 上启用 Family Controls (Distribution),完全重启 Xcode | Dominic | Xcode 自动签名会自动切到分发版。 |

## 三、Bundle ID 建议

没有自有域名时的两种做法(Apple 不验证域名所有权,但用自己控制的命名空间更干净):

已确定(工程里已在用):

| 用途 | Bundle ID |
|---|---|
| 主 app | `io.github.guodominic.screentimenext` |
| DeviceActivityMonitor extension | `io.github.guodominic.screentimenext.monitor` |
| ShieldConfiguration extension(D-012 过渡插页) | `io.github.guodominic.screentimenext.shieldconfig` |
| ShieldAction extension(插页按钮的响应) | `io.github.guodominic.screentimenext.shieldaction` |
| App Group | `group.io.github.guodominic.screentimenext` |
| Widget(Live Activity,**不需要** entitlement) | `io.github.guodominic.screentimenext.ScreenTimeNextWidgets` |

**Screen Time 的四个 bundle ID 各要提交一次申请**(Apple:"submit the same request for the
extension")。Widget 不涉及 Screen Time API,不用申请。

**核对过 2026-09-08**:以上四个是 `project.pbxproj` 里真实的 `PRODUCT_BUNDLE_IDENTIFIER`。
这份文档原本写的是 `.monitor` / `.shieldconfig` / `.shieldaction` —— 那是当初的**计划**,
不是 Xcode 建 target 时实际生成的名字。照旧稿提交会申请到三个不存在的 Bundle ID:
批下来也是白批,而重新申请要重新排队。填表前以项目为准,不以文档为准。

Widget(`...ScreenTimeNextWidgets`)不碰 Screen Time API,不要提交。

Bundle ID 注册后**不可更改**,而且它与 App Store 展示名无关 —— 所以即便展示名以后改掉 "ScreenTimeNext",Bundle ID 保持不变没有问题。

## 三点五、表单变了(2026-09-08 实测)

**发布权限现在是发给整个开发者账号的,不是一个 bundle ID 一份。**

developer.apple.com/contact/request/family-controls-distribution 现在只有三个只读字段
(Name / Email / Team ID,自动填好)、一段条款,和一个 **Get Entitlement** 按钮。**没有 bundle ID
字段,没有描述字段** —— 点下去直接就是 "Thank you for your submission"。

表单自己那句话是关键:*"Once assigned to your developer **account**, you can build apps that use
the capabilities of the Family Controls Framework."*

Apple 的文档(`requesting-the-family-controls-entitlement`)仍写着"如果 app 含 Screen Time
extension,为 extension 再提交一次" —— 那是表单还有 bundle ID 字段时的写法。现在没有那个字段,
也就无从分开提交。文档同时确认了账号级:*"adds the entitlement to your developer account using
managed capabilities"*,批准后在 Certificates, Identifiers & Profiles 里显示 **Assigned**。

**所以:提交一次,四个 target 一起覆盖。** 下面第四节那些答案不再需要填进这个表单 ——
但**不要删**:那正是上架送审时 App Review Information → Notes 要写的东西,审核的人问的是同样的
问题。见 §六。

## 四、产品说明(原为表单答案;现用于 App Review Notes)

以下按开发者报告的字段组织。两次提交内容基本相同,只有 Bundle ID 和"这个 Bundle 的角色"一段不同。

### App name
```
ScreenTimeNext
```

### Developer / company website
```
https://github.com/guodominic/ScreenTimeNext
```

### Bundle ID — 四次提交,每次填一个
```
io.github.guodominic.screentimenext                                ← 第 1 次(主 app)
io.github.guodominic.screentimenext.DeviceActivityMonitorExtension ← 第 2 次(DeviceActivityMonitor)
io.github.guodominic.screentimenext.ShieldConfigurationExtension   ← 第 3 次(ShieldConfiguration)
io.github.guodominic.screentimenext.ShieldActionExtension          ← 第 4 次(ShieldAction)
```

### Which Screen Time frameworks does your app use?
```
FamilyControls, DeviceActivity, ManagedSettings
```

### Describe your app and how it uses Family Controls(主 app 用)

**重写于 2026-09-08,对照当前代码逐条核对过。** 旧稿写的是 10/5/1 三个提醒、在 10 分钟提醒
时选活动、活动是 drawing/reading —— 全部已经不成立。申请描述与实际行为不符是明确的拒绝原因。

```
ScreenTimeNext is a parental control app for iOS and iPadOS that helps a child end screen
time calmly.

A parent sets a session budget (1 to 90 minutes, 15 by default) for one child on the
child's own device, and selects which apps, categories and web domains it applies to.
Two reminders arrive before the end — 5 minutes and 1 minute by default. Each reminder is
a full-screen shield on the covered app, not a notification: the child sees how much time
is left, and, until they have chosen, a menu of what they will do next (for example Family
Time, Outside, Free time, Clean up or Meal time — a list the parent can edit and reorder).
Choosing returns them to the app for the minutes that remain. When the budget is exhausted
the selected content is shielded until the next day, unless the parent grants an extension
from their own screen.

How each framework is used:

- FamilyControls: to request Screen Time authorization on the child's device, and to
  present Apple's FamilyActivityPicker so the parent can choose the content the budget
  applies to. We persist the resulting FamilyActivitySelection as-is. We do not build or
  maintain any mapping from app names to bundle identifiers, and we never log, display or
  transmit the selection's tokens.

- DeviceActivity: in two ways. A daily monitoring schedule carries a usage threshold equal
  to the configured budget, so the day's total is enforced even if the app never runs. In
  addition, each session registers one non-repeating schedule per moment (each reminder,
  and the end), because a reminder is a wall-clock time rather than an amount of usage.
  Our DeviceActivityMonitor extension (bundle ID
  io.github.guodominic.screentimenext.DeviceActivityMonitorExtension, submitted as a
  separate request) receives these callbacks and raises the shield. The app does not need
  to be running for any of this.

- ManagedSettings: to shield the parent-selected applications, categories and web domains,
  and to remove that shield when a parent grants an extension or the next day begins. We
  also offer the parent a switch that blocks all web browsing while time is up, using
  WebContentSettings.blockedByFilter; it is labelled in the UI and counted in what the
  parent is shown as covered. We use a named ManagedSettingsStore owned by our app, we set
  only the keys we created, and we never call clearAllSettings() — settings written by
  Apple's Screen Time or by other apps are never altered or erased.

Two further extensions draw and answer the shield itself; both are submitted as separate
requests (io.github.guodominic.screentimenext.ShieldConfigurationExtension and
io.github.guodominic.screentimenext.ShieldActionExtension).

Data handling: everything is stored locally in an App Group container shared between the
app and its extensions. The app has no backend, no account system, no analytics SDK and no
advertising. No usage data, no selection data and no child information leaves the device.
The only child information collected is a first name, stored locally, so the app can
address the child by name.

Screen Time functionality is the core of the product: without authorization, the
FamilyActivityPicker, DeviceActivity monitoring and ManagedSettings shielding, the app
cannot perform its function at all.
```

### Describe your app and how it uses Family Controls(第 2 次:DeviceActivityMonitor extension 用)
```
This bundle is the DeviceActivityMonitor app extension of ScreenTimeNext
(main app bundle ID io.github.guodominic.screentimenext, submitted separately).

ScreenTimeNext is a parental control app that helps a child end screen time calmly: a
parent sets a session budget for one child on the child's device and selects the content it
applies to; the child gets two full-screen reminders before the end and chooses what to do
next; when the budget is exhausted the selected content is shielded.

This extension receives the DeviceActivity callbacks: the usage threshold for the day's
budget, and the end of each non-repeating schedule registered for a session moment (each
reminder, and the end of the session). On each callback it reads the parent's persisted
FamilyActivitySelection and configuration from the shared App Group container and applies
or removes ManagedSettings shielding accordingly, using a named ManagedSettingsStore owned
by our app. It also records what it did to the App Group so the main app can reflect it and
so a parent can inspect it.

The extension performs no networking, uses no analytics, and never logs or transmits
selection tokens. It does not modify any settings it did not create, and never calls
clearAllSettings().
```

### Describe your app and how it uses Family Controls(第 3 次:ShieldConfiguration extension 用)
```
This bundle is the ShieldConfiguration extension of ScreenTimeNext
(main app bundle ID io.github.guodominic.screentimenext, submitted separately).

ScreenTimeNext is a parental control app that helps a child end screen time calmly: a
parent sets a session budget for one child on the child's device and selects the content it
applies to; the child gets two full-screen reminders before the end and chooses what to do
next; when the budget is exhausted the selected content is shielded.

This extension supplies the appearance of the shield we place on the parent-selected
content. It reads the session's timestamps and the parent's activity list from the shared
App Group container and returns a ShieldConfiguration: an icon, a title naming how many
minutes are left, a short child-friendly subtitle, and button labels. Where the child has
not yet chosen what to do next, the configuration also carries the parent's first three
activities as secondary-button submenu items.

The application and webDomain values this extension receives are opaque tokens. They are
never read, stored, logged or transmitted: what the screen says depends on the clock and on
the parent's own settings, not on which app was opened. The extension performs no
networking and uses no analytics.
```

### Describe your app and how it uses Family Controls(第 4 次:ShieldAction extension 用)
```
This bundle is the ShieldAction extension of ScreenTimeNext
(main app bundle ID io.github.guodominic.screentimenext, submitted separately).

ScreenTimeNext is a parental control app that helps a child end screen time calmly: a
parent sets a session budget for one child on the child's device and selects the content it
applies to; the child gets two full-screen reminders before the end and chooses what to do
next; when the budget is exhausted the selected content is shielded.

This extension handles the buttons on that shield. At a reminder, choosing an activity from
the menu records the choice to the shared App Group container and lifts our own shield so
the child can use the remaining minutes; the other button closes the app. After the budget
is exhausted, every button closes the app and nothing is lifted — a child can never grant
themselves more time; only a parent can, from their own screen behind a PIN or Face ID.

When it lifts a shield it clears only the four shield keys in the named ManagedSettingsStore
owned by our app; it never calls clearAllSettings(). The tokens it receives are never read,
stored, logged or transmitted. The extension performs no networking and uses no analytics.
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
| 漏了 extension 的 Bundle ID | 四次提交,每次的说明里引用主 app 的 Bundle ID |
| 数据用于广告/画像 | 无后端、无分析、无广告,写进说明 |
| 网站空白或无法访问 | GitHub README 已能独立说明产品和隐私 |

## 六、提交后

- 提交日期记到 `docs/BLOCKERS.md` B-001。
- **状态查询**(路径反直觉,2026-09-08 实测):Capability Requests **不在左侧栏**,它在
  **每个 App ID 自己的页面里** ——
  Certificates, Identifiers & Profiles → **Identifiers** → 点开
  `io.github.guodominic.screentimenext` → 页面上的 **Capability Requests** 标签页 → 点
  **Status** 按钮看详情。批准后显示 **Assigned**;再点 info 按钮确认 Provisioning Support
  列出了你需要的分发方式。需要 Account Holder 角色(个人账号本人即是)。
- **批准后要做的**:如果 Xcode 项目已经有 Family Controls 开发能力且用自动签名,Apple 说
  Xcode 会自动切到分发版。B-006 的经验是这台机器上的自动签名不一定听话 —— 真出问题就照
  B-006 的办法,手动在门户生成一次 profile 再双击。
- 第四节那四段说明现在的用途是**送审时的 App Review Notes**,不是权限表单。
- 期间不被卡的工作:Task 001–003、006–009、014、015(不需要分发 entitlement),以及用**开发** entitlement 在真机上做 Task 004–013。

## 来源

- Apple — [Requesting the Family Controls entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)
- Apple — [Program enrollment](https://developer.apple.com/help/account/membership/program-enrollment/)
- Itsuki — [Take Family Control To Production/Distribution](https://medium.com/@itsuki.enjoy/swift-ios-take-family-control-to-production-distribution-83da9b3346c6)(一次一个 Bundle ID、4 个工作日、GitHub 当网站)
- Newly — [How to Get the Apple Family Controls Entitlement](https://newly.app/how-to/family-controls-entitlement)(拒绝原因)
- Apple Forums — [Family Controls Request Form](https://developer.apple.com/forums/thread/735888)(TestFlight 同样需要分发版)
