#!/usr/bin/env bash
# SpecAnchor Boot - 启动检查脚本
#
# 替代 Skill 激活时的多步 Glob/Read 操作，一次性输出结构化摘要，
# 让 Agent 直接消费结论而非逐文件扫描，节省 60-90% 启动 token。
#
# Usage:
#   specanchor-boot.sh                    # 精简摘要（默认）
#   specanchor-boot.sh --format=summary   # 同上
#   specanchor-boot.sh --format=full      # 含 Global Spec 内容
#   specanchor-boot.sh --format=json      # JSON 机器可读
#
# 配置文件查找顺序（双路径 fallback）：
#   1. 项目根目录 anchor.yaml
#   2. .specanchor/config.yaml（向后兼容）
#
# 脚本定位逻辑：
#   此脚本位于 Skill 安装目录的 scripts/ 下。运行时需要 cd 到用户项目根目录，
#   并通过 SPECANCHOR_SKILL_DIR 环境变量指定 Skill 安装目录（用于查找内置 schemas）。
#   如未设置，fallback 到脚本自身所在目录的上级目录。

set -euo pipefail

# ─── 脚本自定位 ───

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="${SPECANCHOR_SKILL_DIR:-$(dirname "$SCRIPT_DIR")}"

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
B_MODULE_INDEX=""     # ok | missing
B_MODULE_INDEX_FORMAT=""  # v2 | legacy | ""
B_INDEX_HEALTH_FRESH=0
B_INDEX_HEALTH_DRIFTED=0
B_INDEX_HEALTH_STALE=0
B_INDEX_HEALTH_OUTDATED=0

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

emit_assembly_trace() {
  local global_mode="$1"
  local i

  echo -e "  Assembly Trace:"

  if [[ "$B_MODE" == "full" ]]; then
    if [[ "$B_GLOBAL_COUNT" -gt 0 ]]; then
      local global_files=()
      for i in "${!B_GLOBAL_NAMES[@]}"; do
        global_files+=("${B_GLOBAL_NAMES[$i]}.spec.md")
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
}

# ─── 核心检查函数（直接写全局变量）───

