# DEVLOG.md — Aftelle 开发日志(给我自己看)

> 这份是给我自己的,不是给 AI 自动读的。
> 三个作用:① 提醒我做到哪、为什么这么定;② 每次开 GPT/Dify/新对话时,把"当前状态"那段粘过去当背景;③ 防止我忘了当初的决定又推翻重来。
> **规则:每次做完一件事、或讨论出一个结论、或改完一个 bug,就来记一笔。不用长,几行即可。**
>
> **boundary 基线 SHA-256(改动即报警)**：`275b95889f55646e3ae99ceb2a12cc0e974fd5338aa23c7311cccff0d2d041a6`（v7 更新:G0 改 A,仅 clock/tick 归属改为 RuntimeCore,4 条 Invariants 不变;旧 v6 基线 f043f4b5…）

---

## 📌 当前状态(每次更新,粘给 AI 时就粘这一段)

- **现在在做**:Stage 7.1.4 —— RuntimeCore 最小运行闭环接入
- **上一步刚完成**:Stage 7.1.3 App 启动流程,7.1.4 轻量边界审核修复中
- **当前卡在**:无
- **下一步**:7.1.4 修复验收后,等待确认再进 7.1.5
- **额度情况**:保持最小启动路径,不碰运行闭环

> - **现在在做**:Stage 7.1.2 —— macOS Desktop Shell 整理
> - **上一步刚完成**:Stage 7.1.1 Platform Adapter boundary 已就绪,开始收口 App shell
> - **当前卡在**:无
> - **下一步**:只做 7.1.2 验收与记录,不进 7.1.3
> - **额度情况**:按节点推进,保持最小 shell 改动

> - **现在在做**: v7 文档收口(G0 改 A / Swift RuntimeCore),准备进 Stage 7.0 Calibration
> - **上一步刚完成**: Stage 6.11 Freeze Audit，后端 pytest 208 passed，前端 typecheck passed，6.7–6.10 手动验收完成
> - **当前卡在**: Stage 7 Gate 缺少冻结文档：DEVLOG.md、runtime_api_contract.md、aftelle_runtime_boundary.md
> - **下一步**:补齐 Gate 文档后，让 Cursor 重新验收 Stage 7 Entry Gate
> - **额度情况**:进入 Stage 7 前先控 token，只做文档冻结，不改代码


## ✅ 我现在要做的事(开工清单,做完打勾)

进 7.1 之前:

- [x] **【G0·已拍板 v7 改选 A】Runtime 策略：A. Swift RuntimeCore（App 内置运行内核）** ← v7 由 B 改 A;只有我能定
- [x] **【G0·已拍板】DR 字段对齐：以 Studio 导出的 DR v0.3 envelope + Runtime API 6.11.0 实际返回字段为准**
- [x] **【G0·已拍板】真实 LLM 来源：Stage 7 MVP 可 mock；真实 Provider 只能走 RuntimeCore ProviderConfig/Profile → ProviderRouter → ProviderAdapter → ExecutionEngine；UI 不直连 OpenAI/Claude/Qwen**
- [ ] 把 `Agent.md` 改成正确的 `AGENTS.md`
- [ ] 建 GitHub/Gitee **私有**仓库,放进全部文档,锁好 .gitignore(密钥/真实DR不进库)
- [ ] 做 2-3 个测试 DR fixture(1 个正常 + 1 个错误 + 空壳)
- [x] Stage 6 收尾完成：DR v0.3 Contract Freeze 已完成，Aftelle 读取字段以后以 `dr_contract_v0_3.md` 为准
- [ ] 开工首日锁定技术栈版本(Swift / Xcode / 最低 macOS),写进仓库
- [ ] 用 Claude Code `/status` 确认我的额度和计费方式

进 7.1 后:

- [ ] 搭空 Xcode 项目,放约 10 个粒子
- [ ] 走通:加载 DR → 改粒子逻辑 → 看到变化
- [ ] 记下:7.1 花了多少额度、AI 读了多少文件、卡在哪 → 用它外推整个 Stage 7

---

## 📒 决策记录(重要的决定记在这,防止以后忘了又推翻)

> 格式:**日期 — 决定了什么 — 为什么**

