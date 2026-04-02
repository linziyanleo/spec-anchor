#!/usr/bin/env bash
# SpecAnchor Frontmatter Inject & Check — Layer 2
#
# 组合 Layer 1 (frontmatter-inject.sh) 和 specanchor-check.sh，
# 实现"注入 → 验证"闭环。
#
# Usage:
#   frontmatter-inject-and-check.sh <target_file> [options]
#   frontmatter-inject-and-check.sh --dir <directory> [options]
#
# Options: 继承 Layer 1 的所有 options + 以下额外选项：
#   --check-level <level>     覆盖检测粒度 (task|module|global)
#   --skip-check              只注入不检测
#   --base <branch>           task 级检测的基准分支 (default: from anchor.yaml)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INJECT_SCRIPT="${SCRIPT_DIR}/frontmatter-inject.sh"
CHECK_SCRIPT="${SCRIPT_DIR}/specanchor-check.sh"

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

die() { echo -e "${RED}error:${RESET} $*" >&2; exit 1; }

# ─── CLI 入口 ───

usage() {
  echo -e "${BOLD}SpecAnchor Frontmatter Inject & Check${RESET} — Layer 2"
  echo ""
  echo "Usage:"
  echo "  frontmatter-inject-and-check.sh <target_file> [options]"
  echo "  frontmatter-inject-and-check.sh --dir <directory> [options]"
  echo ""
  echo "Layer 1 Options (passed to frontmatter-inject.sh):"
  echo "  --task-name <name>        覆盖自动推断的 task_name"
  echo "  --status <status>         覆盖默认 status"
  echo "  --last-change <msg>       设置 last_change 字段"
  echo "  --level <level>           覆盖自动推断的 level (task|module|global)"
  echo "  --writing-protocol <p>    覆盖自动推断的 writing_protocol"
  echo "  --no-config               不读取 anchor.yaml"
  echo "  --dry-run                 只输出，不修改文件也不运行检测"
  echo "  --force                   已有 specanchor 段时强制覆盖"
  echo "  --file-pattern <glob>     批量模式的文件匹配"
  echo ""
  echo "Layer 2 Options:"
  echo "  --check-level <level>     覆盖检测粒度 (task|module|global)"
  echo "  --skip-check              只注入不检测"
  echo "  --base <branch>           task 级检测的基准分支"
  echo ""
  echo "Examples:"
  echo "  frontmatter-inject-and-check.sh mydocs/specs/spec.md"
  echo "  frontmatter-inject-and-check.sh --dir mydocs/specs/ --skip-check"
  echo "  frontmatter-inject-and-check.sh spec.md --check-level global"
  exit 0
}

main() {
  [[ $# -eq 0 ]] && usage

  # 分离 Layer 1 和 Layer 2 参数
  local inject_args=()
  local check_level=""
  local skip_check="false"
  local base_branch=""
  local dry_run="false"
  local target_file=""
  local target_dir=""
  local opt_level=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h) usage ;;
      --check-level) check_level="$2"; shift 2 ;;
      --skip-check) skip_check="true"; shift ;;
      --base) base_branch="$2"; shift 2 ;;
      --dry-run) dry_run="true"; inject_args+=("--dry-run"); shift ;;
      --dir)
        target_dir="$2"
        inject_args+=("--dir" "$2")
        shift 2
        ;;
      --level)
        opt_level="$2"
        inject_args+=("--level" "$2")
        shift 2
        ;;
      -*)
        inject_args+=("$1")
        if [[ $# -gt 1 ]] && [[ "$2" != -* ]]; then
          inject_args+=("$2")
          shift
        fi
        shift
        ;;
      *)
        if [[ -z "$target_file" ]]; then
          target_file="$1"
          inject_args+=("$1")
        fi
        shift
        ;;
    esac
  done

  [[ -f "$INJECT_SCRIPT" ]] || die "Layer 1 脚本不存在: $INJECT_SCRIPT"

  echo -e "${BOLD}═══ Phase 1: Frontmatter Inject ═══${RESET}"
  echo ""

  bash "$INJECT_SCRIPT" "${inject_args[@]}"
  local inject_exit=$?

  if [[ $inject_exit -ne 0 ]]; then
    die "Layer 1 注入失败 (exit code: $inject_exit)"
  fi

  if [[ "$dry_run" == "true" ]]; then
    echo ""
    echo -e "${DIM}dry-run 模式，跳过检测${RESET}"
    return 0
  fi

  if [[ "$skip_check" == "true" ]]; then
    echo ""
    echo -e "${DIM}--skip-check，跳过检测${RESET}"
    return 0
  fi

  if [[ ! -f "$CHECK_SCRIPT" ]]; then
    echo ""
    echo -e "${YELLOW}warning:${RESET} specanchor-check.sh 不存在: $CHECK_SCRIPT"
    echo -e "${DIM}跳过检测。可在 scripts/ 下放置 specanchor-check.sh 以启用。${RESET}"
    return 0
  fi

  echo ""
  echo -e "${BOLD}═══ Phase 2: Freshness Check ═══${RESET}"
  echo ""

  local effective_level="${check_level:-${opt_level:-}}"

  if [[ -n "$target_dir" ]]; then
    effective_level="${effective_level:-global}"
  elif [[ -n "$target_file" ]]; then
    if [[ -z "$effective_level" ]]; then
      local first_line
      first_line=$(head -1 "$target_file" 2>/dev/null || echo "")
      if [[ "$first_line" == "---" ]]; then
        local detected
        detected=$(sed -n '2,/^---$/p' "$target_file" | grep '^\s*level:' | head -1 | sed 's/.*level: *\"\{0,1\}//' | sed 's/\"\{0,1\} *$//')
        effective_level="${detected:-task}"
      else
        effective_level="task"
      fi
    fi
  fi

  case "$effective_level" in
    task)
      local check_args=("task" "$target_file")
      [[ -n "$base_branch" ]] && check_args+=("--base=$base_branch")
      echo -e "${DIM}Running: specanchor-check.sh ${check_args[*]}${RESET}"
      echo ""
      bash "$CHECK_SCRIPT" "${check_args[@]}" 2>&1 || true
      ;;
    module)
      if [[ -n "$target_file" ]]; then
        echo -e "${DIM}Running: specanchor-check.sh module $target_file${RESET}"
        echo ""
        bash "$CHECK_SCRIPT" module "$target_file" 2>&1 || true
      else
        echo -e "${DIM}Running: specanchor-check.sh module --all${RESET}"
        echo ""
        bash "$CHECK_SCRIPT" module --all 2>&1 || true
      fi
      ;;
    global)
      echo -e "${DIM}Running: specanchor-check.sh global${RESET}"
      echo ""
      bash "$CHECK_SCRIPT" global 2>&1 || true
      ;;
    *)
      echo -e "${YELLOW}warning:${RESET} 无法确定检测粒度 (level=${effective_level})，使用 global"
      echo ""
      bash "$CHECK_SCRIPT" global 2>&1 || true
      ;;
  esac

  echo ""
  echo -e "${BOLD}═══ Done ═══${RESET}"
}

main "$@"
