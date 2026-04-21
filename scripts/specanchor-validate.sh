#!/usr/bin/env bash
# SpecAnchor Validate - 基础 schema/frontmatter 校验

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

  local version
  version=$(sa_parse_yaml_field "$file" "version" "")
  if [[ -z "$version" ]]; then
    add_error "${file}: CONFIG_INVALID missing specanchor.version"
  fi
}

validate_spec_file() {
  local file="$1"
  VALIDATED_FILES+=("$file")

  if ! grep -q '^specanchor:' "$file" 2>/dev/null; then
    add_error "${file}: FRONTMATTER_MISSING missing specanchor frontmatter"
    return
  fi

  local level expected_level status module_path
  local created updated last_synced

  level=$(sa_parse_frontmatter_field "$file" "level")
  status=$(sa_parse_frontmatter_field "$file" "status")
  module_path=$(sa_parse_frontmatter_field "$file" "module_path")
  created=$(sa_parse_frontmatter_field "$file" "created")
  updated=$(sa_parse_frontmatter_field "$file" "updated")
  last_synced=$(sa_parse_frontmatter_field "$file" "last_synced")

  expected_level=""
  if [[ "$file" == *"/global/"* ]]; then
    expected_level="global"
  elif [[ "$file" == *"/modules/"* ]]; then
    expected_level="module"
  fi

  if [[ -n "$expected_level" ]] && [[ "$level" != "$expected_level" ]]; then
    add_error "${file}: LEVEL_INVALID expected ${expected_level}, got ${level:-<empty>}"
  fi

  if [[ "$expected_level" == "module" ]] && [[ -z "$module_path" ]]; then
    add_error "${file}: MODULE_PATH_MISSING module spec 缺少 module_path"
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

collect_targets() {
  if [[ -n "$TARGET_PATH" ]]; then
    if [[ ! -e "$TARGET_PATH" ]]; then
      add_error "${TARGET_PATH}: PATH_MISSING"
      return
    fi
    if [[ "$TARGET_PATH" == "anchor.yaml" ]] || [[ "$TARGET_PATH" == ".specanchor/config.yaml" ]]; then
      validate_anchor_yaml "$TARGET_PATH"
    else
      validate_spec_file "$TARGET_PATH"
    fi
    return
  fi

  local config=""
  if config=$(sa_find_config 2>/dev/null); then
    validate_anchor_yaml "$config"
  else
    add_error "anchor.yaml: CONFIG_MISSING"
  fi

  local file=""
  for file in .specanchor/global/*.spec.md .specanchor/modules/*.spec.md; do
    [[ -f "$file" ]] || continue
    validate_spec_file "$file"
  done
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
    local i=0
    local value=""
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
  bash scripts/specanchor-validate.sh --path .specanchor/modules/scripts.spec.md
EOF
  exit 0
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format=json) FORMAT="json" ;;
      --format=text) FORMAT="text" ;;
      --format)
        shift
        [[ $# -gt 0 ]] || sa_die "--format requires a value" 64
        FORMAT="$1"
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
}

main "$@"
