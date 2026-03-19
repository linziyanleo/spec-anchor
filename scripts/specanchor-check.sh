#!/usr/bin/env bash
# SpecAnchor Check - Spec-Commit 对齐检测
#
# Usage:
#   specanchor-check.sh task <spec-file> [--base=<branch>]   # 基准分支（默认从 config.yaml 读取）
#   specanchor-check.sh module <spec-file|--all>             # 阈值从 config.yaml 读取
#   specanchor-check.sh global [--config=.specanchor/config.yaml]
#
# 阈值配置在 .specanchor/config.yaml 的 check 节点下：
#   stale_days (同步后超过N天且有新提交→STALE)
#   outdated_days (同步后超过N天且有新提交→OUTDATED)
#   warn_recent_commits_days, task_base_branch

set -euo pipefail

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

check_git() {
  git rev-parse --is-inside-work-tree &>/dev/null || die "当前目录不在 git 仓库内"
}

parse_frontmatter_field() {
  local file="$1" field="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep "^  ${field}:" | head -1 | sed "s/^  ${field}: *\"\{0,1\}//;s/\"\{0,1\} *$//"
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
    local val
    val=$(grep "^    ${field}:" "$file" 2>/dev/null | head -1 | sed "s/^    ${field}: *\"\{0,1\}//;s/\"\{0,1\} *$//" | sed 's/ *#.*//')
    if [[ -z "$val" ]]; then
      val=$(grep "^  ${field}:" "$file" 2>/dev/null | head -1 | sed "s/^  ${field}: *\"\{0,1\}//;s/\"\{0,1\} *$//" | sed 's/ *#.*//')
    fi
    [[ -n "$val" ]] && echo "$val" || echo "$default"
  else
    echo "$default"
  fi
}

load_check_config() {
  local config="${1:-.specanchor/config.yaml}"
  CFG_STALE_DAYS=$(parse_yaml_field "$config" "stale_days" "14")
  CFG_OUTDATED_DAYS=$(parse_yaml_field "$config" "outdated_days" "30")
  CFG_WARN_RECENT_DAYS=$(parse_yaml_field "$config" "warn_recent_commits_days" "14")
  CFG_TASK_BASE_BRANCH=$(parse_yaml_field "$config" "task_base_branch" "main")
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
      ((covered++))
    else
      echo -e "  ${RED}✗${RESET} ${pf}  ${DIM}(not in commit)${RESET}"
      ((missing++))
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
      ((unplanned++))
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
  [[ -z "$module_path" ]] && return

  local last_synced
  last_synced=$(parse_frontmatter_field "$spec_file" "last_synced")

  local module_name
  module_name=$(parse_frontmatter_field "$spec_file" "module_name")
  [[ -z "$module_name" ]] && module_name=$(basename "$module_path")

  local commits_since=0
  if [[ -n "$last_synced" ]] && [[ -d "$module_path" ]]; then
    commits_since=$(git log --oneline --since="${last_synced} 00:00:00" -- "$module_path" 2>/dev/null | wc -l | tr -d ' ')
  fi

  local status_icon status_label
  if [[ $commits_since -eq 0 ]]; then
    status_icon="${GREEN}✓${RESET}"
    status_label="FRESH"
  elif [[ -n "$last_synced" ]]; then
    local synced_epoch
    synced_epoch=$(date -j -f "%Y-%m-%d" "$last_synced" "+%s" 2>/dev/null || date -d "$last_synced" "+%s" 2>/dev/null || echo 0)
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
  else
    status_icon="${YELLOW}~${RESET}"
    status_label="STALE"
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
      ((covered++))
      check_single_module "$spec_file"
      local ls
      ls=$(parse_frontmatter_field "$spec_file" "last_synced")
      local mp
      mp=$(parse_frontmatter_field "$spec_file" "module_path")
      if [[ -n "$ls" ]] && [[ -n "$mp" ]] && [[ -d "$mp" ]]; then
        local c
        c=$(git log --oneline --since="${ls} 00:00:00" -- "$mp" 2>/dev/null | wc -l | tr -d ' ')
        [[ $c -eq 0 ]] && ((fresh++))
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
  local config="${1:-.specanchor/config.yaml}"

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
      [[ -z "$mp" ]] && continue
      local mod_name
      mod_name=$(parse_frontmatter_field "$spec_file" "module_name")
      [[ -z "$mod_name" ]] && mod_name=$(basename "$mp")

      local ls
      ls=$(parse_frontmatter_field "$spec_file" "last_synced")
      if [[ -n "$ls" ]] && [[ -d "$mp" ]]; then
        local synced_epoch now_epoch days_since commits_since
        synced_epoch=$(date -j -f "%Y-%m-%d" "$ls" "+%s" 2>/dev/null || date -d "$ls" "+%s" 2>/dev/null || echo 0)
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
      fi
    done
  fi

  [[ $has_warnings -eq 0 ]] && echo -e "  ${GREEN}(none)${RESET}"
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
      ((covered++))
    else
      echo -e "  ${RED}✗${RESET} ${filepath}  ${DIM}(no module spec)${RESET}"
      ((uncovered++))
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
  echo "  specanchor-check.sh global [--config=.specanchor/config.yaml]"
  echo "  specanchor-check.sh coverage <file1> [file2] ...         # 检查文件是否被 Module Spec 覆盖"
  echo ""
  echo "Module Spec 存放位置: .specanchor/modules/<module-id>.spec.md"
  echo "Module ID 生成规则: 路径中的 / 替换为 - (如 src/modules/auth → src-modules-auth)"
  echo ""
  echo "阈值配置: .specanchor/config.yaml → check 节点"
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
      local config=".specanchor/config.yaml"
      for arg in "$@"; do
        case "$arg" in
          --config=*) config="${arg#--config=}" ;;
        esac
      done
      check_global "$config"
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
