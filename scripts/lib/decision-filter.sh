#!/usr/bin/env bash
# Harness Context Control — decision context hot/cold filter
# Implements rule B (hot/cold lazy view) + rule C (eager status / lazy hot) from
# task spec _cross-module/2026-05-18_harness-context-control.spec.md §4.3.
#
# Dual interface:
#   Library mode (sourced):
#     sa_filter_decisions <task-spec> [--format=text|json] [opts...]
#   CLI mode (executed):
#     bash scripts/lib/decision-filter.sh \
#       --task-spec=<path> \
#       [--hot-window=<int>] \
#       [--hot-types=<csv>] \
#       [--respect-phase=<true|false>] \
#       [--format=text|json]
#
# Configuration precedence (per spec §4.5):
#   CLI args > task frontmatter `decision_log` > anchor.yaml `context_control.decision_log` > builtin defaults

set -euo pipefail

if [[ -n "${SPECANCHOR_DECISION_FILTER_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
SPECANCHOR_DECISION_FILTER_LOADED=1

_SDF_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$_SDF_SCRIPT_DIR/common.sh"

# === Built-in defaults (per spec §4.4 frontmatter block) ===
SDF_DEFAULT_HOT_WINDOW=5
SDF_DEFAULT_HOT_TYPES="redirect,rollback,halt"
SDF_DEFAULT_RESPECT_PHASE="true"

# === Nested YAML parser: anchor.yaml level 4 (specanchor.context_control.<l3>.<l4>) ===
_sdf_parse_anchor_nested() {
  local file="$1"
  local l3="$2"
  local l4="$3"
  local default="${4:-}"
  [[ -f "$file" ]] || { printf '%s\n' "$default"; return; }

  local val
  val=$(awk -v l3="$l3" -v l4="$l4" '
    /^[A-Za-z_]+:/ && !/^specanchor:/ { in_specanchor=0 }
    /^specanchor:/ { in_specanchor=1; next }
    in_specanchor && /^  context_control:/ { in_cc=1; in_l3=0; next }
    in_specanchor && /^  [A-Za-z_-]+:/ && !/^  context_control:/ { in_cc=0; in_l3=0 }
    in_cc && $0 ~ "^    " l3 ":" { in_l3=1; next }
    in_cc && /^    [A-Za-z_-]+:/ && $0 !~ "^    " l3 ":" { in_l3=0 }
    in_l3 && $0 ~ "^      " l4 ":" {
      sub("^      " l4 ": *", "", $0)
      sub(/[[:space:]]*#.*$/, "", $0)
      print
      exit
    }
  ' "$file")

  val=$(printf '%s' "$val" | sed -E 's/[[:space:]]+$//')
  if [[ -z "$val" ]]; then
    printf '%s\n' "$default"
  else
    sa_normalize_scalar "$val"
  fi
}

# === Frontmatter nested parser: task spec specanchor.<l1>.<l2> ===
_sdf_parse_frontmatter_nested() {
  local file="$1"
  local l1="$2"
  local l2="$3"
  local default="${4:-}"
  [[ -f "$file" ]] || { printf '%s\n' "$default"; return; }

  local val
  val=$(awk -v l1="$l1" -v l2="$l2" '
    /^---$/ { in_fm = !in_fm; next }
    !in_fm { next }
    /^[A-Za-z_]+:/ { in_l1=0 }
    $0 ~ "^  " l1 ":" { in_l1=1; next }
    in_l1 && /^  [A-Za-z_-]+:/ && $0 !~ "^  " l1 ":" { in_l1=0 }
    in_l1 && $0 ~ "^    " l2 ":" {
      sub("^    " l2 ": *", "", $0)
      sub(/[[:space:]]*#.*$/, "", $0)
      print
      exit
    }
  ' "$file")

  val=$(printf '%s' "$val" | sed -E 's/[[:space:]]+$//')
  if [[ -z "$val" ]]; then
    printf '%s\n' "$default"
  else
    sa_normalize_scalar "$val"
  fi
}

# === Strip YAML inline list brackets ===
_sdf_normalize_list() {
  local raw="$1"
  raw="${raw#[}"
  raw="${raw%]}"
  raw=$(printf '%s' "$raw" | sed -E 's/[[:space:]]//g')
  printf '%s' "$raw"
}

_sdf_resolve_field() {
  local task_spec="$1"
  local field="$2"
  local cli_value="$3"
  local builtin_default="$4"

  if [[ -n "$cli_value" ]]; then
    printf '%s\n' "$cli_value"
    return
  fi

  local fm_val
  fm_val=$(_sdf_parse_frontmatter_nested "$task_spec" "decision_log" "$field" "")
  if [[ -n "$fm_val" ]]; then
    printf '%s\n' "$fm_val"
    return
  fi

  local anchor
  anchor=$(sa_find_config 2>/dev/null || true)
  if [[ -n "$anchor" ]]; then
    local av
    av=$(_sdf_parse_anchor_nested "$anchor" "decision_log" "$field" "")
    if [[ -n "$av" ]]; then
      printf '%s\n' "$av"
      return
    fi
  fi

  printf '%s\n' "$builtin_default"
}

# === Resolve config; sets SDF_HOT_WINDOW / SDF_HOT_TYPES / SDF_RESPECT_PHASE globals ===
sa_resolve_decision_config() {
  local task_spec="$1"
  shift
  local cli_hw="" cli_ht="" cli_rp=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --hot-window=*) cli_hw="${1#--hot-window=}" ;;
      --hot-types=*) cli_ht="${1#--hot-types=}" ;;
      --respect-phase=*) cli_rp="${1#--respect-phase=}" ;;
    esac
    shift
  done

  SDF_HOT_WINDOW=$(_sdf_resolve_field "$task_spec" "hot_window" "$cli_hw" "$SDF_DEFAULT_HOT_WINDOW")

  local raw_ht
  raw_ht=$(_sdf_resolve_field "$task_spec" "hot_types" "$cli_ht" "$SDF_DEFAULT_HOT_TYPES")
  SDF_HOT_TYPES=$(_sdf_normalize_list "$raw_ht")

  SDF_RESPECT_PHASE=$(_sdf_resolve_field "$task_spec" "respect_phase" "$cli_rp" "$SDF_DEFAULT_RESPECT_PHASE")
}

# === Read current RIPER phase from task spec body marker ===
sa_read_task_phase() {
  local task_spec="$1"
  awk '/^> Current RIPER Phase:/ {
    sub(/^> Current RIPER Phase: */, "", $0)
    sub(/[[:space:]]+$/, "", $0)
    print
    exit
  }' "$task_spec"
}

# === Parse §5.2 Checkpoint Decisions Log into TSV ===
# Output columns (TSV):
#   id  date  phase  types_csv  status  pin  ref  rule  by  supersedes  superseded_by  note
sa_parse_decisions() {
  local task_spec="$1"
  [[ -f "$task_spec" ]] || sa_die "task spec not found: $task_spec" 64

  awk '
    BEGIN { in_sec=0 }
    /^## 5\.2 / { in_sec=1; next }
    in_sec && /^## [0-9]+\./ { in_sec=0; exit }
    in_sec { print }
  ' "$task_spec" | _sdf_parse_entries
}

# Helper: parse decision entries from §5.2 stdin
_sdf_parse_entries() {
  awk '
    function emit() {
      if (id != "") {
        gsub(/\037/, " ", rule)
        gsub(/\037/, " ", note)
        printf "%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\n",
          id, date, phase, types, status, pin, ref, rule, by, supersedes, superseded_by, note
      }
      id=""; date=""; phase=""; types=""; status="active"; pin="false"; ref=""
      rule=""; by=""; supersedes=""; superseded_by=""; note=""
    }
    BEGIN { emit() }
    # Header line: - **cp-NN** (YYYY-MM-DD[, PHASE]) [tokens] @ref
    /^- \*\*cp-[0-9]+\*\*/ {
      emit()
      line=$0
      if (match(line, /cp-[0-9]+/)) id=substr(line, RSTART, RLENGTH)
      if (match(line, /\([0-9]{4}-[0-9]{2}-[0-9]{2}[^)]*\)/)) {
        meta=substr(line, RSTART+1, RLENGTH-2)
        n=split(meta, parts, ",")
        date=parts[1]; gsub(/[[:space:]]/, "", date)
        if (n>=2) {
          phase=parts[2]; gsub(/[[:space:]]/, "", phase)
        }
      }
      if (match(line, /\[[^\]]+\]/)) {
        bracket=substr(line, RSTART+1, RLENGTH-2)
        n=split(bracket, segs, ",")
        type_segments=""
        for (i=1; i<=n; i++) {
          tok=segs[i]
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", tok)
          if (tok=="active" || tok=="superseded" || tok=="withdrawn") {
            status=tok
          } else if (tok=="pin") {
            pin="true"
          } else if (tok=="hot" || tok=="cold") {
            # ignore lazy view hints
          } else if (i==1) {
            type_segments=tok
          }
        }
        # split type_segments by + sign for multi-type
        if (type_segments != "") {
          gsub(/[[:space:]]*\+[[:space:]]*/, ",", type_segments)
          types=type_segments
        }
      }
      if (match(line, /@[^[:space:]].*$/)) {
        ref=substr(line, RSTART+1)
        gsub(/[[:space:]]+$/, "", ref)
      }
      next
    }
    # Sub-bullets: "  - field: value"
    /^[[:space:]]+- [a-z_]+:/ {
      sub(/^[[:space:]]+- /, "", $0)
      key=$0; sub(/:.*/, "", key)
      val=$0; sub(/^[a-z_]+:[[:space:]]*/, "", val)
      # Strip surrounding quotes
      if (length(val)>=2) {
        first=substr(val,1,1); last=substr(val,length(val),1)
        if (first==last && (first=="\"" || first=="'\''")) {
          val=substr(val,2,length(val)-2)
        }
      }
      if (key=="rule") rule=val
      else if (key=="by") by=val
      else if (key=="supersedes") supersedes=val
      else if (key=="superseded_by") superseded_by=val
      else if (key=="note") note=val
      next
    }
    END { emit() }
  '
}

