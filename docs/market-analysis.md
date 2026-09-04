# ScreenTimeNext — 可行性与市场判断

日期:2026-09-04 · 作者:Claude(应 Dominic 要求在改名时一并分析)· 状态:初版判断,待产品验证数据更新

> 这份文档是给**人**看的判断,不是给 coding agent 的指令。它回答三个问题:这个 idea 技术上做不做得出来、市场上有没有位置、成功的概率有多大。结论先行,证据在后。

---

## 一、结论

**技术可行,商业艰难,值得做但要当成一个验证实验而不是一个产品来做。**

把"成功"分层来看,我的判断如下(这些是基于下文证据的个人估计,不是数据):

| 成功定义 | 估计概率 | 主要门槛 |
|---|---|---|
| 拿到 Family Controls 分发 entitlement | 70–80% | 用途真实、材料完整;时间不可控(几天到几周,论坛上有 3 周以上无回复的案例) |
| 上架 App Store,且执行(shield)在真机上真正可靠 | 50–60% | DeviceActivity 回调的不可靠性;真机调试;审核对 ManagedSettings 用法的挑剔 |
| 有持续付费用户,年收入 > $30k | 10–15% | 最大竞争对手是**免费的** Apple Screen Time;获客成本;差异点薄 |
| 年收入 > $500k 或被收购 | < 3% | 需要品类级别的突破,或 Apple 不做的方向被证明有大需求 |

换个角度:**作为一个单人、借助 AI 编码代理、投入主要是时间的副项目,期望值是正的**——即便商业上不成,你会拿到一个真实上架的 Screen Time API 产品、一份对 Apple 生态最难啃的 API 之一的一手经验,以及 §21 那四个假设的真实答案。前提是把成本控制在"验证假设"这个尺度。

---

## 二、市场:池子在长,但你的位置在最挤的角落

家长控制软件市场 2025 年约 **$15.7 亿**,2026 年预计 $17.6 亿,到 2034 年 $41.2 亿,CAGR 约 11.2%;北美占 33.5%。驱动因素是各国儿童网络安全立法和社交媒体渗透。数字是健康的,但要看清楚这个池子里谁在赚钱:Qustodio、Bark、OurPact、Norton、Google Family Link 这类**全谱系**产品——跨平台、多设备、位置追踪、内容监控、短信监测。它们卖的是"安心",不是"平和地结束屏幕时间"。

定价参考:Qustodio Basic **$59.95/年**(5 台设备),Complete $104.95/年;OurPact Premium **$69.99/年**(20 台儿童设备)。PRD §21 假设的 **$30/年** 对比这些看起来便宜,但 ScreenTimeNext 是单孩、单设备、无远程管理——它的价格锚点其实不是 Qustodio,而是**免费**。

### 真正的对手:Apple 自己

Apple 内置的 Screen Time 已经免费提供:App 限额、限额到期前的 5 分钟提醒、"One More Minute"、"Remind Me in 15 Minutes"、家长开启 "Block at End of Limit" 后的 "Ask For More Time"、Downtime,以及通过 Family Sharing 的**远程**管理。也就是说,"提前预警 + 到时锁定 + 家长可延时"这三件事 Apple 都做了,而且家长不需要碰孩子的 iPad。

ScreenTimeNext 相对 Apple 的**真实增量**只有两条:孩子自己选"接下来做什么",以及整套面向孩子的温和文案与画面。这两条是真的——但很薄,而且 Apple 任何一年的 WWDC 都可以顺手加上(sherlocking 风险)。

### 差异点有没有依据?

"过渡预警"是被广泛推荐的育儿技巧:10/5/1 分钟倒数、明确说出"接下来做什么"、用 first-then 句式,对学龄前和 ADHD 儿童尤其有效。但公开的育儿指南普遍**没有引用同行评审研究**,这是经验共识而非实证结论。PRD §21 把"孩子选下一项活动是否真的让过渡更容易"列为待验证假设,是对的。

