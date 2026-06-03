#!/usr/bin/env bash
# SpecAnchor Boot - 启动检查脚本
#
# 替代 Skill 激活时的多步 Glob/Read 操作，一次性输出结构化摘要，
# 让 Agent 直接消费结论而非逐文件扫描，节省 60-90% 启动 token。
#
# Usage:
#   specanchor-boot.sh                    # 精简摘要（默认）
#   specanchor-boot.sh --format=summary   # 同上
#   specanchor-boot.sh --with-schemas      # 默认开启；显式声明用于兼容
#   specanchor-boot.sh --no-schemas        # 关闭 Available Schemas 段（精简输出）
#   specanchor-boot.sh --format=full      # 含 Global Spec 内容
#   specanchor-boot.sh --format=json      # JSON 机器可读
#   specanchor-boot.sh --format=inline-brief  # 精简内联摘要（用于 hook 注入，~600 token）
#
# 配置文件查找顺序（root-first，支持 local overlay）：
#   1. 项目根目录 anchor.yaml
#   2. anchor.local.yaml（若存在，则叠加到 anchor.yaml）
#   3. .specanchor/config.yaml（向后兼容，仅在缺少 anchor.yaml 时使用）
#
# 脚本定位逻辑：
#   此脚本位于 Skill 安装目录的 scripts/ 下。运行时需要 cd 到用户项目根目录，
#   并通过 SPECANCHOR_SKILL_DIR 环境变量指定 Skill 安装目录（用于查找内置 schemas）。
#   如未设置，fallback 到脚本自身所在目录的上级目录。

set -euo pipefail

# ─── 脚本自定位 ───

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="${SPECANCHOR_SKILL_DIR:-$(dirname "$SCRIPT_DIR")}"
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

# ─── 全局状态（由 boot_* 函数直接写入）───

# Config
B_CONFIG_STATUS=""    # ok | missing
B_CONFIG_PATH=""
B_CONFIG_DISPLAY=""
B_CONFIG_WARN=""      # legacy | ""
B_MODE=""
B_PROJECT_NAME=""
B_VERSION=""
B_DEFAULT_SCHEMA=""

# .specanchor/ dir
B_SA_DIR=""           # ok | missing
B_MODULE_COUNT=0
B_TASK_ACTIVE=0
B_TASK_ARCHIVED=0
B_SPEC_INDEX=""       # ok | missing
B_SPEC_INDEX_PATH=""
B_SPEC_INDEX_FORMAT=""  # v3 | legacy-module-v2 | legacy | ""
B_INDEX_HEALTH_FRESH=0
B_INDEX_HEALTH_DRIFTED=0
B_INDEX_HEALTH_STALE=0
B_INDEX_HEALTH_OUTDATED=0
declare -a B_MOD_PATHS=()
declare -a B_MOD_SPECS=()
declare -a B_MOD_SUMMARIES=()
declare -a B_MOD_HEALTHS=()

# Active Task Specs
declare -a B_TASK_NAMES=()
declare -a B_TASK_STATUSES=()
declare -a B_TASK_PHASES=()       # RIPER phase (sdd-riper-one schema only); empty for fluid schemas
declare -a B_TASK_PROTOCOLS=()
declare -a B_TASK_PATHS=()
B_TASKS_MODE="all"        # all | open | none — open 折叠终态 done/archived 为计数；none 仅留计数行

# Global Specs
B_GLOBAL_STATUS=""    # ok | missing
B_GLOBAL_COUNT=0
B_GLOBAL_LINES=0
declare -a B_GLOBAL_NAMES=()
declare -a B_GLOBAL_LINE_COUNTS=()

# Sources
B_SOURCES_COUNT=0
declare -a B_SRC_PATHS=()
declare -a B_SRC_TYPES=()
declare -a B_SRC_STALE=()
declare -a B_SRC_FRONTMATTER=()
declare -a B_SRC_EXISTS=()

# Schemas
B_SCHEMA_COUNT=0
declare -a B_SCH_NAMES=()
declare -a B_SCH_SOURCES=()     # custom | builtin
declare -a B_SCH_PHILOSOPHIES=()
declare -a B_SCH_DESCS=()
SHOW_SCHEMAS=true

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

parse_yaml_field() {
  local file="$1" field="$2" default="${3:-}"
  if [[ -f "$file" ]]; then
    local raw val
    # 尝试 4 空格缩进（嵌套字段）→ 2 空格 → 0 缩进（顶层字段）
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

parse_yaml_list_first() {
  local file="$1" field="$2"
  if [[ ! -f "$file" ]]; then return; fi
  local raw
  raw=$(awk -v field="$field" '
    $0 ~ "^ *" field ":" { in_list = 1; next }
    in_list && $0 ~ "^ *- " {
      sub("^ *- *", "", $0)
      print
      exit
    }
    in_list && $0 ~ "^ *[A-Za-z0-9_-]+:" { exit }
  ' "$file")
  normalize_scalar "$raw"
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

B_READINESS_STATUS=""
declare -a B_READINESS_REASONS=()

compute_landscape_readiness() {
  [[ -n "$B_READINESS_STATUS" ]] && return 0
  if [[ "$B_MODE" != "full" ]]; then
    B_READINESS_STATUS="N/A"
    B_READINESS_REASONS+=("parasitic mode (sources-only governance)")
    return
  fi

  local not_ready=0 attention=0

  if [[ "$B_GLOBAL_COUNT" -eq 0 ]]; then
    B_READINESS_REASONS+=("no global specs")
    not_ready=1
  fi

  if [[ "$B_SPEC_INDEX" != "ok" ]]; then
    B_READINESS_REASONS+=("spec-index missing")
    not_ready=1
  elif [[ "$B_SPEC_INDEX_FORMAT" != "v3" ]]; then
    B_READINESS_REASONS+=("spec-index is ${B_SPEC_INDEX_FORMAT} format")
    attention=1
  fi

  if [[ "$B_INDEX_HEALTH_OUTDATED" -gt 0 ]]; then
    B_READINESS_REASONS+=("${B_INDEX_HEALTH_OUTDATED} OUTDATED module(s)")
    not_ready=1
  fi
  if [[ "$B_INDEX_HEALTH_STALE" -gt 0 ]]; then
    B_READINESS_REASONS+=("${B_INDEX_HEALTH_STALE} STALE module(s)")
    attention=1
  fi
  if [[ "$B_INDEX_HEALTH_DRIFTED" -gt 0 ]]; then
    B_READINESS_REASONS+=("${B_INDEX_HEALTH_DRIFTED} DRIFTED module(s)")
    attention=1
  fi

  if [[ "$not_ready" -gt 0 ]]; then
    B_READINESS_STATUS="NOT_READY"
  elif [[ "$attention" -gt 0 ]]; then
    B_READINESS_STATUS="ATTENTION"
  else
    B_READINESS_STATUS="READY"
  fi
}

readiness_icon() {
  case "$1" in
    READY)     echo "🟢" ;;
    ATTENTION) echo "🟡" ;;
    NOT_READY) echo "🔴" ;;
    N/A)       echo "⚪" ;;
    *)         echo "⚪" ;;
  esac
}

