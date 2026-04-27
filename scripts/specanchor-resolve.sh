#!/usr/bin/env bash
# SpecAnchor Resolve v2 - budget-aware, explainable anchor resolution.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

FORMAT="text"
FILES_CSV=""
FILES_FROM=""
INTENT=""
INTENT_FILE=""
DIFF_FROM=""
BUDGET_PROFILE="normal"

CONFIG_PATH=""
MODE="unknown"
SPEC_INDEX_PATH=".specanchor/spec-index.md"
CODEMAP_PATH=".specanchor/project-codemap.md"
CHECK_STALE_DAYS=14
CHECK_OUTDATED_DAYS=30
MAX_FILES=12
MAX_LINES=1200
ESTIMATED_FILES=0
ESTIMATED_LINES=0
TRUNCATED="false"
SOURCES_CHECKED=0

declare -a TARGET_FILES=()
declare -a TASK_FILES=()
declare -a WARNING_CODES=()
declare -a WARNING_MESSAGES=()
declare -a MISSING_TYPES=()
declare -a MISSING_PATHS=()
declare -a MISSING_REASONS=()
declare -a MISSING_ACTIONS=()

declare -a ANCH_LEVELS=()
declare -a ANCH_PATHS=()
declare -a ANCH_LOADS=()
declare -a ANCH_MATCH_TYPES=()
declare -a ANCH_CONFIDENCES=()
declare -a ANCH_PRIMARY_REASONS=()
declare -a ANCH_ALL_REASONS=()
declare -a ANCH_FRESHNESS=()
declare -a ANCH_LINE_COUNTS=()
declare -a ANCH_SCORES=()

normalize_token_text() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^[:alnum:]]+/ /g'
}

text_contains_token() {
  local haystack token
  haystack=" $(normalize_token_text "$1") "
  token=" $(normalize_token_text "$2") "
  [[ "$haystack" == *"$token"* ]]
}

module_label_from_path() {
  local module_path="${1:-}"
  module_path="${module_path%/}"
  basename "$module_path"
}

module_label_from_spec() {
  local spec_file="$1"
  local module_name module_path
  module_name=$(sa_parse_frontmatter_field "$spec_file" "module_name")
  module_path=$(sa_parse_frontmatter_field "$spec_file" "module_path")
  if [[ -n "$module_path" ]]; then
    module_label_from_path "$module_path"
  elif [[ -n "$module_name" ]]; then
    printf '%s\n' "$module_name"
  else
    basename "$spec_file" .spec.md
  fi
}

task_label_from_spec() {
  local task_file="$1"
  local title
  title=$(sa_parse_frontmatter_field "$task_file" "title")
  if [[ -n "$title" ]]; then
    printf '%s\n' "$title"
  else
    basename "$task_file" .spec.md
  fi
}

confidence_for_match_type() {
  case "$1" in
    always_global) printf '1.00\n' ;;
    path_prefix) printf '0.95\n' ;;
    frontmatter_applies_to|frontmatter_key_file) printf '0.90\n' ;;
    spec_index_entry) printf '0.85\n' ;;
    source_path_mapping) printf '0.80\n' ;;
    task_spec_recent) printf '0.75\n' ;;
    codemap_area) printf '0.70\n' ;;
    intent_keyword) printf '0.50\n' ;;
    fallback_global_only) printf '0.30\n' ;;
    *) printf '0.00\n' ;;
  esac
}

score_for_match_type() {
  local confidence
  confidence=$(confidence_for_match_type "$1")
  printf '%s\n' "${confidence/./}"
}

set_budget_limits() {
  case "$BUDGET_PROFILE" in
    compact)
      MAX_FILES=6
      MAX_LINES=600
      ;;
    normal)
      MAX_FILES=12
      MAX_LINES=1200
      ;;
    full)
      MAX_FILES=24
      MAX_LINES=2400
      ;;
    *)
      sa_die "invalid budget profile: ${BUDGET_PROFILE}" 64
      ;;
  esac
}

line_estimate_for_load() {
  local load="$1"
  local line_count="$2"
  case "$load" in
    full) printf '%s\n' "$line_count" ;;
    summary)
      if [[ "$line_count" -gt 60 ]]; then
        printf '60\n'
      else
        printf '%s\n' "$line_count"
      fi
      ;;
    deferred) printf '20\n' ;;
    skipped|none) printf '0\n' ;;
    *) printf '%s\n' "$line_count" ;;
  esac
}