一个值得注意的正面信号:**可视化计时器**是一个已被证明家长愿意付费的品类——Time Timer 的实体计时器卖 $30 以上,App Store 上 "Visual Timer for Kids" 类应用有稳定需求,核心用户是 ADHD/自闭谱系儿童的家长,因为这些孩子的过渡困难最尖锐。这可能是 ScreenTimeNext 最合理的**滩头阵地**:不是"所有 5–12 岁孩子的家长",而是"过渡本身就是每天战场的家庭"。

---

## 三、平台风险:这是决定成败的地方

### 1. Entitlement 是日历时间

开发 entitlement(`com.apple.developer.family-controls.development`)可以立刻用,真机测试不受阻。**分发** entitlement 需要 Apple 人工审核,每个 bundle ID(含每个 extension)单独申请。常见时长是几个工作日到几周,但开发者论坛上有大量"10 天以上无回复""3 周以上""2026 年 3 月提交至今无状态"的帖子。常见拒绝原因:Screen Time 不是 app 的核心功能、说明含糊、漏了 extension 的 bundle ID。

ScreenTimeNext 的用途是真实的家长控制,通过审核的概率不低;不可控的是**什么时候**。这在 `docs/BLOCKERS.md` B-001 已记录,应该**今天**就提交。

### 2. DeviceActivity 不可靠,而你的核心承诺依赖精确时机

第三方开发者反复报告:DeviceActivity 回调会被节流、延迟或直接丢弃,受热状态、锁屏状态和用户使用频率影响,且**不报错**;超过约 45 分钟的 schedule 尤其不稳。宿主 app 无法读取当前 shield 状态(必须自己维护影子状态——项目架构里的 `ProtectionState` 正是为此),也无法读取用量数据(只能渲染 Apple 提供的视图)。屏蔽某个 app 不会自动屏蔽它的网页版。模拟器完全不采集用量,`eventDidReachThreshold` 在模拟器上根本不会触发。WWDC 2026 没有改变这些。

这对 ScreenTimeNext 的打击比对 Qustodio 更重,因为**"平和地结束"的全部体验押在 10/5/1 分钟这三个时刻的准确性上**。一个晚了 4 分钟才出现的"还有 5 分钟"提示,比没有提示更糟。

### 3. 一个 PRD 层面的设计缺口(建议记为 D-006)

PRD 把"每日预算"定义为 DeviceActivity 的**用量阈值**(孩子累计用了 60 分钟选定的 app),但 §6.10 要求孩子看到的倒计时基于**绝对时间戳**。这两个时钟是不同的:用量只在阈值触发时通过 extension 回调才能得知,宿主 app 读不到累计值。孩子看到的"剩余 7 分钟"和系统实际执行的时刻可能对不上。

两条出路,需要在 Task 006/010 之前定下来:

- **会话模型**:孩子按"开始",从那一刻起 60 分钟墙钟时间。倒计时精确、本地通知精确,DeviceActivity 只负责兜底执行。代价是"预算"变成了"一次会话",孩子中途放下 iPad 也在计时。
- **多阈值事件模型**:在 budget−600、budget−300、budget−60、budget 各注册一个 DeviceActivity 事件,extension 在每个回调里写时间戳到 App Group 并发本地通知。忠于 PRD,但把三次预警都押在了上面说的不可靠回调上。

我倾向 V1 用会话模型——它让最核心的体验可控,把不可靠的部分限制在"最终执行"这一环。

### 4. 名字的风险

"Screen Time" **不在** Apple 的注册商标列表里。但 App Review 4.1 / 5.2.5 对"暗示 Apple 官方关联"的名字很敏感,"ScreenTimeNext" 读起来像 Apple 功能的延伸,存在被要求改名的可能。另外 App Store 搜索"screen time"这个词被 Apple 自己的结果和头部产品占满,一个含 "Screen Time" 的名字并不能带来搜索优势。

建议:**ScreenTimeNext 作为工程名 / bundle 名保留**(已改),**App Store 展示名另起一个不含 "Screen Time" 的品牌名**,并在提交前准备好备选。这是 D-005 里留出的口子。

### 5. 绕过与诚实

