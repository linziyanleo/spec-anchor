#!/usr/bin/env bash
# Harness Context Control — evidence context hot/cold filter
# Implements rule D from task spec §4.3:
#   - status: pending / verified / failed / unverified-risk
#   - hot OR-rules: pin / last N / status ∈ hot_status
#   - auto_pin_acceptance: acceptance criteria 行自动 pin
#
# Dual interface (lib + CLI) — same shape as decision-filter.sh
# TSV separator: \037 (Unit Separator) — non-whitespace, bash read 不合并 empty fields

set -euo pipefail

if [[ -n "${SPECANCHOR_EVIDENCE_FILTER_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
SPECANCHOR_EVIDENCE_FILTER_LOADED=1

_SEF_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$_SEF_SCRIPT_DIR/common.sh"

# === Built-in defaults (per spec §4.4 frontmatter block) ===
SEF_DEFAULT_HOT_WINDOW=5
SEF_DEFAULT_HOT_STATUS="failed,unverified-risk"
SEF_DEFAULT_AUTO_PIN_ACCEPTANCE="true"

# === anchor.yaml level-4 parser: specanchor.context_control.<l3>.<l4> ===
_sef_parse_anchor_nested() {
  local file="$1" l3="$2" l4="$3" default="${4:-}"
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

# === Frontmatter level-2 parser: specanchor.<l1>.<l2> ===
_sef_parse_frontmatter_nested() {
  local file="$1" l1="$2" l2="$3" default="${4:-}"
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

_sef_normalize_list() {
  local raw="$1"
  raw="${raw#[}"
  raw="${raw%]}"
  raw=$(printf '%s' "$raw" | sed -E 's/[[:space:]]//g')
  printf '%s' "$raw"
}

_sef_resolve_field() {
  local task_spec="$1" field="$2" cli_value="$3" builtin_default="$4"

  if [[ -n "$cli_value" ]]; then
    printf '%s\n' "$cli_value"
    return
  fi

  local fm_val
  fm_val=$(_sef_parse_frontmatter_nested "$task_spec" "evidence_log" "$field" "")
  if [[ -n "$fm_val" ]]; then
    printf '%s\n' "$fm_val"
    return
  fi

  local anchor
  anchor=$(sa_find_config 2>/dev/null || true)
  if [[ -n "$anchor" ]]; then
    local av
    av=$(_sef_parse_anchor_nested "$anchor" "evidence_log" "$field" "")
    if [[ -n "$av" ]]; then
      printf '%s\n' "$av"
      return
    fi
  fi

  printf '%s\n' "$builtin_default"
}

# === Resolve config; sets SEF_HOT_WINDOW / SEF_HOT_STATUS / SEF_AUTO_PIN_ACCEPTANCE ===
sa_resolve_evidence_config() {
  local task_spec="$1"
  shift
  local cli_hw="" cli_hs="" cli_ap=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --hot-window=*) cli_hw="${1#--hot-window=}" ;;
      --hot-status=*) cli_hs="${1#--hot-status=}" ;;
      --auto-pin-acceptance=*) cli_ap="${1#--auto-pin-acceptance=}" ;;
    esac
    shift
  done

  SEF_HOT_WINDOW=$(_sef_resolve_field "$task_spec" "hot_window" "$cli_hw" "$SEF_DEFAULT_HOT_WINDOW")

  local raw_hs
  raw_hs=$(_sef_resolve_field "$task_spec" "hot_status" "$cli_hs" "$SEF_DEFAULT_HOT_STATUS")
  SEF_HOT_STATUS=$(_sef_normalize_list "$raw_hs")

  SEF_AUTO_PIN_ACCEPTANCE=$(_sef_resolve_field "$task_spec" "auto_pin_acceptance" "$cli_ap" "$SEF_DEFAULT_AUTO_PIN_ACCEPTANCE")
}

# === Parse §6.2 Evidence Ledger into TSV ===
# Output columns (separator: \037):
#   id  type  title  status  detail  pin
sa_parse_evidence() {
  local task_spec="$1"
  [[ -f "$task_spec" ]] || sa_die "task spec not found: $task_spec" 64

  awk '
    BEGIN { in_sec=0 }
    /^## 6\.2 / { in_sec=1; next }
    in_sec && /^## [0-9]+\./ { in_sec=0; exit }
    in_sec { print }
  ' "$task_spec" | _sef_parse_subsections
}

_sef_parse_subsections() {
  awk -v auto_pin="${SEF_AUTO_PIN_ACCEPTANCE:-true}" '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    function normalize_status(s,    t) {
      t=tolower(s)
      gsub(/[[:space:]]/, "", t)
      if (t ~ /pass|verified|✅/) return "verified"
      if (t ~ /fail|❌/) return "failed"
      if (t ~ /unverified-risk|unverifiedrisk|⚠/) return "unverified-risk"
      if (t ~ /pending/) return "pending"
      return "pending"
    }
    function emit(type, title, status, detail, pin,    safe_title, safe_detail) {
      if (title == "" || title ~ /^</) return  # skip placeholders
      idx++
      safe_title=title; gsub(/\037/, " ", safe_title)
      safe_detail=detail; gsub(/\037/, " ", safe_detail)
      printf "e%02d\037%s\037%s\037%s\037%s\037%s\n", idx, type, safe_title, status, safe_detail, pin
    }
    BEGIN { state="" }
    /^### Commands Run/ { state="command"; row_idx=0; next }
    /^### Acceptance Criteria/ { state="acceptance"; row_idx=0; next }
    /^### Unverified Risks/ { state="risk"; row_idx=0; next }
    /^### Manual.*Checks/ { state="manual"; row_idx=0; next }
    /^### Rollback/ { state="rollback"; row_idx=0; next }
    /^## / && state != "" { state=""; next }

    # Table row (Commands Run / Acceptance Criteria)
    state ~ /^(command|acceptance)$/ && /^\|/ {
      if ($0 ~ /^\|[[:space:]]*-+/) { row_idx=-1; next }  # separator row
      row_idx++
      if (row_idx == 1) next  # header row
      # Split |a|b|c|
      n=split($0, cells, "|")
      # cells[1] is empty (before first |), cells[2..4] are data, cells[5] empty
      col1=trim(cells[2])
      col2=trim(cells[3])
      col3=trim(cells[4])
      if (col1 == "" || col1 ~ /^</) next  # skip placeholder rows
      if (state == "command") {
        emit("command", col1, normalize_status(col2), col3, "false")
      } else {
        # acceptance: criterion | evidence | status
        pin = (auto_pin == "true" ? "true" : "false")
        emit("acceptance", col1, normalize_status(col3), col2, pin)
      }
      next
    }

    # List item (risk / manual / rollback)
    state ~ /^(risk|manual|rollback)$/ && /^- / {
      text=$0; sub(/^- /, "", text); text=trim(text)
      if (text == "" || text ~ /^</) next
      if (state == "risk") {
        emit("risk", text, "unverified-risk", "", "false")
      } else if (state == "manual") {
        emit("manual", text, "pending", "", "false")
      } else {
        emit("rollback", text, "pending", "", "false")
      }
      next
    }
  '
}