readiness_detail() {
  local icon
  icon=$(readiness_icon "$B_READINESS_STATUS")

  if [[ "$B_READINESS_STATUS" == "READY" ]]; then
    printf '%s READY (%d globals, %d/%d modules fresh)' \
      "$icon" "$B_GLOBAL_COUNT" "$B_INDEX_HEALTH_FRESH" \
      "$((B_INDEX_HEALTH_FRESH + B_INDEX_HEALTH_DRIFTED + B_INDEX_HEALTH_STALE + B_INDEX_HEALTH_OUTDATED))"
  elif [[ "$B_READINESS_STATUS" == "N/A" ]]; then
    printf '%s N/A — %s' "$icon" "${B_READINESS_REASONS[0]:-parasitic mode}"
  else
    printf '%s %s — %s' "$icon" "$B_READINESS_STATUS" "$(join_by ", " "${B_READINESS_REASONS[@]}")"
  fi
}

# 终态状态：在 --tasks=open 下折叠为计数。draft/review/in_progress/未知非终态一律保留可见。
task_status_is_terminal() {
  case "$1" in
    done|archived) return 0 ;;
    *) return 1 ;;
  esac
}

emit_active_tasks() {
  [[ "${#B_TASK_NAMES[@]}" -eq 0 ]] && return 0
  [[ "$B_TASKS_MODE" == "none" ]] && return 0

  echo -e "  Active Tasks:"
  local i status_disp phase_disp protocol_disp name path
  local collapsed=0
  for i in "${!B_TASK_NAMES[@]}"; do
    name="${B_TASK_NAMES[$i]}"
    status_disp="${B_TASK_STATUSES[$i]}"
    phase_disp="${B_TASK_PHASES[$i]}"
    protocol_disp="${B_TASK_PROTOCOLS[$i]}"
    path="${B_TASK_PATHS[$i]}"

    if [[ "$B_TASKS_MODE" == "open" || "$B_TASKS_MODE" == "compact" ]] && task_status_is_terminal "$status_disp"; then
      collapsed=$((collapsed + 1))
      continue
    fi

    if [[ "$B_TASKS_MODE" == "compact" ]]; then
      echo "    - ${name} [${status_disp}]"
      continue
    fi

    local status_color="$DIM"
    case "$status_disp" in
      in_progress) status_color="$YELLOW" ;;
      review)      status_color="$CYAN" ;;
      done)        status_color="$GREEN" ;;
      draft)       status_color="$DIM" ;;
    esac

    local meta="${status_color}${status_disp}${RESET}"
    if [[ -n "$phase_disp" ]]; then
      meta="${meta} ${DIM}·${RESET} ${phase_disp}"
    fi
    meta="${meta} ${DIM}(${protocol_disp})${RESET}"
    echo -e "    - ${name} [${meta}] ${DIM}${path}${RESET}"
  done
  if [[ "$B_TASKS_MODE" == "open" || "$B_TASKS_MODE" == "compact" ]] && [[ $collapsed -gt 0 ]]; then
    echo -e "    ${DIM}(+${collapsed} done/archived collapsed; --tasks=all 展开)${RESET}"
  fi
}

