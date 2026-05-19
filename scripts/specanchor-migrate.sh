#!/usr/bin/env bash
# specanchor-migrate.sh — Legacy task spec migrator
#
# Parses `doctor --include-archive --lint=context-control --strict` output to find
# tasks with CC_LINT_*_MISSING warnings, then appends placeholder sections to
# bring them into Harness Context Control compliance.
#
# Drives v0.5-deferred-followup.spec.md Item 1 ("Automatic Migration Tool").
#
# Usage: specanchor-migrate.sh (--dry-run | --apply) [--include-archive]
# Exit:  0 = ok | 1 = scan failed | 2 = bad args

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

sa_init_colors

MODE=""
INCLUDE_ARCHIVE=""

usage() {
  cat <<EOF
Usage: $(basename "$0") (--dry-run | --apply) [--include-archive]

  --dry-run         Parse doctor warnings; print what would change without modifying files
  --apply           Append placeholder sections to bring legacy tasks into compliance
  --include-archive Pass through to doctor so archive/ specs are linted (typical use)
  -h | --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="dry-run" ;;
    --apply) MODE="apply" ;;
    --include-archive) INCLUDE_ARCHIVE="--include-archive" ;;
    -h|--help) usage; exit 0 ;;
    *) sa_die "unknown argument: $1 (use --help)" 2 ;;
  esac
  shift
done

[[ -n "$MODE" ]] || sa_die "exactly one of --dry-run | --apply required" 2

# === Resolve project root via anchor.yaml ===
ANCHOR=$(sa_find_config 2>/dev/null || true)
[[ -n "$ANCHOR" ]] || sa_die "anchor.yaml not found; run from a SpecAnchor project" 1
PROJECT_ROOT="$(cd "$(dirname "$ANCHOR")" && pwd)"
cd "$PROJECT_ROOT"

# === CC_LINT_*_MISSING → (heading, sentinel) lookup ===
# Each placeholder is a heading + a single sentinel line so future humans/tools
# can identify auto-injected sections.
SENTINEL="> not applicable — legacy task (auto-injected $(date +%Y-%m-%d) by specanchor-migrate.sh)"

_heading_for_code() {
  case "$1" in
    CC_LINT_HARD_BOUNDARIES_MISSING) printf '## 1.2 Hard Boundaries\n' ;;
    CC_LINT_ALLOWED_FREEDOM_MISSING) printf '## 1.3 Allowed Freedom\n' ;;
    CC_LINT_CHECKPOINTS_CONTRACT_MISSING) printf '### 4.7 Checkpoints — Contract\n' ;;
    CC_LINT_DECISIONS_LOG_MISSING) printf '## 5.2 Checkpoint Decisions Log\n' ;;
    CC_LINT_EVIDENCE_LEDGER_MISSING) printf '## 6.2 Evidence Ledger\n' ;;
    CC_LINT_HANDOFF_PACKET_MISSING) printf '## 7.2 Handoff Packet\n' ;;
    *) return 1 ;;
  esac
}

# === Run doctor and collect (file, code) pairs ===
DOCTOR_OUTPUT=$(bash "$SCRIPT_DIR/specanchor-doctor.sh" $INCLUDE_ARCHIVE --lint=context-control --strict 2>&1 || true)

# Parse lines like:
#   - CC_LINT_HARD_BOUNDARIES_MISSING: <basename>.spec.md: §1.2 Hard Boundaries 缺失
# Both Blocking and Warnings sections produce the same line shape.
PAIRS=$(printf '%s\n' "$DOCTOR_OUTPUT" | awk '
  /^  - CC_LINT_[A-Z_]+_MISSING: / {
    sub(/^  - /, "", $0)
    n=split($0, parts, ": ")
    if (n >= 2) {
      code=parts[1]
      base=parts[2]
      print code "\t" base
    }
  }
')

if [[ -z "$PAIRS" ]]; then
  printf '%s\n' "${GREEN}✓ No CC_LINT_*_MISSING warnings; nothing to migrate.${RESET}"
  exit 0
fi

# === Group pairs by file basename ===
# Build newline-delimited list of unique basenames (Bash 3.2 friendly)
UNIQUE_BASENAMES=$(printf '%s\n' "$PAIRS" | awk -F'\t' '{print $2}' | sort -u)

# === Resolve each basename to a real path under archive/ or tasks/ ===
_resolve_path() {
  local base="$1"
  local hit
  hit=$(find .specanchor/archive .specanchor/tasks -name "$base" -type f 2>/dev/null | head -1)
  printf '%s\n' "$hit"
}

# === Build per-file plan: codes (in canonical order) + heading list ===
CANONICAL_ORDER="CC_LINT_HARD_BOUNDARIES_MISSING CC_LINT_ALLOWED_FREEDOM_MISSING CC_LINT_CHECKPOINTS_CONTRACT_MISSING CC_LINT_DECISIONS_LOG_MISSING CC_LINT_EVIDENCE_LEDGER_MISSING CC_LINT_HANDOFF_PACKET_MISSING"

CHANGED_FILES=0
TOTAL_SECTIONS=0

while IFS= read -r base; do
  [[ -z "$base" ]] && continue
  path=$(_resolve_path "$base")
  if [[ -z "$path" ]]; then
    sa_warn "could not resolve path for basename: $base (skipping)"
    continue
  fi

  # Collect codes for this file, in canonical order
  file_codes=""
  for code in $CANONICAL_ORDER; do
    if printf '%s\n' "$PAIRS" | awk -F'\t' -v c="$code" -v b="$base" '$1==c && $2==b {found=1} END{exit !found}'; then
      file_codes+=" $code"
    fi
  done
  file_codes="${file_codes# }"
  count=$(printf '%s\n' "$file_codes" | wc -w | tr -d ' ')

  CHANGED_FILES=$((CHANGED_FILES + 1))
  TOTAL_SECTIONS=$((TOTAL_SECTIONS + count))

  printf '\n%s%s%s\n' "${BOLD}" "$path" "${RESET}"
  printf '  Missing %d section(s):' "$count"
  for code in $file_codes; do
    heading=$(_heading_for_code "$code")
    printf ' %s,' "$(printf '%s' "$heading" | tr -d '\n')"
  done
  printf '\n'

  if [[ "$MODE" == "apply" ]]; then
    # Append blank line + heading + sentinel for each missing section, in canonical order
    {
      printf '\n'
      for code in $file_codes; do
        heading=$(_heading_for_code "$code")
        printf '%s\n%s\n' "$heading" "$SENTINEL"
        printf '\n'
      done
    } >> "$path"
    printf '  %s✓ Appended %d sections to %s%s\n' "${GREEN}" "$count" "$path" "${RESET}"
  fi
done <<< "$UNIQUE_BASENAMES"

printf '\n%s%s%s\n' "${BOLD}" "Summary" "${RESET}"
printf '  Mode: %s\n' "$MODE"
printf '  Files affected: %d\n' "$CHANGED_FILES"
printf '  Total sections: %d\n' "$TOTAL_SECTIONS"

if [[ "$MODE" == "dry-run" ]]; then
  printf '\n%sRun with --apply to actually modify files.%s\n' "${DIM}" "${RESET}"
fi
