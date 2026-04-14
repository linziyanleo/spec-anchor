#!/usr/bin/env bash
# SpecAnchor Init - 初始化 .specanchor/ 目录结构和默认配置
#
# Usage:
#   specanchor-init.sh [--project=<name>] [--mode=full|parasitic] [--scan-sources]
#
# 此脚本处理初始化中的确定性部分（目录创建、模板写入、来源检测）。
# 代码分析和 Global Spec 生成仍由 Agent 完成。

set -euo pipefail

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

create_directory_structure() {
  echo -e "${BOLD}Creating .specanchor/ directory structure...${RESET}"

  local dirs=(
    ".specanchor/global"
    ".specanchor/modules"
    ".specanchor/tasks/_cross-module"
    ".specanchor/archive"
    ".specanchor/scripts"
  )

  for dir in "${dirs[@]}"; do
    mkdir -p "$dir"
    echo -e "  ${GREEN}✓${RESET} ${dir}/"
  done
}

generate_anchor_yaml() {
  local project_name="$1"
  local mode="$2"

  echo -e "${BOLD}Generating anchor.yaml...${RESET}"

  cat > "anchor.yaml" <<YAML
specanchor:
  version: "0.4.0"
  project_name: "${project_name}"

  mode: "${mode}"

  paths:
    global_specs: ".specanchor/global/"
    module_specs: ".specanchor/modules/"
    task_specs: ".specanchor/tasks/"
    archive: ".specanchor/archive/"
    module_index: ".specanchor/module-index.md"
    project_codemap: ".specanchor/project-codemap.md"

  coverage:
    scan_paths:
      - "src/**"
    ignore_paths:
      - "src/**/*.test.*"
      - "src/**/*.spec.*"

  check:
    stale_days: 14
    outdated_days: 30
    warn_recent_commits_days: 14
    task_base_branch: "main"

  sync:
    auto_check_on_mr: true
    sprint_sync_reminder: true
YAML

  echo -e "  ${GREEN}✓${RESET} anchor.yaml"
}

generate_empty_module_index() {
  local index_file=".specanchor/module-index.md"

  if [[ -x "${SCRIPT_DIR}/specanchor-index.sh" ]]; then
    bash "${SCRIPT_DIR}/specanchor-index.sh" --config=anchor.yaml --output="$index_file"
  else
    cat > "$index_file" <<'EOF'
---
specanchor:
  type: module-index
  generated_at: ""
  module_count: 0
  covered_count: 0
  uncovered_count: 0
  health_summary:
    fresh: 0
    drifted: 0
    stale: 0
    outdated: 0

modules: []

uncovered: []
---

# Module Spec 索引

<!-- 以下由 specanchor-index.sh 从 frontmatter 自动渲染，请勿手动编辑 -->

**统计**: 0 个模块 | 0 已覆盖 | 0 未覆盖
EOF
    echo -e "  ${GREEN}✓${RESET} .specanchor/module-index.md (empty)"
  fi
}

generate_empty_codemap() {
  local codemap_file=".specanchor/project-codemap.md"
  cat > "$codemap_file" <<'EOF'
# Project Codemap

<!-- 此文件由 Agent 在需要全局视角时生成/更新。内容基于代码分析。 -->

（尚未生成。运行 `specanchor_status` 或让 Agent 扫描项目代码后自动生成。）
EOF
  echo -e "  ${GREEN}✓${RESET} .specanchor/project-codemap.md (placeholder)"
}

scan_external_sources() {
  echo -e "\n${BOLD}Scanning for existing spec systems...${RESET}"

  local -A type_registry=(
    ["openspec/"]="openspec"
    ["specs/"]="spec-kit"
    ["mydocs/specs/"]="mydocs"
    [".qoder/specs/"]="qoder"
    ["docs/specs/"]="generic"
  )

  local found=0

  for dir in "${!type_registry[@]}"; do
    if [[ -d "$dir" ]]; then
      local type="${type_registry[$dir]}"
      local count
      count=$(find "$dir" -name "*.md" -o -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
      echo -e "  ${CYAN}📂${RESET} ${dir} [${type}] — ${count} files"
      ((found++))
    fi
  done

  if [[ $found -eq 0 ]]; then
    echo -e "  ${DIM}(no existing spec systems detected)${RESET}"
  else
    echo -e "\n  ${YELLOW}ℹ️${RESET} Agent 可以将这些来源配置到 anchor.yaml 的 sources 段中"
  fi
}

main() {
  local project_name=""
  local mode="full"
  local scan_sources=false

  for arg in "$@"; do
    case "$arg" in
      --project=*) project_name="${arg#--project=}" ;;
      --mode=*)    mode="${arg#--mode=}" ;;
      --scan-sources) scan_sources=true ;;
      --help|-h)
        echo "Usage: specanchor-init.sh [--project=<name>] [--mode=full|parasitic] [--scan-sources]"
        echo ""
        echo "初始化 .specanchor/ 目录结构和默认配置。"
        echo "  --project=<name>   项目名称（默认取当前目录名）"
        echo "  --mode=<mode>      运行模式：full（默认）或 parasitic"
        echo "  --scan-sources     扫描检测已有 spec 体系"
        exit 0
        ;;
    esac
  done

  [[ -z "$project_name" ]] && project_name=$(basename "$(pwd)")
  [[ "$mode" != "full" ]] && [[ "$mode" != "parasitic" ]] && die "Invalid mode: $mode (use: full | parasitic)"

  if [[ -f "anchor.yaml" ]]; then
    die "anchor.yaml 已存在。如需重新初始化请先手动删除。"
  fi

  echo -e "${BOLD}SpecAnchor Init${RESET}"
  echo -e "  project: ${CYAN}${project_name}${RESET}"
  echo -e "  mode: ${CYAN}${mode}${RESET}"
  echo ""

  generate_anchor_yaml "$project_name" "$mode"

  if [[ "$mode" == "full" ]]; then
    create_directory_structure
    generate_empty_module_index
    generate_empty_codemap
  fi

  if [[ "$scan_sources" == true ]]; then
    scan_external_sources
  fi

  echo ""
  echo -e "${GREEN}✅ SpecAnchor 初始化完成 [${mode}]${RESET}"
  echo -e "  配置: anchor.yaml"
  [[ "$mode" == "full" ]] && echo -e "  目录: .specanchor/"
  echo ""
  echo -e "${DIM}下一步：让 Agent 扫描项目代码生成 Global Spec（运行 specanchor_global）${RESET}"
}

main "$@"
