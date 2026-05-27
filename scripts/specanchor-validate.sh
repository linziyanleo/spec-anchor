#!/usr/bin/env bash
# SpecAnchor Validate - validate config, specs, and generated JSON contracts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=scripts/lib/finding-parser.sh
source "$SCRIPT_DIR/lib/finding-parser.sh"

FORMAT="text"
TARGET_PATH=""
STRICT_MODE="false"

declare -a ERRORS=()
declare -a WARNINGS=()
declare -a VALIDATED_FILES=()

add_error() {
  ERRORS+=("$1")
}

add_warning() {
  WARNINGS+=("$1")
}

valid_status_for_level() {
  local level="$1"
  local status="$2"
  case "$level" in
    task)
      case "$status" in
        draft|in_progress|review|done|archived|active) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    global|module|"")
      case "$status" in
        draft|review|active|deprecated|archived) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    *)
      return 1
      ;;
  esac
}

valid_date() {
  local value="$1"
  [[ -z "$value" ]] && return 0
  [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
}

# === Schema-aware frontmatter validation helpers ===
# schema yaml 立为 task spec frontmatter 字段集 source of truth；与 doctor.sh 同名 helper 行为对齐。
# Fallback 兼容：未声明 writing_protocol / schema 文件不存在 / schema 未声明 frontmatter_fields → 跳过校验。

parse_task_writing_protocol() {
  local task="$1"
  awk '
    BEGIN { in_fm=0; fm_count=0; in_specanchor=0 }
    /^---[[:space:]]*$/ {
      fm_count++
      if (fm_count == 1) { in_fm=1; next }
      if (fm_count == 2) { exit }
    }
    in_fm && /^specanchor:/ { in_specanchor=1; next }
    in_fm && /^[A-Za-z_-]+:/ && !/^specanchor:/ { in_specanchor=0 }
    in_fm && in_specanchor && /^[[:space:]]+writing_protocol:[[:space:]]*/ {
      sub(/^[[:space:]]+writing_protocol:[[:space:]]*/, "", $0)
      gsub(/^"|"$/, "", $0)
      gsub(/^'\''|'\''$/, "", $0)
      sub(/[[:space:]]*#.*$/, "", $0)
      sub(/[[:space:]]+$/, "", $0)
      print
      exit
    }
  ' "$task" 2>/dev/null
}

locate_schema_yaml() {
  local protocol="$1"
  [[ -z "$protocol" ]] && return 0
  local local_path=".specanchor/schemas/${protocol}/schema.yaml"
  if [[ -f "$local_path" ]]; then
    printf '%s' "$local_path"
    return 0
  fi
  local skill_path="${SKILL_ROOT}/references/schemas/${protocol}/schema.yaml"
  if [[ -f "$skill_path" ]]; then
    printf '%s' "$skill_path"
    return 0
  fi
}

# Read frontmatter_fields list from schema yaml, kind=required|optional.
# Echoes one field name per line.
parse_schema_frontmatter_fields() {
  local schema_path="$1" kind="$2"
  [[ -f "$schema_path" ]] || return 0
  awk -v target_kind="$kind" '
    /^frontmatter_fields:/ { in_ff=1; next }
    /^[A-Za-z_-]+:/ && in_ff && !/^[[:space:]]/ { in_ff=0 }
    in_ff && $0 ~ "^  "target_kind":" { in_kind=1; next }
    in_ff && $0 ~ "^  [a-z_]+:" && !($0 ~ "^  "target_kind":") { in_kind=0 }
    in_ff && in_kind && /^[[:space:]]+-[[:space:]]+/ {
      val=$0
      sub(/^[[:space:]]+-[[:space:]]+/, "", val)
      gsub(/^"|"$/, "", val)
      gsub(/^'\''|'\''$/, "", val)
      sub(/[[:space:]]*#.*$/, "", val)
      sub(/[[:space:]]+$/, "", val)
      if (val != "") print val
    }
  ' "$schema_path" 2>/dev/null
}

# Extract top-level field names directly under 'specanchor:' in the first frontmatter block.
# Top-level = exactly 2-space indent (children of specanchor:). Nested keys not extracted.
extract_frontmatter_field_names() {
  local file="$1"
  awk '
    BEGIN { in_fm=0; fm_count=0; in_specanchor=0 }
    /^---[[:space:]]*$/ {
      fm_count++
      if (fm_count == 1) { in_fm=1; next }
      if (fm_count == 2) { exit }
    }
    in_fm && /^specanchor:/ { in_specanchor=1; next }
    in_fm && /^[A-Za-z_-]+:/ && !/^specanchor:/ { in_specanchor=0; next }
    in_fm && in_specanchor && /^  [a-zA-Z_-]+:/ {
      line = $0
      sub(/^  /, "", line)
      sub(/:.*$/, "", line)
      if (line != "") print line
    }
  ' "$file" 2>/dev/null
}

# Read field_types map from schema yaml. Echoes "name=type" per line.
parse_schema_field_types() {
  local schema_path="$1"
  [[ -f "$schema_path" ]] || return 0
  awk '
    /^field_types:/ { in_ft=1; next }
    /^[A-Za-z_-]+:/ && in_ft && !/^[[:space:]]/ { in_ft=0 }
    in_ft && /^[[:space:]]+[a-zA-Z_-]+:[[:space:]]*[a-zA-Z_-]+/ {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      sub(/[[:space:]]+$/, "", line)
      idx = index(line, ":")
      if (idx > 0) {
        name = substr(line, 1, idx - 1)
        tval = substr(line, idx + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", tval)
        if (name != "" && tval != "") print name "=" tval
      }
    }
  ' "$schema_path" 2>/dev/null
}

# Extract raw yaml value (possibly multi-line) for a frontmatter field.
# Returns the value text; caller infers type via infer_yaml_value_type.
extract_frontmatter_field_value() {
  local file="$1" field="$2"
  awk -v target="$field" '
    BEGIN { in_fm=0; fm_count=0; in_specanchor=0; in_field=0 }
    /^---[[:space:]]*$/ {
      fm_count++
      if (fm_count == 1) { in_fm=1; next }
      if (fm_count == 2) { exit }
    }
    in_fm && /^specanchor:/ { in_specanchor=1; next }
    in_fm && /^[A-Za-z_-]+:/ && !/^specanchor:/ { in_specanchor=0; in_field=0; next }
    in_fm && in_specanchor && match($0, "^  "target":") {
      val = substr($0, RLENGTH+1)
      sub(/^[[:space:]]+/, "", val)
      print val
      in_field = 1
      next
    }
    in_field && /^    / { print $0; next }
    in_field && /^  [a-zA-Z_-]+:/ { in_field = 0 }
  ' "$file" 2>/dev/null
}

# Heuristically infer yaml value type. Returns: list | object | string.
infer_yaml_value_type() {
  local raw="$1"
  if [[ "$raw" == *$'\n'* ]]; then
    if printf '%s' "$raw" | grep -q '^[[:space:]]*-[[:space:]]'; then
      printf 'list'
      return
    fi
    if printf '%s' "$raw" | grep -q '^[[:space:]]\+[a-zA-Z_-]\+:'; then
      printf 'object'
      return
    fi
  fi
  if [[ "$raw" =~ ^\[.*\]$ ]]; then
    printf 'list'
    return
  fi
  if [[ "$raw" =~ ^\{.*\}$ ]]; then
    printf 'object'
    return
  fi
  printf 'string'
}

# Validate field value type against schema declaration. Adds warning on mismatch.
validate_field_type() {
  local file="$1" field="$2" declared_type="$3"
  local raw_value actual_type
  raw_value=$(extract_frontmatter_field_value "$file" "$field")
  [[ -z "$raw_value" ]] && return 0
  actual_type=$(infer_yaml_value_type "$raw_value")
  if [[ "$actual_type" != "$declared_type" ]]; then
    add_warning "${file}: FRONTMATTER_FIELD_TYPE_MISMATCH field '${field}' declared as ${declared_type}, got ${actual_type}"
  fi
}

# Validate schema yaml itself against meta-schema (hardcoded required keys + value constraints).
validate_schema_yaml() {
  local schema_path="$1"
  VALIDATED_FILES+=("$schema_path")

  local key
  for key in name version philosophy artifacts apply template; do
    if ! grep -q "^${key}:" "$schema_path" 2>/dev/null; then
      add_error "${schema_path}: SCHEMA_YAML_INVALID missing required key '${key}'"
    fi
  done

  local philosophy_value
  philosophy_value=$(grep -E '^philosophy:[[:space:]]*' "$schema_path" 2>/dev/null | head -1 | sed -E 's/^philosophy:[[:space:]]*//;s/[[:space:]]*#.*$//;s/[[:space:]]+$//;s/^["'\'']|["'\'']$//g')
  if [[ -n "$philosophy_value" ]] && [[ "$philosophy_value" != "strict" ]] && [[ "$philosophy_value" != "fluid" ]]; then
    add_error "${schema_path}: SCHEMA_YAML_INVALID philosophy must be 'strict' or 'fluid', got '${philosophy_value}'"
  fi

  local version_value
  version_value=$(grep -E '^version:[[:space:]]*' "$schema_path" 2>/dev/null | head -1 | sed -E 's/^version:[[:space:]]*//;s/[[:space:]]*#.*$//;s/[[:space:]]+$//')
  if [[ -n "$version_value" ]] && ! [[ "$version_value" =~ ^[0-9]+$ ]]; then
    add_warning "${schema_path}: SCHEMA_YAML_INCOMPLETE version should be integer, got '${version_value}'"
  fi
}

# Validate task spec frontmatter against schema yaml frontmatter_fields.
# Adds FRONTMATTER_FIELD_MISSING_REQUIRED error for missing required fields,
# FRONTMATTER_FIELD_UNKNOWN warning for unknown fields,
# FRONTMATTER_FIELD_TYPE_MISMATCH warning for declared list/object 字段值类型偏离.
validate_frontmatter_against_schema() {
  local file="$1"
  local protocol
  protocol=$(parse_task_writing_protocol "$file")
  [[ -z "$protocol" ]] && return 0

  local schema_path
  schema_path=$(locate_schema_yaml "$protocol")
  [[ -z "$schema_path" ]] && return 0

  if ! grep -q '^frontmatter_fields:' "$schema_path" 2>/dev/null; then
    return 0
  fi

  local required_fields optional_fields actual_fields
  required_fields=$(parse_schema_frontmatter_fields "$schema_path" "required")
  optional_fields=$(parse_schema_frontmatter_fields "$schema_path" "optional")
  actual_fields=$(extract_frontmatter_field_names "$file")

  local field
  while IFS= read -r field; do
    [[ -n "$field" ]] || continue
    if ! grep -qFx "$field" <<<"$actual_fields"; then
      add_error "${file}: FRONTMATTER_FIELD_MISSING_REQUIRED missing required field '${field}' (schema: ${protocol})"
    fi
  done <<<"$required_fields"

  local declared
  declared=$(printf '%s\n%s' "$required_fields" "$optional_fields")
  while IFS= read -r field; do
    [[ -n "$field" ]] || continue
    if ! grep -qFx "$field" <<<"$declared"; then
      add_warning "${file}: FRONTMATTER_FIELD_UNKNOWN unknown field '${field}' (schema: ${protocol})"
    fi
  done <<<"$actual_fields"

  if grep -q '^field_types:' "$schema_path" 2>/dev/null; then
    local field_types_map entry field_name declared_type
    field_types_map=$(parse_schema_field_types "$schema_path")
    while IFS= read -r entry; do
      [[ -n "$entry" ]] || continue
      field_name=${entry%%=*}
      declared_type=${entry#*=}
      validate_field_type "$file" "$field_name" "$declared_type"
    done <<<"$field_types_map"
  fi
}

validate_anchor_yaml() {
  local file="$1"
  VALIDATED_FILES+=("$file")
  if ! grep -q '^specanchor:' "$file" 2>/dev/null; then
    add_error "${file}: CONFIG_INVALID missing specanchor root"
    return
  fi

  local version mode
  version=$(sa_parse_yaml_field "$file" "version" "")
  mode=$(sa_parse_yaml_field "$file" "mode" "")

  if [[ -z "$version" ]]; then
    add_error "${file}: CONFIG_INVALID missing specanchor.version"
  fi
  if [[ -n "$mode" ]] && [[ "$mode" != "full" ]] && [[ "$mode" != "parasitic" ]]; then
    add_error "${file}: CONFIG_INVALID unsupported mode ${mode}"
  fi
}

validate_overlay_yaml() {
  local file="$1"
  VALIDATED_FILES+=("$file")
  if ! grep -q '^specanchor:' "$file" 2>/dev/null; then
    add_error "${file}: CONFIG_INVALID missing specanchor root"
    return
  fi

  local mode
  mode=$(sa_parse_yaml_field "$file" "mode" "")
  if [[ -n "$mode" ]] && [[ "$mode" != "full" ]] && [[ "$mode" != "parasitic" ]]; then
    add_error "${file}: CONFIG_INVALID unsupported mode ${mode}"
  fi
}

validate_spec_file() {
  local file="$1"
  VALIDATED_FILES+=("$file")

  if ! grep -q '^specanchor:' "$file" 2>/dev/null; then
    add_error "${file}: FRONTMATTER_MISSING missing specanchor frontmatter"
    return
  fi

  local level expected_level status module_path created updated last_synced allow_missing
  level=$(sa_parse_frontmatter_field "$file" "level")
  status=$(sa_parse_frontmatter_field "$file" "status")
  module_path=$(sa_parse_frontmatter_field "$file" "module_path")
  created=$(sa_parse_frontmatter_field "$file" "created")
  updated=$(sa_parse_frontmatter_field "$file" "updated")
  last_synced=$(sa_parse_frontmatter_field "$file" "last_synced")
  allow_missing=$(sa_parse_frontmatter_field "$file" "allow_missing_module_path")

  expected_level=""
  if [[ "$file" == *"/global/"* ]]; then
    expected_level="global"
  elif [[ "$file" == *"/modules/"* ]]; then
    expected_level="module"
  elif [[ "$file" == *"/tasks/"* ]] || [[ "$file" == *"/archive/"* ]]; then
    expected_level="task"
  fi

  if [[ -n "$expected_level" ]] && [[ "$level" != "$expected_level" ]]; then
    add_error "${file}: LEVEL_INVALID expected ${expected_level}, got ${level:-<empty>}"
  fi

  if [[ "$expected_level" == "module" ]]; then
    if [[ -z "$module_path" ]]; then
      add_error "${file}: MODULE_PATH_MISSING module spec 缺少 module_path"
    elif [[ ! -e "$module_path" ]] && [[ "$allow_missing" != "true" ]]; then
      add_error "${file}: MODULE_PATH_INVALID module_path ${module_path} does not exist"
    fi
  fi

  if [[ -n "$status" ]] && ! valid_status_for_level "$expected_level" "$status"; then
    add_error "${file}: STATUS_INVALID unsupported status ${status}"
  fi
  if [[ "$expected_level" == "task" ]] && [[ "$status" == "active" ]]; then
    add_warning "${file}: STATUS_LEGACY task status 'active' is deprecated; use 'in_progress'"
  fi
  if [[ "$expected_level" == "task" ]] && grep -q '^  sdd_phase:' "$file" 2>/dev/null; then
    add_warning "${file}: FRONTMATTER_SDD_PHASE deprecated; move RIPER phase to body marker"
  fi
  if ! valid_date "$created"; then
    add_error "${file}: DATE_INVALID created=${created}"
  fi
  if ! valid_date "$updated"; then
    add_error "${file}: DATE_INVALID updated=${updated}"
  fi
  if ! valid_date "$last_synced"; then
    add_error "${file}: DATE_INVALID last_synced=${last_synced}"
  fi

  if [[ "$expected_level" == "task" ]]; then
    validate_frontmatter_against_schema "$file"
  fi
}

## v0.6 新增：Findings Ledger frontmatter 校验 (references/concepts/findings-ledger.md)
##
## 报错策略（v0.6 lazy-load 加固）：summary / required-field / 枚举三类校验
## 对 status==candidate 走 fail（add_error），对 status!=candidate 走 warn
## (add_warning) — 对称二分宽容期，覆盖 accepted/rejected/superseded/archived
## 与未来新 status，避免老 finding 在迁移窗口炸 CI。
validate_finding_file() {
  local file="$1"
  VALIDATED_FILES+=("$file")
  # 跳过 template / .gitkeep
  case "$(basename "$file")" in
    finding-template.md|.gitkeep) return ;;
  esac

  if ! parse_finding_frontmatter "$file" "VF"; then
    add_error "${file}: FINDING_MISSING_FRONTMATTER"
    return
  fi

  local v_status="$VF_STATUS"
  # severity routing helper：candidate fail，其他 warn（含空 status 视作 candidate）
  _vff_report() {
    local code="$1" detail="${2:-}"
    if [[ -z "$v_status" || "$v_status" == "candidate" ]]; then
      add_error  "${file}: ${code}${detail:+ ${detail}}"
    else
      add_warning "${file}: ${code} (status=${v_status}; grace-period warn)${detail:+ ${detail}}"
    fi
  }

  # 必填字段（含 v0.6 新增 summary）
  local field val
  for field in id summary type status confidence impact visibility; do
    case "$field" in
      id)         val="$VF_ID" ;;
      summary)    val="$VF_SUMMARY" ;;
      type)       val="$VF_TYPE" ;;
      status)     val="$VF_STATUS" ;;
      confidence) val="$VF_CONFIDENCE" ;;
      impact)     val="$VF_IMPACT" ;;
      visibility) val="$VF_VISIBILITY" ;;
    esac
    [[ -n "$val" ]] || _vff_report "FINDING_MISSING_FIELD" "$field"
  done

  # summary 长度与占位校验（仅在 summary 非空时进一步检查）
  if [[ -n "$VF_SUMMARY" ]]; then
    if [[ ${#VF_SUMMARY} -gt 120 ]]; then
      _vff_report "FINDING_SUMMARY_TOO_LONG" "${#VF_SUMMARY} chars (max 120)"
    fi
    if [[ "${VF_SUMMARY:0:1}" == "<" && "${VF_SUMMARY: -1}" == ">" ]]; then
      _vff_report "FINDING_SUMMARY_PLACEHOLDER" "(starts with '<' ends with '>')"
    fi
  fi

  # 枚举校验
  case "$VF_TYPE" in fact|contradiction|stale-claim|risk|reuse-opportunity|pattern|"") ;; *) _vff_report "FINDING_INVALID_TYPE" "$VF_TYPE" ;; esac
  case "$VF_STATUS" in candidate|accepted|rejected|superseded|archived|"") ;; *) _vff_report "FINDING_INVALID_STATUS" "$VF_STATUS" ;; esac
  case "$VF_CONFIDENCE" in low|medium|high|"") ;; *) _vff_report "FINDING_INVALID_CONFIDENCE" "$VF_CONFIDENCE" ;; esac
  case "$VF_IMPACT" in low|medium|high|"") ;; *) _vff_report "FINDING_INVALID_IMPACT" "$VF_IMPACT" ;; esac
  case "$VF_VISIBILITY" in hidden|handoff|sediment_queue|immediate|"") ;; *) _vff_report "FINDING_INVALID_VISIBILITY" "$VF_VISIBILITY" ;; esac

  # accepted finding 必须有 evidence_ref（用 parser 数组判定，不再 grep）
  if [[ "$VF_STATUS" == "accepted" ]]; then
    if [[ ${#VF_EVIDENCE_REFS[@]} -eq 0 ]]; then
      add_error "${file}: FINDING_ACCEPTED_REQUIRES_EVIDENCE_REF"
    fi
  fi
}

## v0.6 新增：Sediment Proposal frontmatter 校验 (references/concepts/sediment-proposal.md)
validate_sediment_proposal_file() {
  local file="$1"
  VALIDATED_FILES+=("$file")
  case "$(basename "$file")" in
    sediment-proposal-template.md|.gitkeep) return ;;
  esac

  local frontmatter=""
  frontmatter=$(awk '/^---$/ { count++; if (count==1) { in_ff=1; next } else { in_ff=0; exit } } in_ff' "$file")
  if [[ -z "$frontmatter" ]]; then
    add_error "${file}: PROPOSAL_MISSING_FRONTMATTER"
    return
  fi

  local field val
  for field in id source_findings target operation status; do
    val=$(printf '%s\n' "$frontmatter" | awk -v k="$field" '$1==k":" { print; exit }')
    [[ -n "$val" ]] || add_error "${file}: PROPOSAL_MISSING_FIELD ${field}"
  done

  local v_op v_status
  v_op=$(printf '%s\n' "$frontmatter" | awk '$1=="operation:" { sub(/^[^:]*:[[:space:]]*/, ""); print; exit }')
  v_status=$(printf '%s\n' "$frontmatter" | awk '$1=="status:" { sub(/^[^:]*:[[:space:]]*/, ""); print; exit }')

  case "$v_op" in append|replace|supersede|deprecate|delete|merge|"") ;; *) add_error "${file}: PROPOSAL_INVALID_OPERATION ${v_op}" ;; esac
  case "$v_status" in proposed|accepted|rejected|deferred|"") ;; *) add_error "${file}: PROPOSAL_INVALID_STATUS ${v_status}" ;; esac

  # source_findings 文件必须存在
  local sf_line found_findings=0 sf_path
  while IFS= read -r sf_line; do
    sf_path=$(printf '%s' "$sf_line" | sed -E 's/^[[:space:]]*-[[:space:]]*//')
    [[ -z "$sf_path" ]] && continue
    found_findings=1
    # source_findings 通常是 finding id（F-YYYYMMDD-NNN）；如果是路径则按路径检查
    if [[ "$sf_path" == F-* ]]; then
      # 查找匹配的 finding 文件
      if ! ls .specanchor/findings/${sf_path}-*.md >/dev/null 2>&1; then
        add_warning "${file}: PROPOSAL_SOURCE_FINDING_NOT_FOUND ${sf_path}"
      fi
    elif [[ "$sf_path" == *.md ]]; then
      [[ -f "$sf_path" ]] || add_warning "${file}: PROPOSAL_SOURCE_FINDING_FILE_MISSING ${sf_path}"
    fi
  done < <(printf '%s\n' "$frontmatter" | awk '/^source_findings:/ {in_sf=1; next} /^[a-zA-Z_]+:/ {in_sf=0} in_sf')

  if [[ $found_findings -eq 0 ]]; then
    add_error "${file}: PROPOSAL_EMPTY_SOURCE_FINDINGS"
  fi

  # operation=supersede 时 supersedes 不能空
  if [[ "$v_op" == "supersede" ]]; then
    if ! printf '%s\n' "$frontmatter" | awk '/^supersedes:/ {in_sup=1; next} /^[a-zA-Z_]+:/ {in_sup=0} in_sup && /^[[:space:]]*-/' | grep -q .; then
      add_error "${file}: PROPOSAL_SUPERSEDE_REQUIRES_SUPERSEDES_LIST"
    fi
  fi
}

