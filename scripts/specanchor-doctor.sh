#!/usr/bin/env bash
# SpecAnchor Doctor - read-only health and release checks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

FORMAT="text"
STRICT_MODE="false"
PROFILE="default"
ALLOW_DIRTY="false"

declare -a BLOCKING_ISSUES=()
declare -a WARNING_ISSUES=()
declare -a SUGGESTED_FIXES=()

CHECK_ANCHOR_YAML=false
CHECK_SPECANCHOR_DIR=false
CHECK_GLOBAL_SPECS=false
CHECK_SPEC_INDEX=false
CHECK_SOURCES=false
CHECK_FRONTMATTER=false
CHECK_COVERAGE=false
CHECK_SCRIPTS=false
CHECK_PROFILE=false

CONFIG_PATH=""
CONFIG_DISPLAY="missing"
MODE="unknown"
GLOBAL_SPECS_DIR=".specanchor/global"
SPEC_INDEX_PATH=".specanchor/spec-index.md"
PROJECT_CODEMAP_PATH=".specanchor/project-codemap.md"

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

check_frontmatter_file() {
  local file="$1"
  if ! grep -q '^specanchor:' "$file" 2>/dev/null; then
    add_warning "FRONTMATTER_MISSING" "${file} 缺少 specanchor frontmatter" "给 ${file} 注入 specanchor frontmatter。"
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

check_local_markdown_links() {
  local file="$1"
  command -v python3 >/dev/null 2>&1 || return 0
  local result=""
  result=$(python3 - "$file" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)', text):
    target = target.strip().strip('<>')
    if not target or target.startswith('#') or '://' in target or target.startswith('mailto:'):
        continue
    target = target.split('#', 1)[0].split('?', 1)[0]
    candidate = (path.parent / target).resolve()
    if not candidate.exists():
        print(target)
PY
)
  if [[ -n "$result" ]]; then
    while IFS= read -r target; do
      [[ -n "$target" ]] || continue
      add_blocking "DOC_LINK_MISSING" "${file} 引用了不存在的本地链接: ${target}" "修复 ${file} 中的链接 ${target}。"
    done <<< "$result"
  fi
}

check_json_smoke() {
  local label="$1"
  shift
  command -v python3 >/dev/null 2>&1 || {
    add_blocking "PYTHON3_MISSING" "python3 不可用，无法验证 ${label} JSON 输出" "安装 Python 3。"
    return 0
  }

  local tmp
  tmp=$(mktemp)
  if "$@" >"$tmp" 2>/dev/null && python3 -m json.tool "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    return 0
  fi
  rm -f "$tmp"
  add_blocking "JSON_SMOKE_FAILED" "${label} 未输出合法 JSON" "修复 ${label} 的 JSON 输出。"
}

check_spec_index_fresh() {
  [[ -f "$SPEC_INDEX_PATH" ]] || {
    add_blocking "SPEC_INDEX_MISSING" "maintainer profile requires spec-index." "运行 bash scripts/specanchor-index.sh。"
    return 0
  }

  local generated_at generated_date latest_synced latest_epoch generated_epoch
  generated_at=$(sa_parse_yaml_field "$SPEC_INDEX_PATH" "generated_at" "")
  generated_date="${generated_at%%T*}"
  generated_epoch=$(sa_date_to_epoch "$generated_date")
  latest_synced=""
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    local synced
    synced=$(sa_parse_frontmatter_field "$file" "last_synced")
    if [[ -n "$synced" ]] && { [[ -z "$latest_synced" ]] || [[ "$synced" > "$latest_synced" ]]; }; then
      latest_synced="$synced"
    fi
  done < <(find .specanchor/modules -maxdepth 1 -name "*.spec.md" 2>/dev/null | sort)

  if [[ -n "$latest_synced" ]]; then
    latest_epoch=$(sa_date_to_epoch "$latest_synced")
    if [[ -n "$generated_epoch" ]] && [[ -n "$latest_epoch" ]] && (( generated_epoch < latest_epoch )); then
      add_warning "SPEC_INDEX_STALE" "spec-index 比最新 Module Spec 更旧。" "重新生成 spec-index。"
    fi
  fi
}

