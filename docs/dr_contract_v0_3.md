# dr_contract_v0_3.md — Aftelle 读取契约 · v7

> 作用:Aftelle 该从 `.digital_resident` 里读哪些字段、实际路径是什么、读不到怎么办。
> 数据来源:**Studio 冻结导出的真实 DR v0.3**(Freezev03.digital_resident),非假设。
> 状态:DR v0.3 Contract Freeze(2026-06-30)。Aftelle DR Loader 以本文件为准。
> v5 变更:补充 ResidentLiveState 最小结构、三种记忆命名空间;运行时 `visual_state` 路径以 `runtime_api_contract.md` 为准。

---

## 0. DR 根结构(真实 v0.3,实测)

DR 是一个 JSON 对象,根字段:
```
file_type, dr_version, dr_schema_version, protocol_version, schema_version,
revision, created_at, updated_at, not_executable,
manifest, payload, compile_info, audit_report, resident,
layers, modules, slots, runtime_requirements,
memory_config, memory_namespace, memory_policy,
lattice_config, lattice_state_schema, voice_config, safety_policy,
screen_capability_declaration, multi_resident_lattice_state, voice_state,
audit, legacy_blueprint
```

> 重要纠正:`manifest` 和 `payload` **确实存在**(此前文档误以为不存在);`revision` **确实是独立字段**(不是用 dr_version 替代)。以本文件为准。

---

## 1. 版本字段(Aftelle 必须核对)

| Aftelle 需要 | 真实路径 | 实测值 | 说明 |
|---|---|---|---|
| DR 格式版本 | `dr_version` | `"0.3"` | 大版本 |
| DR schema 版本 | `dr_schema_version` | `"0.3.0"` | |
| 协议版本 | `protocol_version` | `"0.4.0"` | |
| schema 版本 | `schema_version` | `"0.4.0"` | |
| **revision** | `revision` | `"1"` | **真实字段,直接用,不要用 dr_version 替代** |
| 是否可执行 | `not_executable` | `true` | DR 不自执行,只被 Runtime 加载 |

**版本不匹配处理**:Aftelle 定义 `supported_dr_versions = ["0.3"]`;遇到更高版本拒绝加载 + 明确提示,不带病运行。

---

## 2. 身份(identity)

| Aftelle 需要 | 真实路径 | 实测值 |
|---|---|---|
| resident_id | `manifest.resident_id` 或 `payload.resident_identity.resident_id` | `"schema_canvas"` |
| 名称 | `payload.resident_identity.name` | `"Schema Canvas"` |
| 主语言 | `payload.resident_identity.primary_language` | `"zh"` |
| 城市象征 | `payload.resident_identity.city_symbol` | `"Aftelle"` |
| 来源象征 | `payload.resident_identity.symbolic_origin` | `"Eterna Studio"` |
| 人设摘要 | `payload.resident_identity.personality_summary` | (字符串) |
| 领域焦点 | `payload.resident_identity.domain_focus` | `["memory","lattice","voice","screen_guidance"]` |
| 披露声明 | `resident.disclosure` | "AI-generated digital resident..." |

> resident_id 以 `manifest.resident_id` 为准(manifest 是顶层清单);`payload.resident_identity` 提供更多身份细节。

---

## 3. 视觉状态(visual_state = lattice)⭐

**关键**:Aftelle 的"粒子视觉状态"在 DR 里就是 `lattice_config` / `lattice_state_schema`。不要再找旧视觉字段,用 lattice。

| Aftelle 粒子需要 | 真实路径 | 实测值/类型 |
|---|---|---|
| 情绪 | `lattice_config.emotion` | `"neutral"` |
| 能量 | `lattice_config.energy` | `0.5`(0–1) |
| 注意力 | `lattice_config.attention` | (数值) |
| 运动 | `lattice_config.motion` | `"idle_breathing"` |
| 语音状态 | `lattice_config.voice_state` | (枚举) |
| 粒子密度 | `lattice_config.particle_density` | `0.5`(0–1) |
| 颜色板 | `lattice_config.color_palette` | `["#7aa2f7","#5dd39e","#f2a65a"]` |
| 焦点目标 | `lattice_config.focus_target` | `"none"` |
| 状态机 schema | `lattice_state_schema` | 同上字段的 schema |
| 状态转换策略 | `lattice_config.state_transition_policy` | `"mock_transition"` |