emit_next_action() {
  local next=""
  local i
  for i in "${!B_TASK_STATUSES[@]}"; do
    if [[ "${B_TASK_STATUSES[$i]}" == "in_progress" ]]; then
      local phase_hint=""
      [[ -n "${B_TASK_PHASES[$i]}" ]] && phase_hint="，当前 ${B_TASK_PHASES[$i]}"
      next="继续执行 ${B_TASK_NAMES[$i]}${phase_hint}"
      break
    fi
  done
  if [[ -z "$next" ]]; then
    for i in "${!B_TASK_STATUSES[@]}"; do
      if [[ "${B_TASK_STATUSES[$i]}" == "review" ]]; then
        next="完成 ${B_TASK_NAMES[$i]} Review"
        break
      fi
    done
  fi
  if [[ -z "$next" ]]; then
    for i in "${!B_TASK_STATUSES[@]}"; do
      if [[ "${B_TASK_STATUSES[$i]}" == "draft" ]]; then
        next="推进 ${B_TASK_NAMES[$i]} 到 PLAN"
        break
      fi
    done
  fi
  if [[ -z "$next" ]]; then
    compute_landscape_readiness
    if [[ "$B_READINESS_STATUS" == "NOT_READY" ]] || [[ "$B_READINESS_STATUS" == "ATTENTION" ]]; then
      next="处理 Landscape 健康度问题（${B_READINESS_REASONS[0]}）"
    fi
  fi
  if [[ -z "$next" ]] && [[ ${#B_TASK_NAMES[@]} -eq 0 ]]; then
    next="用 specanchor_task 创建新任务"
  fi
  [[ -n "$next" ]] && echo -e "  ${BOLD}Next:${RESET} ${next}"
}

emit_assembly_trace() {
  local global_mode="$1"
  local i

  echo -e "  Assembly Trace:"

  if [[ "$B_MODE" == "full" ]]; then
    if [[ "$B_GLOBAL_COUNT" -gt 0 ]]; then
      local global_files=()
      for i in "${!B_GLOBAL_NAMES[@]}"; do
        global_files+=(".specanchor/global/${B_GLOBAL_NAMES[$i]}.spec.md")
      done
      echo -e "    - Global: ${CYAN}${global_mode}${RESET} -> $(join_by ", " "${global_files[@]}")"
    else
      echo -e "    - Global: ${YELLOW}none${RESET} -> .specanchor/global/ has no loadable spec"
    fi
    echo -e "    - Module: ${DIM}deferred${RESET} -> none (on-demand after module/path match)"
  else
    echo -e "    - Global: ${DIM}skipped${RESET} -> parasitic mode does not auto-load global specs"
    echo -e "    - Module: ${DIM}sources-only${RESET} -> none (external specs load on demand)"
  fi

  compute_landscape_readiness
  echo -e "    - Landscape Readiness: $(readiness_detail)"
}

emit_command_routing() {
  cat <<'EOF'
  Available Commands:
    init     -> commands/init.md      | 初始化配置与目录
    global   -> commands/global.md    | Global Spec CRUD
    module   -> commands/module.md    | Module Spec CRUD
    infer    -> commands/infer.md     | 从代码逆推 Module Spec
    task     -> commands/task.md      | 创建 Task Spec
    load     -> commands/load.md      | 手动加载 Spec
    status   -> commands/status.md    | 状态/覆盖率
    check    -> commands/check.md     | 对齐检测
    index    -> commands/index.md     | 更新 spec-index
    import   -> commands/import.md    | 导入外部 SDD
    handoff  -> commands/handoff.md   | 跨 session 导出 handoff packet
EOF
}

truncate_summary() {
  local value="$1"
  if [[ ${#value} -gt 60 ]]; then
    printf '%s…' "${value:0:59}"
  else
    printf '%s' "$value"
  fi
}

health_icon() {
  case "$1" in
    FRESH) echo "🟢" ;;
    DRIFTED) echo "🟡" ;;
    STALE) echo "🟠" ;;
    OUTDATED) echo "🔴" ;;
    *) echo "⚪" ;;
  esac
}

emit_available_modules() {
  echo -e "  Available Modules:"
  if [[ "$B_SPEC_INDEX" == "ok" ]] && [[ "$B_SPEC_INDEX_FORMAT" != "v3" ]]; then
    echo -e "    ${YELLOW}⚠ legacy module-index.md (run specanchor_index to upgrade)${RESET}"
  fi
  if [[ ${#B_MOD_PATHS[@]} -eq 0 ]]; then
    echo -e "    ${DIM}(no modules covered yet — run \`specanchor_module\` to start)${RESET}"
    return
  fi

  local max=10 i shown=0 hidden=0
  for i in "${!B_MOD_PATHS[@]}"; do
    local should_show=1
    if [[ ${#B_MOD_PATHS[@]} -gt $max ]]; then
      should_show=0
      if [[ "${B_MOD_HEALTHS[$i]}" != "FRESH" ]] || [[ "$shown" -lt 3 ]]; then
        should_show=1
      fi
    fi
    if [[ "$should_show" -eq 0 ]]; then
      hidden=$((hidden + 1))
      continue
    fi
    local icon summary
    icon=$(health_icon "${B_MOD_HEALTHS[$i]}")
    summary=$(truncate_summary "${B_MOD_SUMMARIES[$i]}")
    printf '    %-13s -> %-22s | %s [%s %s]\n' \
      "${B_MOD_PATHS[$i]}" \
      "${B_MOD_SPECS[$i]}" \
      "$summary" \
      "$icon" \
      "${B_MOD_HEALTHS[$i]:-UNKNOWN}"
    shown=$((shown + 1))
  done
  if [[ "$hidden" -gt 0 ]]; then
    echo -e "    … (+${hidden} more, see .specanchor/spec-index.md)"
  fi
}

# ─── 核心检查函数（直接写全局变量）───

boot_config() {
  if ! B_CONFIG_PATH=$(sa_find_config); then
    B_CONFIG_STATUS="missing"
    return
  fi

  B_CONFIG_DISPLAY=$(sa_config_label "$B_CONFIG_PATH")
  if [[ "$B_CONFIG_PATH" == ".specanchor/config.yaml" ]]; then
    B_CONFIG_WARN="legacy"
  fi

  B_CONFIG_STATUS="ok"
  B_MODE=$(sa_parse_config_field "$B_CONFIG_PATH" "mode" "full")
  B_PROJECT_NAME=$(sa_parse_config_field "$B_CONFIG_PATH" "project_name" "unknown")
  B_VERSION=$(sa_parse_config_field "$B_CONFIG_PATH" "version" "unknown")
  B_DEFAULT_SCHEMA=$(sa_parse_config_field "$B_CONFIG_PATH" "schema" "sdd-riper-one")
}

collect_active_task_details() {
  local file rel name status protocol phase
  while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    rel="${file#.specanchor/tasks/}"
    name=$(parse_yaml_field "$file" "task_name")
    status=$(parse_yaml_field "$file" "status")
    protocol=$(parse_yaml_field "$file" "writing_protocol")
    [[ -z "$protocol" ]] && protocol="$B_DEFAULT_SCHEMA"
    [[ -z "$protocol" ]] && protocol="sdd-riper-one"
    phase=""
    if [[ "$protocol" == "sdd-riper-one" ]]; then
      # pipefail-safe：缺 RIPER Phase 标记时 grep 退出 1，末尾 || true 防止 set -e 中断 boot
      phase=$(grep -m1 '^> Current RIPER Phase:' "$file" 2>/dev/null \
        | sed -E 's/^> Current RIPER Phase:[[:space:]]*//' | tr -d '[:space:]' || true)
    fi
    B_TASK_NAMES+=("${name:-(unnamed)}")
    B_TASK_STATUSES+=("${status:-unknown}")
    B_TASK_PHASES+=("$phase")
    B_TASK_PROTOCOLS+=("$protocol")
    B_TASK_PATHS+=("$rel")
  done < <(find ".specanchor/tasks" -name "*.spec.md" 2>/dev/null | sort)
}

boot_specanchor_dir() {
  if [[ ! -d ".specanchor" ]]; then
    B_SA_DIR="missing"
    return
  fi
  B_SA_DIR="ok"

  if [[ -d ".specanchor/modules" ]]; then
    B_MODULE_COUNT=$(find ".specanchor/modules" -maxdepth 1 -name "*.spec.md" 2>/dev/null | wc -l | tr -d ' ')
  fi

  if [[ -d ".specanchor/tasks" ]]; then
    B_TASK_ACTIVE=$(find ".specanchor/tasks" -name "*.spec.md" 2>/dev/null | wc -l | tr -d ' ')
    collect_active_task_details
  fi
  if [[ -d ".specanchor/archive" ]]; then
    B_TASK_ARCHIVED=$(find ".specanchor/archive" -name "*.spec.md" 2>/dev/null | wc -l | tr -d ' ')
  fi

  if B_SPEC_INDEX_PATH=$(sa_load_spec_index_or_legacy "$B_CONFIG_PATH" 2>/dev/null); then
    B_SPEC_INDEX="ok"
    local idx_type
    idx_type=$(sa_index_type "$B_SPEC_INDEX_PATH")
    case "$idx_type" in
      spec-index) B_SPEC_INDEX_FORMAT="v3" ;;
      module-index) B_SPEC_INDEX_FORMAT="legacy-module-v2" ;;
      *) B_SPEC_INDEX_FORMAT="legacy" ;;
    esac

    local module_path spec_file summary health
    while IFS=$'\t' read -r module_path spec_file summary health; do
      [[ -n "$module_path" ]] || continue
      [[ -z "$health" ]] && health="UNKNOWN"
      B_MOD_PATHS+=("$module_path")
      B_MOD_SPECS+=("$spec_file")
      B_MOD_SUMMARIES+=("$summary")
      B_MOD_HEALTHS+=("$health")
      case "$health" in
        FRESH) B_INDEX_HEALTH_FRESH=$((B_INDEX_HEALTH_FRESH + 1)) ;;
        DRIFTED) B_INDEX_HEALTH_DRIFTED=$((B_INDEX_HEALTH_DRIFTED + 1)) ;;
        STALE) B_INDEX_HEALTH_STALE=$((B_INDEX_HEALTH_STALE + 1)) ;;
        OUTDATED) B_INDEX_HEALTH_OUTDATED=$((B_INDEX_HEALTH_OUTDATED + 1)) ;;
      esac
    done < <(sa_iter_index_modules "$B_SPEC_INDEX_PATH")
  else
    B_SPEC_INDEX="missing"
  fi
}