7 岁孩子绕过 Screen Time 的新闻不是段子。§17 的诚实约束("不能宣称阻止所有绕过")是对的,也意味着宣传只能承诺"温和地结束",不能承诺"锁得住"——而后者才是家长掏钱的主要理由。

---

## 四、商业模型的几个诚实判断

**定价**:对标免费而不是 Qustodio。$30/年的订阅要让家长为"语气"付费,很难;一次性 $9.99–$14.99 或极低月费更贴合"单孩单设备工具"的心智。可视化计时器品类证明了 $10–$30 一次性的意愿存在。

**获客**:parental control 关键词的广告很贵,自然搜索被占满。可行的路径是社区——ADHD/自闭谱系家长社群、蒙氏/正面管教社群、儿科 OT(职能治疗师)推荐。这些渠道慢,但精准且对"过渡"这个词有天然共鸣。

**留存**:孩子长大、换设备、家长换方案,这个品类的自然流失很高。单孩单设备的设计进一步限制了 LTV。

**Sherlocking**:如果 ScreenTimeNext 证明了"孩子选下一项活动"有效,Apple 加这个功能的成本几乎为零。护城河只能是执行细节和品牌,不是功能。

---

## 五、建议

1. **今天提交 entitlement 申请**。它是唯一不受你控制的排期项。
2. **先定 D-006(会话 vs. 用量模型)再动 Task 006**。这是产品层面最大的未决问题。
3. **把 §21 的四个假设变成可测的指标和一个止损线**,例如:上架 90 天内 < N 个付费用户,或试用转化 < X%,就停。写进 PROGRESS.md。
4. **滩头阵地缩到"过渡困难家庭"**,文案、截图、社群投放都围绕这个词,而不是泛家长控制。
5. **App Store 展示名另取**,ScreenTimeNext 留作工程名。
6. **把"体验半"当成可以独立验证的东西**:在 entitlement 等待期间,用 TestFlight(需要分发 entitlement)之前的本地构建,找 5–10 个目标家庭做真人观察——孩子选活动这件事到底有没有让过渡变平和。这个答案比任何代码都值钱。

---

## 来源

- Newly — [How to Get the Apple Family Controls Entitlement](https://newly.app/how-to/family-controls-entitlement)(开发 vs 分发 entitlement、时长、拒绝原因)
- Apple Developer Forums — [FamilyControls distribution entitlement pending for 10+ days](https://developer.apple.com/forums/thread/821964)、[3+ weeks of waiting](https://developer.apple.com/forums/thread/725036)、[Waiting Forever for iOS Family Controls Entitlement](https://developer.apple.com/forums/thread/774812)、[submitted March 9, 2026 — no response](https://developer.apple.com/forums/thread/818553)
- Apple Developer Forums — [DeviceActivityMonitor Extension not firing / simulator limitation](https://developer.apple.com/forums/thread/746416)
- Habit Doom — [What WWDC 2026 Should Fix About Screen Time](https://habitdoom.com/blog/wwdc-2026-screen-time-wishlist)(DeviceActivity 节流、shield 状态不可读、网页绕过、用量不可读)
- Fortune Business Insights — [Parental Control Software Market Size](https://www.fortunebusinessinsights.com/parental-control-software-market-104282)
- The Mac Observer — [Disable "One More Minute" Screen Time Limit](https://www.macobserver.com/tips/how-to/disable-one-more-minute-screen-time-limit-on-iphone/)(Apple 内置行为)
- Boomerang — [Best Screen Time Apps for iPhone in 2026](https://useboomerang.com/article/screen-time-apps-for-iphone/)(iOS 第三方能力限制)
- OurPact — [Pricing](https://www.ourpact.com/pricing);Qustodio — [Premium](https://www.qustodio.com/en/premium/)
- Apple — [Trademark List](https://www.apple.com/legal/intellectual-property/trademark/appletmlist.html)
- Parenting Mentor — [Transition Warnings That Help Kids Cooperate](https://parentingmentor.com/guides/guide/transition-warnings/)
- Tom's Guide — [7-Year-Old Hacks Apple's Screen Time Restrictions](https://www.tomsguide.com/us/ios-screen-time-hack-kid,news-28177.html)
