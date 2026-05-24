#!/usr/bin/env bash
# SpecAnchor Finding - Hot context 写回入口（v0.6 新增）
#
# Usage:
#   specanchor-finding.sh new --topic=<slug> [--type=fact|...] [--confidence=...] [--impact=...] [--visibility=...] [--task=<path>]
#
# 仅提供 `new` 子命令生成 finding 骨架。list / promote / archive 子命令留 v0.7。
#
# 设计原则：脚本只做确定性骨架生成（ID / 文件名 / frontmatter）；正文内容由 agent 或人编辑。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SUBCOMMAND=""
TOPIC=""
TYPE="fact"
CONFIDENCE="medium"
IMPACT="medium"
VISIBILITY=""
SUGGESTED_TARGET="none"
SOURCE_TASK="null"
OUTPUT_DIR=".specanchor/findings"

die() {
  printf 'Error: %s\n' "$1" >&2
  exit "${2:-1}"
}

usage() {
  cat <<'USAGE'
SpecAnchor Finding v0.6

Usage:
  specanchor-finding.sh new --topic=<slug> [options]

Required:
  --topic=<slug>          short-kebab description (e.g. "auth-spec-stale")

Options:
  --type=<enum>           fact|contradiction|stale-claim|risk|reuse-opportunity|pattern (default: fact)
  --confidence=<enum>     low|medium|high (default: medium)
  --impact=<enum>         low|medium|high (default: medium)
  --visibility=<enum>     hidden|handoff|sediment_queue|immediate (default: auto-derived)
  --suggested-target=<e>  none|task|module|global|codemap (default: none)
  --task=<path>           source task spec path
  --output-dir=<dir>      override findings dir (default: .specanchor/findings)

Visibility auto-derivation (when --visibility omitted):
  confidence=low or impact=low                              → hidden
  confidence=medium                                         → handoff
  confidence=high + impact>=medium + suggested-target!=none → sediment_queue

Output:
  Writes .specanchor/findings/F-YYYYMMDD-NNN-<topic>.md and prints its path.
USAGE
}

validate_enum() {
  local name="$1" value="$2" allowed="$3"
  case " $allowed " in
    *" $value "*) ;;
    *) die "invalid --$name: $value (use: $allowed)" 64 ;;
  esac
}

derive_visibility() {
  if [[ -n "$VISIBILITY" ]]; then return; fi
  if [[ "$CONFIDENCE" == "low" || "$IMPACT" == "low" ]]; then
    VISIBILITY="hidden"
  elif [[ "$CONFIDENCE" == "high" && "$IMPACT" != "low" && "$SUGGESTED_TARGET" != "none" ]]; then
    VISIBILITY="sediment_queue"
  else
    VISIBILITY="handoff"
  fi
}

next_serial() {
  local prefix="$1" dir="$2" max=0 file num
  for file in "$dir"/${prefix}-*.md; do
    [[ -f "$file" ]] || continue
    num=$(basename "$file" | awk -F'-' '{print $3}')
    [[ "$num" =~ ^[0-9]+$ ]] || continue
    num=$((10#$num))
    [[ $num -gt $max ]] && max=$num
  done
  printf '%03d\n' $((max + 1))
}

cmd_new() {
  [[ -n "$TOPIC" ]] || die "--topic is required" 64
  [[ "$TOPIC" =~ ^[a-z0-9-]+$ ]] || die "--topic must be kebab-case (a-z 0-9 -)" 64

  validate_enum "type"       "$TYPE"             "fact contradiction stale-claim risk reuse-opportunity pattern"
  validate_enum "confidence" "$CONFIDENCE"       "low medium high"
  validate_enum "impact"     "$IMPACT"           "low medium high"
  validate_enum "suggested-target" "$SUGGESTED_TARGET" "none task module global codemap"

  derive_visibility
  validate_enum "visibility" "$VISIBILITY" "hidden handoff sediment_queue immediate"

  mkdir -p "$OUTPUT_DIR"
  local today serial id path
  today=$(date +%Y%m%d)
  serial=$(next_serial "F-${today}" "$OUTPUT_DIR")
  id="F-${today}-${serial}"
  path="${OUTPUT_DIR}/${id}-${TOPIC}.md"

  [[ ! -e "$path" ]] || die "finding already exists: $path"

  local today_iso
  today_iso=$(date +%Y-%m-%d)

  cat > "$path" <<EOF
---
id: ${id}
type: ${TYPE}
status: candidate
confidence: ${CONFIDENCE}
impact: ${IMPACT}
visibility: ${VISIBILITY}
affects: []
evidence_ref: []
suggested_target: ${SUGGESTED_TARGET}
created: ${today_iso}
updated: ${today_iso}
source_task: ${SOURCE_TASK}
---

# Finding: ${TOPIC}

## Observation

（具体观察到什么——客观事实陈述，避免推测）

## Why It Matters

（影响范围、风险、机会）

## Evidence

（命令输出 / test 结果 / git diff / 文件快照引用）

## Implications

（如果接受这个 finding，对哪些代码 / spec / 决策有影响）

## Proposed Action

（建议处置：是否应该 sediment、是否需要更多验证、是否需要立即处理）
EOF

  printf '%s\n' "$path"
}

main() {
  [[ $# -ge 1 ]] || { usage; exit 0; }
  SUBCOMMAND="$1"; shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --topic=*) TOPIC="${1#--topic=}" ;;
      --topic) shift; [[ $# -gt 0 ]] || die "--topic requires a value" 64; TOPIC="$1" ;;
      --type=*) TYPE="${1#--type=}" ;;
      --type) shift; [[ $# -gt 0 ]] || die "--type requires a value" 64; TYPE="$1" ;;
      --confidence=*) CONFIDENCE="${1#--confidence=}" ;;
      --confidence) shift; [[ $# -gt 0 ]] || die "--confidence requires a value" 64; CONFIDENCE="$1" ;;
      --impact=*) IMPACT="${1#--impact=}" ;;
      --impact) shift; [[ $# -gt 0 ]] || die "--impact requires a value" 64; IMPACT="$1" ;;
      --visibility=*) VISIBILITY="${1#--visibility=}" ;;
      --visibility) shift; [[ $# -gt 0 ]] || die "--visibility requires a value" 64; VISIBILITY="$1" ;;
      --suggested-target=*) SUGGESTED_TARGET="${1#--suggested-target=}" ;;
      --suggested-target) shift; [[ $# -gt 0 ]] || die "--suggested-target requires a value" 64; SUGGESTED_TARGET="$1" ;;
      --task=*) SOURCE_TASK="${1#--task=}" ;;
      --task) shift; [[ $# -gt 0 ]] || die "--task requires a value" 64; SOURCE_TASK="$1" ;;
      --output-dir=*) OUTPUT_DIR="${1#--output-dir=}" ;;
      --output-dir) shift; [[ $# -gt 0 ]] || die "--output-dir requires a value" 64; OUTPUT_DIR="$1" ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown option: $1" 64 ;;
    esac
    shift
  done

  case "$SUBCOMMAND" in
    new) cmd_new ;;
    list|promote|archive) die "subcommand '$SUBCOMMAND' not implemented in v0.6 (planned: v0.7)" 64 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown subcommand: $SUBCOMMAND (use: new)" 64 ;;
  esac
}

main "$@"
