#!/usr/bin/env bash
# tests/run_all.sh — run public shell regressions; opt into legacy bats explicitly
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== SpecAnchor Regression Tests ==="
echo ""

bash "${SCRIPT_DIR}/run.sh" "$@"

if [[ "${SPECANCHOR_RUN_BATS:-0}" == "1" ]] && compgen -G "${SCRIPT_DIR}/test_*.bats" >/dev/null; then
  if ! command -v bats >/dev/null 2>&1; then
    echo "error: bats is required to run tests/run_all.sh when test_*.bats files exist" >&2
    exit 1
  fi
  echo ""
  echo "=== Legacy Bats Suites ==="
  bats "${SCRIPT_DIR}"/test_*.bats "$@"
fi
