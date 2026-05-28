# SkillHub 发布 + GitHub 管理

## SkillHub Web 发布

`skillhub` CLI 是只读的，发布只能通过 Web 界面：

1. 打开 https://skillhub.cn → 登录（手机号+验证码）
2. 找到已发布的 skill → 更新版本
3. 上传新的 SKILL.md
4. 提交审核（自动触发 TRACE 评测）

## GitHub 仓库管理

将 skill 托管到 GitHub 便于版本管理和协作：

```bash
# Clone 空仓库
git clone git@github.com:<user>/<repo>.git
cd <repo>

# 复制 skill 文件（保持目录结构）
mkdir -p scripts references
cp ~/.hermes/skills/<category>/<name>/SKILL.md .
cp ~/.hermes/skills/<category>/<name>/scripts/* scripts/
cp ~/.hermes/skills/<category>/<name>/references/* references/

# 添加 README.md（含安装说明、快速开始、版本历史）

# Commit & push
git add -A
git commit -m "v1.x.0: <变更摘要>"
git push -u origin main
```

### 注意事项

- SSH key 需已配置（`ssh -T git@github.com` 验证）
- `git config user.email` / `user.name` 需提前设置
- SKILL.md 更新后需同步推送 GitHub + 上传 SkillHub（两者独立）