> 运行时 `visual_state` 路径以 `runtime_api_contract.md` 为准:Runtime `step` 当前返回 top-level `visual_state`,其内容直接映射同级 `lattice_state`;Aftelle 优先读取 top-level `visual_state`,`lattice_state` 是来源/同义映射。Aftelle Avatar State Protocol 直接对齐 `lattice_state_schema`。

---

## 4. 运行要求(runtime_requirements)

| Aftelle 需要 | 真实路径 | 实测值 |
|---|---|---|
| 需要的 slot 类型 | `runtime_requirements.required_slot_types` | `["ar","avatar","lattice","llm","memory","tool","tts"]` |
| 需要的引擎 | `runtime_requirements.required_engines` | `["llm_mock","memory_mock","tts_mock","avatar_mock","lattice_mock","screen_mock"]` |
| 需要的 provider 类型 | `runtime_requirements.required_provider_types` | `["llm","memory","tts","avatar","screen"]` |
| Runtime API 版本 | `runtime_requirements.runtime_api_version` | `"0.4.0"` |
| 执行模式 | `runtime_requirements.execution_mode` | `"mock"` |
| 降级模式 | `runtime_requirements.fallback_mode` | `"mock_fallback"` |

> 当前全是 mock。Stage 7 MVP 用 mock 跑通即可,符合 G0。注意:DR 内 `runtime_requirements.runtime_api_version = "0.4.0"` 是 DR 运行要求字段;**RuntimeCore runtime response 的 contract version = "6.11.0"**,Stage 7 Gate 以 RuntimeCore 契约版本为准。(HTTP 仅为未来云端/非 Apple 兼容层)

---

## 5. 记忆(memory)

| Aftelle 需要 | 真实路径 | 实测值 |
|---|---|---|
| memory schema 版本 | `memory_config.schema_version` / `memory_policy.schema_version` | `"0.3.0"` |
| 存储后端 | `memory_config.storage_backend` | `"sqlite"` |
| 命名空间 | `memory_namespace` / `memory_config.namespace` | `"default"` |
| 记忆类型 | `memory_config.memory_types` | (4 类) |
| 保留策略 | `memory_policy.retention_policy` | `"persistent"` |
| 读写策略 | `memory_policy.read_write_policy` | `"local_runtime"` |

### 5.1 v5 三种记忆边界与命名空间

权威边界见 `aftelle_runtime_boundary.md §5`;schema 文档必须区分:
- Private Memory:居民自己的记忆,他人不可见。
- Shared Session Context:当前会话共享上下文。
- Public Transcript:用户可见的对话记录。

落地命名空间:
- Private Memory → `private_memory:{resident_id}`
- Shared Session Context → `shared_session_context:{session_id}`
- Public Transcript → `public_transcript:{session_id}`

Stage 7 允许先使用最小表/命名空间表达能力,但不得把三者语义混成一种长期记忆。居民长期记忆读写只经 RuntimeCore MemoryController / ExecutionEngine;UI 只缓存会话与展示状态。

---

## 5.2 v5 ResidentLiveState(活态结构)

`ResidentLiveState` 是 runtime 活态,独立于 DR 基因组,也独立于 long-term memory。Stage 7 只建结构,不实现 drive 逻辑。

最小字段:
- `schema_version`
- `resident_id`
- `mood` / `emotion`
- `energy`
- `attention`
- `drives`
- `current_concerns`
- `relationship_state`
- `updated_at`

