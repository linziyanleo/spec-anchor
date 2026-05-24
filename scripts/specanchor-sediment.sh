#!/usr/bin/env bash
# SpecAnchor Sediment - Hot→Cold 安全回流（v0.6 新增）
#
# Usage:
#   specanchor-sediment.sh propose --finding=<id> --target=<path> --operation=<enum> [options]
#
# 仅提供 `propose` 子命令生成 sediment proposal 骨架。apply / list / archive 子命令留 v0.7。
#
# 设计原则：脚本只生成 proposal 文件；不自动改 spec。spec 更新必须人审后手动应用。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SUBCOMMAND=""
FINDING_IDS=()
TARGET_PATH=""
TARGET_SECTION=""
OPERATION="append"
SUPERSEDES=""
TOPIC=""
OUTPUT_DIR=".specanchor/sediment/proposals"
FINDINGS_DIR=".specanchor/findings"

die() {
  printf 'Error: %s\n' "$1" >&2
  exit "${2:-1}"
}

usage() {
  cat <<'USAGE'
SpecAnchor Sediment v0.6

Usage:
  specanchor-sediment.sh propose --finding=<id> [--finding=<id> ...] --target=<path> [options]

Required:
  --finding=<id>         source finding id (e.g. F-20260524-001); repeatable for multi-source
  --target=<path>        target spec path (.specanchor/modules/auth.spec.md)
  --topic=<slug>         short-kebab summary for filename

Options:
  --target-section=<s>   section name within target spec
  --operation=<enum>     append|replace|supersede|deprecate|delete|merge (default: append)
  --supersedes=<csv>     when operation=supersede, list section/claim names being replaced
  --output-dir=<dir>     override proposals dir (default: .specanchor/sediment/proposals)
  --findings-dir=<dir>   override findings dir (default: .specanchor/findings)

Output:
  Writes .specanchor/sediment/proposals/SP-YYYYMMDD-NNN-<topic>.md and prints its path.

Constraint:
  Each --finding=<id> must resolve to an existing file in --findings-dir.
USAGE
}

validate_enum() {
  local name="$1" value="$2" allowed="$3"
  case " $allowed " in
    *" $value "*) ;;
    *) die "invalid --$name: $value (use: $allowed)" 64 ;;
  esac
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

