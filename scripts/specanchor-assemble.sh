#!/usr/bin/env bash
# SpecAnchor Assemble - convert resolved anchors into an agent-ready context plan.

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
RESOLVE_JSON=""
WRITE_TRACE=""

TMP_FILES=()

declare -a FILES_TO_READ_PATHS=()
declare -a FILES_TO_READ_LOADS=()
declare -a FILES_TO_READ_REASONS=()
declare -a WARNING_MESSAGES=()
declare -a AGENT_INSTRUCTIONS=()

STATUS="ok"
MAX_FILES=12
MAX_LINES=1200
ESTIMATED_FILES=0
ESTIMATED_LINES=0
TRUNCATED="false"
MISSING_COUNT=0
GLOBAL_TRACE="none"
MODULE_TRACE="none"
TASK_TRACE="none"
SOURCES_TRACE="none"

cleanup() {
  local path=""
  for path in "${TMP_FILES[@]:-}"; do
    [[ -n "$path" ]] && rm -f "$path" 2>/dev/null || true
  done
}
trap cleanup EXIT

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
    skipped|none) printf '0\n' ;;
    *) printf '%s\n' "$line_count" ;;
  esac
}

trace_mode_rank() {
  case "$1" in
    none) printf '0\n' ;;
    skipped) printf '1\n' ;;
    summary) printf '2\n' ;;
    full) printf '3\n' ;;
    *) printf '0\n' ;;
  esac
}

merge_trace_mode() {
  local current="$1"
  local candidate="$2"
  if (( $(trace_mode_rank "$candidate") > $(trace_mode_rank "$current") )); then
    printf '%s\n' "$candidate"
  else
    printf '%s\n' "$current"
  fi
}

assembly_load_for_anchor() {
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

add_file_to_read() {
  local path="$1"
  local load="$2"
  local reason="$3"
  [[ "$load" != "skipped" ]] || return 0
  [[ "$load" != "none" ]] || return 0

  local i=0
  while [[ $i -lt ${#FILES_TO_READ_PATHS[@]} ]]; do
    if [[ "${FILES_TO_READ_PATHS[$i]}" == "$path" ]]; then
      FILES_TO_READ_REASONS[$i]=$(printf '%s / %s' "${FILES_TO_READ_REASONS[$i]}" "$reason")
      return 0
    fi
    i=$((i + 1))
  done

  FILES_TO_READ_PATHS+=("$path")
  FILES_TO_READ_LOADS+=("$load")
  FILES_TO_READ_REASONS+=("$reason")
}

join_paths_for_trace() {
  local category="$1"
  local out="" i=0 path
  while [[ $i -lt ${#FILES_TO_READ_PATHS[@]} ]]; do
    path="${FILES_TO_READ_PATHS[$i]}"
    case "$category" in
      global)
        [[ "$path" == *"/global/"* ]] || {
          i=$((i + 1))
          continue
        }
        ;;
      module)
        [[ "$path" == *"/modules/"* ]] || [[ "$path" == *"project-codemap.md" ]] || {
          i=$((i + 1))
          continue
        }
        ;;
      task)
        [[ "$path" == *"/tasks/"* ]] || {
          i=$((i + 1))
          continue
        }
        ;;
      source)
        [[ "$path" == *"/global/"* ]] && {
          i=$((i + 1))
          continue
        }
        [[ "$path" == *"/modules/"* ]] && {
          i=$((i + 1))
          continue
        }
        [[ "$path" == *"/tasks/"* ]] && {
          i=$((i + 1))
          continue
        }
        [[ "$path" == *"project-codemap.md" ]] && {
          i=$((i + 1))
          continue
        }
        ;;
    esac
    if [[ -n "$out" ]]; then
      out="${out}, ${path}"
    else
      out="$path"
    fi
    i=$((i + 1))
  done
  printf '%s\n' "$out"
}

write_trace_if_requested() {
  [[ -n "$WRITE_TRACE" ]] || return 0
  mkdir -p "$(dirname "$WRITE_TRACE")"
  case "$FORMAT" in
    json)
      print_json > "$WRITE_TRACE"
      ;;
    *)
      local trace_tmp
      trace_tmp=$(mktemp)
      TMP_FILES+=("$trace_tmp")
      print_json > "$trace_tmp"
      cp "$trace_tmp" "$WRITE_TRACE"
      ;;
  esac
}

build_resolve_json() {
  if [[ -n "$RESOLVE_JSON" ]]; then
    [[ -f "$RESOLVE_JSON" ]] || sa_die "--resolve-json file not found: ${RESOLVE_JSON}" 64
    printf '%s\n' "$RESOLVE_JSON"
    return 0
  fi

  local resolve_tmp cmd=()
  resolve_tmp=$(mktemp)
  TMP_FILES+=("$resolve_tmp")

  cmd=(bash "$SCRIPT_DIR/specanchor-resolve.sh" "--budget=${BUDGET_PROFILE}" --format=json)
  [[ -n "$FILES_CSV" ]] && cmd+=("--files=${FILES_CSV}")
  [[ -n "$FILES_FROM" ]] && cmd+=("--files-from=${FILES_FROM}")
  [[ -n "$INTENT" ]] && cmd+=("--intent=${INTENT}")
  [[ -n "$INTENT_FILE" ]] && cmd+=("--intent-file=${INTENT_FILE}")
  [[ -n "$DIFF_FROM" ]] && cmd+=("--diff-from=${DIFF_FROM}")

  "${cmd[@]}" > "$resolve_tmp"
  printf '%s\n' "$resolve_tmp"
}

parse_resolve_json() {
  local resolve_json="$1"
  command -v python3 >/dev/null 2>&1 || sa_die "python3 is required for specanchor-assemble.sh" 1

  local line kind rest
  while IFS=$'\t' read -r kind rest; do
    case "$kind" in
      STATUS) STATUS="$rest" ;;
      PROFILE) BUDGET_PROFILE="$rest" ;;
      MAX_FILES) MAX_FILES="$rest" ;;
      MAX_LINES) MAX_LINES="$rest" ;;
      MISSING_COUNT) MISSING_COUNT="$rest" ;;
      WARNING)
        WARNING_MESSAGES+=("$rest")
        ;;
      ANCHOR)
        local level path match_type primary_reason load
        IFS=$'\t' read -r level path match_type primary_reason load <<< "$rest"
        load=$(assembly_load_for_anchor "$level" "$path")
        add_file_to_read "$path" "$load" "$primary_reason"
        case "$level" in
          global) GLOBAL_TRACE=$(merge_trace_mode "$GLOBAL_TRACE" "$load") ;;
          module) MODULE_TRACE=$(merge_trace_mode "$MODULE_TRACE" "$load") ;;
          task) TASK_TRACE=$(merge_trace_mode "$TASK_TRACE" "$load") ;;
          source) SOURCES_TRACE=$(merge_trace_mode "$SOURCES_TRACE" "$load") ;;
        esac
        if [[ "$level" == "codemap" ]] && [[ "$load" != "skipped" ]]; then
          MODULE_TRACE=$(merge_trace_mode "$MODULE_TRACE" "summary")
        fi
        ;;
    esac
  done < <(
    python3 - "$resolve_json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)

budget = data.get("budget", {})
print("STATUS\t" + data.get("status", "error"))
print("PROFILE\t" + budget.get("profile", "normal"))
print("MAX_FILES\t" + str(budget.get("max_files", 12)))
print("MAX_LINES\t" + str(budget.get("max_lines", 1200)))
print("MISSING_COUNT\t" + str(len(data.get("missing", []))))

for warning in data.get("warnings", []):
    if isinstance(warning, dict):
        message = warning.get("message", "")
    else:
        message = str(warning)
    print("WARNING\t" + message.replace("\t", " ").replace("\n", " "))

for anchor in data.get("anchors", []):
    reasons = anchor.get("reasons", [])
    primary_reason = reasons[0] if reasons else anchor.get("match_type", "")
    fields = [
        anchor.get("level", ""),
        anchor.get("path", ""),
        anchor.get("match_type", ""),
        primary_reason,
        anchor.get("load", ""),
    ]
    print("ANCHOR\t" + "\t".join(value.replace("\t", " ").replace("\n", " ") for value in fields))
PY
  )
}

