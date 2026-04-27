#!/usr/bin/env bash
# tests/setup_helper.bash — 共享 fixture 搭建
#
# 每个 .bats 文件的 setup() 调用此文件中的函数来创建隔离的测试环境。

# 项目根目录（tests/ 的上一级）
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${PROJECT_ROOT}/scripts"

# ─── Fixture 创建 ───

# 创建一个临时 git repo 作为测试沙箱
# 设置 SANDBOX, SANDBOX_SPECANCHOR, SANDBOX_SCRIPTS 变量
create_sandbox() {
  SANDBOX="$(mktemp -d)"
  SANDBOX_SPECANCHOR="${SANDBOX}/.specanchor"
  SANDBOX_SCRIPTS="${SANDBOX}/scripts"

  # 初始化 git repo
  cd "$SANDBOX"
  git init --quiet
  git config user.name "test-user"
  git config user.email "test@example.com"

  # 创建基本 .specanchor 结构
  mkdir -p "${SANDBOX_SPECANCHOR}/global"
  mkdir -p "${SANDBOX_SPECANCHOR}/modules"
  mkdir -p "${SANDBOX_SPECANCHOR}/tasks"
  mkdir -p "${SANDBOX_SPECANCHOR}/archive"

  # 复制脚本到 sandbox
  mkdir -p "$SANDBOX_SCRIPTS"
  mkdir -p "${SANDBOX_SCRIPTS}/lib"
  cp "${SCRIPTS_DIR}/specanchor-check.sh" "${SANDBOX_SCRIPTS}/"
  cp "${SCRIPTS_DIR}/specanchor-index.sh" "${SANDBOX_SCRIPTS}/"
  cp "${SCRIPTS_DIR}/frontmatter-inject.sh" "${SANDBOX_SCRIPTS}/"
  cp "${SCRIPTS_DIR}/frontmatter-inject-and-check.sh" "${SANDBOX_SCRIPTS}/"
  cp "${SCRIPTS_DIR}/lib/common.sh" "${SANDBOX_SCRIPTS}/lib/"

  # 创建默认 anchor.yaml
  cat > "${SANDBOX}/anchor.yaml" <<'YAML'
specanchor:
  version: "0.4.0-alpha.1"
  project_name: "test-project"
  mode: "full"
  paths:
    global_specs: ".specanchor/global/"
    module_specs: ".specanchor/modules/"
    task_specs: ".specanchor/tasks/"
    archive: ".specanchor/archive/"
    spec_index: ".specanchor/spec-index.md"
    module_index: ".specanchor/module-index.md"
    project_codemap: ".specanchor/project-codemap.md"
  writing_protocol:
    schema: "sdd-riper-one"
    schema_recommend: true
  coverage:
    scan_paths:
      - "src/**"
    ignore_paths:
      - "*.md"
  check:
    stale_days: 14
    outdated_days: 30
    warn_recent_commits_days: 14
    task_base_branch: "main"
YAML

  # 初始提交
  git add -A
  git commit --quiet -m "init: sandbox"
}

# 清理沙箱
destroy_sandbox() {
  if [[ -n "${SANDBOX:-}" ]] && [[ -d "$SANDBOX" ]]; then
    rm -rf "$SANDBOX"
  fi
}

# ─── Fixture 工厂 ───

# 创建一个 Global Spec 文件
create_global_spec() {
  local type="${1:-coding-standards}"
  local file="${SANDBOX_SPECANCHOR}/global/${type}.spec.md"
  cat > "$file" <<EOF
---
specanchor:
  level: global
  type: "${type}"
  version: "1.0.0"
  author: "@test-user"
  last_synced: "2026-04-01"
---

# ${type}

Some content.
EOF
  echo "$file"
}

