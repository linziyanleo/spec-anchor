#!/usr/bin/env bats
# tests/test_hook_session_start.bats — SessionStart hook JSON output validation

load setup_helper

setup() {
  create_sandbox
  cat > "${SANDBOX}/anchor.yaml" <<'YAML'
specanchor:
  version: "0.5.0"
  project_name: "hook-test"
  mode: "full"
  paths:
    global_specs: ".specanchor/global/"
    module_specs: ".specanchor/modules/"
    task_specs: ".specanchor/tasks/"
    spec_index: ".specanchor/spec-index.md"
YAML
}

teardown() {
  rm -rf "$SANDBOX"
}

@test "hook outputs valid JSON for Claude Code env" {
  cd "$SANDBOX"
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "${PROJECT_ROOT}/hooks/session-start"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null
}

@test "hook outputs hookSpecificOutput for Claude Code" {
  cd "$SANDBOX"
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "${PROJECT_ROOT}/hooks/session-start"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 'hookSpecificOutput' in d, 'missing hookSpecificOutput'
assert 'additionalContext' in d['hookSpecificOutput'], 'missing additionalContext'
"
}

@test "hook outputs additional_context for Cursor env" {
  cd "$SANDBOX"
  run env CURSOR_PLUGIN_ROOT="$PROJECT_ROOT" CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "${PROJECT_ROOT}/hooks/session-start"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 'additional_context' in d, 'missing additional_context'
"
}

@test "hook outputs additionalContext for generic env" {
  cd "$SANDBOX"
  run env -u CLAUDE_PLUGIN_ROOT -u CURSOR_PLUGIN_ROOT COPILOT_CLI=1 bash "${PROJECT_ROOT}/hooks/session-start"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 'additionalContext' in d, 'missing additionalContext'
"
}

@test "hook includes spec-anchor-context tag" {
  cd "$SANDBOX"
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "${PROJECT_ROOT}/hooks/session-start"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ctx = d['hookSpecificOutput']['additionalContext']
assert 'spec-anchor-context' in ctx, 'missing spec-anchor-context tag'
"
}

@test "hook outputs empty JSON when no anchor.yaml" {
  local EMPTY_DIR
  EMPTY_DIR="$(mktemp -d)"
  cd "$EMPTY_DIR"
  run env CLAUDE_PLUGIN_ROOT="$PROJECT_ROOT" bash "${PROJECT_ROOT}/hooks/session-start"
  [ "$status" -eq 0 ]
  [[ "$output" == "{}" ]]
  rm -rf "$EMPTY_DIR"
}
