#!/usr/bin/env bash
# SpecAnchor health functions — shared across index/status/resolve.
#
# Provides:
#   compute_module_health <module_path> <last_synced> <stale_days> <outdated_days> [<last_synced_sha>]
#   compute_global_health <last_synced> <stale_days> <outdated_days>
#   health_icon <status>
#   sa_health_commits_since <module_path> <last_synced_sha> <last_synced>
#
# When last_synced_sha is provided and resolves to a commit, drift is computed by
# counting commits in $sha..HEAD that touched module_path. This avoids the
# false-positive where a sync commit itself (which both updates last_synced and
# changes module code) gets counted as drift.
#
# When SHA is empty or unresolvable, falls back to date-based:
#   git log --since="${last_synced} 00:00:00" -- $module_path
#
# Caller MUST source scripts/lib/common.sh before this file (this file relies
# on sa_date_to_epoch).

if ! declare -F sa_date_to_epoch >/dev/null 2>&1; then
  echo "lib/health.sh: requires sa_date_to_epoch — source lib/common.sh first" >&2
  return 1 2>/dev/null || exit 1
fi

health_icon() {
  case "$1" in
    FRESH)    echo "🟢" ;;
    DRIFTED)  echo "🟡" ;;
    STALE)    echo "🟠" ;;
    OUTDATED) echo "🔴" ;;
    *)        echo "⚪" ;;
  esac
}

# Echoes the number of commits to count toward drift.
# args: <module_path> <last_synced_sha> <last_synced>
sa_health_commits_since() {
  local module_path="$1" sha="$2" last_synced="$3"
  local commits_since=0

  if ! git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    echo "0"
    return
  fi

  if [[ -n "$sha" ]] && git rev-parse --verify "${sha}^{commit}" &>/dev/null 2>&1; then
    commits_since=$(git rev-list --count "${sha}..HEAD" -- "$module_path" 2>/dev/null || echo 0)
  elif [[ -n "$last_synced" ]]; then
    commits_since=$(git log --oneline --since="${last_synced} 00:00:00" -- "$module_path" 2>/dev/null | wc -l | tr -d ' ')
  fi

  echo "${commits_since:-0}"
}

compute_module_health() {
  local module_path="$1" last_synced="$2" stale_days="$3" outdated_days="$4"
  local last_synced_sha="${5:-}"

  if [[ -z "$last_synced" ]] || [[ ! -e "$module_path" ]]; then
    echo "STALE"
    return
  fi

  local commits_since
  commits_since=$(sa_health_commits_since "$module_path" "$last_synced_sha" "$last_synced")

  if [[ $commits_since -eq 0 ]]; then
    echo "FRESH"
    return
  fi

  local synced_epoch now_epoch days_since
  synced_epoch=$(sa_date_to_epoch "$last_synced")
  if [[ -z "$synced_epoch" ]]; then
    echo "STALE"
    return
  fi
  now_epoch=$(date "+%s")
  days_since=$(( (now_epoch - synced_epoch) / 86400 ))

  if [[ $days_since -ge $outdated_days ]]; then
    echo "OUTDATED"
  elif [[ $days_since -ge $stale_days ]]; then
    echo "STALE"
  else
    echo "DRIFTED"
  fi
}

compute_global_health() {
  local last_synced="$1" stale_days="$2" outdated_days="$3"
  local synced_epoch now_epoch days_since

  synced_epoch=$(sa_date_to_epoch "$last_synced")
  if [[ -z "$last_synced" ]] || [[ -z "$synced_epoch" ]]; then
    echo "STALE"
    return
  fi

  now_epoch=$(date "+%s")
  days_since=$(( (now_epoch - synced_epoch) / 86400 ))
  if [[ $days_since -ge $outdated_days ]]; then
    echo "OUTDATED"
  elif [[ $days_since -ge $stale_days ]]; then
    echo "STALE"
  else
    echo "FRESH"
  fi
}
