---
name: profile-model-manager
description: "查看、更换和管理 Hermes 各 profile 的大模型配置（主模型、辅助模型、delegation 模型）。支持单个/批量操作、切换 provider、全 profile 一览。"
version: 1.1.0
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

## 0. 快速开始

**30 秒上手：**

```bash
# 1. 查看当前所有 profile 模型全景
bash ~/.hermes/scripts/profile-model-overview.sh

# 2. 切换 default profile 主模型
hermes config set model.default glm-5-turbo
hermes config set model.provider zai

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

**切换后必须重启：**
```bash
hermes -p <profile> gateway restart
```

### 3.2 切换辅助模型

```bash
hermes config set auxiliary.vision.provider <provider>
hermes config set auxiliary.vision.model <model>
hermes config set auxiliary.vision.base_url <url>

hermes config set auxiliary.compression.provider <provider>
hermes config set auxiliary.compression.model <model>

hermes config set auxiliary.web_extract.provider <provider>
hermes config set auxiliary.web_extract.model <model>

hermes config set auxiliary.session_search.provider <provider>
hermes config set auxiliary.session_search.model <model>
```

Per-profile 用法同理加 `-p <name>`。

### 3.3 切换 Delegation 模型

```bash
hermes -p <profile> config set delegation.model <model>
hermes -p <profile> config set delegation.provider <provider>
```

设为空字符串即回到继承主模型的行为：
```bash
hermes -p <profile> config set delegation.model ""
hermes -p <profile> config set delegation.provider ""
```

### 3.4 批量操作所有 profile

```bash
# 切换所有 profile 主模型
for p in default cto diary genshin reasoner scout qian-duoduo; do
  if [ "$p" = "default" ]; then
    hermes config set model.default glm-5-turbo
    hermes config set model.provider zai
  else
    hermes -p "$p" config set model.default glm-5-turbo
    hermes -p "$p" config set model.provider zai
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

---

## 4. Provider 速查表

| Provider | Env 变量 | Base URL | 说明 |
|---|---|---|---|
| `xiaomi` | `XIAOMI_API_KEY` | `https://token-plan-cn.xiaomimimo.com/v1` | 小米 MiMo |
| `zai` | `GLM_API_KEY` | `https://open.bigmodel.cn/api/coding/paas/v4` | 智谱 GLM |
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

---

## 5. 模型参考

### 智谱 ZAI

| 模型 | 上下文 | 最大输出 | 适用场景 |
|---|---|---|---|
| `glm-5-turbo` | 200K | 128K | 通用对话，高性价比 |
| `glm-5` | 200K | 128K | 通用推理 |
| `glm-5.1` | 200K | 128K | 复杂推理 |
| `glm-4.7` | 200K | 128K | 旧版主力 |

文档：https://docs.bigmodel.cn/cn/guide/start/model-overview

### 小米 MiMo

| 模型 | 上下文 | 适用场景 |
|---|---|---|
| `mimo-v2.5-pro` | 1M | 通用对话、长上下文 |
| `mimo-v2.5` | 1M | 辅助模型、高性价比 |
| `mimo-v2-omni` | — | 多模态（vision） |

---

## 6. 典型工作流

### 场景 1：临时切换测试模型

```bash
# 切到测试模型
hermes -p reasoner config set model.default glm-5.1
hermes -p reasoner config set model.provider zai
hermes -p reasoner gateway restart

# 验证切换成功
hermes -p reasoner config show | grep "model:" -A3

# 测试完毕后切回
hermes -p reasoner config set model.default mimo-v2.5-pro
hermes -p reasoner config set model.provider xiaomi
hermes -p reasoner gateway restart
```

### 场景 2：所有 profile 统一切换

```bash
# 批量切换
for p in default cto diary genshin reasoner scout qian-duoduo; do
  if [ "$p" = "default" ]; then
    hermes config set model.default glm-5-turbo
    hermes config set model.provider zai
  else
    hermes -p "$p" config set model.default glm-5-turbo
    hermes -p "$p" config set model.provider zai
  fi
done

# 批量重启
hermes profile list 2>/dev/null | grep "running" | awk '{print $1}' | sed 's/◆//' | while read p; do
  hermes -p "$p" gateway restart
done
```

### 场景 3：只改辅助模型

```bash
# 换一个更强的 vision 模型（主模型不变）
hermes config set auxiliary.vision.provider zai
hermes config set auxiliary.vision.model glm-5.1
hermes gateway restart
```

### 场景 4：Delegation 用便宜模型省钱

```bash
# delegation 用轻量模型，主模型保持强模型
hermes config set delegation.model glm-5-turbo
hermes config set delegation.provider zai
hermes gateway restart
```

---

## 7. 常见问题 (FAQ)

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

---

## 8. 限制与注意事项

1. **API Key 隔离**：每个 profile 有独立 `.env`，切换 provider 前务必确认目标 key 存在
2. **Gateway 重启必须**：所有模型修改只对新 session 生效，已运行的 gateway 必须 `restart`
3. **辅助模型 context_length**：compression 至少需要 16K，session_search 建议 32K+
4. **批量操作不可逆**：批量切换前建议备份配置：`cp ~/.hermes/profiles/<name>/config.yaml ~/.hermes/profiles/<name>/config.yaml.bak`
5. **自定义 Provider 需要 base_url**：使用自定义 provider 时必须在 `config set` 中指定 `base_url`
6. **profile 名称区分大小写**：`Profile` ≠ `profile`，使用 `hermes profile list` 确认准确名称

---

## 9. 一键全览脚本

运行以下命令查看所有 profile 的模型全景：

```bash
bash ~/.hermes/scripts/profile-model-overview.sh
```

脚本自动检测所有 profile，解析 config.yaml，以表格形式展示主模型、Provider、Vision、Compression、Delegation 配置。

---

## 发布到 SkillHub

参见 `references/skillhub-publishing.md`。SkillHub CLI 不支持 publish，需通过 Web 界面发布（手机号登录）。
