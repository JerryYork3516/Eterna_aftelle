# runtime_strategy.md — Aftelle · v7

> 性质:**架构决策记录**(不是描述)。记录 G0 拍板的 Runtime 策略 + 理由 + 边界。
> 状态:已拍板。v7 变更:**G0 从 B(Python sidecar)改为 A(Swift RuntimeCore)**。旧 B 方案标记为 superseded(见文末),不删除,留作历史与非 Apple 端参考。

---

## 核心口径(先读这句)

**选 A 是把底层运行语言从 Python 换成 Swift RuntimeCore,不是把 Stage 7 改成 Runtime 项目。**
Stage 7 产品主线不变:仍然是 **Aftelle Desktop 数字居民体验版**(导入 DR、粒子生命体、对话、记忆、TTS、字幕、双居民、屏幕指导、Demo Lock)。RuntimeCore 是支撑体验的**内部底座**,不是产品主角。

---

## 决策:A —— Swift RuntimeCore(Apple 端内置运行内核)

Aftelle 在 App 内部用 Swift 实现运行内核 **RuntimeCore**,不再依赖本地 Python 进程。

```
Aftelle UI (SwiftUI + Metal 粒子)
   │  同进程调用
   ▼
App Controller
   │
   ▼
Swift RuntimeCore
   ├─ ExecutionEngine（唯一 Runtime 入口）
   ├─ Scheduler / RuntimeClock（拥有 tick 与时间）
   ├─ ProviderRouter → ProviderAdapter →（mock / 真实 LLM）
   ├─ MemoryController（居民记忆 + LiveState）
   ├─ VisualStateMapper（→ 粒子 / Avatar）
   └─ TraceRecorder（解释每一步）
```

---

## 为什么改选 A(而非继续 B / 选 C)

1. **Apple 生态优先,验证 Apple 市场**:产品核心能力——**LiDAR(激光雷达)与 Metal 极致粒子渲染**——是 Apple 独占且成熟(iPhone Pro / iPad Pro 均带 LiDAR,亿级装机)。全 Swift + Metal 原生栈能把这些做到极致。
2. **调度系统、Agent 能力、未来扩展的核心都在 Aftelle 的 RuntimeCore**:Studio 只是产出 `.digital_resident` 的上游;真正的运行、调度、Agent、社会扩展发生在 Aftelle 端。把运行内核放在 App 内(Swift),让这些核心能力有原生、低延迟、可离线的地基。
3. **纯本地、零进程间开销**:RuntimeCore 与 UI 同进程,无 HTTP 往返、无需在用户机器上跑 Python,App 是一个干净的原生应用,响应最快,契合"生命感"。

> 关于 Vision Pro:视为**加分项而非支柱**。当前 Apple 已收缩 Vision Pro 硬件路线(重心转向智能眼镜),Vision Pro 装机量有限。因此产品地基押在 **LiDAR + Metal + iPhone/iPad Pro 的巨大装机量**,Vision Pro 支持能上则上,不作为产品成立前提。

---

## 这个决策带来的边界(写进红线,所有 AI 遵守)

- **RuntimeCore 拥有** runtime clock / live state / scheduler tick;UI 只注入外部事件(environment→resident),不模拟 tick、不拥有调度时间。
- **ExecutionEngine 是唯一 Runtime 入口**;UI / 任何模块**禁止绕过** ExecutionEngine 直连 Provider / Tool / TTS。
- Provider 调用走 `RuntimeCore ProviderRouter → ProviderAdapter`;**UI 不直连** OpenAI/Claude/Qwen。
- **Provider secret 由 Apple secure credential store / Keychain 持有**,RuntimeCore 只使用 `key_ref`;secret 不进 UI、不进 DR、不进 Trace / Memory / Git / 日志。
- DR **只读**:记忆 / Trace / LiveState 不写回 DR。
- 红线 1(逻辑与平台/渲染分离)仍成立:RuntimeCore 只做运行逻辑,不写 Metal/UI 绘制;VisualStateMapper 只输出状态,渲染在 UI 层。**这条在 A 方案下更重要**——因为大脑也是 Swift,更要守住"逻辑核心 vs 渲染外壳"的分层,便于未来非 Apple 平台复用逻辑。

---

## 契约是不动的轴(迁移最小化的关键)

DR 契约(dr_contract_v0_3.md)与 Runtime 契约(runtime_api_contract.md)的**字段/结构保持不变**;A 方案只是把"实现方"从 Python sidecar 换成 Swift RuntimeCore。
- Apple 端:契约背后是 Swift RuntimeCore(同进程调用)。
- 未来非 Apple 端(Windows/Android):契约背后可接 Python(云端或本地),行为一致。

Apple 平台优先级:先稳定 macOS RuntimeCore 与单机 Runtime Host。未来 iOS / iPadOS / visionOS / watchOS / tvOS 只能作为不同 Host 复用核心逻辑;UI、渲染、输入、音频由各 Host 自己适配,不承诺复用 macOS UI / Metal 画法。本阶段不定义平台服务、AR / visionOS 细节或任何多平台 target。

---

## Python 的定位(降级,不废弃)

- Studio 仍是产出 `.digital_resident` 的**上游**,继续用 Python。
- 原 Python Runtime **降级为参考实现 / 云端或非 Apple 端备用**,不再是 Apple 端的运行真相源。
- **Apple 端运行真相源 = Swift RuntimeCore。**
- Python 侧的进一步优化(云端化、非 Apple 平台)放到 Apple 端稳定之后再做。

---

## superseded:旧 G0(B — 本地 Python sidecar)

> 保留作历史。2026-06-30 曾拍板 B(Aftelle 通过 HTTP 调本地 Python Runtime,复用 Studio 后端,sidecar 拥有 tick)。
> 改选 A 的原因:Apple 优先(LiDAR/Metal)、核心调度与 Agent 能力应在 Aftelle 原生 RuntimeCore、纯本地零延迟。B 方案的价值转为"非 Apple 端 / 云端参考实现"。