# === Classify: TSV row → category (hot|cold) ===
sa_classify_evidence() {
  local hot_window="$SEF_HOT_WINDOW"
  local hot_status="$SEF_HOT_STATUS"

  # Read all rows, classify by (parse-order desc index, pin, status)
  local -a rows=()
  local row
  while IFS= read -r row; do
    [[ -n "$row" ]] && rows+=("$row")
  done

  local total=${#rows[@]}
  local i
  for ((i=0; i<total; i++)); do
    local row="${rows[$i]}"
    local id type title status detail pin
    IFS=$'\037' read -r id type title status detail pin <<< "$row"

    # parse-order index from end (newest = idx 1)
    local pos=$((total - i))
    local is_hot="false"

    [[ "$pin" == "true" ]] && is_hot="true"

    if [[ "$is_hot" != "true" ]] && [[ $pos -le ${hot_window} ]]; then
      is_hot="true"
    fi

    if [[ "$is_hot" != "true" ]] && [[ -n "$hot_status" ]]; then
      local IFS_OLD="$IFS"
      IFS=','
      local hs
      for hs in $hot_status; do
        if [[ "$status" == "$hs" ]]; then is_hot="true"; break; fi
      done
      IFS="$IFS_OLD"
    fi

    local category
    if [[ "$is_hot" == "true" ]]; then category="hot"; else category="cold"; fi

    printf '%s\037%s\n' "$row" "$category"
  done
}

# === Emit: text format ===
sa_emit_evidence_text() {
  local hot=() cold=()
  local row
  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    local cat
    cat=$(printf '%s' "$row" | awk -F'\037' '{print $NF}')
    case "$cat" in
      hot) hot+=("$row") ;;
      cold) cold+=("$row") ;;
    esac
  done

  _sef_emit_section "Hot (active, in-prompt)" ${hot[@]+"${hot[@]}"}
  _sef_emit_section "Cold (parse-order older)" ${cold[@]+"${cold[@]}"}
}

