# Hermes Profile Model Manager

查看和管理 [Hermes Agent](https://hermes-agent.nousresearch.com) 各 profile 的大模型配置。

## 功能

- 查看所有 profile 的模型配置全景（一键脚本）
- 切换主模型、辅助模型（vision/compression/web_extract/session_search）、delegation 模型
- 支持单个 profile 或批量操作
- 内置 Provider 速查表和模型参考

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

- v1.1.0 — 优化文档结构，新增 FAQ、快速开始、限制说明；脚本增加容错处理
- v1.0.0 — 初始版本

## 许可

MIT
