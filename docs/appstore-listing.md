# App Store 上架文案 — ScreenTimeNext

Apple ID 6809499502 · SKU SCREENTIMENEXT-001 · Utilities / Productivity · 4+

下面每一段都是**可以直接复制粘贴**的成品。中文是给你看的说明，英文是要填进 App Store Connect 的内容。

---

## 1. App Name（30 字符上限）

```
ScreenTimeNext
```

14 字符。不用改。

---

## 2. Subtitle 副标题（30 字符上限）

```
Make screen time end calmly
```

27 字符。这是搜索会索引的字段，也是用户在搜索结果里看到的第二行。

---

## 3. Promotional Text 推广文本（170 字符上限）

这一栏**不用重新提审就能随时改**，所以以后做活动、上新功能都改这里。

```
The hardest ninety seconds of the day is the moment the tablet goes down. ScreenTimeNext gives that moment a countdown, a warning, and somewhere to go next.
```

154 字符。

---

## 4. Keywords 关键词（100 字符上限）

逗号分隔，**逗号后面不要加空格**（空格算字符，浪费额度）。不要重复 App Name 和 Subtitle 里已有的词（Apple 已经索引了 screen、time、calmly），所以下面一个都没重复。

```
parental,control,kids,child,family,limit,timer,block,apps,routine,transition,focus,bedtime,tantrum
```

98 字符。

---

## 5. Description 描述（4000 字符上限）

```
Screen time doesn't have to end in a fight.

ScreenTimeNext is a parental control app built around the hardest ninety seconds of the day: the moment the tablet has to go down. Instead of an app simply vanishing, your child gets a calm countdown, a warning before the end, and a screen that asks one question — what are we doing next?

HOW IT WORKS

1. You pick what to limit. Apps, categories, or all web browsing — chosen with Apple's own Screen Time picker, so your child's app list never leaves their device.

2. You set the time. Start a session from the dashboard and a countdown begins, with a live timer on the Lock Screen and in the Dynamic Island.

3. Time ends gently. A warning arrives before the end. When time is up, the blocked apps show a transition screen instead of a blank wall.

4. Your child chooses what's next. Family time, outside, free time, clean up, or a meal. Choosing is what closes the screen — so the ending has a destination, not just a stop.

FOR THE PARENT

• One dashboard: how much time is left, what your child chose, and a tap to add or take back minutes
• Add time when it's earned. Taking minutes back also shortens today's budget, so a longer session doesn't quietly become a longer day
• Slide to remove every restriction for the rest of the day — one deliberate gesture, never a stray tap
• Start over whenever the day changes shape

PRIVACY

ScreenTimeNext uses Apple's Screen Time framework. Your child's app selections are handled by iOS as opaque tokens: the app cannot read which apps they are, and never stores, logs, or transmits them. There are no accounts, no servers, and no analytics. Nothing leaves the device.

WHAT YOU NEED

• Screen Time permission, granted once by a parent
• ScreenTimeNext limits the device it is installed on

ScreenTimeNext is not a monitoring tool. It doesn't report where your child goes or what they type. It does one thing: it makes the end of screen time predictable, and gives it somewhere to go.
```

---

## 6. App Review Notes 审核备注

这一栏对我们特别重要 —— 我们用了 Family Controls 分发权限，审核员必须知道怎么测、以及我们没碰任何隐私数据。**照抄：**

```
ScreenTimeNext uses the Family Controls, DeviceActivity and ManagedSettings frameworks under the distribution entitlement granted to this account (com.apple.developer.family-controls).

HOW TO TEST — no account or demo credentials are required.

1. Launch the app. It asks for Screen Time authorization on first run. Approve it. (On a device where Screen Time is managed by a Family Sharing organizer, approval must be given by that organizer.)
2. The app opens a FamilyActivityPicker. Select at least one app or category. Social, Games and Entertainment are pre-selected.
3. Set a duration on the dashboard and start a session. A countdown appears on the dashboard, on the Lock Screen and in the Dynamic Island.
4. Wait for the countdown to reach zero, or use "Take time back" to shorten it.
5. Open one of the selected apps. Our transition screen appears with three activity choices behind the "What's next?" button. Choosing one dismisses the screen; the choice is then shown on the parent dashboard.
6. To clear everything, use the "App restriction applied" slider on the dashboard. It removes all restrictions for the rest of the day.

PRIVACY — WHY WE NEED THE ENTITLEMENT

The app shields only the apps and categories the parent selected, using the opaque ApplicationToken and ActivityCategoryToken values returned by FamilyActivityPicker. Those tokens are never read, decoded, persisted outside the App Group, logged, or transmitted. The app has no server, no account system, no analytics SDK and no network calls of any kind. All state lives in the app's own container and its App Group.

The app cannot grant a child more time than the parent set: every extension of a session is initiated from the parent dashboard inside the app, never from the shield screen the child sees.
```

---

## 7. App Privacy 隐私标签（问卷答案）

在 App Store Connect 里点 **App Privacy → Get Started**，按下面回答：

**"Do you or your third-party partners collect data from this app?"**
→ 选 **No, we do not collect data from this app**

然后它会让你确认三件事，三个都成立：

- 不收集任何数据 ✓（没有服务器、没有账号、没有 analytics）
- 不用第三方 SDK 收集数据 ✓（我们一个第三方依赖都没有）
- 数据不离开设备 ✓

选完直接 Publish。**整个 App 的隐私标签就是 "Data Not Collected"。**

⚠️ 注意：Screen Time 的 token 存在 App Group 里，这**不算** "collect data" —— Apple 的定义是"传输到你或第三方的服务器"。我们没有服务器，所以答 No 是准确的。

---

## 8. 还缺的两样东西（这两个没有就交不了）

### ① Privacy Policy URL（必填，没有不让提交）

仓库里已经有 `PRIVACY.md`。最省事的做法是用 GitHub Pages：

1. GitHub 上建一个 public 仓库，比如 `screentimenext-site`
2. 把 `PRIVACY.md` 改名成 `index.md` 放进去
3. Settings → Pages → Source 选 `main` / `root` → Save
4. 几分钟后拿到 `https://<你的用户名>.github.io/screentimenext-site/`

这个链接填进 App Information → Privacy Policy URL。

### ② Support URL（必填）

可以跟隐私政策用同一个站点，加一页 `support.md` 写上一个联系邮箱就行。Apple 只要求这个页面上有办法联系到你。

**Marketing URL 是选填的，留空。**

---

## 9. Copyright 和 Version

- **Copyright**：`2026 Dominic Chen`（填你自己或公司的法定名称）
- **Version**：`1.0`
- **What's New in This Version**：1.0 首次提交不用填

---

## 10. 提交前的最后核对表

- [ ] 5 张 6.9" 截图已上传（已完成）
- [ ] Privacy Policy URL（待办 —— 见第 8 节）
- [ ] Support URL（待办 —— 见第 8 节）
- [ ] Age Rating 4+（已完成）
- [ ] App Privacy 标签 = Data Not Collected（待办 —— 见第 7 节）
- [ ] Description / Keywords / Subtitle / Promotional Text（本文档，待粘贴）
- [ ] App Review Notes（本文档第 6 节，待粘贴）
- [ ] Archive → 上传 → 选 build → Submit for Review

---

## 一个我没法替你确认的地方

Description 里我没写最低系统版本要求，因为我不确定项目的 deployment target 具体是多少。这个不影响提交（App Store 会自动显示"需要 iOS X.X 或更高版本"），但如果你想在描述里明确写出来，在 Xcode 里点项目 → General → Minimum Deployments 看一眼数字告诉我，我加进去。