- 2026-06-30 — G0 Runtime 策略拍板：选 B，本地 Python sidecar，Aftelle 通过 HTTP 调 `/runtime` — Stage 7 先做 macOS Runtime Host MVP，不重写后端 Runtime Kernel，避免 Aftelle 变成第二个 Studio。
- [继续往下记...]
- 2026-06-30 — G0 DR 字段对齐拍板：以 Studio 导出的 DR v0.3 envelope + Runtime API 6.11.0 实际返回字段为准 — 不再按旧版或假设字段设计 Aftelle。
- 2026-06-30 — G0 真实 LLM 来源拍板：Stage 7 MVP 可用 mock；真实 LLM 只能走 Runtime Config → Provider Registry → Provider Adapter → Execution Engine — Aftelle 不直连 OpenAI/Claude/Qwen，不保存 provider secret。
- 2026-06-30 — Stage 6.11 Freeze Audit 通过 — 后端 pytest 208 passed，前端 typecheck passed；6.7 Memory PASS，6.8 Lattice PASS，6.9 Voice/TTS PASS，6.10 Screen PASS_WITH_UI_NODE_NOT_EXPOSED。
- 2026-06-30 — Stage 7 Entry Gate 初验未通过正式准入 — 代码链路与测试基本通过，但当时缺少 Gate 冻结文档：`DEVLOG.md`、`runtime_api_contract.md`、`aftelle_runtime_boundary.md`。
- 2026-06-30 — 文档套件 v4 升级 — 中文文件名统一改为短英文名;`aftelle_runtime_boundary.md` 保持只读并作为单一事实源;`02_architecture.md`、`03_dev_plan.md`、`04_code_standards.md`、`05_dev_guide.md`、`06_product_design.md`、`07_dr_blueprint.md`、`08_product_designer.md`、`runtime_api_contract.md`、`dr_contract_v0_3.md`、`stage7_entry_gate.md`、`AGENTS.md`、`CLAUDE.md` 已对齐 G0 与 boundary;新增 `README.md`。
- 2026-06-30 — v4 G0 结论记录 — Runtime 选 B 本地 Python sidecar;DR 字段以真实 DR v0.3 + Runtime API 6.11.0 实际返回为准;真实 LLM 只能走 Runtime Config → Provider Registry → Provider Adapter → Execution Engine,Aftelle 不直连模型。
- 2026-06-30 — v4 边界对齐记录 — 对齐 4 条 Invariants、Policy≠Layer、content-agnostic 映射、冻6/留缝5、Private/SharedSession/PublicTranscript 三种记忆边界、自我披露策略;新增 App 文字与语言统一格式规范。
- 2026-06-30 — 文档套件 v5 升级 — 按 GPT 审查意见消除文档间硬冲突:AGENTS 流式/`schema_version`/Runtime 对话口径、09_skills_plugins 工具安装时机、Aftelle 浅校验 vs sidecar `load-dr` 完整校验、provider secret 归 sidecar credential store。
- 2026-06-30 — v5 boundary 对齐补强 — 明确 sidecar 拥有 runtime clock/state/tick,Aftelle 只注入外部事件;`runtime_api_contract.md` 保留 HTTP `input_text` 兼容字段并补 `EnvironmentEvent`;新增 `ResidentLiveState` 最小结构、三种记忆命名空间、no-op `system.tick` 存在性要求。
- 2026-06-30 — v5 Stage 7 范围收敛 — 统一 Stage 7 MVP = 7.1–7.5 单居民闭环,Stage 7 Extended Demo = 7.6–7.11;双居民、屏幕指导、隔离验证移出 MVP 基线;7.10 仅检查坐标抽象不阻碍未来 AR,不新增 AR/移动端字段或接口。
- 2026-06-30 — v5 蓝本与存储命名校准 — `07_dr_blueprint.md` 强化"长期愿景、非契约、非 schema、不得用于 Stage 7 coding"警示;Aftelle 侧记忆命名统一为 SessionStore / HostStateStore,居民长期记忆只经 sidecar Execution Engine。
- 2026-07-01 — 文档套件 v6 收口 — 合并 `09_DEVLOG.md` 与 `DEVLOG.md` 为单一 `DEVLOG.md`;核对全套文档与 GPT v4 审查 25 项一致(流式/schema_version/浅校验/secret 归属/environment_event/ResidentLiveState/三种记忆命名空间/no-op tick/MVP=7.1–7.5 收敛/命名去 visual_profile 全部落实,无残留矛盾);boundary 已由本人改为 FROZEN(G0 已锁定),记录新 SHA-256 见下。
- 2026-07-01 — **G0 技术选型从 B 改为 A(重大决策)** — 底层运行方案由 B(本地 Python sidecar)改为 **A(Swift RuntimeCore,App 内置运行内核)**。**理由**:Apple 生态优先(LiDAR + Metal 极致渲染,iPhone/iPad Pro 亿级装机);调度/Agent/未来扩展的核心应在 Aftelle 原生 RuntimeCore;纯本地零延迟。**旧 B 标记为 superseded,不删除**,转为非 Apple 端/云端参考实现。Vision Pro 降级为加分项(Apple 已收缩其硬件路线)。**产品主线不变**:Stage 7 仍是 Aftelle 数字居民体验版,7.1–7.11 顺序不变,只替换运行底座。
- 2026-07-01 — **文档套件 v7 升级** — 全套 16 份文档由 B→A:runtime_strategy 重写为 A;boundary 的 clock/tick 归属改为 RuntimeCore(4 Invariants 不变,新 SHA 见上);architecture/dev_plan/entry_gate/api_contract/provider_profile/dr_contract/code_standards/dev_guide/token_control/bug_contract 及 AGENTS/CLAUDE/README 全部把 sidecar/HTTP/RuntimeAPIClient/Python secret 改为 RuntimeCore/同进程/Apple Keychain。产品阶段顺序与 App 体验主线保持不变。Studio(Python)定位为 `.digital_resident` 上游 + 非 Apple/云端参考。
- 2026-07-01 — **v7 B→A 残留清理(第二轮)** — 按 GPT 复审清单清除首轮遗留的旧口径:README/entry_gate/architecture/dev_plan/dev_guide/CLAUDE 中的"后端 Provider 链路 / Runtime Host Client / 不重写 Runtime Kernel / 重实现 execution_engine"全部改为 RuntimeCore 口径;dr_contract/api_contract 明确"Apple 端同进程契约 vs HTTP 未来云端/非 Apple 兼容层"分层;`brain/`(RuntimeCore)目录约定保持一致并标明 RuntimeCore 归属。产品阶段 7.1–7.11 与 App 体验主线未动。
- 2026-07-02 — Stage 7.0 DR fixture 校准完成 — 测试改用本地 `docs/Freezev03.digital_resident`,删除合成 fixture fallback;发现真实 DR 中 `lattice_config.attention = "self"`,后续 loader/合同需按真实样本校准。
- 2026-07-02 — Stage 7.0-CAL-002 Empty Xcode App bootstrap — 新增 `apps/macos/Aftelle/` 最小 SwiftUI macOS App,仅显示 calibration / runtime not loaded / DR fixture not loaded,未接 RuntimeCore/Provider/LLM。
- 2026-07-02 — Stage 7.0-CAL-003 RuntimeCore skeleton — 在 `apps/macos/Aftelle/` 下新增最小 RuntimeCore 边界类型与 stub,仅预留 DRLoader / ExecutionEngine / ProviderRouter / TraceRecorder / VisualStateMapper,未接 UI、未接真实 provider、未改 fixture、未改 DR schema。
- 2026-07-02 — Stage 7.0-CAL-004 load-dr minimal path — UI 只通过 RuntimeCore 加载本地 DR fixture,只读解析 schema_version / resident_id / display_name,未接 Provider / LLM / API,未实现 mock step,未做 trace display,未写回 DR。
- 2026-07-02 — Stage 7.0.5 mock step path — UI 通过 RuntimeCore.step 输入一句话,内部走 ExecutionEngine / ProviderRouter 的本地 mock 闭环,返回 mock output_text 并展示最小视觉状态变化,未接真实 Provider / LLM / API,未做 trace display。
- 2026-07-02 — Stage 7.0.6 trace + visual_state display — 在 mock step 基础上显示最小 trace / diagnostics / visual_state 状态变化,trace 包含 runtime.step / provider.mock / visual_state.changed,未接真实 Provider / LLM / API,未写回 DR。
- 2026-07-02 — Stage 7.0.6-fix pre-review fixes — 新增脱敏 calibration fixture 并接入 Resources,修正 visual_state 最小序列展示,修正 usage log 路径记录,仍未接真实 Provider / LLM / API。
- 2026-07-02 — Stage 7.0.6-fix log cleanup — 补写 7.0.6-fix 记录到 DEVLOG 和 usage log,保持 Stage 7 仍在最小 calibration/mock/trace 收口内。
- 2026-07-02 — Stage 7.0 final review fix — 将 App 内 calibration fixture 修正为脱敏 DR v0.3-shaped 结构,DRLoader 浅校验读取 revision / manifest / resident_identity / lattice_config / safety flags,不依赖真实 `.digital_resident`。
- 2026-07-02 — Stage 7.0 app cleanup — 修正 Bundle 资源查找为 `Freezev03.calibration_fixture.json`,清理旧 `Eterna_aftelle` 模板工程/测试/顶层无效 `Aftelle.xcodeproj`,保留当前 `apps/macos/Aftelle/` 与 `RuntimeCore/`。
- 2026-07-02 — Stage 7.0 Calibration PASS — 上机验证 Load DR 成功,显示 `schema_canvas` / `Schema Canvas`,mock step / trace / diagnostics 正常;允许合并到 main 并进入 Stage 7.1。
- 2026-07-02 — Stage 7.1.1 Platform Adapter boundary — 新增最小 `HostEnv` / `PlatformAdapter` 协议与 noop 实现,RuntimeCore 通过平台无关接口预留 clock / file access / runtime config / provider profile reference / secure secret reference,未接真实平台实现,未引入 SwiftUI / AppKit / Metal。
- 2026-07-02 — Stage 7.1.2 macOS Desktop Shell — 收敛 Aftelle App 为最小 Desktop Shell,只保留启动壳/窗口壳/加载 DR 的状态展示入口,不再暴露输入/响应/trace 粒子演示,继续通过 RuntimeCore 加载本地 calibration fixture,不接真实 Provider/DR 写回。
- 2026-07-02 — Stage 7.1.3 App 启动流程 — 引入 `AppController` 作为 UI 与 RuntimeCore 之间的启动边界,App 启动时自动加载 bundled calibration fixture 并把只读状态下发到 ContentView,ContentView 不再承担读取/启动逻辑。
- 2026-07-02 — Stage 7.1.4 RuntimeCore minimal loop review fix — 保持 UI→AppController→RuntimeCore→ExecutionEngine 最小闭环,将 load request 命名从 fixture 语义收回为 DR data,AppController 独立保存 loaded resident_id,消除 MainActor 初始化 warning;仍未接真实 Provider/LLM/API,未写回 DR,未进入 7.1.5。


