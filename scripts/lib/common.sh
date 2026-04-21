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

sa_find_overlay_config() {
  local config="$1"
  [[ -n "$config" ]] || return 1

  local config_name config_dir overlay_path
  config_name=$(basename "$config")
  [[ "$config_name" == "anchor.yaml" ]] || return 1

  config_dir=$(cd "$(dirname "$config")" 2>/dev/null && pwd) || return 1
  overlay_path="${config_dir}/anchor.local.yaml"
  [[ -f "$overlay_path" ]] || return 1

  if [[ "$config_dir" == "$PWD" ]]; then
    printf 'anchor.local.yaml\n'
  else
    printf '%s\n' "$overlay_path"
  fi
}

sa_config_label() {
  local config="$1"
  local overlay=""
  overlay=$(sa_find_overlay_config "$config" 2>/dev/null || true)
  if [[ -n "$overlay" ]]; then
    printf '%s + %s\n' "$config" "$overlay"
  else
    printf '%s\n' "$config"
  fi
}

sa_parse_config_field() {
  local config="$1"
  local field="$2"
  local default="${3:-}"
  local overlay=""
  local missing="__SPECANCHOR_FIELD_MISSING__"

  overlay=$(sa_find_overlay_config "$config" 2>/dev/null || true)
  if [[ -n "$overlay" ]]; then
    local overlay_value
    overlay_value=$(sa_parse_yaml_field "$overlay" "$field" "$missing")
    if [[ "$overlay_value" != "$missing" ]]; then
      printf '%s\n' "$overlay_value"
      return 0
    fi
  fi

  sa_parse_yaml_field "$config" "$field" "$default"
}

sa_iter_yaml_sources() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -q "^  sources:" "$file" 2>/dev/null || return 0

  local in_sources=0
  local current_path="" current_type="" stale_check="" frontmatter_inject=""

  _sa_emit_source() {
    if [[ -n "$current_path" ]]; then
      printf '%s\t%s\t%s\t%s\n' \
        "$current_path" \
        "$current_type" \
        "$stale_check" \
        "$frontmatter_inject"
    fi
  }

  _sa_capture_source_field() {
    local raw_line="$1"
    if [[ "$raw_line" =~ path:[[:space:]]*\"?([^\"]+)\"? ]]; then
      current_path="${BASH_REMATCH[1]}"
    fi
    if [[ "$raw_line" =~ type:[[:space:]]*\"?([^\"]+)\"? ]]; then
      current_type="${BASH_REMATCH[1]}"
    fi
    if [[ "$raw_line" =~ stale_check:[[:space:]]*(true|false) ]]; then
      stale_check="${BASH_REMATCH[1]}"
    fi
    if [[ "$raw_line" =~ frontmatter_inject:[[:space:]]*(true|false) ]]; then
      frontmatter_inject="${BASH_REMATCH[1]}"
    fi
  }

  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]{2}sources: ]]; then
      in_sources=1
      continue
    fi

    if [[ $in_sources -eq 1 ]] && [[ "$line" =~ ^[[:space:]]{2}[A-Za-z0-9_-]+: ]] && [[ ! "$line" =~ ^[[:space:]]{4} ]]; then
      _sa_emit_source
      in_sources=0
      continue
    fi

    if [[ $in_sources -eq 0 ]]; then
      continue
    fi

    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(.*)$ ]]; then
      _sa_emit_source
      current_path=""
      current_type=""
      stale_check=""
      frontmatter_inject=""
      _sa_capture_source_field "${BASH_REMATCH[1]}"
      continue
    fi

    _sa_capture_source_field "$line"
  done < "$file"

  if [[ $in_sources -eq 1 ]]; then
    _sa_emit_source
  fi

  unset -f _sa_capture_source_field
  unset -f _sa_emit_source
}

sa_iter_config_sources() {
  local config="$1"
  local overlay=""

  sa_iter_yaml_sources "$config"
  overlay=$(sa_find_overlay_config "$config" 2>/dev/null || true)
  if [[ -n "$overlay" ]]; then
    sa_iter_yaml_sources "$overlay"
  fi
}

sa_yaml_list_contains() {
  local file="$1"
  local parent_field="$2"
  local list_field="$3"
  local needle="$4"
  [[ -f "$file" ]] || return 1

  local in_parent=0
  local in_list=0

  while IFS= read -r line; do
    if [[ $in_parent -eq 0 ]] && [[ "$line" =~ ^[[:space:]]{2}${parent_field}: ]]; then
      in_parent=1
      in_list=0
      continue
    fi

    if [[ $in_parent -eq 1 ]] && [[ "$line" =~ ^[[:space:]]{2}[A-Za-z0-9_-]+: ]] && [[ ! "$line" =~ ^[[:space:]]{4} ]]; then
      in_parent=0
      in_list=0
      continue
    fi

    if [[ $in_parent -eq 1 ]] && [[ "$line" =~ ^[[:space:]]{4}${list_field}: ]]; then
      in_list=1
      continue
    fi

    if [[ $in_list -eq 1 ]] && [[ "$line" =~ ^[[:space:]]{4}[A-Za-z0-9_-]+: ]] && [[ ! "$line" =~ ^[[:space:]]{6} ]]; then
      break
    fi

    if [[ $in_list -eq 1 ]] && [[ "$line" =~ ^[[:space:]]*-[[:space:]]*\"?([^\"]+)\"? ]]; then
      local item="${BASH_REMATCH[1]}"
      item=$(sa_normalize_scalar "$item")
      if [[ "$item" == "$needle" ]]; then
        return 0
      fi
    fi
  done < "$file"

  return 1
}

sa_config_list_contains() {
  local config="$1"
  local parent_field="$2"
  local list_field="$3"
  local needle="$4"
  local overlay=""

  if sa_yaml_list_contains "$config" "$parent_field" "$list_field" "$needle"; then
    return 0
  fi

  overlay=$(sa_find_overlay_config "$config" 2>/dev/null || true)
  if [[ -n "$overlay" ]] && sa_yaml_list_contains "$overlay" "$parent_field" "$list_field" "$needle"; then
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

sa_trim_spaces() {
  local value="${1:-}"
  printf '%s' "$value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

sa_join_by() {
  local sep="$1"
  shift

  local out="" item
  for item in "$@"; do
    if [[ -n "$out" ]]; then
      out="${out}${sep}${item}"
    else
      out="$item"
    fi
  done

  printf '%s' "$out"
}

sa_file_line_count() {
  local file="$1"
  [[ -f "$file" ]] || {
    printf '0\n'
    return 0
  }
  wc -l < "$file" | tr -d ' '
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
