#!/usr/bin/env bash
# SpecAnchor Resolve - 根据文件与意图决定应该加载哪些锚点

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

FORMAT="text"
FILES_CSV=""
INTENT=""

declare -a TARGET_FILES=()
declare -a ANCH_LEVELS=()
declare -a ANCH_PATHS=()
declare -a ANCH_LOADS=()
declare -a ANCH_REASONS=()
declare -a ANCH_CONFIDENCES=()
declare -a MISSING_PATHS=()

MODE="unknown"

trim_spaces() {
  printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

normalize_token_text() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^[:alnum:]]+/ /g'
}

text_contains_token() {
  local haystack token
  haystack=" $(normalize_token_text "$1") "
  token=" $(normalize_token_text "$2") "
  [[ "$haystack" == *"$token"* ]]
}

add_anchor() {
  local level="$1"
  local path="$2"
  local load="$3"
  local reason="$4"
  local confidence="$5"
  local i=0
  while [[ $i -lt ${#ANCH_PATHS[@]} ]]; do
    if [[ "${ANCH_PATHS[$i]}" == "$path" ]]; then
      return
    fi
    i=$((i + 1))
  done

  ANCH_LEVELS+=("$level")
  ANCH_PATHS+=("$path")
  ANCH_LOADS+=("$load")
  ANCH_REASONS+=("$reason")
  ANCH_CONFIDENCES+=("$confidence")
}

module_label_from_path() {
  local module_path="$1"
  module_path="${module_path%/}"
  basename "$module_path"
}

load_target_files() {
  local raw=""
  IFS=',' read -r -a TARGET_FILES <<< "$FILES_CSV"
  local i=0
  while [[ $i -lt ${#TARGET_FILES[@]} ]]; do
    raw=$(trim_spaces "${TARGET_FILES[$i]}")
    TARGET_FILES[$i]="$raw"
    i=$((i + 1))
  done
}

resolve_full_mode() {
  local global_file=""
  for global_file in .specanchor/global/*.spec.md; do
    [[ -f "$global_file" ]] || continue
    add_anchor "global" "$global_file" "full" "always_load" "1.0"
  done

  local intent_lc=""
  intent_lc=$(printf '%s' "$INTENT" | tr '[:upper:]' '[:lower:]')
  local matched_files=""

  local module_file=""
  for module_file in .specanchor/modules/*.spec.md; do
    [[ -f "$module_file" ]] || continue
    local module_path module_name module_label target_file
    module_path=$(sa_parse_frontmatter_field "$module_file" "module_path")
    module_name=$(sa_parse_frontmatter_field "$module_file" "module_name")
    module_label=$(module_label_from_path "${module_path:-$module_name}")
    module_label=$(printf '%s' "$module_label" | tr '[:upper:]' '[:lower:]')

    for target_file in "${TARGET_FILES[@]}"; do
      [[ -n "$target_file" ]] || continue
      if [[ -n "$module_path" ]] && [[ "$target_file" == "$module_path"* ]]; then
        add_anchor "module" "$module_file" "full" "file_path_matches_module_path:${module_label}" "0.9"
        matched_files="${matched_files}
${target_file}"
      fi
    done

    if [[ -n "$intent_lc" ]] && [[ -n "$module_label" ]] && [[ "$intent_lc" == *"$module_label"* ]]; then
      add_anchor "module" "$module_file" "full" "intent_matches_module:${module_label}" "0.6"
    fi
  done

  if [[ -f ".specanchor/module-index.md" ]]; then
    local in_modules=0
    local current_path="" current_spec="" target_file=""
    while IFS= read -r line; do
      local trimmed
      trimmed=$(trim_spaces "$line")
      if [[ "$trimmed" == "modules:" ]]; then
        in_modules=1
        continue
      fi
      if [[ $in_modules -eq 1 ]] && [[ "$trimmed" == "uncovered:"* ]]; then
        break
      fi
      if [[ $in_modules -eq 0 ]]; then
        continue
      fi
      if [[ "$trimmed" == "- path:"* ]]; then
        current_path=$(trim_spaces "${trimmed#- path:}")
        current_path=$(sa_normalize_scalar "$current_path")
      elif [[ "$trimmed" == "spec:"* ]]; then
        current_spec=$(trim_spaces "${trimmed#spec:}")
        current_spec=$(sa_normalize_scalar "$current_spec")
        for target_file in "${TARGET_FILES[@]}"; do
          [[ -n "$target_file" ]] || continue
          if [[ -n "$current_path" ]] && [[ -n "$current_spec" ]] && [[ "$target_file" == "$current_path"* ]]; then
            add_anchor "module" ".specanchor/modules/${current_spec}" "full" "file_path_matches_module_index:$(module_label_from_path "$current_path")" "0.8"
          fi
        done
        current_path=""
        current_spec=""
      fi
    done < ".specanchor/module-index.md"
  fi

  local target_file=""
  for target_file in "${TARGET_FILES[@]}"; do
    [[ -n "$target_file" ]] || continue
    local matched=false
    local anchor_path=""
    for anchor_path in "${ANCH_PATHS[@]}"; do
      if [[ "$anchor_path" == ".specanchor/global/"* ]]; then
        continue
      fi
      local module_path=""
      module_path=$(sa_parse_frontmatter_field "$anchor_path" "module_path" || true)
      if [[ -n "$module_path" ]] && [[ "$target_file" == "$module_path"* ]]; then
        matched=true
        break
      fi
    done
    if [[ "$matched" == "false" ]]; then
      MISSING_PATHS+=("$target_file")
    fi
  done
}

resolve_parasitic_mode() {
  local target_file=""
  for target_file in "${TARGET_FILES[@]}"; do
    [[ -n "$target_file" ]] || continue
    local matched=false
    local target_context=""
    target_context="${target_file} ${INTENT}"

    local source_path=""
    while IFS=$'\t' read -r source_path _type _stale _inject; do
      [[ -n "$source_path" ]] || continue

      if [[ "$target_file" == "$source_path"* ]]; then
        add_anchor "source" "$source_path" "summary" "file_path_matches_source_path:$(module_label_from_path "$source_path")" "0.7"
        matched=true
        continue
      fi

      local candidate_file=""
      while IFS= read -r candidate_file; do
        [[ -n "$candidate_file" ]] || continue
        local candidate_name=""
        candidate_name=$(basename "$candidate_file")
        candidate_name="${candidate_name%.*}"
        [[ -n "$candidate_name" ]] || continue

        if text_contains_token "$target_context" "$candidate_name"; then
          add_anchor "source" "$candidate_file" "summary" "target_matches_source_file:${candidate_name}" "0.8"
          matched=true
          break
        fi
      done < <(find "$source_path" -type f \( -name "*.md" -o -name "*.yaml" -o -name "*.yml" \) 2>/dev/null | sort)

      if [[ "$matched" == "false" ]] && text_contains_token "$target_context" "$(module_label_from_path "$source_path")"; then
        add_anchor "source" "$source_path" "summary" "target_mentions_source:$(module_label_from_path "$source_path")" "0.5"
        matched=true
      fi
    done < <(sa_iter_config_sources "$CONFIG_PATH")

    if [[ "$matched" == "false" ]]; then
      MISSING_PATHS+=("$target_file")
    fi
  done
}

status_value() {
  if [[ ${#MISSING_PATHS[@]} -gt 0 ]]; then
    printf 'warning\n'
  else
    printf 'ok\n'
  fi
}

print_text() {
  echo -e "${BOLD}SpecAnchor Resolve [$(status_value)]${RESET}"
  echo "  Mode: ${MODE}"
  echo "  Files: ${FILES_CSV:-<none>}"
  if [[ -n "$INTENT" ]]; then
    echo "  Intent: ${INTENT}"
  fi
  echo ""
  echo "Anchors:"
  local i=0
  while [[ $i -lt ${#ANCH_PATHS[@]} ]]; do
    echo "  - [${ANCH_LEVELS[$i]}] ${ANCH_PATHS[$i]} (${ANCH_REASONS[$i]}, confidence=${ANCH_CONFIDENCES[$i]})"
    i=$((i + 1))
  done

  if [[ ${#MISSING_PATHS[@]} -gt 0 ]]; then
    echo ""
    echo "Missing:"
    local missing=""
    for missing in "${MISSING_PATHS[@]}"; do
      echo "  - ${missing} -> consider specanchor_infer/specanchor_module"
    done
  fi
}

print_json() {
  printf '{\n'
  printf '  "status": "%s",\n' "$(status_value)"
  printf '  "mode": "%s",\n' "$MODE"
  printf '  "anchors": [\n'
  local i=0
  while [[ $i -lt ${#ANCH_PATHS[@]} ]]; do
    [[ $i -gt 0 ]] && printf ',\n'
    printf '    {"level":"%s","path":"%s","load":"%s","reason":"%s","confidence":%s}' \
      "${ANCH_LEVELS[$i]}" \
      "$(sa_json_escape "${ANCH_PATHS[$i]}")" \
      "${ANCH_LOADS[$i]}" \
      "$(sa_json_escape "${ANCH_REASONS[$i]}")" \
      "${ANCH_CONFIDENCES[$i]}"
    i=$((i + 1))
  done
  printf '\n  ],\n'
  printf '  "missing": ['
  i=0
  while [[ $i -lt ${#MISSING_PATHS[@]} ]]; do
    [[ $i -gt 0 ]] && printf ','
    printf '"%s"' "$(sa_json_escape "${MISSING_PATHS[$i]}")"
    i=$((i + 1))
  done
  printf '],\n'
  if [[ "$MODE" == "full" ]]; then
    printf '  "trace": {"global":"full","module":"full"}\n'
  else
    printf '  "trace": {"global":"skipped","module":"sources-only"}\n'
  fi
  printf '}\n'
}

usage() {
  cat <<'EOF'
Usage:
  bash scripts/specanchor-resolve.sh --files "scripts/specanchor-boot.sh,references/commands/check.md" --intent "make boot JSON stable" --format=json
EOF
  exit 0
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --files=*) FILES_CSV="${1#--files=}" ;;
      --files)
        shift
        [[ $# -gt 0 ]] || sa_die "--files requires a value" 64
        FILES_CSV="$1"
        ;;
      --intent=*) INTENT="${1#--intent=}" ;;
      --intent)
        shift
        [[ $# -gt 0 ]] || sa_die "--intent requires a value" 64
        INTENT="$1"
        ;;
      --format=text) FORMAT="text" ;;
      --format=json) FORMAT="json" ;;
      --format)
        shift
        [[ $# -gt 0 ]] || sa_die "--format requires a value" 64
        FORMAT="$1"
        ;;
      --help|-h) usage ;;
      *) sa_die "invalid argument: $1" 64 ;;
    esac
    shift
  done

  if [[ -z "$FILES_CSV" ]] && [[ -z "$INTENT" ]]; then
    sa_die "either --files or --intent is required" 64
  fi

  if ! CONFIG_PATH=$(sa_find_config); then
    if [[ "$FORMAT" == "json" ]]; then
      printf '{"status":"error","mode":"unknown","anchors":[],"missing":[],"trace":{"global":"none","module":"none"}}\n'
    else
      sa_die "CONFIG_MISSING: 未找到 anchor.yaml 或 .specanchor/config.yaml" 2
    fi
    exit 2
  fi

  MODE=$(sa_parse_config_field "$CONFIG_PATH" "mode" "full")
  load_target_files

  if [[ "$MODE" == "full" ]]; then
    resolve_full_mode
  else
    resolve_parasitic_mode
  fi

  case "$FORMAT" in
    text) print_text ;;
    json) print_json ;;
    *) sa_die "invalid format: ${FORMAT}" 64 ;;
  esac
}

main "$@"
