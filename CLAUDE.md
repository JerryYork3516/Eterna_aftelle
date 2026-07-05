# CLAUDE.md — Aftelle Desktop

> 这份是给 **Claude Code** 的入口文件。
> **所有项目规则以 `AGENTS.md` 为唯一真相。** 本文件不重复规则(避免两份不同步),只做两件事:① 把你指向 AGENTS.md;② 补 Claude Code 特有的协作约定。
> **每次工作前:先读 `AGENTS.md`,再读本文件。**

---

## 一、先读 AGENTS.md(不要跳过)

AGENTS.md 里有你必须遵守的全部核心规则,包括:
- 项目是什么 + Stage 7 命脉链路
- **G0 三个已锁定决策**:A Swift RuntimeCore / 真实 DR v0.3 / 真实 LLM 走 RuntimeCore ProviderRouter 链路
- **四个不可违反的技术约束**(7.4 前接流式或模拟流式反馈 / NSOpenPanel+URL / 粒子日志降频 / schema 版本不匹配防崩)
- 六条红线、文档地图、防烧钱铁律、Git 安全、行为准则、安全边界、改 bug 流程、粒子验证、完成定义

**规则冲突时:红线以"02_architecture.md + 04_code_standards.md 一致版本"为准,本文件和 AGENTS.md 都不覆盖架构事实。**

---

## 二、你(Claude Code)在本项目的定位

- 你是 **写代码主力**,主理 `brain/`(平台无关运行内核 = **RuntimeCore**:ExecutionEngine / Scheduler / ProviderRouter / MemoryController / VisualStateMapper / TraceRecorder / Orchestration / DR Loader / soul / HostEnv 协议)。
- `platform-macos/`(SwiftUI / Metal / 输入 / 音频)由 **Codex** 主理,你不主动改它的 SwiftUI/Metal/Audio 具体实现。
- `shared-protocol/`(DR schema、协议常量)改动需与 Codex 同步,不单方面改。
- 跨 `brain/`(RuntimeCore) ↔ `platform-macos/` 只改接口契约(HostEnv / Avatar State Protocol),**不直接 import 对方内部实现**。

> 红线 1 对你尤其重要:`brain/`(RuntimeCore) 里**禁止** import Metal / AppKit / SwiftUI / Keychain SDK / SQLite 驱动 —— 一切外部访问走 HostEnv。这是你最容易踩的线,写之前自检。

### Apple Host 预留边界

Stage 7 只开发 macOS 单机 Runtime Host。看到 Apple ecosystem / iOS / iPadOS / visionOS / watchOS / tvOS / AR / RealityKit 等关键词时,只把它们当作文档级 Host 预留,不得自动扩展成 Stage 8、多平台 target、DR schema、Runtime API 或功能代码开发。未来 Apple 平台只能作为 Host 复用 RuntimeCore,不能在 Host 内复制 Scheduler / Memory Kernel / ProviderRouter / DR compiler。

涉及 SwiftUI / Metal / FileManager / Keychain / Human Interface Guidelines / Accessibility 时,只按 `docs/apple_official_reference_stage7.md` 读取当前节点最小 Apple 官方文档。Apple 官方文档只是实现参考,不是 Aftelle 架构事实源;若它与 Stage 7 项目文档冲突,停止并报告,不要替项目改边界。

Stage 7 开发、审核或 PR 前后都要使用 `docs/stage7_forbidden_checklist.md` 输出 PASS / REWORK / FAIL。遇到 iOS / visionOS / AR / Provider / DR schema / Runtime API / scheduler / memory 等高危关键词时,先按 checklist 判断,再决定是否继续。

---

## 三、和 Codex 的协作边界(防止互相覆盖)

- **一个任务一个 AI 改**。你改 `brain/`(RuntimeCore),Codex 改 `platform-macos/`,**不要互相进对方目录改实现**。
- 需要对方配合时,改的是**接口契约**(HostEnv / Avatar State Protocol),并说明"这里改了接口,platform 侧需同步",而不是直接替 Codex 写 macOS 代码。
- 审查可以交叉(你审 Codex 的边界、Codex 审你的),但**不准两个 AI 同时改同一块代码**(防群殴,见 AGENTS.md 改 bug 流程 + bug_contract.md)。

---

## 四、Claude Code 的工具习惯(省 token + 不改崩)

- **文件白名单**:动手前先报告"预计读哪些文件、范围多大",等确认再读。**禁止为'理解全局'扫全仓库。**(AGENTS.md 防烧钱铁律)
- **跨文件改动前先 commit** 一次作回滚点(`[7.1] xxx`);改崩能一键回滚。
- **不重复读**已读过、没变化的文件。
- 改 bug 走两轮制(第一轮只定位不改,第二轮才最小修复),详见 bug_contract.md;改两次仍不行就停手回报,不硬试。
- **粒子相关代码**:你看不见屏幕,凭日志数字验证(降频日志,见05_dev_guide.md第 6 节),不要假设"应该对了"。

---

## 五、完成的定义(和 AGENTS.md 一致)

一个任务"做完"必须:① 编译通过;② 该功能用手动操作或日志数字验证跑通;③ 没违反任何红线;④ 没碰授权范围外的文件。
**不许报"做完了"却没验证。**

---

## 六、按需读哪份文档(别一次全读)

- 改 `brain/`(RuntimeCore)逻辑、HostEnv、运行链路 → 02_architecture.md 的相关节
- 写代码细则、去 AI 味、命名 → 04_code_standards.md
- 执行流程、粒子盲测、测试、改 bug → 05_dev_guide.md / bug_contract.md
- 当前阶段做什么 → 03_dev_plan.md
- 造/改居民 → 07_dr_blueprint.md
- 评估 Stage 7 live-state 功能、MVP/Extended 分层、禁止项 → feature_livestate.md
- 查 SwiftUI / Metal / FileManager / Keychain / HIG / Accessibility 官方参考 → apple_official_reference_stage7.md
- Runtime/DR 字段 → runtime_api_contract.md / dr_contract_v0_3.md
- 架构边界判断 → aftelle_runtime_boundary.md(只读不改)
- 当前进度/历史决策 → DEVLOG 的"当前状态"段

**默认:写代码时只读 AGENTS.md + 本文件 + 当前任务直接相关的 1–2 份。** 其余不确定就先问,别自行全部加载。
