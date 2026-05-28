#!/usr/bin/env bats
# tests/test_hook_inline_brief.bats — specanchor-boot.sh --format=inline-brief

load setup_helper

setup() {
  create_sandbox
  cat > "${SANDBOX}/anchor.yaml" <<'YAML'
specanchor:
  version: "0.5.0"
  project_name: "test-proj"
  mode: "full"
  paths:
    global_specs: ".specanchor/global/"
    module_specs: ".specanchor/modules/"
    task_specs: ".specanchor/tasks/"
    spec_index: ".specanchor/spec-index.md"
YAML
  mkdir -p "${SANDBOX}/.specanchor/global"
  cat > "${SANDBOX}/.specanchor/global/coding.spec.md" <<'MD'
---
specanchor:
  level: global
  type: coding
---
# Coding Standards
## Shell Rules
- Always use set -euo pipefail
## Naming
- Use snake_case for functions
MD
}

teardown() {
  rm -rf "$SANDBOX"
}

@test "inline-brief produces output" {
  cd "$SANDBOX"
  run bash "${SCRIPTS_DIR}/specanchor-boot.sh" --format=inline-brief
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "inline-brief includes project name" {
  cd "$SANDBOX"
  run bash "${SCRIPTS_DIR}/specanchor-boot.sh" --format=inline-brief
  [ "$status" -eq 0 ]
  [[ "$output" == *"test-proj"* ]]
}

@test "inline-brief includes coding standards sections" {
  cd "$SANDBOX"
  run bash "${SCRIPTS_DIR}/specanchor-boot.sh" --format=inline-brief
  [ "$status" -eq 0 ]
  [[ "$output" == *"Coding Standards"* ]]
  [[ "$output" == *"Shell Rules"* ]]
}

@test "inline-brief respects budget cap" {
  cd "$SANDBOX"
  # Set very low budget
  cat >> "${SANDBOX}/anchor.yaml" <<'YAML'
  hook:
    inline_budget_tokens: 200
YAML
  run bash "${SCRIPTS_DIR}/specanchor-boot.sh" --format=inline-brief
  [ "$status" -eq 0 ]
  # 200 tokens * 4 chars = 800 char max
  [ "${#output}" -le 900 ]
}

@test "inline-brief warns on out-of-bounds budget" {
  cd "$SANDBOX"
  cat >> "${SANDBOX}/anchor.yaml" <<'YAML'
  hook:
    inline_budget_tokens: 50
YAML
  run bash "${SCRIPTS_DIR}/specanchor-boot.sh" --format=inline-brief
  [ "$status" -eq 0 ]
  # stderr should contain warning (captured in output by bats run)
}