_sef_emit_section() {
  local title="$1"
  shift
  printf '### %s — %d entries\n' "$title" "$#"
  if [[ $# -eq 0 ]]; then
    printf '  (none)\n\n'
    return
  fi
  local row
  for row in "$@"; do
    local id type t status detail pin _cat
    IFS=$'\037' read -r id type t status detail pin _cat <<< "$row"
    local pin_marker=""
    [[ "$pin" == "true" ]] && pin_marker=" 📌"
    printf '  - %s [%s, %s%s] %s\n' "$id" "$type" "$status" "$pin_marker" "$t"
    [[ -n "$detail" ]] && printf '      → %s\n' "$detail"
  done
  printf '\n'
}

# === Emit: json format ===
sa_emit_evidence_json() {
  local hot=() cold=()
  local row
  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    local cat
    cat=$(printf '%s' "$row" | awk -F'\037' '{print $NF}')
    case "$cat" in
      hot) hot+=("$row") ;;
      cold) cold+=("$row") ;;
    esac
  done

  printf '{\n'
  printf '  "config": {\n'
  printf '    "hot_window": %s,\n' "$SEF_HOT_WINDOW"
  printf '    "hot_status": "%s",\n' "$(sa_json_escape "$SEF_HOT_STATUS")"
  printf '    "auto_pin_acceptance": %s\n' "$SEF_AUTO_PIN_ACCEPTANCE"
  printf '  },\n'
  printf '  "totals": { "hot": %d, "cold": %d },\n' "${#hot[@]}" "${#cold[@]}"
  _sef_emit_json_array "hot" ${hot[@]+"${hot[@]}"}
  printf ',\n'
  _sef_emit_json_array "cold" ${cold[@]+"${cold[@]}"}
  printf '\n}\n'
}

_sef_emit_json_array() {
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
    local id type title status detail pin _cat
    IFS=$'\037' read -r id type title status detail pin _cat <<< "$row"
    [[ $i -gt 0 ]] && printf ',\n'
    printf '    {'
    printf '"id":"%s",' "$(sa_json_escape "$id")"
    printf '"type":"%s",' "$(sa_json_escape "$type")"
    printf '"title":"%s",' "$(sa_json_escape "$title")"
    printf '"status":"%s",' "$(sa_json_escape "$status")"
    printf '"detail":"%s",' "$(sa_json_escape "$detail")"
    printf '"pin":%s' "$pin"
    printf '}'
    i=$((i+1))
  done
  printf '\n  ]'
}

# === Public top-level: filter + emit ===
sa_filter_evidence() {
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

  sa_resolve_evidence_config "$task_spec" "${cli_args[@]+"${cli_args[@]}"}"

  local classified
  classified=$(sa_parse_evidence "$task_spec" | sa_classify_evidence)

  case "$format" in
    text) printf '%s\n' "$classified" | sa_emit_evidence_text ;;
    json) printf '%s\n' "$classified" | sa_emit_evidence_json ;;
    *) sa_die "unknown format: $format (use text|json)" 64 ;;
  esac
}

# === CLI ===
_sef_main() {
  local task_spec="" format="text"
  local cli=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --task-spec=*) task_spec="${1#--task-spec=}" ;;
      --format=*) format="${1#--format=}" ;;
      --hot-window=*|--hot-status=*|--auto-pin-acceptance=*) cli+=("$1") ;;
      --help|-h)
        cat <<EOF
Usage: evidence-filter.sh --task-spec=<path> [opts]
  --hot-window=<int>              Override hot window size
  --hot-status=<csv>              Override hot statuses (e.g. failed,unverified-risk)
  --auto-pin-acceptance=<bool>    Override auto-pin for acceptance criteria
  --format=text|json              Output format (default: text)
EOF
        return 0
        ;;
      *) sa_die "unknown argument: $1" 64 ;;
    esac
    shift
  done
  [[ -n "$task_spec" ]] || sa_die "--task-spec=<path> required" 64
  sa_filter_evidence "$task_spec" --format="$format" "${cli[@]+"${cli[@]}"}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _sef_main "$@"
fi