validate_json_shape_file() {
  local file="$1"
  VALIDATED_FILES+=("$file")

  if ! command -v python3 >/dev/null 2>&1; then
    add_warning "${file}: PYTHON3_MISSING json shape validation skipped"
    return 0
  fi

  local output
  if ! output=$(python3 - "$file" 2>&1 <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

schema = data.get("schema_version")
if schema == "specanchor.resolve.v2":
    required = ["status", "mode", "budget", "inputs", "anchors", "missing", "warnings", "trace"]
elif schema == "specanchor.assembly.v1":
    required = ["status", "budget", "files_to_read", "agent_instructions", "assembly_trace", "warnings"]
elif schema == "specanchor.context_bundle.v1":
    required = ["status", "intent", "budget", "layers", "files_to_read", "stop_triggers",
                "missing", "agent_instructions", "assembly_trace", "warnings"]
else:
    raise SystemExit(f"UNKNOWN_SCHEMA {schema!r}")

missing = [key for key in required if key not in data]
if missing:
    raise SystemExit("MISSING_KEYS " + ",".join(missing))

print(schema)
PY
  ); then
    add_error "${file}: JSON_SCHEMA_INVALID ${output}"
    return 0
  fi
}

validate_agent_docs_if_linked() {
  local linked=0
  if grep -q 'references/agents/' README.md README_ZH.md SKILL.md 2>/dev/null; then
    linked=1
  fi
  [[ "$linked" -eq 1 ]] || return 0

  local doc
  for doc in \
    references/agents/agent-contract.md \
    references/agents/claude-code.md \
    references/agents/codex.md \
    references/agents/cursor.md \
    references/agents/gemini.md; do
    if [[ ! -f "$doc" ]]; then
      add_error "${doc}: LINKED_FILE_MISSING"
    fi
  done
}