enforce_budget_caps() {
  local i=0 changed=0

  recalculate_estimate
  while [[ "$ESTIMATED_FILES" -gt "$MAX_FILES" || "$ESTIMATED_LINES" -gt "$MAX_LINES" ]]; do
    changed=0
    i=0
    while [[ $i -lt ${#FILES_TO_READ_PATHS[@]} ]]; do
      if [[ "${FILES_TO_READ_LOADS[$i]}" == "full" ]]; then
        FILES_TO_READ_LOADS[$i]="summary"
        changed=1
        break
      fi
      i=$((i + 1))
    done
    if [[ "$changed" -eq 0 ]]; then
      break
    fi
    TRUNCATED="true"
    recalculate_estimate
  done
}

recalculate_estimate() {
  ESTIMATED_FILES=0
  ESTIMATED_LINES=0
  local i=0 line_count
  while [[ $i -lt ${#FILES_TO_READ_PATHS[@]} ]]; do
    ESTIMATED_FILES=$((ESTIMATED_FILES + 1))
    line_count=$(sa_file_line_count "${FILES_TO_READ_PATHS[$i]}")
    ESTIMATED_LINES=$((ESTIMATED_LINES + $(line_estimate_for_load "${FILES_TO_READ_LOADS[$i]}" "$line_count")))
    i=$((i + 1))
  done
}

finalize_instructions() {
  AGENT_INSTRUCTIONS=()
  AGENT_INSTRUCTIONS+=("Read files_to_read before editing code.")
  if [[ "$MISSING_COUNT" -gt 0 ]]; then
    AGENT_INSTRUCTIONS+=("Missing coverage exists. Do not invent business rules; stop or create a Task Spec.")
  else
    AGENT_INSTRUCTIONS+=("Report the anchors you used before proposing or applying changes.")
  fi
  if [[ ${#WARNING_MESSAGES[@]} -gt 0 ]]; then
    AGENT_INSTRUCTIONS+=("Carry warnings forward in the final report so missing or risky context stays visible.")
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

print_json() {
  local i=0
  printf '{\n'
  printf '  "schema_version": "specanchor.assembly.v1",\n'
  printf '  "status": "%s",\n' "$STATUS"
  printf '  "budget": {\n'
  printf '    "profile": "%s",\n' "$BUDGET_PROFILE"
  printf '    "max_files": %s,\n' "$MAX_FILES"
  printf '    "max_lines": %s,\n' "$MAX_LINES"
  printf '    "estimated_files": %s,\n' "$ESTIMATED_FILES"
  printf '    "estimated_lines": %s,\n' "$ESTIMATED_LINES"
  printf '    "truncated": %s\n' "$TRUNCATED"
  printf '  },\n'
  printf '  "files_to_read": [\n'
  while [[ $i -lt ${#FILES_TO_READ_PATHS[@]} ]]; do
    [[ $i -gt 0 ]] && printf ',\n'
    printf '    {"path":"%s","load":"%s","reason":"%s"}' \
      "$(sa_json_escape "${FILES_TO_READ_PATHS[$i]}")" \
      "${FILES_TO_READ_LOADS[$i]}" \
      "$(sa_json_escape "${FILES_TO_READ_REASONS[$i]}")"
    i=$((i + 1))
  done
  printf '\n  ],\n'
  printf '  "agent_instructions": '
  print_json_array AGENT_INSTRUCTIONS
  printf ',\n'
  printf '  "assembly_trace": {\n'
  printf '    "global": "%s",\n' "$GLOBAL_TRACE"
  printf '    "module": "%s",\n' "$MODULE_TRACE"
  printf '    "task": "%s",\n' "$TASK_TRACE"
  printf '    "sources": "%s",\n' "$SOURCES_TRACE"
  printf '    "missing": %s\n' "$MISSING_COUNT"
  printf '  },\n'
  printf '  "warnings": '
  print_json_array WARNING_MESSAGES
  printf '\n}\n'
}

print_markdown() {
  local i=0
  echo "Assembly Trace:"
  if [[ ${#FILES_TO_READ_PATHS[@]} -eq 0 ]]; then
    echo "- Global: none"
  else
    echo "- Global: ${GLOBAL_TRACE} -> $(join_paths_for_trace global)"
  fi
  echo "- Module: ${MODULE_TRACE} -> $(join_paths_for_trace module)"
  echo "- Task: ${TASK_TRACE} -> $(join_paths_for_trace task)"
  echo "- Sources: ${SOURCES_TRACE} -> $(join_paths_for_trace source)"
  echo "- Missing: ${MISSING_COUNT}"
  echo "- Budget: ${BUDGET_PROFILE}, ${ESTIMATED_FILES} files / ${ESTIMATED_LINES} estimated lines"
  echo ""
  echo "Agent Instructions:"
  i=0
  while [[ $i -lt ${#AGENT_INSTRUCTIONS[@]} ]]; do
    echo "$((i + 1)). ${AGENT_INSTRUCTIONS[$i]}"
    i=$((i + 1))
  done
  echo ""
  echo "Files to Read:"
  i=0
  while [[ $i -lt ${#FILES_TO_READ_PATHS[@]} ]]; do
    echo "- ${FILES_TO_READ_PATHS[$i]} (${FILES_TO_READ_LOADS[$i]})"
    i=$((i + 1))
  done
  if [[ ${#WARNING_MESSAGES[@]} -gt 0 ]]; then
    echo ""
    echo "Warnings:"
    i=0
    while [[ $i -lt ${#WARNING_MESSAGES[@]} ]]; do
      echo "- ${WARNING_MESSAGES[$i]}"
      i=$((i + 1))
    done
  fi
}

usage() {
  cat <<'EOF'
Usage:
  bash scripts/specanchor-assemble.sh --files "scripts/specanchor-boot.sh" --intent "debug startup" --budget=normal --format=json
  bash scripts/specanchor-assemble.sh --resolve-json /tmp/specanchor-resolve.json --format=markdown
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
      --resolve-json=*) RESOLVE_JSON="${1#--resolve-json=}" ;;
      --resolve-json)
        shift
        [[ $# -gt 0 ]] || sa_die "--resolve-json requires a value" 64
        RESOLVE_JSON="$1"
        ;;
      --write-trace=*) WRITE_TRACE="${1#--write-trace=}" ;;
      --write-trace)
        shift
        [[ $# -gt 0 ]] || sa_die "--write-trace requires a value" 64
        WRITE_TRACE="$1"
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

  local resolve_json
  resolve_json=$(build_resolve_json)
  parse_resolve_json "$resolve_json"
  recalculate_estimate
  enforce_budget_caps
  finalize_instructions
  write_trace_if_requested

  case "$FORMAT" in
    text|markdown) print_markdown ;;
    json) print_json ;;
    *) sa_die "invalid format: ${FORMAT}" 64 ;;
  esac
}

main "$@"
