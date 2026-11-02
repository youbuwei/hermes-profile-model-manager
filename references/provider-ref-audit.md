# Provider 引用漂移审计（删除/改名 provider 后必做）

适用：用户删除、改名或合并了自定义 provider（`providers:` 块条目）后，排查配置里仍指向旧名的地方。

## 第 0 步：先确认对象类型
动手搜之前先问清删的是什么：**模型**（model slug）、**provider**（`providers:` 条目）、还是 **MCP server**。对象类型决定搜索词和判断口径——按错误对象搜会全盘返工。

## 第 1 步：定搜索口径
- `providers:` 的 key 是引用 ID，`name:` 只是显示名；先确认两者，再决定"什么算命中"。
- 裸词 grep 必须排除同前缀噪音。例：查 `zai` 需排除 `zai-coding`、`hp-zai`、`z-ai`（OpenRouter slug）：
  `grep -rnE 'zai' <paths> | grep -viE 'zai-coding|hp-zai|z-ai'`
- 生效范围：主 `config.yaml` + `profiles/*/config.yaml` + `cron/jobs.json` + 各 `auth.json` + `scripts/` + 技能文档。
- `sessions/`、`logs/` 是历史记录，排除；`backups/` 不算生效引用但可取证（确认删除前存在哪些 provider key、引用当时指向谁）。
- 全库扫会命中海量会话噪音，先 count 摸底再定向，输出打码 api_key。
- **模板引用也要扫**：config 值支持 `${VAR}` env 插值（如 `api_key: ${ZAI_CODING_API_KEY}`）。换密钥变量名/删 env 后，只 grep 旧 key 明文会漏掉模板引用；且各 profile 的 auxiliary 子集不一致，逐 profile 全树遍历 YAML 确认键位，不要假设各 profile 键位相同。

## 第 2 步：追解析链（"没报错" ≠ "没漂移"）
对每处命中核对实际解析路径：
1. 节内显式 `base_url`/`api_key`（auxiliary/delegation 节常自带）→ 自足；
2. env 兜底：辅助/delegation 的 key 变量按 id 推导 `HERMES_<ID大写,-→_>_API_KEY`；内置 provider 另有 `ZAI_API_KEY`/`GLM_BASE_URL`（显式 env 优先级最高）；
3. `auth.json` 的 `custom:<id>` 残留记录：指向已删除的 config 条目，无害但属残留。
同名自定义 provider 删除后，裸引用静默落到**内置同名 provider**——功能可能照常，语义已不是用户保留的那个 provider，必须单独指出。

## 第 3 步：分类输出（只汇报，不代改）
- **生效引用**：含休眠配置（未激活的 `moa.presets.default` 等），每条带 `文件:行` + 所属配置节。
- **残留记录**：auth.json 的 `custom:<id>`、闲置 env key。
- **文档与脚本**：技能文档示例、`scripts/` 里 `PROVIDER=` 硬编码、provider preset JSON——下次执行会踩。
修改建议给 `hermes config set` 命令或 yaml 行级清单，**等用户确认后由用户手动改**（SKILL.md 边界条件 7）。改完后全量复查：所有 `provider:` 引用与 `providers:` key 一一对应。

## 本环境现状（provider 整理后约定）
- 智谱 coding plan 自定义 provider：**key=`hp-zai`，显示名=`zai-coding`**，api=`https://open.bigmodel.cn/api/coding/paas/v4`；主 config + diary/genshin/qian-duoduo 四份定义一致。
- key 值存 `.env` 的 **`ZAI_CODING_API_KEY`**（default + 三 profile 四份同名变量），config 内全部为 `${ZAI_CODING_API_KEY}` 模板引用（`model.api_key`、`providers.hp-zai.api_key`、各 auxiliary 节 `api_key`）；轮换 = 改 .env + 重启，不动 config。
- 裸 `zai` = 内置官方 provider，已弃用：其专属 env `ZAI_API_KEY`/`GLM_API_KEY`/`GLM_BASE_URL` 已全部清除（含各 profile），`auth.json` 的 `zai`/`custom:zai` 记录已清。
- 典型漂移点（均已修复；审计同类问题时优先核对这些位置）：auxiliary.web_extract / session_search 的 `provider:`、主 config delegation 与各 profile memory flush 的 `provider:`、以及全配置所有 `api_key` 的模板变量名。
