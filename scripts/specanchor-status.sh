#!/usr/bin/env bash
# SpecAnchor Status - 显示 Spec 状态和覆盖率
#
# Usage:
#   specanchor-status.sh [--config=anchor.yaml] [--format=summary|json]
#
# 输出: Global Spec 统计、Module Spec 覆盖率和健康度、Task Spec 统计、来源统计。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

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
declare -a S_GLOBAL_FILES=()
S_CONFIG_DISPLAY=""

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

join_by() {
  local sep="$1"
  shift

  local out="" item
  for item in "$@"; do
    if [[ -n "$out" ]]; then
      out="${out}${sep}${item}"
    else
      out="$item"
    fi
  done

  printf '%s' "$out"
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

collect_stats() {
  local config="$1"

  S_GLOBAL_FILES=()
  S_CONFIG_DISPLAY=$(sa_config_label "$config")

  local mode
  mode=$(sa_parse_config_field "$config" "mode" "full")

  local stale_days outdated_days
  stale_days=$(sa_parse_config_field "$config" "stale_days" "14")
  outdated_days=$(sa_parse_config_field "$config" "outdated_days" "30")

  local global_count=0 global_lines=0
  if [[ -d ".specanchor/global" ]]; then
    for f in .specanchor/global/*.spec.md; do
      [[ -f "$f" ]] || continue
      global_count=$((global_count + 1))
      S_GLOBAL_FILES+=("$(basename "$f")")
      local lines
      lines=$(wc -l < "$f" | tr -d ' ')
      global_lines=$((global_lines + lines))
    done
  fi

  local module_count=0 fresh=0 drifted=0 stale=0 outdated=0
  if [[ -d ".specanchor/modules" ]]; then
    for f in .specanchor/modules/*.spec.md; do
      [[ -f "$f" ]] || continue
      module_count=$((module_count + 1))

      local mp ls
      mp=$(parse_frontmatter_field "$f" "module_path")
      ls=$(parse_frontmatter_field "$f" "last_synced")

      if [[ -z "$mp" ]] || [[ -z "$ls" ]] || [[ ! -e "$mp" ]]; then
        stale=$((stale + 1))
        continue
      fi

      local commits_since=0
      if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
        commits_since=$(git log --oneline --since="${ls} 00:00:00" -- "$mp" 2>/dev/null | wc -l | tr -d ' ')
      fi

      if [[ $commits_since -eq 0 ]]; then
        fresh=$((fresh + 1))
      else
        local synced_epoch now_epoch days_since
        synced_epoch=$(sa_date_to_epoch "$ls")
        if [[ -z "$synced_epoch" ]]; then
          stale=$((stale + 1))
          continue
        fi
        now_epoch=$(date "+%s")
        days_since=$(( (now_epoch - synced_epoch) / 86400 ))
        if [[ $days_since -ge $outdated_days ]]; then
          outdated=$((outdated + 1))
        elif [[ $days_since -ge $stale_days ]]; then
          stale=$((stale + 1))
        else
          drifted=$((drifted + 1))
        fi
      fi
    done
  fi

  local task_active=0 task_archived=0
  if [[ -d ".specanchor/tasks" ]]; then
    task_active=$(find ".specanchor/tasks" -name "*.spec.md" 2>/dev/null | wc -l | tr -d ' ')
  fi
  if [[ -d ".specanchor/archive" ]]; then
    task_archived=$(find ".specanchor/archive" -name "*.spec.md" 2>/dev/null | wc -l | tr -d ' ')
  fi

  local index_format="missing"
  local index_path=""
  if index_path=$(sa_load_spec_index_or_legacy "$config" 2>/dev/null); then
    case "$(sa_index_type "$index_path")" in
      spec-index) index_format="v3" ;;
      module-index) index_format="legacy-module-v2" ;;
      *) index_format="legacy" ;;
    esac
  fi

  S_MODE="$mode"
  S_GLOBAL_COUNT=$global_count
  S_GLOBAL_LINES=$global_lines
  S_MODULE_COUNT=$module_count
  S_FRESH=$fresh
  S_DRIFTED=$drifted
  S_STALE=$stale
  S_OUTDATED=$outdated
  S_TASK_ACTIVE=$task_active
  S_TASK_ARCHIVED=$task_archived
  S_INDEX_FORMAT="$index_format"
  S_STALE_DAYS=$stale_days
  S_OUTDATED_DAYS=$outdated_days
}

output_summary() {
  local config="$1"

  echo -e "${BOLD}SpecAnchor Status [${S_MODE}]${RESET}"
  echo -e "  Config: ${CYAN}${S_CONFIG_DISPLAY}${RESET}"
  echo ""

  echo -e "  Assembly Trace:"
  if [[ ${#S_GLOBAL_FILES[@]} -gt 0 ]]; then
    echo -e "    - Global: ${CYAN}summary${RESET} -> $(join_by ", " "${S_GLOBAL_FILES[@]}")"
  else
    echo -e "    - Global: ${YELLOW}none${RESET} -> .specanchor/global/ has no loadable spec"
  fi
  if [[ "$S_MODE" == "full" ]]; then
    echo -e "    - Module: ${DIM}deferred${RESET} -> none (status does not preload module bodies)"
  else
    echo -e "    - Module: ${DIM}sources-only${RESET} -> none (external specs load on demand)"
  fi
  echo ""

  echo -e "  Global Specs: ${S_GLOBAL_COUNT} file(s), ${S_GLOBAL_LINES} lines total"

  echo -e "  Module Specs: ${S_MODULE_COUNT} module(s)"
  if [[ $S_MODULE_COUNT -gt 0 ]]; then
    echo -e "    健康度: 🟢${S_FRESH} FRESH  🟡${S_DRIFTED} DRIFTED  🟠${S_STALE} STALE  🔴${S_OUTDATED} OUTDATED"
  fi

  echo -n "  Spec Index: "
  case "$S_INDEX_FORMAT" in
    v3)     echo -e "${GREEN}v3 (structured)${RESET}" ;;
    legacy-module-v2) echo -e "${YELLOW}legacy module-index v2${RESET} — 建议运行 specanchor_index 迁移" ;;
    legacy) echo -e "${YELLOW}legacy (Markdown table)${RESET} — 建议运行 specanchor_index 迁移" ;;
    missing) echo -e "${YELLOW}missing${RESET} — 建议运行 specanchor_index 生成" ;;
  esac

  echo -e "  Task Specs: ${S_TASK_ACTIVE} active, ${S_TASK_ARCHIVED} archived"
  echo -e "  ${DIM}Thresholds: stale_days=${S_STALE_DAYS}, outdated_days=${S_OUTDATED_DAYS}${RESET}"

  if [[ $S_MODULE_COUNT -gt 0 ]]; then
    echo ""
    echo -e "  ${BOLD}Module Details:${RESET}"
    for f in .specanchor/modules/*.spec.md; do
      [[ -f "$f" ]] || continue
      local name mp ls status version
      name=$(parse_frontmatter_field "$f" "module_name")
      mp=$(parse_frontmatter_field "$f" "module_path")
      ls=$(parse_frontmatter_field "$f" "last_synced")
      status=$(parse_frontmatter_field "$f" "status")
      version=$(parse_frontmatter_field "$f" "version")
      [[ -z "$name" ]] && name=$(basename "$f" .spec.md)
      [[ -z "$status" ]] && status="unknown"
      [[ -z "$version" ]] && version="?"

      echo -e "    ${CYAN}${name}${RESET} (${mp:-?}) — v${version}, synced ${ls:-unknown}, ${status}"
    done
  fi
}

output_json() {
  printf '{\n'
  printf '  "mode": "%s",\n' "$S_MODE"
  printf '  "assembly_trace": {\n'
  printf '    "global": {"mode":"summary","files":['
  local i
  for i in "${!S_GLOBAL_FILES[@]}"; do
    [[ $i -gt 0 ]] && printf ','
    printf '"%s"' "${S_GLOBAL_FILES[$i]}"
  done
  printf ']},\n'
  if [[ "$S_MODE" == "full" ]]; then
    printf '    "module": {"mode":"deferred","files":[],"note":"status does not preload module bodies"}\n'
  else
    printf '    "module": {"mode":"sources-only","files":[],"note":"external specs load on demand"}\n'
  fi
  printf '  },\n'
  printf '  "global_specs": {"count": %d, "lines": %d},\n' "$S_GLOBAL_COUNT" "$S_GLOBAL_LINES"
  printf '  "module_specs": {"count": %d, "health": {"fresh": %d, "drifted": %d, "stale": %d, "outdated": %d}},\n' \
    "$S_MODULE_COUNT" "$S_FRESH" "$S_DRIFTED" "$S_STALE" "$S_OUTDATED"
  printf '  "task_specs": {"active": %d, "archived": %d},\n' "$S_TASK_ACTIVE" "$S_TASK_ARCHIVED"
  printf '  "spec_index_format": "%s",\n' "$S_INDEX_FORMAT"
  printf '  "thresholds": {"stale_days": %d, "outdated_days": %d}\n' "$S_STALE_DAYS" "$S_OUTDATED_DAYS"
  printf '}\n'
}

main() {
  local config_file=""
  local format="summary"

  for arg in "$@"; do
    case "$arg" in
      --config=*)  config_file="${arg#--config=}" ;;
      --format=*)  format="${arg#--format=}" ;;
      --help|-h)
        echo "Usage: specanchor-status.sh [--config=anchor.yaml] [--format=summary|json]"
        echo ""
        echo "显示 SpecAnchor 状态和覆盖率概览。"
        exit 0
        ;;
    esac
  done

  if [[ -z "$config_file" ]]; then
    config_file=$(sa_find_config) || die "未找到配置文件（anchor.yaml 或 .specanchor/config.yaml）"
  fi
  collect_stats "$config_file"

  case "$format" in
    summary) output_summary "$config_file" ;;
    json)    output_json ;;
    *)       die "Unknown format: $format (use: summary | json)" ;;
  esac
}

main "$@"
