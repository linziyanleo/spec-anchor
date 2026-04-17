#!/usr/bin/env bash
# SpecAnchor Frontmatter Inject — Layer 1
#
# 自动推断并注入 SpecAnchor YAML frontmatter 到 spec 文件。
# Agent 只需提供核心参数，其余字段由脚本自动推断。
#
# Usage:
#   frontmatter-inject.sh <target_file> [options]       # 单文件注入
#   frontmatter-inject.sh --dir <directory> [options]    # 批量注入
#
# Options:
#   --task-name <name>        覆盖自动推断的 task_name
#   --status <status>         覆盖默认 status (default: draft)
#   --last-change <msg>       设置 last_change 字段
#   --level <level>           覆盖自动推断的 level (task|module|global)
#   --writing-protocol <p>    覆盖自动推断的 writing_protocol
#   --no-config               不读取 anchor.yaml，使用内置默认值
#   --dry-run                 只输出将要注入的 frontmatter，不修改文件
#   --force                   已有 specanchor 段时强制覆盖
#   --file-pattern <glob>     批量模式的文件匹配 (default: *.md)

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

# ─── 计数器 ───

COUNT_INJECTED=0
COUNT_SKIPPED=0
COUNT_FAILED=0
INJECTED_FILES=()

# ─── 工具函数 ───

die() { echo -e "${RED}error:${RESET} $*" >&2; exit 1; }

warn() { echo -e "${YELLOW}warning:${RESET} $*" >&2; }

info() { echo -e "${CYAN}ℹ️${RESET} $*"; }

success() { echo -e "${GREEN}✅${RESET} $*"; }

skip() { echo -e "${DIM}⏭️${RESET} $*"; }

# ─── 配置查找 ───

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