validate_generated_json_smokes() {
  local resolve_tmp assembly_tmp
  resolve_tmp=$(mktemp)
  assembly_tmp=$(mktemp)

  if bash "$SCRIPT_DIR/specanchor-resolve.sh" --files "anchor.yaml" --intent "validate json shape" --budget=normal --format=json >"$resolve_tmp" 2>/dev/null; then
    validate_json_shape_file "$resolve_tmp"
  else
    add_error "specanchor-resolve.sh: SMOKE_FAILED"
  fi

  if bash "$SCRIPT_DIR/specanchor-assemble.sh" --files "anchor.yaml" --intent "validate assembly shape" --budget=normal --format=json >"$assembly_tmp" 2>/dev/null; then
    validate_json_shape_file "$assembly_tmp"
  else
    add_error "specanchor-assemble.sh: SMOKE_FAILED"
  fi

  rm -f "$resolve_tmp" "$assembly_tmp"
}

collect_targets() {
  if [[ -n "$TARGET_PATH" ]]; then
    if [[ ! -e "$TARGET_PATH" ]]; then
      add_error "${TARGET_PATH}: PATH_MISSING"
      return
    fi
    case "$TARGET_PATH" in
      anchor.yaml|.specanchor/config.yaml) validate_anchor_yaml "$TARGET_PATH" ;;
      anchor.local.yaml) validate_overlay_yaml "$TARGET_PATH" ;;
      *.json) validate_json_shape_file "$TARGET_PATH" ;;
      .specanchor/findings/*.md) validate_finding_file "$TARGET_PATH" ;;
      .specanchor/sediment/proposals/*.md) validate_sediment_proposal_file "$TARGET_PATH" ;;
      *.md) validate_spec_file "$TARGET_PATH" ;;
      *) add_warning "${TARGET_PATH}: UNSUPPORTED_TARGET skipped" ;;
    esac
    return
  fi

  local config=""
  if config=$(sa_find_config 2>/dev/null); then
    validate_anchor_yaml "$config"
    local overlay=""
    overlay=$(sa_find_overlay_config "$config" 2>/dev/null || true)
    if [[ -n "$overlay" ]]; then
      validate_overlay_yaml "$overlay"
    fi
  else
    add_error "anchor.yaml: CONFIG_MISSING"
  fi

  local file=""
  for file in .specanchor/global/*.spec.md .specanchor/modules/*.spec.md; do
    [[ -f "$file" ]] || continue
    validate_spec_file "$file"
  done
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    validate_spec_file "$file"
  done < <(find .specanchor/tasks .specanchor/archive -name "*.spec.md" 2>/dev/null | sort)

  # v0.6 新增：findings + sediment proposals
  local fmd=""
  for fmd in .specanchor/findings/*.md; do
    [[ -f "$fmd" ]] || continue
    validate_finding_file "$fmd"
  done
  for fmd in .specanchor/sediment/proposals/*.md; do
    [[ -f "$fmd" ]] || continue
    validate_sediment_proposal_file "$fmd"
  done

  local schema_path=""
  for schema_path in "${SKILL_ROOT}"/references/schemas/*/schema.yaml; do
    [[ -f "$schema_path" ]] || continue
    validate_schema_yaml "$schema_path"
  done

  validate_agent_docs_if_linked
  validate_generated_json_smokes
}

