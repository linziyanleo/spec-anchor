#!/usr/bin/env bash

# shellcheck source=tests/helpers/assert.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/assert.sh"

assert_json_golden() {
  local actual_file="$1"
  local golden_file="$2"
  local actual_pretty golden_pretty

  actual_pretty=$(mktemp)
  golden_pretty=$(mktemp)

  python3 -m json.tool "$actual_file" >"$actual_pretty" || {
    rm -f "$actual_pretty" "$golden_pretty"
    fail "invalid JSON for actual golden comparison: $actual_file"
    return 1
  }
  python3 -m json.tool "$golden_file" >"$golden_pretty" || {
    rm -f "$actual_pretty" "$golden_pretty"
    fail "invalid JSON for golden file: $golden_file"
    return 1
  }

  if ! diff -u "$golden_pretty" "$actual_pretty" >/dev/null 2>&1; then
    diff -u "$golden_pretty" "$actual_pretty" >&2 || true
    rm -f "$actual_pretty" "$golden_pretty"
    fail "golden mismatch: $actual_file"
    return 1
  fi

  rm -f "$actual_pretty" "$golden_pretty"
  return 0
}