find_config() {
  if [[ -f "anchor.yaml" ]]; then
    echo "anchor.yaml"
  elif [[ -f ".specanchor/config.yaml" ]]; then
    warn "使用旧版配置 .specanchor/config.yaml，建议迁移到根目录 anchor.yaml"
    echo ".specanchor/config.yaml"
  else
    echo ""
  fi
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

# ─── 自动推断函数 ───

detect_level() {
  local file="$1"
  local dir
  dir=$(dirname "$file")

  if [[ "$dir" == *"/tasks/"* ]] || [[ "$dir" == *"/tasks" ]]; then
    echo "task"
  elif [[ "$dir" == *"/modules/"* ]] || [[ "$dir" == *"/modules" ]]; then
    echo "module"
  elif [[ "$dir" == *"/global/"* ]] || [[ "$dir" == *"/global" ]]; then
    echo "global"
  else
    echo "task"
  fi
}

detect_author() {
  local author
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    author=$(git config user.name 2>/dev/null || echo "")
    if [[ -n "$author" ]]; then
      echo "@${author}"
      return
    fi
  fi
  echo "@unknown"
}

detect_created() {
  local file="$1"
  if git rev-parse --is-inside-work-tree &>/dev/null && git log --follow --format='%ai' -- "$file" 2>/dev/null | tail -1 | grep -q '^[0-9]'; then
    git log --follow --diff-filter=A --format='%ai' -- "$file" 2>/dev/null | tail -1 | cut -d' ' -f1
  else
    local filename
    filename=$(basename "$file")
    local date_prefix
    date_prefix=$(echo "$filename" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || echo "")
    if [[ -n "$date_prefix" ]]; then
      echo "$date_prefix"
    else
      date '+%Y-%m-%d'
    fi
  fi
}

detect_branch() {
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    git branch --show-current 2>/dev/null || echo "main"
  else
    echo "main"
  fi
}

detect_protocol() {
  local config="$1"
  if [[ -n "$config" ]] && [[ -f "$config" ]]; then
    local schema
    schema=$(parse_yaml_field "$config" "schema" "")
    if [[ -n "$schema" ]]; then
      echo "$schema"
      return
    fi
  fi
  echo "sdd-riper-one"
}

detect_task_name() {
  local file="$1"

  local h1
  h1=$(grep -m1 '^# ' "$file" 2>/dev/null | sed 's/^# *//' || echo "")

  if [[ -n "$h1" ]]; then
    # SDD-RIPER-ONE 格式
    h1=$(echo "$h1" | sed 's/^SDD Spec: *//' | sed 's/^Research: *//' | sed 's/^Change: *//' | sed 's/^Task: *//')
    # Superpowers 格式
    h1=$(echo "$h1" | sed 's/ Implementation Plan$//' | sed 's/ Design$//' | sed 's/ Design Spec$//')
    echo "$h1"
    return
  fi

  local filename
  filename=$(basename "$file" .md)
  filename=$(echo "$filename" | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_[0-9]\{2\}-[0-9]\{2\}_//')
  filename=$(echo "$filename" | tr '-' ' ' | tr '_' ' ')
  echo "$filename"
}

detect_sdd_phase() {
  local file="$1"
  local content
  content=$(cat "$file" 2>/dev/null || echo "")

  # SDD-RIPER-ONE 格式（优先检测）
  if echo "$content" | grep -q '^## 7\. Plan-Execution Diff'; then
    echo "DONE"
  elif echo "$content" | grep -q '^## 6\. Review Verdict'; then
    echo "REVIEW"
  elif echo "$content" | grep -q '^## 5\. Execute Log'; then
    echo "EXECUTE"
  elif echo "$content" | grep -q '^## 4\. Plan'; then
    echo "PLAN"
  elif echo "$content" | grep -q '^## 3\. Innovate'; then
    echo "INNOVATE"
  elif echo "$content" | grep -q '^## 2\. Research'; then
    echo "RESEARCH"
  # Superpowers plan 格式 fallback（### Task N: + checkbox 风格）
  elif echo "$content" | grep -qE '^### Task [0-9]+:'; then
    local total_checks done_checks
    total_checks=$(echo "$content" | grep -cE '^\s*- \[(x| )\]' || echo "0")
    done_checks=$(echo "$content" | grep -cE '^\s*- \[x\]' || echo "0")
    if [[ "$total_checks" -gt 0 ]] && [[ "$total_checks" -eq "$done_checks" ]]; then
      echo "DONE"
    elif [[ "$done_checks" -gt 0 ]]; then
      echo "EXECUTE"
    else
      echo "PLAN"
    fi
  # Superpowers design spec 格式 fallback（**Goal:** + **Architecture:** 风格）
  elif echo "$content" | grep -q '^\*\*Goal:\*\*'; then
    echo "RESEARCH"
  else
    echo "RESEARCH"
  fi
}

detect_related_global() {
  local global_dir=".specanchor/global"
  local result=""
  if [[ -d "$global_dir" ]]; then
    while IFS= read -r spec; do
      [[ -n "$spec" ]] && result="${result}    - \"${spec}\"\n"
    done < <(find "$global_dir" -name "*.spec.md" -maxdepth 1 2>/dev/null | sort)
  fi
  echo -e "$result"
}

detect_related_modules() {
  local file="$1"
  local index_file=".specanchor/module-index.md"
  local result=""

  if [[ ! -f "$index_file" ]]; then
    echo ""
    return
  fi

  local content
  content=$(cat "$file" 2>/dev/null || echo "")

  local first_line
  first_line=$(head -1 "$index_file")

  if [[ "$first_line" == "---" ]]; then
    local current_path="" current_spec=""
    while IFS= read -r line; do
      local trimmed
      trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')
      if [[ "$trimmed" == path:* ]]; then
        current_path=$(echo "$trimmed" | sed 's/^path: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/')
      elif [[ "$trimmed" == spec:* ]]; then
        current_spec=$(echo "$trimmed" | sed 's/^spec: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/')
        if [[ -n "$current_path" ]] && [[ -n "$current_spec" ]]; then
          if echo "$content" | grep -q "$current_path" 2>/dev/null; then
            result="${result}    - \"${current_spec}\"\n"
          fi
        fi
        current_path=""
        current_spec=""
      fi
    done < "$index_file"
  else
    while IFS='|' read -r _ module_path spec_file _ _; do
      module_path=$(echo "$module_path" | xargs 2>/dev/null || echo "")
      spec_file=$(echo "$spec_file" | xargs 2>/dev/null || echo "")
      [[ -z "$module_path" ]] && continue
      [[ "$module_path" == "模块路径" ]] && continue
      [[ "$module_path" == "--------" ]] && continue

      if echo "$content" | grep -q "$module_path" 2>/dev/null; then
        result="${result}    - \"${spec_file}\"\n"
      fi
    done < "$index_file"
  fi

  echo -e "$result"
}

detect_status() {
  local file="$1"

  local total_checks
  total_checks=$(grep -cE '^\s*- \[(x| )\]' "$file" 2>/dev/null | tr -d '[:space:]' || echo "0")
  local done_checks
  done_checks=$(grep -cE '^\s*- \[x\]' "$file" 2>/dev/null | tr -d '[:space:]' || echo "0")

  if [[ "$total_checks" -gt 0 ]] && [[ "$total_checks" -eq "$done_checks" ]]; then
    echo "done"
  elif [[ "$done_checks" -gt 0 ]]; then
    echo "in_progress"
  else
    echo "draft"
  fi
}

# ─── Frontmatter 检测 ───

# Returns: "none" | "no_specanchor" | "has_specanchor"
check_existing_frontmatter() {
  local file="$1"
  local first_line
  first_line=$(head -1 "$file" 2>/dev/null || echo "")

  if [[ "$first_line" != "---" ]]; then
    echo "none"
    return
  fi

  local end_line
  end_line=$(awk 'NR>1 && /^---$/{print NR; exit}' "$file")

  if [[ -z "$end_line" ]]; then
    echo "none"
    return
  fi

  local fm_block
  fm_block=$(sed -n "2,$((end_line - 1))p" "$file")

  if echo "$fm_block" | grep -q '^specanchor:' 2>/dev/null; then
    echo "has_specanchor"
  else
    echo "no_specanchor"
  fi
}

# ─── Frontmatter 生成 ───

generate_frontmatter() {
  local level="$1"
  local task_name="$2"
  local author="$3"
  local created="$4"
  local status="$5"
  local last_change="$6"
  local branch="$7"
  local protocol="$8"
  local sdd_phase="$9"
  local related_global="${10}"
  local related_modules="${11}"

  local fm=""
  fm+="specanchor:\n"
  fm+="  level: ${level}\n"

  case "$level" in
    task)
      fm+="  task_name: \"${task_name}\"\n"
      ;;
    module)
      fm+="  module_name: \"${task_name}\"\n"
      fm+="  module_path: \"unknown\"\n"
      ;;
    global)
      fm+="  type: \"unknown\"\n"
      ;;
  esac

  fm+="  author: \"${author}\"\n"
  fm+="  created: \"${created}\"\n"
  fm+="  status: \"${status}\"\n"

  if [[ -n "$last_change" ]]; then
    fm+="  last_change: \"${last_change}\"\n"
  fi

  if [[ "$level" == "task" ]]; then
    if [[ -n "$related_modules" ]]; then
      fm+="  related_modules:\n"
      fm+="${related_modules}"
    else
      fm+="  related_modules: []\n"
    fi

    if [[ -n "$related_global" ]]; then
      fm+="  related_global:\n"
      fm+="${related_global}"
    else
      fm+="  related_global: []\n"
    fi

    fm+="  writing_protocol: \"${protocol}\"\n"

    if [[ "$protocol" == "sdd-riper-one" ]]; then
      fm+="  sdd_phase: \"${sdd_phase}\"\n"
    fi
  fi

  fm+="  branch: \"${branch}\"\n"

  echo -e "$fm"
}

