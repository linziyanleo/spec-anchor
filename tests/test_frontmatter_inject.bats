#!/usr/bin/env bats
# test_frontmatter_inject.bats — frontmatter-inject.sh 回归测试

setup() {
  source "${BATS_TEST_DIRNAME}/setup_helper.bash"
  create_sandbox
}

teardown() {
  destroy_sandbox
}

# ════════════════════════════════════════
# 单文件注入
# ════════════════════════════════════════

@test "inject: file without frontmatter → prepends specanchor frontmatter" {
  local file
  file=$(create_plain_md "mydocs/specs/plain.md")

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"注入 frontmatter"* ]]

  # 验证文件现在有 specanchor frontmatter
  head -1 "$file" | grep -q "^---$"
  grep -q "^specanchor:" "$file"
}

@test "inject: file with non-SA frontmatter → appends specanchor block" {
  local file
  file=$(create_non_sa_frontmatter_md "docs/non-sa.md")

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"追加 specanchor"* ]]

  # 验证原有 frontmatter 仍在，且新增了 specanchor 段
  grep -q "^title:" "$file"
  grep -q "^specanchor:" "$file"
}

@test "inject: file with SA frontmatter → skips (idempotent)" {
  local file
  file=$(create_sa_frontmatter_md "existing.md")

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"跳过"* ]]
  [[ "$output" == *"Skipped:  1"* ]]
}

@test "inject: --force on existing SA frontmatter → overwrites" {
  local file
  file=$(create_sa_frontmatter_md "force-test.md")

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"强制覆盖"* ]]
}

@test "inject: --dry-run → stdout shows frontmatter, file unchanged" {
  local file
  file=$(create_plain_md "dryrun.md")
  local before
  before=$(cat "$file")

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --dry-run --writing-protocol simple
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  [[ "$output" == *"specanchor:"* ]]

  # 文件应该不变
  local after
  after=$(cat "$file")
  [ "$before" = "$after" ]
}

@test "inject: nonexistent file → warns and counts as failed" {
  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "/nonexistent/file.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"不存在"* ]]
  [[ "$output" == *"Failed:   1"* ]]
}

# ════════════════════════════════════════
# 自动推断
# ════════════════════════════════════════

@test "detect_level: file in tasks/ → level=task" {
  local file
  file=$(create_plain_md ".specanchor/tasks/test.md")

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --dry-run --writing-protocol simple
  [ "$status" -eq 0 ]
  [[ "$output" == *"level: task"* ]]
}

@test "detect_level: file in modules/ → level=module" {
  local file
  file=$(create_plain_md ".specanchor/modules/test.md")

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --dry-run --writing-protocol simple
  [ "$status" -eq 0 ]
  [[ "$output" == *"level: module"* ]]
}

@test "detect_level: file in global/ → level=global" {
  local file
  file=$(create_plain_md ".specanchor/global/test.md")

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --dry-run --writing-protocol simple
  [ "$status" -eq 0 ]
  [[ "$output" == *"level: global"* ]]
}

@test "detect_author: in git repo → returns @username" {
  local file
  file=$(create_plain_md "test-author.md")

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --dry-run --writing-protocol simple
  [ "$status" -eq 0 ]
  [[ "$output" == *"@test-user"* ]]
}

@test "detect_status: all checkboxes done → status=done" {
  local file="${SANDBOX}/done.md"
  cat > "$file" <<'EOF'
# Done Task

- [x] Step 1
- [x] Step 2
- [x] Step 3
EOF

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --dry-run --writing-protocol simple
  [ "$status" -eq 0 ]
  [[ "$output" == *'status: "done"'* ]]
}

@test "detect_status: some checkboxes done → status=in_progress" {
  local file="${SANDBOX}/partial.md"
  cat > "$file" <<'EOF'
# Partial Task

- [x] Step 1
- [ ] Step 2
- [ ] Step 3
EOF

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --dry-run --writing-protocol simple
  [ "$status" -eq 0 ]
  [[ "$output" == *'status: "in_progress"'* ]]
}

@test "detect_status: no checkboxes → status=draft" {
  local file="${SANDBOX}/draft.md"
  cat > "$file" <<'EOF'
# Draft

Some content without checkboxes.
EOF

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'status: "draft"'* ]]
}

@test "detect_task_name: H1 title → extracts clean name" {
  local file="${SANDBOX}/named.md"
  cat > "$file" <<'EOF'
# SDD Spec: My Cool Feature

Content.
EOF

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'task_name: "My Cool Feature"'* ]]
}

# ════════════════════════════════════════
# Superpowers 格式兼容
# ════════════════════════════════════════

@test "superpowers: plan H1 → strips 'Implementation Plan' suffix" {
  local file="${SANDBOX}/docs/superpowers/plans/2026-04-02-auth-system.md"
  mkdir -p "$(dirname "$file")"
  cat > "$file" <<'EOF'
# Auth System Implementation Plan

**Goal:** Add JWT authentication
**Architecture:** Express middleware + Redis session store
**Tech Stack:** Express, jsonwebtoken, Redis

---

### Task 1: Create auth middleware

- [ ] **Step 1: Write failing test**
- [ ] **Step 2: Implement middleware**
EOF

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'task_name: "Auth System"'* ]]
}

