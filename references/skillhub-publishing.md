# 发布 Skill 到 SkillHub

SkillHub (https://skillhub.cn) 是面向中国用户的 AI Skills 社区。

## CLI 能力

`skillhub` CLI 是**只读**的，支持：search / install / upgrade / list / login / logout / config

**不支持** `publish`。发布只能通过 Web 界面。

## Web 发布流程

1. 打开 https://skillhub.cn
2. 点击右上角「发布 Skill」按钮
3. 手机号 + 验证码登录（个人或团队）
4. 填写 skill 信息，上传 SKILL.md
5. 提交审核

## 注意事项

- 登录方式：手机号 + 短信验证码，无密码登录
- 发布后需审核
- 来源声明：部分 Skill 内容来源于 ClawHub (https://clawhub.ai)
- 版权问题联系：skillhub_ipr@tencent.com
- CLI 版本：`skillhub --version`（当前 2026.5.23+）

## CLI Login（企业源）

```bash
skillhub login --key sk-ent-xxx --host https://api.skillhub.cn
```

这用于连接企业私有源，不是发布认证。