status_value() {
  if [[ ${#ERRORS[@]} -gt 0 ]]; then
    printf 'error\n'
  elif [[ ${#WARNINGS[@]} -gt 0 ]]; then
    printf 'warning\n'
  else
    printf 'ok\n'
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

print_text() {
  echo -e "${BOLD}SpecAnchor Validate [$(status_value)]${RESET}"
  echo "  Files: ${#VALIDATED_FILES[@]}"
  if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo ""
    echo "Errors:"
    local item=""
    for item in "${ERRORS[@]}"; do
      echo "  - ${item}"
    done
  fi
  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo ""
    echo "Warnings:"
    local item=""
    for item in "${WARNINGS[@]}"; do
      echo "  - ${item}"
    done
  fi
}

print_json() {
  printf '{\n'
  printf '  "status": "%s",\n' "$(status_value)"
  printf '  "errors": '
  print_json_array ERRORS
  printf ',\n'
  printf '  "warnings": '
  print_json_array WARNINGS
  printf ',\n'
  printf '  "validated_files": '
  print_json_array VALIDATED_FILES
  printf '\n}\n'
}

usage() {
  cat <<'EOF'
Usage:
  bash scripts/specanchor-validate.sh
  bash scripts/specanchor-validate.sh --strict
  bash scripts/specanchor-validate.sh --format=json
  bash scripts/specanchor-validate.sh --format=summary
  bash scripts/specanchor-validate.sh --path .specanchor/modules/scripts.spec.md
EOF
  exit 0
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format=json) FORMAT="json" ;;
      --format=text|--format=summary) FORMAT="text" ;;
      --strict) STRICT_MODE="true" ;;
      --format)
        shift
        [[ $# -gt 0 ]] || sa_die "--format requires a value" 64
        FORMAT="$1"
        if [[ "$FORMAT" == "summary" ]]; then
          FORMAT="text"
        fi
        ;;
      --path)
        shift
        [[ $# -gt 0 ]] || sa_die "--path requires a value" 64
        TARGET_PATH="$1"
        ;;
      --path=*)
        TARGET_PATH="${1#--path=}"
        ;;
      --help|-h) usage ;;
      *) sa_die "invalid argument: $1" 64 ;;
    esac
    shift
  done

  collect_targets

  case "$FORMAT" in
    text) print_text ;;
    json) print_json ;;
    *) sa_die "invalid format: ${FORMAT}" 64 ;;
  esac

  if [[ ${#ERRORS[@]} -gt 0 ]]; then
    exit 2
  fi
  if [[ ${#WARNINGS[@]} -gt 0 ]] && [[ "$STRICT_MODE" == "true" ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
