---
name: profile-model-manager
description: "查看、更换和管理 Hermes 各 profile 的大模型配置（主模型、辅助模型、delegation 模型）。支持单个/批量操作、切换 provider、全 profile 一览。"
version: 3.1.0
author: 贾维斯
metadata:
  hermes:
    tags: [hermes, model, provider, profile, configuration]
    related_skills: [hermes-agent, auxiliary-model-config]
---

# Profile Model Manager

管理 Hermes 各 profile 的全部模型配置——主模型、辅助模型（vision / compression / web_extract / session_search）、delegation 模型。支持查看、切换、批量操作。

> **适用场景：** 需要查看或切换 Hermes 各 profile 的大模型时使用本 skill。
> **不适用场景：** 安装新 provider、配置 API Key（参见 `hermes-agent` skill）；管理 MCP 模型（参见 `native-mcp` skill）。

---

## 🤖 Agent 智能触发与自动执行指引

**⚠️ 核心原则：Agent 是智能助手，不是文档阅读器。用户说意图，Agent 来执行。**

### 触发条件

| 用户意图 | 触发关键词示例 | Agent 应执行的操作 |
|---|---|---|
| 查看当前模型 | "现在用的什么模型"、"模型配置"、"看看模型" | 自动运行 `bash ~/.hermes/scripts/profile-model-overview.sh` 并解读结果 |
| 切换模型 | "换成 xxx 模型"、"切到 xxx"、"用 glm-5" | 自动执行 §3.1 完整流程（含检查 key → set → restart → 验证） |
| 批量操作 | "所有 profile 都换成"、"统一切换" | 自动执行 §3.4 批量脚本，并逐个验证结果 |
| 诊断问题 | "模型报错了"、"切换不生效" | 自动运行诊断命令，定位问题，给出一键修复命令 |
| 辅助模型 | "vision 模型"、"compression 模型" | 自动执行 §3.2 流程 |
| delegation | "子 agent 用什么模型"、"delegate 便宜点" | 自动执行 §3.3 流程 |

### Agent 自动执行决策树

```
用户表达意图
  │
  ├─ 查看类 → 直接运行 overview 脚本 + 解读
  │
  ├─ 切换类 → 执行完整 6 步流程：
  │   Step 1: 运行 overview 确认当前状态
  │   Step 2: 检查目标 provider 的 API Key 是否存在
  │           → 缺 key？先告诉用户，不要继续
  │   Step 3: 执行 hermes config set（model + provider + base_url）
  │           → ⚠️ 选择 base_url 时必须判断（见下方 Z.AI vs zai 规则）
  │   Step 4: 重启 Gateway（hermes -p <name> gateway restart）
  │   Step 5: 验证生效（config show + 测试消息）
  │   Step 6: 展示切换前后对比
  │
  ├─ 诊断类 → 执行诊断流程：
  │   Step 1: 运行 overview 看配置
  │   Step 2: 检查 Gateway 状态
  │   Step 3: 查看最近错误日志（hermes -p <name> gateway logs --tail 20）
  │   Step 4: 根据错误类型执行 §7 对应修复
  │
  └─ 不确定 → 先展示当前状态，问用户想做什么
```

### ⚠️ Agent 必须遵守的规则

1. **切换操作必须包含完整链路**：检查 key → set model → set provider → set base_url → restart → 验证。不能只做其中一步。
2. **Z.AI vs zai base_url 选择**：切换到智谱模型时，**必须根据模型用途选择正确的 base_url**，不能一律设为 coding plan：
   - **Vision（glm-4.6v）** → base_url = `https://open.bigmodel.cn/api/paas/v4`（Z.AI 直连端）
   - **其余所有模型**（主模型/Compression/WebExtract/SessionSearch/Delegation） → base_url = `https://open.bigmodel.cn/api/coding/paas/v4`（zai coding plan 端）
3. **切换后必须验证**：不能改完配置就结束，必须 `config show` 确认写入成功 + `gateway restart` 确认重启。
4. **缺 key 时主动阻止**：发现目标 provider 的 API Key 不存在时，不要盲目继续，应告知用户并提供添加 key 的命令。
5. **批量操作前备份**：执行批量切换前，先备份所有 profile 的 config.yaml。
6. **default profile 不加 -p**：对 default 操作时不加 `-p` 参数。

---

## 0. 快速开始

**30 秒上手：**

```bash
# 1. 查看当前所有 profile 模型全景
bash ~/.hermes/scripts/profile-model-overview.sh

# 1b. 诊断模式（含 Gateway 状态 + API Key 检查）
bash ~/.hermes/scripts/profile-model-overview.sh --diagnose
```

**预期输出示例：**
```
┌──────────────┬─────────────────┬──────────┬─────────────────┬─────────────────┬─────────────────┐
│ Profile      │ Model           │ Provider │ Vision          │ Compression     │ Delegation      │
├──────────────┼─────────────────┼──────────┼─────────────────┼─────────────────┼─────────────────┤
│ default      │ mimo-v2.5-pro   │ xiaomi   │ mimo-v2-omni    │ mimo-v2.5       │ mimo-v2.5       │
│ cto          │ mimo-v2.5-pro   │ xiaomi   │ mimo-v2-omni    │ mimo-v2.5       │ mimo-v2.5       │
│ diary        │ mimo-v2.5-pro   │ xiaomi   │ mimo-v2-omni    │ mimo-v2.5       │ mimo-v2.5       │
│ ...          │ ...             │ ...      │ ...             │ ...             │ ...             │
└──────────────┴─────────────────┴──────────┴─────────────────┴─────────────────┴─────────────────┘
```

```bash
# 2. 切换 default profile 主模型（必须显式设 base_url）
hermes config set model.default glm-5-turbo
hermes config set model.provider zai
hermes config set model.base_url https://open.bigmodel.cn/api/coding/paas/v4

# 3. 重启生效
hermes gateway restart
```

**前置条件：**
- Hermes Agent 已安装（`hermes --version` 可用）
- 目标 provider 的 API Key 已配置在对应 profile 的 `.env` 中
- 切换后必须重启 Gateway 才能生效

---

## 1. 模型配置架构

每个 profile 的 `config.yaml` 中有三个模型相关配置块：

```yaml
model:          ← 主模型（对话用）
auxiliary:      ← 辅助模型（vision / compression / web_extract / session_search）
delegation:     ← 子 agent 模型（delegate_task 时使用）
```

### 1.1 主模型 `model:`

```yaml
model:
  default: mimo-v2.5-pro        # 模型名称
  provider: xiaomi               # provider 名称
  base_url: https://...          # API 端点（部分 provider 可省略）
  api_key: xxx                   # 可选，也可放 .env
  context_length: 200000         # 上下文窗口大小
  api_mode: chat_completions     # API 模式
```

### 1.2 辅助模型 `auxiliary:`

```yaml
auxiliary:
  vision:                        # 图片分析、截图识别
    provider: xiaomi
    model: mimo-v2-omni
    base_url: https://...
    timeout: 120
  compression:                   # 上下文压缩
    provider: xiaomi
    model: mimo-v2.5
    base_url: https://...
    timeout: 120
  web_extract:                   # 网页内容提取
    provider: xiaomi
    model: mimo-v2.5
    base_url: https://...
    timeout: 360
  session_search:                # 历史会话搜索
    provider: xiaomi
    model: mimo-v2.5
    base_url: https://...
    timeout: 30
    max_concurrency: 3
```

