#!/usr/bin/env bats
# tests/test_specanchor_status.bats — specanchor-status.sh tests

load setup_helper

setup() {
  create_sandbox
}

teardown() {
  destroy_sandbox
}

create_module_spec_for_status() {
  local name="$1" path="$2" synced="${3:-2026-04-14}"
  local spec_file="${SANDBOX_SPECANCHOR}/modules/${name}.spec.md"
  cat > "$spec_file" <<EOF
---
specanchor:
  level: module
  module_name: "${name}"
  module_path: "${path}"
  summary: "Test module ${name}"
  version: "1.0.0"
  owner: "@test"
  created: "2026-01-01"
  status: active
  last_synced: "${synced}"
  depends_on: []
---
# ${name}
EOF
}

@test "status shows global spec count" {
  create_global_spec
  cd "$SANDBOX"
  run bash "${SCRIPTS_DIR}/specanchor-status.sh" --config=anchor.yaml
  [ "$status" -eq 0 ]
  [[ "$output" == *"Global Specs:"* ]]
}

@test "status prints assembly trace" {
  create_global_spec
  cd "$SANDBOX"
  run bash "${SCRIPTS_DIR}/specanchor-status.sh" --config=anchor.yaml
  [ "$status" -eq 0 ]
  [[ "$output" == *"Assembly Trace:"* ]]
  [[ "$output" == *"Global: summary -> coding-standards.spec.md"* ]]
  [[ "$output" == *"Module: deferred -> none (status does not preload module bodies)"* ]]
}

@test "status shows module spec count" {
  create_global_spec
  create_module_spec_for_status "auth" "src/auth/"
  cd "$SANDBOX"
  run bash "${SCRIPTS_DIR}/specanchor-status.sh" --config=anchor.yaml
  [ "$status" -eq 0 ]
  [[ "$output" == *"Module Specs: 1 module"* ]]
}

@test "status shows task spec count" {
  create_global_spec
  cd "$SANDBOX"
  mkdir -p .specanchor/tasks/test
  cat > .specanchor/tasks/test/test.spec.md <<'EOF'
---
specanchor:
  level: task
  task_name: "test-task"
---
# Test
EOF
  run bash "${SCRIPTS_DIR}/specanchor-status.sh" --config=anchor.yaml
  [ "$status" -eq 0 ]
  [[ "$output" == *"Task Specs: 1 active"* ]]
}

@test "status shows spec index format" {
  create_global_spec
  create_spec_index_v3_with_modules
  cd "$SANDBOX"
  run bash "${SCRIPTS_DIR}/specanchor-status.sh" --config=anchor.yaml
  [ "$status" -eq 0 ]
  [[ "$output" == *"v3 (structured)"* ]]
}

@test "status warns when spec-index is missing" {
  create_global_spec
  cd "$SANDBOX"
  run bash "${SCRIPTS_DIR}/specanchor-status.sh" --config=anchor.yaml
  [ "$status" -eq 0 ]
  [[ "$output" == *"missing"* ]]
}

@test "status JSON output is valid" {
  create_global_spec
  create_module_spec_for_status "auth" "src/auth/"
  cd "$SANDBOX"
  run bash "${SCRIPTS_DIR}/specanchor-status.sh" --config=anchor.yaml --format=json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"mode":'* ]]
  [[ "$output" == *'"assembly_trace": {'* ]]
  [[ "$output" == *'"global_specs":'* ]]
  [[ "$output" == *'"module_specs":'* ]]
  [[ "$output" == *'"task_specs":'* ]]
}

@test "status shows module details" {
  create_global_spec
  create_module_spec_for_status "auth" "src/auth/"
  cd "$SANDBOX"
  run bash "${SCRIPTS_DIR}/specanchor-status.sh" --config=anchor.yaml
  [ "$status" -eq 0 ]
  [[ "$output" == *"auth"* ]]
  [[ "$output" == *"src/auth/"* ]]
}

@test "status handles single-quoted frontmatter values" {
  create_global_spec
  mkdir -p "${SANDBOX}/src/home"
  cat > "${SANDBOX_SPECANCHOR}/modules/home.spec.md" <<'EOF'
---
specanchor:
  level: module
  module_name: 'home'
  module_path: 'src/home'
  summary: 'Test module home'
  version: '1.0.0'
  owner: '@test'
  created: '2026-01-01'
  status: active
  last_synced: '2026-04-14'
---
# home
EOF

  cd "$SANDBOX"
  run bash "${SCRIPTS_DIR}/specanchor-status.sh" --config=anchor.yaml
  [ "$status" -eq 0 ]
  [[ "$output" == *"🟢1 FRESH"* ]]
  [[ "$output" == *"home (src/home)"* ]]
}

@test "status fails without config" {
  local empty_dir
  empty_dir=$(mktemp -d)
  cd "$empty_dir"
  run bash "${SCRIPTS_DIR}/specanchor-status.sh"
  [ "$status" -ne 0 ]
  rm -rf "$empty_dir"
}
