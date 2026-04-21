#!/usr/bin/env bash
# SpecAnchor Doctor - 只读健康检查

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

FORMAT="text"
STRICT_MODE="false"

declare -a BLOCKING_ISSUES=()
declare -a WARNING_ISSUES=()
declare -a SUGGESTED_FIXES=()

CHECK_ANCHOR_YAML=false
CHECK_SPECANCHOR_DIR=false
CHECK_GLOBAL_SPECS=false
CHECK_MODULE_INDEX=false
CHECK_SOURCES=false
CHECK_FRONTMATTER=false
CHECK_COVERAGE=false
CHECK_SCRIPTS=false

CONFIG_PATH=""
MODE="unknown"
GLOBAL_SPECS_DIR=".specanchor/global"
MODULE_INDEX_PATH=".specanchor/module-index.md"

add_blocking() {
  local code="$1"
  local message="$2"
  local fix="${3:-}"
  BLOCKING_ISSUES+=("${code}: ${message}")
  if [[ -n "$fix" ]]; then
    SUGGESTED_FIXES+=("$fix")
  fi
}

add_warning() {
  local code="$1"
  local message="$2"
  local fix="${3:-}"
  WARNING_ISSUES+=("${code}: ${message}")
  if [[ -n "$fix" ]]; then
    SUGGESTED_FIXES+=("$fix")
  fi
}

parse_sources() {
  local config="$1"
  local in_sources=0
  local current_path=""

  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]{2}sources: ]]; then
      in_sources=1
      continue
    fi

    if [[ $in_sources -eq 1 ]] && [[ "$line" =~ ^[[:space:]]{2}[A-Za-z0-9_-]+: ]] && [[ ! "$line" =~ ^[[:space:]]{4} ]]; then
      break
    fi

    if [[ $in_sources -eq 0 ]]; then
      continue
    fi

    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*path:[[:space:]]*\"?([^\"]+)\"? ]]; then
      current_path="${BASH_REMATCH[1]}"
      printf '%s\n' "$current_path"
    fi
  done < "$config"
}

check_frontmatter_file() {
  local file="$1"
  if ! grep -q '^specanchor:' "$file" 2>/dev/null; then
    add_warning "FRONTMATTER_MISSING" "${file} 缺少 specanchor frontmatter" \
      "给 ${file} 注入 specanchor frontmatter。"
  fi
}

