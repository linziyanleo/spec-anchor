#!/usr/bin/env bash

# shellcheck source=tests/helpers/assert.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/assert.sh"

# Normalize volatile JSON fields (e.g. `freshness` flips between fresh/drifted
# depending on `git log --since=last_synced` against the current HEAD; not a
# stable invariant for replay-style golden comparisons).
_golden_normalize() {
  python3 - "$1" <<'PY'
import json, sys
VOLATILE = {"freshness", "generated_at"}
def normalize(obj):
    if isinstance(obj, dict):
        for k in list(obj.keys()):
            if k in VOLATILE:
                obj[k] = "<NORMALIZED>"
            else:
                normalize(obj[k])
    elif isinstance(obj, list):
        for item in obj:
            normalize(item)
with open(sys.argv[1]) as fh:
    data = json.load(fh)
normalize(data)
json.dump(data, sys.stdout, indent=4, sort_keys=True)
PY
}

assert_json_golden() {
  local actual_file="$1"
  local golden_file="$2"
  local actual_pretty golden_pretty

  actual_pretty=$(mktemp)
  golden_pretty=$(mktemp)

  _golden_normalize "$actual_file" >"$actual_pretty" 2>/dev/null || {
    rm -f "$actual_pretty" "$golden_pretty"
    fail "invalid JSON for actual golden comparison: $actual_file"
    return 1
  }
  _golden_normalize "$golden_file" >"$golden_pretty" 2>/dev/null || {
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
