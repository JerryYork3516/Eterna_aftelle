# bug_contract.md — Aftelle · v5

> v5 变更:示例文件范围改为 SessionStore / HostStateStore 命名,避免把 Aftelle 缓存误读成居民长期记忆。

> 目的:防止"改 bug 无限循环烧 token/额度"。
> 核心:**不是让 AI 找问题,而是你把问题压缩到最小现场,让 AI 在限定文件内修。**
> 每个 bug 都必须有:分级、范围、文件、验收、熔断线、回滚点。

---

## 0. 三条铁律(违反就回到 Studio 烧钱老路)

1. **先定位,不准改**(第一轮只定位,第二轮才修)。
2. **只读列出的文件,不准全仓库搜索**。
3. **一个 bug 一个 AI**,不准换多个 AI 群殴(换人规则见 §7 升级阶梯)。

---

## 1. Bug 分级与读取上限

| 级别 | 含义 | 允许读 | 最多读 |
|---|---|---|---|
| **P0** | 启动/编译/主链路坏 | AGENTS.md、运行契约、报错文件、调用它的上一级、相关测试 | 5–8 个文件 |
| **P1** | 功能异常 | 目标功能文件、相关 model/契约、相关测试 | 3–5 个文件 |
| **P2** | UI/文案/小体验 | 当前 UI 文件、样式文件 | 1–3 个文件 |

---

## 2. 每个 Bug 必须先填模板(不准直接说"修这个 bug")

```
Bug ID：
级别：P0 / P1 / P2
现象：
复现步骤：
期望结果：
实际结果：
错误日志：
怀疑范围：
允许读取文件：
禁止读取文件：
允许修改文件：
验收方式：
熔断线：（不填则用 §6 默认值）
回滚点：（修复前的 git commit,见 §5）
```

**示例:**
```
Bug ID：S7-UI-014
级别：P2
现象：导入 DR 后粒子没切换颜色
复现步骤：启动 → Import DR → 选 humanistic fixture
期望结果：粒子颜色切到 DR lattice visual state
实际结果：仍是默认灰白
错误日志：无崩溃
怀疑范围：DRFileLoader / ResidentSessionStore / ParticleState
允许读取文件：DRFileLoader.swift / ResidentSessionStore.swift / ParticleState.swift / 运行契约
禁止读取文件：apps/api/** / Studio 前端 / DR Compiler
允许修改文件：DRFileLoader.swift / ResidentSessionStore.swift / ParticleState.swift
验收方式：导入 humanistic DR 后 visual_state.colorTheme 生效
熔断线：默认 P2(3 轮)
回滚点：commit abc123
```

---

## 3. 第一轮:只定位,不改

> 提示词:
> 只做定位,不要改代码。限制:① 只读我列出的文件;② 不全仓库搜索;③ 不重构。
> 输出:最可能原因 / 需修改的最小文件 / 是否需额外读取文件(若需,说明具体文件和理由)。

---

## 4. 第二轮:最小修复

> 提示词:
> 只改上一轮确认的最小文件集合。不改架构、不顺手重构、不新增无关抽象。
> 改完给出:修改点 / 影响范围 / 验收步骤 / 是否需要测试。

---

## 5. 回滚点(关键:防"越修越崩")⭐

- **每个 bug 开修前,先 git commit 一次**,这是回滚点,写进模板。
- **修复后若引入新问题**:不要在坏代码上继续叠加修——**立刻 git 回滚到修复前**,重新定位。
- 禁止"修 A 出 B,修 B 出 C"的链式叠加。出现一次链式,立即回滚 + 降速 + 回 §7 升级。

---

## 6. 熔断线(按轮次,不靠你盯 token)⭐

token 难实时监控,改用**轮次**作为熔断,更可执行:

| 级别 | 定位轮上限 | 修复轮上限 | 触发熔断后 |
|---|---|---|---|
| P2 | 2 轮 | 1 轮 | 停 |
| P1 | 3 轮 | 2 轮 | 停 |
| P0 | 4 轮 | 3 轮 | 停 |

> 触发熔断时,让 AI 输出:
> 已知事实 / 已读文件 / 已排除的原因 / 未排除的原因 / 下一步最小验证。
> **然后停手,进入 §7 升级阶梯,不许继续硬试。**

---

## 7. 升级阶梯(熔断后怎么办,防卡死也防群殴)⭐