---

## 🧊 Stage 7 Gate 冻结文档清单

进入 Stage 7 的冻结文档(Gate 用):
- Runtime 策略：`runtime_strategy.md`
- Runtime API 契约：`runtime_api_contract.md`
- DR v0.3 契约：`dr_contract_v0_3.md`
- Provider Profile 契约：`provider_profile_contract.md`
- Aftelle Runtime 边界(唯一事实源,只读)：`aftelle_runtime_boundary.md`
- 准入标准：`stage7_entry_gate.md`

Stage 6.11 Freeze：Backend pytest 208 passed / Web typecheck passed / 6.7 Memory PASS / 6.8 Lattice PASS / 6.9 Voice·TTS PASS / 6.10 Screen PASS_WITH_UI_NODE_NOT_EXPOSED。

---

## 🐛 Bug 记录(修好的 bug 记一笔,下次遇到类似的不用重新踩坑)

> 格式:**问题 — 原因 — 怎么修的**

- [示范] DR 加载报错 — 原因是 fixture 缺了 schema_version 字段 — 给 fixture 补上字段后正常

---

## 💬 讨论结论(在 GPT/Dify 讨论完,把结论搬到这)

> 格式:**日期 — 讨论了什么 — 结论是什么**

- 2026-XX-XX — 问了三家 AI 评估整套方案 — 共识:体系扎实,唯一风险是准备过头不开工;补了粒子盲测、文件白名单、commit保险三个执行层漏点
- [继续往下记...]

---

## 🅿️ 以后再说(现在不做的需求/想法,攒在这,别打断当前进度)

> 任何"想到但现在不该做"的,扔这里,别立刻去做

- 双居民复杂互动 → Stage 7 后半段
- 付费/登录/云端 → Stage 9
- Android/Windows 移植 → 远期,大脑现成只重做身体
- AR / Vision Pro 身体 → Stage 8
- [继续往下扔...]

---

## 自律守则(给我自己的提醒,卡住时回来看)

1. **想清楚再让 AI 动手** —— 别让代码 AI 当我的草稿纸,架构反复在讨论里消化完。
2. **改动前先想能不能只改一小块** —— 默认局部改,不默认大改。
3. **一个 bug 一个 AI,不换人群殴。**
4. **每条指令圈定范围**,不说"看整个项目"。
5. **准备够了就开工** —— 再想新问题,大多答案是"前面已经定了"。行动 > 完美规划。
