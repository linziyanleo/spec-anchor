#!/usr/bin/env bats
# test_frontmatter_inject_and_check.bats — Layer 2 组合测试

setup() {
  source "${BATS_TEST_DIRNAME}/setup_helper.bash"
  create_sandbox
}

teardown() {
  destroy_sandbox
}

# ════════════════════════════════════════
# Layer 2 组合流程
# ════════════════════════════════════════

@test "layer2: inject + check for task file → both phases run" {
  local file
  file=$(create_plain_md ".specanchor/tasks/combo.md")

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject-and-check.sh" "$file"
  [ "$status" -eq 0 ]
  # Phase 1 应该注入
  [[ "$output" == *"Phase 1"* ]]
  [[ "$output" == *"注入 frontmatter"* ]] || [[ "$output" == *"Injected: 1"* ]]
  # Phase 2 应该运行检测
  [[ "$output" == *"Phase 2"* ]]
}

@test "layer2: --dry-run → inject preview, no check" {
  local file
  file=$(create_plain_md ".specanchor/tasks/dry.md")

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject-and-check.sh" "$file" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  [[ "$output" == *"dry-run 模式，跳过检测"* ]]
  # Phase 2 不应该出现
  [[ "$output" != *"Phase 2"* ]]
}

@test "layer2: --skip-check → inject only" {
  local file
  file=$(create_plain_md ".specanchor/tasks/skipcheck.md")

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject-and-check.sh" "$file" --skip-check
  [ "$status" -eq 0 ]
  [[ "$output" == *"Injected: 1"* ]]
  [[ "$output" == *"--skip-check"* ]]
}

@test "layer2: missing check script → warns and skips Phase 2" {
  local file
  file=$(create_plain_md ".specanchor/tasks/nocheck.md")

  # 删除 check 脚本
  rm -f "${SANDBOX_SCRIPTS}/specanchor-check.sh"

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject-and-check.sh" "$file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"specanchor-check.sh 不存在"* ]] || [[ "$output" == *"跳过检测"* ]]
}

@test "layer2: --check-level global → runs global check after inject" {
  local file
  file=$(create_plain_md "docs/readme.md")
  create_global_spec "coding-standards"

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject-and-check.sh" "$file" --check-level global
  [ "$status" -eq 0 ]
  [[ "$output" == *"Phase 2"* ]]
  [[ "$output" == *"Coverage Report"* ]] || [[ "$output" == *"global"* ]]
}

@test "layer2: batch --dir → inject all then check" {
  mkdir -p "${SANDBOX}/batch-l2"
  echo "# Doc1" > "${SANDBOX}/batch-l2/a.md"
  echo "# Doc2" > "${SANDBOX}/batch-l2/b.md"

  run bash "${SANDBOX_SCRIPTS}/frontmatter-inject-and-check.sh" --dir "${SANDBOX}/batch-l2" --check-level global
  [ "$status" -eq 0 ]
  [[ "$output" == *"Injected: 2"* ]]
  [[ "$output" == *"Phase 2"* ]]
}
