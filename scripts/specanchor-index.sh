#!/usr/bin/env bash
# SpecAnchor Index - generate/update spec-index.md (v3 YAML frontmatter)
#
# Usage:
#   specanchor-index.sh [--config=anchor.yaml] [--output=.specanchor/spec-index.md] [--legacy-module-index]
#
# Scans Global, Module, and Task Specs, then writes a v3 spec-index.md.
# During the v0.4 migration window, --legacy-module-index also writes the
# legacy v2 module-index.md subset for older consumers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  CYAN='\033[0;36m'
  RESET='\033[0m'
else
  GREEN='' CYAN='' RESET=''
fi

die() { echo -e "error: $*" >&2; exit 1; }

yaml_quote() {
  local value="${1:-}"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  printf '"%s"' "$value"
}

date_to_epoch() {
  sa_date_to_epoch "$1"
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

compute_module_health() {
  local module_path="$1" last_synced="$2" stale_days="$3" outdated_days="$4"

  if [[ -z "$last_synced" ]] || [[ ! -e "$module_path" ]]; then
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

compute_global_health() {
  local last_synced="$1" stale_days="$2" outdated_days="$3"
  local synced_epoch now_epoch days_since

  synced_epoch=$(date_to_epoch "$last_synced")
  if [[ -z "$last_synced" ]] || [[ -z "$synced_epoch" ]]; then
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
    echo "FRESH"
  fi
}

detect_task_phase_marker() {
  local file="$1"
  local line
  line=$(grep -m1 '^>[[:space:]]*Current RIPER Phase:' "$file" 2>/dev/null || true)
  if [[ "$line" =~ ^\>[[:space:]]*Current[[:space:]]RIPER[[:space:]]Phase:[[:space:]]*\*{0,2}(RESEARCH|INNOVATE|PLAN|EXECUTE|REVIEW|DONE)\*{0,2}[[:space:]]*$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  fi
}

status_from_phase() {
  case "$1" in
    RESEARCH|INNOVATE) echo "draft" ;;
    PLAN|EXECUTE) echo "in_progress" ;;
    REVIEW) echo "review" ;;
    DONE) echo "done" ;;
    *) echo "" ;;
  esac
}