### 1.3 Delegation 模型 `delegation:`

```yaml
delegation:
  model: mimo-v2.5               # 空则继承主模型
  provider: xiaomi
  base_url: ''                   # 空则继承主模型 base_url
  reasoning_effort: ''
  max_iterations: 50
  max_concurrent_children: 3
```

---

## 2. 查看模型配置

```bash
# 查看 default profile 的完整配置
hermes config show

# 查看指定 profile 的主模型
cat ~/.hermes/profiles/<name>/config.yaml | grep -A5 "^model:"

# 查看指定 profile 的辅助模型
cat ~/.hermes/profiles/<name>/config.yaml | grep -A20 "^auxiliary:"

# 查看指定 profile 的 delegation 模型
cat ~/.hermes/profiles/<name>/config.yaml | grep -A10 "^delegation:"

# 一键查看所有 profile 模型全景
bash ~/.hermes/scripts/profile-model-overview.sh
```

**`hermes config show` 预期输出（片段）：**
```yaml
model:
  default: mimo-v2.5-pro
  provider: xiaomi
  base_url: https://token-plan-cn.xiaomimimo.com/v1
  context_length: 200000
  api_mode: chat_completions
auxiliary:
  vision:
    provider: xiaomi
    model: mimo-v2-omni
  compression:
    provider: xiaomi
    model: mimo-v2.5
  ...
```

**⚠️ 注意：** 如果 `cat` 命令返回空，说明 config.yaml 中没有该配置块。此时需要检查是否使用了正确的 profile 路径：`~/.hermes/profiles/<name>/config.yaml`（注意 `default` profile 的路径是 `~/.hermes/config.yaml`）。

---

## 3. 切换模型

### 3.1 切换单个 profile 的主模型

```bash
# 对 default profile（不加 -p 参数）
hermes config set model.default <model_name>
hermes config set model.provider <provider>
hermes config set model.base_url <base_url>

# 对其他 profile（必须加 -p <name>）
hermes -p <profile> config set model.default <model_name>
hermes -p <profile> config set model.provider <provider>
hermes -p <profile> config set model.base_url <base_url>
```

**操作效果示例：**
```bash
$ hermes -p reasoner config set model.default glm-5.1
✅ Set model.default = glm-5.1

$ hermes -p reasoner config set model.provider zai
✅ Set model.provider = zai

$ hermes -p reasoner config set model.base_url https://open.bigmodel.cn/api/coding/paas/v4
✅ Set model.base_url = https://open.bigmodel.cn/api/coding/paas/v4
```

**切换后必须重启：**
```bash
hermes -p <profile> gateway restart
```

**重启效果：**
```bash
$ hermes -p reasoner gateway restart
🔄 Restarting gateway for profile 'reasoner'...
✅ Gateway restarted successfully
```

### 3.2 切换辅助模型

```bash
# Vision → Z.AI 直连端（⚠️ glm-4.6v 是唯一多模态模型，必须走直连端 /api/paas/v4）
hermes config set auxiliary.vision.provider zai
hermes config set auxiliary.vision.model glm-4.6v
hermes config set auxiliary.vision.base_url https://open.bigmodel.cn/api/paas/v4

# 其余辅助模型 → zai coding plan 端（⚠️ 不是直连端！是 /api/coding/paas/v4）
hermes config set auxiliary.compression.provider zai
hermes config set auxiliary.compression.model glm-4.5-air
hermes config set auxiliary.compression.base_url https://open.bigmodel.cn/api/coding/paas/v4

hermes config set auxiliary.web_extract.provider zai
hermes config set auxiliary.web_extract.model glm-4.5-air
hermes config set auxiliary.web_extract.base_url https://open.bigmodel.cn/api/coding/paas/v4

hermes config set auxiliary.session_search.provider zai
hermes config set auxiliary.session_search.model glm-4.5-air
hermes config set auxiliary.session_search.base_url https://open.bigmodel.cn/api/coding/paas/v4
```

> **为什么 Vision 走直连而其余走 coding plan？**
> - glm-4.6v 是多模态视觉模型，Coding Plan 端（`/api/coding/paas/v4`）不支持多模态输入，只有直连端（`/api/paas/v4`）支持图片传入
> - 其余辅助模型（compression/web_extract/session_search）是纯文本模型，走 Coding Plan 端更便宜且不影响并发

Per-profile 用法同理加 `-p <name>`。

### 3.3 切换 Delegation 模型

```bash
hermes -p <profile> config set delegation.model <model>
hermes -p <profile> config set delegation.provider zai
hermes -p <profile> config set delegation.base_url https://open.bigmodel.cn/api/coding/paas/v4
```

设为空字符串即回到继承主模型的行为：
```bash
hermes -p <profile> config set delegation.model ""
hermes -p <profile> config set delegation.provider ""
```

### 3.4 批量操作所有 profile

```bash
# 切换所有 profile 主模型（必须显式设 base_url）
for p in default cto diary genshin reasoner scout qian-duoduo; do
  if [ "$p" = "default" ]; then
    hermes config set model.default glm-5-turbo
    hermes config set model.provider zai
    hermes config set model.base_url https://open.bigmodel.cn/api/coding/paas/v4
  else
    hermes -p "$p" config set model.default glm-5-turbo
    hermes -p "$p" config set model.provider zai
    hermes -p "$p" config set model.base_url https://open.bigmodel.cn/api/coding/paas/v4
  fi
done
```

### 3.5 批量重启 Gateway

```bash
# 重启所有运行中的 profile
hermes profile list 2>/dev/null | grep "running" | awk '{print $1}' | sed 's/◆//' | while read p; do
  hermes -p "$p" gateway restart
done
```

### 3.6 操作后验证（重要！）

每次切换后，务必执行验证确认生效：

```bash
# 方法 1：查看配置是否写入成功
hermes -p <profile> config show | grep "default:" -A1

# 预期输出：
#   default: glm-5.1      ← 看到这里是新模型名就对了

# 方法 2：发送测试消息确认模型实际响应
hermes -p <profile> chat -q "你是什么模型？回答模型名称即可" -Q

# 方法 3：确认 Gateway 状态
hermes -p <profile> gateway status

# 预期输出：
# ◆ reasoner: running     ← 必须是 running
```

**⚠️ 如果验证方法 2 的回答仍是旧模型**，说明 Gateway 没有成功重启，请重新执行 `hermes -p <profile> gateway restart`。

---

## 4. Provider 速查表

| Provider | Env 变量 | Base URL | 说明 |
|---|---|---|---|
| `xiaomi` | `XIAOMI_API_KEY` | `https://token-plan-cn.xiaomimimo.com/v1` | 小米 MiMo |
| **`zai`** | `GLM_API_KEY` | `https://open.bigmodel.cn/api/coding/paas/v4` | **zai = Coding Plan 端** — 主模型、Compression、WebExtract、SessionSearch、Delegation 全部用此端 |
| **`Z.AI`** | `GLM_API_KEY` | `https://open.bigmodel.cn/api/paas/v4` | **Z.AI = 直连端** — **仅 Vision（glm-4.6v）使用**，其他模型禁止走此端 |

**⚠️ Z.AI vs zai 核心规则（2026-06-22 确立，Agent 切换模型时必须遵守）：**

