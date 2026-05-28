#!/usr/bin/env bats
# tests/test_hook_boot_failure.bats — Hook behavior when boot fails

load setup_helper

setup() {
  create_sandbox
  cat > "${SANDBOX}/anchor.yaml" <<'YAML'
specanchor:
  version: "0.5.0"
  project_name: "bad-project"
  mode: "full"
  paths:
    global_specs: ".specanchor/global/"
    spec_index: ".specanchor/spec-index.md"
YAML
  # Make the boot script unreachable by overriding PLUGIN_ROOT to a broken path
  BROKEN_PLUGIN="$(mktemp -d)"
  mkdir -p "$BROKEN_PLUGIN/hooks"
  mkdir -p "$BROKEN_PLUGIN/scripts"
  # Create a boot script that always fails
  cat > "$BROKEN_PLUGIN/scripts/specanchor-boot.sh" <<'SH'
#!/usr/bin/env bash
echo "fatal: corrupted config" >&2
exit 1
SH
  chmod +x "$BROKEN_PLUGIN/scripts/specanchor-boot.sh"
  # Copy the real hook but it will call the broken boot
  cp "${PROJECT_ROOT}/hooks/session-start" "$BROKEN_PLUGIN/hooks/session-start"
}

teardown() {
  rm -rf "$SANDBOX" "$BROKEN_PLUGIN"
}

@test "hook exits 0 even when boot fails" {
  cd "$SANDBOX"
  run env CLAUDE_PLUGIN_ROOT="$BROKEN_PLUGIN" bash "${BROKEN_PLUGIN}/hooks/session-start"
  [ "$status" -eq 0 ]
}

@test "hook outputs valid JSON when boot fails" {
  cd "$SANDBOX"
  run env CLAUDE_PLUGIN_ROOT="$BROKEN_PLUGIN" bash "${BROKEN_PLUGIN}/hooks/session-start"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}

@test "hook includes error indicator when boot fails" {
  cd "$SANDBOX"
  run env CLAUDE_PLUGIN_ROOT="$BROKEN_PLUGIN" bash "${BROKEN_PLUGIN}/hooks/session-start"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ctx = d['hookSpecificOutput']['additionalContext']
assert 'Boot failed' in ctx or 'status' in ctx, f'missing error indicator in context'
"
}