按顺序走,**不准跳级、不准一上来换 AI**:

```
第 1 级:同一 AI,缩小范围再试一轮(可能是范围给错了)
   ↓ 还不行
第 2 级:回 §5 回滚,带着"已排除原因"重新定位(不是从头读)
   ↓ 还不行
第 3 级:才允许换另一个 AI——但必须把"已知事实+已读文件+已排除原因"一起给它,
        让它接力,不准从零重读项目。
   ↓ 还不行
第 4 级:判定为"当前修不了",走 §8 deferred 出口。
```

**换 AI 只在第 3 级、且带着完整上下文。** 这才不是"群殴",是"接力"。

---

## 8. Deferred 出口(防困在不该现在修的 bug 上)⭐

有些 bug 当下就是不该修:
- 依赖未就绪(如 Studio DR 字段没定、真实 LLM 没接)
- 是 Studio/上游的问题,不是 Aftelle 的
- 超出 Stage 7 范围

→ **标记为 `deferred` 或 `blocked`,记进 BUG_INDEX,绕过它继续干别的。** 不许在阻塞型 bug 上烧到熔断。

---

## 9. 禁止的搜索/指令(最烧钱)

**允许的搜索只有三种:** 按文件名 / 按函数名 / 按错误字符串。

**禁止这些指令:**
- "帮我检查整个项目哪里有问题"
- "读完整仓库找 bug"
- "全面审查这个模块"
- "顺便优化一下" / "顺手重构" / "顺手清理"

---

## 10. 配套文件(越写越省 token)

**BUG_INDEX.md** — 每个 bug 先记录,后续 AI 先读这份,不重读历史对话:
```
S7-UI-014
状态：open / fixed / deferred / blocked
级别：P2
范围：ParticleState / DRFileLoader
文件：DRFileLoader.swift / ResidentSessionStore.swift / ParticleState.swift
原因：导入 DR 后 lattice visual state 没映射到 ParticleState
验收：导入 fixture 后颜色切换
回滚点：commit abc123
```

**FILE_OWNERS.md** — 什么问题看什么文件(AI 不用猜范围):
```
DR 导入：DRFileLoader.swift / RuntimeCore.swift / ResidentSessionStore.swift
Runtime step：RuntimeCore.swift / RuntimeModels.swift / DebugPanel.swift
粒子状态：ParticleState.swift / ParticleRenderer.swift / MetalParticleView.swift
字幕：SubtitleController.swift / CaptionView.swift
TTS：TTSProvider.swift / SpeechPlaybackController.swift
记忆/展示缓存：SessionStore.swift / HostStateStore.swift
```
> 注:以上文件名为示例,按实际项目结构填。

**ERROR_PLAYBOOK.md** — 常见错误和修法沉淀:
```
## Swift Codable decode failed
优先查：RuntimeModels.swift / 运行契约 / JSON 字段是否 nullable
## Metal blank screen
优先查：MetalParticleView.swift / ParticleRenderer.swift / MTKView delegate 是否绑定
## DR load success but UI no update
优先查：ResidentSessionStore.swift / @Published / ObservableObject 是否触发
```

---

## 11. 标准流程

```
复现 → 填 Bug 模板 → git commit(回滚点)
→ AI 第一轮只定位 → 你批准是否读额外文件
→ AI 第二轮最小修复 → Xcode/pytest 验收
→ 通过:记 BUG_INDEX(fixed)
→ 引入新问题:回滚(§5)→ 升级阶梯(§7)
→ 熔断:停 → 升级阶梯 → 实在不行 deferred(§8)
→ 全程不做额外优化
```

---

## 12. 节省原则

- **不贴全文件**,只贴:错误日志 / 相关函数 / 相关 model / 调用栈。
- **不让 AI 猜**,给:复现步骤 / 实际结果 / 期望结果 / 相关文件。
- **不让 AI 顺手优化**:禁止顺便重构/清理/增强。
- **谁主力谁修**(按你的工具分工:写代码主力修;讨论型 AI 做"定位方向是否合理、diff 有没有破坏边界"的判断,不下场重读全项目)。

---

## 一句话

Bug 修复不是"让 AI 找问题",而是**你把问题压缩到最小现场,让 AI 在限定文件内修**。
每个 bug 必须有:范围、文件、验收、**回滚点、轮次熔断线、升级阶梯、deferred 出口**——后四个是防"无限循环烧 token"的关键。