这两个名称指向**同一个 Env 变量** `GLM_API_KEY`，但 **base_url 完全不同**，Agent 切换模型时**必须根据模型用途选择正确的端点**，不能统一设为 coding plan：

| 用途 | Provider 名 | base_url | 命名 |
|---|---|---|---|
| **主模型**（对话/推理） | `zai` | `https://open.bigmodel.cn/api/coding/paas/v4` | zai Coding Plan 端 |
| **Vision**（glm-4.6v，唯一多模态） | `zai` | `https://open.bigmodel.cn/api/paas/v4` | **Z.AI 直连端** |
| **Compression / WebExtract / SessionSearch** | `zai` | `https://open.bigmodel.cn/api/coding/paas/v4` | zai Coding Plan 端 |
| **Delegation** | `zai` | `https://open.bigmodel.cn/api/coding/paas/v4` | zai Coding Plan 端 |

**一句话口诀：Vision 走 Z.AI 直连，其余全走 zai coding plan。**

- `config.yaml` 中 `base_url` 必须显式指定，不能留空让 Hermes 自动探测（内置默认 `api.z.ai` 是全球直连端，会导致非 Vision 模型走错端）
| `openrouter` | `OPENROUTER_API_KEY` | — | OpenRouter |
| `anthropic` | `ANTHROPIC_API_KEY` | — | Anthropic Claude |
| `deepseek` | `DEEPSEEK_API_KEY` | — | DeepSeek |
| `xai` | `XAI_API_KEY` | — | xAI Grok |
| `gemini` | `GOOGLE_API_KEY` | — | Google Gemini |
| `openai-codex` | — (OAuth) | — | OpenAI Codex |
| `copilot` | `COPILOT_GITHUB_TOKEN` | — | GitHub Copilot |
| `kimi-coding` | `KIMI_API_KEY` | — | Kimi/Moonshot |
| `minimax` | `MINIMAX_API_KEY` | — | MiniMax |
| `alibaba` | `DASHSCOPE_API_KEY` | — | 阿里 DashScope |

**自定义 Provider** 在 `config.yaml` 的 `custom_providers:` 中定义：
```yaml
custom_providers:
- name: zai
  base_url: https://open.bigmodel.cn/api/coding/paas/v4
  api_key: xxx
  api_mode: chat_completions
```

**⚠️ Base URL 规则：**
- 内置 provider（xiaomi/zai/openrouter 等）：`base_url` 可省略，Hermes 自动填充
- **Z.AI 有 4 个端点**（见 `hermes-gateway-api-key-debug` → `references/zai-endpoint-architecture.md`）：Coding Plan 端（`/api/coding/paas/v4`）支持 glm-5.1/glm-4.7 等新模型；直连端（`/api/paas/v4`）只支持 glm-5 及标准模型。国内用户应选 `open.bigmodel.cn` 而非 `api.z.ai`。**建议始终显式指定 base_url**，避免自动探测选错端点或区域。
- **⚠️ Z.AI 解析优先级陷阱：** `config.yaml` 中 `providers.zai.api` 只是**兜底值**，不是权威覆盖。优先级为：`GLM_BASE_URL` 环境变量 > `auth.json` 缓存 > 探测结果 > `providers.zai.api`。要确保一致性，最可靠的做法是设置环境变量 `GLM_BASE_URL=<desired_url>`。详见 `hermes-gateway-api-key-debug` → `references/zai-endpoint-architecture.md` § "Base URL Resolution Priority Chain"。
- 自定义 provider：`base_url` **必须**显式指定，否则报错
- 切换 provider 时如果两个 provider 的 `base_url` 不同，**必须同时设置** `base_url`

---

## 5. 模型参考

### 智谱 ZAI

| 模型 | 上下文 | 最大输出 | 适用场景 |
|---|---|---|---|
| `glm-5-turbo` | 200K | 128K | 主模型（对话/推理） |
| `glm-5` | 200K | 128K | 通用推理 |
| `glm-5.1` | 200K | 128K | 复杂推理 |
| `glm-4.7` | 200K | 128K | 旧版主力 |
| `glm-4.6v` | 128K | — | **Vision 专用**（唯一多模态） |
| `glm-4.5-air` | 128K | — | **辅助模型首选**（compression/web_extract，轻量不抢并发） |

推荐搭配：主模型 glm-5-turbo + Vision glm-4.6v + 辅助(glm-4.5-air)

文档：https://docs.bigmodel.cn/cn/guide/start/model-overview

### 小米 MiMo

| 模型 | 上下文 | 适用场景 |
|---|---|---|
| `mimo-v2.5-pro` | 1M | 通用对话、长上下文 |
| `mimo-v2.5` | 1M | 辅助模型、高性价比 |
| `mimo-v2-omni` | — | 多模态（vision） |

### DeepSeek V4

| 模型 | 上下文 | 最大输出 | 适用场景 | 定价（输入/输出/缓存命中） |
|---|---|---|---|---|
| `deepseek-v4-flash` | 1M | 384K | **Agent 首选**：工具调用、搜索、日常问答 | $0.14 / $0.28 / $0.0028 per M tokens |
| `deepseek-v4-pro` | 1M | 384K | 复杂推理、代码、长文档分析 | $0.435 / $0.87 / $0.003625 per M tokens |

**V4 Flash 架构亮点（CSA+HCA）：**
- 总参 2840 亿，激活 130 亿（MoE）
- KV Cache 仅为 V3.2 的 **7%**，推理 FLOPs 仅为 V3.2 的 **10%**
- 100 万 tokens 上下文，缓存命中价低至 ~0.1 元/百万 tokens
- 注意：`deepseek-chat`（旧名）≈ Flash 非思考模式，`deepseek-reasoner`（旧名）≈ Flash 思考模式

**⚠️ 思考模式有坑：** DeepSeek V4 默认开启 thinking 模式，但 Hermes Agent 工具调用场景下必须禁用——详见 §13。

---

## 6. 典型工作流

### 场景 1：临时切换测试模型

```bash
# 切到测试模型
hermes -p reasoner config set model.default glm-5.1
hermes -p reasoner config set model.provider zai
hermes -p reasoner config set model.base_url https://open.bigmodel.cn/api/coding/paas/v4
hermes -p reasoner gateway restart

# ✅ 验证切换成功
hermes -p reasoner config show | grep "default:" -A1
# 预期输出：
#   default: glm-5.1

# 测试模型是否正常响应
hermes -p reasoner chat -q "你好，请确认你的模型名称" -Q
# 预期输出应提到 glm-5.1 或智谱

# 测试完毕后切回
hermes -p reasoner config set model.default mimo-v2.5-pro
hermes -p reasoner config set model.provider xiaomi
hermes -p reasoner gateway restart

# ✅ 验证切回成功
hermes -p reasoner config show | grep "default:" -A1
# 预期输出：
#   default: mimo-v2.5-pro
```

### 场景 2：所有 profile 统一切换