check_project_codemap_paths() {
  [[ -f "$PROJECT_CODEMAP_PATH" ]] || {
    add_warning "CODEMAP_MISSING" "project-codemap 不存在。" "恢复 .specanchor/project-codemap.md。"
    return 0
  }
  command -v python3 >/dev/null 2>&1 || return 0

  local result=""
  result=$(python3 - "$PROJECT_CODEMAP_PATH" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
targets = set(re.findall(r'`([^`]+)`', text))
for target in sorted(targets):
    if target.startswith("references/agents/*.md"):
        continue
    if "/" not in target and "." not in target:
        continue
    if "*" in target:
        continue
    candidate = (path.parent.parent / target).resolve()
    if not candidate.exists():
        print(target)
PY
)
  if [[ -n "$result" ]]; then
    while IFS= read -r target; do
      [[ -n "$target" ]] || continue
      add_warning "CODEMAP_PATH_MISSING" "project-codemap 引用了不存在的路径: ${target}" "修复 codemap 中的路径引用。"
    done <<< "$result"
  fi
}

run_base_checks() {
  CHECK_ANCHOR_YAML=true
  if ! CONFIG_PATH=$(sa_find_config); then
    add_blocking "CONFIG_MISSING" "未找到 anchor.yaml 或 .specanchor/config.yaml" "创建 anchor.yaml，或恢复 legacy .specanchor/config.yaml。"
    return
  fi
  CONFIG_DISPLAY=$(sa_config_label "$CONFIG_PATH")

  if [[ "$CONFIG_PATH" == ".specanchor/config.yaml" ]]; then
    add_warning "CONFIG_LEGACY" "检测到 legacy 配置 .specanchor/config.yaml" "迁移到仓库根目录 anchor.yaml。"
  fi
  if ! grep -q '^specanchor:' "$CONFIG_PATH" 2>/dev/null; then
    add_blocking "CONFIG_INVALID" "${CONFIG_PATH} 缺少 specanchor 根节点" "补齐 ${CONFIG_PATH} 中的 specanchor: 根节点。"
    return
  fi

  local overlay_config=""
  overlay_config=$(sa_find_overlay_config "$CONFIG_PATH" 2>/dev/null || true)
  if [[ -n "$overlay_config" ]] && ! grep -q '^specanchor:' "$overlay_config" 2>/dev/null; then
    add_blocking "CONFIG_OVERLAY_INVALID" "${overlay_config} 缺少 specanchor 根节点" "补齐 ${overlay_config} 中的 specanchor: 根节点。"
    return
  fi

  MODE=$(sa_parse_config_field "$CONFIG_PATH" "mode" "full")
  if [[ "$MODE" != "full" ]] && [[ "$MODE" != "parasitic" ]]; then
    add_blocking "CONFIG_INVALID" "mode 必须是 full 或 parasitic，当前为 ${MODE}" "将 mode 修正为 full 或 parasitic。"
  fi

  GLOBAL_SPECS_DIR=$(sa_parse_config_field "$CONFIG_PATH" "global_specs" ".specanchor/global/")
  SPEC_INDEX_PATH=$(sa_spec_index_path "$CONFIG_PATH")
  PROJECT_CODEMAP_PATH=$(sa_parse_config_field "$CONFIG_PATH" "project_codemap" ".specanchor/project-codemap.md")

  CHECK_SPECANCHOR_DIR=true
  if [[ "$MODE" == "full" ]]; then
    if [[ ! -d ".specanchor" ]]; then
      add_blocking "FULL_MODE_SPECANCHOR_MISSING" "mode=full 但 .specanchor/ 不存在" "恢复 .specanchor/，或将 mode 改为 parasitic。"
    fi
    if [[ ! -d "$GLOBAL_SPECS_DIR" ]]; then
      add_blocking "GLOBAL_SPECS_MISSING" "full 模式下缺少 Global Spec 目录: ${GLOBAL_SPECS_DIR}" "创建 ${GLOBAL_SPECS_DIR} 并提交基础 Global Specs。"
    fi
  fi

  CHECK_GLOBAL_SPECS=true
  if [[ -d "$GLOBAL_SPECS_DIR" ]]; then
    local total_lines=0 spec_count=0 spec_file=""
    for spec_file in "$GLOBAL_SPECS_DIR"/*.spec.md; do
      [[ -f "$spec_file" ]] || continue
      spec_count=$((spec_count + 1))
      total_lines=$((total_lines + $(sa_file_line_count "$spec_file")))
      check_frontmatter_file "$spec_file"
    done
    if [[ "$spec_count" -eq 0 ]]; then
      add_warning "GLOBAL_SPECS_EMPTY" "${GLOBAL_SPECS_DIR} 中没有 Global Spec" "补齐最小可用的 Global Spec 基线。"
    fi
    if [[ "$total_lines" -gt 200 ]]; then
      add_warning "GLOBAL_SPEC_OVER_BUDGET" "Global Specs 总行数 ${total_lines} 超过 200 行" "压缩 .specanchor/global/ 下的 Spec 体积。"
    fi
  fi

  CHECK_SPEC_INDEX=true
  if [[ "$MODE" == "full" ]]; then
    local loaded_index=""
    loaded_index=$(sa_load_spec_index_or_legacy "$CONFIG_PATH" 2>/dev/null || true)
    if [[ -z "$loaded_index" ]]; then
      add_warning "SPEC_INDEX_MISSING" "未找到 spec-index: ${SPEC_INDEX_PATH}" "运行 bash scripts/specanchor-index.sh 重新生成 spec-index。"
    elif [[ "$(sa_index_type "$loaded_index")" != "spec-index" ]]; then
      add_warning "SPEC_INDEX_LEGACY_FALLBACK" "当前仍在使用 legacy module-index fallback: ${loaded_index}" "运行 bash scripts/specanchor-index.sh 迁移到 spec-index。"
    fi
  fi

  CHECK_SOURCES=true
  local source_path=""
  while IFS=$'\t' read -r source_path _rest; do
    [[ -n "$source_path" ]] || continue
    if [[ ! -d "$source_path" ]]; then
      add_warning "SOURCE_MISSING" "source 路径不存在: ${source_path}" "创建 ${source_path}，或从 anchor.yaml 中移除该 source。"
    fi
  done < <(sa_iter_config_sources "$CONFIG_PATH")

  CHECK_FRONTMATTER=true
  local module_file=""
  if [[ -d ".specanchor/modules" ]]; then
    for module_file in .specanchor/modules/*.spec.md; do
      [[ -f "$module_file" ]] || continue
      check_frontmatter_file "$module_file"
    done
  fi

  CHECK_COVERAGE=true
  if sa_config_list_contains "$CONFIG_PATH" "coverage" "ignore_paths" "*.md"; then
    add_warning "COVERAGE_MARKDOWN_IGNORED" "coverage.ignore_paths 全局忽略了 *.md" "移除全局 *.md 忽略，改为精确忽略 template 或历史文档。"
  fi

  CHECK_SCRIPTS=true
  local required_script=""
  for required_script in \
    "$SKILL_ROOT/scripts/specanchor-boot.sh" \
    "$SKILL_ROOT/scripts/specanchor-resolve.sh" \
    "$SKILL_ROOT/scripts/specanchor-assemble.sh" \
    "$SKILL_ROOT/scripts/specanchor-validate.sh"; do
    if [[ ! -r "$required_script" ]]; then
      add_blocking "SCRIPT_UNREADABLE" "脚本不可读或缺失: ${required_script}" "恢复 ${required_script}。"
    fi
  done

  local schema_count=0
  schema_count=$(find "${SKILL_ROOT}/references/schemas" -mindepth 2 -maxdepth 2 -name "schema.yaml" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$schema_count" -eq 0 ]]; then
    add_blocking "SCHEMA_MISSING" "references/schemas 下未发现 schema.yaml" "恢复 references/schemas/*/schema.yaml。"
  fi
}

