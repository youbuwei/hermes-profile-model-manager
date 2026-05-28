#!/bin/bash
# Hermes Profile Model Manager
# Usage:
#   bash profile-model-overview.sh                          # 查看所有 profile 全景
#   bash profile-model-overview.sh <profile>                 # 查看单个 profile 详情
#   bash profile-model-overview.sh <profile> <provider>      # 按 provider 智能配置（预览）
#   bash profile-model-overview.sh <profile> --apply <provider>  # 确认执行配置
# Examples:
#   bash profile-model-overview.sh reasoner                  # 查看 reasoner 详情
#   bash profile-model-overview.sh reasoner zai              # 预览切换到智谱的效果
#   bash profile-model-overview.sh reasoner --apply zai      # 执行切换并重启
# Exit codes: 0=success, 1=hermes not found, 2=no profiles, 3=invalid args, 4=config failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PRESETS_FILE="$SCRIPT_DIR/provider-presets.json"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"

# ══════════════════════════════════════════════════════════
# JSON 预设加载
# ════════════════════════════════════════════════════════
# JSON 预设加载（通过 python3 单行，零外部依赖）
# ════════════════════════════════════════════════════════

# json_query <python_expr> — 对 presets JSON 执行表达式，返回结果
# 例: json_query "d['xiaomi']['models']['vision']"
json_query() {
  python3 -c 'import json,sys
with open(sys.argv[1]) as f: d=json.load(f)
r='"$1"'
print(r if isinstance(r,str) else r,end="")' "$PRESETS_FILE"
}

# 获取 provider 预设中的模型名
preset_model() {
  local provider="$1" role="$2"
  json_query "d['${provider}']['models']['${role}']"
}

# 获取 provider 显示名
preset_name() {
  json_query "d['${1}']['name']"
}

# 获取 provider 所需环境变量名
preset_env() {
  json_query "d['${1}']['env']"
}

# 获取 provider base_url（可选，部分 provider 无此字段）
preset_base_url() {
  json_query "d.get('${1}',{}).get('base_url','')"
}

# 列出所有已注册的 provider
list_providers() {
  python3 -c 'import json,sys
with open(sys.argv[1]) as f: d=json.load(f)
print(" ".join(d.keys()))' "$PRESETS_FILE"
}

# 校验预设文件
if [ ! -f "$PRESETS_FILE" ]; then
  echo "❌ 预设文件不存在: $PRESETS_FILE" >&2
  exit 3
fi

SUPPORTED_PROVIDERS=$(list_providers)

# ══════════════════════════════════════════════════════════
# 工具函数
# ══════════════════════════════════════════════════════════

cfg_path() {
  local profile="$1"
  if [ "$profile" = "default" ]; then
    echo "$HERMES_HOME/config.yaml"
  else
    echo "$HERMES_HOME/profiles/$profile/config.yaml"
  fi
}

