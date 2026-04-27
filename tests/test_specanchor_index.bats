#!/usr/bin/env bats
# tests/test_specanchor_index.bats — specanchor-index.sh tests

load setup_helper

setup() {
  create_sandbox
}

teardown() {
  destroy_sandbox
}

create_index_module_spec() {
  local name="$1" path="$2" summary="$3" status="${4:-active}" version="${5:-1.0.0}" synced="${6:-2026-04-14}"
  local spec_file="${SANDBOX_SPECANCHOR}/modules/${name}.spec.md"
  cat > "$spec_file" <<EOF
---
specanchor:
  level: module
  module_name: "${name}"
  module_path: "${path}"
  summary: "${summary}"
  version: "${version}"
  owner: "@test-user"
  created: "2026-01-01"
  status: ${status}
  last_synced: "${synced}"
  depends_on: []
---

# ${name} Module Spec

## 1. Overview
Test module.
EOF
  mkdir -p "${SANDBOX}/${path}"
  echo "$spec_file"
}

@test "index.sh generates v3 spec-index.md" {
  create_index_module_spec "auth" "src/auth/" "Authentication module"
  cd "$SANDBOX"

  run bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml
  [ "$status" -eq 0 ]
  [ -f ".specanchor/spec-index.md" ]
  run grep "type: spec-index" ".specanchor/spec-index.md"
  [ "$status" -eq 0 ]
  run grep "version: 3" ".specanchor/spec-index.md"
  [ "$status" -eq 0 ]
}

@test "index.sh extracts module count correctly" {
  create_index_module_spec "auth" "src/auth/" "Auth module"
  create_index_module_spec "order" "src/order/" "Order module"
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml
  run grep "    modules: 2" ".specanchor/spec-index.md"
  [ "$status" -eq 0 ]
}

@test "index.sh writes correct module path" {
  create_index_module_spec "auth" "src/auth/" "Auth module"
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml
  run grep 'path: "src/auth/"' ".specanchor/spec-index.md"
  [ "$status" -eq 0 ]
}

@test "index.sh writes correct summary" {
  create_index_module_spec "auth" "src/auth/" "Auth module"
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml
  run grep 'summary: "Auth module"' ".specanchor/spec-index.md"
  [ "$status" -eq 0 ]
}

@test "index.sh writes correct version" {
  create_index_module_spec "auth" "src/auth/" "Auth module" "active" "2.1.0"
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml
  run grep 'version: "2.1.0"' ".specanchor/spec-index.md"
  [ "$status" -eq 0 ]
}

@test "index.sh writes health field" {
  create_index_module_spec "auth" "src/auth/" "Auth module"
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml
  run grep 'health:' ".specanchor/spec-index.md"
  [ "$status" -eq 0 ]
}

@test "index.sh normalizes single-quoted frontmatter values" {
  local spec_file="${SANDBOX_SPECANCHOR}/modules/home.spec.md"
  mkdir -p "${SANDBOX}/src/home"
  cat > "$spec_file" <<'EOF'
---
specanchor:
  level: module
  module_name: 'home'
  module_path: 'src/home'
  summary: 'Home module'
  version: '1.0.0'
  owner: '@test'
  status: active
  last_synced: '2026-04-14'
---
# Home
EOF
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml
  run grep 'path: "src/home"' ".specanchor/spec-index.md"
  [ "$status" -eq 0 ]
}

@test "index.sh handles empty modules dir" {
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml
  [ -f ".specanchor/spec-index.md" ]
  run grep "    modules: 0" ".specanchor/spec-index.md"
  [ "$status" -eq 0 ]
}

@test "index.sh renders markdown table" {
  create_index_module_spec "auth" "src/auth/" "Auth module"
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml
  run grep '| src/auth/ |' ".specanchor/spec-index.md"
  [ "$status" -eq 0 ]
}

@test "index.sh renders stats line" {
  create_index_module_spec "auth" "src/auth/" "Auth module"
  create_index_module_spec "order" "src/order/" "Order module"
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml
  run grep '2 modules' ".specanchor/spec-index.md"
  [ "$status" -eq 0 ]
}

@test "boot reads script-generated v3 index" {
  create_index_module_spec "auth" "src/auth/" "Auth module"
  create_global_spec
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml
  run bash "${SCRIPTS_DIR}/specanchor-boot.sh" --format=summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"Spec Index:"*"v3 (structured)"* ]]
  [[ "$output" == *"src/auth/"* ]]
}

@test "index.sh respects --output flag" {
  create_index_module_spec "auth" "src/auth/" "Auth module"
  cd "$SANDBOX"

  run bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml --output="/tmp/test-idx.md"
  [ "$status" -eq 0 ]
  [ -f "/tmp/test-idx.md" ]
  run grep "type: spec-index" "/tmp/test-idx.md"
  [ "$status" -eq 0 ]
  rm -f "/tmp/test-idx.md"
}

@test "index.sh --legacy-module-index writes compatibility file" {
  create_index_module_spec "auth" "src/auth/" "Auth module"
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml --legacy-module-index
  [ -f ".specanchor/spec-index.md" ]
  [ -f ".specanchor/module-index.md" ]
  run grep "type: module-index" ".specanchor/module-index.md"
  [ "$status" -eq 0 ]
}

@test "check.sh global refreshes spec-index" {
  create_index_module_spec "auth" "src/auth/" "Auth module"
  create_global_spec
  cd "$SANDBOX"

  rm -f ".specanchor/spec-index.md"
  run bash "${SANDBOX_SCRIPTS}/specanchor-check.sh" global
  [ "$status" -eq 0 ]
  [ -f ".specanchor/spec-index.md" ]
  run grep "type: spec-index" ".specanchor/spec-index.md"
  [ "$status" -eq 0 ]
}
