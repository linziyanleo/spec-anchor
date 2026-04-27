#!/usr/bin/env bats
# tests/test_spec_index.bats — spec-index.md structured format tests

load setup_helper

setup() {
  create_sandbox
}

teardown() {
  destroy_sandbox
}

parse_yaml_field() {
  local file="$1" field="$2" default="$3"
  awk -v field="$field" -v default="$default" '
    $0 ~ "^    " field ":" {
      sub("^    " field ": *", "", $0)
      gsub(/^"|"$/, "", $0)
      print
      found=1
      exit
    }
    $0 ~ "^  " field ":" {
      sub("^  " field ": *", "", $0)
      gsub(/^"|"$/, "", $0)
      print
      found=1
      exit
    }
    END { if (!found) print default }
  ' "$file"
}

@test "parse_yaml_field reads type from spec-index.md" {
  create_spec_index_v3_with_modules
  cd "$SANDBOX"

  local val
  val=$(parse_yaml_field ".specanchor/spec-index.md" "type" "")
  [ "$val" = "spec-index" ]
}

@test "parse_yaml_field reads spec-index version" {
  create_spec_index_v3_with_modules
  cd "$SANDBOX"

  local val
  val=$(parse_yaml_field ".specanchor/spec-index.md" "version" "0")
  [ "$val" = "3" ]
}

@test "grep extracts module paths from specs.modules" {
  create_spec_index_v3_with_modules
  cd "$SANDBOX"

  local paths
  paths=$(grep 'path:' ".specanchor/spec-index.md" | sed 's/.*path: *"\([^"]*\)".*/\1/')
  [[ "$paths" == *"src/auth/"* ]]
  [[ "$paths" == *"src/order/"* ]]
}

@test "grep extracts module health values" {
  create_spec_index_v3_with_modules
  cd "$SANDBOX"

  local healths
  healths=$(grep '^[[:space:]]*health:' ".specanchor/spec-index.md" | sed 's/.*health: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/')
  [[ "$healths" == *"FRESH"* ]]
  [[ "$healths" == *"DRIFTED"* ]]
}

@test "boot recognizes v3 spec-index correctly" {
  create_spec_index_v3_with_modules
  cd "$SANDBOX"

  run bash "${SCRIPTS_DIR}/specanchor-boot.sh" --format=summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"Spec Index:"*"v3 (structured)"* ]]
  [[ "$output" == *"Available Modules:"* ]]
  [[ "$output" == *"src/auth/"* ]]
}

@test "boot recognizes legacy module-index fallback" {
  create_module_index_v2_with_modules
  cd "$SANDBOX"

  run bash "${SCRIPTS_DIR}/specanchor-boot.sh" --format=summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"legacy-module-v2"* ]]
  [[ "$output" == *"legacy module-index.md"* ]]
}

@test "boot warns when spec-index is missing" {
  cd "$SANDBOX"

  run bash "${SCRIPTS_DIR}/specanchor-boot.sh" --format=summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"spec-index.md"* ]]
  [[ "$output" == *"不存在"* || "$output" == *"missing"* ]]
}

@test "legacy module-index remains parseable during migration" {
  create_module_index_legacy
  cd "$SANDBOX"

  local first_line
  first_line=$(head -1 ".specanchor/module-index.md")
  [ "$first_line" = "# Module Spec 索引" ]

  run bash "${SCRIPTS_DIR}/specanchor-boot.sh" --format=summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"legacy"* ]]
}