# ─── Frontmatter 注入 ───

inject_single_file() {
  local file="$1"
  local opt_task_name="$2"
  local opt_status="$3"
  local opt_last_change="$4"
  local opt_level="$5"
  local opt_protocol="$6"
  local opt_no_config="$7"
  local opt_dry_run="$8"
  local opt_force="$9"
  local config="${10}"

  [[ -f "$file" ]] || { warn "文件不存在: $file"; COUNT_FAILED=$((COUNT_FAILED + 1)); return; }

  local fm_status
  fm_status=$(check_existing_frontmatter "$file")

  if [[ "$fm_status" == "has_specanchor" ]] && [[ "$opt_force" != "true" ]]; then
    skip "已有 specanchor frontmatter，跳过: $file"
    COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
    return
  fi

  local level author created branch protocol task_name sdd_phase status last_change
  local related_global related_modules

  level="${opt_level:-$(detect_level "$file")}"
  author=$(detect_author)
  created=$(detect_created "$file")
  branch=$(detect_branch)
  protocol="${opt_protocol:-$(detect_protocol "$config")}"
  task_name="${opt_task_name:-$(detect_task_name "$file")}"
  sdd_phase=$(detect_sdd_phase "$file")
  status="${opt_status:-$(detect_status "$file")}"
  last_change="${opt_last_change:-}"
  related_global=$(detect_related_global)
  related_modules=$(detect_related_modules "$file")

  local fm_content
  fm_content=$(generate_frontmatter "$level" "$task_name" "$author" "$created" "$status" \
    "$last_change" "$branch" "$protocol" "$sdd_phase" "$related_global" "$related_modules")

  if [[ "$opt_dry_run" == "true" ]]; then
    echo -e "${BOLD}[dry-run] ${file}${RESET}"
    echo "---"
    echo -e "$fm_content" | sed '/^$/d'
    echo "---"
    echo ""
    COUNT_INJECTED=$((COUNT_INJECTED + 1))
    INJECTED_FILES+=("$file")
    return
  fi

  local tmpfile
  tmpfile=$(mktemp)
  trap "rm -f '$tmpfile'" EXIT

  case "$fm_status" in
    none)
      {
        echo "---"
        echo -e "$fm_content" | sed '/^$/d'
        echo "---"
        echo ""
        cat "$file"
      } > "$tmpfile"
      mv "$tmpfile" "$file"
      success "注入 frontmatter: $file"
      ;;
    no_specanchor)
      local end_line
      end_line=$(awk 'NR>1 && /^---$/{print NR; exit}' "$file")
      if [[ -z "$end_line" ]]; then
        warn "无法定位 frontmatter 结束标记: $file"
        COUNT_FAILED=$((COUNT_FAILED + 1))
        return
      fi
      {
        head -n $((end_line - 1)) "$file"
        echo -e "$fm_content" | sed '/^$/d'
        tail -n +"$end_line" "$file"
      } > "$tmpfile"
      mv "$tmpfile" "$file"
      success "追加 specanchor 段到已有 frontmatter: $file"
      ;;
    has_specanchor)
      if [[ "$opt_force" == "true" ]]; then
        local start_line end_line
        start_line=$(grep -n '^specanchor:' "$file" | head -1 | cut -d: -f1)
        end_line=$(awk 'NR>1 && /^---$/{print NR; exit}' "$file")

        if [[ -z "$start_line" ]] || [[ -z "$end_line" ]]; then
          warn "无法定位 specanchor 段边界: $file"
          COUNT_FAILED=$((COUNT_FAILED + 1))
          return
        fi

        {
          head -n $((start_line - 1)) "$file"
          echo -e "$fm_content" | sed '/^$/d'
          tail -n +"$end_line" "$file"
        } > "$tmpfile"
        mv "$tmpfile" "$file"
        success "强制覆盖 specanchor 段: $file"
      fi
      ;;
  esac

  COUNT_INJECTED=$((COUNT_INJECTED + 1))
  INJECTED_FILES+=("$file")
}

