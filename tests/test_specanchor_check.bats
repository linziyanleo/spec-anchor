#!/usr/bin/env bats
# test_specanchor_check.bats — specanchor-check.sh 回归测试

setup() {
  source "${BATS_TEST_DIRNAME}/setup_helper.bash"
  create_sandbox
}

teardown() {
  destroy_sandbox
}

# ════════════════════════════════════════
# task 模式
# ════════════════════════════════════════

@test "task: planned files all covered → shows all green" {
  local spec
  spec=$(create_task_spec "test-task" "src/auth.ts" "src/utils.ts")

  # task 检测需要 feature 分支 vs base 分支的 diff
  sandbox_create_branch "feat/test"
  sandbox_commit "src/auth.ts" "feat: auth"
  sandbox_commit "src/utils.ts" "feat: utils"

  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" task "$spec" --base=main
  [ "$status" -eq 0 ]
  [[ "$output" == *"2/2"* ]]
  [[ "$output" == *"all planned files covered"* ]]
}

@test "task: missing planned file → shows missing count" {
  local spec
  spec=$(create_task_spec "test-task" "src/auth.ts" "src/utils.ts")

  sandbox_create_branch "feat/missing"
  sandbox_commit "src/auth.ts" "feat: auth"

  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" task "$spec" --base=main
  [ "$status" -eq 0 ]
  [[ "$output" == *"1/2"* ]]
  [[ "$output" == *"1 planned file(s) missing"* ]]
}

@test "task: unplanned changes → shows unplanned count" {
  local spec
  spec=$(create_task_spec "test-task" "src/auth.ts")

  sandbox_create_branch "feat/unplanned"
  sandbox_commit "src/auth.ts" "feat: auth"
  sandbox_commit "src/surprise.ts" "feat: surprise"

  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" task "$spec" --base=main
  [ "$status" -eq 0 ]
  [[ "$output" == *"unplanned"* ]]
}

@test "task: spec without File Changes → skips coverage check" {
  local spec="${SANDBOX_SPECANCHOR}/tasks/empty.spec.md"
  cat > "$spec" <<'EOF'
---
specanchor:
  level: task
  task_name: "empty"
  branch: "main"
---

# SDD Spec: empty

## 4. Plan
No file changes listed.
EOF

  sandbox_create_branch "feat/empty"
  sandbox_commit "src/foo.ts" "feat: foo"

  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" task "$spec" --base=main
  [ "$status" -eq 0 ]
  [[ "$output" == *"未找到 File Changes"* ]]
}

@test "task: nonexistent spec file → exits with error" {
  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" task "/nonexistent/spec.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"不存在"* ]]
}

@test "task: short filename false positive # known-bug" {
  # S1: auth.ts 被 test-auth.ts 的子串匹配命中 → 假阳性
  local spec
  spec=$(create_task_spec "test-task" "auth.ts")

  sandbox_create_branch "feat/known-bug"
  sandbox_commit "src/test-auth.ts" "test: auth"

  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" task "$spec" --base=main
  [ "$status" -eq 0 ]
  # known-bug: 当前子串匹配会把 test-auth.ts 视为覆盖 auth.ts
  # 修复后应改为 "1 planned file(s) missing"
  [[ "$output" == *"1/1"* ]]
}

# ════════════════════════════════════════
# module 模式
# ════════════════════════════════════════

@test "module: fresh module (no commits since sync) → FRESH" {
  create_module_spec "src/auth/" "2026-04-01"

  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" module "${SANDBOX_SPECANCHOR}/modules/src-auth.spec.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"FRESH"* ]]
}

@test "module: single-quoted frontmatter path/date → FRESH" {
  local file="${SANDBOX_SPECANCHOR}/modules/src-home.spec.md"
  mkdir -p "${SANDBOX}/src/home"
  cat > "$file" <<'EOF'
---
specanchor:
  level: module
  module_name: 'src-home'
  module_path: 'src/home'
  version: '1.0.0'
  owner: '@test-user'
  last_synced: '2026-04-01'
  status: active
---

# Module: src/home
EOF

  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" module "$file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"src/home"* ]]
  [[ "$output" == *"FRESH"* ]]
}