load_mode_for_anchor() {
  local level="$1"
  local path="$2"
  local line_count
  line_count=$(sa_file_line_count "$path")

  case "$level" in
    global)
      case "$BUDGET_PROFILE" in
        full) printf 'full\n' ;;
        *) printf 'summary\n' ;;
      esac
      ;;
    module)
      case "$BUDGET_PROFILE" in
        compact) printf 'summary\n' ;;
        normal)
          if [[ "$line_count" -le 220 ]]; then
            printf 'full\n'
          else
            printf 'summary\n'
          fi
          ;;
        full) printf 'full\n' ;;
      esac
      ;;
    task)
      case "$BUDGET_PROFILE" in
        compact) printf 'skipped\n' ;;
        normal) printf 'summary\n' ;;
        full) printf 'full\n' ;;
      esac
      ;;
    source)
      case "$BUDGET_PROFILE" in
        full)
          if [[ -f "$path" ]] && [[ "$line_count" -le 220 ]]; then
            printf 'full\n'
          else
            printf 'summary\n'
          fi
          ;;
        *) printf 'summary\n' ;;
      esac
      ;;
    codemap)
      case "$BUDGET_PROFILE" in
        compact) printf 'skipped\n' ;;
        *) printf 'summary\n' ;;
      esac
      ;;
    *)
      printf 'summary\n'
      ;;
  esac
}

module_freshness() {
  local spec_file="$1"
  local module_path last_synced commits_since synced_epoch now_epoch days_since
  module_path=$(sa_parse_frontmatter_field "$spec_file" "module_path")
  last_synced=$(sa_parse_frontmatter_field "$spec_file" "last_synced")

  if [[ -z "$last_synced" ]]; then
    printf 'unknown\n'
    return 0
  fi

  synced_epoch=$(sa_date_to_epoch "$last_synced")
  if [[ -z "$synced_epoch" ]]; then
    printf 'unknown\n'
    return 0
  fi

  commits_since=0
  if [[ -n "$module_path" ]] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    commits_since=$(git log --oneline --since="${last_synced} 00:00:00" -- "$module_path" 2>/dev/null | wc -l | tr -d ' ')
  fi

  if [[ "$commits_since" -eq 0 ]]; then
    printf 'fresh\n'
    return 0
  fi

  now_epoch=$(date "+%s")
  days_since=$(( (now_epoch - synced_epoch) / 86400 ))
  if [[ "$days_since" -ge "$CHECK_OUTDATED_DAYS" ]]; then
    printf 'outdated\n'
  elif [[ "$days_since" -ge "$CHECK_STALE_DAYS" ]]; then
    printf 'stale\n'
  else
    printf 'drifted\n'
  fi
}

freshness_for_anchor() {
  local level="$1"
  local path="$2"
  case "$level" in
    module) module_freshness "$path" ;;
    task)
      if [[ -f "$path" ]]; then
        local updated
        updated=$(sa_parse_frontmatter_field "$path" "updated")
        if [[ -n "$updated" ]]; then
          printf 'fresh\n'
        else
          printf 'unknown\n'
        fi
      else
        printf 'unknown\n'
      fi
      ;;
    *) printf 'unknown\n' ;;
  esac
}

