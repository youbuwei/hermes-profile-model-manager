# DeepSeek V4 Thinking Mode Trap

## 问题

DeepSeek V4 系列（V4 Flash / V4 Pro）默认开启 thinking 模式。在 Hermes Agent 中使用工具调用时，会导致 API 返回 HTTP 400：

```
reasoning_content must be passed back
```

## 根因

来自 Hermes 源码 `plugins/model-providers/deepseek/__init__.py`：

```
DeepSeek's V4 family (and the legacy deepseek-reasoner) defaults to
thinking-mode ON when extra_body.thinking is unset.  The API then returns
reasoning_content and starts enforcing the contract that subsequent turns
echo it back; combined with how Hermes replays history this lands on the
notorious HTTP 400 "reasoning_content must be passed back" error after the
first tool call (#15700, #17212, #17825).
```

**流程：**
1. 不传 `extra_body.thinking` → 默认 `enabled`
2. 模型返回 `reasoning_content`（CoT 推理过程）
3. 下一轮请求必须回传该 `reasoning_content`
4. Hermes Agent 工具调用后拼接消息时未正确回传
5. API 400 拒绝

## 哪些模型受影响

| 模型 | 受影响 | 说明 |
|---|---|---|
| `deepseek-v4-flash` | ✅ | 支持 thinking，默认开启 |
| `deepseek-v4-pro` | ✅ | 支持 thinking，默认开启 |
| `deepseek-reasoner` | ✅ | 旧名，对应 Flash 思考模式 |
| `deepseek-chat` | ❌ | 旧名，对应 V3（无 thinking） |
| `deepseek-v3*` | ❌ | V3 系列不支持 thinking |

## Hermes Provider Profile 处理逻辑

完整代码见 `plugins/model-providers/deepseek/__init__.py`：

```python
def _model_supports_thinking(model: str | None) -> bool:
    """DeepSeek thinking-capable model families."""
    m = (model or "").strip().lower()
    if not m:
        return False
    if m.startswith("deepseek-v") and not m.startswith("deepseek-v3"):
        # deepseek-v4-*, deepseek-v5-*, etc.
        return True
    if m == "deepseek-reasoner":
        return True
    return False


class DeepSeekProfile(ProviderProfile):
    def build_api_kwargs_extras(
        self, *, reasoning_config: dict | None = None, model: str | None = None, **context
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        extra_body: dict[str, Any] = {}
        top_level: dict[str, Any] = {}

        if not _model_supports_thinking(model):
            return extra_body, top_level

        # reasoning_config.enabled == False → thinking disabled
        enabled = True
        if isinstance(reasoning_config, dict) and reasoning_config.get("enabled") is False:
            enabled = False

        extra_body["thinking"] = {"type": "enabled" if enabled else "disabled"}

        if not enabled:
            return extra_body, top_level

        # Effort mapping
        if isinstance(reasoning_config, dict):
            effort = (reasoning_config.get("effort") or "").strip().lower()
            if effort in {"xhigh", "max"}:
                top_level["reasoning_effort"] = "max"
            elif effort in {"low", "medium", "high"}:
                top_level["reasoning_effort"] = "effort"

        return extra_body, top_level
```

## Hermes 中 reasoning_config 的来源

从 `hermes config show` 输出可以看到 `Reasoning: off` 字段，类型为 Display 配置。

```yaml
# config.yaml 中的对应字段
display:
  reasoning: off    # 或 on
```

此字段通过 `config set reasoning on|off` 控制，经 agent 初始化时传递为 `reasoning_config` 字典（`{"enabled": True/False}`），最终由各 provider profile 的 `build_api_kwargs_extras()` 消费。

## 修复方法

```bash
# 关闭思考模式
hermes config set reasoning off
hermes gateway restart
```

## 验证

```bash
# 确认配置
hermes config show | grep "Reasoning:"
# → Reasoning: off

# 发送测试消息确认无 400 错误
hermes chat -q "测试一下工具调用" -Q
```

## 相关 Issue

- #15700
- #17212
- #17825