@test "module: stale module → STALE" {
  # 使用很久以前的同步日期
  create_module_spec "src/auth/" "2026-03-01"

  # 在模块目录下提交一些文件
  sandbox_commit "src/auth/index.ts" "feat: auth init"

  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" module "${SANDBOX_SPECANCHOR}/modules/src-auth.spec.md"
  [ "$status" -eq 0 ]
  # 32 天前同步 + 有新提交 → STALE 或 OUTDATED
  [[ "$output" == *"STALE"* ]] || [[ "$output" == *"OUTDATED"* ]]
}

@test "module --all: lists all modules" {
  create_module_spec "src/auth/" "2026-04-01"
  create_module_spec "src/core/" "2026-04-01"

  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" module --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"src-auth"* ]]
  [[ "$output" == *"src-core"* ]]
  [[ "$output" == *"Covered: 2 module(s)"* ]]
}

@test "module: missing module_path → degrades gracefully" {
  local file="${SANDBOX_SPECANCHOR}/modules/broken.spec.md"
  cat > "$file" <<'EOF'
---
specanchor:
  level: module
  module_name: "broken"
  version: "1.0.0"
---

# Broken module
EOF

  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" module "$file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"missing module_path"* ]]
  [[ "$output" == *"STALE"* ]]
}

@test "module: invalid module_path → STALE instead of FRESH" {
  local file="${SANDBOX_SPECANCHOR}/modules/ghost.spec.md"
  cat > "$file" <<'EOF'
---
specanchor:
  level: module
  module_name: "ghost"
  module_path: "src/ghost"
  version: "1.0.0"
  owner: "@test-user"
  last_synced: "2026-04-01"
  status: active
---

# Ghost module
EOF

  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" module "$file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"invalid module_path"* ]]
  [[ "$output" == *"STALE"* ]]
  [[ "$output" != *"FRESH"* ]]
}

@test "module: nonexistent spec file → exits with error" {
  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" module "/nonexistent.spec.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"不存在"* ]]
}

# ════════════════════════════════════════
# global 模式
# ════════════════════════════════════════

@test "global: reports global spec count" {
  create_global_spec "coding-standards"
  create_global_spec "architecture"

  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" global
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 file(s)"* ]]
}

@test "global: no warnings when all fresh" {
  create_global_spec "coding-standards"
  create_module_spec "src/auth/" "2026-04-01"

  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" global
  [ "$status" -eq 0 ]
  [[ "$output" == *"(none)"* ]]
}

@test "global: invalid module_path → surfaces warning" {
  create_global_spec "coding-standards"
  local file="${SANDBOX_SPECANCHOR}/modules/ghost.spec.md"
  cat > "$file" <<'EOF'
---
specanchor:
  level: module
  module_name: "ghost"
  module_path: "src/ghost"
  version: "1.0.0"
  owner: "@test-user"
  last_synced: "2026-04-01"
  status: active
---

# Ghost module
EOF

  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" global
  [ "$status" -eq 0 ]
  [[ "$output" == *"invalid module_path"* ]]
  [[ "$output" == *"ghost"* ]]
}

@test "global: missing anchor.yaml → exits with error" {
  rm -f "${SANDBOX}/anchor.yaml"
  rm -rf "${SANDBOX}/.specanchor/config.yaml"

  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" global
  [ "$status" -ne 0 ]
  [[ "$output" == *"未找到配置文件"* ]]
}

@test "global: empty modules dir → reports 0 modules" {
  create_global_spec "coding-standards"

  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" global
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 module(s)"* ]]
}

# ════════════════════════════════════════
# coverage 模式
# ════════════════════════════════════════

@test "coverage: file under covered module → shows covered" {
  create_module_spec "src/auth/"

  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" coverage "src/auth/login.ts"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓"* ]] || [[ "$output" == *"covered"* ]]
}

@test "coverage: file under uncovered path → shows uncovered" {
  create_module_spec "src/auth/"

  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" coverage "src/billing/pay.ts"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✗"* ]] || [[ "$output" == *"no module spec"* ]]
}

@test "coverage: empty modules dir → all uncovered" {
  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" coverage "src/foo.ts"
  [ "$status" -eq 0 ]
  [[ "$output" == *"0/"* ]]
}

# ════════════════════════════════════════
# 边界条件
# ════════════════════════════════════════

@test "no subcommand → shows usage" {
  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh"
  [ "$status" -ne 0 ]
}

@test "unknown subcommand → exits with error" {
  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" foobar
  [ "$status" -ne 0 ]
  [[ "$output" == *"未知"* ]]
}
