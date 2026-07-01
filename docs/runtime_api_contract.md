# runtime_api_contract.md — Aftelle ↔ RuntimeCore · v7

> 作用:冻结 Aftelle UI 与 **Swift RuntimeCore** 之间的运行契约(App 内同进程调用)。**字段/结构是不动的轴**;A 方案下实现方是 Swift RuntimeCore,HTTP 仅作为未来云端/非 Apple 兼容层。
> 前提:G0 选 A(Swift RuntimeCore,见 runtime_strategy.md)。
> 状态:**已冻结(FROZEN,2026-06-30),已与 Stage 6.11 参考实现的 `load-dr` / `step` 实际返回逐字段核对**。字段命名对齐 DR v0.3 的 lattice/voice/memory(见 dr_contract_v0_3.md)。RuntimeCore(Swift)按此契约实现;HTTP 仅为未来云端/非 Apple 兼容层。
> v7 变更:**契约主体从 HTTP sidecar 改为 RuntimeCore 同进程契约**;字段结构不变。`load-dr`/`step` 表示 RuntimeCore 的加载/单步调用(下方仍以 REST 形式书写作为契约描述,Apple 端为同进程函数调用,未来云端/非 Apple 端可落为 HTTP)。

---

## 0. 约定

- 传输:**Apple 端为 App 内同进程调用**(无网络)。未来云端/非 Apple 端可将同一契约落为本地或 HTTPS 传输。
- 编码:UTF-8 JSON。
- 版本:每个响应带 `runtime_api_version`;Aftelle 定义 `minimum_supported_api_version`,不匹配则拒绝并提示。
- 当前 RuntimeCore runtime response `runtime_api_version = "6.11.0"`;`schema_version = "0.4.0"`;`runtime_version = "resident_v1_mock"`。(Apple 端同进程契约;HTTP 仅为未来云端/非 Apple 兼容层)
- DR 内 `runtime_requirements.runtime_api_version = "0.4.0"` 是 DR 运行要求字段,不等同于 RuntimeCore 运行契约版本。

---

## 1. POST /runtime/resident/load-dr —— 加载居民

**请求:**
```json
{
  "runtime_api_version": "6.11.0",
  "dr": { /* 完整 .digital_resident JSON,或本地路径 */ },
  "namespace": "default"
}
```

**响应:**
```json
{
  "runtime_api_version": "6.11.0",
  "schema_version": "0.4.0",
  "runtime_version": "resident_v1_mock",
  "ok": true,
  "resident_id": "schema_canvas",
  "dr_version": "0.3",
  "revision": "1",
  "loaded": {
    "identity": { "name": "...", "primary_language": "zh", "city_symbol": "..." },
    "lattice_state": { /* 初始 lattice state,见 §3 */ },
    "voice_profile": { "voice_id": "mock_voice", "speed": 1, "timbre": "neutral" },
    "memory_namespace": "default"
  },
  "diagnostics": {},
  "error": null
}
```

**错误响应(结构化,不暴露内部实现异常):**
```json
{ "ok": false, "error": { "code": "DR_SCHEMA_INVALID", "message": "..." } }
```

---

## 2. POST /runtime/resident/step —— 跑一轮

**请求:**
```json
{
  "runtime_api_version": "6.11.0",
  "resident_id": "schema_canvas",
  "run_id": "run_xxx",
  "input_text": "你好",
  "namespace": "default"
}
```

> `input_text` 是 Stage 7 兼容字段,字段名保留不删。RuntimeCore 内部先建模为 `EnvironmentEvent(type: "user.text", payload: { "input_text": "你好" })`,再适配到 `input_text`。长期内核模型是 environment→resident,不是 user→assistant 二元消息管线。

**响应(对齐 DR v0.3 的 runtime_plan 链路):**
```json
{
  "runtime_api_version": "6.11.0",
  "schema_version": "0.4.0",
  "runtime_version": "resident_v1_mock",
  "ok": true,
  "resident_id": "schema_canvas",
  "run_id": "run_xxx",
  "status": "completed",
  "output_text": "...",
  "lattice_state": {
    "emotion": "neutral",
    "energy": 0.5,
    "attention": 0.5,
    "motion": "idle_breathing",
    "voice_state": "speaking",
    "particle_density": 0.5,
    "color_palette": ["#7aa2f7", "#5dd39e", "#f2a65a"],
    "focus_target": "none"
  },
  "visual_state": { /* equals lattice_state */ },
  "voice_state": "speaking",
  "memory_snapshot": {},
  "trace": [ /* 见 §4 */ ],
  "execution_trace": [ /* trace 的兼容别名,内容一致 */ ],
  "diagnostics": { "execution_mode": "mock" },
  "next_action": "none",
  "error": null
}
```

> 当前 Runtime response **返回 top-level `visual_state`**,其内容直接映射当前 `lattice_state`。Aftelle 优先读取 top-level `visual_state`;`lattice_state` 是来源/同义映射,可用于调试和兼容。
> **流式**:RuntimeCore 未来可提供流式回调(逐字接收,见 §5),避免等全部生成。Stage 7 Entry Gate 当前只冻结 `step` 非流式返回。
> `next_action` 当前恒为 `"none"`(Stage 7 单步);**为 Stage 8 Agent 多步循环预留**,Stage 7 不实现循环。

---