# 创建一个 Module Spec 文件
# Usage: create_module_spec <module_path> [last_synced]
create_module_spec() {
  local module_path="$1"
  local last_synced="${2:-2026-04-01}"
  local module_id
  module_id=$(echo "$module_path" | tr '/' '-' | sed 's/-$//')
  local file="${SANDBOX_SPECANCHOR}/modules/${module_id}.spec.md"
  cat > "$file" <<EOF
---
specanchor:
  level: module
  module_name: "${module_id}"
  module_path: "${module_path}"
  version: "1.0.0"
  owner: "@test-user"
  last_synced: "${last_synced}"
  status: active
---

# Module: ${module_path}

## 7. Code Structure
Key files:
- \`${module_path}index.ts\`
EOF

  # 创建实际的模块目录
  mkdir -p "${SANDBOX}/${module_path}"
  echo "$file"
}

# 创建一个单文件 Module Spec 文件
# Usage: create_single_file_module_spec <module_path> [last_synced]
create_single_file_module_spec() {
  local module_path="$1"
  local last_synced="${2:-2026-04-01}"
  local module_id
  module_id=$(echo "$module_path" | tr '/' '-')
  local file="${SANDBOX_SPECANCHOR}/modules/${module_id}.spec.md"
  cat > "$file" <<EOF
---
specanchor:
  level: module
  module_name: "${module_id}"
  module_path: "${module_path}"
  version: "1.0.0"
  owner: "@test-user"
  last_synced: "${last_synced}"
  status: active
---

# Module: ${module_path}

## 7. Code Structure
Key files:
- \`${module_path}\`
EOF

  mkdir -p "$(dirname "${SANDBOX}/${module_path}")"
  : > "${SANDBOX}/${module_path}"
  echo "$file"
}

# 创建一个 Task Spec 文件（含 File Changes）
# Usage: create_task_spec <name> <planned_files...>
create_task_spec() {
  local name="$1"
  shift
  local file="${SANDBOX_SPECANCHOR}/tasks/${name}.spec.md"
  cat > "$file" <<EOF
---
specanchor:
  level: task
  task_name: "${name}"
  author: "@test-user"
  created: "2026-04-01"
  status: "in_progress"
  branch: "main"
  writing_protocol: "sdd-riper-one"
  sdd_phase: "EXECUTE"
---

# SDD Spec: ${name}

## 4. Plan
### 4.1 File Changes
EOF

  for f in "$@"; do
    echo "- \`${f}\`: 变更说明" >> "$file"
  done

  cat >> "$file" <<'EOF'

## 5. Execute Log
- [ ] Step 1

## 6. Review Verdict
EOF
  echo "$file"
}

# 创建一个纯 Markdown 文件（无 frontmatter）
create_plain_md() {
  local name="${1:-plain.md}"
  local file="${SANDBOX}/${name}"
  mkdir -p "$(dirname "$file")"
  cat > "$file" <<'EOF'
# Some Title

Some content here.

- [ ] Item 1
- [x] Item 2
EOF
  echo "$file"
}

# 创建一个含非 SA frontmatter 的 Markdown 文件
create_non_sa_frontmatter_md() {
  local name="${1:-non-sa.md}"
  local file="${SANDBOX}/${name}"
  mkdir -p "$(dirname "$file")"
  cat > "$file" <<'EOF'
---
title: "Some Doc"
author: "someone"
---

# Some Title

Content.
EOF
  echo "$file"
}

# 创建一个已有 SA frontmatter 的 Markdown 文件
create_sa_frontmatter_md() {
  local name="${1:-sa-existing.md}"
  local file="${SANDBOX}/${name}"
  mkdir -p "$(dirname "$file")"
  cat > "$file" <<'EOF'
---
specanchor:
  level: task
  task_name: "existing"
  author: "@someone"
  status: "draft"
---

# Existing

Content.
EOF
  echo "$file"
}

# 在 sandbox 中模拟 git 提交
# Usage: sandbox_commit <file_path> <message>
sandbox_commit() {
  local file="$1"
  local msg="${2:-change}"
  cd "$SANDBOX"
  mkdir -p "$(dirname "$file")"
  echo "change $(date +%s)" >> "$file"
  git add "$file"
  git commit --quiet -m "$msg"
}

# 在 sandbox 中创建 feature 分支（task 检测需要 base vs HEAD diff）
# Usage: sandbox_create_branch <branch_name>
sandbox_create_branch() {
  local branch="$1"
  cd "$SANDBOX"
  git checkout --quiet -b "$branch"
}

# 创建 module-index.md（旧格式：纯 Markdown table，用于向后兼容测试）
create_module_index_legacy() {
  local file="${SANDBOX_SPECANCHOR}/module-index.md"
  cat > "$file" <<'EOF'
# Module Spec 索引

| 模块路径 | Spec 文件 | 来源 | 状态 |
| -------- | --------- | ---- | ---- |
EOF
  echo "$file"
}

# 创建 module-index.md（旧格式）— 保持向后兼容
create_module_index() {
  create_module_index_legacy "$@"
}

# 向旧格式 module-index.md 添加条目
# Usage: add_module_index_entry <module_path> <spec_file>
add_module_index_entry() {
  local module_path="$1"
  local spec_file="$2"
  local index="${SANDBOX_SPECANCHOR}/module-index.md"
  echo "| ${module_path} | ${spec_file} | native | active |" >> "$index"
}

# 创建 module-index.md（新格式：YAML frontmatter + Markdown）
# Usage: create_module_index_v2 [modules_yaml_block]
create_module_index_v2() {
  local file="${SANDBOX_SPECANCHOR}/module-index.md"
  cat > "$file" <<'EOF'
---
specanchor:
  type: module-index
  generated_at: "2026-04-14T16:00:00"
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

<!-- 以下由 specanchor_index 从 frontmatter 自动渲染 -->

**统计**: 0 个模块 | 0 已覆盖 | 0 未覆盖
EOF
  echo "$file"
}

# 创建带具体模块数据的 module-index.md（新格式）
# Usage: create_module_index_v2_with_modules
create_module_index_v2_with_modules() {
  local file="${SANDBOX_SPECANCHOR}/module-index.md"
  cat > "$file" <<'EOF'
---
specanchor:
  type: module-index
  generated_at: "2026-04-14T16:00:00"
  module_count: 2
  covered_count: 2
  uncovered_count: 0
  health_summary:
    fresh: 1
    drifted: 1
    stale: 0
    outdated: 0

modules:
  - path: "src/auth/"
    spec: "src-auth.spec.md"
    summary: "User authentication module"
    source: native
    status: active
    version: "1.0.0"
    last_synced: "2026-04-14"
    owner: "@test-user"
    health: FRESH

  - path: "src/order/"
    spec: "src-order.spec.md"
    summary: "Order management module"
    source: native
    status: active
    version: "2.0.0"
    last_synced: "2026-03-01"
    owner: "@test-user"
    health: DRIFTED

uncovered: []
---

# Module Spec 索引

<!-- 以下由 specanchor_index 从 frontmatter 自动渲染 -->

**统计**: 2 个模块 | 2 已覆盖 | 0 未覆盖

| 模块路径 | 摘要 | 状态 | 健康度 | 版本 | 最后同步 |
|----------|------|------|--------|------|---------|
| src/auth/ | User authentication module | ✅ active | 🟢 FRESH | 1.0.0 | 2026-04-14 |
| src/order/ | Order management module | ✅ active | 🟡 DRIFTED | 2.0.0 | 2026-03-01 |
EOF
  echo "$file"
}

# 创建 spec-index.md（v3 格式，含两个 Module 条目）
create_spec_index_v3_with_modules() {
  local file="${SANDBOX_SPECANCHOR}/spec-index.md"
  cat > "$file" <<'EOF'
---
specanchor:
  type: spec-index
  version: 3
  generated_at: "2026-04-27T16:00:00"
  spec_counts:
    globals: 0
    modules: 2
    tasks_active: 0
    tasks_archived: 0
  health_summary:
    globals:
      fresh: 0
      drifted: 0
      stale: 0
      outdated: 0
    modules:
      fresh: 1
      drifted: 1
      stale: 0
      outdated: 0
    tasks:
      active: 0
      archived: 0
specs:
  globals: []
  modules:
    - path: "src/auth/"
      spec: "src-auth.spec.md"
      summary: "User authentication module"
      source: "native"
      status: "active"
      version: "1.0.0"
      last_synced: "2026-04-14"
      owner: "@test-user"
      health: "FRESH"
    - path: "src/order/"
      spec: "src-order.spec.md"
      summary: "Order management module"
      source: "native"
      status: "active"
      version: "2.0.0"
      last_synced: "2026-03-01"
      owner: "@test-user"
      health: "DRIFTED"
  tasks: []
uncovered: []
---

# Spec Index

<!-- Generated by specanchor-index.sh. Do not edit by hand. -->

**Stats**: 0 globals | 2 modules | 0 active tasks | 0 archived tasks
EOF
  echo "$file"
}