@test "superpowers: design spec H1 → strips 'Design Spec' suffix" {
  local file="${SANDBOX}/docs/superpowers/specs/2026-04-02-auth-design.md"
  mkdir -p "$(dirname "$file")"
  cat > "$file" <<'EOF'
# Auth System Design Spec

**Goal:** Design JWT authentication flow

## Approach A
...
EOF

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'task_name: "Auth System"'* ]]
}

@test "superpowers: plan with no checked tasks → status=in_progress" {
  local file="${SANDBOX}/plan-pending.md"
  cat > "$file" <<'EOF'
# Feature Implementation Plan

**Goal:** Build feature

### Task 1: Setup
- [ ] Step 1
- [ ] Step 2

### Task 2: Implement
- [ ] Step 1
EOF

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'status: "in_progress"'* ]]
  [[ "$output" != *'sdd_phase:'* ]]
}

@test "superpowers: plan with some checked tasks → status=in_progress" {
  local file="${SANDBOX}/plan-partial.md"
  cat > "$file" <<'EOF'
# Feature Implementation Plan

**Goal:** Build feature

### Task 1: Setup
- [x] Step 1
- [x] Step 2

### Task 2: Implement
- [ ] Step 1
EOF

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'status: "in_progress"'* ]]
  [[ "$output" != *'sdd_phase:'* ]]
}

@test "superpowers: plan with all checked tasks → status=done" {
  local file="${SANDBOX}/plan-done.md"
  cat > "$file" <<'EOF'
# Feature Implementation Plan

**Goal:** Build feature

### Task 1: Setup
- [x] Step 1
- [x] Step 2

### Task 2: Implement
- [x] Step 1
EOF

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'status: "done"'* ]]
  [[ "$output" != *'sdd_phase:'* ]]
}

@test "superpowers: design spec with Goal → status=draft" {
  local file="${SANDBOX}/design-spec.md"
  cat > "$file" <<'EOF'
# Auth System Design

**Goal:** Design JWT authentication flow
**Architecture:** Middleware-based

## Options
### Option A: Session-based
### Option B: Token-based
EOF

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'status: "draft"'* ]]
  [[ "$output" != *'sdd_phase:'* ]]
}

# ════════════════════════════════════════
# 批量注入
# ════════════════════════════════════════

@test "batch: --dir with 3 files → injects all, reports summary" {
  mkdir -p "${SANDBOX}/batch"
  for i in 1 2 3; do
    cat > "${SANDBOX}/batch/file${i}.md" <<EOF
# File ${i}

Content for file ${i}.
EOF
  done

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" --dir "${SANDBOX}/batch"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Injected: 3"* ]]
}

@test "batch: --dir with 0 matching files → warns" {
  mkdir -p "${SANDBOX}/empty-dir"

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" --dir "${SANDBOX}/empty-dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"未找到匹配"* ]]
}

@test "batch: --dir mixed (some already injected) → correct skip count" {
  mkdir -p "${SANDBOX}/mixed"
  # 一个已有 SA frontmatter
  cat > "${SANDBOX}/mixed/existing.md" <<'EOF'
---
specanchor:
  level: task
  task_name: "existing"
---

# Existing
EOF
  # 两个没有
  echo "# New1" > "${SANDBOX}/mixed/new1.md"
  echo "# New2" > "${SANDBOX}/mixed/new2.md"

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" --dir "${SANDBOX}/mixed"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Injected: 2"* ]]
  [[ "$output" == *"Skipped:  1"* ]]
}

# ════════════════════════════════════════
# 配置读取
# ════════════════════════════════════════

@test "no anchor.yaml + --no-config → uses defaults" {
  local file
  file=$(create_plain_md "no-config.md")
  rm -f "${SANDBOX}/anchor.yaml"

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --no-config --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"config: (none"* ]]
  [[ "$output" == *"sdd-riper-one"* ]]
}

@test "anchor.yaml exists → reads writing_protocol from config" {
  # 修改 anchor.yaml 的 schema 为 simple
  cd "$SANDBOX"
  cat > anchor.yaml <<'YAML'
specanchor:
  version: "0.4.0-alpha.1"
  project_name: "test"
  mode: "full"
  writing_protocol:
    schema: "simple"
YAML

  local file
  file=$(create_plain_md "config-test.md")

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'writing_protocol: "simple"'* ]]
}

# ════════════════════════════════════════
# 选项覆盖
# ════════════════════════════════════════

@test "inject: --level overrides auto-detect" {
  local file
  file=$(create_plain_md "override.md")

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --level module --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"level: module"* ]]
}

@test "inject: --task-name overrides H1 detection" {
  local file="${SANDBOX}/custom-name.md"
  cat > "$file" <<'EOF'
# Original Title

Content.
EOF

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject.sh" "$file" --task-name "Custom Name" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'task_name: "Custom Name"'* ]]
}
