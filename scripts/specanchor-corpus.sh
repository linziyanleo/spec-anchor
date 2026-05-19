#!/usr/bin/env bash
# specanchor-corpus.sh — Checkpoint Decisions corpus collector for Steering Trigger
#
# Scans all task spec §5.2 Checkpoint Decisions Log entries across .specanchor/{tasks,archive}/
# and reports aggregate distribution + cross-task repeated patterns + threshold gate verdict.
#
# Drives Item 3 (Steering Trigger) of v0.5-deferred-followup.spec.md: corpus collector
# precedes design-draft decision (CP-3 of 2026-05-19_steering-trigger-corpus-and-design.spec.md).
#
# Reuses scripts/lib/decision-filter.sh::sa_parse_decisions for cp-NN parsing.
#
# Usage: specanchor-corpus.sh [--format=summary|json|details] [--scope=tasks|archive|all]
#                             [--dedupe-prefix=N] [--threshold=N]
# Exit:  0 = scan ok | 1 = scan failed | 2 = bad args

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=scripts/lib/decision-filter.sh
source "$SCRIPT_DIR/lib/decision-filter.sh"

sa_init_colors

# === Defaults ===
FORMAT="summary"
SCOPE="all"
DEDUPE_PREFIX=50
THRESHOLD=50

# Type enum (per sdd-riper-one v2 template)
STANDARD_TYPES="pass clarify add-spec redirect rollback halt"

# Legacy sentinel patterns (rule lines that mean "no real decision")
_corpus_is_legacy_sentinel() {
  local rule="$1"
  case "$rule" in
    ""|"(none)"|"(无)"|"(空)"|*"not applicable"*"legacy"*) return 0 ;;
  esac
  return 1
}

# === Arg parse ===
usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --format=summary|json|details   Output format (default: summary)
  --scope=tasks|archive|all       Scan scope (default: all)
  --dedupe-prefix=N               Repeated-pattern dedupe key length (default: 50)
  --threshold=N                   Steering Trigger threshold for verdict (default: 50)
  -h | --help                     Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format=*) FORMAT="${1#--format=}" ;;
    --scope=*) SCOPE="${1#--scope=}" ;;
    --dedupe-prefix=*) DEDUPE_PREFIX="${1#--dedupe-prefix=}" ;;
    --threshold=*) THRESHOLD="${1#--threshold=}" ;;
    -h|--help) usage; exit 0 ;;
    *) sa_die "unknown argument: $1 (use --help)" 2 ;;
  esac
  shift
done

case "$FORMAT" in summary|json|details) ;; *) sa_die "invalid --format=$FORMAT" 2 ;; esac
case "$SCOPE" in tasks|archive|all) ;; *) sa_die "invalid --scope=$SCOPE" 2 ;; esac
[[ "$DEDUPE_PREFIX" =~ ^[0-9]+$ ]] || sa_die "--dedupe-prefix must be integer" 2
[[ "$THRESHOLD" =~ ^[0-9]+$ ]] || sa_die "--threshold must be integer" 2

# === Resolve project root via anchor.yaml ===
ANCHOR=$(sa_find_config 2>/dev/null || true)
[[ -n "$ANCHOR" ]] || sa_die "anchor.yaml not found; run from a SpecAnchor project" 1
PROJECT_ROOT="$(cd "$(dirname "$ANCHOR")" && pwd)"

# === Scope discovery ===
declare -a SCAN_FILES=()
_corpus_discover() {
  local base="$1"
  [[ -d "$base" ]] || return 0
  while IFS= read -r f; do
    [[ -n "$f" ]] && SCAN_FILES+=("$f")
  done < <(find "$base" -type f -name "*.spec.md" 2>/dev/null | sort)
}

