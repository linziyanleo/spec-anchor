#!/usr/bin/env bash
# Agent reliability regression tests for SpecAnchor beta.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/agent-reliability"

# shellcheck source=tests/helpers/assert.sh
source "${SCRIPT_DIR}/helpers/assert.sh"
# shellcheck source=tests/helpers/golden.sh
source "${SCRIPT_DIR}/helpers/golden.sh"

TMP_DIRS=()
PASS_COUNT=0
FAIL_COUNT=0
CAPTURE_OUTPUT=""
CAPTURE_STATUS=0

cleanup() {
  local path=""
  set +e
  for path in "${TMP_DIRS[@]:-}"; do
    [[ -n "$path" ]] && rm -rf "$path" 2>/dev/null
  done
}
trap cleanup EXIT

make_temp_dir() {
  local dir
  dir=$(mktemp -d)
  TMP_DIRS+=("$dir")
  printf '%s\n' "$dir"
}

copy_fixture() {
  local fixture_name="$1"
  local target_dir="$2"
  mkdir -p "$target_dir"
  cp -R "${FIXTURE_ROOT}/${fixture_name}/." "$target_dir/"
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

init_git_repo() {
  local workdir="$1"
  (
    cd "$workdir"
    git init >/dev/null
    git config user.name "SpecAnchor Fixture"
    git config user.email "fixture@example.com"
    git add .
    git commit -m "base" >/dev/null
    git branch -M main
    git checkout -b feature >/dev/null
  )
}

test_resolve_v2_root_json() {
  local out_file
  out_file=$(make_temp_dir)/resolve-root.json
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-resolve.sh" --files "scripts/specanchor-boot.sh,references/commands/check.md" --intent "make boot JSON stable and add tests" --budget=normal --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" '"schema_version": "specanchor.resolve.v2"'
  assert_contains "$CAPTURE_OUTPUT" '.specanchor/modules/scripts.spec.md'
  assert_contains "$CAPTURE_OUTPUT" '.specanchor/modules/references.spec.md'
  assert_contains "$CAPTURE_OUTPUT" '"profile": "normal"'
}

test_resolve_unknown_missing_warning() {
  local out_file
  out_file=$(make_temp_dir)/resolve-missing.json
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-resolve.sh" --files "unknown/place.txt" --intent "mystery change" --budget=compact --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" '"status": "warning"'
  assert_contains "$CAPTURE_OUTPUT" '"type":"module_spec"'
  assert_contains "$CAPTURE_OUTPUT" '"path":"unknown/place.txt"'
}

test_resolve_intent_only_is_low_confidence() {
  local out_file
  out_file=$(make_temp_dir)/resolve-intent-only.json
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-resolve.sh" --files "unknown/feature.txt" --intent "references protocol cleanup" --budget=normal --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" '"match_type": "intent_keyword"'
  assert_contains "$CAPTURE_OUTPUT" '"confidence": 0.50'
}

test_resolve_parasitic_fixture() {
  local workdir out_file
  workdir=$(make_temp_dir)
  out_file="${workdir}/resolve-parasitic.json"
  copy_fixture "resolve-v2/parasitic-source" "$workdir"
  capture_cmd "$workdir" bash "$REPO_ROOT/scripts/specanchor-resolve.sh" --files "src/auth/login.md" --intent "change login behavior" --budget=normal --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" '"mode": "parasitic"'
  assert_contains "$CAPTURE_OUTPUT" '"path": "specs/auth.md"'
}

test_resolve_diff_from_fixture() {
  local workdir out_file
  workdir=$(make_temp_dir)
  out_file="${workdir}/resolve-diff.json"
  copy_fixture "resolve-v2/diff-repo" "$workdir"
  init_git_repo "$workdir"
  printf '\necho "changed"\n' >> "${workdir}/scripts/example.sh"
  (
    cd "$workdir"
    git add scripts/example.sh
    git commit -m "change" >/dev/null
  )

  capture_cmd "$workdir" bash "$REPO_ROOT/scripts/specanchor-resolve.sh" --diff-from=main --budget=normal --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" '"files": ["scripts/example.sh"]'
  assert_contains "$CAPTURE_OUTPUT" '.specanchor/modules/scripts.spec.md'
}

test_assemble_root_json() {
  local out_file
  out_file=$(make_temp_dir)/assemble-root.json
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-assemble.sh" --files "scripts/specanchor-boot.sh" --intent "debug startup" --budget=normal --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" '"schema_version": "specanchor.assembly.v1"'
  assert_contains "$CAPTURE_OUTPUT" '"path":".specanchor/modules/scripts.spec.md"'
  assert_contains "$CAPTURE_OUTPUT" '"module": "full"'
}

test_assemble_markdown_missing() {
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-assemble.sh" --files "unknown/path.ts" --intent "new feature" --budget=compact --format=markdown
  assert_eq "$CAPTURE_STATUS" "0"
  assert_contains "$CAPTURE_OUTPUT" 'Assembly Trace:'
  assert_contains "$CAPTURE_OUTPUT" 'Missing: 1'
  assert_contains "$CAPTURE_OUTPUT" 'Missing coverage exists.'
}

test_assemble_resolve_json_input() {
  local workdir resolve_file out_file
  workdir=$(make_temp_dir)
  resolve_file="${workdir}/resolve.json"
  out_file="${workdir}/assembly.json"
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-resolve.sh" --files "references/commands/check.md" --intent "fix command docs" --budget=normal --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$resolve_file"

  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-assemble.sh" --resolve-json "$resolve_file" --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" '.specanchor/modules/references.spec.md'
}

test_assemble_write_trace() {
  local workdir trace_file
  workdir=$(make_temp_dir)
  trace_file="${workdir}/trace.json"
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-assemble.sh" --files "scripts/specanchor-boot.sh" --intent "debug startup" --write-trace "$trace_file" --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  assert_file_exists "$trace_file"
  assert_valid_json "$trace_file"
}

test_doctor_agent_profile_json() {
  local out_file
  out_file=$(make_temp_dir)/doctor-agent.json
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-doctor.sh" --format=json --profile=agent
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" '"profile": "agent"'
  assert_contains "$CAPTURE_OUTPUT" '"status": "ok"'
}

test_doctor_release_profile_missing_note() {
  local workdir repo_dir out_file current_version
  workdir=$(make_temp_dir)
  repo_dir="${workdir}/repo"
  mkdir -p "$repo_dir"
  rsync -a --exclude .git "${REPO_ROOT}/" "$repo_dir/"
  current_version=$(awk -F'"' '/version:/ {print $2; exit}' "${repo_dir}/anchor.yaml")
  rm -f "${repo_dir}/docs/release/v${current_version}.md"

  out_file="${workdir}/doctor-release.json"
  capture_cmd "$repo_dir" bash "${repo_dir}/scripts/specanchor-doctor.sh" --format=json --profile=release
  assert_eq "$CAPTURE_STATUS" "2"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" 'RELEASE_NOTE_MISSING'
}

test_validate_root_json() {
  local out_file
  out_file=$(make_temp_dir)/validate-root.json
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-validate.sh" --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" '"status": "ok"'
}

test_validate_invalid_resolve_json() {
  local workdir invalid_file out_file
  workdir=$(make_temp_dir)
  invalid_file="${workdir}/invalid-resolve.json"
  out_file="${workdir}/validate-invalid-resolve.json"
  cat >"$invalid_file" <<'EOF'
{"schema_version":"specanchor.resolve.v2","status":"ok"}
EOF
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-validate.sh" --path "$invalid_file" --format=json
  assert_eq "$CAPTURE_STATUS" "2"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" 'JSON_SCHEMA_INVALID'
}

test_validate_invalid_assembly_json() {
  local workdir invalid_file out_file
  workdir=$(make_temp_dir)
  invalid_file="${workdir}/invalid-assembly.json"
  out_file="${workdir}/validate-invalid-assembly.json"
  cat >"$invalid_file" <<'EOF'
{"schema_version":"specanchor.assembly.v1","status":"ok"}
EOF
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-validate.sh" --path "$invalid_file" --format=json
  assert_eq "$CAPTURE_STATUS" "2"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" 'JSON_SCHEMA_INVALID'
}

test_hygiene_root_json() {
  local out_file
  out_file=$(make_temp_dir)/hygiene-root.json
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-hygiene.sh" --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" '"schema_version": "specanchor.hygiene.v1"'
}

test_hygiene_duplicate_modules_fixture() {
  local workdir out_file
  workdir=$(make_temp_dir)
  out_file="${workdir}/hygiene-duplicate.json"
  copy_fixture "hygiene/duplicate-modules" "$workdir"
  capture_cmd "$workdir" bash "$REPO_ROOT/scripts/specanchor-hygiene.sh" --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" 'DUPLICATE_MODULE_PATH'
}

test_hygiene_dead_links_fixture() {
  local workdir out_file
  workdir=$(make_temp_dir)
  out_file="${workdir}/hygiene-dead-links.json"
  copy_fixture "hygiene/dead-links" "$workdir"
  capture_cmd "$workdir" bash "$REPO_ROOT/scripts/specanchor-hygiene.sh" --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" 'DEAD_LINK'
}

test_hygiene_fix_generated_fixture() {
  local workdir out_file
  workdir=$(make_temp_dir)
  out_file="${workdir}/hygiene-fix-generated.json"
  copy_fixture "hygiene/fix-generated" "$workdir"
  rm -f "${workdir}/.specanchor/spec-index.md" "${workdir}/.specanchor/module-index.md"
  capture_cmd "$workdir" bash "$REPO_ROOT/scripts/specanchor-hygiene.sh" --fix-generated --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_file_exists "${workdir}/.specanchor/spec-index.md"
}

test_golden_replay_outputs() {
  local workdir resolve_actual assembly_actual
  workdir=$(make_temp_dir)

  resolve_actual="${workdir}/scripts-change.resolve.json"
  assembly_actual="${workdir}/scripts-change.assembly.json"
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-resolve.sh" --files "scripts/specanchor-boot.sh" --intent "debug startup" --budget=normal --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$resolve_actual"
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-assemble.sh" --files "scripts/specanchor-boot.sh" --intent "debug startup" --budget=normal --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$assembly_actual"

  assert_json_golden "$resolve_actual" "${FIXTURE_ROOT}/replay/scripts-change.resolve.golden.json"
  assert_json_golden "$assembly_actual" "${FIXTURE_ROOT}/replay/scripts-change.assembly.golden.json"

  resolve_actual="${workdir}/references-change.resolve.json"
  assembly_actual="${workdir}/references-change.assembly.json"
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-resolve.sh" --files "references/commands/check.md" --intent "fix command docs" --budget=normal --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$resolve_actual"
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-assemble.sh" --files "references/commands/check.md" --intent "fix command docs" --budget=normal --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$assembly_actual"

  assert_json_golden "$resolve_actual" "${FIXTURE_ROOT}/replay/references-change.resolve.golden.json"
  assert_json_golden "$assembly_actual" "${FIXTURE_ROOT}/replay/references-change.assembly.golden.json"
}

echo "=== SpecAnchor Agent Reliability Tests ==="

run_test test_resolve_v2_root_json
run_test test_resolve_unknown_missing_warning
run_test test_resolve_intent_only_is_low_confidence
run_test test_resolve_parasitic_fixture
run_test test_resolve_diff_from_fixture
run_test test_assemble_root_json
run_test test_assemble_markdown_missing
run_test test_assemble_resolve_json_input
run_test test_assemble_write_trace
run_test test_doctor_agent_profile_json
run_test test_doctor_release_profile_missing_note
run_test test_validate_root_json
run_test test_validate_invalid_resolve_json
run_test test_validate_invalid_assembly_json
run_test test_hygiene_root_json
run_test test_hygiene_duplicate_modules_fixture
run_test test_hygiene_dead_links_fixture
run_test test_hygiene_fix_generated_fixture
run_test test_golden_replay_outputs

echo ""
echo "Summary: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