boot_config() {
  if [[ -f "anchor.yaml" ]]; then
    B_CONFIG_PATH="anchor.yaml"
  elif [[ -f ".specanchor/config.yaml" ]]; then
    B_CONFIG_PATH=".specanchor/config.yaml"
    B_CONFIG_WARN="legacy"
  else
    B_CONFIG_STATUS="missing"
    return
  fi

  B_CONFIG_STATUS="ok"
  B_MODE=$(parse_yaml_field "$B_CONFIG_PATH" "mode" "full")
  B_PROJECT_NAME=$(parse_yaml_field "$B_CONFIG_PATH" "project_name" "unknown")
  B_VERSION=$(parse_yaml_field "$B_CONFIG_PATH" "version" "unknown")
  B_DEFAULT_SCHEMA=$(parse_yaml_field "$B_CONFIG_PATH" "schema" "sdd-riper-one")
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
  fi
  if [[ -d ".specanchor/archive" ]]; then
    B_TASK_ARCHIVED=$(find ".specanchor/archive" -name "*.spec.md" 2>/dev/null | wc -l | tr -d ' ')
  fi

  if [[ -f ".specanchor/module-index.md" ]]; then
    B_MODULE_INDEX="ok"
    local first_line
    first_line=$(head -1 ".specanchor/module-index.md")
    if [[ "$first_line" == "---" ]]; then
      local idx_type
      idx_type=$(parse_yaml_field ".specanchor/module-index.md" "type" "")
      if [[ "$idx_type" == "module-index" ]]; then
        B_MODULE_INDEX_FORMAT="v2"
        B_INDEX_HEALTH_FRESH=$(parse_yaml_field ".specanchor/module-index.md" "fresh" "0")
        B_INDEX_HEALTH_DRIFTED=$(parse_yaml_field ".specanchor/module-index.md" "drifted" "0")
        B_INDEX_HEALTH_STALE=$(parse_yaml_field ".specanchor/module-index.md" "stale" "0")
        B_INDEX_HEALTH_OUTDATED=$(parse_yaml_field ".specanchor/module-index.md" "outdated" "0")
      else
        B_MODULE_INDEX_FORMAT="legacy"
      fi
    else
      B_MODULE_INDEX_FORMAT="legacy"
    fi
  else
    B_MODULE_INDEX="missing"
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
  if ! grep -q "^  sources:" "$config" 2>/dev/null; then
    return
  fi

  local in_sources=0
  local current_path="" current_type="" stale_check="" frontmatter_inject=""

  _save_source() {
    if [[ -n "$current_path" ]]; then
      local dir_exists="no"
      [[ -d "$current_path" ]] && dir_exists="yes"
      B_SRC_PATHS+=("$current_path")
      B_SRC_TYPES+=("$current_type")
      B_SRC_STALE+=("$stale_check")
      B_SRC_FRONTMATTER+=("$frontmatter_inject")
      B_SRC_EXISTS+=("$dir_exists")
      B_SOURCES_COUNT=$((B_SOURCES_COUNT + 1))
    fi
  }

  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]{2}sources: ]]; then
      in_sources=1
      continue
    fi

    if [[ $in_sources -eq 1 ]] && [[ "$line" =~ ^[[:space:]]{2}[a-z] ]] && [[ ! "$line" =~ ^[[:space:]]{4} ]]; then
      _save_source
      in_sources=0
      continue
    fi

    if [[ $in_sources -eq 0 ]]; then continue; fi

    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*path:[[:space:]]*\"?([^\"]+)\"? ]]; then
      _save_source
      current_path="${BASH_REMATCH[1]}"
      current_type="" stale_check="" frontmatter_inject=""
      continue
    fi

    if [[ "$line" =~ type:[[:space:]]*\"?([^\"]+)\"? ]]; then
      current_type="${BASH_REMATCH[1]}"
    fi
    if [[ "$line" =~ stale_check:[[:space:]]*(true|false) ]]; then
      stale_check="${BASH_REMATCH[1]}"
    fi
    if [[ "$line" =~ frontmatter_inject:[[:space:]]*(true|false) ]]; then
      frontmatter_inject="${BASH_REMATCH[1]}"
    fi
  done < "$config"

  # 文件末尾保存最后一个 source
  if [[ $in_sources -eq 1 ]]; then
    _save_source
  fi

  unset -f _save_source
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
    boot_schemas
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
  echo -e "  Config: ${CYAN}${B_CONFIG_PATH}${RESET} (v${B_VERSION}, project: ${B_PROJECT_NAME})"
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
    if [[ "$B_MODULE_INDEX" == "ok" ]] && [[ "$B_MODULE_INDEX_FORMAT" == "v2" ]]; then
      echo -e "  Module Index: ${GREEN}v2 (structured)${RESET} — 🟢${B_INDEX_HEALTH_FRESH} 🟡${B_INDEX_HEALTH_DRIFTED} 🟠${B_INDEX_HEALTH_STALE} 🔴${B_INDEX_HEALTH_OUTDATED}"
    elif [[ "$B_MODULE_INDEX" == "ok" ]]; then
      echo -e "  Module Index: ${YELLOW}legacy (Markdown table)${RESET} — 建议运行 specanchor_index 迁移到 v2 格式"
    else
      echo -e "  ${YELLOW}⚠️ module-index.md 不存在，建议运行 specanchor_index${RESET}"
    fi
    echo -e "  Task Specs: ${B_TASK_ACTIVE} active, ${B_TASK_ARCHIVED} archived"

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

    # Schemas
    echo -e "  Available Schemas:"
    if [[ $B_SCHEMA_COUNT -gt 0 ]]; then
      for i in "${!B_SCH_NAMES[@]}"; do
        local tag=""
        [[ "${B_SCH_SOURCES[$i]}" == "custom" ]] && tag=" ${CYAN}[custom]${RESET}"
        [[ "${B_SCH_NAMES[$i]}" == "$B_DEFAULT_SCHEMA" ]] && tag="${tag} ${DIM}(default)${RESET}"
        echo -e "    ${B_SCH_NAMES[$i]}${tag} [${B_SCH_PHILOSOPHIES[$i]}]: ${B_SCH_DESCS[$i]}"
      done
    else
      echo -e "    ${DIM}(none — fallback to sdd-riper-one)${RESET}"
    fi

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
    echo '{"status":"error","message":"未找到配置文件"}'
    exit 1
  fi

  printf '{\n'
  printf '  "status": "ok",\n'
  printf '  "config": "%s",\n' "$B_CONFIG_PATH"
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
    printf '  "module_index": "%s",\n' "$B_MODULE_INDEX"
    printf '  "module_index_format": "%s",\n' "$B_MODULE_INDEX_FORMAT"
    if [[ "$B_MODULE_INDEX_FORMAT" == "v2" ]]; then
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
    printf '    "module": {"mode":"deferred","files":[],"note":"boot does not preload module specs"}\n'
  else
    printf '    "global": {"mode":"skipped","files":[]},\n'
    printf '    "module": {"mode":"sources-only","files":[],"note":"external specs load on demand"}\n'
  fi
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
  echo "  specanchor-boot.sh --format=full         # 含 Global Spec 内容"
  echo "  specanchor-boot.sh --format=json         # JSON 机器可读"
  echo ""
  echo "环境变量:"
  echo "  SPECANCHOR_SKILL_DIR   Skill 安装目录（用于查找内置 schemas）"
  echo "                          默认: 脚本自身上级目录"
  echo ""
  echo "示例:"
  echo "  cd /path/to/project && bash /path/to/skill/scripts/specanchor-boot.sh"
  echo "  SPECANCHOR_SKILL_DIR=/path/to/skill bash scripts/specanchor-boot.sh --format=json"
  exit 0
}

main() {
  local format="summary"

  for arg in "$@"; do
    case "$arg" in
      --format=*) format="${arg#--format=}" ;;
      --help|-h) usage ;;
      *) die "未知参数: $arg" ;;
    esac
  done

  case "$format" in
    summary) output_summary ;;
    full)    output_full ;;
    json)    output_json ;;
    *)       die "未知格式: $format (可选: summary | full | json)" ;;
  esac
}

main "$@"
