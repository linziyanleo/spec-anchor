#!/usr/bin/env bash
# SpecAnchor Boot-Install
#
# 幂等注入/移除 SpecAnchor 触发块到 Agent 指令文件
# （CLAUDE.md / AGENTS.md / GEMINI.md / .cursor/rules/specanchor.mdc）。
#
# 触发块用 <!-- specanchor:boot:start --> / <!-- specanchor:boot:end --> 包裹，
# 块外内容永不修改。重复运行只替换块内内容，--remove 干净移除块及上方空行。
#
# Usage:
#   specanchor-boot-install.sh [--target=auto|all|<csv>] [--dry-run] [--remove]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SCRIPT_DIR}/lib/common.sh"

BLOCK_START='<!-- specanchor:boot:start -->'
BLOCK_END='<!-- specanchor:boot:end -->'

target_to_path() {
  case "$1" in
    claude) printf '%s\n' "CLAUDE.md" ;;
    codex)  printf '%s\n' "AGENTS.md" ;;
    gemini) printf '%s\n' "GEMINI.md" ;;
    cursor) printf '%s\n' ".cursor/rules/specanchor.mdc" ;;
    *) return 1 ;;
  esac
}

target_to_label() {
  case "$1" in
    claude) printf '%s\n' "Claude Code" ;;
    codex)  printf '%s\n' "Codex / AGENTS.md" ;;
    gemini) printf '%s\n' "Gemini CLI" ;;
    cursor) printf '%s\n' "Cursor" ;;
    *) return 1 ;;
  esac
}

detect_targets() {
  local detected=""
  [[ -d ".claude"   ]] && detected="${detected} claude"
  [[ -f "AGENTS.md" ]] && detected="${detected} codex"
  [[ -f "GEMINI.md" ]] && detected="${detected} gemini"
  [[ -d ".cursor"   ]] && detected="${detected} cursor"
  detected="$(printf '%s' "$detected" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  if [[ -z "$detected" ]]; then
    detected="claude"
  fi
  printf '%s\n' "$detected"
}

