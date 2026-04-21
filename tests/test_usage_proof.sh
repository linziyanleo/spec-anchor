#!/usr/bin/env bash
# Usage-proof smoke tests for committed public examples.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=tests/helpers/assert.sh
source "${SCRIPT_DIR}/helpers/assert.sh"

TMP_DIRS=()
PASS_COUNT=0
FAIL_COUNT=0
CAPTURE_OUTPUT=""
CAPTURE_STATUS=0

cleanup() {
  local dir=""
  set +e
  for dir in "${TMP_DIRS[@]:-}"; do
    [[ -n "$dir" ]] && rm -rf "$dir" 2>/dev/null
  done
}
trap cleanup EXIT

make_temp_dir() {
  local dir
  dir=$(mktemp -d)
  TMP_DIRS+=("$dir")
  printf '%s\n' "$dir"
}

copy_example() {
  local example_name="$1"
  local target_dir="$2"
  mkdir -p "$target_dir"
  cp -R "${REPO_ROOT}/examples/${example_name}/." "$target_dir/"
}

install_skill() {
  local project_dir="$1"
  local skill_dir="$2"
  mkdir -p "$skill_dir"
  rsync -a --exclude-from="${REPO_ROOT}/.skillexclude" "${REPO_ROOT}/" "${skill_dir}/"
}

capture_cmd() {
  local workdir="$1"
  shift
  local output_file
  output_file=$(mktemp)
  TMP_DIRS+=("$output_file")

  set +e
  (
    cd "$workdir"
    "$@"
  ) >"$output_file" 2>&1
  CAPTURE_STATUS=$?
  set -e
  CAPTURE_OUTPUT=$(cat "$output_file")
  rm -f "$output_file"
}

assert_path_missing() {
  local path="$1"
  if [[ -e "$path" ]]; then
    fail "expected path to be absent: $path"
    return 1
  fi
  return 0
}

run_test() {
  local test_name="$1"
  local status=0

  set +e
  (
    set -e
    "$test_name"
  )
  status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    echo "ok - ${test_name}"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "not ok - ${test_name}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

test_minimal_full_project_flow() {
  local workdir project_dir skill_dir
  workdir=$(make_temp_dir)
  project_dir="${workdir}/project"
  skill_dir="${project_dir}/.cursor/skills/specanchor"

  copy_example "minimal-full-project" "$project_dir"
  install_skill "$project_dir" "$skill_dir"

  capture_cmd "$project_dir" env SPECANCHOR_SKILL_DIR="$skill_dir" bash "$skill_dir/scripts/specanchor-init.sh" --project=minimal-full-project --mode=full
  assert_eq "$CAPTURE_STATUS" "0"
  assert_file_exists "${project_dir}/anchor.yaml"
  assert_file_exists "${project_dir}/.specanchor/global/architecture.spec.md"
  assert_file_exists "${project_dir}/.specanchor/global/coding-standards.spec.md"
  assert_file_exists "${project_dir}/.specanchor/global/project-setup.spec.md"
  assert_file_exists "${project_dir}/.specanchor/module-index.md"
  assert_file_exists "${project_dir}/.specanchor/project-codemap.md"

  capture_cmd "$project_dir" env SPECANCHOR_SKILL_DIR="$skill_dir" bash "$skill_dir/scripts/specanchor-boot.sh" --format=summary
  assert_eq "$CAPTURE_STATUS" "0"
  assert_contains "$CAPTURE_OUTPUT" 'SpecAnchor Boot [full]'
  assert_not_contains "$CAPTURE_OUTPUT" '✗'

  capture_cmd "$project_dir" bash "$skill_dir/scripts/specanchor-doctor.sh" --strict
  assert_eq "$CAPTURE_STATUS" "0"
  assert_contains "$CAPTURE_OUTPUT" 'SpecAnchor Doctor [ok]'

  capture_cmd "$project_dir" bash "$skill_dir/scripts/specanchor-validate.sh" --format=summary
  assert_eq "$CAPTURE_STATUS" "0"
  assert_contains "$CAPTURE_OUTPUT" 'SpecAnchor Validate [ok]'
}

test_parasitic_openspec_project_flow() {
  local workdir project_dir skill_dir out_file
  workdir=$(make_temp_dir)
  project_dir="${workdir}/project"
  skill_dir="${project_dir}/.cursor/skills/specanchor"
  out_file="${workdir}/resolve.json"

  copy_example "parasitic-openspec-project" "$project_dir"
  install_skill "$project_dir" "$skill_dir"

  capture_cmd "$project_dir" env SPECANCHOR_SKILL_DIR="$skill_dir" bash "$skill_dir/scripts/specanchor-boot.sh" --format=summary
  assert_eq "$CAPTURE_STATUS" "0"
  assert_contains "$CAPTURE_OUTPUT" 'SpecAnchor Boot [parasitic]'
  assert_contains "$CAPTURE_OUTPUT" 'specs/ [openspec]'

  capture_cmd "$project_dir" bash "$skill_dir/scripts/specanchor-doctor.sh" --strict
  assert_eq "$CAPTURE_STATUS" "0"
  assert_contains "$CAPTURE_OUTPUT" 'SpecAnchor Doctor [ok]'

  capture_cmd "$project_dir" bash "$skill_dir/scripts/specanchor-resolve.sh" --files="src/auth/login.md" --intent="change login behavior" --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" '"status": "ok"'
  assert_contains "$CAPTURE_OUTPUT" '"path":"specs/auth.md"'
  assert_path_missing "${project_dir}/.specanchor"
}

test_installed_skill_excludes_dev_only_files() {
  local workdir project_dir skill_dir
  workdir=$(make_temp_dir)
  project_dir="${workdir}/consumer-project"
  skill_dir="${project_dir}/.cursor/skills/specanchor"

  mkdir -p "$project_dir"
  install_skill "$project_dir" "$skill_dir"

  assert_path_missing "${skill_dir}/tests"
  assert_path_missing "${skill_dir}/.github"
  assert_path_missing "${skill_dir}/.specanchor"
  assert_path_missing "${skill_dir}/.git"
  assert_file_exists "${skill_dir}/scripts/specanchor-init.sh"
  assert_file_exists "${skill_dir}/examples/minimal-full-project/README.md"
}

test_readme_quick_start_equivalent() {
  local workdir project_dir skill_dir
  workdir=$(make_temp_dir)
  project_dir="${workdir}/project"
  skill_dir="${project_dir}/.cursor/skills/specanchor"

  copy_example "minimal-full-project" "$project_dir"
  install_skill "$project_dir" "$skill_dir"

  capture_cmd "$project_dir" env SPECANCHOR_SKILL_DIR="$skill_dir" bash "$skill_dir/scripts/specanchor-init.sh" --project="$(basename "$project_dir")" --mode=full
  assert_eq "$CAPTURE_STATUS" "0"

  capture_cmd "$project_dir" env SPECANCHOR_SKILL_DIR="$skill_dir" bash "$skill_dir/scripts/specanchor-boot.sh" --format=summary
  assert_eq "$CAPTURE_STATUS" "0"
  assert_contains "$CAPTURE_OUTPUT" 'SpecAnchor Boot [full]'
  assert_not_contains "$CAPTURE_OUTPUT" '✗'
}

echo "=== SpecAnchor Usage Proof Tests ==="

run_test test_minimal_full_project_flow
run_test test_parasitic_openspec_project_flow
run_test test_installed_skill_excludes_dev_only_files
run_test test_readme_quick_start_equivalent

echo ""
echo "Summary: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
