#!/usr/bin/env bash

fail() {
  echo "ASSERTION FAILED: $*" >&2
  return 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  if [[ "$actual" != "$expected" ]]; then
    fail "expected [$expected], got [$actual]"
    return 1
  fi
  return 0
}

assert_ne() {
  local actual="$1"
  local unexpected="$2"
  if [[ "$actual" == "$unexpected" ]]; then
    fail "did not expect [$unexpected]"
    return 1
  fi
  return 0
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    fail "expected output to contain [$needle]"
    return 1
  fi
  return 0
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" == *"$needle"* ]]; then
    fail "did not expect output to contain [$needle]"
    return 1
  fi
  return 0
}

assert_file_exists() {
  local file="$1"
  if [[ ! -e "$file" ]]; then
    fail "expected file to exist: $file"
    return 1
  fi
  return 0
}

assert_valid_json() {
  local file="$1"
  if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP JSON validation (python3 not found): $file"
    return 0
  fi
  python3 -m json.tool "$file" >/dev/null 2>&1 || fail "invalid JSON: $file"
}
