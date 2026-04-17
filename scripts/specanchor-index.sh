#!/usr/bin/env bash
# SpecAnchor Index - 自动生成/更新 module-index.md (v2 YAML frontmatter)
#
# Usage:
#   specanchor-index.sh [--config=anchor.yaml] [--output=.specanchor/module-index.md]
#
# 从 .specanchor/modules/ 扫描所有 Module Spec，
# 读取 frontmatter，计算健康度，生成 v2 格式的 module-index.md。

set -euo pipefail

if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  CYAN='\033[0;36m'
  DIM='\033[2m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' CYAN='' DIM='' BOLD='' RESET=''
fi

die() { echo -e "${RED}error:${RESET} $*" >&2; exit 1; }

normalize_scalar() {
  local value="${1:-}"
  value=$(printf '%s' "$value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  if [[ ${#value} -ge 2 ]]; then
    local first_char="${value:0:1}"
    local last_char="${value:$((${#value} - 1)):1}"
    if [[ "$first_char" == "$last_char" ]] && { [[ "$first_char" == '"' ]] || [[ "$first_char" == "'" ]]; }; then
      value="${value:1:$((${#value} - 2))}"
    fi
  fi
  printf '%s\n' "$value"
}

date_to_epoch() {
  local value="$1"
  local epoch
  epoch=$(date -j -f "%Y-%m-%d" "$value" "+%s" 2>/dev/null || date -d "$value" "+%s" 2>/dev/null || true)
  printf '%s\n' "$epoch"
}

parse_yaml_field() {
  local file="$1" field="$2" default="$3"
  if [[ -f "$file" ]]; then
    local raw val
    raw=$(awk -v field="$field" '
      $0 ~ "^    " field ":" {
        sub("^    " field ": *", "", $0)
        print
        exit
      }
      $0 ~ "^  " field ":" {
        sub("^  " field ": *", "", $0)
        print
        exit
      }
      $0 ~ "^" field ":" {
        sub("^" field ": *", "", $0)
        print
        exit
      }
    ' "$file")
    val=$(printf '%s' "$raw" | sed 's/[[:space:]]#.*$//')
    if [[ -z "$val" ]]; then
      echo "$default"
      return
    fi
    normalize_scalar "$val"
  else
    echo "$default"
  fi
}

parse_frontmatter_field() {
  local file="$1" field="$2"
  local raw
  raw=$(awk -v field="$field" '
    /^---$/ { in_frontmatter = !in_frontmatter; next }
    in_frontmatter && $0 ~ "^  " field ":" {
      sub("^  " field ": *", "", $0)
      print
      exit
    }
  ' "$file")
  normalize_scalar "$raw"
}

find_config() {
  if [[ -f "anchor.yaml" ]]; then
    echo "anchor.yaml"
  elif [[ -f ".specanchor/config.yaml" ]]; then
    echo ".specanchor/config.yaml"
  else
    die "未找到配置文件（anchor.yaml 或 .specanchor/config.yaml）"
  fi
}

compute_health() {
  local module_path="$1" last_synced="$2" stale_days="$3" outdated_days="$4"

  if [[ -z "$last_synced" ]] || [[ ! -d "$module_path" ]]; then
    echo "STALE"
    return
  fi

  local commits_since=0
  if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    commits_since=$(git log --oneline --since="${last_synced} 00:00:00" -- "$module_path" 2>/dev/null | wc -l | tr -d ' ')
  fi

  if [[ $commits_since -eq 0 ]]; then
    echo "FRESH"
    return
  fi

  local synced_epoch now_epoch days_since
  synced_epoch=$(date_to_epoch "$last_synced")
  if [[ -z "$synced_epoch" ]]; then
    echo "STALE"
    return
  fi
  now_epoch=$(date "+%s")
  days_since=$(( (now_epoch - synced_epoch) / 86400 ))

  if [[ $days_since -ge $outdated_days ]]; then
    echo "OUTDATED"
  elif [[ $days_since -ge $stale_days ]]; then
    echo "STALE"
  else
    echo "DRIFTED"
  fi
}

health_icon() {
  case "$1" in
    FRESH)    echo "🟢" ;;
    DRIFTED)  echo "🟡" ;;
    STALE)    echo "🟠" ;;
    OUTDATED) echo "🔴" ;;
    *)        echo "⚪" ;;
  esac
}