run_agent_profile_checks() {
  CHECK_PROFILE=true
  [[ -f "$SKILL_ROOT/references/assembly-trace.md" ]] || add_blocking "ASSEMBLY_TRACE_REF_MISSING" "缺少 references/assembly-trace.md" "恢复 Assembly Trace 协议文档。"
  [[ -n "$(sa_load_spec_index_or_legacy "$CONFIG_PATH" 2>/dev/null || true)" ]] || add_blocking "SPEC_INDEX_REQUIRED" "agent profile 要求可读的 spec-index。" "恢复或生成 spec-index。"

  local ref
  while IFS= read -r ref; do
    [[ -n "$ref" ]] || continue
    [[ -f "$SKILL_ROOT/$ref" ]] || add_blocking "SKILL_REF_MISSING" "SKILL.md 引用了不存在的 reference: ${ref}" "修复 SKILL.md 中的 reference 链接。"
  done < <(grep -o 'references/[A-Za-z0-9._/-]*\.md' "$SKILL_ROOT/SKILL.md" | sort -u)

  local source_path=""
  while IFS=$'\t' read -r source_path _rest; do
    [[ -n "$source_path" ]] || continue
    [[ -d "$source_path" ]] || add_blocking "SOURCE_REQUIRED" "agent profile 发现缺失 source: ${source_path}" "恢复 source 或从配置移除。"
  done < <(sa_iter_config_sources "$CONFIG_PATH")

  check_json_smoke "resolve" bash "$SKILL_ROOT/scripts/specanchor-resolve.sh" --files "anchor.yaml" --intent "doctor runtime smoke" --budget=normal --format=json
  check_json_smoke "assemble" bash "$SKILL_ROOT/scripts/specanchor-assemble.sh" --files "anchor.yaml" --intent "doctor runtime smoke" --budget=normal --format=json
}

