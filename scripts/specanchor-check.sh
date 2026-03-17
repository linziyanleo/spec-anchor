#!/usr/bin/env bash
# SpecAnchor Check - Spec-Commit 对齐检测
#
# Usage:
#   specanchor-check.sh task <spec-file> [--base=main] # 指定基准分支
#   specanchor-check.sh module <spec-file|--all> [--stale-days=30] # 指定过期天数
#   specanchor-check.sh global [--config=.specanchor/config.yaml] # 指定配置文件

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
  local stale_days="$2"

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
    commits_since=$(git log --oneline --since="$last_synced" -- "$module_path" 2>/dev/null | wc -l | tr -d ' ')
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
    if [[ $days_since -gt $stale_days ]]; then
      status_icon="${RED}!${RESET}"
      status_label="OUTDATED"
    else
      status_icon="${YELLOW}~${RESET}"
      status_label="STALE"
    fi
  else
    status_icon="${YELLOW}~${RESET}"
    status_label="STALE"
  fi

  printf "  %b %-18s %-25s synced %-12s %3d commits since   %s\n" \
    "$status_icon" "${module_name}" "${module_path}" "${last_synced:-unknown}" "$commits_since" "$status_label"
}

check_module() {
  local target="$1"
  local stale_days="${2:-30}"

  check_git

  echo -e "${BOLD}SpecAnchor Module Freshness${RESET}"

  if [[ "$target" == "--all" ]]; then
    local modules_dir=".specanchor/modules"
    [[ -d "$modules_dir" ]] || die "Module Spec 目录不存在: $modules_dir"

    local config=".specanchor/config.yaml"

    local -a scan_paths=()
    if [[ -f "$config" ]]; then
      while IFS= read -r p; do
        [[ -n "$p" ]] && scan_paths+=("$p")
      done < <(sed -n '/scan_paths:/,/^  [a-z]/p' "$config" | grep '^ *- ' | sed 's/^ *- *"\{0,1\}//;s/"\{0,1\} *$//')
    fi

    echo -e "  modules dir: ${CYAN}${modules_dir}/${RESET}"
    echo ""

    local total=0 covered=0 fresh=0

    for sp in "${scan_paths[@]}"; do
      local base_dir="${sp%%/\*\*}"
      [[ -d "$base_dir" ]] || continue
      for dir in "$base_dir"/*/; do
        [[ -d "$dir" ]] || continue
        ((total++))

        local dir_clean="${dir%/}"
        local module_id
        module_id=$(path_to_module_id "$dir_clean")
        local spec_file="${modules_dir}/${module_id}.spec.md"

        if [[ -f "$spec_file" ]]; then
          ((covered++))
          check_single_module "$spec_file" "$stale_days"
          local ls
          ls=$(parse_frontmatter_field "$spec_file" "last_synced")
          if [[ -n "$ls" ]]; then
            local c
            c=$(git log --oneline --since="$ls" -- "$dir" 2>/dev/null | wc -l | tr -d ' ')
            [[ $c -eq 0 ]] && ((fresh++))
          fi
        else
          local recent
          recent=$(git log --oneline -n 20 --since="30 days ago" -- "$dir" 2>/dev/null | wc -l | tr -d ' ')
          printf "  ${RED}✗${RESET} %-18s %-25s no Module Spec          %3d recent commits  NO SPEC\n" \
            "$(basename "$dir_clean")/" "$dir_clean" "$recent"
        fi
      done
    done

    echo ""
    echo -e "Coverage: ${covered}/${total} ($(( total > 0 ? covered * 100 / total : 0 ))%)   Fresh: ${fresh}/${covered} ($(( covered > 0 ? fresh * 100 / covered : 0 ))%)"
  else
    [[ -f "$target" ]] || die "Spec 文件不存在: $target"
    local module_path
    module_path=$(parse_frontmatter_field "$target" "module_path")
    echo -e "  scope: ${CYAN}${module_path:-unknown}${RESET}"
    echo ""
    check_single_module "$target" "$stale_days"
  fi
}

# ─── Global 级检测 ───

check_global() {
  local config="${1:-.specanchor/config.yaml}"

  [[ -f "$config" ]] || die "配置文件不存在: $config"

  echo -e "${BOLD}SpecAnchor Coverage Report${RESET}"
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

  local -a scan_paths=()
  while IFS= read -r p; do
    [[ -n "$p" ]] && scan_paths+=("$p")
  done < <(sed -n '/scan_paths:/,/^  [a-z]/p' "$config" | grep '^ *- ' | sed 's/^ *- *"\{0,1\}//;s/"\{0,1\} *$//')

  local total=0 covered=0
  for sp in "${scan_paths[@]}"; do
    local base_dir="${sp%%/\*\*}"
    [[ -d "$base_dir" ]] || continue
    for dir in "$base_dir"/*/; do
      [[ -d "$dir" ]] || continue
      ((total++))

      local dir_clean="${dir%/}"
      local module_id
      module_id=$(path_to_module_id "$dir_clean")
      [[ -f "${modules_dir}/${module_id}.spec.md" ]] && ((covered++))
    done
  done

  echo -e "Module Specs:  ${covered}/${total} modules covered ($(( total > 0 ? covered * 100 / total : 0 ))%)"
  echo -e "Task Specs:    ${active_tasks} active, ${archived_tasks} archived"

  echo ""
  echo -e "Warnings:"
  local has_warnings=0

  for sp in "${scan_paths[@]}"; do
    local base_dir="${sp%%/\*\*}"
    [[ -d "$base_dir" ]] || continue
    for dir in "$base_dir"/*/; do
      [[ -d "$dir" ]] || continue
      local dir_clean="${dir%/}"
      local mod_name
      mod_name=$(basename "$dir_clean")
      local module_id
      module_id=$(path_to_module_id "$dir_clean")
      local spec_file="${modules_dir}/${module_id}.spec.md"

      if [[ ! -f "$spec_file" ]]; then
        local recent
        recent=$(git log --oneline --since="30 days ago" -- "$dir" 2>/dev/null | wc -l | tr -d ' ')
        if [[ $recent -gt 0 ]]; then
          echo -e "  ${RED}✗${RESET} ${mod_name}/  no spec (${recent} commits in last 30 days)"
          has_warnings=1
        fi
      else
        local ls
        ls=$(parse_frontmatter_field "$spec_file" "last_synced")
        if [[ -n "$ls" ]]; then
          local synced_epoch now_epoch days_since commits_since
          synced_epoch=$(date -j -f "%Y-%m-%d" "$ls" "+%s" 2>/dev/null || date -d "$ls" "+%s" 2>/dev/null || echo 0)
          now_epoch=$(date "+%s")
          days_since=$(( (now_epoch - synced_epoch) / 86400 ))
          commits_since=$(git log --oneline --since="$ls" -- "$dir" 2>/dev/null | wc -l | tr -d ' ')
          if [[ $days_since -gt 30 ]] && [[ $commits_since -gt 0 ]]; then
            echo -e "  ${YELLOW}!${RESET} ${mod_name}/ spec outdated (${days_since} days, ${commits_since} commits)"
            has_warnings=1
          fi
        fi
      fi
    done
  done

  [[ $has_warnings -eq 0 ]] && echo -e "  ${GREEN}(none)${RESET}"
}

# ─── CLI 入口 ───

usage() {
  echo "SpecAnchor Check - Spec-Commit 对齐检测"
  echo ""
  echo "Usage:"
  echo "  specanchor-check.sh task <spec-file> [--base=main]"
  echo "  specanchor-check.sh module <spec-file|--all> [--stale-days=30]"
  echo "  specanchor-check.sh global [--config=.specanchor/config.yaml]"
  echo ""
  echo "Module Spec 存放位置: .specanchor/modules/<module-id>.spec.md"
  echo "Module ID 生成规则: 路径中的 / 替换为 - (如 src/modules/auth → src-modules-auth)"
  echo ""
  echo "Examples:"
  echo "  specanchor-check.sh task .specanchor/tasks/auth/2026-03-13_sms-login.spec.md"
  echo "  specanchor-check.sh module --all"
  echo "  specanchor-check.sh module .specanchor/modules/src-modules-auth.spec.md"
  echo "  specanchor-check.sh global"
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
      local base="main"
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
      local stale_days=30
      for arg in "$@"; do
        case "$arg" in
          --stale-days=*) stale_days="${arg#--stale-days=}" ;;
        esac
      done
      check_module "$target" "$stale_days"
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
    *)
      die "未知检测级别: $level (可选: task | module | global)"
      ;;
  esac
}

main "$@"
