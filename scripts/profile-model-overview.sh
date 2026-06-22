#!/bin/bash
# 一键查看所有 profile 的模型配置全景（含错误检测）
# Usage: bash profile-model-overview.sh [--diagnose]
# Exit codes: 0=success, 1=hermes not found, 2=no profiles found
# Options:
#   --diagnose  同时检查 Gateway 状态和 API Key 配置

set -euo pipefail

DIAGNOSE=false
[[ "${1:-}" == "--diagnose" ]] && DIAGNOSE=true

# ── 前置检查 ──────────────────────────────────────
if ! command -v hermes &>/dev/null; then
  echo "❌ 错误：hermes 命令未找到。请先安装 Hermes Agent。" >&2
  echo "   安装指南：https://hermes-agent.nousresearch.com/docs" >&2
  exit 1
fi

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"

# ── 获取 profile 列表 ─────────────────────────────
PROFILES=$(hermes profile list 2>/dev/null | tail -n +4 | awk '{print $1}' | sed 's/◆//' | grep -v "^$" || true)

if [ -z "$PROFILES" ]; then
  echo "⚠️  未找到任何 profile。请检查 Hermes 是否已初始化：" >&2
  echo "   hermes profile list" >&2
  echo "   hermes init  # 如果尚未初始化" >&2
  exit 2
fi

# ── 表头 ──────────────────────────────────────────
if $DIAGNOSE; then
  printf "%-14s %-20s %-10s %-20s %-10s %-10s %-10s %-8s\n" \
    "PROFILE" "主模型" "Provider" "Vision" "Compress" "Delegat" "Gateway" "Keys"
  printf "%s\n" "$(printf '─%.0s' {1..110})"
else
  printf "%-14s %-20s %-10s %-20s %-10s %-10s\n" \
    "PROFILE" "主模型" "Provider" "Vision" "Compress" "Delegat"
  printf "%s\n" "$(printf '─%.0s' {1..90})"
fi

# ── 遍历每个 profile ──────────────────────────────
ERROR_COUNT=0
WARN_COUNT=0

for p in $PROFILES; do
  dir=$( [ "$p" = "default" ] && echo "$HERMES_HOME" || echo "$HERMES_HOME/profiles/$p" )
  cfg="$dir/config.yaml"

  if [ ! -f "$cfg" ]; then
    if $DIAGNOSE; then
      printf "%-14s %-20s %-10s %-20s %-10s %-10s %-10s %-8s\n" \
        "$p" "⚠ 无config" "—" "—" "—" "—" "—" "—"
    else
      printf "%-14s %-20s\n" "$p" "⚠ 无 config.yaml"
    fi
    ERROR_COUNT=$((ERROR_COUNT + 1))
    continue
  fi

  # Parse YAML with awk (simple key-value extraction)
  main_model=$(awk '/^model:/{found=1} found && /^  default:/{print $2; exit}' "$cfg" 2>/dev/null || echo "")
  main_provider=$(awk '/^model:/{found=1} found && /^  provider:/{print $2; exit}' "$cfg" 2>/dev/null || echo "")
  vision_model=$(awk '/auxiliary:/{found=1} found && /vision:/{v=1} v && /model:/{print $2; exit}' "$cfg" 2>/dev/null || echo "")
  compress_model=$(awk '/auxiliary:/{found=1} found && /compression:/{c=1} c && /model:/{print $2; exit}' "$cfg" 2>/dev/null || echo "")
  deleg_model=$(awk '/^delegation:/{found=1} found && /^  model:/{print $2; exit}' "$cfg" 2>/dev/null || echo "")

  [ -z "$main_model" ] && main_model="(inherit)"
  [ -z "$main_provider" ] && main_provider="—"
  [ -z "$vision_model" ] && vision_model="(auto)"
  [ -z "$compress_model" ] && compress_model="(auto)"
  [ -z "$deleg_model" ] && deleg_model="(inherit)"

  if $DIAGNOSE; then
    # Check gateway status
    gw_status=$(hermes -p "$p" gateway status 2>&1 | grep -oE "(running|stopped|not running)" | head -1 || echo "unknown")
    [ -z "$gw_status" ] && gw_status="unknown"
    
    # Check API keys
    env_file="$dir/.env"
    key_count=0
    if [ -f "$env_file" ]; then
      key_count=$(grep -c "_API_KEY" "$env_file" 2>/dev/null || echo "0")
    fi
    
    # Flag warnings
    warn=""
    if [ "$key_count" -eq 0 ]; then
      warn="⚠no-keys"
      WARN_COUNT=$((WARN_COUNT + 1))
    fi
    if [ "$gw_status" != "running" ] && [ "$gw_status" != "unknown" ]; then
      warn="${warn:+$warn }⚠stopped"
      WARN_COUNT=$((WARN_COUNT + 1))
    fi

    printf "%-14s %-20s %-10s %-20s %-10s %-10s %-10s %3dkey%s\n" \
      "$p" "$main_model" "$main_provider" "$vision_model" "$compress_model" "$deleg_model" "$gw_status" "$key_count" "${warn:+ $warn}"
  else
    printf "%-14s %-20s %-10s %-20s %-10s %-10s\n" \
      "$p" "$main_model" "$main_provider" "$vision_model" "$compress_model" "$deleg_model"
  fi
done

# ── 尾部提示 ──────────────────────────────────────
echo ""
PROFILE_COUNT=$(echo "$PROFILES" | wc -l | tr -d ' ')
echo "📊 共 ${PROFILE_COUNT} 个 profile"

if [ "$ERROR_COUNT" -gt 0 ]; then
  echo "⚠️  ${ERROR_COUNT} 个 profile 缺少 config.yaml，可能需要初始化或检查路径" >&2
fi

if $DIAGNOSE && [ "$WARN_COUNT" -gt 0 ]; then
  echo "⚠️  ${WARN_COUNT} 个警告（缺 key 或 Gateway 未运行）" >&2
fi

echo ""
echo "💡 提示："
echo "   切换模型后需重启 Gateway 生效 → hermes -p <name> gateway restart"
echo "   诊断模式（含 Gateway 状态和 Key 检查）→ bash $0 --diagnose"