boot_global_specs() {
  local global_dir=".specanchor/global"
  if [[ ! -d "$global_dir" ]]; then
    B_GLOBAL_STATUS="missing"
    return
  fi

  B_GLOBAL_STATUS="ok"
  for f in "$global_dir"/*.spec.md; do
    [[ -f "$f" ]] || continue
    local name lines
    name=$(basename "$f" .spec.md)
    lines=$(wc -l < "$f" | tr -d ' ')
    B_GLOBAL_NAMES+=("$name")
    B_GLOBAL_LINE_COUNTS+=("$lines")
    B_GLOBAL_LINES=$((B_GLOBAL_LINES + lines))
    B_GLOBAL_COUNT=$((B_GLOBAL_COUNT + 1))
  done
}

boot_sources() {
  local config="$1"
  local source_path="" source_type="" stale_check="" frontmatter_inject=""

  while IFS=$'\t' read -r source_path source_type stale_check frontmatter_inject; do
    [[ -n "$source_path" ]] || continue
    local dir_exists="no"
    [[ -d "$source_path" ]] && dir_exists="yes"
    B_SRC_PATHS+=("$source_path")
    B_SRC_TYPES+=("$source_type")
    B_SRC_STALE+=("$stale_check")
    B_SRC_FRONTMATTER+=("$frontmatter_inject")
    B_SRC_EXISTS+=("$dir_exists")
    B_SOURCES_COUNT=$((B_SOURCES_COUNT + 1))
  done < <(sa_iter_config_sources "$config")
}

boot_schemas() {
  # 用空格分隔的字符串模拟集合（兼容 bash 3.x，无 associative array）
  local seen_names=""

  _is_seen() {
    local name="$1"
    [[ " $seen_names " == *" $name "* ]]
  }

  _add_schema() {
    local name="$1" source="$2" philosophy="$3" desc="$4"
    B_SCH_NAMES+=("$name")
    B_SCH_SOURCES+=("$source")
    B_SCH_PHILOSOPHIES+=("$philosophy")
    B_SCH_DESCS+=("$desc")
    B_SCHEMA_COUNT=$((B_SCHEMA_COUNT + 1))
    seen_names="$seen_names $name"
  }

  # schema.yaml 的顶层字段用 0 缩进，需要专用解析器避免匹配到 artifacts 内的同名字段
  _parse_schema_top_field() {
    local file="$1" field="$2" default="${3:-}"
    local val
    val=$(grep "^${field}:" "$file" 2>/dev/null | head -1 | sed "s/^${field}: *\"\{0,1\}//;s/\"\{0,1\} *$//" | sed 's/ *#.*//')
    [[ -n "$val" ]] && echo "$val" || echo "$default"
  }

  # 优先扫描项目自定义 schemas
  if [[ -d ".specanchor/schemas" ]]; then
    for schema_yaml in .specanchor/schemas/*/schema.yaml; do
      [[ -f "$schema_yaml" ]] || continue
      local name desc philosophy
      name=$(_parse_schema_top_field "$schema_yaml" "name" "")
      [[ -z "$name" ]] && continue
      desc=$(_parse_schema_top_field "$schema_yaml" "description" "")
      philosophy=$(_parse_schema_top_field "$schema_yaml" "philosophy" "strict")
      _add_schema "$name" "custom" "$philosophy" "$desc"
    done
  fi

  # 扫描 Skill 内置 schemas
  local builtin_dir="${SKILL_DIR}/references/schemas"
  if [[ -d "$builtin_dir" ]]; then
    for schema_yaml in "$builtin_dir"/*/schema.yaml; do
      [[ -f "$schema_yaml" ]] || continue
      local name desc philosophy
      name=$(_parse_schema_top_field "$schema_yaml" "name" "")
      [[ -z "$name" ]] && continue
      # 跳过已被自定义覆盖的同名 schema
      if _is_seen "$name"; then continue; fi
      desc=$(_parse_schema_top_field "$schema_yaml" "description" "")
      philosophy=$(_parse_schema_top_field "$schema_yaml" "philosophy" "strict")
      _add_schema "$name" "builtin" "$philosophy" "$desc"
    done
  fi

  unset -f _add_schema _is_seen _parse_schema_top_field
}