render_block() {
  cat <<EOF
${BLOCK_START}
## SpecAnchor (mandatory)

This project uses SpecAnchor (see \`anchor.yaml\`).
Invoke the \`spec-anchor\` skill before code changes, reviews, spec/context management, or process skills.

Boot is session-start / preflight — run it once per session. For later edits in the same session, prefer targeted assemble over re-running boot.

Triggers: code edits, reviews, spec/context queries, alignment, checkpoint, handoff, finding, sediment.
Not needed for: grep, find, git log, running tests, git commit/push — purely mechanical read-only operations.
${BLOCK_END}
EOF
}

inject_block() {
  local file="$1"
  local block_src="$2"

  if [[ ! -f "$file" ]]; then
    local dir
    dir="$(dirname "$file")"
    [[ "$dir" != "." && "$dir" != "" ]] && mkdir -p "$dir"
    cat "$block_src" > "$file"
    return 0
  fi

  local tmpfile
  tmpfile="$(mktemp -t saboot.XXXXXX)"
  awk -v start="$BLOCK_START" -v end="$BLOCK_END" -v blockfile="$block_src" '
    BEGIN {
      in_block = 0
      replaced = 0
      nb = 0
      while ((getline line < blockfile) > 0) {
        block[++nb] = line
      }
      close(blockfile)
    }
    {
      if (in_block == 0 && index($0, start)) {
        in_block = 1
        for (i = 1; i <= nb; i++) print block[i]
        replaced = 1
        next
      }
      if (in_block == 1) {
        if (index($0, end)) { in_block = 0 }
        next
      }
      print
    }
    END {
      if (replaced == 0) {
        if (NR > 0) print ""
        for (i = 1; i <= nb; i++) print block[i]
      }
    }
  ' "$file" > "$tmpfile"
  mv "$tmpfile" "$file"
}

remove_block() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  local stripped
  stripped="$(mktemp -t saboot-strip.XXXXXX)"
  awk -v start="$BLOCK_START" -v end="$BLOCK_END" '
    BEGIN { in_block = 0 }
    {
      if (in_block == 0 && index($0, start)) { in_block = 1; next }
      if (in_block == 1) {
        if (index($0, end)) { in_block = 0 }
        next
      }
      print
    }
  ' "$file" > "$stripped"

  # 收敛连续空行为一个 + trim 首尾空行
  local normalized
  normalized="$(mktemp -t saboot-norm.XXXXXX)"
  awk '
    {
      if ($0 == "") {
        if (seen_nonblank == 1) pending_blank = 1
      } else {
        if (pending_blank == 1) print ""
        print
        seen_nonblank = 1
        pending_blank = 0
      }
    }
  ' "$stripped" > "$normalized"

  mv "$normalized" "$file"
  rm -f "$stripped"
}

usage() {
  cat <<EOF
SpecAnchor boot-install — 幂等注入 Skill 触发块到 Agent 指令文件

Usage:
  specanchor-boot-install.sh [--target=<spec>] [--dry-run] [--remove]

Targets:
  --target=auto         自动检测：.claude/ AGENTS.md GEMINI.md .cursor/（默认）
  --target=all          claude,codex,gemini,cursor 全写
  --target=claude       CLAUDE.md
  --target=codex        AGENTS.md
  --target=gemini       GEMINI.md
  --target=cursor       .cursor/rules/specanchor.mdc
  --target=a,b          多选逗号分隔（如 --target=claude,codex）

Flags:
  --dry-run             仅预览，不写文件
  --remove              移除已注入的标记块（与 --dry-run 兼容）
  -h, --help            显示此帮助

Markers:
  ${BLOCK_START}
  ${BLOCK_END}

幂等行为：
  - 文件不存在：创建并写入标记块（cursor 模式自动 mkdir）
  - 文件存在但无标记块：在末尾追加（前置空行隔离）
  - 文件存在且有标记块：仅替换块内内容，块外保留
EOF
}

main() {
  local target_spec="auto"
  local dry_run=false
  local do_remove=false

  if [[ $# -gt 0 ]]; then
    for arg in "$@"; do
      case "$arg" in
        --target=*) target_spec="${arg#--target=}" ;;
        --dry-run)  dry_run=true ;;
        --remove)   do_remove=true ;;
        --help|-h)  usage; exit 0 ;;
        *) sa_die "Unknown argument: $arg" 64 ;;
      esac
    done
  fi

  local targets=""
  if [[ "$target_spec" == "auto" ]]; then
    targets="$(detect_targets)"
  elif [[ "$target_spec" == "all" ]]; then
    targets="claude codex gemini cursor"
  else
    targets="$(printf '%s' "$target_spec" | tr ',' ' ')"
  fi

  for t in $targets; do
    target_to_path "$t" >/dev/null || sa_die "Unknown target: $t (valid: claude codex gemini cursor)" 64
  done

  echo -e "${BOLD}SpecAnchor Boot-Install${RESET}"
  [[ "$dry_run"   == true ]] && echo -e "  ${YELLOW}(dry-run)${RESET}"
  [[ "$do_remove" == true ]] && echo -e "  ${YELLOW}(remove mode)${RESET}"
  echo -e "  targets: ${CYAN}${targets}${RESET}"
  echo ""

  local block_tmp
  block_tmp="$(mktemp -t saboot-block.XXXXXX)"
  render_block > "$block_tmp"

  for t in $targets; do
    local path label action
    path="$(target_to_path "$t")"
    label="$(target_to_label "$t")"

    if [[ "$do_remove" == true ]]; then
      if [[ -f "$path" ]] && grep -q -F "$BLOCK_START" "$path" 2>/dev/null; then
        if [[ "$dry_run" == true ]]; then
          echo -e "  ${YELLOW}would remove${RESET}  ${path} [${label}]"
        else
          remove_block "$path"
          echo -e "  ${GREEN}✓ removed${RESET}    ${path} [${label}]"
        fi
      else
        echo -e "  ${DIM}skip${RESET}         ${path} (no block)"
      fi
      continue
    fi

    if [[ -f "$path" ]] && grep -q -F "$BLOCK_START" "$path" 2>/dev/null; then
      action="updated"
    elif [[ -f "$path" ]]; then
      action="appended"
    else
      action="created"
    fi

    if [[ "$dry_run" == true ]]; then
      echo -e "  ${YELLOW}would ${action}${RESET}  ${path} [${label}]"
      echo -e "  ${DIM}--- block preview ---${RESET}"
      sed 's/^/    /' "$block_tmp"
      echo -e "  ${DIM}---------------------${RESET}"
    else
      inject_block "$path" "$block_tmp"
      echo -e "  ${GREEN}✓ ${action}${RESET}     ${path} [${label}]"
    fi
  done

  rm -f "$block_tmp"

  echo ""
  if   [[ "$dry_run"   == true ]]; then echo -e "${DIM}dry-run finished, no files changed${RESET}"
  elif [[ "$do_remove" == true ]]; then echo -e "${GREEN}✅ removal complete${RESET}"
  else
    echo -e "${GREEN}✅ boot-install complete${RESET}"
    echo -e "${DIM}下次 Agent session 启动时将读取此触发块${RESET}"
  fi
}

main "$@"
