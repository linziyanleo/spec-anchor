#!/usr/bin/env bats
# tests/test_module_index.bats — module-index.md structured format tests
#
# Validates:
# 1. YAML frontmatter can be parsed by parse_yaml_field
# 2. boot script recognizes v2 and legacy formats
# 3. health summary data can be extracted

load setup_helper

setup() {
  create_sandbox
}

teardown() {
  destroy_sandbox
}

# --- parse_yaml_field compatibility ---

@test "parse_yaml_field reads type from module-index.md" {
  create_module_index_v2_with_modules
  cd "$SANDBOX"
  source "${SCRIPTS_DIR}/specanchor-boot.sh" 2>/dev/null || true

  local val
  val=$(parse_yaml_field ".specanchor/module-index.md" "type" "")
  [ "$val" = "module-index" ]
}

@test "parse_yaml_field reads module_count" {
  create_module_index_v2_with_modules
  cd "$SANDBOX"
  source "${SCRIPTS_DIR}/specanchor-boot.sh" 2>/dev/null || true

  local val
  val=$(parse_yaml_field ".specanchor/module-index.md" "module_count" "0")
  [ "$val" = "2" ]
}

@test "parse_yaml_field reads covered_count" {
  create_module_index_v2_with_modules
  cd "$SANDBOX"
  source "${SCRIPTS_DIR}/specanchor-boot.sh" 2>/dev/null || true

  local val
  val=$(parse_yaml_field ".specanchor/module-index.md" "covered_count" "0")
  [ "$val" = "2" ]
}

@test "parse_yaml_field reads uncovered_count" {
  create_module_index_v2_with_modules
  cd "$SANDBOX"
  source "${SCRIPTS_DIR}/specanchor-boot.sh" 2>/dev/null || true

  local val
  val=$(parse_yaml_field ".specanchor/module-index.md" "uncovered_count" "0")
  [ "$val" = "0" ]
}

@test "parse_yaml_field reads health_summary.fresh" {
  create_module_index_v2_with_modules
  cd "$SANDBOX"
  source "${SCRIPTS_DIR}/specanchor-boot.sh" 2>/dev/null || true

  local val
  val=$(parse_yaml_field ".specanchor/module-index.md" "fresh" "0")
  [ "$val" = "1" ]
}

@test "parse_yaml_field reads health_summary.drifted" {
  create_module_index_v2_with_modules
  cd "$SANDBOX"
  source "${SCRIPTS_DIR}/specanchor-boot.sh" 2>/dev/null || true

  local val
  val=$(parse_yaml_field ".specanchor/module-index.md" "drifted" "0")
  [ "$val" = "1" ]
}

# --- module data extraction via grep ---

@test "grep extracts all path values from modules array" {
  create_module_index_v2_with_modules
  cd "$SANDBOX"

  local paths
  paths=$(grep 'path:' ".specanchor/module-index.md" | grep -v 'module_path' | sed 's/.*path: *"\([^"]*\)".*/\1/')
  [ "$(echo "$paths" | head -1)" = "src/auth/" ]
  [ "$(echo "$paths" | tail -1)" = "src/order/" ]
}

@test "grep extracts all health values from modules array" {
  create_module_index_v2_with_modules
  cd "$SANDBOX"

  local healths
  healths=$(grep '^\s*health:' ".specanchor/module-index.md" | sed 's/.*health: *//' | tr -d ' ')
  [ "$(echo "$healths" | head -1)" = "FRESH" ]
  [ "$(echo "$healths" | tail -1)" = "DRIFTED" ]
}

@test "grep extracts all summary values from modules array" {
  create_module_index_v2_with_modules
  cd "$SANDBOX"

  local summaries
  summaries=$(grep '^\s*summary:' ".specanchor/module-index.md" | sed 's/.*summary: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/')
  [ "$(echo "$summaries" | head -1)" = "User authentication module" ]
  [ "$(echo "$summaries" | tail -1)" = "Order management module" ]
}

# --- boot script integration ---

@test "boot recognizes v2 module-index correctly" {
  create_module_index_v2_with_modules
  create_global_spec
  cd "$SANDBOX"

  run bash "${SCRIPTS_DIR}/specanchor-boot.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"module-index.md"*"不存在"* ]]
}

@test "boot recognizes legacy module-index correctly" {
  create_module_index_legacy
  create_global_spec
  cd "$SANDBOX"

  run bash "${SCRIPTS_DIR}/specanchor-boot.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"module-index.md"*"不存在"* ]]
}

@test "boot warns when module-index is missing" {
  create_global_spec
  cd "$SANDBOX"

  run bash "${SCRIPTS_DIR}/specanchor-boot.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"module-index.md"* ]]
}

@test "boot summary prints assembly trace with global summary and deferred module" {
  create_global_spec
  cd "$SANDBOX"

  run bash "${SCRIPTS_DIR}/specanchor-boot.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Assembly Trace:"* ]]
  [[ "$output" == *"Global: summary -> coding-standards.spec.md"* ]]
  [[ "$output" == *"Module: deferred -> none (on-demand after module/path match)"* ]]
}

@test "boot full prints assembly trace with global full" {
  create_global_spec
  cd "$SANDBOX"

  run bash "${SCRIPTS_DIR}/specanchor-boot.sh" --format=full
  [ "$status" -eq 0 ]
  [[ "$output" == *"Assembly Trace:"* ]]
  [[ "$output" == *"Global: full -> coding-standards.spec.md"* ]]
  [[ "$output" == *"=== coding-standards.spec.md ==="* ]]
}

@test "boot JSON outputs ok status for v2 module-index" {
  create_module_index_v2_with_modules
  create_global_spec
  cd "$SANDBOX"

  run bash "${SCRIPTS_DIR}/specanchor-boot.sh" --format=json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"module_index": "ok"'* ]]
  [[ "$output" == *'"assembly_trace": {'* ]]
  [[ "$output" == *'"global": {"mode":"summary","files":["coding-standards.spec.md"]}'* ]]
}

# --- v2 vs legacy detection ---

@test "v2 detection: file with type module-index is recognized" {
  create_module_index_v2_with_modules
  cd "$SANDBOX"

  local has_frontmatter
  has_frontmatter=$(head -1 ".specanchor/module-index.md")
  [ "$has_frontmatter" = "---" ]

  local index_type
  index_type=$(grep "type:" ".specanchor/module-index.md" | head -1 | sed 's/.*type: *//' | tr -d ' ')
  [ "$index_type" = "module-index" ]
}

@test "legacy detection: file without frontmatter is legacy" {
  create_module_index_legacy
  cd "$SANDBOX"

  local first_line
  first_line=$(head -1 ".specanchor/module-index.md")
  [ "$first_line" = "# Module Spec 索引" ]
}

# --- empty modules list ---

@test "parse_yaml_field reads module_count as 0 for empty index" {
  create_module_index_v2
  cd "$SANDBOX"
  source "${SCRIPTS_DIR}/specanchor-boot.sh" 2>/dev/null || true

  local val
  val=$(parse_yaml_field ".specanchor/module-index.md" "module_count" "0")
  [ "$val" = "0" ]
}
