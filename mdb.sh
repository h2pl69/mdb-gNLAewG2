#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/h2pl69/mdb-gNLAewG2.git"
REPO_REF="main"

log_step() { printf '[INFO]  %s\n' "$1"; }
log_ok()   { printf '[OK]    %s\n' "$1"; }
log_error(){ printf '[ERROR] %s\n' "$1" >&2; }
cleanup()  { rm -rf "$1"; }

usage() {
  printf 'Usage: mdb.sh --install | --uninstall\n' >&2
}

check_macos() {
  if [[ "$(uname)" != "Darwin" ]]; then
    log_error "This wrapper only supports macOS."
    return 1
  fi
}

check_git() {
  if ! command -v git >/dev/null 2>&1; then
    log_error "git is required to fetch the repository."
    return 1
  fi
}

parse_target_script() {
  case "${1:-}" in
    --install) printf 'install.sh\n' ;;
    --uninstall) printf 'uninstall.sh\n' ;;
    *) usage; return 1 ;;
  esac
}

clone_repo() {
  local workdir="$1"
  git clone --depth=1 --branch "$REPO_REF" --single-branch "$REPO_URL" "$workdir/repo"
}

run_target_script() {
  local workdir="$1"
  local script_name="$2"
  shift 2 || true

  cd "$workdir/repo"
  bash "./$script_name" "$@"
}

main() {
  local target="${1:-}"
  local script_name
  script_name="$(parse_target_script "${target}")"
  shift || true

  check_macos
  check_git

  local workdir
  workdir="$(mktemp -d)"
  trap "cleanup '$workdir'" EXIT

  log_step "Cloning $REPO_URL ($REPO_REF)..."
  clone_repo "$workdir"

  log_step "Running $script_name..."
  run_target_script "$workdir" "$script_name" "$@"
  trap - EXIT
  cleanup "$workdir"
  log_ok "Done."
}

if [[ "${#BASH_SOURCE[@]}" -eq 0 || "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