cmd_propose() {
  [[ ${#FINDING_IDS[@]} -gt 0 ]] || die "at least one --finding=<id> is required" 64
  [[ -n "$TARGET_PATH" ]] || die "--target is required" 64
  [[ -n "$TOPIC" ]] || die "--topic is required" 64
  [[ "$TOPIC" =~ ^[a-z0-9-]+$ ]] || die "--topic must be kebab-case (a-z 0-9 -)" 64
  validate_enum "operation" "$OPERATION" "append replace supersede deprecate delete merge"

  if [[ "$OPERATION" == "supersede" && -z "$SUPERSEDES" ]]; then
    die "--operation=supersede requires --supersedes=<csv>" 64
  fi

  # 校验每个 finding id 都能在 findings dir 找到文件
  local fid resolved
  for fid in "${FINDING_IDS[@]}"; do
    resolved=$(ls "$FINDINGS_DIR"/${fid}-*.md 2>/dev/null | head -1 || true)
    [[ -n "$resolved" ]] || die "finding not found: $fid in $FINDINGS_DIR" 1
  done

  mkdir -p "$OUTPUT_DIR"
  local today serial id path today_iso
  today=$(date +%Y%m%d)
  serial=$(next_serial "SP-${today}" "$OUTPUT_DIR")
  id="SP-${today}-${serial}"
  path="${OUTPUT_DIR}/${id}-${TOPIC}.md"
  today_iso=$(date +%Y-%m-%d)

  [[ ! -e "$path" ]] || die "proposal already exists: $path"

  # 渲染 source_findings YAML 列表
  local source_findings_yaml=""
  for fid in "${FINDING_IDS[@]}"; do
    source_findings_yaml+="  - ${fid}"$'\n'
  done

  # 渲染 supersedes YAML 列表
  local supersedes_yaml="[]"
  if [[ -n "$SUPERSEDES" ]]; then
    supersedes_yaml=$'\n'
    local item
    IFS=',' read -r -a SUPERSEDES_ARRAY <<< "$SUPERSEDES"
    for item in "${SUPERSEDES_ARRAY[@]}"; do
      supersedes_yaml+="  - ${item}"$'\n'
    done
    supersedes_yaml="${supersedes_yaml%$'\n'}"
  fi

  # 渲染 source findings 链接段
  local source_links=""
  for fid in "${FINDING_IDS[@]}"; do
    resolved=$(ls "$FINDINGS_DIR"/${fid}-*.md 2>/dev/null | head -1)
    source_links+="- [${fid}](../../findings/$(basename "$resolved")) — <core observation>"$'\n'
  done

  cat > "$path" <<EOF
---
id: ${id}
source_findings:
${source_findings_yaml%$'\n'}
target:
  path: ${TARGET_PATH}
  section: ${TARGET_SECTION}
operation: ${OPERATION}
supersedes: ${supersedes_yaml}
status: proposed
created: ${today_iso}
updated: ${today_iso}
reviewer: null
review_decision: null
---

# Sediment Proposal: ${TOPIC}

## Source Findings

${source_links}
## Proposed Change

（具体改什么——diff/patch 形式或描述形式）

\`\`\`diff
- (旧内容，如果 operation 是 replace/supersede/delete)
+ (新内容，如果 operation 是 append/replace/merge)
\`\`\`

## Why This Should Become Cold Context

- 稳定性：（这个规则在可预见的未来不会变 / 已经被反复证实 / 是不可变约束）
- 广泛适用性：（这个规则适用于整个 module / 整个项目 / 跨模块）
- 不可遗忘性：（如果不写入 spec，后续 agent / 人会反复重蹈覆辙）

## Evidence

（关联的 evidence_ref / test 结果 / 命令输出 / git diff）

## Risk / Trade-off

（应用这个变更可能带来的风险或权衡）

## Reviewer Decision

> 由 batch review 时 reviewer 填写

- [ ] accept：按 operation 字段 apply 到 target spec
- [ ] reject：拒绝并归档
- [ ] defer：下次 review 再看
- [ ] merge-with-edit：人改 proposal 内容后 accept

Decision rationale: ...
EOF

  printf '%s\n' "$path"
}

main() {
  [[ $# -ge 1 ]] || { usage; exit 0; }
  SUBCOMMAND="$1"; shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --finding=*) FINDING_IDS+=("${1#--finding=}") ;;
      --finding) shift; [[ $# -gt 0 ]] || die "--finding requires a value" 64; FINDING_IDS+=("$1") ;;
      --target=*) TARGET_PATH="${1#--target=}" ;;
      --target) shift; [[ $# -gt 0 ]] || die "--target requires a value" 64; TARGET_PATH="$1" ;;
      --target-section=*) TARGET_SECTION="${1#--target-section=}" ;;
      --target-section) shift; [[ $# -gt 0 ]] || die "--target-section requires a value" 64; TARGET_SECTION="$1" ;;
      --operation=*) OPERATION="${1#--operation=}" ;;
      --operation) shift; [[ $# -gt 0 ]] || die "--operation requires a value" 64; OPERATION="$1" ;;
      --supersedes=*) SUPERSEDES="${1#--supersedes=}" ;;
      --supersedes) shift; [[ $# -gt 0 ]] || die "--supersedes requires a value" 64; SUPERSEDES="$1" ;;
      --topic=*) TOPIC="${1#--topic=}" ;;
      --topic) shift; [[ $# -gt 0 ]] || die "--topic requires a value" 64; TOPIC="$1" ;;
      --output-dir=*) OUTPUT_DIR="${1#--output-dir=}" ;;
      --output-dir) shift; [[ $# -gt 0 ]] || die "--output-dir requires a value" 64; OUTPUT_DIR="$1" ;;
      --findings-dir=*) FINDINGS_DIR="${1#--findings-dir=}" ;;
      --findings-dir) shift; [[ $# -gt 0 ]] || die "--findings-dir requires a value" 64; FINDINGS_DIR="$1" ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown option: $1" 64 ;;
    esac
    shift
  done

  case "$SUBCOMMAND" in
    propose) cmd_propose ;;
    apply|list|archive) die "subcommand '$SUBCOMMAND' not implemented in v0.6 (planned: v0.7)" 64 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown subcommand: $SUBCOMMAND (use: propose)" 64 ;;
  esac
}

main "$@"