# === Classify: each TSV row → category (hot|cold|superseded|withdrawn) ===
# Reads from stdin, writes TSV with extra "category" column appended.
# Requires SDF_* config globals + current_phase arg.
sa_classify_decisions() {
  local current_phase="$1"
  local hot_window="$SDF_HOT_WINDOW"
  local hot_types="$SDF_HOT_TYPES"
  local respect_phase="$SDF_RESPECT_PHASE"

  # Load all rows into array, sort by id desc (newest first), then classify
  local -a rows=()
  local row
  while IFS= read -r row; do
    [[ -n "$row" ]] && rows+=("$row")
  done

  # Sort rows desc by numeric suffix of id
  local sorted
  sorted=$(printf '%s\n' "${rows[@]}" | awk -F'\037' '
    {
      id=$1
      n=id; sub(/^cp-/, "", n)
      printf "%012d\037%s\n", n, $0
    }
  ' | sort -r | cut -d $'\037' -f2-)

  local idx=0
  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    idx=$((idx + 1))
    local id date phase types_csv status pin ref rule by supersedes superseded_by note
    IFS=$'\037' read -r id date phase types_csv status pin ref rule by supersedes superseded_by note <<< "$row"

    local category
    if [[ "$status" == "withdrawn" ]]; then
      category="withdrawn"
    elif [[ "$status" == "superseded" ]] || [[ -n "$superseded_by" ]]; then
      category="superseded"
    else
      # active: decide hot vs cold
      local is_hot="false"
      # OR rule 1: last N (idx <= hot_window after desc sort)
      if [[ $idx -le ${hot_window} ]]; then
        is_hot="true"
      fi
      # OR rule 2: pin
      if [[ "$pin" == "true" ]]; then
        is_hot="true"
      fi
      # OR rule 3: type ∈ hot_types
      if [[ "$is_hot" != "true" ]] && [[ -n "$types_csv" ]] && [[ -n "$hot_types" ]]; then
        local IFS_OLD="$IFS"
        IFS=','
        local t ht
        for t in $types_csv; do
          for ht in $hot_types; do
            if [[ "$t" == "$ht" ]]; then is_hot="true"; break; fi
          done
          [[ "$is_hot" == "true" ]] && break
        done
        IFS="$IFS_OLD"
      fi
      # OR rule 4: same phase (respect_phase=true)
      if [[ "$is_hot" != "true" ]] && [[ "$respect_phase" == "true" ]] && [[ -n "$phase" ]] && [[ "$phase" == "$current_phase" ]]; then
        is_hot="true"
      fi
      if [[ "$is_hot" == "true" ]]; then
        category="hot"
      else
        category="cold"
      fi
    fi
    printf '%s\037%s\n' "$row" "$category"
  done <<< "$sorted"
}

# === Emit: text format (3 sections) ===
sa_emit_decisions_text() {
  local hot=() cold=() superseded=() withdrawn=()
  local row
  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    local cat
    cat=$(printf '%s' "$row" | awk -F'\037' '{print $NF}')
    case "$cat" in
      hot) hot+=("$row") ;;
      cold) cold+=("$row") ;;
      superseded) superseded+=("$row") ;;
      withdrawn) withdrawn+=("$row") ;;
    esac
  done

  _sdf_emit_section "Hot (active, in-prompt)" ${hot[@]+"${hot[@]}"}
  _sdf_emit_section "Cold (active, audit-only)" ${cold[@]+"${cold[@]}"}
  _sdf_emit_section "Superseded" ${superseded[@]+"${superseded[@]}"}
}