# 从 config.yaml 提取值
# 用法: yaml_get <file> <section> <key>
#       yaml_get <file> <section> <subsection> <key>
yaml_get() {
  local file="$1"; shift
  if [ $# -eq 2 ]; then
    local section="$1" key="$2"
    awk -v sec="^${section}:" -v key="^  ${key}:" '
      $0 ~ sec { in_sec=1; next }
      in_sec && /^[^ \t]/ { exit }
      in_sec && $0 ~ key { sub(/^[^:]*:[ \t]*/, ""); print; exit }
    ' "$file" 2>/dev/null || true
  elif [ $# -eq 3 ]; then
    local section="$1" sub="$2" key="$3"
    awk -v sec="^${section}:" -v sub="^  ${sub}:" -v key="^    ${key}:" '
      $0 ~ sec  { in_sec=1; next }
      in_sec && /^[^ \t]/ { in_sec=0 }
      in_sec && $0 ~ sub  { in_sub=1; next }
      in_sub && /^  [^ \t]/ { in_sub=0 }
      in_sub && $0 ~ key { sub(/^[^:]*:[ \t]*/, ""); print; exit }
    ' "$file" 2>/dev/null || true
  fi
}

# 对 profile 执行 hermes config set
hermes_set() {
  local profile="$1"
  local key="$2"
  local value="$3"
  if [ "$profile" = "default" ]; then
    hermes config set "$key" "$value"
  else
    hermes -p "$profile" config set "$key" "$value"
  fi
}

# 重启 Gateway
gateway_restart() {
  local profile="$1"
  if [ "$profile" = "default" ]; then
    hermes gateway restart
  else
    hermes -p "$profile" gateway restart
  fi
}

# ══════════════════════════════════════════════════════════
# Mode 1: 全景模式 — 查看所有 profile
# ══════════════════════════════════════════════════════════

cmd_overview() {
  local PROFILES
  PROFILES=$(hermes profile list 2>/dev/null | tail -n +4 | awk '{print $1}' | sed 's/◆//' | grep -v "^$" || true)

  if [ -z "$PROFILES" ]; then
    echo "⚠️  未找到任何 profile。请检查 Hermes 是否已初始化：" >&2
    echo "   hermes profile list" >&2
    echo "   hermes init  # 如果尚未初始化" >&2
    exit 2
  fi

  printf "%-14s %-20s %-10s %-20s %-14s %-14s %-14s\n" \
    "PROFILE" "主模型" "Provider" "Vision" "Compression" "WebExtract" "Delegation"
  printf "%s\n" "$(printf '─%.0s' {1..110})"

  local ERROR_COUNT=0
  for p in $PROFILES; do
    local cfg
    cfg=$(cfg_path "$p")

    if [ ! -f "$cfg" ]; then
      printf "%-14s %-20s\n" "$p" "⚠ 无 config.yaml"
      ERROR_COUNT=$((ERROR_COUNT + 1))
      continue
    fi

    local main_model main_provider vision_model compress_model extract_model deleg_model
    main_model=$(yaml_get "$cfg" "model" "default")
    main_provider=$(yaml_get "$cfg" "model" "provider")
    vision_model=$(yaml_get "$cfg" "auxiliary" "vision" "model")
    compress_model=$(yaml_get "$cfg" "auxiliary" "compression" "model")
    extract_model=$(yaml_get "$cfg" "auxiliary" "web_extract" "model")
    deleg_model=$(yaml_get "$cfg" "delegation" "model")

    [ -z "$main_model" ]      && main_model="(inherit)"
    [ -z "$main_provider" ]   && main_provider="—"
    [ -z "$vision_model" ]    && vision_model="(auto)"
    [ -z "$compress_model" ]  && compress_model="(auto)"
    [ -z "$extract_model" ]   && extract_model="(auto)"
    [ -z "$deleg_model" ]     && deleg_model="(inherit)"

    printf "%-14s %-20s %-10s %-20s %-14s %-14s %-14s\n" \
      "$p" "$main_model" "$main_provider" "$vision_model" "$compress_model" "$extract_model" "$deleg_model"
  done

  echo ""
  local PROFILE_COUNT
  PROFILE_COUNT=$(echo "$PROFILES" | wc -l | tr -d ' ')
  echo "📊 共 ${PROFILE_COUNT} 个 profile"

  if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "⚠️  ${ERROR_COUNT} 个 profile 缺少 config.yaml" >&2
  fi

  echo ""
  echo "💡 提示："
  echo "   查看单个 profile 详情:  bash $0 <profile>"
  echo "   切换 provider:          bash $0 <profile> <provider>"
}

# ══════════════════════════════════════════════════════════
# Mode 2: 单 profile 详情
# ══════════════════════════════════════════════════════════

cmd_detail() {
  local profile="$1"
  local cfg
  cfg=$(cfg_path "$profile")

  if [ ! -f "$cfg" ]; then
    echo "❌ Profile '$profile' 的 config.yaml 不存在: $cfg" >&2
    exit 3
  fi

  # ── 主模型 ────────────────────────────────────────
  local main_model main_provider main_base main_ctx main_mode
  main_model=$(yaml_get "$cfg" "model" "default")
  main_provider=$(yaml_get "$cfg" "model" "provider")
  main_base=$(yaml_get "$cfg" "model" "base_url")
  main_ctx=$(yaml_get "$cfg" "model" "context_length")
  main_mode=$(yaml_get "$cfg" "model" "api_mode")

  # ── 辅助模型 ──────────────────────────────────────
  local vis_prov vis_model vis_to
  vis_prov=$(yaml_get "$cfg" "auxiliary" "vision" "provider")
  vis_model=$(yaml_get "$cfg" "auxiliary" "vision" "model")
  vis_to=$(yaml_get "$cfg" "auxiliary" "vision" "timeout")

  local comp_prov comp_model comp_to
  comp_prov=$(yaml_get "$cfg" "auxiliary" "compression" "provider")
  comp_model=$(yaml_get "$cfg" "auxiliary" "compression" "model")
  comp_to=$(yaml_get "$cfg" "auxiliary" "compression" "timeout")

  local ext_prov ext_model ext_to
  ext_prov=$(yaml_get "$cfg" "auxiliary" "web_extract" "provider")
  ext_model=$(yaml_get "$cfg" "auxiliary" "web_extract" "model")
  ext_to=$(yaml_get "$cfg" "auxiliary" "web_extract" "timeout")

  local srch_prov srch_model srch_to srch_conc
  srch_prov=$(yaml_get "$cfg" "auxiliary" "session_search" "provider")
  srch_model=$(yaml_get "$cfg" "auxiliary" "session_search" "model")
  srch_to=$(yaml_get "$cfg" "auxiliary" "session_search" "timeout")
  srch_conc=$(yaml_get "$cfg" "auxiliary" "session_search" "max_concurrency")

  # ── Delegation ────────────────────────────────────
  local deleg_model deleg_provider deleg_base deleg_iter deleg_conc deleg_effort
  deleg_model=$(yaml_get "$cfg" "delegation" "model")
  deleg_provider=$(yaml_get "$cfg" "delegation" "provider")
  deleg_base=$(yaml_get "$cfg" "delegation" "base_url")
  deleg_iter=$(yaml_get "$cfg" "delegation" "max_iterations")
  deleg_conc=$(yaml_get "$cfg" "delegation" "max_concurrent_children")
  deleg_effort=$(yaml_get "$cfg" "delegation" "reasoning_effort")

  # ── 渲染 ──────────────────────────────────────────
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║  Profile: $(printf '%-44s' "$profile")║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""

  echo "── 主模型 (model) ───────────────────────────────────────"
  printf "  %-18s %s\n" "model:" "${main_model:-(未设置)}"
  printf "  %-18s %s\n" "provider:" "${main_provider:-(未设置)}"
  printf "  %-18s %s\n" "base_url:" "${main_base:-(自动)}"
  printf "  %-18s %s\n" "context_length:" "${main_ctx:-(默认)}"
  printf "  %-18s %s\n" "api_mode:" "${main_mode:-(默认)}"
  echo ""

  echo "── 辅助模型 (auxiliary) ─────────────────────────────────"
  printf "  %-18s %-14s %-20s %s\n" "" "Provider" "Model" "Timeout"
  printf "  %-18s %-14s %-20s %s\n" "vision:" "${vis_prov:-(auto)}" "${vis_model:-(auto)}" "${vis_to:-(默认)}"
  printf "  %-18s %-14s %-20s %s\n" "compression:" "${comp_prov:-(auto)}" "${comp_model:-(auto)}" "${comp_to:-(默认)}"
  printf "  %-18s %-14s %-20s %s\n" "web_extract:" "${ext_prov:-(auto)}" "${ext_model:-(auto)}" "${ext_to:-(默认)}"
  printf "  %-18s %-14s %-20s %s %s\n" "session_search:" "${srch_prov:-(auto)}" "${srch_model:-(auto)}" "${srch_to:-(默认)}" "conc=${srch_conc:-(默认)}"
  echo ""

  echo "── Delegation ───────────────────────────────────────────"
  printf "  %-18s %s\n" "model:" "${deleg_model:-(继承主模型)}"
  printf "  %-18s %s\n" "provider:" "${deleg_provider:-(继承主模型)}"
  printf "  %-18s %s\n" "base_url:" "${deleg_base:-(继承)}"
  printf "  %-18s %s\n" "reasoning_effort:" "${deleg_effort:-(默认)}"
  printf "  %-18s %s\n" "max_iterations:" "${deleg_iter:-(默认)}"
  printf "  %-18s %s\n" "max_concurrent:" "${deleg_conc:-(默认)}"
  echo ""

  # ── 提示 ──────────────────────────────────────────
  echo "── 可用 Provider ────────────────────────────────────────"
  echo "  $SUPPORTED_PROVIDERS"
  echo ""
  echo "💡 切换 provider:"
  echo "   bash $0 $profile <provider>          # 预览"
  echo "   bash $0 $profile --apply <provider>  # 执行"
}

# ══════════════════════════════════════════════════════════
# Mode 3: 按 Provider 智能配置
# ══════════════════════════════════════════════════════════

cmd_switch() {
  local profile="$1"
  local provider="$2"
  local apply="${3:-false}"

  # 校验 provider
  local found=false
  for p in $SUPPORTED_PROVIDERS; do
    if [ "$p" = "$provider" ]; then found=true; break; fi
  done
  if [ "$found" = "false" ]; then
    echo "❌ 不支持的 provider: $provider" >&2
    echo "   支持的 provider: $SUPPORTED_PROVIDERS" >&2
    exit 3
  fi

  local cfg
  cfg=$(cfg_path "$profile")
  if [ ! -f "$cfg" ]; then
    echo "❌ Profile '$profile' 的 config.yaml 不存在: $cfg" >&2
    exit 3
  fi

  # 从 JSON 预设读取模型
  local new_main new_vis new_comp new_ext new_srch new_deleg
  new_main=$(preset_model "$provider" "main")
  new_vis=$(preset_model "$provider" "vision")
  new_comp=$(preset_model "$provider" "compression")
  new_ext=$(preset_model "$provider" "web_extract")
  new_srch=$(preset_model "$provider" "session_search")
  new_deleg=$(preset_model "$provider" "delegation")

  if [ -z "$new_main" ]; then
    echo "❌ Provider '$provider' 预设数据不完整（缺少 main 模型）" >&2
    exit 3
  fi

  # 读取当前值
  local cur_main cur_prov cur_base cur_vis cur_comp cur_ext cur_srch cur_deleg
  cur_main=$(yaml_get "$cfg" "model" "default")
  cur_prov=$(yaml_get "$cfg" "model" "provider")
  cur_base=$(yaml_get "$cfg" "model" "base_url")
  cur_vis=$(yaml_get "$cfg" "auxiliary" "vision" "model")
  cur_comp=$(yaml_get "$cfg" "auxiliary" "compression" "model")
  cur_ext=$(yaml_get "$cfg" "auxiliary" "web_extract" "model")
  cur_srch=$(yaml_get "$cfg" "auxiliary" "session_search" "model")
  cur_deleg=$(yaml_get "$cfg" "delegation" "model")

  # 读取预设 base_url
  local new_base
  new_base=$(preset_base_url "$provider")

  # ── 预览表 ────────────────────────────────────────
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║  Profile: $(printf '%-20s' "$profile")  Provider: $(printf '%-14s' "$provider")║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""
  printf "  %-16s %-24s → %-24s %s\n" "角色" "当前值" "新值" "变更"
  printf "  %s\n" "$(printf '─%.0s' {1..78})"

  show_change() {
    local role="$1" cur="$2" new="$3"
    local mark="✅"
    [ -z "$cur" ] && cur="(未设置)"
    [ "$cur" = "$new" ] && mark="＝"
    printf "  %-16s %-24s → %-24s %s\n" "$role" "$cur" "$new" "$mark"
  }

  show_change "主模型" "${cur_main:-(未设置)}" "$new_main"
  show_change "provider" "${cur_prov:-(未设置)}" "$provider"
  [ -n "$new_base" ] && show_change "base_url" "${cur_base:-(自动)}" "$new_base"
  show_change "vision" "${cur_vis:-(auto)}" "$new_vis"
  show_change "compression" "${cur_comp:-(auto)}" "$new_comp"
  show_change "web_extract" "${cur_ext:-(auto)}" "$new_ext"
  show_change "session_search" "${cur_srch:-(auto)}" "$new_srch"
  show_change "delegation" "${cur_deleg:-(继承)}" "$new_deleg"

  echo ""

  if [ "$apply" = "false" ]; then
    echo "📋 以上为预览，未做任何修改。"
    echo ""
    echo "💡 确认执行："
    echo "   bash $0 $profile --apply $provider"
    return 0
  fi

  # ── 执行配置 ──────────────────────────────────────
  echo "🚀 正在配置..."

  local FAIL=0

  # 主模型
  if hermes_set "$profile" "model.default" "$new_main"; then
    echo "  ✅ model.default = $new_main"
  else
    echo "  ❌ 主模型设置失败" >&2; FAIL=$((FAIL + 1))
  fi

  if hermes_set "$profile" "model.provider" "$provider"; then
    echo "  ✅ model.provider = $provider"
  else
    echo "  ❌ Provider 设置失败" >&2; FAIL=$((FAIL + 1))
  fi

  # base_url（仅预设中有的 provider 才设置）
  if [ -n "$new_base" ]; then
    if hermes_set "$profile" "model.base_url" "$new_base"; then
      echo "  ✅ model.base_url = $new_base"
    else
      echo "  ⚠️  model.base_url 设置失败" >&2
    fi
  fi

  # 辅助模型
  for role in vision compression web_extract session_search; do
    local model
    case "$role" in
      vision)         model="$new_vis" ;;
      compression)    model="$new_comp" ;;
      web_extract)    model="$new_ext" ;;
      session_search) model="$new_srch" ;;
    esac

    hermes_set "$profile" "auxiliary.${role}.provider" "$provider" 2>/dev/null || true

    if hermes_set "$profile" "auxiliary.${role}.model" "$model"; then
      echo "  ✅ auxiliary.${role}.model = $model"
    else
      echo "  ⚠️  auxiliary.${role}.model 设置失败（可能不支持）" >&2
    fi
  done

  # Delegation
  if hermes_set "$profile" "delegation.model" "$new_deleg"; then
    echo "  ✅ delegation.model = $new_deleg"
  else
    echo "  ⚠️  delegation.model 设置失败（可能不支持）" >&2
  fi

  if hermes_set "$profile" "delegation.provider" "$provider" 2>/dev/null; then
    echo "  ✅ delegation.provider = $provider"
  fi

  # ── 重启 Gateway ──────────────────────────────────
  echo ""
  echo "🔄 重启 Gateway..."
  if gateway_restart "$profile" 2>/dev/null; then
    echo "  ✅ Gateway 已重启"
  else
    echo "  ⚠️  Gateway 重启失败，请手动执行: hermes -p $profile gateway restart" >&2
  fi

  # ── 结果 ──────────────────────────────────────────
  echo ""
  if [ "$FAIL" -gt 0 ]; then
    echo "⚠️  完成，但有 $FAIL 个错误。请检查上方输出。"
    exit 4
  fi

  echo "✅ Profile '$profile' 已全部切换到 $provider。"
}

