# SkillHub 发布 + GitHub 管理

## GitHub 仓库

**仓库：** `youbuwei/hermes-profile-model-manager`  
**协议：** SSH (`git@github.com:youbuwei/hermes-profile-model-manager.git`)  
**分支：** `main`

> ⚠️ `gh` CLI 未登录（SSH 已配置）。Git 操作通过 SSH 直接 push，不依赖 `gh auth`。

## 同步本地 skill 到 GitHub 的标准流程

```bash
# 1. Clone 到临时目录
cd /tmp && rm -rf hermes-profile-model-manager
git clone git@github.com:youbuwei/hermes-profile-model-manager.git

# 2. 从本地 skill 目录复制最新文件
cp ~/.hermes/skills/hermes/profile-model-manager/SKILL.md /tmp/hermes-profile-model-manager/SKILL.md
cp ~/.hermes/skills/hermes/profile-model-manager/scripts/* /tmp/hermes-profile-model-manager/scripts/
cp ~/.hermes/skills/hermes/profile-model-manager/references/* /tmp/hermes-profile-model-manager/references/

# 3. 同步版本号到 AGENTS.md（检查 SKILL.md 的 version 字段，同步到 AGENTS.md）
# SKILL.md frontmatter 中 metadata.version 决定版本号
# AGENTS.md 中所有 "v<x.y.z>" 引用需同步更新

# 4. 对比确认变更范围
cd /tmp/hermes-profile-model-manager
git diff --stat

# 5. Commit + Push
git add -A
git commit -m "v<x.y.z>: <变更摘要>"
git push origin main
```

**验证：** push 后在 https://github.com/youbuwei/hermes-profile-model-manager 确认文件已更新。

## SkillHub Web 发布

`skillhub` CLI 是只读的，发布只能通过 Web 界面：

1. 打开 https://skillhub.cn → 登录（手机号+验证码）
2. 找到已发布的 skill → 更新版本
3. 上传新的 SKILL.md
4. 提交审核（自动触发 TRACE 评测）

> GitHub push 和 SkillHub 上传是**独立的两个步骤**，需要分别操作。