_sdf_emit_section() {
  local title="$1"
  shift
  printf '### %s — %d entries\n' "$title" "$#"
  if [[ $# -eq 0 ]]; then
    printf '  (none)\n\n'
    return
  fi
  local row
  for row in "$@"; do
    local id date phase types_csv status pin ref rule rest
    IFS=$'\037' read -r id date phase types_csv status pin ref rule rest <<< "$row"
    local flags=""
    [[ "$pin" == "true" ]] && flags=" pin"
    printf '  - %s (%s, %s) [%s%s] @%s\n' "$id" "$date" "${phase:-?}" "${types_csv:-?}" "$flags" "${ref:-?}"
    [[ -n "$rule" ]] && printf '      rule: %s\n' "$rule"
  done
  printf '\n'
}

# === Emit: json format ===
sa_emit_decisions_json() {
  local hot=() cold=() superseded=() withdrawn=()
  local row
  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    local cat
    cat=$(printf '%s' "$row" | awk -F'\037' '{print $NF}')
    case "$cat" in
      hot) hot+=("$row") ;;
      cold) cold+=("$row") ;;
      superseded) superseded+=("$row") ;;
      withdrawn) withdrawn+=("$row") ;;
    esac
  done

  printf '{\n'
  printf '  "config": {\n'
  printf '    "hot_window": %s,\n' "$SDF_HOT_WINDOW"
  printf '    "hot_types": "%s",\n' "$(sa_json_escape "$SDF_HOT_TYPES")"
  printf '    "respect_phase": %s\n' "$SDF_RESPECT_PHASE"
  printf '  },\n'
  printf '  "totals": { "hot": %d, "cold": %d, "superseded": %d, "withdrawn": %d },\n' \
    "${#hot[@]}" "${#cold[@]}" "${#superseded[@]}" "${#withdrawn[@]}"
  _sdf_emit_json_array "hot" ${hot[@]+"${hot[@]}"}
  printf ',\n'
  _sdf_emit_json_array "cold" ${cold[@]+"${cold[@]}"}
  printf ',\n'
  _sdf_emit_json_array "superseded" ${superseded[@]+"${superseded[@]}"}
  printf ',\n'
  _sdf_emit_json_array "withdrawn" ${withdrawn[@]+"${withdrawn[@]}"}
  printf '\n}\n'
}

