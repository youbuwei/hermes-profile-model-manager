# Repository Guidelines

## Project Overview

**Hermes Profile Model Manager** (v2.1.0) — a Hermes Agent skill for viewing, switching, and managing LLM model configurations across all Hermes profiles. Covers main model, auxiliary models (vision, compression, web_extract, session_search), and delegation models. Supports single-profile and batch operations, plus one-command provider switching with intelligent model presets.

This is a **skill package**, not a compiled application. It ships as a `SKILL.md` consumed by the Hermes runtime plus a companion shell script.

## Architecture & Data Flow

```
SKILL.md (v2.1.0)                          # Skill definition + full user-facing docs
  ├─ §Agent: 智能触发指引                   # Intent → keyword mapping for auto-trigger
  ├─ §0: 快速开始
  ├─ §1-3: 配置架构 / 查看 / 切换            # Core operations
  ├─ §4-5: Provider 速查 / 模型参考
  ├─ §6: 典型工作流 (4 scenarios)
  ├─ §7: 异常处理与排错 (7 error scenarios)
  ├─ §8: FAQ (10 items)
  ├─ §9: 反模式与边界条件 (4 + 4)
  ├─ §10: 限制与注意事项
  └─ §11: Profile Model Manager 脚本 (3 modes)
       └─ calls → scripts/profile-model-overview.sh
                    ├─ Mode 1: 全景 — all profiles overview
                    ├─ Mode 2: 详情 — single profile detail
                    └─ Mode 3: 智能切换 — preview / --apply provider switch
                    ├─ reads ~/.hermes/profiles/*/config.yaml
                    └─ reads scripts/provider-presets.json for model mappings

scripts/profile-model-overview.sh          # 3-mode CLI: overview / detail / smart switch
scripts/provider-presets.json              # Provider → model presets (10 providers, 6 roles each)
references/
  skillhub-publishing.md                   # SkillHub Web publishing (original)
  skillhub-and-github-publishing.md        # SkillHub + GitHub management workflow
README.md                                  # Install & quick-start
```

Hermes profiles live at `~/.hermes/profiles/<name>/config.yaml`. Each profile has three model config blocks: `model:` (main), `auxiliary:` (vision/compression/web_extract/session_search), `delegation:` (sub-agent). API keys are per-profile in `.env`.

## Key Directories
| Path | Purpose |
|---|---|
| `scripts/` | Shell utilities (`profile-model-overview.sh`) + provider presets JSON |
| `references/` | External workflow notes (SkillHub publishing, GitHub management) |

## Development Commands

```bash
# View all profile model configs (overview mode)
bash scripts/profile-model-overview.sh

# View single profile detail (detail mode)
bash scripts/profile-model-overview.sh <profile>

# Preview provider switch (dry-run, no changes)
bash scripts/profile-model-overview.sh <profile> <provider>

# Execute provider switch + restart Gateway
bash scripts/profile-model-overview.sh <profile> --apply <provider>
```

There is no build step, test suite, or linter. The project is shell + Markdown only.

## Code Conventions & Common Patterns
### Shell scripting
- **Strict mode**: `set -euo pipefail` in all scripts.
- **Error handling**: Explicit exit codes (0=success, 1=hermes not found, 2=no profiles, 3=invalid args, 4=config failed). Errors counted and reported at end.
- **YAML parsing**: Done via `awk` — no dependencies on `yq` or Python. Extracted into `yaml_get()` function with section/subsection/key support.
- **Heredoc-free**: All output via `printf` for consistent column formatting.
- **Profile default special case**: `default` profile has no `-p` flag and its config is at `$HERMES_HOME/config.yaml` (not under `profiles/`).
- **Provider presets**: Stored in `scripts/provider-presets.json`. Loaded via `python3` one-liners (`json_query()`, `preset_model()`, `preset_name()`, `preset_env()`). Each provider maps 6 roles: main, vision, compression, web_extract, session_search, delegation.