anchor_index_by_path() {
  local path="$1"
  local i=0
  while [[ $i -lt ${#ANCH_PATHS[@]} ]]; do
    if [[ "${ANCH_PATHS[$i]}" == "$path" ]]; then
      printf '%s\n' "$i"
      return 0
    fi
    i=$((i + 1))
  done
  printf '%s\n' "-1"
}

append_reason() {
  local existing="$1"
  local reason="$2"
  if [[ -z "$existing" ]]; then
    printf '%s\n' "$reason"
    return 0
  fi
  if [[ "$existing" == *"$reason"* ]]; then
    printf '%s\n' "$existing"
    return 0
  fi
  printf '%s||%s\n' "$existing" "$reason"
}

add_warning() {
  WARNING_CODES+=("$1")
  WARNING_MESSAGES+=("$2")
}

add_missing() {
  local type="$1"
  local path="$2"
  local reason="$3"
  local action="$4"
  local i=0
  while [[ $i -lt ${#MISSING_PATHS[@]} ]]; do
    if [[ "${MISSING_PATHS[$i]}" == "$path" ]]; then
      return 0
    fi
    i=$((i + 1))
  done
  MISSING_TYPES+=("$type")
  MISSING_PATHS+=("$path")
  MISSING_REASONS+=("$reason")
  MISSING_ACTIONS+=("$action")
}

add_or_update_anchor() {
  local level="$1"
  local path="$2"
  local match_type="$3"
  local reason="$4"

  [[ -n "$path" ]] || return 0

  local confidence score idx load freshness line_count
  confidence=$(confidence_for_match_type "$match_type")
  score=$(score_for_match_type "$match_type")
  load=$(load_mode_for_anchor "$level" "$path")
  freshness=$(freshness_for_anchor "$level" "$path")
  line_count=$(sa_file_line_count "$path")
  idx=$(anchor_index_by_path "$path")

  if [[ "$idx" == "-1" ]]; then
    ANCH_LEVELS+=("$level")
    ANCH_PATHS+=("$path")
    ANCH_LOADS+=("$load")
    ANCH_MATCH_TYPES+=("$match_type")
    ANCH_CONFIDENCES+=("$confidence")
    ANCH_PRIMARY_REASONS+=("$reason")
    ANCH_ALL_REASONS+=("$reason")
    ANCH_FRESHNESS+=("$freshness")
    ANCH_LINE_COUNTS+=("$line_count")
    ANCH_SCORES+=("$score")
    return 0
  fi

  ANCH_ALL_REASONS[$idx]=$(append_reason "${ANCH_ALL_REASONS[$idx]}" "$reason")
  if (( 10#$score > 10#${ANCH_SCORES[$idx]} )); then
    ANCH_LEVELS[$idx]="$level"
    ANCH_MATCH_TYPES[$idx]="$match_type"
    ANCH_CONFIDENCES[$idx]="$confidence"
    ANCH_PRIMARY_REASONS[$idx]="$reason"
    ANCH_LOADS[$idx]="$load"
    ANCH_FRESHNESS[$idx]="$freshness"
    ANCH_LINE_COUNTS[$idx]="$line_count"
    ANCH_SCORES[$idx]="$score"
  fi
}

add_target_file() {
  local raw_file="$1"
  local file
  file=$(sa_trim_spaces "$raw_file")
  [[ -n "$file" ]] || return 0

  local existing=""
  for existing in "${TARGET_FILES[@]:-}"; do
    if [[ "$existing" == "$file" ]]; then
      return 0
    fi
  done

  TARGET_FILES+=("$file")
}

load_target_files() {
  local raw item

  if [[ -n "$FILES_CSV" ]]; then
    IFS=',' read -r -a raw <<< "$FILES_CSV"
    for item in "${raw[@]:-}"; do
      add_target_file "$item"
    done
  fi

  if [[ -n "$FILES_FROM" ]]; then
    [[ -f "$FILES_FROM" ]] || sa_die "--files-from file not found: ${FILES_FROM}" 64
    while IFS= read -r item; do
      add_target_file "$item"
    done < "$FILES_FROM"
  fi

  if [[ -n "$DIFF_FROM" ]]; then
    local diff_output=""
    diff_output=$(git diff --name-only "${DIFF_FROM}...HEAD" 2>/dev/null || git diff --name-only "$DIFF_FROM" 2>/dev/null || true)
    if [[ -z "$diff_output" ]]; then
      add_warning "DIFF_EMPTY" "No changed files were detected for --diff-from=${DIFF_FROM}."
    else
      while IFS= read -r item; do
        add_target_file "$item"
      done <<< "$diff_output"
    fi
  fi
}

load_intent() {
  if [[ -n "$INTENT_FILE" ]]; then
    [[ -f "$INTENT_FILE" ]] || sa_die "--intent-file not found: ${INTENT_FILE}" 64
    INTENT=$(cat "$INTENT_FILE")
  fi
}

load_config() {
  if ! CONFIG_PATH=$(sa_find_config); then
    return 1
  fi

  MODE=$(sa_parse_config_field "$CONFIG_PATH" "mode" "full")
  SPEC_INDEX_PATH=$(sa_load_spec_index_or_legacy "$CONFIG_PATH" 2>/dev/null || sa_spec_index_path "$CONFIG_PATH")
  CODEMAP_PATH=$(sa_parse_config_field "$CONFIG_PATH" "project_codemap" ".specanchor/project-codemap.md")
  CHECK_STALE_DAYS=$(sa_parse_config_field "$CONFIG_PATH" "stale_days" "14")
  CHECK_OUTDATED_DAYS=$(sa_parse_config_field "$CONFIG_PATH" "outdated_days" "30")
  return 0
}

resolve_global_anchors() {
  local global_dir global_file
  global_dir=$(sa_parse_config_field "$CONFIG_PATH" "global_specs" ".specanchor/global/")
  global_dir="${global_dir%/}"
  [[ "$MODE" == "full" ]] || return 0
  [[ -d "$global_dir" ]] || return 0

  for global_file in "$global_dir"/*.spec.md; do
    [[ -f "$global_file" ]] || continue
    add_or_update_anchor "global" "$global_file" "always_global" "Global specs are always considered in full mode."
  done
}

resolve_spec_index_matches() {
  local target_file="$1"
  [[ -f "$SPEC_INDEX_PATH" ]] || return 0

  local current_path current_spec _summary _health
  while IFS=$'\t' read -r current_path current_spec _summary _health; do
    if [[ -n "$current_path" ]] && [[ -n "$current_spec" ]] && [[ "$target_file" == "$current_path"* ]]; then
      add_or_update_anchor \
        "module" \
        ".specanchor/modules/${current_spec}" \
        "spec_index_entry" \
        "Spec index maps ${target_file} to ${current_path}."
    fi
  done < <(sa_iter_index_modules "$SPEC_INDEX_PATH")
}

resolve_full_mode_for_file() {
  local target_file="$1"
  local matched=0
  local module_file module_path applies_to key_file module_label

  if [[ -d ".specanchor/modules" ]]; then
    for module_file in .specanchor/modules/*.spec.md; do
      [[ -f "$module_file" ]] || continue
      module_path=$(sa_parse_frontmatter_field "$module_file" "module_path")
      applies_to=$(sa_parse_frontmatter_field "$module_file" "applies_to")
      key_file=$(sa_parse_frontmatter_field "$module_file" "key_file")
      module_label=$(module_label_from_spec "$module_file")
      local module_name
      module_name=$(sa_parse_frontmatter_field "$module_file" "module_name")

      if [[ -n "$module_path" ]] && [[ "$target_file" == "$module_path"* ]]; then
        add_or_update_anchor "module" "$module_file" "path_prefix" "File path ${target_file} is inside module_path ${module_path}."
        matched=1
      fi
      if [[ -n "$applies_to" ]] && [[ "$target_file" == "$applies_to"* ]]; then
        add_or_update_anchor "module" "$module_file" "frontmatter_applies_to" "Frontmatter applies_to=${applies_to} matches ${target_file}."
        matched=1
      fi
      if [[ -n "$key_file" ]] && [[ "$target_file" == "$key_file" ]]; then
        add_or_update_anchor "module" "$module_file" "frontmatter_key_file" "Frontmatter key_file=${key_file} matches ${target_file}."
        matched=1
      fi
      if [[ -n "$INTENT" ]] && text_contains_token "$INTENT" "$module_label"; then
        add_or_update_anchor "module" "$module_file" "intent_keyword" "Intent mentions module token ${module_label}."
      fi
      if [[ -n "$INTENT" ]] && [[ -n "$module_name" ]] && text_contains_token "$INTENT" "$module_name"; then
        add_or_update_anchor "module" "$module_file" "intent_keyword" "Intent mentions module token ${module_name}."
      fi
    done
  fi

  resolve_spec_index_matches "$target_file"

  if [[ -f "$CODEMAP_PATH" ]]; then
    local target_root
    target_root="${target_file%%/*}"
    if [[ -n "$target_root" ]] && grep -q "${target_root}/" "$CODEMAP_PATH" 2>/dev/null; then
      add_or_update_anchor "codemap" "$CODEMAP_PATH" "codemap_area" "Project codemap references area ${target_root}/ for ${target_file}."
    fi
  fi

  local task_file task_label
  for task_file in "${TASK_FILES[@]:-}"; do
    [[ -f "$task_file" ]] || continue
    task_label=$(task_label_from_spec "$task_file")
    if [[ -n "$INTENT" ]] && text_contains_token "$INTENT" "$task_label"; then
      add_or_update_anchor "task" "$task_file" "task_spec_recent" "Task spec ${task_label} overlaps the current intent."
    fi
  done

  local anchor_path
  for anchor_path in "${ANCH_PATHS[@]:-}"; do
    if [[ "$anchor_path" == ".specanchor/modules/"* ]]; then
      local module_path_for_anchor
      module_path_for_anchor=$(sa_parse_frontmatter_field "$anchor_path" "module_path")
      if [[ -n "$module_path_for_anchor" ]] && [[ "$target_file" == "$module_path_for_anchor"* ]]; then
        matched=1
        break
      fi
    fi
  done

  if [[ "$matched" -eq 0 ]]; then
    add_missing "module_spec" "$target_file" "No Module Spec matched this file path." "specanchor_infer or specanchor_module"
  fi
}

resolve_source_file_match() {
  local source_root="$1"
  local target_file="$2"
  local matched=1
  local target_context candidate_file candidate_name parent_name

  target_context="${target_file} ${INTENT}"

  while IFS= read -r candidate_file; do
    [[ -n "$candidate_file" ]] || continue
    candidate_name=$(basename "$candidate_file")
    candidate_name="${candidate_name%.*}"
    parent_name=$(basename "$(dirname "$candidate_file")")

    if text_contains_token "$target_context" "$candidate_name" || text_contains_token "$target_context" "$parent_name"; then
      add_or_update_anchor "source" "$candidate_file" "source_path_mapping" "External source file ${candidate_file} matches target tokens for ${target_file}."
      matched=0
      break
    fi
  done < <(find "$source_root" -type f \( -name "*.md" -o -name "*.yaml" -o -name "*.yml" \) 2>/dev/null | sort)

  return "$matched"
}

resolve_parasitic_mode_for_file() {
  local target_file="$1"
  local matched=0
  local source_path source_type _stale _inject

  while IFS=$'\t' read -r source_path source_type _stale _inject; do
    [[ -n "$source_path" ]] || continue
    SOURCES_CHECKED=$((SOURCES_CHECKED + 1))

    if [[ "$target_file" == "$source_path"* ]]; then
      add_or_update_anchor "source" "$source_path" "source_path_mapping" "Target file ${target_file} is inside configured source ${source_path}."
      matched=1
      continue
    fi

    if [[ -d "$source_path" ]]; then
      if resolve_source_file_match "$source_path" "$target_file"; then
        matched=1
      fi
    fi

    if [[ -n "$INTENT" ]] && text_contains_token "$INTENT" "$(module_label_from_path "$source_path")"; then
      add_or_update_anchor "source" "$source_path" "intent_keyword" "Intent mentions external source token $(module_label_from_path "$source_path")."
    fi
  done < <(sa_iter_config_sources "$CONFIG_PATH")

  if [[ "$matched" -eq 0 ]]; then
    add_missing "source" "$target_file" "No external source matched this file path." "add a source mapping or create a Module Spec"
  fi
}

resolve_by_mode() {
  local target_file
  resolve_global_anchors

  while IFS= read -r target_file; do
    [[ -n "$target_file" ]] || continue
    if [[ "$MODE" == "full" ]]; then
      resolve_full_mode_for_file "$target_file"
    else
      resolve_parasitic_mode_for_file "$target_file"
    fi
  done < <(printf '%s\n' "${TARGET_FILES[@]:-}")
}

collect_task_specs() {
  TASK_FILES=()
  [[ -d ".specanchor/tasks" ]] || return 0
  while IFS= read -r task_file; do
    [[ -n "$task_file" ]] || continue
    TASK_FILES+=("$task_file")
  done < <(find ".specanchor/tasks" -name "*.spec.md" 2>/dev/null | sort)
}

add_fallback_anchor_if_needed() {
  local non_global_count=0
  local i=0
  while [[ $i -lt ${#ANCH_PATHS[@]} ]]; do
    if [[ "${ANCH_LEVELS[$i]}" != "global" ]]; then
      non_global_count=$((non_global_count + 1))
    fi
    i=$((i + 1))
  done

  if [[ "$non_global_count" -eq 0 ]] && [[ "$MODE" == "full" ]] && [[ -f "$CODEMAP_PATH" ]]; then
    add_or_update_anchor "codemap" "$CODEMAP_PATH" "fallback_global_only" "No module anchor matched; fall back to global specs plus project codemap."
    add_warning "GLOBAL_ONLY" "No module anchor matched. The plan falls back to global specs and codemap guidance."
  fi
}

recalculate_budget_estimate() {
  ESTIMATED_FILES=0
  ESTIMATED_LINES=0
  local i=0
  while [[ $i -lt ${#ANCH_PATHS[@]} ]]; do
    if [[ "${ANCH_LOADS[$i]}" != "skipped" ]] && [[ "${ANCH_LOADS[$i]}" != "none" ]]; then
      ESTIMATED_FILES=$((ESTIMATED_FILES + 1))
      ESTIMATED_LINES=$((ESTIMATED_LINES + $(line_estimate_for_load "${ANCH_LOADS[$i]}" "${ANCH_LINE_COUNTS[$i]}")))
    fi
    i=$((i + 1))
  done
}

enforce_budget_caps() {
  recalculate_budget_estimate
  local changed=0
  local i=0

  while [[ "$ESTIMATED_FILES" -gt "$MAX_FILES" || "$ESTIMATED_LINES" -gt "$MAX_LINES" ]]; do
    changed=0
    i=0
    while [[ $i -lt ${#ANCH_PATHS[@]} ]]; do
      if [[ "${ANCH_LOADS[$i]}" == "full" ]] && [[ "${ANCH_LEVELS[$i]}" != "global" ]]; then
        ANCH_LOADS[$i]="summary"
        changed=1
        break
      fi
      if [[ "${ANCH_LOADS[$i]}" == "summary" ]] && { [[ "${ANCH_LEVELS[$i]}" == "task" ]] || [[ "${ANCH_LEVELS[$i]}" == "codemap" ]]; }; then
        ANCH_LOADS[$i]="skipped"
        changed=1
        break
      fi
      i=$((i + 1))
    done
    if [[ "$changed" -eq 0 ]]; then
      break
    fi
    TRUNCATED="true"
    recalculate_budget_estimate
  done
}

status_value() {
  if [[ -z "$CONFIG_PATH" ]]; then
    printf 'error\n'
  elif [[ ${#MISSING_PATHS[@]} -gt 0 ]] || [[ ${#WARNING_MESSAGES[@]} -gt 0 ]]; then
    printf 'warning\n'
  else
    printf 'ok\n'
  fi
}

print_json_reasons() {
  local raw="$1"
  local first=1 reason
  printf '['
  IFS='||'
  for reason in $raw; do
    [[ -n "$reason" ]] || continue
    if [[ $first -eq 0 ]]; then
      printf ','
    fi
    printf '"%s"' "$(sa_json_escape "$reason")"
    first=0
  done
  unset IFS
  printf ']'
}

print_json() {
  local i=0
  printf '{\n'
  printf '  "schema_version": "specanchor.resolve.v2",\n'
  printf '  "status": "%s",\n' "$(status_value)"
  printf '  "mode": "%s",\n' "$MODE"
  printf '  "budget": {\n'
  printf '    "profile": "%s",\n' "$BUDGET_PROFILE"
  printf '    "max_files": %s,\n' "$MAX_FILES"
  printf '    "max_lines": %s,\n' "$MAX_LINES"
  printf '    "estimated_files": %s,\n' "$ESTIMATED_FILES"
  printf '    "estimated_lines": %s,\n' "$ESTIMATED_LINES"
  printf '    "truncated": %s\n' "$TRUNCATED"
  printf '  },\n'
  printf '  "inputs": {\n'
  printf '    "files": ['
  i=0
  while [[ $i -lt ${#TARGET_FILES[@]} ]]; do
    [[ $i -gt 0 ]] && printf ','
    printf '"%s"' "$(sa_json_escape "${TARGET_FILES[$i]}")"
    i=$((i + 1))
  done
  printf '],\n'
  printf '    "intent": '
  if [[ -n "$INTENT" ]]; then
    printf '"%s",\n' "$(sa_json_escape "$INTENT")"
  else
    printf 'null,\n'
  fi
  printf '    "diff_from": '
  if [[ -n "$DIFF_FROM" ]]; then
    printf '"%s"\n' "$(sa_json_escape "$DIFF_FROM")"
  else
    printf 'null\n'
  fi
  printf '  },\n'
  printf '  "anchors": [\n'
  i=0
  while [[ $i -lt ${#ANCH_PATHS[@]} ]]; do
    [[ $i -gt 0 ]] && printf ',\n'
    printf '    {\n'
    printf '      "level": "%s",\n' "${ANCH_LEVELS[$i]}"
    printf '      "path": "%s",\n' "$(sa_json_escape "${ANCH_PATHS[$i]}")"
    printf '      "load": "%s",\n' "${ANCH_LOADS[$i]}"
    printf '      "match_type": "%s",\n' "${ANCH_MATCH_TYPES[$i]}"
    printf '      "confidence": %s,\n' "${ANCH_CONFIDENCES[$i]}"
    printf '      "reasons": '
    print_json_reasons "${ANCH_ALL_REASONS[$i]}"
    printf ',\n'
    printf '      "freshness": "%s"\n' "${ANCH_FRESHNESS[$i]}"
    printf '    }'
    i=$((i + 1))
  done
  printf '\n  ],\n'
  printf '  "missing": [\n'
  i=0
  while [[ $i -lt ${#MISSING_PATHS[@]} ]]; do
    [[ $i -gt 0 ]] && printf ',\n'
    printf '    {"type":"%s","path":"%s","reason":"%s","suggested_action":"%s"}' \
      "${MISSING_TYPES[$i]}" \
      "$(sa_json_escape "${MISSING_PATHS[$i]}")" \
      "$(sa_json_escape "${MISSING_REASONS[$i]}")" \
      "$(sa_json_escape "${MISSING_ACTIONS[$i]}")"
    i=$((i + 1))
  done
  printf '\n  ],\n'
  printf '  "warnings": [\n'
  i=0
  while [[ $i -lt ${#WARNING_MESSAGES[@]} ]]; do
    [[ $i -gt 0 ]] && printf ',\n'
    printf '    {"code":"%s","message":"%s"}' \
      "$(sa_json_escape "${WARNING_CODES[$i]}")" \
      "$(sa_json_escape "${WARNING_MESSAGES[$i]}")"
    i=$((i + 1))
  done
  printf '\n  ],\n'
  printf '  "trace": {\n'
  printf '    "config": "%s",\n' "$(sa_json_escape "$CONFIG_PATH")"
  printf '    "spec_index": "%s",\n' "$(sa_json_escape "$SPEC_INDEX_PATH")"
  printf '    "codemap": "%s",\n' "$(sa_json_escape "$CODEMAP_PATH")"
  printf '    "sources_checked": %s,\n' "$SOURCES_CHECKED"
  printf '    "resolver": "specanchor-resolve.sh"\n'
  printf '  }\n'
  printf '}\n'
}

print_markdown() {
  local i=0
  echo "# SpecAnchor Resolve Plan"
  echo ""
  echo "Status: $(status_value)"
  echo "Budget: ${BUDGET_PROFILE}, estimated ${ESTIMATED_FILES} files / ${ESTIMATED_LINES} lines"
  echo ""
  echo "## Anchors to Load"
  if [[ ${#ANCH_PATHS[@]} -eq 0 ]]; then
    echo "- none"
  fi
  while [[ $i -lt ${#ANCH_PATHS[@]} ]]; do
    echo "- [${ANCH_LEVELS[$i]}:${ANCH_LOADS[$i]}] ${ANCH_PATHS[$i]}"
    echo "  - confidence: ${ANCH_CONFIDENCES[$i]}"
    echo "  - match_type: ${ANCH_MATCH_TYPES[$i]}"
    echo "  - freshness: ${ANCH_FRESHNESS[$i]}"
    echo "  - reason: ${ANCH_PRIMARY_REASONS[$i]}"
    i=$((i + 1))
  done

  echo ""
  echo "## Missing Coverage"
  if [[ ${#MISSING_PATHS[@]} -eq 0 ]]; then
    echo "- none"
  else
    i=0
    while [[ $i -lt ${#MISSING_PATHS[@]} ]]; do
      echo "- ${MISSING_PATHS[$i]} -> ${MISSING_REASONS[$i]}"
      i=$((i + 1))
    done
  fi

  if [[ ${#WARNING_MESSAGES[@]} -gt 0 ]]; then
    echo ""
    echo "## Warnings"
    i=0
    while [[ $i -lt ${#WARNING_MESSAGES[@]} ]]; do
      echo "- ${WARNING_CODES[$i]}: ${WARNING_MESSAGES[$i]}"
      i=$((i + 1))
    done
  fi

  echo ""
  echo "## Trace"
  echo "- config: ${CONFIG_PATH}"
  echo "- spec_index: ${SPEC_INDEX_PATH}"
  echo "- codemap: ${CODEMAP_PATH}"
  echo "- sources_checked: ${SOURCES_CHECKED}"
  echo "- resolver: specanchor-resolve.sh"
}

usage() {
  cat <<'EOF'
Usage:
  bash scripts/specanchor-resolve.sh --files "scripts/specanchor-boot.sh" --intent "debug startup" --budget=normal --format=json
  bash scripts/specanchor-resolve.sh --files-from .specanchor/tmp/changed-files.txt --intent-file .specanchor/tmp/task-intent.txt --format=markdown
  bash scripts/specanchor-resolve.sh --diff-from=main --budget=compact --format=json
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
      --files-from=*) FILES_FROM="${1#--files-from=}" ;;
      --files-from)
        shift
        [[ $# -gt 0 ]] || sa_die "--files-from requires a value" 64
        FILES_FROM="$1"
        ;;
      --intent=*) INTENT="${1#--intent=}" ;;
      --intent)
        shift
        [[ $# -gt 0 ]] || sa_die "--intent requires a value" 64
        INTENT="$1"
        ;;
      --intent-file=*) INTENT_FILE="${1#--intent-file=}" ;;
      --intent-file)
        shift
        [[ $# -gt 0 ]] || sa_die "--intent-file requires a value" 64
        INTENT_FILE="$1"
        ;;
      --diff-from=*) DIFF_FROM="${1#--diff-from=}" ;;
      --diff-from)
        shift
        [[ $# -gt 0 ]] || sa_die "--diff-from requires a value" 64
        DIFF_FROM="$1"
        ;;
      --budget=*) BUDGET_PROFILE="${1#--budget=}" ;;
      --budget)
        shift
        [[ $# -gt 0 ]] || sa_die "--budget requires a value" 64
        BUDGET_PROFILE="$1"
        ;;
      --format=text|--format=summary) FORMAT="text" ;;
      --format=markdown) FORMAT="markdown" ;;
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

  load_intent
  load_target_files
  set_budget_limits

  if [[ ${#TARGET_FILES[@]} -eq 0 ]] && [[ -z "$INTENT" ]]; then
    sa_die "at least one of --files/--files-from/--diff-from/--intent is required" 64
  fi

  if ! load_config; then
    if [[ "$FORMAT" == "json" ]]; then
      printf '{"schema_version":"specanchor.resolve.v2","status":"error","mode":"unknown","budget":{"profile":"%s","max_files":%s,"max_lines":%s,"estimated_files":0,"estimated_lines":0,"truncated":false},"inputs":{"files":[],"intent":null,"diff_from":null},"anchors":[],"missing":[],"warnings":[{"code":"CONFIG_MISSING","message":"anchor.yaml or .specanchor/config.yaml was not found."}],"trace":{"config":"","spec_index":"","codemap":"","sources_checked":0,"resolver":"specanchor-resolve.sh"}}\n' "$BUDGET_PROFILE" "$MAX_FILES" "$MAX_LINES"
      exit 2
    fi
    sa_die "CONFIG_MISSING: 未找到 anchor.yaml 或 .specanchor/config.yaml" 2
  fi

  collect_task_specs
  resolve_by_mode
  add_fallback_anchor_if_needed
  enforce_budget_caps

  case "$FORMAT" in
    text|markdown) print_markdown ;;
    json) print_json ;;
    *) sa_die "invalid format: ${FORMAT}" 64 ;;
  esac
}

main "$@"
