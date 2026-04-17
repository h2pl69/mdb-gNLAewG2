#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$REPO_ROOT/mdb.sh"

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'Expected output to contain: %s\n' "$needle" >&2
    printf 'Actual output:\n%s\n' "$haystack" >&2
    return 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" == *"$needle"* ]]; then
    printf 'Did not expect output to contain: %s\n' "$needle" >&2
    printf 'Actual output:\n%s\n' "$haystack" >&2
    return 1
  fi
}

run_stdin_case() {
  local output

  set +e
  output="$(bash -s -- --bogus < "$SCRIPT_PATH" 2>&1)"
  local status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    printf 'Expected stdin execution with invalid arg to fail.\n' >&2
    printf 'Actual output:\n%s\n' "$output" >&2
    return 1
  fi

  assert_contains "$output" "Usage: mdb.sh --install | --uninstall"
  assert_not_contains "$output" "BASH_SOURCE[0]: unbound variable"
}

run_file_case() {
  local output

  set +e
  output="$(bash "$SCRIPT_PATH" --bogus 2>&1)"
  local status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    printf 'Expected file execution with invalid arg to fail.\n' >&2
    printf 'Actual output:\n%s\n' "$output" >&2
    return 1
  fi

  assert_contains "$output" "Usage: mdb.sh --install | --uninstall"
  assert_not_contains "$output" "BASH_SOURCE[0]: unbound variable"
}

run_stdin_case
run_file_case