# ══════════════════════════════════════════════════════════
# 入口
# ══════════════════════════════════════════════════════════

usage() {
  echo "Hermes Profile Model Manager v2.1"
  echo ""
  echo "用法:"
  echo "  $(basename "$0")                                    查看所有 profile 模型全景"
  echo "  $(basename "$0") <profile>                          查看单个 profile 详情"
  echo "  $(basename "$0") <profile> <provider>               预览切换 provider 的效果"
  echo "  $(basename "$0") <profile> --apply <provider>       执行切换并重启 Gateway"
  echo ""
  echo "支持的 Provider (见 $PRESETS_FILE):"
  echo "  $SUPPORTED_PROVIDERS"
  echo ""
  echo "示例:"
  echo "  $(basename "$0")                                    # 全景一览"
  echo "  $(basename "$0") reasoner                           # reasoner 详情"
  echo "  $(basename "$0") reasoner zai                       # 预览切到智谱"
  echo "  $(basename "$0") reasoner --apply zai               # 执行切换"
}

# 前置检查
if ! command -v hermes &>/dev/null; then
  echo "❌ 错误：hermes 命令未找到。请先安装 Hermes Agent。" >&2
  echo "   安装指南：https://hermes-agent.nousresearch.com/docs" >&2
  exit 1
fi

# 参数解析
case $# in
  0)
    cmd_overview
    ;;
  1)
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
      usage
    else
      cmd_detail "$1"
    fi
    ;;
  2)
    if [ "$1" = "--apply" ]; then
      echo "❌ 缺少 profile 名称。用法: $(basename "$0") <profile> --apply <provider>" >&2
      exit 3
    fi
    cmd_switch "$1" "$2" "false"
    ;;
  3)
    if [ "$2" != "--apply" ]; then
      echo "❌ 参数错误。用法: $(basename "$0") <profile> --apply <provider>" >&2
      exit 3
    fi
    cmd_switch "$1" "$3" "true"
    ;;
  *)
    usage
    exit 3
    ;;
esac
