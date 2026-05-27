#!/usr/bin/env bash
# SpecAnchor Finding Frontmatter Parser (v0.6 lazy-load)
#
# 共享函数 parse_finding_frontmatter，被 finding.sh / validate.sh / assemble.sh /
# doctor.sh 使用，避免各处重复实现。
#
# 设计：bash 3.2 兼容（无 associative array），所有输出走 caller 提供的 prefix
# 命名的全局变量 + 并行数组。
#
# 支持字段（root-level，---/--- 块内）：
#   Scalar: id summary type status confidence impact visibility created updated
#           source_task suggested_target
#   Multiline list-of-single-key:
#     affects:    每条 entry 是单行 `- module: <v>` / `- path: <v>` / `- contract: <v>`
#                 → <PREFIX>_AFFECTS_TYPES[]  + <PREFIX>_AFFECTS_VALUES[]
#   Multiline list-of-two-key:
#     evidence_ref: 每条 entry 跨两行：
#                     - type: <X>
#                       ref: <Y>
#                   → <PREFIX>_EVIDENCE_TYPES[] + <PREFIX>_EVIDENCE_REFS[]
#                   缺 ref 的 entry 跳过 + stderr warn。
#
# 返回：
#   0 = parse 成功（即使所有字段都为空）
#   1 = frontmatter 缺失或文件不可读
#
# 用法：
#   . scripts/lib/finding-parser.sh
#   parse_finding_frontmatter ".specanchor/findings/F-X.md" "FA"
#   echo "$FA_ID"; echo "${FA_AFFECTS_TYPES[@]}"

