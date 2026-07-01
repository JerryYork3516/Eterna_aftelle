# 04_code_standards.md — Aftelle Desktop · v7

> 严格执行。本规范的条目是**规矩,不是建议**。违反即不合格,PR 不合并。
> 优先级:六红线 > 强制项 > 风格项。能被工具自动检测的,一律交给工具强制,不靠自觉。
> v7 变更:G0 由 B 改 A;密钥归 Apple Keychain;完整 DR 校验归 RuntimeCore;runtime-core 目录承载 Swift RuntimeCore。

---

## 0. 总纲

**身体尽情用 Apple 原生技术做到极致;大脑(Runtime)必须保持平台无关。**
任何为了性能而让大脑依赖具体平台的代码,无论多快,都判定为错误。

---

## 1. 技术栈(锁定,不得擅自更换)

| 层 | 技术 | 强制 |
|---|---|---|
| 语言 | Swift(版本写入 `.swift-version`,首日锁定) | 是 |
| UI | SwiftUI(仅用于设置、文件选择等系统刚需,App 主体是粒子) | 是 |
| 粒子渲染 | Metal | 是 |
| 本地存储 | SQLite(经 HostEnv 访问) | 是 |
| 密钥 | Apple Keychain(经 `key_ref` 引用) | 是 |
| 格式化 | SwiftFormat | 强制,提交前自动跑 |
| 静态检查 | SwiftLint | 强制,提交前自动跑 |

- **禁止**在未经讨论的情况下引入任何新的第三方依赖。需要新依赖必须先说明理由并获批。
- **禁止**为图快换用未锁定的技术(如临时改用别的渲染方式)。

---

## 1.1 文字与语言规范

第七阶段只做单语言(中文/中英),不做界面多语言切换系统。多语言切换属于 Stage 8+ 能力,Stage 7 不为它提前做复杂系统。

**用户可见文字必须集中管理:**
- 使用 Swift 的 `String(localized:)` + `Localizable.strings` 或 `.xcstrings`,哪怕当前只有一种语言。
- 禁止在 View / Controller / Runtime 逻辑里硬编码用户可见字符串。
- 目的:将来加语言 = 加翻译文件,不是满代码查找替换。

**底层文字正确性(Stage 7 必做):**
- 编码统一 UTF-8。
- 字幕 / 粒子文字渲染必须使用支持中文的字体,避免中文显示成方块。
- UI / 字幕布局不得写死宽度;中英文长度差异大,必须保留弹性。
- TTS Provider 必须支持中文音色。

**居民说话语言:**
- 居民"说"的语言由 DR 字段 `payload.resident_identity.primary_language` 决定;真实 DR 当前值为 `"zh"`。
- App 界面语言不得写死居民输出语言。

---

## 2. 目录结构(强制,违反即架构错误)

```
brain/            平台无关大脑。禁止任何 Apple/平台依赖。
  runtime-core/   RuntimeCoreInterface + OrchestrationKernel + DRLoader + Trace
  soul/           AvatarState / ParticleLogic / EmotionMapping(纯逻辑,无画法)
  hostenv/        HostEnv 协议定义
platform-macos/   macOS 原生身体
  app-shell/      SwiftUI 外壳
  particle-render/ Metal 画法
  input/          鼠标/键盘 → Intent 翻译
  audio/          TTS / 字幕
  hostenv-macos/  HostEnv 的 macOS 实现
shared-protocol/  DR schema、协议常量
```

**硬规则:**
- `brain/` 内**禁止出现** `import Metal` / `import AppKit` / `import SwiftUI` / 直接 SQLite/Keychain 调用。→ **可自动检测,设为 lint/hook 规则。**
- 平台实现文件名带平台后缀:`HostEnvMacOS`、`ParticleRendererMetal`。
- 一个文件一个主类型,文件名 = 主类型名。

---

## 3. 六条红线(零容忍)

| # | 红线 | 自动可检测? |
|---|---|---|
| 1 | 大脑不碰平台(brain 内无平台 import,只走 HostEnv) | ✅ 可自动扫 |
| 2 | 所有存储表含 `schema_version` 字段(不强制第一列)+ schema_migrations 表 | ✅ 可自动扫建表语句 |
| 3 | UI 不直接调 LLM/读 DR/写居民长期 Memory,严格分层 | ⚠️ 部分需人审 |
| 4 | DR 只读;不把记忆/状态/Key 写回 DR | ⚠️ 需人审 |
| 5 | 粒子逻辑(brain/soul)与画法(platform/particle-render)分离 | ⚠️ 看目录归属 |
| 6 | 逻辑层只认 Intent,不写死鼠标/触摸坐标 | ⚠️ 需人审 |

**✅ 标记的设成自动检测(lint/hook),违反则提交失败;⚠️ 标记的由审查 AI/人首查。**

---

## 4. 命名(强制)

- 类型/协议:`UpperCamelCase`(`RuntimeKernel`、`HostEnv`)
- 函数/变量:`lowerCamelCase`(`callLLM`、`particleDensity`)
- 协议:能力型 `SessionStoring` / `HostStateStoring`,契约型名词 `HostEnv`
- Intent 统一前缀:`Intent.attentionApproached`
- **禁止机械直译命名、禁止无意义缩写**(`drv`、`mgr2` 等)。`dr` 仅指 digital_resident。
- 命名要让人不看注释也能懂用途。

---

## 5. 代码去 AI 味(强制,这是本规范的重点)