run_checks() {
  CHECK_ANCHOR_YAML=true
  if ! CONFIG_PATH=$(sa_find_config); then
    add_blocking "CONFIG_MISSING" "未找到 anchor.yaml 或 .specanchor/config.yaml" \
      "创建 anchor.yaml，或恢复 legacy .specanchor/config.yaml。"
    return
  fi

  if [[ "$CONFIG_PATH" == ".specanchor/config.yaml" ]]; then
    add_warning "CONFIG_LEGACY" "检测到 legacy 配置 .specanchor/config.yaml" \
      "迁移到仓库根目录 anchor.yaml。"
  fi

  if ! grep -q '^specanchor:' "$CONFIG_PATH" 2>/dev/null; then
    add_blocking "CONFIG_INVALID" "${CONFIG_PATH} 缺少 specanchor 根节点" \
      "补齐 ${CONFIG_PATH} 中的 specanchor: 根节点。"
    return
  fi

  MODE=$(sa_parse_yaml_field "$CONFIG_PATH" "mode" "full")
  if [[ -z "$MODE" ]]; then
    MODE="full"
  fi
  if [[ "$MODE" != "full" ]] && [[ "$MODE" != "parasitic" ]]; then
    add_blocking "CONFIG_INVALID" "mode 必须是 full 或 parasitic，当前为 ${MODE}" \
      "将 anchor.yaml 中的 mode 修正为 full 或 parasitic。"
  fi

  GLOBAL_SPECS_DIR=$(sa_parse_yaml_field "$CONFIG_PATH" "global_specs" ".specanchor/global/")
  MODULE_INDEX_PATH=$(sa_parse_yaml_field "$CONFIG_PATH" "module_index" ".specanchor/module-index.md")

  CHECK_SPECANCHOR_DIR=true
  if [[ "$MODE" == "full" ]]; then
    if [[ ! -d ".specanchor" ]]; then
      add_blocking "FULL_MODE_SPECANCHOR_MISSING" "mode=full 但 .specanchor/ 不存在" \
        "恢复仓库内的 .specanchor/，或将 mode 改为 parasitic。"
    fi
    if [[ ! -d "$GLOBAL_SPECS_DIR" ]]; then
      add_blocking "GLOBAL_SPECS_MISSING" "full 模式下缺少 Global Spec 目录: ${GLOBAL_SPECS_DIR}" \
        "创建 ${GLOBAL_SPECS_DIR} 并提交基础 Global Specs。"
    fi
  fi

  CHECK_GLOBAL_SPECS=true
  if [[ -d "$GLOBAL_SPECS_DIR" ]]; then
    local total_lines=0
    local spec_count=0
    local spec_file=""
    for spec_file in "$GLOBAL_SPECS_DIR"/*.spec.md; do
      [[ -f "$spec_file" ]] || continue
      spec_count=$((spec_count + 1))
      total_lines=$((total_lines + $(wc -l < "$spec_file" | tr -d ' ')))
      check_frontmatter_file "$spec_file"
    done
    if [[ $spec_count -eq 0 ]]; then
      add_warning "GLOBAL_SPECS_EMPTY" "${GLOBAL_SPECS_DIR} 中没有 Global Spec" \
        "补齐最小可用的 Global Spec 基线。"
    fi
    if [[ $total_lines -gt 200 ]]; then
      add_warning "GLOBAL_SPEC_OVER_BUDGET" "Global Specs 总行数 ${total_lines} 超过 200 行" \
        "压缩 .specanchor/global/ 下的 Spec 体积。"
    fi
  fi

  CHECK_MODULE_INDEX=true
  if [[ "$MODE" == "full" ]] && [[ ! -f "$MODULE_INDEX_PATH" ]]; then
    add_warning "MODULE_INDEX_MISSING" "未找到 module-index: ${MODULE_INDEX_PATH}" \
      "运行 bash scripts/specanchor-index.sh 重新生成 module-index。"
  fi

  CHECK_SOURCES=true
  local source_path=""
  while IFS= read -r source_path; do
    [[ -n "$source_path" ]] || continue
    if [[ ! -d "$source_path" ]]; then
      add_warning "SOURCE_MISSING" "source 路径不存在: ${source_path}" \
        "创建 ${source_path}，或从 anchor.yaml 中移除该 source。"
    fi
  done < <(parse_sources "$CONFIG_PATH")

  CHECK_FRONTMATTER=true
  local module_file=""
  if [[ -d ".specanchor/modules" ]]; then
    for module_file in .specanchor/modules/*.spec.md; do
      [[ -f "$module_file" ]] || continue
      check_frontmatter_file "$module_file"
    done
  fi

  CHECK_COVERAGE=true
  if grep -Eq '^[[:space:]]*-[[:space:]]*["'"'"']?\*\.md["'"'"']?[[:space:]]*$' "$CONFIG_PATH"; then
    add_warning "COVERAGE_MARKDOWN_IGNORED" "coverage.ignore_paths 全局忽略了 *.md" \
      "移除全局 *.md 忽略，改为精确忽略 template 或历史文档。"
  fi

  if grep -q '不使用 CLI 风格的命令前缀' "${SKILL_ROOT}/references/commands-quickref.md" 2>/dev/null; then
    add_warning "COMMAND_SEMANTICS_CONFLICT" "commands-quickref 仍保留旧的命令前缀口径" \
      "将 quickref 与 SKILL.md 统一为“自然语言优先，SA: 仅可选 shorthand”。"
  fi

  CHECK_SCRIPTS=true
  local script_file=""
  for script_file in "${SKILL_ROOT}"/scripts/*.sh; do
    [[ -e "$script_file" ]] || continue
    if [[ ! -r "$script_file" ]]; then
      add_blocking "SCRIPT_UNREADABLE" "脚本不可读: ${script_file}" \
        "修正 ${script_file} 的权限。"
    fi
  done

  local schema_count=0
  schema_count=$(find "${SKILL_ROOT}/references/schemas" -mindepth 2 -maxdepth 2 -name "schema.yaml" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$schema_count" -eq 0 ]]; then
    add_blocking "SCHEMA_MISSING" "references/schemas 下未发现 schema.yaml" \
      "恢复 references/schemas/*/schema.yaml。"
  fi
}