generate_index() {
  local config_file="$1"
  local output_file="$2"
  local modules_dir=".specanchor/modules"

  local stale_days outdated_days
  stale_days=$(parse_yaml_field "$config_file" "stale_days" "14")
  outdated_days=$(parse_yaml_field "$config_file" "outdated_days" "30")

  [[ -d "$modules_dir" ]] || die "Module Spec 目录不存在: $modules_dir"

  local -a paths=() specs=() summaries=() sources=() statuses=()
  local -a versions=() syncs=() owners=() healths=()

  local fresh=0 drifted=0 stale=0 outdated=0 covered=0

  for spec_file in "$modules_dir"/*.spec.md; do
    [[ -f "$spec_file" ]] || continue

    local mp ms summary status version last_synced owner health source
    mp=$(parse_frontmatter_field "$spec_file" "module_path")
    [[ -z "$mp" ]] && continue

    ms=$(basename "$spec_file")
    summary=$(parse_frontmatter_field "$spec_file" "summary")
    [[ -z "$summary" ]] && summary=""
    status=$(parse_frontmatter_field "$spec_file" "status")
    [[ -z "$status" ]] && status="active"
    version=$(parse_frontmatter_field "$spec_file" "version")
    [[ -z "$version" ]] && version="0.0.0"
    last_synced=$(parse_frontmatter_field "$spec_file" "last_synced")
    [[ -z "$last_synced" ]] && last_synced="unknown"
    owner=$(parse_frontmatter_field "$spec_file" "owner")
    [[ -z "$owner" ]] && owner=""

    source="native"
    health=$(compute_health "$mp" "$last_synced" "$stale_days" "$outdated_days")

    case "$health" in
      FRESH)    ((fresh++)) ;;
      DRIFTED)  ((drifted++)) ;;
      STALE)    ((stale++)) ;;
      OUTDATED) ((outdated++)) ;;
    esac
    ((covered++))

    paths+=("$mp")
    specs+=("$ms")
    summaries+=("$summary")
    sources+=("$source")
    statuses+=("$status")
    versions+=("$version")
    syncs+=("$last_synced")
    owners+=("$owner")
    healths+=("$health")
  done

  local uncovered_count=0
  local uncovered_yaml=""

  local generated_at
  generated_at=$(date "+%Y-%m-%dT%H:%M:%S")

  local total=$((covered + uncovered_count))

  {
    echo "---"
    echo "specanchor:"
    echo "  type: module-index"
    echo "  generated_at: \"${generated_at}\""
    echo "  module_count: ${total}"
    echo "  covered_count: ${covered}"
    echo "  uncovered_count: ${uncovered_count}"
    echo "  health_summary:"
    echo "    fresh: ${fresh}"
    echo "    drifted: ${drifted}"
    echo "    stale: ${stale}"
    echo "    outdated: ${outdated}"
    echo ""

    if [[ $covered -gt 0 ]]; then
      echo "modules:"
      for i in "${!paths[@]}"; do
        echo "  - path: \"${paths[$i]}\""
        echo "    spec: \"${specs[$i]}\""
        echo "    summary: \"${summaries[$i]}\""
        echo "    source: ${sources[$i]}"
        echo "    status: ${statuses[$i]}"
        echo "    version: \"${versions[$i]}\""
        echo "    last_synced: \"${syncs[$i]}\""
        echo "    owner: \"${owners[$i]}\""
        echo "    health: ${healths[$i]}"
        echo ""
      done
    else
      echo "modules: []"
    fi

    if [[ $uncovered_count -gt 0 ]]; then
      echo "$uncovered_yaml"
    else
      echo "uncovered: []"
    fi

    echo "---"
    echo ""
    echo "# Module Spec 索引"
    echo ""
    echo "<!-- 以下由 specanchor-index.sh 从 frontmatter 自动渲染，请勿手动编辑 -->"
    echo ""

    local health_str=""
    [[ $fresh -gt 0 ]]    && health_str="${health_str} 🟢 ${fresh} FRESH"
    [[ $drifted -gt 0 ]]  && health_str="${health_str} 🟡 ${drifted} DRIFTED"
    [[ $stale -gt 0 ]]    && health_str="${health_str} 🟠 ${stale} STALE"
    [[ $outdated -gt 0 ]] && health_str="${health_str} 🔴 ${outdated} OUTDATED"
    [[ -z "$health_str" ]] && health_str=" (empty)"

    echo "**统计**: ${total} 个模块 | ${covered} 已覆盖 | ${uncovered_count} 未覆盖 | 健康度:${health_str}"
    echo ""

    if [[ $covered -gt 0 ]]; then
      echo "| 模块路径 | 摘要 | 状态 | 健康度 | 版本 | 最后同步 |"
      echo "|----------|------|------|--------|------|---------|"
      for i in "${!paths[@]}"; do
        local icon
        icon=$(health_icon "${healths[$i]}")
        local status_icon="✅"
        [[ "${statuses[$i]}" != "active" ]] && status_icon="⚠️"
        echo "| ${paths[$i]} | ${summaries[$i]} | ${status_icon} ${statuses[$i]} | ${icon} ${healths[$i]} | ${versions[$i]} | ${syncs[$i]} |"
      done
    fi
  } > "$output_file"

  echo -e "${GREEN}✓${RESET} module-index.md 已更新: ${CYAN}${output_file}${RESET}"
  echo -e "  ${covered} 个模块 | 健康度: 🟢${fresh} 🟡${drifted} 🟠${stale} 🔴${outdated}"
}

main() {
  local config_file=""
  local output_file=".specanchor/module-index.md"

  for arg in "$@"; do
    case "$arg" in
      --config=*) config_file="${arg#--config=}" ;;
      --output=*) output_file="${arg#--output=}" ;;
      --help|-h)
        echo "Usage: specanchor-index.sh [--config=anchor.yaml] [--output=.specanchor/module-index.md]"
        echo ""
        echo "扫描 .specanchor/modules/ 下的 Module Spec，生成 v2 格式的 module-index.md。"
        echo "健康度阈值从 anchor.yaml 的 check 配置读取。"
        exit 0
        ;;
    esac
  done

  [[ -z "$config_file" ]] && config_file=$(find_config)
  generate_index "$config_file" "$output_file"
}

main "$@"