```bash
# 批量切换
# ⚠️ 切到 zai 时必须显式设 base_url（coding plan 端），不能留空
for p in default cto diary genshin reasoner scout qian-duoduo; do
  if [ "$p" = "default" ]; then
    hermes config set model.default glm-5-turbo
    hermes config set model.provider zai
    hermes config set model.base_url https://open.bigmodel.cn/api/coding/paas/v4
  else
    hermes -p "$p" config set model.default glm-5-turbo
    hermes -p "$p" config set model.provider zai
    hermes -p "$p" config set model.base_url https://open.bigmodel.cn/api/coding/paas/v4
  fi
done

# 批量重启
hermes profile list 2>/dev/null | grep "running" | awk '{print $1}' | sed 's/◆//' | while read p; do
  hermes -p "$p" gateway restart
done

# ✅ 验证全景
bash ~/.hermes/scripts/profile-model-overview.sh
# 预期：所有 profile 的 Model 列都显示 glm-5-turbo
```

### 场景 3：只改辅助模型

```bash
# 换 Vision 模型（主模型不变）
# ⚠️ Vision 必须用 Z.AI 直连端（/api/paas/v4），不能用 coding plan 端！
# 原因：glm-4.6v 是多模态模型，coding plan 端不支持图片输入
hermes config set auxiliary.vision.provider zai
hermes config set auxiliary.vision.model glm-4.6v
hermes config set auxiliary.vision.base_url https://open.bigmodel.cn/api/paas/v4
hermes gateway restart

# ✅ 验证
hermes config show | grep -A4 "vision:"
# 预期输出：
#   vision:
#     provider: zai
#     model: glm-4.6v
#     base_url: https://open.bigmodel.cn/api/paas/v4  ← 必须是直连端
```

### 场景 4：Delegation 用便宜模型省钱

```bash
# delegation 用轻量模型，主模型保持强模型
# ⚠️ Delegation 必须用 coding plan 端（zai），不能留空
hermes config set delegation.model glm-4.5-air
hermes config set delegation.provider zai
hermes config set delegation.base_url https://open.bigmodel.cn/api/coding/paas/v4
hermes gateway restart

# ✅ 验证 delegation 和主模型分离
hermes config show | grep -E "(default:|delegation)" -A3
# 预期：主模型仍为原模型，delegation 显示 glm-4.5-air
```

---

## 7. 异常处理与排错指南

> **排错原则：** 先定位 → 再诊断 → 最后修复。每个错误都有「一键诊断」命令，复制即用。

### 🔴 错误 1：no API key found（修复时间：~1 分钟）

**错误码：** `AUTH_NO_KEY`
**症状：** `RuntimeError: no API key found for provider <name>`

**一键诊断：**
```bash
# 检查目标 profile 的所有 API Key 配置
PROFILE="<name>"  # ← 替换为实际 profile 名
echo "=== .env 文件中的 Key ==="
grep "_API_KEY\|_KEY=" ~/.hermes/profiles/$PROFILE/.env 2>/dev/null || echo "⚠️ .env 文件为空或不存在"
echo ""
echo "=== config.yaml 中的 provider ==="
awk '/^model:/{found=1} found && /^  provider:/{print "provider: "$2; exit}' ~/.hermes/profiles/$PROFILE/config.yaml 2>/dev/null
```

**诊断结果解读：**
| 输出 | 含义 | 修复 |
|---|---|---|
| `.env` 中没有目标 key | 缺少 API Key | 见下方修复 |
| `.env` 为空 | .env 未初始化 | 需要添加所有必要的 key |
| provider 和 key 不匹配 | 切了 provider 但没加 key | 添加对应 key |

**一键修复（以 ZAI 为例）：**
```bash
# 添加缺失的 key
echo "GLM_API_KEY=your_key_here" >> ~/.hermes/profiles/<name>/.env
# 重启生效
hermes -p <name> gateway restart
```

**预防检查（切换 provider 前必做）：**
```bash
# 检查目标 profile 是否有目标 provider 的 key
grep -l "GLM_API_KEY" ~/.hermes/profiles/<name>/.env && echo "✅ 有 ZAI key" || echo "❌ 缺 ZAI key"
```

### 🔴 错误 2：context too small（修复时间：~30 秒）

**错误码：** `CTX_TOO_SMALL`
**症状：** compression 或 session_search 报错 `context too small` 或类似上下文不足的错误。

**一键诊断：**
```bash
# 检查辅助模型的 context_length 是否足够
hermes config show | grep -A8 "compression:\|session_search:"
```

**诊断结果解读：**
| 模型 | 最低 context 要求 | 症状 |
|---|---|---|
| compression | ≥ 16K | 压缩失败、消息丢失 |
| session_search | ≥ 32K | 搜索结果不全、报错 |

**一键修复：**
```bash
hermes config set auxiliary.compression.model mimo-v2.5
hermes config set auxiliary.compression.provider xiaomi
hermes config set auxiliary.session_search.model mimo-v2.5
hermes config set auxiliary.session_search.provider xiaomi
hermes gateway restart
```

### 🔴 错误 3：切换不生效（修复时间：~30 秒）

**错误码：** `SWITCH_NOT_APPLIED`
**症状：** 执行了 `config set` 但发消息仍用旧模型。

**一键诊断：**
```bash
PROFILE="<name>"  # ← 替换
echo "=== Step 1: 配置是否写入 ==="
hermes -p $PROFILE config show 2>&1 | grep "default:" -A1

echo ""
echo "=== Step 2: Gateway 状态 ==="
hermes -p $PROFILE gateway status 2>&1

echo ""
echo "=== Step 3: Gateway 是否需要 start（而非 restart）==="
pgrep -f "hermes.*$PROFILE" > /dev/null && echo "✅ 进程存在" || echo "❌ 进程不存在，需用 start"
```

**诊断结果解读：**
| Step 1 结果 | Step 2 结果 | 原因 | 修复 |
|---|---|---|---|
| 旧模型 | running | config set 没成功 | 检查 set 命令的返回值 |
| 新模型 | not running | Gateway 没重启 | `hermes -p <name> gateway start` |
| 新模型 | running | 缓存未刷新 | `hermes -p <name> gateway restart` |

**一键修复：**
```bash
# 强制重启
hermes -p <name> gateway restart 2>/dev/null || hermes -p <name> gateway start
# 验证
hermes -p <name> chat -q "你是什么模型？回答模型名称即可" -Q
```

### 🔴 错误 4：config set 报 YAML 格式错误（修复时间：~2 分钟）

**错误码：** `YAML_PARSE_ERROR`
**症状：** `hermes config set` 返回 YAML parse error。

**一键诊断：**
```bash
PROFILE="<name>"  # ← 替换
CONFIG=$( [ "$PROFILE" = "default" ] && echo "$HOME/.hermes/config.yaml" || echo "$HOME/.hermes/profiles/$PROFILE/config.yaml" )
echo "=== YAML 语法检查 ==="
python3 -c "import sys,yaml; yaml.safe_load(open('$CONFIG'))" 2>&1
echo ""
echo "=== 最后修改时间 ==="
ls -la "$CONFIG"
```

**一键修复（恢复备份）：**
```bash
CONFIG="<path>"  # ← 替换为上面输出的路径
if [ -f "${CONFIG}.bak" ]; then
  cp "${CONFIG}.bak" "$CONFIG"
  echo "✅ 已从备份恢复"
else
  echo "❌ 无备份文件，需手动修复 YAML 语法"
fi
```

**预防：** 批量操作前备份配置：
```bash
for p in $(hermes profile list 2>/dev/null | tail -n +4 | awk '{print $1}' | sed 's/◆//'); do
  cfg=$( [ "$p" = "default" ] && echo "$HOME/.hermes/config.yaml" || echo "$HOME/.hermes/profiles/$p/config.yaml" )
  [ -f "$cfg" ] && cp "$cfg" "${cfg}.bak" && echo "✅ 备份 $p"
done
```

