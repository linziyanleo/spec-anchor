#!/usr/bin/env bash
# tests/run_all.sh — 一键运行所有 bats 测试
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== SpecAnchor Regression Tests ==="
echo ""

bats "${SCRIPT_DIR}"/test_*.bats "$@"