doctor_status() {
  if [[ ${#BLOCKING_ISSUES[@]} -gt 0 ]]; then
    printf 'error\n'
  elif [[ ${#WARNING_ISSUES[@]} -gt 0 ]]; then
    printf 'warning\n'
  else
    printf 'ok\n'
  fi
}

print_text() {
  local status
  status=$(doctor_status)

  echo -e "${BOLD}SpecAnchor Doctor [${status}]${RESET}"
  echo "  Mode: ${MODE}"
  echo "  Config: ${CONFIG_PATH:-missing}"

  if [[ ${#BLOCKING_ISSUES[@]} -gt 0 ]]; then
    echo ""
    echo "Blocking:"
    local item=""
    for item in "${BLOCKING_ISSUES[@]}"; do
      echo "  - ${item}"
    done
  fi

  if [[ ${#WARNING_ISSUES[@]} -gt 0 ]]; then
    echo ""
    echo "Warnings:"
    local item=""
    for item in "${WARNING_ISSUES[@]}"; do
      echo "  - ${item}"
    done
  fi

  if [[ ${#SUGGESTED_FIXES[@]} -gt 0 ]]; then
    echo ""
    echo "Suggested fixes:"
    local fix=""
    for fix in "${SUGGESTED_FIXES[@]}"; do
      echo "  - ${fix}"
    done
  fi
}

print_json_array() {
  local array_name="$1"
  local count
  count=$(eval "printf '%s' \${#$array_name[@]}")
  printf '['
  if [[ "$count" -gt 0 ]]; then
    local i=0
    local value=""
    while [[ $i -lt $count ]]; do
      value=$(eval "printf '%s' \"\${$array_name[$i]}\"")
      [[ $i -gt 0 ]] && printf ','
      printf '"%s"' "$(sa_json_escape "$value")"
      i=$((i + 1))
    done
  fi
  printf ']'
}

print_json() {
  local status
  status=$(doctor_status)

  printf '{\n'
  printf '  "status": "%s",\n' "$status"
  printf '  "mode": "%s",\n' "$MODE"
  printf '  "blocking": '
  print_json_array BLOCKING_ISSUES
  printf ',\n'
  printf '  "warnings": '
  print_json_array WARNING_ISSUES
  printf ',\n'
  printf '  "suggested_fixes": '
  print_json_array SUGGESTED_FIXES
  printf ',\n'
  printf '  "checked": {\n'
  printf '    "anchor_yaml": %s,\n' "$CHECK_ANCHOR_YAML"
  printf '    "specanchor_dir": %s,\n' "$CHECK_SPECANCHOR_DIR"
  printf '    "global_specs": %s,\n' "$CHECK_GLOBAL_SPECS"
  printf '    "module_index": %s,\n' "$CHECK_MODULE_INDEX"
  printf '    "sources": %s,\n' "$CHECK_SOURCES"
  printf '    "frontmatter": %s,\n' "$CHECK_FRONTMATTER"
  printf '    "coverage": %s,\n' "$CHECK_COVERAGE"
  printf '    "scripts": %s\n' "$CHECK_SCRIPTS"
  printf '  }\n'
  printf '}\n'
}

usage() {
  cat <<'EOF'
Usage:
  bash scripts/specanchor-doctor.sh
  bash scripts/specanchor-doctor.sh --format=text
  bash scripts/specanchor-doctor.sh --format=json
  bash scripts/specanchor-doctor.sh --strict
EOF
  exit 0
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format=text) FORMAT="text" ;;
      --format=json) FORMAT="json" ;;
      --format)
        shift
        [[ $# -gt 0 ]] || sa_die "--format requires a value" 64
        FORMAT="$1"
        ;;
      --strict) STRICT_MODE="true" ;;
      --help|-h) usage ;;
      *) sa_die "invalid argument: $1" 64 ;;
    esac
    shift
  done

  run_checks

  case "$FORMAT" in
    text) print_text ;;
    json) print_json ;;
    *) sa_die "invalid format: ${FORMAT}" 64 ;;
  esac

  if [[ ${#BLOCKING_ISSUES[@]} -gt 0 ]]; then
    exit 2
  fi
  if [[ ${#WARNING_ISSUES[@]} -gt 0 ]] && [[ "$STRICT_MODE" == "true" ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