## 3. lattice_state / voice_state schema(= Stage 7 MVP visual input)

| 字段 | 类型 | 范围/示例 |
|---|---|---|
| emotion | string | "neutral" / 情绪枚举 |
| energy | number | 0–1 |
| attention | number | 0–1 |
| motion | string | "idle_breathing" 等 |
| voice_state | string | idle/speaking/listening/muted |
| particle_density | number | 0–1 |
| color_palette | string[] | hex 颜色数组 |
| focus_target | string | "none" 或目标 id |

---

## 4. trace schema(结构化事件,可扩展)

```json
{
  "trace": [
    { "event_type": "memory.read",   "ts": "...", "detail": {} },
    { "event_type": "llm.reasoning", "ts": "...", "detail": {} },
    { "event_type": "memory.write",  "ts": "...", "detail": {} },
    { "event_type": "lattice.update","ts": "...", "detail": {} },
    { "event_type": "voice.speak",   "ts": "...", "detail": {} },
    { "event_type": "system.tick",   "ts": "...", "detail": { "mode": "noop" } }
  ],
  "execution_trace": [ /* 与 trace 内容一致,作为兼容别名 */ ]
}
```

> `trace` 是主字段,`execution_trace` 是兼容别名,两者内容一致。`event_type` 用可扩展枚举,当前对齐 runtime_plan 的步骤。**为 Stage 8 Agent 预留**:将来加 `tool_call` 等事件类型不需改 trace 结构。Aftelle Debug Panel 按 event_type 渲染。
> Stage 7 MVP 可使用 no-op tick,但 RuntimeClock/Scheduler 必须存在;trace 或测试中至少能看到最小 `system.tick` 事件。

---

## 5. ResidentLiveState(活态结构)

`ResidentLiveState` 独立于 `.digital_resident` 基因组,也独立于 long-term memory。Stage 7 只建结构,不实现 drive 逻辑。

最小字段:
```json
{
  "schema_version": "0.1",
  "resident_id": "schema_canvas",
  "mood": "neutral",
  "emotion": "neutral",
  "energy": 0.5,
  "attention": 0.5,
  "drives": {},
  "current_concerns": [],
  "relationship_state": {},
  "updated_at": "..."
}
```

该结构由 RuntimeCore runtime clock/state/tick 推进;UI 只可读取或缓存展示副本,不得写回 DR。

---

## 6. v5 协议冻结边界

权威边界见 `aftelle_runtime_boundary.md §4`;本文件只记录 Runtime API 侧落点。

**Stage 7 冻结 6 个会被真实使用的协议概念:**
- `ResidentState`
- `EmotionState`
- `VisualState`
- `MemoryEvent`
- `TraceEvent`
- `DialogueIntent`

**Stage 8+ 只留缝 5 个 reserved 名称,本文件不定义字段:**
- `ActionRequest` reserved
- `Observation` reserved
- `PermissionDecision` reserved
- `TaskState` reserved
- `SocialMessage` reserved

## 7. v5 记忆边界

权威边界见 `aftelle_runtime_boundary.md §5`;Runtime API 和后续 schema 文档必须区分:
- Private Memory → `private_memory:{resident_id}`
- Shared Session Context → `shared_session_context:{session_id}`
- Public Transcript → `public_transcript:{session_id}`

Stage 7 可只建最小表/命名空间,但语义必须分开。居民长期记忆读写只经 RuntimeCore MemoryController / ExecutionEngine;UI 侧 SessionStore / HostStateStore 只缓存会话和展示状态。

---

## 8. (可选)流式回调

```
POST /runtime/resident/step/stream  → SSE / chunked
  data: {"delta":"你"}  data: {"delta":"好"}  ...  data: {"done":true,"lattice_state":{...},"voice_state":"speaking"}
```
Stage 7 不强制流式。7.4 真实体验前优先接流式或模拟流式反馈;UI 收到首个 delta 后可开始出字 + 切 speaking 状态。最终事件带完整 top-level `visual_state` / `lattice_state` / `voice_state`。

---

## 9. 错误码(结构化,不暴露内部)

| code | 含义 |
|---|---|
| DR_SCHEMA_INVALID | DR 不合规/版本不支持 |
| RESIDENT_NOT_LOADED | step 前未 load-dr |
| PROVIDER_FAILED | LLM/TTS provider 失败(返回 fallback) |
| API_VERSION_UNSUPPORTED | 版本不匹配 |
| INTERNAL | 兜底,message 脱敏 |

---

## 10. 已核对清单(2026-06-30)

- [x] Stage 6.11 参考实现 `load-dr` 实际返回已核对,契约版本 `runtime_api_version = "6.11.0"`
- [x] 后端 `step` 实际返回 top-level `visual_state`,内容直接映射 `lattice_state`
- [x] `trace` 和 `execution_trace` 都存在,两者内容一致
- [x] `diagnostics` 存在;`memory_snapshot` 存在
- [x] 成功响应 `error = null`;失败/拒绝响应为结构化 error 对象
- [x] RuntimeCore runtime response `runtime_api_version = "6.11.0"`;DR 内 `runtime_requirements.runtime_api_version = "0.4.0"` 保持为 DR 运行要求字段

> 本文件已从"草案"改为"冻结"。Stage 7 MVP 的 `minimum_supported_api_version = "6.11.0"`。
