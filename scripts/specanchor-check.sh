#!/usr/bin/env bash
# SpecAnchor Check - Spec-Commit 对齐检测
#
# Usage:
#   specanchor-check.sh task <spec-file> [--base=<branch>]   # 基准分支（默认从 anchor.yaml 读取）
#   specanchor-check.sh module <spec-file|--all>             # 阈值从 anchor.yaml 读取
#   specanchor-check.sh global [--config=anchor.yaml]
#
# 配置文件查找顺序（root-first，支持 local overlay）：
#   1. 项目根目录 anchor.yaml
#   2. anchor.local.yaml（若存在，则叠加到 anchor.yaml）
#   3. .specanchor/config.yaml（向后兼容，仅在缺少 anchor.yaml 时使用）
#
# 阈值配置从 resolved config 的 check 节点读取：
#   stale_days (同步后超过N天且有新提交→STALE)
#   outdated_days (同步后超过N天且有新提交→OUTDATED)
#   warn_recent_commits_days, task_base_branch

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# ─── 颜色定义 ───

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

# ─── 工具函数 ───

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

check_git() {
  git rev-parse --is-inside-work-tree &>/dev/null || die "当前目录不在 git 仓库内"
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

parse_frontmatter_list() {
  local file="$1" field="$2"
  sed -n '/^---$/,/^---$/p' "$file" | sed -n "/^  ${field}:/,/^  [a-z]/p" | grep '^ *- ' | sed 's/^ *- *"\{0,1\}//;s/"\{0,1\} *$//'
}

parse_file_changes() {
  local file="$1"
  grep -E '^\s*[-*]\s*`[^`]+`' "$file" | grep -oE '`[^`]+\.[a-zA-Z]+`' | tr -d '`' | sort -u
}

parse_key_files() {
  local file="$1"
  sed -n '/## 7\. /,/## [0-9]/p' "$file" | grep -oE '`[^`]+\.[a-zA-Z]+`' | tr -d '`' | sort -u
}

path_to_module_id() {
  local path="$1"
  echo "$path" | tr '/' '-'
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

find_config() {
  local config=""
  if ! config=$(sa_find_config); then
    die "未找到配置文件（anchor.yaml 或 .specanchor/config.yaml）"
  fi

  if [[ "$config" == ".specanchor/config.yaml" ]]; then
    echo -e "${YELLOW}warning:${RESET} 使用旧版配置 .specanchor/config.yaml，建议迁移到根目录 anchor.yaml" >&2
  fi

  printf '%s\n' "$config"
}

load_check_config() {
  local config="${1:-$(find_config)}"
  CFG_STALE_DAYS=$(sa_parse_config_field "$config" "stale_days" "14")
  CFG_OUTDATED_DAYS=$(sa_parse_config_field "$config" "outdated_days" "30")
  CFG_WARN_RECENT_DAYS=$(sa_parse_config_field "$config" "warn_recent_commits_days" "14")
  CFG_TASK_BASE_BRANCH=$(sa_parse_config_field "$config" "task_base_branch" "main")
}

run_scan_if_available() {
  local scan_script=".specanchor/scripts/scan.sh"
  if [[ -f "$scan_script" ]]; then
    echo -e "${DIM}Running scan.sh for sources...${RESET}"
    bash "$scan_script" 2>&1 | sed 's/^/  /'
    echo ""
  fi
}

refresh_spec_index() {
  local config="$1"
  local mode
  mode=$(sa_parse_config_field "$config" "mode" "full")
  if [[ "$mode" != "full" ]] || [[ ! -d ".specanchor/modules" ]]; then
    return 0
  fi

  local index_script="${SCRIPT_DIR}/specanchor-index.sh"
  if [[ -f "$index_script" ]]; then
    echo ""
    bash "$index_script" --config="$config"
  fi
}

# ─── Task 级检测 ───

check_task() {
  local spec_file="$1"
  local base_branch="${2:-main}"

  [[ -f "$spec_file" ]] || die "Spec 文件不存在: $spec_file"
  check_git

  local branch
  branch=$(parse_frontmatter_field "$spec_file" "branch")
  [[ -z "$branch" ]] && branch=$(git branch --show-current)

  echo -e "${BOLD}SpecAnchor Task Check${RESET}"
  echo -e "  spec: ${CYAN}${spec_file}${RESET}"
  echo -e "  branch: ${CYAN}${branch}${RESET} → ${base_branch}"
  echo ""

  local -a planned_files=()
  while IFS= read -r f; do
    [[ -n "$f" ]] && planned_files+=("$f")
  done < <(parse_file_changes "$spec_file")

  if [[ ${#planned_files[@]} -eq 0 ]]; then
    echo -e "${YELLOW}warning:${RESET} Spec 中未找到 File Changes（§4.1），跳过 Plan Coverage 检测"
    echo ""
    return
  fi

  local -a committed_files=()
  while IFS= read -r f; do
    [[ -n "$f" ]] && committed_files+=("$f")
  done < <(git diff --name-only "${base_branch}"...HEAD 2>/dev/null || git diff --name-only "${base_branch}..HEAD" 2>/dev/null || echo "")

  if [[ ${#committed_files[@]} -eq 0 ]]; then
    echo -e "${YELLOW}warning:${RESET} 无法获取 ${base_branch}..HEAD 的 diff，可能分支不存在或无改动"
    echo ""
    return
  fi

  echo -e "Planned files:"
  local covered=0
  local missing=0
  for pf in "${planned_files[@]}"; do
    local found=0
    for cf in "${committed_files[@]}"; do
      if [[ "$cf" == *"$pf"* ]] || [[ "$pf" == *"$cf"* ]]; then
        found=1
        break
      fi
    done
    if [[ $found -eq 1 ]]; then
      echo -e "  ${GREEN}✓${RESET} ${pf}"
      covered=$((covered + 1))
    else
      echo -e "  ${RED}✗${RESET} ${pf}  ${DIM}(not in commit)${RESET}"
      missing=$((missing + 1))
    fi
  done

  echo ""
  echo -e "Unplanned changes:"
  local unplanned=0
  for cf in "${committed_files[@]}"; do
    local is_planned=0
    for pf in "${planned_files[@]}"; do
      if [[ "$cf" == *"$pf"* ]] || [[ "$pf" == *"$cf"* ]]; then
        is_planned=1
        break
      fi
    done
    if [[ $is_planned -eq 0 ]]; then
      local label="file"
      if [[ "$cf" == *.spec.md ]]; then
        label="spec"
      elif [[ "$cf" == *package.json ]] || [[ "$cf" == *config* ]] || [[ "$cf" == *.lock ]]; then
        label="config"
      elif [[ "$cf" == *.test.* ]] || [[ "$cf" == *.spec.* ]]; then
        label="test"
      fi
      echo -e "  ${CYAN}?${RESET} ${cf}  ${DIM}(${label})${RESET}"
      unplanned=$((unplanned + 1))
    fi
  done

  [[ $unplanned -eq 0 ]] && echo -e "  ${DIM}(none)${RESET}"

  local total=${#planned_files[@]}
  local pct=0
  [[ $total -gt 0 ]] && pct=$((covered * 100 / total))

  echo ""
  echo -e "Plan coverage: ${covered}/${total} (${pct}%)"

  if [[ $missing -gt 0 ]] || [[ $unplanned -gt 0 ]]; then
    local verdict=""
    [[ $missing -gt 0 ]] && verdict="${missing} planned file(s) missing"
    [[ $unplanned -gt 0 ]] && {
      [[ -n "$verdict" ]] && verdict="${verdict}, "
      verdict="${verdict}${unplanned} unplanned file(s) changed"
    }
    echo -e "${YELLOW}Verdict: ${verdict}${RESET}"
  else
    echo -e "${GREEN}Verdict: all planned files covered, no unplanned changes${RESET}"
  fi
}

# ─── Module 级检测 ───

check_single_module() {
  local spec_file="$1"

  [[ -f "$spec_file" ]] || return

  local module_path
  module_path=$(parse_frontmatter_field "$spec_file" "module_path")

  local last_synced
  last_synced=$(parse_frontmatter_field "$spec_file" "last_synced")

  local module_name
  module_name=$(parse_frontmatter_field "$spec_file" "module_name")
  [[ -z "$module_name" ]] && module_name=$(basename "${module_path:-$spec_file}" .spec.md)

  local status_icon status_label

  if [[ -z "$module_path" ]]; then
    status_icon="${YELLOW}~${RESET}"
    status_label="STALE (missing module_path)"
    printf "  %b %-18s %-25s synced %-12s %3d commits since   %s\n" \
      "$status_icon" "${module_name}" "unknown" "${last_synced:-unknown}" 0 "$status_label"
    echo -e "    ${DIM}spec: ${spec_file}${RESET}"
    return
  fi

  if [[ ! -e "$module_path" ]]; then
    status_icon="${YELLOW}~${RESET}"
    status_label="STALE (invalid module_path)"
    printf "  %b %-18s %-25s synced %-12s %3d commits since   %s\n" \
      "$status_icon" "${module_name}" "${module_path}" "${last_synced:-unknown}" 0 "$status_label"
    echo -e "    ${DIM}spec: ${spec_file}${RESET}"
    return
  fi

  if [[ -z "$last_synced" ]]; then
    status_icon="${YELLOW}~${RESET}"
    status_label="STALE (missing last_synced)"
    printf "  %b %-18s %-25s synced %-12s %3d commits since   %s\n" \
      "$status_icon" "${module_name}" "${module_path}" "unknown" 0 "$status_label"
    echo -e "    ${DIM}spec: ${spec_file}${RESET}"
    return
  fi

  local commits_since=0
  commits_since=$(git log --oneline --since="${last_synced} 00:00:00" -- "$module_path" 2>/dev/null | wc -l | tr -d ' ')

  if [[ $commits_since -eq 0 ]]; then
    status_icon="${GREEN}✓${RESET}"
    status_label="FRESH"
  else
    local synced_epoch
    synced_epoch=$(date_to_epoch "$last_synced")
    if [[ -z "$synced_epoch" ]]; then
      status_icon="${YELLOW}~${RESET}"
      status_label="STALE (invalid last_synced)"
      printf "  %b %-18s %-25s synced %-12s %3d commits since   %s\n" \
        "$status_icon" "${module_name}" "${module_path}" "${last_synced}" "$commits_since" "$status_label"
      echo -e "    ${DIM}spec: ${spec_file}${RESET}"
      return
    fi
    local now_epoch
    now_epoch=$(date "+%s")
    local days_since=$(( (now_epoch - synced_epoch) / 86400 ))
    if [[ $days_since -gt $CFG_OUTDATED_DAYS ]]; then
      status_icon="${RED}!${RESET}"
      status_label="OUTDATED (${days_since}d)"
    elif [[ $days_since -gt $CFG_STALE_DAYS ]]; then
      status_icon="${YELLOW}~${RESET}"
      status_label="STALE (${days_since}d)"
    else
      status_icon="${YELLOW}~${RESET}"
      status_label="DRIFTED"
    fi
  fi

  printf "  %b %-18s %-25s synced %-12s %3d commits since   %s\n" \
    "$status_icon" "${module_name}" "${module_path}" "${last_synced:-unknown}" "$commits_since" "$status_label"
  echo -e "    ${DIM}spec: ${spec_file}${RESET}"
}

check_module() {
  local target="$1"

  check_git
  load_check_config

  echo -e "${BOLD}SpecAnchor Module Freshness${RESET}"
  echo -e "  ${DIM}config: stale_days=${CFG_STALE_DAYS}, outdated_days=${CFG_OUTDATED_DAYS}${RESET}"

  if [[ "$target" == "--all" ]]; then
    local modules_dir=".specanchor/modules"
    [[ -d "$modules_dir" ]] || die "Module Spec 目录不存在: $modules_dir"

    echo -e "  modules dir: ${CYAN}${modules_dir}/${RESET}"
    echo ""

    local covered=0 fresh=0

    for spec_file in "$modules_dir"/*.spec.md; do
      [[ -f "$spec_file" ]] || continue
      covered=$((covered + 1))
      check_single_module "$spec_file"
      local ls
      ls=$(parse_frontmatter_field "$spec_file" "last_synced")
      local mp
      mp=$(parse_frontmatter_field "$spec_file" "module_path")
      if [[ -n "$ls" ]] && [[ -n "$mp" ]] && [[ -e "$mp" ]]; then
        local c
        c=$(git log --oneline --since="${ls} 00:00:00" -- "$mp" 2>/dev/null | wc -l | tr -d ' ')
        if [[ $c -eq 0 ]]; then
          fresh=$((fresh + 1))
        fi
      fi
    done

    [[ $covered -eq 0 ]] && echo -e "  ${DIM}(no Module Spec files found)${RESET}"

    echo ""
    local fresh_pct=0
    [[ $covered -gt 0 ]] && fresh_pct=$((fresh * 100 / covered))
    echo -e "Covered: ${covered} module(s)   Fresh: ${fresh}/${covered} (${fresh_pct}%)"
  else
    [[ -f "$target" ]] || die "Spec 文件不存在: $target"
    local module_path
    module_path=$(parse_frontmatter_field "$target" "module_path")
    echo -e "  scope: ${CYAN}${module_path:-unknown}${RESET}"
    echo ""
    check_single_module "$target"
  fi
}

# ─── Global 级检测 ───

check_global() {
  local config="${1:-$(find_config)}"

  [[ -f "$config" ]] || die "配置文件不存在: $config"
  load_check_config "$config"

  echo -e "${BOLD}SpecAnchor Coverage Report${RESET}"
  echo -e "  ${DIM}config: stale_days=${CFG_STALE_DAYS}, outdated_days=${CFG_OUTDATED_DAYS}, warn_recent_days=${CFG_WARN_RECENT_DAYS}${RESET}"
  echo ""

  local global_dir=".specanchor/global"
  local global_count=0
  if [[ -d "$global_dir" ]]; then
    global_count=$(find "$global_dir" -name "*.spec.md" -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
  fi
  echo -e "Global Specs:  ${global_count} file(s) in ${global_dir}/"

  local task_dir=".specanchor/tasks"
  local active_tasks=0 archived_tasks=0
  if [[ -d "$task_dir" ]]; then
    active_tasks=$(find "$task_dir" -name "*.spec.md" 2>/dev/null | wc -l | tr -d ' ')
  fi
  local archive_dir=".specanchor/archive"
  if [[ -d "$archive_dir" ]]; then
    archived_tasks=$(find "$archive_dir" -name "*.spec.md" 2>/dev/null | wc -l | tr -d ' ')
  fi

  local modules_dir=".specanchor/modules"

  local covered=0
  if [[ -d "$modules_dir" ]]; then
    covered=$(find "$modules_dir" -name "*.spec.md" -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
  fi

  echo -e "Module Specs:  ${covered} module(s) covered"
  echo -e "Task Specs:    ${active_tasks} active, ${archived_tasks} archived"

  echo ""
  echo -e "Warnings:"
  local has_warnings=0

  if [[ -d "$modules_dir" ]]; then
    for spec_file in "$modules_dir"/*.spec.md; do
      [[ -f "$spec_file" ]] || continue
      local mp
      mp=$(parse_frontmatter_field "$spec_file" "module_path")
      local mod_name
      mod_name=$(parse_frontmatter_field "$spec_file" "module_name")
      [[ -z "$mod_name" ]] && mod_name=$(basename "${mp:-$spec_file}" .spec.md)

      local ls
      ls=$(parse_frontmatter_field "$spec_file" "last_synced")
      if [[ -z "$mp" ]]; then
        echo -e "  ${YELLOW}~${RESET} ${mod_name} (unknown) STALE (missing module_path)"
        has_warnings=1
        continue
      fi
      if [[ ! -e "$mp" ]]; then
        echo -e "  ${YELLOW}~${RESET} ${mod_name} (${mp}) STALE (invalid module_path)"
        has_warnings=1
        continue
      fi
      if [[ -z "$ls" ]]; then
        echo -e "  ${YELLOW}~${RESET} ${mod_name} (${mp}) STALE (missing last_synced)"
        has_warnings=1
        continue
      fi

      local synced_epoch now_epoch days_since commits_since
      synced_epoch=$(date_to_epoch "$ls")
      if [[ -z "$synced_epoch" ]]; then
        echo -e "  ${YELLOW}~${RESET} ${mod_name} (${mp}) STALE (invalid last_synced)"
        has_warnings=1
        continue
      fi
      now_epoch=$(date "+%s")
      days_since=$(( (now_epoch - synced_epoch) / 86400 ))
      commits_since=$(git log --oneline --since="${ls} 00:00:00" -- "$mp" 2>/dev/null | wc -l | tr -d ' ')
      if [[ $days_since -gt $CFG_OUTDATED_DAYS ]] && [[ $commits_since -gt 0 ]]; then
        echo -e "  ${RED}!${RESET} ${mod_name} (${mp}) OUTDATED (${days_since} days, ${commits_since} commits)"
        has_warnings=1
      elif [[ $days_since -gt $CFG_STALE_DAYS ]] && [[ $commits_since -gt 0 ]]; then
        echo -e "  ${YELLOW}~${RESET} ${mod_name} (${mp}) STALE (${days_since} days, ${commits_since} commits)"
        has_warnings=1
      fi
    done
  fi

  if [[ $has_warnings -eq 0 ]]; then
    echo -e "  ${GREEN}(none)${RESET}"
  fi
}

# ─── Coverage 检测 ───

check_coverage() {
  local modules_dir=".specanchor/modules"
  [[ -d "$modules_dir" ]] || die "Module Spec 目录不存在: $modules_dir"

  local -a module_paths=()
  local -a module_specs=()
  local -a module_names=()

  for spec_file in "$modules_dir"/*.spec.md; do
    [[ -f "$spec_file" ]] || continue
    local mp
    mp=$(parse_frontmatter_field "$spec_file" "module_path")
    [[ -z "$mp" ]] && continue
    local mn
    mn=$(parse_frontmatter_field "$spec_file" "module_name")
    [[ -z "$mn" ]] && mn=$(basename "$mp")
    module_paths+=("$mp")
    module_specs+=("$spec_file")
    module_names+=("$mn")
  done

  echo -e "${BOLD}SpecAnchor Coverage Check${RESET}"
  echo -e "  ${DIM}module specs loaded: ${#module_paths[@]}${RESET}"
  echo ""

  local covered=0 uncovered=0
  local -a uncovered_modules=()

  for filepath in "$@"; do
    local best_match="" best_spec="" best_name="" best_len=0

    for i in "${!module_paths[@]}"; do
      local mp="${module_paths[$i]}"
      if [[ "$filepath" == "$mp"* ]] || [[ "$filepath" == "$mp/"* ]]; then
        local mp_len=${#mp}
        if [[ $mp_len -gt $best_len ]]; then
          best_match="$mp"
          best_spec="${module_specs[$i]}"
          best_name="${module_names[$i]}"
          best_len=$mp_len
        fi
      fi
    done

    if [[ -n "$best_match" ]]; then
      echo -e "  ${GREEN}✓${RESET} ${filepath}"
      echo -e "    ${DIM}covered by: ${best_name} (${best_spec})${RESET}"
      covered=$((covered + 1))
    else
      echo -e "  ${RED}✗${RESET} ${filepath}  ${DIM}(no module spec)${RESET}"
      uncovered=$((uncovered + 1))
      local dir_path
      dir_path=$(dirname "$filepath")
      local already_listed=0
      for um in "${uncovered_modules[@]+"${uncovered_modules[@]}"}"; do
        [[ "$um" == "$dir_path" ]] && already_listed=1 && break
      done
      [[ $already_listed -eq 0 ]] && uncovered_modules+=("$dir_path")
    fi
  done

  echo ""
  local total=$((covered + uncovered))
  local pct=0
  [[ $total -gt 0 ]] && pct=$((covered * 100 / total))
  echo -e "Coverage: ${covered}/${total} files (${pct}%)"

  if [[ ${#uncovered_modules[@]} -gt 0 ]]; then
    echo ""
    echo -e "Uncovered modules (need specanchor_infer):"
    for um in "${uncovered_modules[@]}"; do
      echo -e "  ${YELLOW}→${RESET} ${um}"
    done
  fi
}

# ─── CLI 入口 ───

usage() {
  echo "SpecAnchor Check - Spec-Commit 对齐检测"
  echo ""
  echo "Usage:"
  echo "  specanchor-check.sh task <spec-file> [--base=<branch>]"
  echo "  specanchor-check.sh module <spec-file|--all>"
  echo "  specanchor-check.sh global [--config=anchor.yaml]"
  echo "  specanchor-check.sh coverage <file1> [file2] ...         # 检查文件是否被 Module Spec 覆盖"
  echo ""
  echo "Module Spec 存放位置: .specanchor/modules/<module-id>.spec.md"
  echo "Module ID 生成规则: 路径中的 / 替换为 - (如 src/modules/auth → src-modules-auth)"
  echo ""
  echo "阈值配置: anchor.yaml (+ anchor.local.yaml if present) → check 节点（legacy fallback: .specanchor/config.yaml）"
  echo "  stale_days (${CFG_STALE_DAYS}), outdated_days (${CFG_OUTDATED_DAYS}),"
  echo "  warn_recent_commits_days (${CFG_WARN_RECENT_DAYS}), task_base_branch (${CFG_TASK_BASE_BRANCH})"
  echo ""
  echo "Examples:"
  echo "  specanchor-check.sh task .specanchor/tasks/auth/2026-03-13_sms-login.spec.md"
  echo "  specanchor-check.sh task .specanchor/tasks/auth/spec.md --base=develop"
  echo "  specanchor-check.sh module --all"
  echo "  specanchor-check.sh module .specanchor/modules/src-modules-auth.spec.md"
  echo "  specanchor-check.sh global"
  echo "  specanchor-check.sh coverage src/app/bloom/index.tsx src/utils/helper.ts"
  exit 1
}

main() {
  [[ $# -lt 1 ]] && usage

  local level="$1"
  shift

  case "$level" in
    task)
      [[ $# -lt 1 ]] && die "task 级需要指定 spec 文件路径"
      local spec_file="$1"
      shift
      load_check_config
      local base="$CFG_TASK_BASE_BRANCH"
      for arg in "$@"; do
        case "$arg" in
          --base=*) base="${arg#--base=}" ;;
        esac
      done
      check_task "$spec_file" "$base"
      ;;
    module)
      [[ $# -lt 1 ]] && die "module 级需要指定 spec 文件路径或 --all"
      local target="$1"
      shift
      check_module "$target"
      ;;
    global)
      local config=""
      for arg in "$@"; do
        case "$arg" in
          --config=*) config="${arg#--config=}" ;;
        esac
      done
      [[ -z "$config" ]] && config=$(find_config)
      run_scan_if_available
      check_global "$config"
      refresh_spec_index "$config"
      ;;
    coverage)
      [[ $# -lt 1 ]] && die "coverage 级需要指定至少一个文件路径"
      check_coverage "$@"
      ;;
    *)
      die "未知检测级别: $level (可选: task | module | global | coverage)"
      ;;
  esac
}

main "$@"
