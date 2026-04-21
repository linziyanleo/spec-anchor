#!/usr/bin/env bash

if [[ -n "${SPECANCHOR_COMMON_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
SPECANCHOR_COMMON_LOADED=1

sa_init_colors() {
  if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    DIM='\033[2m'
    BOLD='\033[1m'
    RESET='\033[0m'
  else
    RED='' GREEN='' YELLOW='' CYAN='' DIM='' BOLD='' RESET=''
  fi
}

sa_init_colors

sa_die() {
  local message="$1"
  local exit_code="${2:-1}"
  echo -e "${RED}error:${RESET} ${message}" >&2
  exit "$exit_code"
}

sa_warn() {
  echo -e "${YELLOW}warning:${RESET} $*" >&2
}

sa_normalize_scalar() {
  local value="${1:-}"
  value=$(printf '%s' "$value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  if [[ ${#value} -ge 2 ]]; then
    local first_char="${value:0:1}"
    local last_char="${value:$((${#value} - 1)):1}"
    if [[ "$first_char" == "$last_char" ]] && { [[ "$first_char" == '"' ]] || [[ "$first_char" == "'" ]]; }; then
      value="${value:1:$((${#value} - 2))}"
    fi
  fi
  printf '%s\n' "$value"
}

sa_parse_yaml_field() {
  local file="$1"
  local field="$2"
  local default="${3:-}"
  if [[ -f "$file" ]]; then
    local raw val
    raw=$(awk -v field="$field" '
      $0 ~ "^    " field ":" {
        sub("^    " field ": *", "", $0)
        print
        exit
      }
      $0 ~ "^  " field ":" {
        sub("^  " field ": *", "", $0)
        print
        exit
      }
      $0 ~ "^" field ":" {
        sub("^" field ": *", "", $0)
        print
        exit
      }
    ' "$file")
    val=$(printf '%s' "$raw" | sed 's/[[:space:]]#.*$//')
    if [[ -z "$val" ]]; then
      printf '%s\n' "$default"
      return
    fi
    sa_normalize_scalar "$val"
  else
    printf '%s\n' "$default"
  fi
}

sa_parse_frontmatter_field() {
  local file="$1"
  local field="$2"
  local raw
  raw=$(awk -v field="$field" '
    /^---$/ { in_frontmatter = !in_frontmatter; next }
    in_frontmatter && $0 ~ "^  " field ":" {
      sub("^  " field ": *", "", $0)
      print
      exit
    }
  ' "$file")
  sa_normalize_scalar "$raw"
}

sa_find_config() {
  if [[ -f "anchor.yaml" ]]; then
    printf 'anchor.yaml\n'
    return 0
  fi
  if [[ -f ".specanchor/config.yaml" ]]; then
    printf '.specanchor/config.yaml\n'
    return 0
  fi
  return 1
}

sa_date_to_epoch() {
  local value="$1"
  local epoch
  epoch=$(date -j -f "%Y-%m-%d" "$value" "+%s" 2>/dev/null || date -d "$value" "+%s" 2>/dev/null || true)
  printf '%s\n' "$epoch"
}

sa_json_escape() {
  local value="${1:-}"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