### SKILL.md structure
- YAML frontmatter with `name`, `description`, `version`, `author`, `metadata`.
- Numbered sections (Agent + 0–11): Quick Start → Architecture → Operations → Troubleshooting → Anti-patterns → FAQ → Limitations.
- All CLI examples include **expected output** so agents can validate success.
- Tables for provider reference and model specs.
- v2.1.0: Script §11 expanded from 1 mode to 3 (overview / detail / smart switch with preview+apply).

### Hermes CLI patterns
- `hermes config set <yaml.path> <value>` — dot-path YAML merge, non-destructive.
- `hermes -p <profile> config set ...` — target non-default profiles.
- Every model change **must** be followed by `hermes -p <profile> gateway restart`.
- Validation after every operation: `hermes -p <profile> config show` + `hermes chat -q "..." -Q`.

### Anti-patterns documented in §9
1. Changing model without changing provider (mismatch)
2. Switching provider without restarting Gateway
3. Switching provider without checking API key in `.env`
4. Using `-p default` (default profile must omit `-p`)

## Important Files

| File | Role |
|---|---|
| `SKILL.md` | Skill definition — the single deliverable Hermes loads (v2.1.0) |
| `scripts/profile-model-overview.sh` | 3-mode CLI: overview / detail / smart provider switch |
| `scripts/provider-presets.json` | Provider → model presets (10 providers, 6 roles each) |
| `README.md` | Install instructions, quick-start, version history |
| `references/skillhub-and-github-publishing.md` | SkillHub Web + GitHub repo management workflow |
| `references/skillhub-publishing.md` | SkillHub Web publishing notes (original, simpler) |

## Runtime/Tooling Preferences
- **Runtime**: Bash (no Node/Bun/Python required).
- **Runtime**: Bash + `python3` for JSON parsing (pre-installed on macOS/Linux).
- **CLI dependency**: `hermes` must be installed and on `$PATH`.
- **Config location**: `~/.hermes/` (overridable via `$HERMES_HOME`).
- **No package manager**: Files are copied or installed via `hermes skill install`.

## Testing & QA

No automated tests. Verification is manual:

```bash
# Syntax check
bash -n scripts/profile-model-overview.sh

# Run overview mode
bash scripts/profile-model-overview.sh

# Run detail mode for a profile
bash scripts/profile-model-overview.sh <profile>

# Preview a provider switch (dry-run)
bash scripts/profile-model-overview.sh <profile> zai
```

Quality checks: script exits with code 0 on success, 1 if `hermes` not found, 2 if no profiles exist, 3 on invalid args, 4 if config failed. Errors are counted and reported.

### Supported providers and their model presets

Presets live in `scripts/provider-presets.json`. Structure per provider:

```json
{
  "provider-name": {
    "name": "Display Name",
    "env": "API_KEY_ENV_VAR",
    "base_url": "https://...",       // optional — set only if provider requires explicit base_url
    "note": "description",           // optional
    "models": {
      "main": "...",
      "vision": "...",
      "compression": "...",
      "web_extract": "...",
      "session_search": "...",
      "delegation": "..."
    }
  }
}
```

**Zhipu (智谱) has 4 variants** — differentiated by region (CN/Global) and access mode (Coding Plan/Direct API):

| Key | Region | Mode | Base URL | Env |
|---|---|---|---|---|
| `zhipu` | CN | Coding Plan (订阅制) | `open.bigmodel.cn/api/coding/paas/v4` | `ZHIPU_API_KEY` |
| `zhipu-direct` | CN | Direct API (按量计费) | `open.bigmodel.cn/api/paas/v4` | `ZHIPU_API_KEY` |
| `zai` | Global | Coding Plan (订阅制) | `api.z.ai/api/coding/paas/v4` | `ZAI_API_KEY` |
| `zai-direct` | Global | Direct API (按量计费) | `api.z.ai/api/paas/v4` | `ZAI_API_KEY` |

When a preset has `base_url`, the script automatically sets `model.base_url` during `--apply`. Providers without `base_url` rely on Hermes defaults.

**To add a new provider**: add a new top-level key to `provider-presets.json`. No script changes needed — `list_providers()` auto-discovers all keys.