run_release_profile_checks() {
  CHECK_PROFILE=true
  check_local_markdown_links "$SKILL_ROOT/README.md"
  check_local_markdown_links "$SKILL_ROOT/README_ZH.md"

  local current_version release_tag release_note_path
  current_version=$(sa_parse_config_field "$CONFIG_PATH" "version" "")
  if [[ -z "$current_version" ]]; then
    add_blocking "CONFIG_VERSION_MISSING" "anchor.yaml 缺少 version。" "补充当前发布版本号。"
  else
    release_tag="v${current_version}"
    release_note_path="$SKILL_ROOT/docs/release/${release_tag}.md"
    grep -Fq "## ${release_tag}" "$SKILL_ROOT/CHANGELOG.md" 2>/dev/null || add_blocking "CHANGELOG_RELEASE_MISSING" "CHANGELOG 缺少当前发布 section: ${release_tag}" "补充 ${release_tag} 的 changelog section。"
    [[ -f "$release_note_path" ]] || add_blocking "RELEASE_NOTE_MISSING" "缺少 ${release_note_path#$SKILL_ROOT/}" "补充 ${release_tag} release note。"
  fi
  [[ -f "$SKILL_ROOT/.github/workflows/ci.yml" ]] || add_blocking "CI_MISSING" "缺少 .github/workflows/ci.yml" "恢复 CI workflow。"
  [[ -f "$SKILL_ROOT/.github/settings.yml" ]] || add_warning "ABOUT_METADATA_MISSING" "缺少 .github/settings.yml" "补充 About metadata 文件。"
  [[ -f "$SKILL_ROOT/.skillexclude" ]] || add_blocking "SKILLEXCLUDE_MISSING" "缺少 .skillexclude" "恢复 .skillexclude。"

  if [[ -f "$SKILL_ROOT/.skillexclude" ]]; then
    grep -Eq '^\.github/?$' "$SKILL_ROOT/.skillexclude" 2>/dev/null || add_warning "SKILLEXCLUDE_GITHUB" ".skillexclude 未排除 .github" "将 .github 加入 .skillexclude。"
    grep -Eq '^tests/?$' "$SKILL_ROOT/.skillexclude" 2>/dev/null || add_warning "SKILLEXCLUDE_TESTS" ".skillexclude 未排除 tests" "将 tests 加入 .skillexclude。"
    grep -Eq '^\.specanchor/?$' "$SKILL_ROOT/.skillexclude" 2>/dev/null || add_warning "SKILLEXCLUDE_SPECANCHOR" ".skillexclude 未排除 .specanchor" "将 .specanchor 加入 .skillexclude。"
  fi
}