# ─── CLI 入口 ───

usage() {
  echo -e "${BOLD}SpecAnchor Frontmatter Inject${RESET} — Layer 1"
  echo ""
  echo "Usage:"
  echo "  frontmatter-inject.sh <target_file> [options]"
  echo "  frontmatter-inject.sh --dir <directory> [options]"
  echo ""
  echo "Options:"
  echo "  --task-name <name>        覆盖自动推断的 task_name / module_name"
  echo "  --status <status>         覆盖默认 status (default: auto-detect)"
  echo "  --last-change <msg>       设置 last_change 字段"
  echo "  --level <level>           覆盖自动推断的 level (task|module|global)"
  echo "  --writing-protocol <p>    覆盖自动推断的 writing_protocol"
  echo "  --no-config               不读取 anchor.yaml，使用内置默认值"
  echo "  --dry-run                 只输出将要注入的 frontmatter，不修改文件"
  echo "  --force                   已有 specanchor 段时强制覆盖"
  echo "  --file-pattern <glob>     批量模式的文件匹配 (default: *.md)"
  echo ""
  echo "Examples:"
  echo "  frontmatter-inject.sh mydocs/specs/2026-03-16_spec.md"
  echo "  frontmatter-inject.sh mydocs/specs/spec.md --task-name '我的任务'"
  echo "  frontmatter-inject.sh --dir mydocs/specs/ --dry-run"
  echo "  frontmatter-inject.sh --dir mydocs/specs/ --level task --status in_progress"
  exit 0
}