# ─── 收集所有数据 ───

collect_all() {
  boot_config

  if [[ "$B_CONFIG_STATUS" == "missing" ]]; then return; fi

  if [[ "$B_MODE" == "full" ]]; then
    boot_specanchor_dir
    if [[ "$B_SA_DIR" != "missing" ]]; then
      boot_global_specs
    fi
    if [[ "$SHOW_SCHEMAS" == "true" ]]; then
      boot_schemas
    fi
  fi

  boot_sources "$B_CONFIG_PATH"
}

# ─── 输出格式化 ───

output_summary() {
  local global_mode="${1:-summary}"

  collect_all

  if [[ "$B_CONFIG_STATUS" == "missing" ]]; then
    echo -e "${RED}⛔ 未找到 anchor.yaml 或 .specanchor/config.yaml${RESET}"
    echo -e "  请先说\"初始化 SpecAnchor\"来创建。"
    exit 1
  fi

  if [[ "$B_CONFIG_WARN" == "legacy" ]]; then
    echo -e "${YELLOW}⚠️ 检测到旧版配置 .specanchor/config.yaml，建议迁移到根目录 anchor.yaml${RESET}" >&2
  fi

  if [[ "$B_MODE" == "full" ]] && [[ "$B_SA_DIR" == "missing" ]]; then
    echo -e "${RED}⛔ mode 为 full 但 .specanchor/ 目录不存在${RESET}"
    exit 1
  fi

  echo -e "${BOLD}SpecAnchor Boot [${B_MODE}]${RESET}"
  echo -e "  Config: ${CYAN}${B_CONFIG_DISPLAY}${RESET} (v${B_VERSION}, project: ${B_PROJECT_NAME})"
  emit_assembly_trace "$global_mode"

  if [[ "$B_MODE" == "full" ]]; then
    # Global Specs
    if [[ "$B_GLOBAL_STATUS" == "ok" ]]; then
      echo -e "  Global Specs: ${GREEN}${B_GLOBAL_COUNT} files${RESET}, ${B_GLOBAL_LINES} lines total"
      for i in "${!B_GLOBAL_NAMES[@]}"; do
        echo -e "    - ${B_GLOBAL_NAMES[$i]}.spec.md (${B_GLOBAL_LINE_COUNTS[$i]} lines)"
      done
    else
      echo -e "  Global Specs: ${YELLOW}⚠️ .specanchor/global/ 不存在，建议生成${RESET}"
    fi

    # Module / Task
    echo -e "  Module Specs: ${B_MODULE_COUNT} module(s) (按需加载)"
    if [[ "$B_SPEC_INDEX" == "ok" ]] && [[ "$B_SPEC_INDEX_FORMAT" == "v3" ]]; then
      echo -e "  Spec Index: ${GREEN}v3 (structured)${RESET} — 🟢${B_INDEX_HEALTH_FRESH} 🟡${B_INDEX_HEALTH_DRIFTED} 🟠${B_INDEX_HEALTH_STALE} 🔴${B_INDEX_HEALTH_OUTDATED}"
    elif [[ "$B_SPEC_INDEX" == "ok" ]]; then
      echo -e "  Spec Index: ${YELLOW}${B_SPEC_INDEX_FORMAT}${RESET} — 建议运行 specanchor_index 迁移到 v3 格式"
    else
      echo -e "  ${YELLOW}⚠️ spec-index.md 不存在，建议运行 specanchor_index${RESET}"
    fi
    echo -e "  Task Specs: ${B_TASK_ACTIVE} active, ${B_TASK_ARCHIVED} archived"
    emit_active_tasks
    emit_command_routing
    emit_available_modules

    # Sources
    if [[ $B_SOURCES_COUNT -gt 0 ]]; then
      echo -e "  Sources:"
      for i in "${!B_SRC_PATHS[@]}"; do
        local icon="${GREEN}✓${RESET}"
        [[ "${B_SRC_EXISTS[$i]}" != "yes" ]] && icon="${RED}✗${RESET}"
        echo -e "    ${icon} ${B_SRC_PATHS[$i]} [${B_SRC_TYPES[$i]}]: stale_check=${B_SRC_STALE[$i]:-?}, frontmatter_inject=${B_SRC_FRONTMATTER[$i]:-?}"
      done
    else
      echo -e "  Sources: (无外部来源)"
    fi

    if [[ "$SHOW_SCHEMAS" == "true" ]]; then
      echo -e "  Available Schemas:"
      if [[ $B_SCHEMA_COUNT -gt 0 ]]; then
        for i in "${!B_SCH_NAMES[@]}"; do
          local tag=""
          [[ "${B_SCH_SOURCES[$i]}" == "custom" ]] && tag=" ${CYAN}[custom]${RESET}"
          [[ "${B_SCH_NAMES[$i]}" == "$B_DEFAULT_SCHEMA" ]] && tag="${tag} ${DIM}(default)${RESET}"
          local desc="${B_SCH_DESCS[$i]}"
          if [[ "$global_mode" == "summary" ]] && [[ ${#desc} -gt 60 ]]; then
            desc="${desc:0:57}..."
          fi
          echo -e "    ${B_SCH_NAMES[$i]}${tag} [${B_SCH_PHILOSOPHIES[$i]}]: ${desc}"
        done
      else
        echo -e "    ${DIM}(none — fallback to sdd-riper-one)${RESET}"
      fi
    fi

    emit_next_action

  elif [[ "$B_MODE" == "parasitic" ]]; then
    if [[ $B_SOURCES_COUNT -gt 0 ]]; then
      echo -e "  Sources:"
      for i in "${!B_SRC_PATHS[@]}"; do
        local icon="${GREEN}✓${RESET}"
        [[ "${B_SRC_EXISTS[$i]}" != "yes" ]] && icon="${RED}✗${RESET}"
        echo -e "    ${icon} ${B_SRC_PATHS[$i]} [${B_SRC_TYPES[$i]}]: stale_check=${B_SRC_STALE[$i]:-?}, frontmatter_inject=${B_SRC_FRONTMATTER[$i]:-?}"
      done
    else
      echo -e "  Sources: ${YELLOW}⚠️ parasitic 模式但未配置 sources${RESET}"
    fi
    echo -e "  ${DIM}Note: parasitic 模式仅提供治理能力（腐化检测 + 扫描），不支持创建 Spec${RESET}"
  fi
}

output_inline_brief() {
  local budget="${SPECANCHOR_INLINE_BUDGET:-600}"
  if [[ -f "anchor.yaml" ]]; then
    local cfg_budget
    cfg_budget="$(parse_yaml_field "anchor.yaml" "inline_budget_tokens" "")"
    if [[ -n "$cfg_budget" ]]; then
      if [[ "$cfg_budget" -lt 200 ]] 2>/dev/null; then
        echo "warning: hook.inline_budget_tokens=$cfg_budget below minimum 200, clamping" >&2
        budget=200
      elif [[ "$cfg_budget" -gt 1500 ]] 2>/dev/null; then
        echo "warning: hook.inline_budget_tokens=$cfg_budget above maximum 1500, clamping" >&2
        budget=1500
      else
        budget="$cfg_budget"
      fi
    fi
  fi

  SHOW_SCHEMAS=false
  collect_all

  if [[ "$B_CONFIG_STATUS" == "missing" ]]; then
    echo "spec-anchor: no anchor.yaml found"
    return 0
  fi

  local output=""
  output+="Project: ${B_PROJECT_NAME} (v${B_VERSION}, mode=${B_MODE})"$'\n'

  if [[ "$B_MODE" == "full" ]] && [[ "$B_GLOBAL_STATUS" == "ok" ]] && [[ $B_GLOBAL_COUNT -gt 0 ]]; then
    output+="Coding Standards:"$'\n'
    for f in .specanchor/global/*.spec.md; do
      [[ -f "$f" ]] || continue
      local fname
      fname="$(basename "$f" .spec.md)"
      local sections
      sections="$(grep -E '^## ' "$f" 2>/dev/null | head -5 | sed 's/^## /    /')"
      if [[ -n "$sections" ]]; then
        output+="  [${fname}]: sections:"$'\n'
        output+="${sections}"$'\n'
      fi
    done
  fi

  if [[ "$B_MODE" == "full" ]] && [[ ${#B_MOD_SPECS[@]} -gt 0 ]]; then
    output+="Module Contracts: ${B_MODULE_COUNT} modules"$'\n'
    local shown=0
    for i in "${!B_MOD_SPECS[@]}"; do
      [[ $shown -ge 5 ]] && break
      output+="  - ${B_MOD_SPECS[$i]}"
      [[ -n "${B_MOD_SUMMARIES[$i]:-}" ]] && output+=" — ${B_MOD_SUMMARIES[$i]}"
      output+=$'\n'
      ((shown++))
    done
  fi

  if [[ ${#B_TASK_NAMES[@]} -gt 0 ]] && [[ "$B_TASKS_MODE" != "none" ]]; then
    output+="Active Tasks:"$'\n'
    local tb_collapsed=0
    for i in "${!B_TASK_NAMES[@]}"; do
      if [[ "$B_TASKS_MODE" == "open" ]] && task_status_is_terminal "${B_TASK_STATUSES[$i]}"; then
        tb_collapsed=$((tb_collapsed + 1))
        continue
      fi
      output+="  - ${B_TASK_NAMES[$i]} [${B_TASK_STATUSES[$i]}]"$'\n'
    done
    [[ "$B_TASKS_MODE" == "open" && $tb_collapsed -gt 0 ]] && output+="  (+${tb_collapsed} done/archived collapsed)"$'\n'
  fi

  local char_budget=$((budget * 4))
  if [[ ${#output} -gt $char_budget ]]; then
    output="${output:0:$char_budget}"
    output+=$'\n'"(truncated to ~${budget} tokens)"
  fi

  printf '%s' "$output"
}

output_full() {
  output_summary "full"

  # 额外输出 Global Spec 内容
  if [[ "$B_MODE" == "full" ]] && [[ -d ".specanchor/global" ]]; then
    echo ""
    echo -e "${BOLD}─── Global Spec Contents ───${RESET}"
    for f in .specanchor/global/*.spec.md; do
      [[ -f "$f" ]] || continue
      echo ""
      echo -e "${CYAN}=== $(basename "$f") ===${RESET}"
      cat "$f"
    done
  fi
}

output_json() {
  collect_all

  if [[ "$B_CONFIG_STATUS" == "missing" ]]; then
    echo '{"status":"error","error_code":"CONFIG_MISSING","message":"未找到配置文件"}'
    exit 1
  fi

  if [[ "$B_MODE" == "full" ]] && [[ "$B_SA_DIR" == "missing" ]]; then
    echo '{"status":"error","error_code":"FULL_MODE_SPECANCHOR_MISSING","message":"mode 为 full 但 .specanchor/ 目录不存在"}'
    exit 1
  fi

  printf '{\n'
  printf '  "status": "ok",\n'
  printf '  "config": "%s",\n' "$B_CONFIG_PATH"
  printf '  "config_display": "%s",\n' "$(sa_json_escape "$B_CONFIG_DISPLAY")"
  printf '  "version": "%s",\n' "$B_VERSION"
  printf '  "project_name": "%s",\n' "$B_PROJECT_NAME"
  printf '  "mode": "%s",\n' "$B_MODE"
  printf '  "default_schema": "%s",\n' "$B_DEFAULT_SCHEMA"

  if [[ "$B_MODE" == "full" ]]; then
    printf '  "specanchor_dir": "%s",\n' "$B_SA_DIR"
    printf '  "global_specs": {\n'
    printf '    "count": %d,\n' "$B_GLOBAL_COUNT"
    printf '    "total_lines": %d,\n' "$B_GLOBAL_LINES"
    printf '    "files": ['
    for i in "${!B_GLOBAL_NAMES[@]}"; do
      [[ $i -gt 0 ]] && printf ','
      printf '{"name":"%s","lines":%d}' "${B_GLOBAL_NAMES[$i]}" "${B_GLOBAL_LINE_COUNTS[$i]}"
    done
    printf ']\n'
    printf '  },\n'
    printf '  "module_count": %d,\n' "$B_MODULE_COUNT"
    printf '  "task_active": %d,\n' "$B_TASK_ACTIVE"
    printf '  "task_archived": %d,\n' "$B_TASK_ARCHIVED"
    printf '  "active_tasks": ['
    local _t
    for _t in "${!B_TASK_NAMES[@]}"; do
      [[ $_t -gt 0 ]] && printf ','
      printf '{"task_name":"%s","status":"%s","phase":"%s","writing_protocol":"%s","path":"%s"}' \
        "$(sa_json_escape "${B_TASK_NAMES[$_t]}")" \
        "$(sa_json_escape "${B_TASK_STATUSES[$_t]}")" \
        "$(sa_json_escape "${B_TASK_PHASES[$_t]}")" \
        "$(sa_json_escape "${B_TASK_PROTOCOLS[$_t]}")" \
        "$(sa_json_escape "${B_TASK_PATHS[$_t]}")"
    done
    printf '],\n'
    printf '  "spec_index": "%s",\n' "$B_SPEC_INDEX"
    printf '  "spec_index_path": "%s",\n' "$(sa_json_escape "$B_SPEC_INDEX_PATH")"
    printf '  "spec_index_format": "%s",\n' "$B_SPEC_INDEX_FORMAT"
    if [[ "$B_SPEC_INDEX_FORMAT" == "v3" ]] || [[ "$B_SPEC_INDEX_FORMAT" == "legacy-module-v2" ]]; then
      printf '  "index_health": {"fresh":%d,"drifted":%d,"stale":%d,"outdated":%d},\n' \
        "$B_INDEX_HEALTH_FRESH" "$B_INDEX_HEALTH_DRIFTED" "$B_INDEX_HEALTH_STALE" "$B_INDEX_HEALTH_OUTDATED"
    fi
  fi

  printf '  "assembly_trace": {\n'
  if [[ "$B_MODE" == "full" ]]; then
    printf '    "global": {"mode":"summary","files":['
    for i in "${!B_GLOBAL_NAMES[@]}"; do
      [[ $i -gt 0 ]] && printf ','
      printf '"%s.spec.md"' "${B_GLOBAL_NAMES[$i]}"
    done
    printf ']},\n'
    printf '    "module": {"mode":"deferred","files":[],"note":"boot does not preload module specs"},\n'
  else
    printf '    "global": {"mode":"skipped","files":[]},\n'
    printf '    "module": {"mode":"sources-only","files":[],"note":"external specs load on demand"},\n'
  fi
  compute_landscape_readiness
  printf '    "landscape_readiness": {\n'
  printf '      "status": "%s",\n' "$B_READINESS_STATUS"
  printf '      "global_count": %d,\n' "$B_GLOBAL_COUNT"
  local module_total=$((B_INDEX_HEALTH_FRESH + B_INDEX_HEALTH_DRIFTED + B_INDEX_HEALTH_STALE + B_INDEX_HEALTH_OUTDATED))
  printf '      "module_total": %d,\n' "$module_total"
  printf '      "module_fresh": %d,\n' "$B_INDEX_HEALTH_FRESH"
  printf '      "module_drifted": %d,\n' "$B_INDEX_HEALTH_DRIFTED"
  printf '      "module_stale": %d,\n' "$B_INDEX_HEALTH_STALE"
  printf '      "module_outdated": %d,\n' "$B_INDEX_HEALTH_OUTDATED"
  printf '      "index_format": "%s",\n' "${B_SPEC_INDEX_FORMAT:-none}"
  printf '      "reasons": ['
  local r_i=0
  for r_i in "${!B_READINESS_REASONS[@]}"; do
    [[ $r_i -gt 0 ]] && printf ','
    printf '"%s"' "$(sa_json_escape "${B_READINESS_REASONS[$r_i]}")"
  done
  printf ']\n'
  printf '    }\n'
  printf '  },\n'

  printf '  "sources": ['
  for i in "${!B_SRC_PATHS[@]}"; do
    [[ $i -gt 0 ]] && printf ','
    printf '{"path":"%s","type":"%s","stale_check":"%s","frontmatter_inject":"%s","exists":"%s"}' \
      "${B_SRC_PATHS[$i]}" "${B_SRC_TYPES[$i]}" "${B_SRC_STALE[$i]}" "${B_SRC_FRONTMATTER[$i]}" "${B_SRC_EXISTS[$i]}"
  done
  printf '],\n'

  if [[ "$B_MODE" == "full" ]]; then
    printf '  "schemas": ['
    for i in "${!B_SCH_NAMES[@]}"; do
      [[ $i -gt 0 ]] && printf ','
      # JSON escape description（简化版：替换双引号）
      local escaped_desc="${B_SCH_DESCS[$i]//\"/\\\"}"
      printf '{"name":"%s","source":"%s","philosophy":"%s","description":"%s"}' \
        "${B_SCH_NAMES[$i]}" "${B_SCH_SOURCES[$i]}" "${B_SCH_PHILOSOPHIES[$i]}" "$escaped_desc"
    done
    printf ']\n'
  else
    printf '  "schemas": []\n'
  fi

  printf '}\n'
}

# ─── CLI 入口 ───

usage() {
  echo "SpecAnchor Boot - 启动检查脚本"
  echo ""
  echo "Usage:"
  echo "  specanchor-boot.sh                      # 精简摘要（默认）"
  echo "  specanchor-boot.sh --format=summary      # 同上"
  echo "  specanchor-boot.sh --with-schemas        # 默认开启；显式声明用于向后兼容"
  echo "  specanchor-boot.sh --no-schemas          # 关闭 Available Schemas（精简输出）"
  echo "  specanchor-boot.sh --tasks=open          # 折叠终态 done/archived 任务为计数（保留 draft/review/in_progress）"
  echo "                                           #   默认: summary/full=all（向后兼容），inline-brief=open"
  echo "  specanchor-boot.sh --format=full         # 含 Global Spec 内容"
  echo "  specanchor-boot.sh --format=json         # JSON 机器可读"
  echo ""
  echo "  # v0.7 新增：agent 模式——直接输出 preflight context bundle JSON v1"
  echo "  specanchor-boot.sh --agent --intent=\"add Google OAuth\""
  echo "  specanchor-boot.sh --agent --intent=\"...\" --files=src/auth/session.ts"
  echo "  specanchor-boot.sh --agent --intent=\"...\" --bundle-schema=assembly.v1  # 切回老 schema"
  echo ""
  echo "环境变量:"
  echo "  SPECANCHOR_SKILL_DIR   Skill 安装目录（用于查找内置 schemas）"
  echo "                          默认: 脚本自身上级目录"
  echo ""
  echo "示例:"
  echo "  cd /path/to/project && bash /path/to/skill/scripts/specanchor-boot.sh"
  echo "  SPECANCHOR_SKILL_DIR=/path/to/skill bash scripts/specanchor-boot.sh --format=json"
  echo ""
  echo "注意:"
  echo "  长参数必须作为单个 shell 参数传入，例如 --format=summary。"
  exit 0
}

main() {
  local format="summary"
  local tasks_mode=""   # 空 = 按 format 解析默认（inline-brief→open，其余→all）
  # v0.7 新增：agent 模式相关参数
  local agent_mode="false"
  local intent=""
  local files=""
  local bundle_schema="context_bundle.v1"

  while [[ $# -gt 0 ]]; do
    local arg="$1"
    shift
    if [[ "$arg" == "--" ]]; then
      [[ $# -gt 0 ]] || die "未知参数: -- (did you mean --format=summary?)"
      arg="--$1"
      shift
    fi
    case "$arg" in
      --format=*) format="${arg#--format=}" ;;
      --tasks=*) tasks_mode="${arg#--tasks=}" ;;
      --with-schemas) SHOW_SCHEMAS=true ;;
      --no-schemas) SHOW_SCHEMAS=false ;;
      --agent) agent_mode="true" ;;
      --intent=*) intent="${arg#--intent=}" ;;
      --intent)
        [[ $# -gt 0 ]] || die "--intent requires a value"
        intent="$1"
        shift
        ;;
      --files=*) files="${arg#--files=}" ;;
      --files)
        [[ $# -gt 0 ]] || die "--files requires a value"
        files="$1"
        shift
        ;;
      --bundle-schema=*) bundle_schema="${arg#--bundle-schema=}" ;;
      --bundle-schema)
        [[ $# -gt 0 ]] || die "--bundle-schema requires a value"
        bundle_schema="$1"
        shift
        ;;
      --help|-h) usage ;;
      *) die "未知参数: $arg" ;;
    esac
  done

  # --tasks 默认：inline-brief（hook 注入路径，~600 token）默认 open 压缩；
  # summary/full 默认 all 保持向后兼容、不改默认输出 shape。json 不受影响（机器契约全量）。
  if [[ -z "$tasks_mode" ]]; then
    if [[ "$format" == "inline-brief" ]]; then tasks_mode="open"; else tasks_mode="all"; fi
  fi
  case "$tasks_mode" in
    all|open|none|compact) B_TASKS_MODE="$tasks_mode" ;;
    *) die "未知 --tasks 值: $tasks_mode (可选: open | all | none | compact)" ;;
  esac

  # v0.7 新增：--agent --intent 模式直接产 preflight context bundle
  # 等价于 specanchor-assemble.sh --intent=... --format=json --bundle-schema=context_bundle.v1
  if [[ "$agent_mode" == "true" ]]; then
    [[ -n "$intent" ]] || die "--agent 模式要求 --intent=\"<task intent>\""
    local assemble_cmd=(bash "$SCRIPT_DIR/specanchor-assemble.sh"
      "--intent=$intent"
      "--format=json"
      "--bundle-schema=$bundle_schema")
    [[ -n "$files" ]] && assemble_cmd+=("--files=$files")
    exec "${assemble_cmd[@]}"
  fi

  case "$format" in
    summary)      output_summary ;;
    full)         output_full ;;
    json)         output_json ;;
    inline-brief) output_inline_brief ;;
    *)            die "未知格式: $format (可选: summary | full | json | inline-brief)" ;;
  esac
}

main "$@"