_sdf_emit_json_array() {
  local key="$1"
  shift
  printf '  "%s": [' "$key"
  if [[ $# -eq 0 ]]; then
    printf ']'
    return
  fi
  printf '\n'
  local i=0 row
  for row in "$@"; do
    local id date phase types_csv status pin ref rule by supersedes superseded_by note _cat
    IFS=$'\037' read -r id date phase types_csv status pin ref rule by supersedes superseded_by note _cat <<< "$row"
    [[ $i -gt 0 ]] && printf ',\n'
    printf '    {'
    printf '"id":"%s",' "$(sa_json_escape "$id")"
    printf '"date":"%s",' "$(sa_json_escape "$date")"
    printf '"phase":"%s",' "$(sa_json_escape "$phase")"
    printf '"types":"%s",' "$(sa_json_escape "$types_csv")"
    printf '"status":"%s",' "$(sa_json_escape "$status")"
    printf '"pin":%s,' "$pin"
    printf '"ref":"%s",' "$(sa_json_escape "$ref")"
    printf '"rule":"%s",' "$(sa_json_escape "$rule")"
    printf '"by":"%s",' "$(sa_json_escape "$by")"
    printf '"supersedes":"%s",' "$(sa_json_escape "$supersedes")"
    printf '"superseded_by":"%s",' "$(sa_json_escape "$superseded_by")"
    printf '"note":"%s"' "$(sa_json_escape "$note")"
    printf '}'
    i=$((i+1))
  done
  printf '\n  ]'
}

# === Public top-level entry: filter + emit ===
sa_filter_decisions() {
  local task_spec="$1"
  shift
  local format="text"
  local cli_args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format=*) format="${1#--format=}" ;;
      *) cli_args+=("$1") ;;
    esac
    shift
  done

  sa_resolve_decision_config "$task_spec" "${cli_args[@]+"${cli_args[@]}"}"
  local current_phase
  current_phase=$(sa_read_task_phase "$task_spec")

  local classified
  classified=$(sa_parse_decisions "$task_spec" | sa_classify_decisions "$current_phase")

  case "$format" in
    text) printf '%s\n' "$classified" | sa_emit_decisions_text ;;
    json) printf '%s\n' "$classified" | sa_emit_decisions_json ;;
    *) sa_die "unknown format: $format (use text|json)" 64 ;;
  esac
}

# === CLI entry ===
_sdf_main() {
  local task_spec="" format="text"
  local cli=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --task-spec=*) task_spec="${1#--task-spec=}" ;;
      --format=*) format="${1#--format=}" ;;
      --hot-window=*|--hot-types=*|--respect-phase=*) cli+=("$1") ;;
      --help|-h)
        cat <<EOF
Usage: decision-filter.sh --task-spec=<path> [opts]
  --hot-window=<int>          Override hot window size
  --hot-types=<csv>           Override hot types (e.g. redirect,rollback,halt)
  --respect-phase=<bool>      Override respect_phase flag
  --format=text|json          Output format (default: text)
EOF
        return 0
        ;;
      *) sa_die "unknown argument: $1" 64 ;;
    esac
    shift
  done
  [[ -n "$task_spec" ]] || sa_die "--task-spec=<path> required" 64
  sa_filter_decisions "$task_spec" --format="$format" "${cli[@]+"${cli[@]}"}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _sdf_main "$@"
fi
