#!/usr/bin/env bats
# tests/test_specanchor_init.bats — specanchor-init.sh tests

load setup_helper

setup() {
  INIT_SANDBOX=$(mktemp -d)
}

teardown() {
  rm -rf "$INIT_SANDBOX"
}

@test "init creates anchor.yaml" {
  cd "$INIT_SANDBOX"
  run bash "${SCRIPTS_DIR}/specanchor-init.sh" --project=test-proj
  [ "$status" -eq 0 ]
  [ -f "anchor.yaml" ]
}

@test "init creates .specanchor directory structure" {
  cd "$INIT_SANDBOX"
  bash "${SCRIPTS_DIR}/specanchor-init.sh" --project=test-proj
  [ -d ".specanchor/global" ]
  [ -d ".specanchor/modules" ]
  [ -d ".specanchor/tasks/_cross-module" ]
  [ -d ".specanchor/archive" ]
  [ -d ".specanchor/scripts" ]
}

@test "init creates spec-index.md" {
  cd "$INIT_SANDBOX"
  bash "${SCRIPTS_DIR}/specanchor-init.sh" --project=test-proj
  [ -f ".specanchor/spec-index.md" ]
}

@test "init creates project-codemap.md" {
  cd "$INIT_SANDBOX"
  bash "${SCRIPTS_DIR}/specanchor-init.sh" --project=test-proj
  [ -f ".specanchor/project-codemap.md" ]
}

@test "init writes project name to anchor.yaml" {
  cd "$INIT_SANDBOX"
  bash "${SCRIPTS_DIR}/specanchor-init.sh" --project=my-app
  run grep "project_name" anchor.yaml
  [ "$status" -eq 0 ]
  [[ "$output" == *"my-app"* ]]
}

@test "init writes mode to anchor.yaml" {
  cd "$INIT_SANDBOX"
  bash "${SCRIPTS_DIR}/specanchor-init.sh" --project=test --mode=full
  run grep 'mode:' anchor.yaml
  [ "$status" -eq 0 ]
  [[ "$output" == *"full"* ]]
}

@test "init fails if anchor.yaml already exists" {
  cd "$INIT_SANDBOX"
  touch anchor.yaml
  run bash "${SCRIPTS_DIR}/specanchor-init.sh" --project=test
  [ "$status" -ne 0 ]
  [[ "$output" == *"已存在"* ]]
}

@test "init parasitic mode skips .specanchor directory" {
  cd "$INIT_SANDBOX"
  bash "${SCRIPTS_DIR}/specanchor-init.sh" --project=test --mode=parasitic
  [ -f "anchor.yaml" ]
  [ ! -d ".specanchor/global" ]
}

@test "init defaults project name to directory name" {
  cd "$INIT_SANDBOX"
  bash "${SCRIPTS_DIR}/specanchor-init.sh"
  local dir_name
  dir_name=$(basename "$INIT_SANDBOX")
  run grep "project_name" anchor.yaml
  [ "$status" -eq 0 ]
  [[ "$output" == *"$dir_name"* ]]
}