case "$SCOPE" in
  tasks) _corpus_discover "$PROJECT_ROOT/.specanchor/tasks" ;;
  archive) _corpus_discover "$PROJECT_ROOT/.specanchor/archive" ;;
  all)
    _corpus_discover "$PROJECT_ROOT/.specanchor/tasks"
    _corpus_discover "$PROJECT_ROOT/.specanchor/archive"
    ;;
esac

# === Aggregation buckets (parallel arrays — Bash 3.2 friendly) ===
# Per-cp records (TSV row prefixed with originating file)
declare -a CP_ROWS=()  # each row: <file>\037<sa_parse_decisions output row>
LEGACY_EXCLUDED=0
TOTAL_RAW=0

# Tally helpers using newline-delimited "key:count" string (Bash 3.2 has no assoc arrays)
_tally_inc() {
  local var="$1" key="$2"
  local cur
  eval "cur=\${$var:-}"
  local replaced=""
  local found=0
  local line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local k="${line%%:*}"
    local v="${line#*:}"
    if [[ "$k" == "$key" ]]; then
      v=$((v + 1))
      replaced+="$k:$v"$'\n'
      found=1
    else
      replaced+="$k:$v"$'\n'
    fi
  done <<< "$cur"
  if [[ $found -eq 0 ]]; then
    replaced+="$key:1"$'\n'
  fi
  eval "$var=\$replaced"
}

_tally_get() {
  local var="$1" key="$2"
  local cur
  eval "cur=\${$var:-}"
  local line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "${line%%:*}" == "$key" ]]; then
      printf '%s\n' "${line#*:}"
      return
    fi
  done <<< "$cur"
  printf '0\n'
}

_tally_sorted_desc() {
  local var="$1"
  local cur
  eval "cur=\${$var:-}"
  printf '%s' "$cur" | awk -F: 'NF>=2 {print $2"\t"$1}' | sort -rn
}

TYPES_TALLY=""
TYPES_NONSTD_TALLY=""
PHASE_TALLY=""
BY_TALLY=""
FILE_TALLY=""
PIN_COUNT=0

# === Scan & populate ===
for spec_file in "${SCAN_FILES[@]+"${SCAN_FILES[@]}"}"; do
  rel="${spec_file#$PROJECT_ROOT/}"
  while IFS= read -r tsv; do
    [[ -z "$tsv" ]] && continue
    IFS=$'\037' read -r cp_id cp_date cp_phase cp_types cp_status cp_pin cp_ref cp_rule cp_by _supersedes _superseded_by _note <<< "$tsv"

    if _corpus_is_legacy_sentinel "$cp_rule"; then
      LEGACY_EXCLUDED=$((LEGACY_EXCLUDED + 1))
      continue
    fi
    [[ -z "$cp_id" ]] && continue

    TOTAL_RAW=$((TOTAL_RAW + 1))
    CP_ROWS+=("$rel"$'\037'"$tsv")

    # Type tally — split CSV (from sa_parse_decisions which converted "+" to ",")
    local_types="${cp_types:-unknown}"
    saved_ifs="$IFS"; IFS=','
    set -- $local_types
    IFS="$saved_ifs"
    for t in "$@"; do
      [[ -z "$t" ]] && continue
      _tally_inc TYPES_TALLY "$t"
      is_std=0
      for std in $STANDARD_TYPES; do
        [[ "$t" == "$std" ]] && { is_std=1; break; }
      done
      [[ $is_std -eq 0 ]] && _tally_inc TYPES_NONSTD_TALLY "$t"
    done

    _tally_inc PHASE_TALLY "${cp_phase:-no-phase}"

    # by classification: human / agent / *-with-rationale (has " (")
    by_class="${cp_by:-unknown}"
    case "$by_class" in
      human) by_bucket="human" ;;
      agent) by_bucket="agent" ;;
      "human ("*) by_bucket="human-with-rationale" ;;
      "agent ("*) by_bucket="agent-with-rationale" ;;
      *) by_bucket="$by_class" ;;
    esac
    _tally_inc BY_TALLY "$by_bucket"

    _tally_inc FILE_TALLY "$rel"
    [[ "$cp_pin" == "true" ]] && PIN_COUNT=$((PIN_COUNT + 1))
  done < <(sa_parse_decisions "$spec_file" 2>/dev/null || true)
