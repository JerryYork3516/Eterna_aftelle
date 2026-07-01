# provider_profile_contract.md — Aftelle · v7

> 作用:定义一个 Provider 配置(LLM / TTS)长什么样、存哪里。
> 前提:G0 选 A —— **真实 provider 调用在 Swift RuntimeCore 的 ProviderRouter**,UI 只提供配置入口和状态展示,不直连。
> 状态:可用基线(简版);真实接入时按需补字段。
> v7 变更:G0 由 B 改 A;provider secret 归属改为 **Apple secure credential store / Keychain**;RuntimeCore 只用 `key_ref`。

---

## 0. 边界(对齐 runtime_strategy + safety_policy)

- Aftelle **不直连** OpenAI/Claude/Qwen。真实调用走 `RuntimeCore ProviderRouter → ProviderAdapter → ExecutionEngine`。
- Aftelle 的 Provider Profile 只是**本地配置入口 + 显示**,实际密钥在 Apple Keychain、调用在 RuntimeCore。
- Aftelle 可以提供 Provider Profile 配置入口,但不得直接发起 provider 调用;真实调用只能由 RuntimeCore ProviderRouter → ProviderAdapter 执行。
- **Provider secret 由 Apple secure credential store / Keychain 持有**;UI 只提交/更新 `key_ref`,不保存真实 key;RuntimeCore 只用 `key_ref`,不向 UI 暴露 `getSecret`。
- **Base URL / Model 不是密钥**,可作为非密钥配置由 UI 展示/提交给 RuntimeCore。
- Trace/日志只显示脱敏的 `provider_id` / `model_alias`,不显示 key、base_url。

---

## 1. ProviderProfile schema

```json
{
  "profile_id": "humanistic_llm",
  "provider_type": "llm",
  "provider_name": "deepseek",
  "base_url": "https://api.example.com/v1",
  "model": "model-name",
  "model_alias": "人文居民-主模型",
  "key_ref": "keychain://provider/humanistic_llm",
  "enabled": true,
  "stream_enabled": true,
  "timeout_ms": 30000,
  "fallback_profile_id": null
}
```

| 字段 | 说明 | 存哪 |
|---|---|---|
| profile_id | 配置唯一 id | 本地配置 |
| provider_type | `llm` / `tts` | 本地配置 |
| provider_name | 厂商标识 | 本地配置 |
| base_url | 接口地址(非密钥) | **本地配置,不进 Keychain** |
| model | 模型名 | 本地配置 |
| model_alias | 给用户/Trace 看的脱敏别名 | 本地配置 |
| key_ref | 指向 Apple Keychain 的引用,**不是 key 本身** | key 在 **Apple Keychain** |
| enabled | 是否启用 | 本地配置 |
| stream_enabled | 是否流式(LLM 应 true) | 本地配置 |
| timeout_ms | 超时 | 本地配置 |
| fallback_profile_id | 失败时回退到哪个 profile | 本地配置 |

---

## 2. TTS profile(对齐 DR voice_config)

DR v0.3 的 `voice_config.tts_profile` 当前是 `{ provider: "mock", voice_id: "mock_voice" }`。真实 TTS profile:
```json
{
  "profile_id": "humanistic_tts",
  "provider_type": "tts",
  "provider_name": "...",
  "voice_id": "...",
  "model_alias": "人文居民-音色",
  "key_ref": "keychain://provider/humanistic_tts",
  "speed": 1.0,
  "enabled": true,
  "timeout_ms": 20000,
  "fallback_profile_id": null
}
```

---

## 3. Stage 7 处理

- MVP 阶段 provider 全 mock(DR 里 provider 全是 mock 模式),profile 可先指向 mock。
- 7.4 居民打磨前接真实 LLM:在 RuntimeCore 配置真实 provider,UI 这边只提交 base_url/model/key_ref(key 进 Apple Keychain)。
- **禁止**把真实 key 写进任何 profile 文件 / DR / Git / 日志。

---

## 4. 校验规则

- `key_ref` 必须是引用,值里出现疑似真实 key(如 `sk-`)→ 拒绝保存 + 警告。
- `base_url` 只允许 https(或显式开关下的 localhost),防 SSRF。
- LLM profile 的 `stream_enabled` 默认 true(对齐"居民立刻开口")。

---

## 一句话

Provider Profile = Aftelle 侧管理"用哪个模型、地址、超时、回退"的配置入口;**key 只进 Apple Keychain(用 key_ref 指),base_url/model 是非密钥配置**;真实调用永远在 RuntimeCore,UI 不直连。
