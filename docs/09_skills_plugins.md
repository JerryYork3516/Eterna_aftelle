# 09_skills_plugins.md — Aftelle · v5

> 这是一份**参考清单,不是现在就装的清单**。真正要装是 Stage 7 正式开工/工具配置前,按当前任务逐个评估。
> 原则:工具不是越多越好。一位老手的经验——试了 60+ 个,最后只留 10 个;列表超过 10 个就有东西崩。**宁缺毋滥。**
> 安全:✅ 官方放心 / ⚠️ 社区需看 star 和口碑 / 🚫 别碰。
> v5 变更:更新 Stage 7 工具安装时机,移除 Stage 6 未结束口径。

---

## 一、先搞清楚四个概念(别混)

| 概念 | 是什么 | 一句话 |
|---|---|---|
| **Skill(技能)** | 一个带 SKILL.md 的文件夹,教 AI 怎么做某类事 | 一张速查表 |
| **Plugin(插件)** | 打包了技能/命令的分发单位 | 一个工具箱 |
| **Hook(钩子)** | "发生某事就自动做某事"的触发器 | 自动门 |
| **MCP(连接器)** | 让 AI 连到外部应用(Xcode/GitHub) | 一座桥 |

---

## 二、现在就能用的(几乎不用"装",治 Stage 7 的病)

| 项目 | 类型 | 治什么 | 怎么用 | 安全 |
|---|---|---|---|---|
| **Karpathy 四原则** | 文字 | 烧钱四毛病(自作主张/过度工程/瞎改/没想清就冲) | 已抄进 AGENTS.md | ✅ |
| **/simplify** | Claude Code 自带 | 代码 AI 味、过度封装 | 写完复杂代码后输入,挑着用 | ✅ |
| **code-review** | 官方 | 替你做看不懂的代码审查、抓 bug | 一个阶段做完跑一次 | ✅ |
| **Codex 互补审查** | Claude Code 插件 | 替代"换 agent 群殴";两个模型各审各的、不抢额度 | 发起对抗性审查,后台跑 | ✅ |
| **Grill Me / 想清楚再写** | 一种纪律或自建 skill | 没想清就动手 | 让 AI 先盘问方案漏洞,盘清楚再写 | ✅ |

> 这一类要么抄几句话、要么是自带命令。**Stage 7 有这些就够了,别急着加别的。**

---

## 三、Stage 7 开工后再装(写 Swift 时,官方优先,一次别贪多)

| 项目 | 类型 | 治什么/帮什么 | 装的时机 | 安全 |
|---|---|---|---|---|
| **frontend-design** | 官方 Skill | 去 UI 的 AI 味,避开模板字体/紫渐变 | 做粒子 UI 时(7.3) | ✅ |
| **code-simplifier** | 官方插件 | 代码去 AI 味(行为不变前提下简化) | 合并前对复杂代码跑,挑着用 | ✅ |
| **XcodeBuildMCP** | MCP 连接器 | 让 AI 自动 build / 测试 / 跑模拟器 | 进 Xcode 后(7.1) | ⚠️ 看口碑 |
| **Context Mode** | Skill | 防会话太长崩溃、自动恢复日志 | 会话老崩时再装 | ⚠️ 社区 |
| **Caveman** | Skill | 去客套省 token(实测省输出 token) | 觉得输出啰嗦烧钱时 | ⚠️ 社区 |
| **Swift / SwiftUI Skill** | Skill | 指导 Swift 最佳实践、查常见错 | 写 Swift 时 | ⚠️ **官方优先,社区严选** |

> Swift 专用 skill 各 AI 推荐过若干(Apple Skills、Axiom、Swift Agent Skills 等),**到时挑 1-2 个 star 高、近期维护的,别全装。**

---

## 四、以后(Stage 8+)才碰,现在完全忽略

| 项目 | 用在哪 | 备注 |
|---|---|---|
| GitHub Copilot for Xcode | iOS/SwiftUI 行级补全 | 做 iOS App 时再考虑 |
| ARKit / RealityKit 相关 | AR 粒子身体 | Stage 8 |
| Server-Side Swift(Vapor 等) | 云端 Runtime | Stage 9 |
| Xcode 26.3 原生 Claude/Codex Agent | iOS 真机开发 | 做 iOS 时 |

---

## 五、🚫 不要碰的

- **"黑客代理 / 伪装 Provider 把第三方模型塞进 Xcode"** —— 灰色、不稳、来路不明。商业项目别碰。
- **来路不明的 Xcode AI 插件** —— 只用官方或高口碑社区的。
- **中转站 API** —— 会让你的核心代码经过第三方,商业项目不用。
- **一次装一大堆 skill** —— 每个 skill 都占上下文(单个建议 <2000 token,10 个就吃约 5% 上下文),装多反而烧额度、还可能互相干扰。

---

## 六、安装与管理(等开工时用)

- Claude Code:`/plugin` 浏览,官方市场 `claude-plugins-official`。Skill 放 `~/.claude/skills/` 或项目 `.claude/skills/`。
- Codex:Skill 放 `.agents/skills/`,认 `AGENTS.md`。
- **装之前先问自己:它治我哪个具体的病?治不上就别装。**
- 定期清理:数数过去 7 天真正用过几个,没用的删掉。

---

## 七、判断"要不要装"的尺子

一个工具值得装,要同时满足:
1. 它治一个我**真实存在**的病(不是"听起来有用");
2. 官方的,或社区里 **star 高 + 近期有维护**;
3. 装了之后我**记得用、用得上**。

三条缺一,就别装。

---

## 八、Stage 7 最小推荐(就这些,别超)

```
现在:Karpathy四原则(已在AGENTS) + /simplify + code-review + Codex互补审查
开工后先装:frontend-design + 1个Swift skill + XcodeBuildMCP(看口碑)
其余:用到了、确认治病了,再一个一个加
```

> 提醒:这些工具的名称、安装方式、是否官方维护,到你 Stage 7 开工时(可能还有一段时间)可能有变。**真要装时查一下当时的最新情况和 star 数,别照名字盲装。**
