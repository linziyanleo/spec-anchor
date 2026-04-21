#!/usr/bin/env bash
# SpecAnchor Validate - validate config, specs, and generated JSON contracts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

FORMAT="text"
TARGET_PATH=""

declare -a ERRORS=()
declare -a WARNINGS=()
declare -a VALIDATED_FILES=()

add_error() {
  ERRORS+=("$1")
}

add_warning() {
  WARNINGS+=("$1")
}

valid_status() {
  case "$1" in
    draft|review|active|deprecated|archived) return 0 ;;
    *) return 1 ;;
  esac
}

valid_date() {
  local value="$1"
  [[ -z "$value" ]] && return 0
  [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
}

validate_anchor_yaml() {
  local file="$1"
  VALIDATED_FILES+=("$file")
  if ! grep -q '^specanchor:' "$file" 2>/dev/null; then
    add_error "${file}: CONFIG_INVALID missing specanchor root"
    return
  fi

  local version mode
  version=$(sa_parse_yaml_field "$file" "version" "")
  mode=$(sa_parse_yaml_field "$file" "mode" "")

  if [[ -z "$version" ]]; then
    add_error "${file}: CONFIG_INVALID missing specanchor.version"
  fi
  if [[ -n "$mode" ]] && [[ "$mode" != "full" ]] && [[ "$mode" != "parasitic" ]]; then
    add_error "${file}: CONFIG_INVALID unsupported mode ${mode}"
  fi
}

validate_overlay_yaml() {
  local file="$1"
  VALIDATED_FILES+=("$file")
  if ! grep -q '^specanchor:' "$file" 2>/dev/null; then
    add_error "${file}: CONFIG_INVALID missing specanchor root"
    return
  fi

  local mode
  mode=$(sa_parse_yaml_field "$file" "mode" "")
  if [[ -n "$mode" ]] && [[ "$mode" != "full" ]] && [[ "$mode" != "parasitic" ]]; then
    add_error "${file}: CONFIG_INVALID unsupported mode ${mode}"
  fi
}

validate_spec_file() {
  local file="$1"
  VALIDATED_FILES+=("$file")

  if ! grep -q '^specanchor:' "$file" 2>/dev/null; then
    add_error "${file}: FRONTMATTER_MISSING missing specanchor frontmatter"
    return
  fi

  local level expected_level status module_path created updated last_synced allow_missing
  level=$(sa_parse_frontmatter_field "$file" "level")
  status=$(sa_parse_frontmatter_field "$file" "status")
  module_path=$(sa_parse_frontmatter_field "$file" "module_path")
  created=$(sa_parse_frontmatter_field "$file" "created")
  updated=$(sa_parse_frontmatter_field "$file" "updated")
  last_synced=$(sa_parse_frontmatter_field "$file" "last_synced")
  allow_missing=$(sa_parse_frontmatter_field "$file" "allow_missing_module_path")

  expected_level=""
  if [[ "$file" == *"/global/"* ]]; then
    expected_level="global"
  elif [[ "$file" == *"/modules/"* ]]; then
    expected_level="module"
  elif [[ "$file" == *"/tasks/"* ]] || [[ "$file" == *"/archive/"* ]]; then
    expected_level="task"
  fi

  if [[ -n "$expected_level" ]] && [[ "$level" != "$expected_level" ]]; then
    add_error "${file}: LEVEL_INVALID expected ${expected_level}, got ${level:-<empty>}"
  fi

  if [[ "$expected_level" == "module" ]]; then
    if [[ -z "$module_path" ]]; then
      add_error "${file}: MODULE_PATH_MISSING module spec 缺少 module_path"
    elif [[ ! -e "$module_path" ]] && [[ "$allow_missing" != "true" ]]; then
      add_error "${file}: MODULE_PATH_INVALID module_path ${module_path} does not exist"
    fi
  fi

  if [[ -n "$status" ]] && ! valid_status "$status"; then
    add_error "${file}: STATUS_INVALID unsupported status ${status}"
  fi
  if ! valid_date "$created"; then
    add_error "${file}: DATE_INVALID created=${created}"
  fi
  if ! valid_date "$updated"; then
    add_error "${file}: DATE_INVALID updated=${updated}"
  fi
  if ! valid_date "$last_synced"; then
    add_error "${file}: DATE_INVALID last_synced=${last_synced}"
  fi
}

validate_json_shape_file() {
  local file="$1"
  VALIDATED_FILES+=("$file")

  if ! command -v python3 >/dev/null 2>&1; then
    add_warning "${file}: PYTHON3_MISSING json shape validation skipped"
    return 0
  fi

  local output
  if ! output=$(python3 - "$file" 2>&1 <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

schema = data.get("schema_version")
if schema == "specanchor.resolve.v2":
    required = ["status", "mode", "budget", "inputs", "anchors", "missing", "warnings", "trace"]
elif schema == "specanchor.assembly.v1":
    required = ["status", "budget", "files_to_read", "agent_instructions", "assembly_trace", "warnings"]
else:
    raise SystemExit(f"UNKNOWN_SCHEMA {schema!r}")

missing = [key for key in required if key not in data]
if missing:
    raise SystemExit("MISSING_KEYS " + ",".join(missing))

print(schema)
PY
  ); then
    add_error "${file}: JSON_SCHEMA_INVALID ${output}"
    return 0
  fi
}

validate_agent_docs_if_linked() {
  local linked=0
  if grep -q 'references/agents/' README.md README_ZH.md SKILL.md 2>/dev/null; then
    linked=1
  fi
  [[ "$linked" -eq 1 ]] || return 0

  local doc
  for doc in \
    references/agents/agent-contract.md \
    references/agents/claude-code.md \
    references/agents/codex.md \
    references/agents/cursor.md \
    references/agents/gemini.md; do
    if [[ ! -f "$doc" ]]; then
      add_error "${doc}: LINKED_FILE_MISSING"
    fi
  done
}

validate_generated_json_smokes() {
  local resolve_tmp assembly_tmp
  resolve_tmp=$(mktemp)
  assembly_tmp=$(mktemp)

  if bash "$SCRIPT_DIR/specanchor-resolve.sh" --files "anchor.yaml" --intent "validate json shape" --budget=normal --format=json >"$resolve_tmp" 2>/dev/null; then
    validate_json_shape_file "$resolve_tmp"
  else
    add_error "specanchor-resolve.sh: SMOKE_FAILED"
  fi

  if bash "$SCRIPT_DIR/specanchor-assemble.sh" --files "anchor.yaml" --intent "validate assembly shape" --budget=normal --format=json >"$assembly_tmp" 2>/dev/null; then
    validate_json_shape_file "$assembly_tmp"
  else
    add_error "specanchor-assemble.sh: SMOKE_FAILED"
  fi

  rm -f "$resolve_tmp" "$assembly_tmp"
}

collect_targets() {
  if [[ -n "$TARGET_PATH" ]]; then
    if [[ ! -e "$TARGET_PATH" ]]; then
      add_error "${TARGET_PATH}: PATH_MISSING"
      return
    fi
    case "$TARGET_PATH" in
      anchor.yaml|.specanchor/config.yaml) validate_anchor_yaml "$TARGET_PATH" ;;
      anchor.local.yaml) validate_overlay_yaml "$TARGET_PATH" ;;
      *.json) validate_json_shape_file "$TARGET_PATH" ;;
      *.md) validate_spec_file "$TARGET_PATH" ;;
      *) add_warning "${TARGET_PATH}: UNSUPPORTED_TARGET skipped" ;;
    esac
    return
  fi

  local config=""
  if config=$(sa_find_config 2>/dev/null); then
    validate_anchor_yaml "$config"
    local overlay=""
    overlay=$(sa_find_overlay_config "$config" 2>/dev/null || true)
    if [[ -n "$overlay" ]]; then
      validate_overlay_yaml "$overlay"
    fi
  else
    add_error "anchor.yaml: CONFIG_MISSING"
  fi

  local file=""
  for file in .specanchor/global/*.spec.md .specanchor/modules/*.spec.md; do
    [[ -f "$file" ]] || continue
    validate_spec_file "$file"
  done
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    validate_spec_file "$file"
  done < <(find .specanchor/tasks .specanchor/archive -name "*.spec.md" 2>/dev/null | sort)

  validate_agent_docs_if_linked
  validate_generated_json_smokes
}

status_value() {
  if [[ ${#ERRORS[@]} -gt 0 ]]; then
    printf 'error\n'
  elif [[ ${#WARNINGS[@]} -gt 0 ]]; then
    printf 'warning\n'
  else
    printf 'ok\n'
  fi
}

print_json_array() {
  local array_name="$1"
  local count
  count=$(eval "printf '%s' \${#$array_name[@]}")
  printf '['
  if [[ "$count" -gt 0 ]]; then
    local i=0 value
    while [[ $i -lt $count ]]; do
      value=$(eval "printf '%s' \"\${$array_name[$i]}\"")
      [[ $i -gt 0 ]] && printf ','
      printf '"%s"' "$(sa_json_escape "$value")"
      i=$((i + 1))
    done
  fi
  printf ']'
}

print_text() {
  echo -e "${BOLD}SpecAnchor Validate [$(status_value)]${RESET}"
  echo "  Files: ${#VALIDATED_FILES[@]}"
  if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo ""
    echo "Errors:"
    local item=""
    for item in "${ERRORS[@]}"; do
      echo "  - ${item}"
    done
  fi
  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo ""
    echo "Warnings:"
    local item=""
    for item in "${WARNINGS[@]}"; do
      echo "  - ${item}"
    done
  fi
}

print_json() {
  printf '{\n'
  printf '  "status": "%s",\n' "$(status_value)"
  printf '  "errors": '
  print_json_array ERRORS
  printf ',\n'
  printf '  "warnings": '
  print_json_array WARNINGS
  printf ',\n'
  printf '  "validated_files": '
  print_json_array VALIDATED_FILES
  printf '\n}\n'
}

usage() {
  cat <<'EOF'
Usage:
  bash scripts/specanchor-validate.sh
  bash scripts/specanchor-validate.sh --format=json
  bash scripts/specanchor-validate.sh --format=summary
  bash scripts/specanchor-validate.sh --path .specanchor/modules/scripts.spec.md
EOF
  exit 0
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format=json) FORMAT="json" ;;
      --format=text|--format=summary) FORMAT="text" ;;
      --format)
        shift
        [[ $# -gt 0 ]] || sa_die "--format requires a value" 64
        FORMAT="$1"
        if [[ "$FORMAT" == "summary" ]]; then
          FORMAT="text"
        fi
        ;;
      --path)
        shift
        [[ $# -gt 0 ]] || sa_die "--path requires a value" 64
        TARGET_PATH="$1"
        ;;
      --path=*)
        TARGET_PATH="${1#--path=}"
        ;;
      --help|-h) usage ;;
      *) sa_die "invalid argument: $1" 64 ;;
    esac
    shift
  done

  collect_targets

  case "$FORMAT" in
    text) print_text ;;
    json) print_json ;;
    *) sa_die "invalid format: ${FORMAT}" 64 ;;
  esac

  if [[ ${#ERRORS[@]} -gt 0 ]]; then
    exit 2
  fi
  exit 0
}

main "$@"