main() {
  local target_file=""
  local target_dir=""
  local opt_task_name=""
  local opt_status=""
  local opt_last_change=""
  local opt_level=""
  local opt_protocol=""
  local opt_no_config="false"
  local opt_dry_run="false"
  local opt_force="false"
  local opt_file_pattern="*.md"

  [[ $# -eq 0 ]] && usage

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h) usage ;;
      --dir) target_dir="$2"; shift 2 ;;
      --task-name) opt_task_name="$2"; shift 2 ;;
      --status) opt_status="$2"; shift 2 ;;
      --last-change) opt_last_change="$2"; shift 2 ;;
      --level) opt_level="$2"; shift 2 ;;
      --writing-protocol) opt_protocol="$2"; shift 2 ;;
      --no-config) opt_no_config="true"; shift ;;
      --dry-run) opt_dry_run="true"; shift ;;
      --force) opt_force="true"; shift ;;
      --file-pattern) opt_file_pattern="$2"; shift 2 ;;
      -*)
        die "未知选项: $1"
        ;;
      *)
        if [[ -z "$target_file" ]]; then
          target_file="$1"
        else
          die "多个文件参数，请使用 --dir 进行批量操作"
        fi
        shift
        ;;
    esac
  done

  local config=""
  if [[ "$opt_no_config" != "true" ]]; then
    config=$(find_config)
  fi

  echo -e "${BOLD}SpecAnchor Frontmatter Inject${RESET}"
  if [[ -n "$config" ]]; then
    echo -e "  ${DIM}config: ${config}${RESET}"
  else
    echo -e "  ${DIM}config: (none — using defaults)${RESET}"
  fi
  [[ "$opt_dry_run" == "true" ]] && echo -e "  ${YELLOW}mode: dry-run${RESET}"
  echo ""

  if [[ -n "$target_dir" ]]; then
    [[ -d "$target_dir" ]] || die "目录不存在: $target_dir"

    local files_found=0
    while IFS= read -r f; do
      [[ -n "$f" ]] || continue
      ((files_found++))
      inject_single_file "$f" "$opt_task_name" "$opt_status" "$opt_last_change" \
        "$opt_level" "$opt_protocol" "$opt_no_config" "$opt_dry_run" "$opt_force" "$config"
    done < <(find "$target_dir" -maxdepth 1 -name "$opt_file_pattern" -type f 2>/dev/null | sort)

    [[ $files_found -eq 0 ]] && warn "目录中未找到匹配 $opt_file_pattern 的文件: $target_dir"

  elif [[ -n "$target_file" ]]; then
    inject_single_file "$target_file" "$opt_task_name" "$opt_status" "$opt_last_change" \
      "$opt_level" "$opt_protocol" "$opt_no_config" "$opt_dry_run" "$opt_force" "$config"
  else
    die "请指定目标文件或 --dir <目录>"
  fi

  echo ""
  echo -e "${BOLD}Summary${RESET}"
  echo -e "  Injected: ${GREEN}${COUNT_INJECTED}${RESET}"
  echo -e "  Skipped:  ${DIM}${COUNT_SKIPPED}${RESET}"
  echo -e "  Failed:   ${RED}${COUNT_FAILED}${RESET}"

  if [[ ${#INJECTED_FILES[@]} -gt 0 ]]; then
    echo ""
    echo -e "${DIM}Injected files:${RESET}"
    for f in "${INJECTED_FILES[@]}"; do
      echo -e "  ${f}"
    done
  fi
}

main "$@"
