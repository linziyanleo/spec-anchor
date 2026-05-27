#!/usr/bin/env bash
# SpecAnchor Assemble - convert resolved anchors into an agent-ready context plan.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=scripts/lib/finding-parser.sh
source "$SCRIPT_DIR/lib/finding-parser.sh"

FORMAT="text"
FILES_CSV=""
FILES_FROM=""
INTENT=""
INTENT_FILE=""
DIFF_FROM=""
BUDGET_PROFILE="normal"
RESOLVE_JSON=""
WRITE_TRACE=""

# === Harness Context Control handoff mode (v0.5.0-beta.1) ===
MODE="resolve"
TASK_SPEC_PATH=""
WRITE_BACK="false"
BUNDLE_SCHEMA="assembly.v1"        # v0.6 新增：assembly.v1 (默认，向后兼容) | context_bundle.v1
FRESHNESS_STALE_AGE_DAYS=14        # v0.6 新增：age >= 此值标 stale（对齐 anchor.yaml.check.stale_days）
FRESHNESS_OUTDATED_AGE_DAYS=30     # age >= 此值标 outdated（对齐 anchor.yaml.check.outdated_days）
MAX_FINDINGS=50                    # v0.6 lazy-load：sediment_queue + handoff 共享 cap（immediate 桶 uncapped）
MAX_FINDINGS_CLI_SET=0             # v0.6 lazy-load：CLI 显式 --max-findings=N 时置 1，让 anchor.yaml override 跳过

TMP_FILES=()

declare -a FILES_TO_READ_PATHS=()
declare -a FILES_TO_READ_LOADS=()
declare -a FILES_TO_READ_REASONS=()
declare -a WARNING_MESSAGES=()
declare -a AGENT_INSTRUCTIONS=()

# v0.6 lazy-load：finding discovery 输入与输出（不与 FILES_TO_READ_* 共享）
declare -a REQUESTED_TARGET_FILES=()
declare -a DISCOVERED_FINDING_PATHS=()
declare -a DISCOVERED_FINDING_LOADS=()
declare -a DISCOVERED_FINDING_IDS=()
declare -a DISCOVERED_FINDING_TYPES=()
declare -a DISCOVERED_FINDING_IMPACTS=()
declare -a DISCOVERED_FINDING_VISIBILITIES=()
declare -a DISCOVERED_FINDING_AFFECTS=()       # 已 JSON 字符串化的 list
declare -a DISCOVERED_FINDING_SUMMARIES=()
declare -a DISCOVERED_FINDING_MATCH_PRECISIONS=()

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
      out="${out}, ${path} [${FILES_TO_READ_LOADS[$i]}]"
    else
      out="${path} [${FILES_TO_READ_LOADS[$i]}]"
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