run_maintainer_profile_checks() {
  CHECK_PROFILE=true
  if [[ "$ALLOW_DIRTY" != "true" ]] && [[ -n "$(git status --short 2>/dev/null || true)" ]]; then
    add_blocking "WORKTREE_DIRTY" "maintainer profile 要求干净工作树。" "提交、stash，或改用 --allow-dirty。"
  fi
  check_spec_index_fresh
  check_project_codemap_paths
  [[ -d "$SKILL_ROOT/tests/fixtures/agent-reliability" ]] || add_warning "FIXTURES_MISSING" "缺少 tests/fixtures/agent-reliability" "补充 beta 可靠性 fixtures。"
}

print_text() {
  local status
  status=$(doctor_status)

  echo -e "${BOLD}SpecAnchor Doctor [${status}]${RESET}"
  echo "  Mode: ${MODE}"
  echo "  Config: ${CONFIG_DISPLAY}"
  echo "  Profile: ${PROFILE}"

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

print_markdown() {
  local status
  status=$(doctor_status)
  echo "# SpecAnchor Doctor"
  echo ""
  echo "Status: ${status}"
  echo "Profile: ${PROFILE}"
  echo "Mode: ${MODE}"
  echo "Config: ${CONFIG_DISPLAY}"
  if [[ ${#BLOCKING_ISSUES[@]} -gt 0 ]]; then
    echo ""
    echo "## Blocking"
    local item=""
    for item in "${BLOCKING_ISSUES[@]}"; do
      echo "- ${item}"
    done
  fi
  if [[ ${#WARNING_ISSUES[@]} -gt 0 ]]; then
    echo ""
    echo "## Warnings"
    local item=""
    for item in "${WARNING_ISSUES[@]}"; do
      echo "- ${item}"
    done
  fi
}

print_json_array() {
  local array_name="$1"
  local count
  count=$(eval "printf '%s' \${#$array_name[@]}")
  printf '['
  if [[ "$count" -gt 0 ]]; then
    local i=0 value=""
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
  printf '  "profile": "%s",\n' "$PROFILE"
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
  printf '    "spec_index": %s,\n' "$CHECK_SPEC_INDEX"
  printf '    "sources": %s,\n' "$CHECK_SOURCES"
  printf '    "frontmatter": %s,\n' "$CHECK_FRONTMATTER"
  printf '    "coverage": %s,\n' "$CHECK_COVERAGE"
  printf '    "scripts": %s,\n' "$CHECK_SCRIPTS"
  printf '    "profile": %s\n' "$CHECK_PROFILE"
  printf '  }\n'
  printf '}\n'
}

usage() {
  cat <<'EOF'
Usage:
  bash scripts/specanchor-doctor.sh
  bash scripts/specanchor-doctor.sh --format=text
  bash scripts/specanchor-doctor.sh --format=json
  bash scripts/specanchor-doctor.sh --format=markdown --profile=release
  bash scripts/specanchor-doctor.sh --strict --profile=agent
  bash scripts/specanchor-doctor.sh --profile=maintainer --allow-dirty
EOF
  exit 0
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format=text) FORMAT="text" ;;
      --format=json) FORMAT="json" ;;
      --format=markdown) FORMAT="markdown" ;;
      --format)
        shift
        [[ $# -gt 0 ]] || sa_die "--format requires a value" 64
        FORMAT="$1"
        ;;
      --strict) STRICT_MODE="true" ;;
      --profile=*) PROFILE="${1#--profile=}" ;;
      --profile)
        shift
        [[ $# -gt 0 ]] || sa_die "--profile requires a value" 64
        PROFILE="$1"
        ;;
      --allow-dirty) ALLOW_DIRTY="true" ;;
      --help|-h) usage ;;
      *) sa_die "invalid argument: $1" 64 ;;
    esac
    shift
  done

  case "$PROFILE" in
    default|agent|release|maintainer) ;;
    *) sa_die "invalid profile: ${PROFILE}" 64 ;;
  esac

  run_base_checks
  case "$PROFILE" in
    agent) run_agent_profile_checks ;;
    release) run_release_profile_checks ;;
    maintainer)
      run_release_profile_checks
      run_maintainer_profile_checks
      ;;
  esac

  case "$FORMAT" in
    text) print_text ;;
    json) print_json ;;
    markdown) print_markdown ;;
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