### 🔴 错误 5：profile 名称不对（修复时间：~10 秒）

**错误码：** `PROFILE_NOT_FOUND`
**症状：** `hermes -p <name> config set ...` 报错 `profile not found`。

**一键诊断：**
```bash
echo "=== 可用 profile 列表 ==="
hermes profile list
```

**常见错误：** `default` profile 不加 `-p`，其他 profile 必须加 `-p <name>`。名称区分大小写。

### 🟡 错误 6：辅助模型设为空后行为异常（修复时间：~1 分钟）

**错误码：** `AUX_AUTO_FAIL`
**症状：** 辅助模型字段留空后，某些功能（如图片识别）不工作。

**一键诊断：**
```bash
# 检查哪些辅助模型是空的
hermes config show | awk '/^auxiliary:/{a=1} a && /provider:/{if($2=="") print NR": 空 provider"}' 
```

**修复：** 始终显式配置所有辅助模型，尤其是 `vision` 和 `compression`：
```bash
hermes config set auxiliary.vision.provider xiaomi
hermes config set auxiliary.vision.model mimo-v2-omni
hermes config set auxiliary.compression.provider xiaomi
hermes config set auxiliary.compression.model mimo-v2.5
hermes gateway restart
```

### 🟡 错误 7：base_url 未设置导致请求发错地址（修复时间：~30 秒）

**错误码：** `WRONG_ENDPOINT`
**症状：** 切换 provider 后请求发到了错误的 API 端点，返回 401 或连接超时。

**一键诊断：**
```bash
echo "=== 当前 base_url ==="
hermes config show | grep "base_url:"
```

**修复：**
```bash
hermes -p <profile> config set model.base_url https://open.bigmodel.cn/api/coding/paas/v4
hermes -p <profile> gateway restart
```

### 🔴 错误 8：Context length exceeded 但 token 数极小（修复时间：~30 秒）

**错误码：** `STALE_GATEWAY_MODULE`
**症状：** `RuntimeError: Context length exceeded (4,959 tokens). Cannot compress further.` — 注意 token 数只有几千，远低于任何模型的上下文窗口。
**根本原因：** Gateway 进程在 Hermes 代码更新**之前**启动，使用了旧版内存中的模块。某次代码更新添加了新方法（如 `ProviderProfile.get_max_tokens`），旧进程没有该方法，导致 `AttributeError`，被 Hermes 误判为上下文溢出。

**一键诊断：**
```bash
PROFILE="<name>"  # ← 替换

echo "=== 1. Gateway 启动时间 ==="
systemctl show hermes-gateway-$PROFILE.service --property=ActiveEnterTimestamp 2>/dev/null || \
  pgrep -f "hermes.*$PROFILE" -o -a 2>/dev/null

echo ""
echo "=== 2. 检查日志中的 AttributeError ==="
grep "error_type=AttributeError" ~/.hermes/profiles/$PROFILE/logs/agent.log 2>/dev/null | tail -5

echo ""
echo "=== 3. 检查 stale module 警告 ==="
grep "stale in-memory module" ~/.hermes/profiles/$PROFILE/logs/agent.log 2>/dev/null | tail -3

echo ""
echo "=== 4. 代码最后修改时间 ==="
ls -la ~/.hermes/hermes-agent/providers/base.py 2>/dev/null
```

**诊断结果解读：**

| 日志中的线索 | 含义 | 修复 |
|---|---|---|
| `error_type=AttributeError` + `ProviderProfile` | 旧进程缺少新方法 | restart gateway |
| `stale in-memory module after an update` | 明确提示需要重启 | restart gateway |
| Gateway 启动时间早于代码更新时间 | 确认根因 | restart gateway |
| Context exceeded token 数 < 10,000 | 不是真正的上下文问题 | 不要换模型 |

**⚠️ 关键区分：** 如果 token 数在几千级别（如 4,959、4,995），这是**假性上下文溢出**——真正原因是 API 调用阶段就失败了。如果 token 数在几十万级别，那才是真正的上下文窗口不足，需要换大上下文模型。

**一键修复：**
```bash
hermes -p <profile> gateway restart
# 验证
hermes -p <profile> gateway status
```

**预防：** Hermes 每次 `hermes update` 后，所有运行中的 gateway 都应重启以加载新代码。详细调试记录见 `references/stale-gateway-context-overflow.md`。

### 🔴 错误 9：401 "token expired or incorrect" — API Key 截断或 provider 错配（修复时间：~2 分钟）

**错误码：** `API_KEY_MISMATCH`
**症状：** `RuntimeError: Error code: 401 - {'error': {'code': '401', 'message': '令牌已过期或验证不正确'}}` 或英文 `'token expired or incorrect'`。
**注意：** 不是真的过期——是 key 配错了。

**两种常见根因：**

| 根因 | 表现 | 修复 |
|---|---|---|
| `.env` 中 key 被截断为掩码值 | key 长度异常短（如 13 字符），形如 `3541b5...vBc2` | 用完整 key 替换 |
| `config.yaml` 硬编码了错误 provider 的 key | 如 xiaomi 的 `tp-cb1...` 用在了 zai/bigmodel 端点 | 删除硬编码的 `api_key`/`base_url`，让 profile 继承全局 provider |

**一键诊断：**
```bash
PROFILE="<name>"
echo "=== 1. .env 中的 key 长度 ==="
grep "_API_KEY" ~/.hermes/profiles/$PROFILE/.env 2>/dev/null | while IFS='=' read -r k v; do
  echo "$k: length=${#v}"
done
echo ""
echo "=== 2. config.yaml 是否硬编码了 api_key ==="
grep -A5 "^model:" ~/.hermes/profiles/$PROFILE/config.yaml | grep -E "api_key|base_url"
echo ""
echo "=== 3. 快速 API 测试 ==="
python3 -c "
import yaml
cfg = yaml.safe_load(open('$HOME/.hermes/config.yaml'))
key = cfg['providers'].get('zai',{}).get('api_key','')
print(f'全局 zai key: {key[:10]}...{key[-4:]} (len={len(key)})')
"
```

**诊断结果解读：**
| 发现 | 含义 | 修复 |
|---|---|---|
| .env 中 ZAI_API_KEY 长度 < 30 | key 被截断为掩码值 | 用全局 provider 中的真实 key 替换 |
| config.yaml 中有 `api_key: tp-cb1...` | xiaomi token 硬编码在 zai provider 配置中 | 删除 `api_key`、`base_url`、`api_mode`，只保留 `model` + `provider` |
| 两处都正常 | 可能是全局 provider key 真的过期了 | 检查全局 `config.yaml` 中 `providers.zai.api_key` |

**一键修复（根因 1 — .env 截断）：**
```bash
# 从全局 providers 获取真实 key，写入 profile .env
python3 -c "
import yaml
cfg = yaml.safe_load(open('$HOME/.hermes/config.yaml'))
for name, p in cfg.get('providers',{}).items():
    key = p.get('api_key','')
    if key:
        print(f'{name.upper()}_API_KEY={key}')
" | while IFS='=' read -r k v; do
  PROFILE="<name>"  # ← 替换
  ENV_FILE="$HOME/.hermes/profiles/$PROFILE/.env"
  # Replace existing masked/truncated key or append if missing
  if grep -q "^${k}=" "$ENV_FILE"; then
    sed -i "s|^${k}=.*|${k}=${v}|" "$ENV_FILE"
  else
    echo "${k}=${v}" >> "$ENV_FILE"
  fi
  echo "✅ Fixed $k in $ENV_FILE"
done
```