# v0.6 lazy-load：从 anchor.yaml 读 context.budget.max_findings（CLI 已显式覆写时跳过）
load_anchor_max_findings_override() {
  [[ "$MAX_FINDINGS_CLI_SET" == "1" ]] && return 0
  local config
  config=$(sa_find_config 2>/dev/null) || return 0
  [[ -f "$config" ]] || return 0
  local raw
  # 优先识别 `findings:` 块内的 `max_per_bundle: <N>`（v0.6 lazy-load 契约）
  # fallback 兼容历史 `max_findings: <N>` 写法
  raw=$(awk '
    BEGIN { in_findings = 0; findings_depth = -1 }
    {
      match($0, /^[[:space:]]*/)
      cur_depth = RLENGTH
    }
    # 优先识别 findings: 块开头（top-level 或嵌套均可）
    /^[[:space:]]*findings:[[:space:]]*$/ {
      in_findings = 1
      findings_depth = cur_depth
      next
    }
    # 块内非空且缩进 > findings_depth 视为 in-block；缩进 <= 视为 block 结束
    in_findings && /[^[:space:]]/ && cur_depth <= findings_depth {
      in_findings = 0
    }
    in_findings && /^[[:space:]]*max_per_bundle:[[:space:]]/ {
      sub(/^[[:space:]]*max_per_bundle:[[:space:]]*/, "", $0)
      sub(/[[:space:]]*#.*$/, "", $0)
      print
      exit
    }
    # legacy fallback：未在 findings: 块内的 max_findings 全局兜底
    !in_findings && /^[[:space:]]+max_findings:[[:space:]]/ {
      sub(/^[[:space:]]+max_findings:[[:space:]]*/, "", $0)
      sub(/[[:space:]]*#.*$/, "", $0)
      print
      exit
    }
  ' "$config")
  raw=$(printf '%s' "$raw" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    MAX_FINDINGS="$raw"
  fi
}

# v0.6 lazy-load：合并各路输入到 REQUESTED_TARGET_FILES[]（去重 + 去空 + repo-relative）
build_requested_targets() {
  REQUESTED_TARGET_FILES=()
  local seen_marker_prefix="__sa_seen__"
  local raw_path normalized

  add_target() {
    local p="$1"
    p=$(printf '%s' "$p" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^"//; s/"$//; s/^,//; s/,$//')
    [[ -z "$p" ]] && return 0
    # 去重（线性扫描；REQUESTED_TARGET_FILES 通常 < 100 entries）
    local existing
    for existing in "${REQUESTED_TARGET_FILES[@]:-}"; do
      [[ "$existing" == "$p" ]] && return 0
    done
    REQUESTED_TARGET_FILES+=("$p")
  }

  # FILES_CSV：逗号分隔
  if [[ -n "$FILES_CSV" ]]; then
    local IFS=','
    local item
    for item in $FILES_CSV; do
      add_target "$item"
    done
  fi

  # FILES_FROM：每行一个
  if [[ -n "$FILES_FROM" && -f "$FILES_FROM" ]]; then
    while IFS= read -r raw_path || [[ -n "$raw_path" ]]; do
      add_target "$raw_path"
    done < "$FILES_FROM"
  fi

  # DIFF_FROM：git diff name-only
  if [[ -n "$DIFF_FROM" ]]; then
    local diff_files
    if diff_files=$(git diff --name-only "$DIFF_FROM" 2>/dev/null); then
      while IFS= read -r raw_path; do
        add_target "$raw_path"
      done <<< "$diff_files"
    fi
  fi

  # RESOLVE_JSON：读 inputs.files[]（resolve.v2 中保存用户原始 target 文件；
  # 不读 anchors[].path——那是已解析锚点 ≠ 用户输入）
  if [[ -n "$RESOLVE_JSON" && -f "$RESOLVE_JSON" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      local files_block
      files_block=$(python3 - "$RESOLVE_JSON" <<'PY'
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as fh:
        data = json.load(fh)
    for f in (data.get("inputs", {}) or {}).get("files", []) or []:
        if isinstance(f, str) and f.strip():
            print(f.strip())
except Exception:
    pass
PY
)
      while IFS= read -r raw_path; do
        add_target "$raw_path"
      done <<< "$files_block"
    fi
  fi
}

# v0.6 lazy-load：visibility → load 标签映射
visibility_to_load() {
  case "$1" in
    immediate)      printf 'full' ;;
    sediment_queue) printf 'summary' ;;
    handoff)        printf 'title' ;;
    *)              printf 'title' ;;
  esac
}

# v0.6 lazy-load：把 affects 并行数组渲染为内联 JSON list
finding_render_affects_json() {
  local i count="$1"
  shift
  local types_var="$1" values_var="$2"
  local out="["
  i=0
  while [[ $i -lt $count ]]; do
    local t v
    t=$(eval "printf '%s' \"\${${types_var}[$i]}\"")
    v=$(eval "printf '%s' \"\${${values_var}[$i]}\"")
    [[ $i -gt 0 ]] && out+=","
    out+=$(printf '{"type":"%s","value":"%s"}' "$(sa_json_escape "$t")" "$(sa_json_escape "$v")")
    i=$((i + 1))
  done
  out+="]"
  printf '%s' "$out"
}

# v0.6 lazy-load：把 module 名 → 目录前缀（扫 .specanchor/specs/modules/*.md 的 module_path frontmatter 字段）
declare -a SA_MODULE_NAMES=()
declare -a SA_MODULE_PATHS=()
SA_MODULE_MAP_LOADED=0
load_module_path_map() {
  [[ "$SA_MODULE_MAP_LOADED" == "1" ]] && return 0
  SA_MODULE_MAP_LOADED=1
  local module_dir
  for module_dir in .specanchor/specs/modules .specanchor/modules; do
    [[ -d "$module_dir" ]] || continue
    local f mp name fname
    for f in "$module_dir"/*.md; do
      [[ -f "$f" ]] || continue
      mp=$(sa_parse_frontmatter_field "$f" "module_path" 2>/dev/null || true)
      [[ -n "$mp" ]] || continue
      # 优先用 frontmatter module_name；fallback 到去 .spec.md / .md 后缀的文件名
      name=$(sa_parse_frontmatter_field "$f" "module_name" 2>/dev/null || true)
      if [[ -z "$name" ]]; then
        fname=$(basename "$f")
        name="${fname%.spec.md}"
        name="${name%.md}"
      fi
      SA_MODULE_NAMES+=("$name")
      SA_MODULE_PATHS+=("$mp")
    done
  done
}

module_name_to_path() {
  local name="$1"
  load_module_path_map
  local i=0
  while [[ $i -lt ${#SA_MODULE_NAMES[@]} ]]; do
    if [[ "${SA_MODULE_NAMES[$i]}" == "$name" ]]; then
      printf '%s' "${SA_MODULE_PATHS[$i]}"
      return 0
    fi
    i=$((i + 1))
  done
  printf ''
}

# v0.6 lazy-load：扫描 .specanchor/findings/*.md，按 affects + REQUESTED_TARGET_FILES 命中匹配
discover_findings() {
  # 守门：调用方应已确认 schema gate；这里再加一层防御
  [[ "$FORMAT" == "json" ]] || return 0
  [[ "$BUNDLE_SCHEMA" == "context_bundle.v1" ]] || return 0
  [[ ${#REQUESTED_TARGET_FILES[@]} -gt 0 ]] || return 0
  [[ -d ".specanchor/findings" ]] || return 0

  local f
  # 临时收集所有命中（未 cap），存到本地并行数组，最后做 cap+sort 写入 DISCOVERED_FINDING_*
  local -a tmp_paths=() tmp_loads=() tmp_ids=() tmp_types=() tmp_impacts=() tmp_visibilities=()
  local -a tmp_summaries=() tmp_match_precisions=() tmp_affects_json=() tmp_created=()

  for f in .specanchor/findings/*.md; do
    [[ -f "$f" ]] || continue
    case "$(basename "$f")" in
      finding-template.md|.gitkeep) continue ;;
    esac

    if ! parse_finding_frontmatter "$f" "DF"; then
      continue
    fi
    [[ -n "$DF_ID" ]] || continue
    [[ "$DF_VISIBILITY" == "hidden" ]] && continue

    # 默认 visibility 兜底（解析失败/缺字段时按 handoff 处理，避免漏 finding）
    local vis="${DF_VISIBILITY:-handoff}"

    # 按 affects 与 REQUESTED_TARGET_FILES[] 做最长前缀匹配
    local hit=0 best_precision=0
    local n_aff=${#DF_AFFECTS_TYPES[@]}
    local i=0
    while [[ $i -lt $n_aff ]]; do
      local at="${DF_AFFECTS_TYPES[$i]}"
      local av="${DF_AFFECTS_VALUES[$i]}"
      local prefix=""
      case "$at" in
        path)     prefix="$av" ;;
        module)   prefix=$(module_name_to_path "$av") ;;
        contract) prefix="" ;; # v0.6 不支持 contract 命中
      esac
      if [[ -n "$prefix" ]]; then
        local tf
        for tf in "${REQUESTED_TARGET_FILES[@]}"; do
          # 前缀匹配（以 prefix 开头；prefix 不必以 / 结尾）
          case "$tf" in
            "$prefix"|"$prefix"/*|"$prefix"*)
              hit=1
              if [[ ${#prefix} -gt $best_precision ]]; then
                best_precision=${#prefix}
              fi
              ;;
          esac
        done
      fi
      i=$((i + 1))
    done

    [[ $hit -eq 1 ]] || continue

    local load
    load=$(visibility_to_load "$vis")
    local affects_json
    affects_json=$(finding_render_affects_json "$n_aff" DF_AFFECTS_TYPES DF_AFFECTS_VALUES)

    tmp_paths+=("$f")
    tmp_loads+=("$load")
    tmp_ids+=("$DF_ID")
    tmp_types+=("${DF_TYPE:-}")
    tmp_impacts+=("${DF_IMPACT:-medium}")
    tmp_visibilities+=("$vis")
    tmp_summaries+=("${DF_SUMMARY:-}")
    tmp_match_precisions+=("$best_precision")
    tmp_affects_json+=("$affects_json")
    tmp_created+=("${DF_CREATED:-}")
  done

  # cap + sort：分桶
  local total=${#tmp_paths[@]}
  [[ $total -gt 0 ]] || return 0

  # 按桶顺序 immediate → sediment_queue → handoff，桶内按
  # 长前缀 desc → impact desc(high>medium>low) → created desc
  # 用 awk pipeline 排序：每行一个 sort key + index
  impact_rank() {
    case "$1" in high) printf '3' ;; medium) printf '2' ;; low) printf '1' ;; *) printf '0' ;; esac
  }

  local -a bucket_immediate=()
  local -a bucket_sediment=()
  local -a bucket_handoff=()

  local idx=0
  while [[ $idx -lt $total ]]; do
    local v="${tmp_visibilities[$idx]}"
    case "$v" in
      immediate)      bucket_immediate+=("$idx") ;;
      sediment_queue) bucket_sediment+=("$idx") ;;
      handoff|*)      bucket_handoff+=("$idx") ;;
    esac
    idx=$((idx + 1))
  done

  # 桶内排序 helper（bash 3.2 兼容：用 eval 取数组元素，sort 后 read 回栈）
  bucket_sort_by_keys() {
    local arr_name="$1"
    local count
    count=$(eval "printf '%s' \${#$arr_name[@]}")
    [[ $count -gt 0 ]] || return 0
    local input="" k i
    i=0
    while [[ $i -lt $count ]]; do
      local idx_val
      idx_val=$(eval "printf '%s' \"\${${arr_name}[$i]}\"")
      local impact created precision
      precision="${tmp_match_precisions[$idx_val]}"
      impact=$(impact_rank "${tmp_impacts[$idx_val]}")
      created="${tmp_created[$idx_val]}"
      # key: precision(8d desc) <TAB> impact(1d desc) <TAB> created(desc 字符串) <TAB> idx
      input+=$(printf '%08d\t%s\t%s\t%s\n' "$precision" "$impact" "$created" "$idx_val")
      input+=$'\n'
      i=$((i + 1))
    done
    # 三键 desc 排序：-k1,1 数字 desc; -k2,2 数字 desc; -k3,3 字符串 desc
    local sorted
    sorted=$(printf '%s' "$input" | grep -v '^$' | sort -t $'\t' -k1,1nr -k2,2nr -k3,3r)
    # rebuild array
    eval "$arr_name=()"
    while IFS=$'\t' read -r _ _ _ idx_val; do
      [[ -z "$idx_val" ]] && continue
      eval "$arr_name+=(\"$idx_val\")"
    done <<< "$sorted"
  }

  bucket_sort_by_keys bucket_immediate
  bucket_sort_by_keys bucket_sediment
  bucket_sort_by_keys bucket_handoff

  # cap：immediate uncapped；sediment + handoff 共享 MAX_FINDINGS
  local cap=$MAX_FINDINGS
  [[ "$cap" =~ ^[0-9]+$ ]] || cap=50
  local kept_sediment_count=${#bucket_sediment[@]}
  local kept_handoff_count=${#bucket_handoff[@]}
  local total_shared=$((kept_sediment_count + kept_handoff_count))
  local truncated_count=0
  if [[ $total_shared -gt $cap ]]; then
    truncated_count=$((total_shared - cap))
    # 优先保留 sediment（重要性更高），剩余 cap 给 handoff
    if [[ $kept_sediment_count -ge $cap ]]; then
      kept_sediment_count=$cap
      kept_handoff_count=0
    else
      kept_handoff_count=$((cap - kept_sediment_count))
    fi
  fi

  # 组装最终 DISCOVERED_FINDING_* 数组
  emit_one() {
    local arr_name="$1" limit="$2"
    local count
    count=$(eval "printf '%s' \${#$arr_name[@]}")
    [[ -z "$limit" ]] && limit=$count
    [[ $limit -gt $count ]] && limit=$count
    local k=0
    while [[ $k -lt $limit ]]; do
      local idx_val
      idx_val=$(eval "printf '%s' \"\${${arr_name}[$k]}\"")
      DISCOVERED_FINDING_PATHS+=("${tmp_paths[$idx_val]}")
      DISCOVERED_FINDING_LOADS+=("${tmp_loads[$idx_val]}")
      DISCOVERED_FINDING_IDS+=("${tmp_ids[$idx_val]}")
      DISCOVERED_FINDING_TYPES+=("${tmp_types[$idx_val]}")
      DISCOVERED_FINDING_IMPACTS+=("${tmp_impacts[$idx_val]}")
      DISCOVERED_FINDING_VISIBILITIES+=("${tmp_visibilities[$idx_val]}")
      DISCOVERED_FINDING_AFFECTS+=("${tmp_affects_json[$idx_val]}")
      DISCOVERED_FINDING_SUMMARIES+=("${tmp_summaries[$idx_val]}")
      DISCOVERED_FINDING_MATCH_PRECISIONS+=("${tmp_match_precisions[$idx_val]}")
      k=$((k + 1))
    done
  }
  emit_one bucket_immediate ""
  emit_one bucket_sediment "$kept_sediment_count"
  emit_one bucket_handoff  "$kept_handoff_count"

  if [[ $truncated_count -gt 0 ]]; then
    WARNING_MESSAGES+=("finding_cap_truncated: truncated ${truncated_count} findings (cap=${cap}, buckets=sediment_queue+handoff)")
    sa_warn "truncated ${truncated_count} findings (sediment_queue+handoff bucket exceeded cap=${cap})"
  fi
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

# v0.6 新增：source_type 启发式推断（path → spec|decision|evidence|finding|codemap）
infer_source_type() {
  local path="$1"
  case "$path" in
    *"/findings/"*) printf 'finding' ;;
    *"/sediment/"*) printf 'finding' ;;
    *"/decisions/"*) printf 'decision' ;;
    *"/evidence/"*) printf 'evidence' ;;
    *"codemap"*|*"project-codemap"*) printf 'codemap' ;;
    *) printf 'spec' ;;
  esac
}

# v0.6 新增：time-based freshness（用 git mtime 或文件 mtime；输出 fresh|stale|outdated|unknown）
infer_freshness() {
  local path="$1"
  local mtime age_days
  if [[ ! -e "$path" ]]; then
    printf 'unknown'
    return
  fi
  # 优先用 git 最后修改时间（更稳）；fallback 文件 mtime
  if mtime=$(git -C "$(dirname "$path")" log -1 --format=%ct -- "$(basename "$path")" 2>/dev/null); then
    :
  fi
  if [[ -z "$mtime" ]]; then
    mtime=$(stat -f %m "$path" 2>/dev/null || stat -c %Y "$path" 2>/dev/null || echo "")
  fi
  if [[ -z "$mtime" ]]; then
    printf 'unknown'
    return
  fi
  age_days=$(( ($(date +%s) - mtime) / 86400 ))
  if   [[ $age_days -lt $FRESHNESS_STALE_AGE_DAYS ]];     then printf 'fresh'
  elif [[ $age_days -lt $FRESHNESS_OUTDATED_AGE_DAYS ]];  then printf 'stale'
  else                                                          printf 'outdated'
  fi
}

# v0.6 新增：freshness_reasons 文本（time-based 描述）
infer_freshness_reason() {
  local path="$1"
  local mtime age_days
  [[ -e "$path" ]] || { printf 'file not found'; return; }
  if mtime=$(git -C "$(dirname "$path")" log -1 --format=%ct -- "$(basename "$path")" 2>/dev/null); then :; fi
  if [[ -z "$mtime" ]]; then
    mtime=$(stat -f %m "$path" 2>/dev/null || stat -c %Y "$path" 2>/dev/null || echo "")
  fi
  [[ -n "$mtime" ]] || { printf 'no mtime available'; return; }
  age_days=$(( ($(date +%s) - mtime) / 86400 ))
  printf 'last modified %d day(s) ago' "$age_days"
}

# v0.6 新增：Context Bundle v1 JSON 输出
print_json_bundle_v1() {
  local i=0 path load reason stype freshness reason_text
  printf '{\n'
  printf '  "schema_version": "specanchor.context_bundle.v1",\n'
  printf '  "status": "%s",\n' "$STATUS"
  printf '  "intent": "%s",\n' "$(sa_json_escape "$INTENT")"
  printf '  "budget": {\n'
  printf '    "profile": "%s",\n' "$BUDGET_PROFILE"
  printf '    "max_files": %s,\n' "$MAX_FILES"
  printf '    "max_lines": %s,\n' "$MAX_LINES"
  printf '    "estimated_files": %s,\n' "$ESTIMATED_FILES"
  printf '    "estimated_lines": %s,\n' "$ESTIMATED_LINES"
  printf '    "truncated": %s\n' "$TRUNCATED"
  printf '  },\n'

  # layers: 按 source_type 分组（保留 files_to_read 列表作为 flat view 备份）
  # finding 层独立从 DISCOVERED_FINDING_* 并行数组取（v0.6 lazy-load discovery 输出），
  # 不再从 FILES_TO_READ_* 推断；其他层（spec/decision/evidence/codemap）保持旧行为。
  local layer
  printf '  "layers": {\n'
  local first_layer=1
  for layer in spec decision evidence finding codemap; do
    [[ $first_layer -eq 1 ]] || printf ',\n'
    first_layer=0
    printf '    "%s": [' "$layer"
    local first_item=1
    if [[ "$layer" == "finding" ]]; then
      i=0
      while [[ $i -lt ${#DISCOVERED_FINDING_PATHS[@]} ]]; do
        path="${DISCOVERED_FINDING_PATHS[$i]}"
        load="${DISCOVERED_FINDING_LOADS[$i]}"
        freshness=$(infer_freshness "$path")
        reason_text=$(infer_freshness_reason "$path")
        [[ $first_item -eq 1 ]] || printf ','
        first_item=0
        printf '\n      {"id":"%s","path":"%s","type":"%s","impact":"%s","visibility":"%s","affects":%s,"summary":"%s","load":"%s","freshness":"%s","freshness_reasons":["%s"],"confidence":"%s","source_type":"finding"}' \
          "$(sa_json_escape "${DISCOVERED_FINDING_IDS[$i]}")" \
          "$(sa_json_escape "$path")" \
          "$(sa_json_escape "${DISCOVERED_FINDING_TYPES[$i]}")" \
          "$(sa_json_escape "${DISCOVERED_FINDING_IMPACTS[$i]}")" \
          "$(sa_json_escape "${DISCOVERED_FINDING_VISIBILITIES[$i]}")" \
          "${DISCOVERED_FINDING_AFFECTS[$i]}" \
          "$(sa_json_escape "${DISCOVERED_FINDING_SUMMARIES[$i]}")" \
          "$load" \
          "$freshness" \
          "$(sa_json_escape "$reason_text")" \
          "$(sa_json_escape "${DISCOVERED_FINDING_IMPACTS[$i]}")"
        i=$((i + 1))
      done
    else
      i=0
      while [[ $i -lt ${#FILES_TO_READ_PATHS[@]} ]]; do
        path="${FILES_TO_READ_PATHS[$i]}"
        stype=$(infer_source_type "$path")
        # finding 层的 file 已在 DISCOVERED_FINDING_* 渲染；这里跳过避免重复
        if [[ "$stype" == "finding" ]]; then
          i=$((i + 1)); continue
        fi
        if [[ "$stype" == "$layer" ]]; then
          load="${FILES_TO_READ_LOADS[$i]}"
          reason="${FILES_TO_READ_REASONS[$i]}"
          freshness=$(infer_freshness "$path")
          reason_text=$(infer_freshness_reason "$path")
          [[ $first_item -eq 1 ]] || printf ','
          first_item=0
          printf '\n      {"path":"%s","load":"%s","reason":"%s","source_type":"%s","freshness":"%s","freshness_reasons":["%s"],"confidence":null}' \
            "$(sa_json_escape "$path")" \
            "$load" \
            "$(sa_json_escape "$reason")" \
            "$stype" \
            "$freshness" \
            "$(sa_json_escape "$reason_text")"
        fi
        i=$((i + 1))
      done
    fi
    [[ $first_item -eq 0 ]] && printf '\n    '
    printf ']'
  done
  printf '\n  },\n'

  # files_to_read 保留为 flat view（向后兼容老消费者）
  printf '  "files_to_read": [\n'
  i=0
  while [[ $i -lt ${#FILES_TO_READ_PATHS[@]} ]]; do
    [[ $i -gt 0 ]] && printf ',\n'
    printf '    {"path":"%s","load":"%s","reason":"%s"}' \
      "$(sa_json_escape "${FILES_TO_READ_PATHS[$i]}")" \
      "${FILES_TO_READ_LOADS[$i]}" \
      "$(sa_json_escape "${FILES_TO_READ_REASONS[$i]}")"
    i=$((i + 1))
  done
  printf '\n  ],\n'

  # v0.6 stop_triggers 留占位（Phase 5 实现）
  printf '  "stop_triggers": [],\n'
  printf '  "missing": %s,\n' "$MISSING_COUNT"
  printf '  "agent_instructions": '
  print_json_array AGENT_INSTRUCTIONS
  printf ',\n'
  printf '  "assembly_trace": {\n'
  printf '    "global": "%s",\n' "$GLOBAL_TRACE"
  printf '    "module": "%s",\n' "$MODULE_TRACE"
  printf '    "task": "%s",\n' "$TASK_TRACE"
  printf '    "sources": "%s"\n' "$SOURCES_TRACE"
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

# === Handoff packet rendering (Harness Context Control) ===
hp_extract_modules_list() {
  local task_spec="$1"
  awk '
    /^---$/ { in_fm=!in_fm; next }
    !in_fm { next }
    /^  related_modules:/ { in_rm=1; next }
    in_rm && /^  [A-Za-z_-]+:/ && !/^  related_modules:/ { in_rm=0 }
    in_rm && /^[[:space:]]+- / {
      sub(/^[[:space:]]+- "?/, "", $0); sub(/"?[[:space:]]*$/, "", $0)
      print
    }
  ' "$task_spec"
}

hp_next_step() {
  local task_spec="$1"
  awk '
    /^## 5\. Execute Log/ { in_log=1; next }
    in_log && /^## / && !/^## 5\.2/ { exit }
    in_log && /^- \[ \]/ {
      sub(/^- \[ \] /, ""); print; exit
    }
  ' "$task_spec"
}

hp_render_packet() {
  local format="$1" name="$2" status="$3" phase="$4" modules_csv="$5"
  local hot_ids="$6" hot_count="$7" cold_count="$8" superseded_count="$9" withdrawn_count="${10}"
  local ev_verified="${11}" ev_failed="${12}" ev_unverified_risk="${13}" ev_pending="${14}"
  local next_step="${15}"

  local timestamp
  timestamp=$(date -u "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date "+%Y-%m-%dT%H:%M:%SZ")

  local module_display="${modules_csv:-(none)}"
  local hot_display="${hot_ids:-(none)}"
  local dont_read_total=$((cold_count + superseded_count + withdrawn_count))
  [[ -z "$next_step" ]] && next_step="all execute steps complete"

  case "$format" in
    text|markdown)
      cat <<EOF
> auto-generated by \`specanchor-assemble.sh --mode=handoff\`
> 不要手写。重新生成请运行 \`specanchor_handoff\`。
> Last generated: ${timestamp} (phase: ${phase})

- Task: ${name} (status: ${status}, phase: ${phase})
- Spec Landscape: Module(${module_display})
- Active Decisions (hot, ${hot_count}): ${hot_display}
- Evidence Status: ${ev_verified} verified / ${ev_unverified_risk} unverified-risk / ${ev_failed} failed / ${ev_pending} pending
- Read next: ${module_display}
- Don't read: ${dont_read_total} entries (cold ${cold_count} / superseded ${superseded_count} / withdrawn ${withdrawn_count})
- Next step: ${next_step}
EOF
      ;;
    json)
      local modules_json hot_json
      modules_json=$(printf '%s' "$modules_csv" | awk 'BEGIN{RS=", "} NF{printf "%s\"%s\"", (n++?",":""), $0}')
      hot_json=$(printf '%s' "$hot_ids" | awk 'BEGIN{RS=", "} NF{printf "%s\"%s\"", (n++?",":""), $0}')
      cat <<EOF
{
  "generated_at": "${timestamp}",
  "task": {
    "name": "$(sa_json_escape "$name")",
    "status": "$(sa_json_escape "$status")",
    "phase": "$(sa_json_escape "$phase")"
  },
  "spec_landscape": {
    "modules": [${modules_json}]
  },
  "active_decisions_hot": [${hot_json}],
  "evidence": {
    "verified": ${ev_verified},
    "unverified_risk": ${ev_unverified_risk},
    "failed": ${ev_failed},
    "pending": ${ev_pending}
  },
  "totals": {
    "decisions_hot": ${hot_count},
    "decisions_cold": ${cold_count},
    "decisions_superseded": ${superseded_count},
    "decisions_withdrawn": ${withdrawn_count}
  },
  "next_step": "$(sa_json_escape "$next_step")"
}
EOF
      ;;
    *) sa_die "unknown handoff format: $format (use text|markdown|json)" 64 ;;
  esac
}

hp_write_back() {
  local task_spec="$1" packet="$2"
  local tmp
  tmp=$(mktemp)
  TMP_FILES+=("$tmp")
  awk '/^## 7\.2 Handoff Packet/ { print; exit } { print }' "$task_spec" > "$tmp"
  printf '\n%s\n' "$packet" >> "$tmp"
  cp "$tmp" "$task_spec"
}

handoff_mode() {
  local task_spec="$TASK_SPEC_PATH"
  [[ -n "$task_spec" ]] || sa_die "--mode=handoff requires --task-spec=<path>" 64
  [[ -f "$task_spec" ]] || sa_die "task spec not found: $task_spec" 64

  # shellcheck source=scripts/lib/decision-filter.sh
  source "$SCRIPT_DIR/lib/decision-filter.sh"
  # shellcheck source=scripts/lib/evidence-filter.sh
  source "$SCRIPT_DIR/lib/evidence-filter.sh"

  local task_name task_status task_phase
  task_name=$(sa_parse_frontmatter_field "$task_spec" "task_name")
  task_status=$(sa_parse_frontmatter_field "$task_spec" "status")
  task_phase=$(sa_read_task_phase "$task_spec")
  [[ -z "$task_phase" ]] && task_phase="?"

  local modules_csv
  modules_csv=$(hp_extract_modules_list "$task_spec" | awk 'NF{printf "%s%s", (n++?", ":""), $0} END{print ""}')

  # Decisions: hot ids + counts
  sa_resolve_decision_config "$task_spec"
  local classified_decisions
  classified_decisions=$(sa_parse_decisions "$task_spec" | sa_classify_decisions "$task_phase")
  local hot_ids="" hot_count=0 cold_count=0 superseded_count=0 withdrawn_count=0
  local row
  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    local id cat
    id=$(printf '%s' "$row" | awk -F'\037' '{print $1}')
    cat=$(printf '%s' "$row" | awk -F'\037' '{print $NF}')
    case "$cat" in
      hot)
        if [[ -z "$hot_ids" ]]; then hot_ids="$id"; else hot_ids="$hot_ids, $id"; fi
        hot_count=$((hot_count+1)) ;;
      cold) cold_count=$((cold_count+1)) ;;
      superseded) superseded_count=$((superseded_count+1)) ;;
      withdrawn) withdrawn_count=$((withdrawn_count+1)) ;;
    esac
  done <<< "$classified_decisions"

  # Evidence: status counts
  sa_resolve_evidence_config "$task_spec"
  local classified_evidence
  classified_evidence=$(sa_parse_evidence "$task_spec" | sa_classify_evidence)
  local ev_verified=0 ev_failed=0 ev_unverified_risk=0 ev_pending=0
  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    local status
    status=$(printf '%s' "$row" | awk -F'\037' '{print $4}')
    case "$status" in
      verified) ev_verified=$((ev_verified+1)) ;;
      failed) ev_failed=$((ev_failed+1)) ;;
      unverified-risk) ev_unverified_risk=$((ev_unverified_risk+1)) ;;
      pending) ev_pending=$((ev_pending+1)) ;;
    esac
  done <<< "$classified_evidence"

  local next_step
  next_step=$(hp_next_step "$task_spec")

  local packet
  packet=$(hp_render_packet "$FORMAT" "$task_name" "$task_status" "$task_phase" "$modules_csv" \
    "$hot_ids" "$hot_count" "$cold_count" "$superseded_count" "$withdrawn_count" \
    "$ev_verified" "$ev_failed" "$ev_unverified_risk" "$ev_pending" \
    "$next_step")

  printf '%s\n' "$packet"

  if [[ "$WRITE_BACK" == "true" ]]; then
    hp_write_back "$task_spec" "$packet"
    printf '\n[handoff] §7.2 written back to %s\n' "$task_spec" >&2
  fi
}

usage() {
  cat <<'EOF'
Usage:
  bash scripts/specanchor-assemble.sh --files "scripts/specanchor-boot.sh" --intent "debug startup" --budget=normal --format=json
  bash scripts/specanchor-assemble.sh --resolve-json /tmp/specanchor-resolve.json --format=markdown
  bash scripts/specanchor-assemble.sh --mode=handoff --task-spec=<path> [--format=text|markdown|json] [--write-back]

Options (v0.6 lazy-load):
  --bundle-schema=<v>   assembly.v1 (default) | context_bundle.v1 (enables finding lazy-load)
  --max-findings=<N>    cap for sediment_queue+handoff buckets (default 50, immediate uncapped)
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
      --bundle-schema=*) BUNDLE_SCHEMA="${1#--bundle-schema=}" ;;
      --bundle-schema)
        shift
        [[ $# -gt 0 ]] || sa_die "--bundle-schema requires a value" 64
        BUNDLE_SCHEMA="$1"
        ;;
      --max-findings=*) MAX_FINDINGS="${1#--max-findings=}"; MAX_FINDINGS_CLI_SET=1 ;;
      --max-findings)
        shift
        [[ $# -gt 0 ]] || sa_die "--max-findings requires a value" 64
        MAX_FINDINGS="$1"
        MAX_FINDINGS_CLI_SET=1
        ;;
      --mode=handoff) MODE="handoff" ;;
      --mode=*) sa_die "unknown mode: ${1#--mode=} (use: handoff)" 64 ;;
      --mode)
        shift
        [[ $# -gt 0 ]] || sa_die "--mode requires a value" 64
        [[ "$1" == "handoff" ]] || sa_die "unknown mode: $1 (use: handoff)" 64
        MODE="handoff"
        ;;
      --task-spec=*) TASK_SPEC_PATH="${1#--task-spec=}" ;;
      --task-spec)
        shift
        [[ $# -gt 0 ]] || sa_die "--task-spec requires a value" 64
        TASK_SPEC_PATH="$1"
        ;;
      --write-back) WRITE_BACK="true" ;;
      --help|-h) usage ;;
      *) sa_die "invalid argument: $1" 64 ;;
    esac
    shift
  done

  if [[ "$MODE" == "handoff" ]]; then
    handoff_mode
    return 0
  fi

  load_anchor_max_findings_override
  build_requested_targets

  local resolve_json
  resolve_json=$(build_resolve_json)
  parse_resolve_json "$resolve_json"

  # v0.6 lazy-load：finding discovery — 只在 schema-gated 路径上走
  if [[ "$FORMAT" == "json" && "$BUNDLE_SCHEMA" == "context_bundle.v1" ]] && \
     [[ ${#REQUESTED_TARGET_FILES[@]} -gt 0 ]]; then
    discover_findings
  fi

  recalculate_estimate
  enforce_budget_caps
  finalize_instructions

  # v0.6 lazy-load：B3 agent_instructions hint（必须在 finalize_instructions 之后追加，
  # 让 finalize 把 warning 转 instruction 的逻辑先跑完）
  if [[ ${#DISCOVERED_FINDING_PATHS[@]} -gt 0 ]]; then
    AGENT_INSTRUCTIONS+=("${#DISCOVERED_FINDING_PATHS[@]} findings are attached to your target files.")
    AGENT_INSTRUCTIONS+=("Findings with load=full MUST be read in full before editing.")
    AGENT_INSTRUCTIONS+=("For load=summary or load=title, scan the summary/type/impact/affects fields first; read full text only if relevant to your changes.")
  fi

  write_trace_if_requested

  case "$FORMAT" in
    text|markdown) print_markdown ;;
    json)
      case "$BUNDLE_SCHEMA" in
        assembly.v1) print_json ;;
        context_bundle.v1) print_json_bundle_v1 ;;
        *) sa_die "invalid bundle-schema: ${BUNDLE_SCHEMA} (use: assembly.v1 | context_bundle.v1)" 64 ;;
      esac
      ;;
    *) sa_die "invalid format: ${FORMAT}" 64 ;;
  esac
}

main "$@"
