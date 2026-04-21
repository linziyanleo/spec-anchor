#!/usr/bin/env bash
# SpecAnchor Hygiene - read-only spec drift and dead-link checks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

FORMAT="markdown"
FIX_GENERATED="false"

declare -a FINDING_SEVERITY=()
declare -a FINDING_CODE=()
declare -a FINDING_PATH=()
declare -a FINDING_MESSAGE=()
declare -a FINDING_ACTION=()

DEAD_LINKS=0
DUPLICATE_MODULES=0
STALE_TASKS=0
OVERSIZED_GLOBALS=0

add_finding() {
  FINDING_SEVERITY+=("$1")
  FINDING_CODE+=("$2")
  FINDING_PATH+=("$3")
  FINDING_MESSAGE+=("$4")
  FINDING_ACTION+=("$5")
}

hygiene_status() {
  if [[ ${#FINDING_CODE[@]} -gt 0 ]]; then
    printf 'warning\n'
  else
    printf 'ok\n'
  fi
}

check_module_index() {
  local module_index=".specanchor/module-index.md"
  if [[ ! -f "$module_index" ]]; then
    add_finding "warning" "MODULE_INDEX_MISSING" "$module_index" "module-index.md is missing." "Run bash scripts/specanchor-index.sh"
    if [[ "$FIX_GENERATED" == "true" ]]; then
      bash "$SCRIPT_DIR/specanchor-index.sh" >/dev/null
    fi
    return 0
  fi

  local line_count
  line_count=$(sa_file_line_count "$module_index")
  if [[ "$line_count" -gt 220 ]]; then
    add_finding "warning" "MODULE_INDEX_TOO_LONG" "$module_index" "module-index.md exceeds the recommended line budget." "Prune summaries or regenerate the index."
  fi

  local in_modules=0 current_path="" current_spec=""
  while IFS= read -r line; do
    local trimmed
    trimmed=$(sa_trim_spaces "$line")
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
      current_path=$(sa_normalize_scalar "${trimmed#- path:}")
    elif [[ "$trimmed" == "spec:"* ]]; then
      current_spec=$(sa_normalize_scalar "${trimmed#spec:}")
      if [[ -n "$current_path" ]] && [[ ! -e "$current_path" ]]; then
        add_finding "warning" "MODULE_INDEX_PATH_MISSING" "$current_path" "module-index references a path that does not exist." "Update the index or restore the path."
      fi
      if [[ -n "$current_spec" ]] && [[ ! -f ".specanchor/modules/${current_spec}" ]]; then
        add_finding "warning" "MODULE_INDEX_SPEC_MISSING" ".specanchor/modules/${current_spec}" "module-index references a Module Spec that does not exist." "Regenerate the index."
      fi
      current_path=""
      current_spec=""
    fi
  done < "$module_index"

  if [[ "$FIX_GENERATED" == "true" ]] && grep -q 'MODULE_INDEX_' < <(printf '%s\n' "${FINDING_CODE[@]:-}"); then
    bash "$SCRIPT_DIR/specanchor-index.sh" >/dev/null
  fi
}

check_duplicate_modules() {
  [[ -d ".specanchor/modules" ]] || return 0
  local files=()
  local file=""
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    files+=("$file")
  done < <(find .specanchor/modules -maxdepth 1 -name "*.spec.md" | sort)

  local i=0 j module_path_i module_path_j
  while [[ $i -lt ${#files[@]} ]]; do
    module_path_i=$(sa_parse_frontmatter_field "${files[$i]}" "module_path")
    j=$((i + 1))
    while [[ $j -lt ${#files[@]} ]]; do
      module_path_j=$(sa_parse_frontmatter_field "${files[$j]}" "module_path")
      if [[ -n "$module_path_i" ]] && [[ "$module_path_i" == "$module_path_j" ]]; then
        DUPLICATE_MODULES=$((DUPLICATE_MODULES + 1))
        add_finding "warning" "DUPLICATE_MODULE_PATH" "${files[$j]}" "Multiple Module Specs share module_path ${module_path_i}." "Keep only one Module Spec per module_path."
      fi
      j=$((j + 1))
    done
    i=$((i + 1))
  done
}

check_global_sizes() {
  local file=""
  for file in .specanchor/global/*.spec.md; do
    [[ -f "$file" ]] || continue
    local lines
    lines=$(sa_file_line_count "$file")
    if [[ "$lines" -gt 120 ]]; then
      OVERSIZED_GLOBALS=$((OVERSIZED_GLOBALS + 1))
      add_finding "warning" "GLOBAL_TOO_LONG" "$file" "Global Spec exceeds the recommended single-file budget." "Move details into Module Specs or reference docs."
    fi
  done
}

check_module_summaries() {
  local file summary
  for file in .specanchor/modules/*.spec.md; do
    [[ -f "$file" ]] || continue
    summary=$(sa_parse_frontmatter_field "$file" "summary")
    if [[ -z "$summary" ]] || [[ ${#summary} -lt 12 ]]; then
      add_finding "warning" "MODULE_SUMMARY_WEAK" "$file" "Module Spec summary is missing or too short." "Write a concise summary that helps resolver/assembler decisions."
    fi
  done
}

check_dead_links() {
  command -v python3 >/dev/null 2>&1 || return 0

  local files=() file=""
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    files+=("$file")
  done < <(find README.md README_ZH.md WHY.md WHY_ZH.md SKILL.md references docs -type f -name "*.md" 2>/dev/null | sort)

  [[ ${#files[@]} -gt 0 ]] || return 0

  local result=""
  result=$(python3 - "${files[@]}" <<'PY'
import re
import sys
from pathlib import Path

for raw in sys.argv[1:]:
    path = Path(raw)
    text = path.read_text(encoding="utf-8")
    for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)', text):
        target = target.strip().strip('<>')
        if not target or target.startswith('#') or '://' in target or target.startswith('mailto:'):
            continue
        target = target.split('#', 1)[0].split('?', 1)[0]
        candidate = (path.parent / target).resolve()
        if not candidate.exists():
            print(f"{raw}\t{target}")
PY
)
  if [[ -n "$result" ]]; then
    local raw_file target
    while IFS=$'\t' read -r raw_file target; do
      [[ -n "$raw_file" ]] || continue
      DEAD_LINKS=$((DEAD_LINKS + 1))
      add_finding "warning" "DEAD_LINK" "$raw_file" "Dead local link target: ${target}" "Fix the link or restore the referenced file."
    done <<< "$result"
  fi
}

check_stale_tasks() {
  local now_epoch task_file date_value task_epoch age_days status
  now_epoch=$(date "+%s")
  while IFS= read -r task_file; do
    [[ -n "$task_file" ]] || continue
    status=$(sa_parse_frontmatter_field "$task_file" "status")
    [[ "$status" == "archived" ]] && continue
    date_value=$(sa_parse_frontmatter_field "$task_file" "updated")
    [[ -z "$date_value" ]] && date_value=$(sa_parse_frontmatter_field "$task_file" "created")
    [[ -n "$date_value" ]] || continue
    task_epoch=$(sa_date_to_epoch "$date_value")
    [[ -n "$task_epoch" ]] || continue
    age_days=$(( (now_epoch - task_epoch) / 86400 ))
    if [[ "$age_days" -gt 30 ]]; then
      STALE_TASKS=$((STALE_TASKS + 1))
      add_finding "warning" "STALE_TASK" "$task_file" "Task Spec is older than 30 days and still not archived." "Archive the task or refresh its status."
    fi
  done < <(find .specanchor/tasks -name "*.spec.md" 2>/dev/null | sort)
}

check_spec_reference_drift() {
  local file supersedes module_path status allow_missing
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    supersedes=$(sa_parse_frontmatter_field "$file" "supersedes")
    status=$(sa_parse_frontmatter_field "$file" "status")
    module_path=$(sa_parse_frontmatter_field "$file" "module_path")
    allow_missing=$(sa_parse_frontmatter_field "$file" "allow_missing_module_path")

    if [[ -n "$supersedes" ]] && [[ ! -f "$supersedes" ]]; then
      add_finding "warning" "SUPERSEDES_MISSING" "$file" "supersedes points to a file that no longer exists." "Update or remove the supersedes field."
    fi
    if [[ -n "$supersedes" ]] && [[ "$status" == "active" ]]; then
      add_finding "warning" "SUPERSEDES_STATUS_CONFLICT" "$file" "Spec is active while also declaring supersedes." "Clarify the lifecycle state."
    fi
    if [[ -n "$module_path" ]] && [[ ! -e "$module_path" ]] && [[ "$allow_missing" != "true" ]]; then
      add_finding "warning" "MODULE_PATH_REMOVED" "$file" "module_path points to a removed path." "Update module_path or mark allow_missing_module_path: true."
    fi
  done < <(find .specanchor/global .specanchor/modules .specanchor/tasks .specanchor/archive -name "*.spec.md" 2>/dev/null | sort)
}

check_optional_sources() {
  local config
  if ! config=$(sa_find_config 2>/dev/null); then
    return 0
  fi

  local raw_path optional path
  raw_path=""
  optional="false"
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*path:[[:space:]]*\"?([^\"]+)\"? ]]; then
      raw_path="${BASH_REMATCH[1]}"
      optional="false"
      continue
    fi
    if [[ -n "$raw_path" ]] && [[ "$line" =~ optional:[[:space:]]*(true|false) ]]; then
      optional="${BASH_REMATCH[1]}"
      path="$raw_path"
      if [[ "$optional" == "true" ]] && [[ -d "$path" ]] && [[ -z "$(find "$path" -mindepth 1 -maxdepth 1 2>/dev/null | head -1)" ]]; then
        add_finding "warning" "OPTIONAL_SOURCE_EMPTY" "$path" "Optional source exists but is empty." "Remove it or populate it with actual specs."
      fi
      raw_path=""
      optional="false"
    fi
  done < "$config"
}

print_json() {
  local i=0
  printf '{\n'
  printf '  "schema_version": "specanchor.hygiene.v1",\n'
  printf '  "status": "%s",\n' "$(hygiene_status)"
  printf '  "summary": {\n'
  printf '    "dead_links": %s,\n' "$DEAD_LINKS"
  printf '    "duplicate_modules": %s,\n' "$DUPLICATE_MODULES"
  printf '    "stale_tasks": %s,\n' "$STALE_TASKS"
  printf '    "oversized_globals": %s\n' "$OVERSIZED_GLOBALS"
  printf '  },\n'
  printf '  "findings": [\n'
  while [[ $i -lt ${#FINDING_CODE[@]} ]]; do
    [[ $i -gt 0 ]] && printf ',\n'
    printf '    {"severity":"%s","code":"%s","path":"%s","message":"%s","suggested_action":"%s"}' \
      "${FINDING_SEVERITY[$i]}" \
      "$(sa_json_escape "${FINDING_CODE[$i]}")" \
      "$(sa_json_escape "${FINDING_PATH[$i]}")" \
      "$(sa_json_escape "${FINDING_MESSAGE[$i]}")" \
      "$(sa_json_escape "${FINDING_ACTION[$i]}")"
    i=$((i + 1))
  done
  printf '\n  ]\n'
  printf '}\n'
}

print_markdown() {
  local i=0
  echo "# SpecAnchor Hygiene"
  echo ""
  echo "Status: $(hygiene_status)"
  echo ""
  echo "Summary:"
  echo "- Dead links: ${DEAD_LINKS}"
  echo "- Duplicate modules: ${DUPLICATE_MODULES}"
  echo "- Stale tasks: ${STALE_TASKS}"
  echo "- Oversized globals: ${OVERSIZED_GLOBALS}"
  echo ""
  echo "Findings:"
  if [[ ${#FINDING_CODE[@]} -eq 0 ]]; then
    echo "- none"
    return 0
  fi
  while [[ $i -lt ${#FINDING_CODE[@]} ]]; do
    echo "- [${FINDING_SEVERITY[$i]}] ${FINDING_CODE[$i]} :: ${FINDING_PATH[$i]}"
    echo "  ${FINDING_MESSAGE[$i]}"
    echo "  Suggested action: ${FINDING_ACTION[$i]}"
    i=$((i + 1))
  done
}

usage() {
  cat <<'EOF'
Usage:
  bash scripts/specanchor-hygiene.sh --format=markdown
  bash scripts/specanchor-hygiene.sh --format=json
  bash scripts/specanchor-hygiene.sh --fix-generated
EOF
  exit 0
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format=markdown|--format=text) FORMAT="markdown" ;;
      --format=json) FORMAT="json" ;;
      --format)
        shift
        [[ $# -gt 0 ]] || sa_die "--format requires a value" 64
        FORMAT="$1"
        ;;
      --fix-generated) FIX_GENERATED="true" ;;
      --help|-h) usage ;;
      *) sa_die "invalid argument: $1" 64 ;;
    esac
    shift
  done

  check_module_index
  check_duplicate_modules
  check_global_sizes
  check_module_summaries
  check_dead_links
  check_stale_tasks
  check_spec_reference_drift
  check_optional_sources

  case "$FORMAT" in
    markdown|text) print_markdown ;;
    json) print_json ;;
    *) sa_die "invalid format: ${FORMAT}" 64 ;;
  esac
}

main "$@"