done

# === Cross-task repeated patterns (raw + deduped) ===
# Build temp TSV: <prefix>\t<file>\t<id>
_PATTERNS_TSV=""
for row in "${CP_ROWS[@]+"${CP_ROWS[@]}"}"; do
  IFS=$'\037' read -r rfile cp_id _date _phase _types _status _pin _ref cp_rule _rest <<< "$row"
  prefix="${cp_rule:0:$DEDUPE_PREFIX}"
  [[ -z "$prefix" ]] && continue
  _PATTERNS_TSV+="$prefix"$'\t'"$rfile"$'\t'"$cp_id"$'\n'
done

# Raw top-N patterns: group by prefix, count occurrences
PATTERNS_RAW=$(printf '%s' "$_PATTERNS_TSV" | awk -F'\t' '
  NF>=3 {
    cnt[$1]++
    files[$1] = files[$1] (files[$1]?",":"") $2
  }
  END {
    for (p in cnt) printf "%d\t%s\t%s\n", cnt[p], p, files[p]
  }
' | sort -rn | head -5)

# Deduped: same prefix → one entry, count = unique files
PATTERNS_DEDUPED=$(printf '%s' "$_PATTERNS_TSV" | awk -F'\t' '
  NF>=3 {
    key = $1 "\037" $2
    if (!(key in seen)) {
      seen[key]=1
      cnt[$1]++
      files[$1] = files[$1] (files[$1]?",":"") $2
    }
  }
  END {
    for (p in cnt) printf "%d\t%s\t%s\n", cnt[p], p, files[p]
  }
' | sort -rn | head -5)

# Total deduped count: distinct (prefix, file) pairs collapsed by prefix
TOTAL_DEDUPED=$(printf '%s' "$_PATTERNS_TSV" | awk -F'\t' '
  NF>=3 { seen[$1]=1 } END { print length(seen) }
')
[[ -z "$TOTAL_DEDUPED" ]] && TOTAL_DEDUPED=0

# === Dogfood ratio: top-1 file's cp share ===
TOP_FILE_LINE=$(_tally_sorted_desc FILE_TALLY | head -1)
TOP_FILE_COUNT="${TOP_FILE_LINE%%	*}"
TOP_FILE_PATH="${TOP_FILE_LINE#*	}"
[[ -z "$TOP_FILE_COUNT" ]] && TOP_FILE_COUNT=0
if [[ $TOTAL_RAW -gt 0 ]]; then
  DOGFOOD_PCT=$(awk -v n="$TOP_FILE_COUNT" -v d="$TOTAL_RAW" 'BEGIN{printf "%.0f", n*100/d}')
else
  DOGFOOD_PCT=0
fi

# === Threshold gate ===
if [[ $TOTAL_RAW -lt $THRESHOLD ]]; then
  THRESHOLD_VERDICT="below"
else
  THRESHOLD_VERDICT="above"
fi

# === Pin ratio ===
if [[ $TOTAL_RAW -gt 0 ]]; then
  PIN_PCT=$(awk -v n="$PIN_COUNT" -v d="$TOTAL_RAW" 'BEGIN{printf "%.0f", n*100/d}')
else
  PIN_PCT=0
fi

# === Counts by scope class ===
TASKS_COUNT=0
ARCHIVE_COUNT=0
for f in "${SCAN_FILES[@]+"${SCAN_FILES[@]}"}"; do
  case "${f#$PROJECT_ROOT/}" in
    .specanchor/tasks/*) TASKS_COUNT=$((TASKS_COUNT + 1)) ;;
    .specanchor/archive/*) ARCHIVE_COUNT=$((ARCHIVE_COUNT + 1)) ;;
  esac
done

# === Emit format ===
_emit_summary() {
  printf 'SpecAnchor Corpus  (scope=%s)\n' "$SCOPE"
  printf '  Files scanned: %d (tasks=%d, archive=%d, legacy_excluded=%d entries)\n' \
    "${#SCAN_FILES[@]}" "$TASKS_COUNT" "$ARCHIVE_COUNT" "$LEGACY_EXCLUDED"
  printf '  Total cp-NN: %d (raw_count) / %d (deduped by --dedupe-prefix=%d)\n\n' \
    "$TOTAL_RAW" "$TOTAL_DEDUPED" "$DEDUPE_PREFIX"

  printf '  Type distribution:\n'
  local line
  for std in $STANDARD_TYPES; do
    printf '    %-12s %d\n' "${std}:" "$(_tally_get TYPES_TALLY "$std")"
  done
  if [[ -n "$TYPES_NONSTD_TALLY" ]]; then
    printf '    Non-standard:'
    _tally_sorted_desc TYPES_NONSTD_TALLY | while IFS=$'\t' read -r cnt key; do
      printf ' %s(%d)' "$key" "$cnt"
    done
    printf '  ⚠️\n'
  fi
  printf '\n'

  printf '  Phase distribution:\n'
  _tally_sorted_desc PHASE_TALLY | while IFS=$'\t' read -r cnt key; do
    printf '    %-20s %d\n' "${key}:" "$cnt"
  done
  printf '\n'

  printf '  By distribution:'
  _tally_sorted_desc BY_TALLY | while IFS=$'\t' read -r cnt key; do
    printf ' %s(%d)' "$key" "$cnt"
  done
  printf '\n'

  printf '  Pin ratio: %d%% (%d/%d)\n' "$PIN_PCT" "$PIN_COUNT" "$TOTAL_RAW"

  printf '  Top-3 dense files:\n'
  _tally_sorted_desc FILE_TALLY | head -3 | while IFS=$'\t' read -r cnt path; do
    printf '    %s (%d)\n' "$path" "$cnt"
  done

  if [[ "$DOGFOOD_PCT" -gt 50 ]]; then
    printf '  Dogfood self-reference: %d/%d = %d%%  ⚠️ (>50%%)\n' \
      "$TOP_FILE_COUNT" "$TOTAL_RAW" "$DOGFOOD_PCT"
  else
    printf '  Dogfood self-reference: %d/%d = %d%%\n' \
      "$TOP_FILE_COUNT" "$TOTAL_RAW" "$DOGFOOD_PCT"
  fi
  printf '\n'

  printf '  Cross-task repeated patterns (top 5, raw):\n'
  if [[ -n "$PATTERNS_RAW" ]]; then
    while IFS=$'\t' read -r cnt prefix files; do
      printf '    [%dx] "%s" @ %s\n' "$cnt" "$prefix" "$files"
    done <<< "$PATTERNS_RAW"
  else
    printf '    (none)\n'
  fi
  printf '  Cross-task repeated patterns (top 5, deduped):\n'
  if [[ -n "$PATTERNS_DEDUPED" ]]; then
    while IFS=$'\t' read -r cnt prefix files; do
      printf '    [%dx] "%s" @ %s\n' "$cnt" "$prefix" "$files"
    done <<< "$PATTERNS_DEDUPED"
  else
    printf '    (none)\n'
  fi
  printf '\n'

  printf '  Threshold gate (--threshold=%d, default 50): %d → "%s"\n' \
    "$THRESHOLD" "$TOTAL_RAW" "$THRESHOLD_VERDICT"
}

_emit_json() {
  printf '{\n'
  printf '  "scan_meta": {\n'
  printf '    "scope": "%s",\n' "$SCOPE"
  printf '    "files_scanned": %d,\n' "${#SCAN_FILES[@]}"
  printf '    "tasks_files": %d,\n' "$TASKS_COUNT"
  printf '    "archive_files": %d,\n' "$ARCHIVE_COUNT"
  printf '    "legacy_excluded": %d,\n' "$LEGACY_EXCLUDED"
  printf '    "dedupe_prefix": %d\n' "$DEDUPE_PREFIX"
  printf '  },\n'
  printf '  "totals": {"raw": %d, "deduped": %d, "pin_count": %d, "pin_pct": %d},\n' \
    "$TOTAL_RAW" "$TOTAL_DEDUPED" "$PIN_COUNT" "$PIN_PCT"

  _emit_json_tally() {
    local var="$1"; local first=1
    printf '['
    _tally_sorted_desc "$var" | while IFS=$'\t' read -r cnt key; do
      [[ $first -eq 0 ]] && printf ','
      printf '{"key":"%s","count":%d}' "$(sa_json_escape "$key")" "$cnt"
      first=0
    done
    printf ']'
  }
  printf '  "type_dist": '; _emit_json_tally TYPES_TALLY; printf ',\n'
  printf '  "type_nonstandard": '; _emit_json_tally TYPES_NONSTD_TALLY; printf ',\n'
  printf '  "phase_dist": '; _emit_json_tally PHASE_TALLY; printf ',\n'
  printf '  "by_dist": '; _emit_json_tally BY_TALLY; printf ',\n'
  printf '  "top_files": '; _emit_json_tally FILE_TALLY; printf ',\n'
  printf '  "dogfood_ratio": {"top_file": "%s", "count": %d, "pct": %d},\n' \
    "$(sa_json_escape "$TOP_FILE_PATH")" "$TOP_FILE_COUNT" "$DOGFOOD_PCT"

  _emit_json_patterns() {
    local data="$1"; local first=1
    printf '['
    if [[ -n "$data" ]]; then
      while IFS=$'\t' read -r cnt prefix files; do
        [[ $first -eq 0 ]] && printf ','
        printf '{"count":%d,"prefix":"%s","files":"%s"}' \
          "$cnt" "$(sa_json_escape "$prefix")" "$(sa_json_escape "$files")"
        first=0
      done <<< "$data"
    fi
    printf ']'
  }
  printf '  "repeated_patterns_raw": '; _emit_json_patterns "$PATTERNS_RAW"; printf ',\n'
  printf '  "repeated_patterns_deduped": '; _emit_json_patterns "$PATTERNS_DEDUPED"; printf ',\n'
  printf '  "threshold_status": {"value": %d, "total": %d, "verdict": "%s"}\n' \
    "$THRESHOLD" "$TOTAL_RAW" "$THRESHOLD_VERDICT"
  printf '}\n'
}

_emit_details() {
  printf 'SpecAnchor Corpus details (scope=%s, total=%d, legacy_excluded=%d)\n\n' \
    "$SCOPE" "$TOTAL_RAW" "$LEGACY_EXCLUDED"
  # Group rows by file (already sorted by SCAN_FILES discovery order)
  local current_file=""
  for row in "${CP_ROWS[@]+"${CP_ROWS[@]}"}"; do
    IFS=$'\037' read -r rfile cp_id cp_date cp_phase cp_types cp_status cp_pin cp_ref cp_rule cp_by _rest <<< "$row"
    if [[ "$rfile" != "$current_file" ]]; then
      printf '=== %s ===\n' "$rfile"
      current_file="$rfile"
    fi
    pin_flag=""
    [[ "$cp_pin" == "true" ]] && pin_flag=",pin"
    rule_excerpt="${cp_rule:0:80}"
    printf '  %s [%s][%s][%s%s] | %s\n' \
      "$cp_id" "${cp_types:-?}" "${cp_phase:-no-phase}" "${cp_by:-?}" "$pin_flag" "$rule_excerpt"
  done
}

case "$FORMAT" in
  summary) _emit_summary ;;
  json) _emit_json ;;
  details) _emit_details ;;
esac