**一键修复（根因 2 — config.yaml 硬编码错误 key）：**
```bash
# 删除 profile config.yaml 中 model 块的硬编码 api_key/base_url/api_mode
# 只保留 model.default + model.provider，让其继承全局 provider
hermes -p <name> config set model.api_key ""
hermes -p <name> config set model.base_url ""
hermes -p <name> config set model.api_mode ""
# 重启生效
hermes -p <name> gateway restart
```

**预防：** Profile `config.yaml` 的 `model:` 块应只含 `default` + `provider`，不要硬编码 `api_key`/`base_url`/`api_mode`。这些应从全局 `providers:` 配置继承，或通过 `.env` 中的环境变量传递。批量设置模型时（如 `§3.4 批量操作`），只 set `model.default` + `model.provider`，不要 set `model.api_key`。

### 🟡 错误 10：Gateway 流式响应超时（修复时间：~1 分钟）

**错误码：** `STREAM_STALE`
**症状：** 日志中出现 `Stream stale for 180s` 或 `RemoteProtocolError: peer closed connection without sending complete message body`。

**一键诊断：**
```bash
# 查看最近的流式超时日志
hermes -p <profile> gateway logs --tail 50 2>&1 | grep -i "stale\|RemoteProtocolError\|timeout\|stream"
```

**诊断结果解读：**
| 现象 | 原因 | 修复 |
|---|---|---|
| 0 bytes, 0 chunks | 上游模型服务卡住 | 重试或切换 provider |
| 偶发一次 | 网络抖动 | 无需处理，自动重试 |
| 频繁出现 | provider 服务不稳定 | 切换到备用 provider |

**修复：** 如果频繁出现，切换到备用 provider：
```bash
# 示例：从 xiaomi 切到 zai
hermes -p <profile> config set model.provider zai
hermes -p <profile> config set model.default glm-5-turbo
hermes -p <profile> config set model.base_url https://open.bigmodel.cn/api/coding/paas/v4
hermes -p <profile> gateway restart
```

---

## 8. 常见问题 (FAQ)

### Q1: 切换模型后为什么没生效？
**A:** 模型配置只对新 session 生效，已运行的 Gateway 必须重启：
```bash
hermes -p <profile> gateway restart
```
验证方法：`hermes -p <profile> gateway status` 确认状态为 `running`。

### Q2: 切换 provider 后报 "no API key found"？
**A:** 每个 profile 有独立的 `.env` 文件，需要确保目标 profile 的 `.env` 中有对应 key：
```bash
# 检查 key 是否存在
grep "ZAI\|XIAOMI\|DEEPSEEK" ~/.hermes/profiles/<name>/.env

# 如果没有，手动添加
echo "GLM_API_KEY=your_key_here" >> ~/.hermes/profiles/<name>/.env
```

### Q3: 辅助模型设为空会怎样？
**A:** Hermes 会尝试 `auto` 模式自动匹配，但可能失败或选到不合适的模型。建议显式配置所有辅助模型，特别是 `vision` 和 `compression`。

### Q4: `hermes config set` 会覆盖其他字段吗？
**A:** 不会。`config set` 是逐字段 YAML merge，只修改指定的字段，不影响其他配置。

### Q5: compression 模型报错 "context too small"？
**A:** compression 模型的 `context_length` 至少需要 16K，否则压缩会失败。选择模型时注意其上下文窗口大小。

### Q6: default profile 的 `-p` 参数写法？
**A:** default profile **不加** `-p` 参数，其他 profile **必须加** `-p <name>`。这是最常见的错误。

### Q7: 如何确认切换后的模型实际生效了？
**A:**
```bash
# 方法 1：查看配置
hermes -p <profile> config show | grep "default:" -A1

# 方法 2：发送测试消息
hermes -p <profile> chat -q "你是什么模型？回答模型名称即可" -Q

# 方法 3：查看 Gateway 状态
hermes -p <profile> gateway status
```

### Q8: 批量切换后发现切错了，怎么回滚？
**A:** 如果操作前备份了配置：
```bash
# 恢复备份
cp ~/.hermes/profiles/<name>/config.yaml.bak ~/.hermes/profiles/<name>/config.yaml
hermes -p <profile> gateway restart
```
**预防：** 批量操作前务必执行备份命令（见 §3.4）。

### Q9: 自定义 provider 和内置 provider 的区别？
**A:**
- **内置 provider**（xiaomi/zai/openrouter 等）：`base_url` 和 `api_key` 的 env 变量名由 Hermes 自动识别，只需设置 `provider` 名即可
- **自定义 provider**：在 `custom_providers` 中定义，切换时必须同时设置 `base_url`

### Q10: Gateway restart 和 start 的区别？
**A:**
- `restart`：停止后重新启动，适用于已运行的 profile
- `start`：首次启动或停止后的启动
- 如果 `restart` 报错说没有运行中的进程，改用 `start`

### Q11: Gateway 日志中出现 Stream stale / RemoteProtocolError？
**A:** 这是上游模型 API 服务端的问题（模型服务卡住，没有返回任何数据）。Hermes 会自动重试 3 次。如果频繁出现，建议切换到备用 provider：
```bash
# 快速切换到备用 provider
hermes -p <profile> config set model.provider zai
hermes -p <profile> config set model.default glm-5-turbo
hermes -p <profile> config set model.base_url https://open.bigmodel.cn/api/coding/paas/v4
hermes -p <profile> gateway restart
```

### Q12: 批量操作如何安全回滚？
**A:** 如果操作前用了 §7 的批量备份脚本，可以一键回滚：
```bash
for p in $(hermes profile list 2>/dev/null | tail -n +4 | awk '{print $1}' | sed 's/◆//'); do
  cfg=$( [ "$p" = "default" ] && echo "$HOME/.hermes/config.yaml" || echo "$HOME/.hermes/profiles/$p/config.yaml" )
  if [ -f "${cfg}.bak" ]; then
    cp "${cfg}.bak" "$cfg"
    echo "✅ 回滚 $p"
  fi
done
# 批量重启
hermes profile list 2>/dev/null | grep "running" | awk '{print $1}' | sed 's/◆//' | while read p; do
  hermes -p "$p" gateway restart
done
```

### Q13: "Context length exceeded (4,959 tokens)" — token 数才几千，是模型上下文太小吗？
**A:** 不是。几千 token 的 "context exceeded" 是**假性溢出**，真正原因是 Gateway 进程使用了旧版代码模块（Hermes 更新后未重启 Gateway）。日志中会伴随 `error_type=AttributeError` 和 `stale in-memory module` 警告。**修复：** `hermes -p <profile> gateway restart`。参见 §7 错误 8。

### Q15: 401 "token expired or incorrect" 但 key 明明没过期？
**A:** 两种常见原因：① profile `.env` 中的 API Key 被截断成了掩码值（如 `3541b5...vBc2`，仅 13 字符），检查 `grep "_API_KEY" ~/.hermes/profiles/<name>/.env` 看长度是否异常短；② `config.yaml` 硬编码了错误 provider 的 key（如 xiaomi 的 token 放在 zai provider 下）。修复见 §7 错误 9。