if [[ -n "${SPECANCHOR_FINDING_PARSER_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
SPECANCHOR_FINDING_PARSER_LOADED=1

# Strip surrounding quotes (single or double) and leading/trailing whitespace.
sa_fp_strip() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  if [[ ${#v} -ge 2 ]]; then
    local f="${v:0:1}" l="${v:$((${#v}-1)):1}"
    if [[ "$f" == "$l" ]] && { [[ "$f" == '"' ]] || [[ "$f" == "'" ]]; }; then
      v="${v:1:$((${#v}-2))}"
    fi
  fi
  printf '%s' "$v"
}

# Reset all output vars for the given prefix.
sa_fp_reset() {
  local p="$1"
  local f
  for f in ID SUMMARY TYPE STATUS CONFIDENCE IMPACT VISIBILITY CREATED UPDATED SOURCE_TASK SUGGESTED_TARGET; do
    eval "${p}_${f}=''"
  done
  eval "${p}_AFFECTS_TYPES=()"
  eval "${p}_AFFECTS_VALUES=()"
  eval "${p}_EVIDENCE_TYPES=()"
  eval "${p}_EVIDENCE_REFS=()"
}

# parse_finding_frontmatter <file> <prefix>
parse_finding_frontmatter() {
  local file="$1"
  local prefix="$2"
  [[ -n "$file" && -n "$prefix" ]] || return 1
  [[ -r "$file" ]] || return 1

  sa_fp_reset "$prefix"

  # Verify frontmatter present (file must start with `---` line).
  local first_line
  IFS= read -r first_line < "$file" || return 1
  [[ "$first_line" == "---" ]] || return 1

  # State machine over the frontmatter block only.
  local state="scan"          # scan | in_affects | in_evidence
  local pending_ev_type=""
  local saw_close=0
  local lineno=0
  local raw stripped key value
  # awk extracts only the first frontmatter block to keep parsing scoped.
  local frontmatter
  frontmatter=$(awk '
    BEGIN { fm = 0 }
    /^---$/ {
      if (fm == 0) { fm = 1; next }
      else { exit }
    }
    fm == 1 { print }
  ' "$file") || return 1

  if [[ -z "$frontmatter" ]]; then
    # Empty frontmatter → still success but no fields populated.
    return 0
  fi

  while IFS= read -r raw; do
    lineno=$((lineno + 1))
    # Skip pure-whitespace and comment-only lines.
    if [[ -z "${raw//[[:space:]]/}" ]]; then
      # Blank line breaks list state.
      if [[ "$state" == "in_evidence" && -n "$pending_ev_type" ]]; then
        sa_fp_warn_orphan "$file" "$lineno" "$pending_ev_type"
        pending_ev_type=""
      fi
      state="scan"
      continue
    fi

    # Detect list-item indent forms: '  - ' or '    - '
    if [[ "$raw" =~ ^[[:space:]]+-[[:space:]] ]]; then
      local item="${raw#*- }"
      case "$state" in
        in_affects)
          # item like 'module: name' or 'path: x' or 'contract: y'
          if [[ "$item" =~ ^[[:space:]]*([A-Za-z_]+)[[:space:]]*:[[:space:]]*(.*)$ ]]; then
            local k="${BASH_REMATCH[1]}"
            local v="${BASH_REMATCH[2]}"
            v="$(sa_fp_strip "$v")"
            v="${v%%#*}"
            v="$(sa_fp_strip "$v")"
            eval "${prefix}_AFFECTS_TYPES+=(\"\$k\")"
            eval "${prefix}_AFFECTS_VALUES+=(\"\$v\")"
          fi
          continue
          ;;
        in_evidence)
          # If a previous evidence entry's type was awaiting a ref, it's now orphan.
          if [[ -n "$pending_ev_type" ]]; then
            sa_fp_warn_orphan "$file" "$lineno" "$pending_ev_type"
            pending_ev_type=""
          fi
          # New entry must start with `type:` after `- `.
          if [[ "$item" =~ ^[[:space:]]*type[[:space:]]*:[[:space:]]*(.*)$ ]]; then
            local v="${BASH_REMATCH[1]}"
            v="$(sa_fp_strip "$v")"
            v="${v%%#*}"
            v="$(sa_fp_strip "$v")"
            pending_ev_type="$v"
          fi
          continue
          ;;
        *)
          # List item outside known list keys → ignore.
          continue
          ;;
      esac
    fi

    # Continuation line for evidence_ref entry: `      ref: <X>` (no leading dash).
    if [[ "$state" == "in_evidence" && -n "$pending_ev_type" ]]; then
      if [[ "$raw" =~ ^[[:space:]]+ref[[:space:]]*:[[:space:]]*(.*)$ ]]; then
        local v="${BASH_REMATCH[1]}"
        v="$(sa_fp_strip "$v")"
        v="${v%%#*}"
        v="$(sa_fp_strip "$v")"
        eval "${prefix}_EVIDENCE_TYPES+=(\"\$pending_ev_type\")"
        eval "${prefix}_EVIDENCE_REFS+=(\"\$v\")"
        pending_ev_type=""
        continue
      fi
    fi

    # Top-level `key: value` line (no leading whitespace).
    if [[ "$raw" =~ ^([A-Za-z_]+)[[:space:]]*:[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"

      # Close any pending evidence entry without ref.
      if [[ "$state" == "in_evidence" && -n "$pending_ev_type" ]]; then
        sa_fp_warn_orphan "$file" "$lineno" "$pending_ev_type"
        pending_ev_type=""
      fi

      case "$key" in
        affects)
          if [[ -z "${value//[[:space:]]/}" || "$value" == "[]" ]]; then
            state="scan"
            # Empty list — keep arrays empty.
            if [[ "$value" == "[]" ]]; then
              :  # explicit empty
            else
              state="in_affects"
            fi
          else
            # Inline list-of-string is not part of finding schema; treat as scan.
            state="scan"
          fi
          ;;
        evidence_ref)
          if [[ -z "${value//[[:space:]]/}" || "$value" == "[]" ]]; then
            if [[ "$value" == "[]" ]]; then
              state="scan"
            else
              state="in_evidence"
            fi
          else
            state="scan"
          fi
          ;;
        id|summary|type|status|confidence|impact|visibility|created|updated|source_task|suggested_target)
          # Strip trailing inline comment for non-summary fields. summary is freeform.
          local v="$value"
          v="$(sa_fp_strip "$v")"
          if [[ "$key" != "summary" ]]; then
            v="${v%%#*}"
            v="$(sa_fp_strip "$v")"
          fi
          # Strip surrounding quotes for non-summary scalars; for summary, only
          # strip if the entire trimmed value is wrapped in matching quotes.
          if [[ "$key" == "summary" ]]; then
            if [[ ${#v} -ge 2 ]]; then
              local f="${v:0:1}" l="${v:$((${#v}-1)):1}"
              if [[ "$f" == "$l" ]] && { [[ "$f" == '"' ]] || [[ "$f" == "'" ]]; }; then
                v="${v:1:$((${#v}-2))}"
              fi
            fi
          fi
          local upkey
          upkey=$(printf '%s' "$key" | tr 'a-z' 'A-Z')
          eval "${prefix}_${upkey}=\"\$v\""
          state="scan"
          ;;
        *)
          state="scan"
          ;;
      esac
      continue
    fi

  done <<< "$frontmatter"

  # Flush any orphan evidence type at EOF.
  if [[ "$state" == "in_evidence" && -n "$pending_ev_type" ]]; then
    sa_fp_warn_orphan "$file" "$lineno" "$pending_ev_type"
  fi

  return 0
}

sa_fp_warn_orphan() {
  local file="$1" lineno="$2" t="$3"
  printf '[finding-parser] warning: %s near line %s: evidence_ref entry type=%s missing ref:; skipped\n' \
    "$file" "$lineno" "$t" >&2
}