RuntimeCore runtime clock/state/tick 拥有并推进该状态;UI 可读取/缓存展示副本,不得写回 DR 文件。

---

## 5.3 v5 协议冻结边界

权威边界见 `aftelle_runtime_boundary.md §4`;本文件只记录 DR/schema 侧落点。

**Stage 7 冻结 6 个:**
- `ResidentState`
- `EmotionState`
- `VisualState`
- `MemoryEvent`
- `TraceEvent`
- `DialogueIntent`

**Stage 8+ 只留缝 5 个 reserved 名称,勿定字段:**
- `ActionRequest` reserved
- `Observation` reserved
- `PermissionDecision` reserved
- `TaskState` reserved
- `SocialMessage` reserved

---

## 6. 语音(voice / TTS)

| Aftelle 需要 | 真实路径 | 实测值 |
|---|---|---|
| voice schema 版本 | `voice_config.schema_version` | `"0.3.0"` |
| TTS provider | `voice_config.tts_profile.provider` | `"mock"` |
| voice_id | `voice_config.tts_profile.voice_id` / `voice_profile.voice_id` | `"mock_voice"` |
| 语速/音色 | `voice_config.voice_profile.speed` / `.timbre` | `1` / `"neutral"` |
| 语音状态枚举 | `voice_config.voice_state_schema.voice_state` | `["idle","speaking","listening","muted"]` |
| 字幕策略 | `voice_config.subtitle_policy` | (dict) |
| 语音输入事件 | `voice_config.speech_event_schema` | placeholder(语音输入仅预留) |

---

## 7. 安全(safety)

| Aftelle 需要确认 | 真实路径 | 实测值 |
|---|---|---|
| DR 无密钥 | `safety_policy.no_secret_in_dr` | `true` ✅ |
| 不直连 provider | `safety_policy.no_direct_provider_binding` | `true` ✅ |
| 仅 mock 屏幕 | `safety_policy.mock_screen_only` | `true` |
| 用户数据不内嵌 | `safety_policy.user_data_not_embedded` | `true` ✅ |
| 不可执行 | `safety_policy.not_executable` | `true` ✅ |

> 这些 flag 已由 Studio 保证。Aftelle 加载时可断言这些为 true,否则拒绝加载(防被篡改的 DR)。

---

## 8. 运行链路(runtime_plan,UI 参考即可,执行在 RuntimeCore)

`payload.runtime_plan.steps` 已定义命脉链路(与 RuntimeCore runtime_plan 一致;Aftelle 架构上按 environment event→resident 抽象):
```
environment_event → memory.read → llm.reasoning → memory.write → lattice.update → voice.speak
```
`payload.fallback_routes`:每个能力(llm/memory/tts/lattice/screen)都有 mock fallback 路由。

> UI 不执行此链路(RuntimeCore 执行),但 Trace/Debug 面板可据此展示步骤。

---

## 9. Aftelle 暂不读 / 读而不用(为后续留)

| 字段 | Stage 7 处理 |
|---|---|
| `layers` / `modules`(143) / `slots` | 不解析内部(那是 Studio/Runtime 的事),Aftelle 不依赖 |
| `manifest.required_capabilities` | **读取保存,不执行**(为 Stage 8 Agent 能力留) |
| `screen_capability_declaration` | 读取,Stage 7 仅 mock 屏幕指导 |
| `legacy_blueprint` | 忽略(旧蓝图,兼容用) |
| `multi_resident_lattice_state` | 读取,双居民(7.7)才用 |

---

## 一句话

Aftelle 读 DR v0.3 时:**身份看 `manifest`+`payload.resident_identity`;视觉看 `lattice_config`;运行时视觉状态优先读 top-level `visual_state`,`lattice_state` 是来源/同义映射,并同时使用 `voice_state`;记忆边界按三种命名空间分开;语音看 `voice_config`;版本用真实的 `revision` 字段;安全 flag 必须全 true 否则拒载。** 内部 layers/modules 不碰。
