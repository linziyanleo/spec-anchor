#!/usr/bin/env bash
# Portable public shell test runner for SpecAnchor.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures"

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

checksum_file() {
  cksum "$1" | awk '{print $1 ":" $2}'
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

test_repo_boot_json() {
  local out_file
  out_file=$(make_temp_dir)/boot.json
  capture_cmd "$REPO_ROOT" env SPECANCHOR_SKILL_DIR="$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-boot.sh" --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" '"project_name": "spec-anchor"'
  assert_contains "$CAPTURE_OUTPUT" '"mode": "full"'
}

test_repo_boot_summary_has_no_missing_sources() {
  capture_cmd "$REPO_ROOT" env SPECANCHOR_SKILL_DIR="$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-boot.sh" --format=summary
  assert_eq "$CAPTURE_STATUS" "0"
  assert_contains "$CAPTURE_OUTPUT" 'SpecAnchor Boot [full]'
  assert_not_contains "$CAPTURE_OUTPUT" '✗'
}

test_repo_doctor_strict_ok() {
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-doctor.sh" --strict
  assert_eq "$CAPTURE_STATUS" "0"
  assert_contains "$CAPTURE_OUTPUT" 'SpecAnchor Doctor [ok]'
}

test_fixture_boot_full_summary() {
  local workdir
  workdir=$(make_temp_dir)
  copy_fixture "full-minimal" "$workdir"
  capture_cmd "$workdir" env SPECANCHOR_SKILL_DIR="$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-boot.sh" --format=summary
  assert_eq "$CAPTURE_STATUS" "0"
  assert_contains "$CAPTURE_OUTPUT" 'SpecAnchor Boot [full]'
  assert_contains "$CAPTURE_OUTPUT" 'Global Specs:'
}

test_full_mode_missing_specanchor_fails() {
  local workdir
  workdir=$(make_temp_dir)
  copy_fixture "full-missing-specanchor" "$workdir"
  capture_cmd "$workdir" env SPECANCHOR_SKILL_DIR="$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-boot.sh" --format=summary
  assert_eq "$CAPTURE_STATUS" "1"
  assert_contains "$CAPTURE_OUTPUT" '.specanchor/'
  assert_contains "$CAPTURE_OUTPUT" 'full'
}

test_parasitic_mode_without_specanchor_passes() {
  local workdir
  workdir=$(make_temp_dir)
  copy_fixture "parasitic-with-sources" "$workdir"
  capture_cmd "$workdir" env SPECANCHOR_SKILL_DIR="$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-boot.sh" --format=summary
  assert_eq "$CAPTURE_STATUS" "0"
  assert_contains "$CAPTURE_OUTPUT" 'SpecAnchor Boot [parasitic]'
  assert_contains "$CAPTURE_OUTPUT" 'Sources:'
}

test_overlay_boot_merges_sources_and_fields() {
  local workdir
  workdir=$(make_temp_dir)
  copy_fixture "overlay-local-config" "$workdir"
  capture_cmd "$workdir" env SPECANCHOR_SKILL_DIR="$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-boot.sh" --format=summary
  assert_eq "$CAPTURE_STATUS" "0"
  assert_contains "$CAPTURE_OUTPUT" 'SpecAnchor Boot [parasitic]'
  assert_contains "$CAPTURE_OUTPUT" 'anchor.yaml + anchor.local.yaml'
  assert_contains "$CAPTURE_OUTPUT" 'project: local-project'
  assert_contains "$CAPTURE_OUTPUT" 'base-specs [base]'
  assert_contains "$CAPTURE_OUTPUT" 'local-specs [local]'
  assert_not_contains "$CAPTURE_OUTPUT" '✗'
}

test_overlay_status_and_check_use_local_thresholds() {
  local workdir out_file
  workdir=$(make_temp_dir)
  out_file="${workdir}/status.json"
  copy_fixture "overlay-local-config" "$workdir"

  capture_cmd "$workdir" bash "$REPO_ROOT/scripts/specanchor-status.sh" --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" '"stale_days": 3'
  assert_contains "$CAPTURE_OUTPUT" '"outdated_days": 30'

  capture_cmd "$workdir" bash "$REPO_ROOT/scripts/specanchor-check.sh" global
  assert_eq "$CAPTURE_STATUS" "0"
  assert_contains "$CAPTURE_OUTPUT" 'stale_days=3'
  assert_contains "$CAPTURE_OUTPUT" 'warn_recent_days=1'
}

test_overlay_resolve_uses_local_sources() {
  local workdir out_file
  workdir=$(make_temp_dir)
  out_file="${workdir}/resolve-overlay.json"
  copy_fixture "overlay-local-config" "$workdir"

  capture_cmd "$workdir" bash "$REPO_ROOT/scripts/specanchor-resolve.sh" --files "local-specs/example.md" --intent "inspect overlay source" --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" 'local-specs'
}

test_legacy_config_fallback() {
  local workdir
  workdir=$(make_temp_dir)
  copy_fixture "legacy-config" "$workdir"
  capture_cmd "$workdir" env SPECANCHOR_SKILL_DIR="$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-boot.sh" --format=summary
  assert_eq "$CAPTURE_STATUS" "0"
  assert_contains "$CAPTURE_OUTPUT" '.specanchor/config.yaml'
  assert_contains "$CAPTURE_OUTPUT" '建议迁移到根目录 anchor.yaml'
}

test_frontmatter_injection_is_idempotent() {
  local workdir file before mid after
  workdir=$(make_temp_dir)
  copy_fixture "frontmatter-idempotent" "$workdir"
  file="${workdir}/specs/example.md"
  before=$(checksum_file "$file")

  capture_cmd "$workdir" bash "$REPO_ROOT/scripts/frontmatter-inject.sh" specs/example.md
  assert_eq "$CAPTURE_STATUS" "0"
  mid=$(checksum_file "$file")
  assert_ne "$mid" "$before"

  capture_cmd "$workdir" bash "$REPO_ROOT/scripts/frontmatter-inject.sh" specs/example.md
  assert_eq "$CAPTURE_STATUS" "0"
  after=$(checksum_file "$file")
  assert_eq "$after" "$mid"
}

test_status_json_root() {
  local out_file
  out_file=$(make_temp_dir)/status.json
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-status.sh" --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" '"module_specs"'
}

test_doctor_root_json() {
  local out_file
  out_file=$(make_temp_dir)/doctor-root.json
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-doctor.sh" --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" '"status": "ok"'
}

test_doctor_missing_specanchor_errors() {
  local workdir out_file
  workdir=$(make_temp_dir)
  out_file="${workdir}/doctor.json"
  copy_fixture "full-missing-specanchor" "$workdir"
  capture_cmd "$workdir" bash "$REPO_ROOT/scripts/specanchor-doctor.sh" --format=json
  assert_eq "$CAPTURE_STATUS" "2"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" 'FULL_MODE_SPECANCHOR_MISSING'
}

test_doctor_warns_on_global_markdown_ignore() {
  local workdir out_file
  workdir=$(make_temp_dir)
  out_file="${workdir}/doctor-warning.json"
  copy_fixture "full-minimal" "$workdir"
  cp "${FIXTURE_ROOT}/full-minimal-markdown-ignore/anchor.yaml" "${workdir}/anchor.yaml"
  capture_cmd "$workdir" bash "$REPO_ROOT/scripts/specanchor-doctor.sh" --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" 'COVERAGE_MARKDOWN_IGNORED'
  assert_contains "$CAPTURE_OUTPUT" '"status": "warning"'
}

test_resolve_known_files() {
  local out_file
  out_file=$(make_temp_dir)/resolve-ok.json
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-resolve.sh" --files "scripts/specanchor-boot.sh,references/commands/check.md" --intent "make boot JSON stable and add tests" --budget=normal --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" '"schema_version": "specanchor.resolve.v2"'
  assert_contains "$CAPTURE_OUTPUT" '.specanchor/modules/scripts.spec.md'
  assert_contains "$CAPTURE_OUTPUT" '.specanchor/modules/references.spec.md'
}

test_resolve_unknown_file_warns() {
  local out_file
  out_file=$(make_temp_dir)/resolve-warning.json
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-resolve.sh" --files "unknown/place.txt" --intent "mystery change" --budget=compact --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" '"status": "warning"'
  assert_contains "$CAPTURE_OUTPUT" '"type":"module_spec"'
  assert_contains "$CAPTURE_OUTPUT" '"path":"unknown/place.txt"'
}

test_validate_json_root() {
  local out_file
  out_file=$(make_temp_dir)/validate.json
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-validate.sh" --format=json
  assert_eq "$CAPTURE_STATUS" "0"
  printf '%s\n' "$CAPTURE_OUTPUT" >"$out_file"
  assert_valid_json "$out_file"
  assert_contains "$CAPTURE_OUTPUT" '"status": "ok"'
}

test_skill_entrypoint_checks() {
  local skill_lines
  skill_lines=$(wc -l < "${REPO_ROOT}/SKILL.md" | tr -d ' ')
  grep -q "specanchor-boot.sh" "${REPO_ROOT}/SKILL.md"
  grep -q "specanchor-assemble.sh" "${REPO_ROOT}/SKILL.md"
  grep -q "references/commands-quickref.md" "${REPO_ROOT}/SKILL.md"
  grep -q "Assembly Trace" "${REPO_ROOT}/SKILL.md"
  grep -q "references/agents/agent-contract.md" "${REPO_ROOT}/SKILL.md"
  if [[ "$skill_lines" -gt 140 ]]; then
    echo "note: SKILL.md is ${skill_lines} lines; above target but allowed if behavior is preserved"
  fi
}

test_repo_docs_entrypoints_are_consistent() {
  local anchor_contents readme_en readme_zh why_en why_zh
  anchor_contents=$(cat "${REPO_ROOT}/anchor.yaml")
  readme_en=$(cat "${REPO_ROOT}/README.md")
  readme_zh=$(cat "${REPO_ROOT}/README_ZH.md")
  why_en=$(cat "${REPO_ROOT}/WHY.md")
  why_zh=$(cat "${REPO_ROOT}/WHY_ZH.md")

  assert_contains "$anchor_contents" '"WHY.md"'
  assert_contains "$anchor_contents" '"WHY_ZH.md"'
  assert_not_contains "$anchor_contents" '"WHY_EN.md"'

  assert_contains "$readme_en" '<a href="WHY.md">WHY</a>'
  assert_contains "$readme_zh" '<a href="WHY_ZH.md">为什么需要</a>'
  assert_contains "$why_en" '[中文](WHY_ZH.md)'
  assert_contains "$why_zh" '[English](WHY.md)'
}

test_release_metadata_is_aligned() {
  local anchor_contents readme_en readme_zh changelog settings
  anchor_contents=$(cat "${REPO_ROOT}/anchor.yaml")
  readme_en=$(cat "${REPO_ROOT}/README.md")
  readme_zh=$(cat "${REPO_ROOT}/README_ZH.md")
  changelog=$(cat "${REPO_ROOT}/CHANGELOG.md")
  settings=$(cat "${REPO_ROOT}/.github/settings.yml")

  assert_contains "$anchor_contents" 'version: "0.4.0-beta"'
  assert_contains "$readme_en" 'badge/version-0.4.0--beta-brightgreen.svg'
  assert_contains "$readme_en" 'actions/workflows/ci.yml/badge.svg'
  assert_contains "$readme_en" '[docs/USAGE_PROOF.md](docs/USAGE_PROOF.md)'
  assert_contains "$readme_en" '[examples/minimal-full-project/](examples/minimal-full-project/)'
  assert_contains "$readme_en" '[docs/agent-reliability.md](docs/agent-reliability.md)'
  assert_contains "$readme_en" '[references/agents/agent-contract.md](references/agents/agent-contract.md)'
  assert_contains "$readme_zh" '[`docs/USAGE_PROOF.md`](docs/USAGE_PROOF.md)'
  assert_contains "$readme_zh" '[`docs/agent-reliability.md`](docs/agent-reliability.md)'
  assert_contains "$changelog" '## v0.4.0-beta — Agent Reliability'
  assert_contains "$changelog" '## v0.4.0-alpha.2 — Usage Proof'
  assert_file_exists "${REPO_ROOT}/docs/USAGE_PROOF.md"
  assert_file_exists "${REPO_ROOT}/docs/agent-reliability.md"
  assert_file_exists "${REPO_ROOT}/docs/release/v0.4.0-beta.md"
  assert_file_exists "${REPO_ROOT}/docs/release/v0.4.0-alpha.2.md"
  assert_file_exists "${REPO_ROOT}/references/agents/agent-contract.md"
  assert_file_exists "${REPO_ROOT}/references/agents/claude-code.md"
  assert_file_exists "${REPO_ROOT}/references/agents/codex.md"
  assert_file_exists "${REPO_ROOT}/references/agents/cursor.md"
  assert_contains "$settings" 'Spec governance and anti-decay layer for AI coding agents.'
  assert_contains "$settings" 'ai-coding'
  assert_contains "$settings" 'spec-driven-development'
}

test_consumer_install_smoke() {
  local workdir project_dir skill_dir
  workdir=$(make_temp_dir)
  project_dir="${workdir}/consumer-project"
  skill_dir="${project_dir}/.cursor/skills/specanchor"
  mkdir -p "$skill_dir"

  rsync -a --exclude-from="${REPO_ROOT}/.skillexclude" "${REPO_ROOT}/" "${skill_dir}/"

  capture_cmd "$project_dir" env SPECANCHOR_SKILL_DIR="$skill_dir" bash "$skill_dir/scripts/specanchor-init.sh" --project=demo --mode=full
  assert_eq "$CAPTURE_STATUS" "0"
  assert_file_exists "${project_dir}/anchor.yaml"
  assert_file_exists "${project_dir}/.specanchor/module-index.md"

  capture_cmd "$project_dir" env SPECANCHOR_SKILL_DIR="$skill_dir" bash "$skill_dir/scripts/specanchor-boot.sh" --format=summary
  assert_eq "$CAPTURE_STATUS" "0"
  assert_contains "$CAPTURE_OUTPUT" 'SpecAnchor Boot [full]'
  assert_not_contains "$CAPTURE_OUTPUT" '✗'
}

test_usage_proof_suite() {
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/tests/test_usage_proof.sh"
  if [[ "$CAPTURE_STATUS" != "0" ]]; then
    printf '%s\n' "$CAPTURE_OUTPUT"
  fi
  assert_eq "$CAPTURE_STATUS" "0"
  assert_contains "$CAPTURE_OUTPUT" 'SpecAnchor Usage Proof Tests'
  assert_contains "$CAPTURE_OUTPUT" 'Summary: 4 passed, 0 failed'
}

test_agent_reliability_suite() {
  capture_cmd "$REPO_ROOT" bash "$REPO_ROOT/tests/test_agent_reliability.sh"
  if [[ "$CAPTURE_STATUS" != "0" ]]; then
    printf '%s\n' "$CAPTURE_OUTPUT"
  fi
  assert_eq "$CAPTURE_STATUS" "0"
  assert_contains "$CAPTURE_OUTPUT" 'SpecAnchor Agent Reliability Tests'
}

echo "=== SpecAnchor Public Shell Tests ==="

run_test test_repo_boot_json
run_test test_repo_boot_summary_has_no_missing_sources
run_test test_repo_doctor_strict_ok
run_test test_fixture_boot_full_summary
run_test test_full_mode_missing_specanchor_fails
run_test test_parasitic_mode_without_specanchor_passes
run_test test_overlay_boot_merges_sources_and_fields
run_test test_overlay_status_and_check_use_local_thresholds
run_test test_overlay_resolve_uses_local_sources
run_test test_legacy_config_fallback
run_test test_frontmatter_injection_is_idempotent
run_test test_status_json_root
run_test test_doctor_root_json
run_test test_doctor_missing_specanchor_errors
run_test test_doctor_warns_on_global_markdown_ignore
run_test test_resolve_known_files
run_test test_resolve_unknown_file_warns
run_test test_validate_json_root
run_test test_skill_entrypoint_checks
run_test test_repo_docs_entrypoints_are_consistent
run_test test_release_metadata_is_aligned
run_test test_consumer_install_smoke
run_test test_usage_proof_suite
run_test test_agent_reliability_suite

echo ""
echo "Summary: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
