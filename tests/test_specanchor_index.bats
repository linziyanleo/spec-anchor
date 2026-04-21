#!/usr/bin/env bats
# tests/test_specanchor_index.bats — specanchor-index.sh tests
#
# Validates:
# 1. Script generates valid v2 module-index.md from Module Specs
# 2. Frontmatter fields are correctly extracted
# 3. Health calculation works
# 4. Empty modules dir handled gracefully
# 5. check.sh global sub-command triggers index refresh

load setup_helper

setup() {
  create_sandbox
}

teardown() {
  destroy_sandbox
}

create_module_spec() {
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
  echo "$spec_file"
}

# --- Basic generation ---

@test "index.sh generates v2 module-index.md" {
  create_module_spec "auth" "src/auth/" "Authentication module"
  cd "$SANDBOX"

  run bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml
  [ "$status" -eq 0 ]
  [ -f ".specanchor/module-index.md" ]

  local idx_type
  idx_type=$(grep "type:" ".specanchor/module-index.md" | head -1 | sed 's/.*type: *//' | tr -d ' ')
  [ "$idx_type" = "module-index" ]
}

@test "index.sh extracts module_count correctly" {
  create_module_spec "auth" "src/auth/" "Auth module"
  create_module_spec "order" "src/order/" "Order module"
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml
  source "${SCRIPTS_DIR}/specanchor-boot.sh" 2>/dev/null || true

  local count
  count=$(parse_yaml_field ".specanchor/module-index.md" "module_count" "0")
  [ "$count" = "2" ]
}

@test "index.sh writes correct module path" {
  create_module_spec "auth" "src/auth/" "Auth module"
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml

  local path
  path=$(grep 'path:' ".specanchor/module-index.md" | grep -v 'module_path' | head -1 | sed 's/.*path: *"\([^"]*\)".*/\1/')
  [ "$path" = "src/auth/" ]
}

@test "index.sh writes correct summary" {
  create_module_spec "auth" "src/auth/" "Auth module"
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml

  local summary
  summary=$(grep '^\s*summary:' ".specanchor/module-index.md" | grep -v 'health_summary' | head -1 | sed 's/.*summary: *"\([^"]*\)".*/\1/')
  [ "$summary" = "Auth module" ]
}

@test "index.sh writes correct version" {
  create_module_spec "auth" "src/auth/" "Auth" "active" "2.1.0"
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml

  local ver
  ver=$(grep 'version:' ".specanchor/module-index.md" | grep -v specanchor | head -1 | sed 's/.*version: *"\([^"]*\)".*/\1/')
  [ "$ver" = "2.1.0" ]
}

@test "index.sh writes health field" {
  create_module_spec "auth" "src/auth/" "Auth"
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml

  run grep 'health:' ".specanchor/module-index.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"FRESH"* ]] || [[ "$output" == *"DRIFTED"* ]] || [[ "$output" == *"STALE"* ]]
}

@test "index.sh normalizes single-quoted frontmatter values" {
  mkdir -p "${SANDBOX}/src/home"
  cat > "${SANDBOX_SPECANCHOR}/modules/home.spec.md" <<'EOF'
---
specanchor:
  level: module
  module_name: 'home'
  module_path: 'src/home'
  summary: 'Home module'
  version: '1.2.0'
  owner: '@test-user'
  created: '2026-01-01'
  status: active
  last_synced: '2026-04-14'
  depends_on: []
---

# home Module Spec
EOF
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml

  run grep 'path: "src/home"' ".specanchor/module-index.md"
  [ "$status" -eq 0 ]
  run grep 'health: FRESH' ".specanchor/module-index.md"
  [ "$status" -eq 0 ]
}

# --- Empty dir ---

@test "index.sh handles empty modules dir" {
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml
  [ -f ".specanchor/module-index.md" ]

  source "${SCRIPTS_DIR}/specanchor-boot.sh" 2>/dev/null || true
  local count
  count=$(parse_yaml_field ".specanchor/module-index.md" "module_count" "0")
  [ "$count" = "0" ]
}

# --- Markdown table rendering ---

@test "index.sh renders markdown table" {
  create_module_spec "auth" "src/auth/" "Auth module"
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml

  run grep '| src/auth/' ".specanchor/module-index.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Auth module"* ]]
}

@test "index.sh renders stats line" {
  create_module_spec "auth" "src/auth/" "Auth"
  create_module_spec "order" "src/order/" "Order"
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml

  run grep '统计' ".specanchor/module-index.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 个模块"* ]]
}

# --- Boot reads script-generated index ---

@test "boot reads script-generated v2 index" {
  create_module_spec "auth" "src/auth/" "Auth"
  create_global_spec
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml
  run bash "${SCRIPTS_DIR}/specanchor-boot.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"v2 (structured)"* ]]
}

# --- Custom output path ---

@test "index.sh respects --output flag" {
  create_module_spec "auth" "src/auth/" "Auth"
  cd "$SANDBOX"

  bash "${SCRIPTS_DIR}/specanchor-index.sh" --config=anchor.yaml --output=/tmp/test-idx.md
  [ -f "/tmp/test-idx.md" ]
  run grep "type: module-index" "/tmp/test-idx.md"
  [ "$status" -eq 0 ]
  rm -f /tmp/test-idx.md
}

# --- check.sh global triggers index refresh ---

@test "check.sh global refreshes module-index" {
  create_module_spec "auth" "src/auth/" "Auth"
  create_global_spec
  cd "$SANDBOX"

  [[ ! -f ".specanchor/module-index.md" ]] || rm ".specanchor/module-index.md"

  run bash "${SCRIPTS_DIR}/specanchor-check.sh" global --config=anchor.yaml
  [ "$status" -eq 0 ]
  [ -f ".specanchor/module-index.md" ]

  run grep "type: module-index" ".specanchor/module-index.md"
  [ "$status" -eq 0 ]
}
