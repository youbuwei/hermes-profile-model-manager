# Hermes Profile Model Manager

查看和管理 [Hermes Agent](https://hermes-agent.nousresearch.com) 各 profile 的大模型配置。

## 功能

- 查看所有 profile 的模型配置全景（一键脚本）
- 切换主模型、辅助模型（vision/compression/web_extract/session_search）、delegation 模型
- 支持单个 profile 或批量操作
- 内置 Provider 速查表和模型参考
- **Agent 智能触发** — 自然语言即可操作，无需记命令
- **完整排错指南** — 7 个常见错误的诊断与修复步骤
- **反模式与边界条件** — 帮你避开配置陷阱

## 安装

```bash
hermes skill install hermes-profile-model-manager
```

或手动复制：
```bash
cp SKILL.md ~/.hermes/skills/hermes/profile-model-manager/SKILL.md
cp scripts/profile-model-overview.sh ~/.hermes/scripts/profile-model-overview.sh
```

## 快速开始

```bash
# 查看所有 profile 模型全景
bash ~/.hermes/scripts/profile-model-overview.sh

# 切换 default profile 主模型
hermes config set model.default glm-5-turbo
hermes config set model.provider zai
hermes gateway restart
```

## 版本

- v2.0.0 — 基于 SkillHub TRACE 评测优化：新增 Agent 智能触发指引、异常处理排错指南（7 个错误场景）、反模式与边界条件、操作效果示例、FAQ 扩展至 10 条
- v1.1.0 — 优化文档结构，新增 FAQ、快速开始、限制说明；脚本增加容错处理
- v1.0.0 — 初始版本

## 许可

MIT