write_legacy_module_index() {
  local output_file="$1"
  local generated_at="$2"
  local fresh="$3" drifted="$4" stale="$5" outdated="$6"
  shift 6

  mkdir -p "$(dirname "$output_file")"
  {
    echo "---"
    echo "specanchor:"
    echo "  type: module-index"
    echo "  generated_at: \"${generated_at}\""
    echo "  module_count: ${#M_PATHS[@]}"
    echo "  covered_count: ${#M_PATHS[@]}"
    echo "  uncovered_count: 0"
    echo "  health_summary:"
    echo "    fresh: ${fresh}"
    echo "    drifted: ${drifted}"
    echo "    stale: ${stale}"
    echo "    outdated: ${outdated}"
    echo ""
    if [[ ${#M_PATHS[@]} -gt 0 ]]; then
      echo "modules:"
      local i
      for i in "${!M_PATHS[@]}"; do
        echo "  - path: $(yaml_quote "${M_PATHS[$i]}")"
        echo "    spec: $(yaml_quote "${M_SPECS[$i]}")"
        echo "    summary: $(yaml_quote "${M_SUMMARIES[$i]}")"
        echo "    source: ${M_SOURCES[$i]}"
        echo "    status: ${M_STATUSES[$i]}"
        echo "    version: $(yaml_quote "${M_VERSIONS[$i]}")"
        echo "    last_synced: $(yaml_quote "${M_SYNCS[$i]}")"
        echo "    owner: $(yaml_quote "${M_OWNERS[$i]}")"
        echo "    health: ${M_HEALTHS[$i]}"
        echo ""
      done
    else
      echo "modules: []"
    fi
    echo "uncovered: []"
    echo "---"
    echo ""
    echo "# Module Spec 索引"
    echo ""
    echo "<!-- 以下由 specanchor-index.sh 从 frontmatter 自动渲染，请勿手动编辑 -->"
    echo ""
    echo "**统计**: ${#M_PATHS[@]} 个模块 | ${#M_PATHS[@]} 已覆盖 | 0 未覆盖 | 健康度: 🟢 ${fresh} FRESH 🟡 ${drifted} DRIFTED 🟠 ${stale} STALE 🔴 ${outdated} OUTDATED"
    echo ""
    if [[ ${#M_PATHS[@]} -gt 0 ]]; then
      echo "| 模块路径 | 摘要 | 状态 | 健康度 | 版本 | 最后同步 |"
      echo "|----------|------|------|--------|------|---------|"
      local icon status_icon
      for i in "${!M_PATHS[@]}"; do
        icon=$(health_icon "${M_HEALTHS[$i]}")
        status_icon="✅"
        [[ "${M_STATUSES[$i]}" != "active" ]] && status_icon="⚠️"
        echo "| ${M_PATHS[$i]} | ${M_SUMMARIES[$i]} | ${status_icon} ${M_STATUSES[$i]} | ${icon} ${M_HEALTHS[$i]} | ${M_VERSIONS[$i]} | ${M_SYNCS[$i]} |"
      done
    fi
  } > "$output_file"
}

generate_spec_index() {
  local config_file="$1"
  local output_file="$2"
  local write_legacy="$3"

  local global_dir modules_dir task_dir archive_dir legacy_index
  global_dir=$(sa_parse_config_field "$config_file" "global_specs" ".specanchor/global/")
  modules_dir=$(sa_parse_config_field "$config_file" "module_specs" ".specanchor/modules/")
  task_dir=$(sa_parse_config_field "$config_file" "task_specs" ".specanchor/tasks/")
  archive_dir=$(sa_parse_config_field "$config_file" "archive" ".specanchor/archive/")
  legacy_index=$(sa_module_index_path "$config_file")
  global_dir="${global_dir%/}"
  modules_dir="${modules_dir%/}"
  task_dir="${task_dir%/}"
  archive_dir="${archive_dir%/}"

  local stale_days outdated_days
  stale_days=$(sa_parse_config_field "$config_file" "stale_days" "14")
  outdated_days=$(sa_parse_config_field "$config_file" "outdated_days" "30")

  M_PATHS=()
  M_SPECS=()
  M_SUMMARIES=()
  M_SOURCES=()
  M_STATUSES=()
  M_VERSIONS=()
  M_SYNCS=()
  M_OWNERS=()
  M_HEALTHS=()
  G_TYPES=()
  G_FILES=()
  G_VERSIONS=()
  G_SYNCS=()
  G_OWNERS=()
  G_HEALTHS=()
  T_SPECS=()
  T_NAMES=()
  T_STATUSES=()
  T_PHASES=()
  T_CREATED=()
  T_CHANGES=()
  A_SPECS=()

  local g_fresh=0 g_stale=0 g_outdated=0
  local m_fresh=0 m_drifted=0 m_stale=0 m_outdated=0

  local spec_file
  if [[ -d "$global_dir" ]]; then
    for spec_file in "$global_dir"/*.spec.md; do
      [[ -f "$spec_file" ]] || continue
      local g_type g_version g_sync g_owner g_health
      g_type=$(sa_parse_frontmatter_field "$spec_file" "type")
      [[ -z "$g_type" ]] && g_type=$(basename "$spec_file" .spec.md)
      g_version=$(sa_parse_frontmatter_field "$spec_file" "version")
      [[ -z "$g_version" ]] && g_version="0.0.0"
      g_sync=$(sa_parse_frontmatter_field "$spec_file" "last_synced")
      g_owner=$(sa_parse_frontmatter_field "$spec_file" "owner")
      [[ -z "$g_owner" ]] && g_owner=$(sa_parse_frontmatter_field "$spec_file" "author")
      g_health=$(compute_global_health "$g_sync" "$stale_days" "$outdated_days")
      case "$g_health" in
        FRESH) g_fresh=$((g_fresh + 1)) ;;
        STALE) g_stale=$((g_stale + 1)) ;;
        OUTDATED) g_outdated=$((g_outdated + 1)) ;;
      esac
      G_TYPES+=("$g_type")
      G_FILES+=("$spec_file")
      G_VERSIONS+=("$g_version")
      G_SYNCS+=("$g_sync")
      G_OWNERS+=("$g_owner")
      G_HEALTHS+=("$g_health")
    done
  fi

  if [[ -d "$modules_dir" ]]; then
    for spec_file in "$modules_dir"/*.spec.md; do
      [[ -f "$spec_file" ]] || continue
      local mp ms summary status version last_synced owner source health
      mp=$(sa_parse_frontmatter_field "$spec_file" "module_path")
      [[ -z "$mp" ]] && continue
      ms=$(basename "$spec_file")
      summary=$(sa_parse_frontmatter_field "$spec_file" "summary")
      status=$(sa_parse_frontmatter_field "$spec_file" "status")
      [[ -z "$status" ]] && status="active"
      version=$(sa_parse_frontmatter_field "$spec_file" "version")
      [[ -z "$version" ]] && version="0.0.0"
      last_synced=$(sa_parse_frontmatter_field "$spec_file" "last_synced")
      owner=$(sa_parse_frontmatter_field "$spec_file" "owner")
      source="native"
      health=$(compute_module_health "$mp" "$last_synced" "$stale_days" "$outdated_days")
      case "$health" in
        FRESH) m_fresh=$((m_fresh + 1)) ;;
        DRIFTED) m_drifted=$((m_drifted + 1)) ;;
        STALE) m_stale=$((m_stale + 1)) ;;
        OUTDATED) m_outdated=$((m_outdated + 1)) ;;
      esac
      M_PATHS+=("$mp")
      M_SPECS+=("$ms")
      M_SUMMARIES+=("$summary")
      M_SOURCES+=("$source")
      M_STATUSES+=("$status")
      M_VERSIONS+=("$version")
      M_SYNCS+=("$last_synced")
      M_OWNERS+=("$owner")
      M_HEALTHS+=("$health")
    done
  fi

  if [[ -d "$task_dir" ]]; then
    while IFS= read -r spec_file; do
      [[ -n "$spec_file" ]] || continue
      local task_name status phase created last_change protocol derived_status
      task_name=$(sa_parse_frontmatter_field "$spec_file" "task_name")
      [[ -z "$task_name" ]] && task_name=$(basename "$spec_file" .spec.md)
      protocol=$(sa_parse_frontmatter_field "$spec_file" "writing_protocol")
      status=$(sa_parse_frontmatter_field "$spec_file" "status")
      phase=$(detect_task_phase_marker "$spec_file")
      if [[ "$protocol" == "sdd-riper-one" ]] && [[ -n "$phase" ]]; then
        derived_status=$(status_from_phase "$phase")
        [[ -n "$derived_status" ]] && status="$derived_status"
      fi
      [[ -z "$status" ]] && status="draft"
      created=$(sa_parse_frontmatter_field "$spec_file" "created")
      last_change=$(sa_parse_frontmatter_field "$spec_file" "last_change")
      T_SPECS+=("$spec_file")
      T_NAMES+=("$task_name")
      T_STATUSES+=("$status")
      T_PHASES+=("$phase")
      T_CREATED+=("$created")
      T_CHANGES+=("$last_change")
    done < <(find "$task_dir" -name "*.spec.md" 2>/dev/null | sort)
  fi

  if [[ -d "$archive_dir" ]]; then
    while IFS= read -r spec_file; do
      [[ -n "$spec_file" ]] || continue
      A_SPECS+=("$spec_file")
    done < <(find "$archive_dir" -name "*.spec.md" 2>/dev/null | sort)
  fi

  local generated_at
  generated_at=$(date "+%Y-%m-%dT%H:%M:%S")

  mkdir -p "$(dirname "$output_file")"
  {
    echo "---"
    echo "specanchor:"
    echo "  type: spec-index"
    echo "  version: 3"
    echo "  generated_at: \"${generated_at}\""
    echo "  spec_counts:"
    echo "    globals: ${#G_FILES[@]}"
    echo "    modules: ${#M_PATHS[@]}"
    echo "    tasks_active: ${#T_SPECS[@]}"
    echo "    tasks_archived: ${#A_SPECS[@]}"
    echo "  health_summary:"
    echo "    globals:"
    echo "      fresh: ${g_fresh}"
    echo "      drifted: 0"
    echo "      stale: ${g_stale}"
    echo "      outdated: ${g_outdated}"
    echo "    modules:"
    echo "      fresh: ${m_fresh}"
    echo "      drifted: ${m_drifted}"
    echo "      stale: ${m_stale}"
    echo "      outdated: ${m_outdated}"
    echo "    tasks:"
    echo "      active: ${#T_SPECS[@]}"
    echo "      archived: ${#A_SPECS[@]}"
    echo "specs:"
    echo "  globals:"
    local i
    if [[ ${#G_FILES[@]} -gt 0 ]]; then
      for i in "${!G_FILES[@]}"; do
        echo "    - type: $(yaml_quote "${G_TYPES[$i]}")"
        echo "      file: $(yaml_quote "${G_FILES[$i]}")"
        echo "      version: $(yaml_quote "${G_VERSIONS[$i]}")"
        echo "      last_synced: $(yaml_quote "${G_SYNCS[$i]}")"
        echo "      owner: $(yaml_quote "${G_OWNERS[$i]}")"
        echo "      health: $(yaml_quote "${G_HEALTHS[$i]}")"
      done
    else
      echo "    []"
    fi
    echo "  modules:"
    if [[ ${#M_PATHS[@]} -gt 0 ]]; then
      for i in "${!M_PATHS[@]}"; do
        echo "    - path: $(yaml_quote "${M_PATHS[$i]}")"
        echo "      spec: $(yaml_quote "${M_SPECS[$i]}")"
        echo "      summary: $(yaml_quote "${M_SUMMARIES[$i]}")"
        echo "      source: $(yaml_quote "${M_SOURCES[$i]}")"
        echo "      status: $(yaml_quote "${M_STATUSES[$i]}")"
        echo "      version: $(yaml_quote "${M_VERSIONS[$i]}")"
        echo "      last_synced: $(yaml_quote "${M_SYNCS[$i]}")"
        echo "      owner: $(yaml_quote "${M_OWNERS[$i]}")"
        echo "      health: $(yaml_quote "${M_HEALTHS[$i]}")"
      done
    else
      echo "    []"
    fi
    echo "  tasks:"
    if [[ ${#T_SPECS[@]} -gt 0 ]]; then
      for i in "${!T_SPECS[@]}"; do
        echo "    - spec: $(yaml_quote "${T_SPECS[$i]}")"
        echo "      task_name: $(yaml_quote "${T_NAMES[$i]}")"
        echo "      status: $(yaml_quote "${T_STATUSES[$i]}")"
        echo "      sdd_phase: $(yaml_quote "${T_PHASES[$i]}")"
        echo "      created: $(yaml_quote "${T_CREATED[$i]}")"
        echo "      last_change: $(yaml_quote "${T_CHANGES[$i]}")"
      done
    else
      echo "    []"
    fi
    echo "uncovered: []"
    echo "---"
    echo ""
    echo "# Spec Index"
    echo ""
    echo "<!-- Generated by specanchor-index.sh. Do not edit by hand. -->"
    echo ""
    echo "**Stats**: ${#G_FILES[@]} globals | ${#M_PATHS[@]} modules | ${#T_SPECS[@]} active tasks | ${#A_SPECS[@]} archived tasks"
    echo ""
    echo "## Modules"
    echo ""
    if [[ ${#M_PATHS[@]} -gt 0 ]]; then
      echo "| Path | Spec | Summary | Status | Health | Version | Last Synced |"
      echo "|---|---|---|---|---|---|---|"
      local icon
      for i in "${!M_PATHS[@]}"; do
        icon=$(health_icon "${M_HEALTHS[$i]}")
        echo "| ${M_PATHS[$i]} | ${M_SPECS[$i]} | ${M_SUMMARIES[$i]} | ${M_STATUSES[$i]} | ${icon} ${M_HEALTHS[$i]} | ${M_VERSIONS[$i]} | ${M_SYNCS[$i]} |"
      done
    else
      echo "(no modules covered yet)"
    fi
  } > "$output_file"

  if [[ "$write_legacy" == "true" ]]; then
    write_legacy_module_index "$legacy_index" "$generated_at" "$m_fresh" "$m_drifted" "$m_stale" "$m_outdated"
  fi

  echo -e "${GREEN}✓${RESET} spec-index.md 已更新: ${CYAN}${output_file}${RESET}"
  echo -e "  globals=${#G_FILES[@]} modules=${#M_PATHS[@]} tasks=${#T_SPECS[@]} archived=${#A_SPECS[@]} | modules: 🟢${m_fresh} 🟡${m_drifted} 🟠${m_stale} 🔴${m_outdated}"
  if [[ "$write_legacy" == "true" ]]; then
    echo -e "${GREEN}✓${RESET} legacy module-index.md 已更新: ${CYAN}${legacy_index}${RESET}"
  fi
}

main() {
  local config_file=""
  local output_file=""
  local legacy_module_index="false"

  for arg in "$@"; do
    case "$arg" in
      --config=*) config_file="${arg#--config=}" ;;
      --output=*) output_file="${arg#--output=}" ;;
      --legacy-module-index) legacy_module_index="true" ;;
      --help|-h)
        echo "Usage: specanchor-index.sh [--config=anchor.yaml] [--output=.specanchor/spec-index.md] [--legacy-module-index]"
        echo ""
        echo "扫描 .specanchor/{global,modules,tasks,archive}/，生成 v3 spec-index.md。"
        echo "--legacy-module-index 在迁移期额外生成 module-index.md v2 子集。"
        exit 0
        ;;
      *) die "未知参数: $arg" ;;
    esac
  done

  if [[ -z "$config_file" ]]; then
    config_file=$(sa_find_config) || die "未找到配置文件（anchor.yaml 或 .specanchor/config.yaml）"
  fi
  if [[ -z "$output_file" ]]; then
    output_file=$(sa_spec_index_path "$config_file")
  fi

  generate_spec_index "$config_file" "$output_file" "$legacy_module_index"
}

main "$@"