AI 生成的代码有典型坏味道,以下**全部禁止**,审查时首查:

1. **禁止过度注释**:不要每行都解释、不要注释显而易见的代码。只在复杂或不直观的逻辑处注释,且解释"为什么"而非"做了什么"。
2. **禁止过度工程**:50 行能解决的不许写 500 行。禁止为"未来可能用到"做防御性封装、加无用的抽象层、配置项、接口。**YAGNI——用不到就别写。**
3. **禁止防御性废代码**:不要到处加"以防万一"的空 catch、冗余判空、永远不会进的分支。
4. **禁止机械啰嗦**:不要把一个简单操作拆成一堆中间变量和样板;不要写 AI 爱写的那种"工整但空洞"的代码。
5. **函数短小、单一职责**:一个函数只做一件事;过长(经验值:超过约 50 行)必须拆,除非拆了更难读。
6. **跟随现有风格**:动手前先读周边代码,风格跟着它走,不另起一套。
7. **外科手术式修改**:只改目标逻辑,**严禁顺手改周围无关代码或重新格式化整个文件**。

> 判断标准:**这段代码像一个有经验的工程师为了解决这个具体问题写的,还是像 AI 为了"看起来完整"堆出来的?** 后者一律重写。

---

## 6. 注释与文档

- 公开接口(HostEnv、协议)写简短文档注释,说明契约和约束。
- 内部实现少注释,代码本身要自解释。
- **禁止 AI 生成的那种泛泛注释**(`// 初始化变量`、`// 调用函数`)。

---

## 7. 错误处理

- 错误要么处理、要么明确向上抛,**禁止空 catch 吞掉错误**。
- 用户可见的失败(DR 加载失败、provider 失败)必须有明确提示和降级路径。
- Aftelle DR 浅校验失败、未知高危字段:**拒绝加载并报错**,不许"宽容地"带病运行。浅校验只包含版本/大小/安全 flag/必要字段/未知高危字段;完整 DR schema 校验由 RuntimeCore 执行。
- **schema_version 不匹配**:Stage 7 不做迁移,但遇到不匹配不能崩——允许清空该表重建,并在日志记录;遇到比支持版本更高的 DR/记忆版本,拒绝并给明确提示(定义 `minimum_dr_version` / `supported_schema_versions`)。
- **Provider 失败降级**:超时 / 401 / 429 / 网络失败 / 模型不存在 / TTS 失败,分别定义 UI 提示、Trace 记录、是否重试、是否回退;不要静默失败。
- **DR 文件安全限制**:最大文件大小限制;禁止自动远程加载;禁止执行内嵌脚本字段;资源路径必须在沙盒内解析(防路径遍历)。
- **本地数据库损坏**:SQLite 损坏/写入失败/磁盘满时,提供安全模式启动 + 重置本地状态选项,不直接崩。

---

## 8. 安全(强制,零容忍)

- **Provider secret 只进 Apple Keychain**(经 `key_ref` 引用)。UI 只提交/更新 `key_ref`,RuntimeCore 只用 `key_ref`,不向 UI 暴露 `getSecret`。**Base URL / Model 不是密钥**,可作为非密钥配置展示/提交给 RuntimeCore。
- key / base_url / model 都**禁止**出现在 DR / Slot / Trace / Memory / 日志 / Git / 源码常量里。Trace 只显示脱敏的 provider_id / model_alias。→ 可自动扫源码里的疑似 key。
- **Provider Base URL 只允许 https,或显式开关下的 localhost**(防 SSRF);拒绝任意内网/自签地址默认放行。
- **Trace Redaction**:Trace/日志不记录 API Key、完整 prompt 中的敏感内容、完整 provider 响应、用户本地绝对路径。
- 真实 `.digital_resident` 文件、密钥**禁止进 Git**(.gitignore 锁死)。
- 日志里禁止打印任何密钥、完整 API 响应中的敏感字段。

---

## 9. 粒子代码的特别要求

因为 AI 看不见屏幕:
- 粒子系统必须能输出结构化日志:粒子数、坐标范围、颜色、FPS、当前 Avatar State。
- **禁止只凭"应该对了"提交粒子代码**——必须有日志或 Previews 截图佐证。
- 粒子逻辑(数学/状态)写在 `brain/soul`,可独立测试;画法(GPU)写在 `platform-macos`。两者不得混写。

---

## 10. 提交(强制)

- 跨文件修改前**先 commit 一次**作为回滚点。
- 提交信息:`[阶段号] 简述`,如 `[7.1] DR Loader 只读加载`。
- 提交前自动跑:SwiftFormat + SwiftLint + 红线自动检测,**不通过不许提交**(设为 pre-commit hook)。

---

## 11. 完成的定义

一个改动算"完成",必须同时满足:
1. 编译通过;
2. SwiftFormat / SwiftLint / 红线检测全过;
3. 功能用手动操作或日志验证跑通;
4. 未违反任何红线、未触碰授权范围外的文件。

**缺任一条都不算完成,不许报"做完了"。**

---

## 12. 自动化优先原则

凡是机器能拦的,绝不靠人和 AI 的自觉:
- 格式/命名 → SwiftFormat/SwiftLint
- `brain/` 平台 import、建表无版本号、源码疑似 key → 自动检测脚本 / pre-commit hook
- 跨文件改动 → 强制 commit 钩子

**本规范里 ✅ 标记的条目,开工后逐条做成自动检测。文档只兜底机器拦不住的部分。**