### Q14: 如何快速诊断任意模型问题？
**A:** 使用一键诊断脚本：
```bash
PROFILE="<name>"  # ← 替换
echo "========== 1. Profile 概况 =========="
bash ~/.hermes/scripts/profile-model-overview.sh 2>&1 | grep -E "HEADER|$PROFILE|^─"
echo ""
echo "========== 2. Gateway 状态 =========="
hermes -p $PROFILE gateway status 2>&1
echo ""
echo "========== 3. 最近日志（错误）=========="
hermes -p $PROFILE gateway logs --tail 20 2>&1 | grep -iE "error|warn|stale|timeout|fail" || echo "✅ 无错误日志"
echo ""
echo "========== 4. API Key 检查 =========="
grep "_API_KEY" ~/.hermes/profiles/$PROFILE/.env 2>/dev/null | sed 's/=.*/=***/' || echo "⚠️ 无 .env 文件"
```

---

## 9. 反模式与边界条件

### ❌ 反模式 1：只改 model 不改 provider

```bash
# ❌ 错误：模型名和 provider 不匹配
hermes config set model.default glm-5.1
# 但 provider 仍是 xiaomi → 请求会发到小米的 API 找 glm-5.1 → 报错

# ✅ 正确：同时切换（必须设 base_url）
hermes config set model.default glm-5.1
hermes config set model.provider zai
hermes config set model.base_url https://open.bigmodel.cn/api/coding/paas/v4
```

### ❌ 反模式 1.5：不区分 Z.AI 和 zai，一律用 coding plan 端

```bash
# ❌ 错误：Vision 也设成了 coding plan 端 → glm-4.6v 不支持多模态输入
hermes config set auxiliary.vision.base_url https://open.bigmodel.cn/api/coding/paas/v4

# ✅ 正确：Vision 必须用直连端（Z.AI）
hermes config set auxiliary.vision.base_url https://open.bigmodel.cn/api/paas/v4

# ❌ 同样错误：把主模型设成了直连端 → 浪费直连端配额，应该走 coding plan
hermes config set model.base_url https://open.bigmodel.cn/api/paas/v4
# ✅ 正确：主模型走 coding plan 端（zai）
hermes config set model.base_url https://open.bigmodel.cn/api/coding/paas/v4
```

### ❌ 反模式 2：切了 provider 不重启

```bash
# ❌ 错误：改了配置就以为生效了
hermes config set model.provider zai
# ...直接发消息 → 仍用旧 provider

# ✅ 正确：改完必须重启
hermes config set model.provider zai
hermes gateway restart
```

### ❌ 反模式 3：切换 provider 不检查 API Key

```bash
# ❌ 错误：直接切 provider
hermes -p diary config set model.provider zai

# ✅ 正确：先检查 key 存在
grep "GLM_API_KEY" ~/.hermes/profiles/diary/.env && \
  hermes -p diary config set model.provider zai || \
  echo "❌ 先添加 GLM_API_KEY 到 .env"
```

### ❌ 反模式 4：default profile 加了 -p 参数

```bash
# ❌ 错误
hermes -p default config set model.default glm-5.1
# 可能报错或行为不可预期

# ✅ 正确
hermes config set model.default glm-5.1
```

### ⚠️ 边界条件 1：批量操作中某个 profile 失败

`for` 循环批量切换时，如果某个 profile 的 config.yaml 格式有误，该 profile 会失败但不影响其他。批量操作后**必须**检查所有 profile 的结果：
```bash
bash ~/.hermes/scripts/profile-model-overview.sh
# 逐行检查 Model 列是否全部正确
```

### ⚠️ 边界条件 2：compression 模型上下文不足

`compression` 和 `session_search` 对上下文大小有要求：
- compression：至少 16K
- session_search：建议 32K+
- 如果模型上下文太小，这些功能会静默失败或报错

### ⚠️ 边界条件 3：裸 profile 的 `model.base_url` 不存在

`dev`/`ops`/`pm`/`qa`/`security` 等 profile 的 `config.yaml` 只有 `model.default` + `model.provider`，没有 `model.base_url` 字段。`config set model.base_url <url>` 会正确添加该字段。验证时必须重新读取 YAML 文件确认字段存在，不能假设 YAML merge 会填充缺失字段。

**验证命令：**
```bash
grep -A4 "^model:" ~/.hermes/profiles/<name>/config.yaml
# 期望看到 base_url 行
```

### ⚠️ 边界条件 4：辅助模型与主模型并发冲突
同一 provider 下，辅助模型不要和主模型用同一个重模型。compression 和 web_extract 是轻量任务，应选用轻量模型（如 glm-4.5-air），避免与主模型（glm-5-turbo 等）争抢并发配额，导致主对话卡顿或超时。

```
# ❌ 错误：辅助模型和主模型用同一个重模型
hermes config set auxiliary.compression.model glm-5-turbo  # 抢并发

# ✅ 正确：轻量任务用轻量模型
hermes config set auxiliary.compression.model glm-4.5-air
hermes config set auxiliary.web_extract.model glm-4.5-air
```

选型原则：vision 必须用多模态模型（如 glm-4.6v）；compression / web_extract / session_search 用轻量模型即可。

### ⚠️ 边界条件 6：全 profile 批量审计 Z.AI vs zai 端点一致性

批量切换 provider 后，不同 profile 可能残留不同的 base_url 配置。验证脚本（`profile-model-overview.sh`）不显示 base_url，所以必须逐 profile 读取 config.yaml 的 `base_url` 字段。

**规则（2026-06-22 确立）：口诀：Vision 走 Z.AI 直连，其余全走 zai coding plan。**
- **Vision** → Z.AI 直连端（`https://open.bigmodel.cn/api/paas/v4`）— 因为 glm-4.6v 是唯一多模态模型，coding plan 端不支持图片输入
- **其余所有模型** → zai coding plan 端（`https://open.bigmodel.cn/api/coding/paas/v4`）

**一键审计脚本（Python）：**
```python
import os, yaml
profiles = ['default','cto','dev','diary','genshin','ops','pm','qa','qian-duoduo','reasoner','scout','security']
ZAI_DIRECT = "https://open.bigmodel.cn/api/paas/v4"      # Vision 用
ZAI_CODING = "https://open.bigmodel.cn/api/coding/paas/v4"  # 其余全部用
for p in profiles:
    cfg_path = os.path.expanduser('~/.hermes/config.yaml') if p == 'default' else os.path.expanduser(f'~/.hermes/profiles/{p}/config.yaml')
    cfg = yaml.safe_load(open(cfg_path))
    model = cfg.get('model', {})
    aux = cfg.get('auxiliary', {})
    deleg = cfg.get('delegation', {})
    # Vision → 直连
    vision = aux.get('vision', {})
    if vision.get('model'):
        bu = vision.get('base_url', '')
        status = '✅' if bu == ZAI_DIRECT else '❌'
        print(f"{status} {p} Vision base_url={bu}")
    # 其余 → coding plan
    for label, sec in [('主模型', model), ('Compression', aux.get('compression',{})),
                       ('WebExtract', aux.get('web_extract',{})),
                       ('SessionSearch', aux.get('session_search',{}))]:
        if sec.get('model'):
            bu = sec.get('base_url', '')
            status = '✅' if bu == ZAI_CODING else '❌'
            print(f"{status} {p} {label} base_url={bu}")
    d_prov = deleg.get('provider', '')
    if d_prov and d_prov != 'mem0':
        bu = deleg.get('base_url', '')
        status = '✅' if bu == ZAI_CODING else '❌'
        print(f"{status} {p} Delegation provider={d_prov} base_url={bu}")
```

