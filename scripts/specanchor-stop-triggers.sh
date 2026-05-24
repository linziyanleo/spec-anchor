#!/usr/bin/env bash
# SpecAnchor Stop Triggers - advisory 风险路径检测（v0.7 新增）
#
# Usage:
#   specanchor-stop-triggers.sh [--against=<ref>] [--staged] [--format=text|json]
#
# 检测 changed/staged 文件是否命中 advisory stop trigger 路径模式：
#   - public_api_change         (api/, openapi/, schema files)
#   - schema_change             (db/migrations/, schema/)
#   - dependency_change         (package.json, Cargo.toml, go.mod, requirements.txt 等)
#   - security_path_change      (auth/, security/, privacy/)
#
# 仅产生 advisory warning——本脚本不阻断执行。硬阻断需要外部 hook / CI / pre-commit。
# 这点与 SpecAnchor v0.6 "语义诚实原则" 一致。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AGAINST="HEAD"
STAGED="false"
FORMAT="text"

die() { printf 'Error: %s\n' "$1" >&2; exit "${2:-1}"; }

usage() {
  cat <<'USAGE'
SpecAnchor Stop Triggers v0.7

Usage:
  specanchor-stop-triggers.sh [options]

Options:
  --against=<ref>    diff against git ref (default: HEAD)
  --staged           detect staged changes only (alternative to --against)
  --format=<fmt>     text | json (default: text)

Trigger categories (all advisory):
  public_api_change      api/, openapi/, swagger.yaml, *.proto
  schema_change          db/migrations/, schema/, *.sql migrations
  dependency_change      package.json, Cargo.toml, go.mod, requirements.txt, Gemfile, pyproject.toml, pom.xml
  security_path_change   auth/, security/, privacy/, .env*, secrets/

Exit codes:
  0   no triggers hit (or triggers reported as advisory; never blocks)
  64  invalid args
USAGE
}

# 输出格式：text 或 json
print_results() {
  local fmt="$1"
  shift
  local -a triggers=("$@")

  if [[ "$fmt" == "json" ]]; then
    printf '['
    local i=0
    while [[ $i -lt ${#triggers[@]} ]]; do
      [[ $i -gt 0 ]] && printf ','
      printf '%s' "${triggers[$i]}"
      i=$((i + 1))
    done
    printf ']\n'
  else
    if [[ ${#triggers[@]} -eq 0 ]]; then
      echo "SpecAnchor Stop Triggers: no advisory triggers hit."
    else
      echo "SpecAnchor Stop Triggers [advisory]:"
      local t
      for t in "${triggers[@]}"; do
        # 解析 JSON 字段 type / files 简单显示
        local ttype tfiles
        ttype=$(printf '%s' "$t" | sed -nE 's/.*"type":"([^"]+)".*/\1/p')
        tfiles=$(printf '%s' "$t" | sed -nE 's/.*"files":\[([^]]*)\].*/\1/p' | tr -d '"' | tr ',' ' ')
        echo "  - ${ttype}: ${tfiles}"
      done
      echo ""
      echo "Note: 仅 advisory。硬阻断需配置 git hooks / CI / pre-commit。"
    fi
  fi
}

# 把空格分隔的文件列表 escape 成 JSON 数组的 string list
json_files_array() {
  local files="$1"
  local file first=1 out=""
  for file in $files; do
    [[ $first -eq 1 ]] && first=0 || out+=','
    # JSON 转义 (最小化：" → \")
    out+="\"$(printf '%s' "$file" | sed 's/"/\\"/g')\""
  done
  printf '%s' "$out"
}

# 检测 trigger：传入 type / pattern_regex / changed_files
# 输出 JSON object 或空（按需）
detect_trigger() {
  local ttype="$1"
  local pattern="$2"
  local changed="$3"
  local enforcement_hint="$4"
  local severity="$5"

  local matched=""
  local f
  for f in $changed; do
    if printf '%s' "$f" | grep -qE "$pattern"; then
      matched+="$f "
    fi
  done
  matched="${matched% }"
  [[ -z "$matched" ]] && return

  local files_arr
  files_arr=$(json_files_array "$matched")
  printf '{"type":"%s","severity":"%s","mode":"advisory","files":[%s],"enforcement_hint":"%s"}' \
    "$ttype" "$severity" "$files_arr" "$enforcement_hint"
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --against=*) AGAINST="${1#--against=}" ;;
      --against)
        shift; [[ $# -gt 0 ]] || die "--against requires a value" 64
        AGAINST="$1"
        ;;
      --staged) STAGED="true" ;;
      --format=*) FORMAT="${1#--format=}" ;;
      --format)
        shift; [[ $# -gt 0 ]] || die "--format requires a value" 64
        FORMAT="$1"
        ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown option: $1" 64 ;;
    esac
    shift
  done

  case "$FORMAT" in text|json) ;; *) die "invalid --format: $FORMAT (use: text | json)" 64 ;; esac

  # 收集 changed files
  local changed_files=""
  if [[ "$STAGED" == "true" ]]; then
    changed_files=$(git diff --cached --name-only 2>/dev/null || true)
  else
    changed_files=$(git diff --name-only "$AGAINST" 2>/dev/null || true)
  fi

  if [[ -z "$changed_files" ]]; then
    print_results "$FORMAT"
    exit 0
  fi

  # 把多行 changed_files 改成空格分隔
  changed_files=$(printf '%s' "$changed_files" | tr '\n' ' ')

  local -a triggers=()
  local t

  # 1. public_api_change
  t=$(detect_trigger "public_api_change" \
      '(^|/)(api|openapi|swagger)(/|\.yaml$|\.json$)|\.proto$' \
      "$changed_files" \
      "consider running OpenAPI codegen + notifying API consumers" \
      "high")
  [[ -n "$t" ]] && triggers+=("$t")

  # 2. schema_change
  t=$(detect_trigger "schema_change" \
      '(^|/)(db|database)/migrations(/|$)|(^|/)schema(/|\.sql$)|migrate.*\.sql$' \
      "$changed_files" \
      "verify rollback path + run migration in staging first" \
      "high")
  [[ -n "$t" ]] && triggers+=("$t")

  # 3. dependency_change
  t=$(detect_trigger "dependency_change" \
      '(^|/)(package\.json|package-lock\.json|pnpm-lock\.yaml|yarn\.lock|Cargo\.toml|Cargo\.lock|go\.mod|go\.sum|requirements\.txt|pyproject\.toml|Pipfile|Gemfile|Gemfile\.lock|pom\.xml|build\.gradle)$' \
      "$changed_files" \
      "audit new deps for license/security; pin versions; verify build" \
      "medium")
  [[ -n "$t" ]] && triggers+=("$t")

  # 4. security_path_change
  t=$(detect_trigger "security_path_change" \
      '(^|/)(auth|security|privacy|secrets)(/|$)|(^|/)\.env(\.|$)' \
      "$changed_files" \
      "require security review; verify no credential leak" \
      "high")
  [[ -n "$t" ]] && triggers+=("$t")

  if [[ ${#triggers[@]} -gt 0 ]]; then
    print_results "$FORMAT" "${triggers[@]}"
  else
    print_results "$FORMAT"
  fi
}

main "$@"