### ⚠️ 边界条件 7：delegation 设为空字符串 vs 删除字段

```bash
# 设为空字符串 → 回到继承主模型的行为
hermes config set delegation.model ""

# 直接编辑 config.yaml 删除 delegation 整块 → 可能导致解析问题
# ❌ 不推荐直接编辑，用 config set
```

### ⚠️ 边界条件 4：.env 中有同名 key 时取最后一个

如果 `.env` 中有多行同一个 key（如两行 `GLM_API_KEY=xxx`），Hermes 取**最后一个**。这可能是预期行为，也可能造成困惑。

---

## 10. 限制与注意事项

1. **API Key 隔离**：每个 profile 有独立 `.env`，切换 provider 前务必确认目标 key 存在
2. **Gateway 重启必须**：所有模型修改只对新 session 生效，已运行的 gateway 必须 `restart`
3. **辅助模型 context_length**：compression 至少需要 16K，session_search 建议 32K+
4. **批量操作不可逆**：批量切换前建议备份配置：`cp ~/.hermes/profiles/<name>/config.yaml ~/.hermes/profiles/<name>/config.yaml.bak`
5. **自定义 Provider 需要 base_url**：使用自定义 provider 时必须在 `config set` 中指定 `base_url`
6. **profile 名称区分大小写**：`Profile` ≠ `profile`，使用 `hermes profile list` 确认准确名称
7. **default profile 不加 -p**：对 default profile 操作时不加 `-p` 参数，这是最常见的错误

---

## 11. 更新后必须重启 Gateway

Hermes 代码更新后，所有运行中的 Gateway 进程仍使用旧版内存中的模块。如果不重启，新方法/新功能会报 `AttributeError`。

**症状识别：** 日志中出现 `stale in-memory module after an update; restart the process to resync`。

**批量重启所有 Gateway：**
```bash
for p in $(hermes profile list 2>/dev/null | tail -n +4 | awk '{print $1}' | sed 's/◆//'); do
  hermes -p "$p" gateway restart 2>/dev/null && echo "✅ $p restarted" || echo "⚠️ $p not running"
done
```

**建议：** 在 cron job 或 `hermes update` 后自动重启所有 gateway，避免假性错误。

---

## 12. 一键全览脚本

运行以下命令查看所有 profile 的模型全景：

```bash
# 基础模式：只看配置
bash ~/.hermes/scripts/profile-model-overview.sh

# 诊断模式：配置 + Gateway 状态 + API Key 检查
bash ~/.hermes/scripts/profile-model-overview.sh --diagnose
```

脚本自动检测所有 profile，解析 config.yaml，以表格形式展示主模型、Provider、Vision、Compression、Delegation 配置。诊断模式额外显示 Gateway 运行状态和 API Key 数量，方便排查问题。

---

## 13. 思考模式 / Reasoning Mode 配置指南

Hemes 通过 `Display.Reasoning`（在 config 中显示为 `reasoning` 字段）控制全局 reasoning/thinking 开关。该字段决定了向 API 发送时是否传递 `extra_body.thinking` 和 `reasoning_effort`。

### 查看当前状态

```bash
hermes config show | grep "Reasoning:"
# 输出：Reasoning: off  或  Reasoning: on
```

### 切换命令

```bash
# 关闭思考模式（推荐 Agent 场景）
hermes config set reasoning off

# 开启思考模式（复杂推理场景）
hermes config set reasoning on

# 修改后必须重启才能生效
hermes gateway restart
```

### Provider 行为对比

| Provider | thinking 关闭时 | thinking 开启时 | 注意事项 |
|---|---|---|---|
| **DeepSeek V4** | `extra_body: {thinking: {type: "disabled"}}` | `extra_body: {thinking: {type: "enabled"}}` + `reasoning_effort` | ⚠️ 关闭思考模式是 Agent 工具调用的**必要条件**，否则踩 `reasoning_content must be passed back` 错误 |
| **Kimi/Moonshot** | 不传 `reasoning_effort` + `thinking: disabled` | 传 `reasoning_effort` + `thinking: enabled` | 和 DeepSeek 类似但回传要求稍有不同 |
| **Gemini** | `thinking_config: {includeThoughts: false}` | `thinking_config: {includeThoughts: true}` + 可选 `thinkingLevel` | 无回传陷阱 |
| **其他（ZAI/MiMo/OpenRouter）** | 无 thinking 参数 | 无 thinking 参数 | 不受 reasoning 开关影响 |

### ⚠️ 核心陷阱：DeepSeek V4 的 reasoning_content 回传错误

**症状：** Hermes Agent 工具调用后，DeepSeek API 返回 HTTP 400 `reasoning_content must be passed back`。

**根本原因（来自 Hermes 源码 `plugins/model-providers/deepseek/__init__.py`）：**
```
DeepSeek's V4 family defaults to thinking-mode ON when extra_body.thinking is unset.
The API then returns reasoning_content and starts enforcing the contract that subsequent
turns echo it back; combined with how Hermes replays history this lands on the notorious
HTTP 400 "reasoning_content must be passed back" error after the first tool call
(#15700, #17212, #17825).
```

即：**V4 默认开启 thinking → 第一次输出返回 `reasoning_content` → 后续轮次必须回传 → 工具调用打破了回传链 → API 400 错误。**

**修复：** 关闭 `hermes config set reasoning off` + `hermes gateway restart`。或者直接切到 `deepseek-chat` 模型名（旧映射，对应非思考模式）。

### 推荐策略

| 使用场景 | reasoning 设置 | 推荐模型 |
|---|---|---|
| **Agent 工具调用、搜索、问答** | `off` | deepseek-v4-flash |
| **复杂推理、数学、代码** | `on` | deepseek-v4-pro（或 glm-5.1） |
| **轻量辅助任务（compression/web_extract）** | 不受影响 | glm-4.5-air / mimo-v2.5 |

### 成本影响

开启 thinking/CoT 后，推理 token 按**输出 tokens 计费**（如 DeepSeek V4 Flash 为 $0.28/M）。对于每天处理大量请求的 Agent 场景，关闭 thinking 可节省 40-60% 的 output token 开销。

### 参考实现

DeepSeek 的 thinking 处理逻辑见 `plugins/model-providers/deepseek/__init__.py`，核心代码：

```python
def build_api_kwargs_extras(self, *, reasoning_config, model, **context):
    extra_body = {}
    top_level = {}
    if not _model_supports_thinking(model):
        return extra_body, top_level
    enabled = True
    if isinstance(reasoning_config, dict) and reasoning_config.get("enabled") is False:
        enabled = False
    extra_body["thinking"] = {"type": "enabled" if enabled else "disabled"}
    if not enabled:
        return extra_body, top_level
    # effort mapping: low/medium/high → pass through; xhigh/max → max
    ...
```

详细分析含完整源码和触发条件见 `references/deepseek-thinking-trap.md`。

---

参见 `references/skillhub-and-github-publishing.md`（含 SkillHub Web 发布 + GitHub 仓库管理流程）。
