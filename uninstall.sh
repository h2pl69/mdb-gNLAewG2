#!/usr/bin/env bash

set -euo pipefail

# ─── Helpers (standalone copy — no dependency on install.sh) ─────────────────
log_step() { printf '[INFO]  %s\n' "$1"; }
log_ok()   { printf '[OK]    %s\n' "$1"; }
log_error(){ printf '[ERROR] %s\n' "$1" >&2; }

command_exists() { command -v "$1" &>/dev/null; }
dir_exists()     { [[ -d "$1" ]]; }

# Returns 0 when our own stdin is a terminal. Separate function so tests can override.
_is_stdin_tty() { [[ -t 0 ]]; }

# Reads one line from /dev/tty into the variable named by $1.
# Returns non-zero if /dev/tty cannot be opened for reading.
_read_from_tty() {
  local __var="$1"
  local __line=""
  if [[ ! -r /dev/tty ]]; then
    return 1
  fi
  # shellcheck disable=SC2229
  IFS= read -r __line </dev/tty || return 1
  printf -v "$__var" "%s" "$__line"
}

# Reads one line of confirmation into the variable named by $1.
# - If stdin is a TTY, reads from stdin (normal `bash uninstall.sh`).
# - Otherwise reads from /dev/tty (supports `curl | bash`).
# - If neither source is available, prints an [ERROR] and returns non-zero.
read_confirmation() {
  local __var="$1"
  local __line=""
  if _is_stdin_tty; then
    IFS= read -r __line || __line=""
    printf -v "$__var" "%s" "$__line"
    return 0
  fi
  if _read_from_tty "$__var"; then
    return 0
  fi
  log_error "No controlling terminal available to read confirmation."
  return 1
}

# ─── Constants (overridable for testing) ─────────────────────────────────────
HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-$HOME/.homebrew}"
BUN_DIR="${BUN_DIR:-$HOME/.bun}"
UV_BIN="${UV_BIN:-$HOME/.local/bin/uv}"
UVX_BIN="${UVX_BIN:-$HOME/.local/bin/uvx}"
UV_DATA="${UV_DATA:-$HOME/.local/share/uv}"
CLAUDE_SHARE_DIR="${CLAUDE_SHARE_DIR:-$HOME/.local/share/claude}"
CLAUDE_STATE_DIR="${CLAUDE_STATE_DIR:-$HOME/.local/state/claude}"
ZSHRC_FILE="${ZSHRC_FILE:-$HOME/.zshrc}"
CLAUDE_INSTALL_MARKER="${CLAUDE_INSTALL_MARKER:-$HOME/.claude/.macos-dev-bootstrap-claude-bin}"
CLAUDE_MANAGED_PATHS="${CLAUDE_MANAGED_PATHS:-$HOME/.local/bin/claude:$HOME/.claude/local/claude}"
OMZ_DIR="${OMZ_DIR:-$HOME/.oh-my-zsh}"

# ─── Removal functions ────────────────────────────────────────────────────────

remove_claude_code() {
  log_step "Removing Claude Code..."
  if ! command_exists claude; then
    log_ok "Claude Code not found, skipping."
    return 0
  fi
  local claude_bin
  claude_bin=$(command -v claude)
  local managed=0

  # Remove only binaries we can attribute to this installer:
  # either via explicit marker path or known user-local install paths.
  if [[ -f "$CLAUDE_INSTALL_MARKER" ]]; then
    local marker_path
    marker_path=$(<"$CLAUDE_INSTALL_MARKER")
    if [[ "$claude_bin" == "$marker_path" ]]; then
      managed=1
    fi
  fi

  if [[ $managed -eq 0 ]]; then
    local IFS=':'
    local managed_path
    for managed_path in $CLAUDE_MANAGED_PATHS; do
      if [[ "$claude_bin" == "$managed_path" ]]; then
        managed=1
        break
      fi
    done
  fi

  if [[ $managed -eq 0 ]]; then
    log_ok "Claude Code found at $claude_bin but not managed by this installer, skipping."
    return 0
  fi

  rm -f "$claude_bin"
  log_ok "Claude Code binary removed from $claude_bin."
}

remove_claude_data() {
  log_step "Removing Claude data..."
  local removed=0
  for path in "$HOME/.claude" "$HOME/.claude.json" "$CLAUDE_SHARE_DIR" "$CLAUDE_STATE_DIR"; do
    if [[ -e "$path" ]]; then
      rm -rf "$path"
      log_ok "Removed $path"
      removed=1
    fi
  done
  [[ $removed -eq 0 ]] && log_ok "No Claude data found, skipping."
  return 0
}

remove_bun() {
  log_step "Removing Bun..."
  if ! dir_exists "$BUN_DIR"; then
    log_ok "Bun not found ($BUN_DIR), skipping."
    return 0
  fi
  rm -rf "$BUN_DIR"
  log_ok "Bun removed."
}

remove_uv() {
  log_step "Removing uv..."
  local removed=0
  if [[ -f "$UV_BIN" ]]; then
    rm -f "$UV_BIN"
    log_ok "Removed $UV_BIN"
    removed=1
  fi
  if [[ -f "$UVX_BIN" ]]; then
    rm -f "$UVX_BIN"
    log_ok "Removed $UVX_BIN"
    removed=1
  fi
  if dir_exists "$UV_DATA"; then
    rm -rf "$UV_DATA"
    log_ok "Removed $UV_DATA"
    removed=1
  fi
  [[ $removed -eq 0 ]] && log_ok "uv not found, skipping."
  return 0
}

remove_powerlevel10k() {
  log_step "Removing Powerlevel10k..."
  local p10k_dir="${P10K_DIR:-${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k}"
  if [[ ! -d "$p10k_dir" ]]; then
    log_ok "Powerlevel10k not found at $p10k_dir, skipping."
    return 0
  fi
  rm -rf "$p10k_dir"
  log_ok "Powerlevel10k removed from $p10k_dir."
}

remove_zsh_plugins() {
  log_step "Removing zsh plugins..."
  local plugins_dir="$HOME/.oh-my-zsh/custom/plugins"
  for plugin in zsh-completions zsh-autosuggestions zsh-syntax-highlighting; do
    local plugin_dir="${plugins_dir:?}/$plugin"
    if dir_exists "$plugin_dir"; then
      rm -rf "$plugin_dir"
      log_ok "$plugin removed."
    else
      log_ok "$plugin not found, skipping."
    fi
  done
}

remove_ohmyzsh() {
  log_step "Removing Oh My Zsh..."
  if ! dir_exists "$OMZ_DIR"; then
    log_ok "Oh My Zsh not found, skipping."
    return 0
  fi
  if [[ -f "$OMZ_DIR/tools/uninstall.sh" ]]; then
    # CHSH=no prevents the uninstaller from changing the default shell.
    # Run interactively so the user can confirm; determine success by post-condition.
    local _omz_rc=0
    if _is_stdin_tty; then
      ZSH="$OMZ_DIR" CHSH=no bash "$OMZ_DIR/tools/uninstall.sh" || _omz_rc=$?
    elif [[ -r /dev/tty ]]; then
      ZSH="$OMZ_DIR" CHSH=no bash "$OMZ_DIR/tools/uninstall.sh" </dev/tty || _omz_rc=$?
    else
      log_error "No controlling terminal available to run Oh My Zsh uninstaller interactively."
      return 1
    fi
    if ! dir_exists "$OMZ_DIR"; then
      log_ok "Oh My Zsh removed."
    else
      log_step "Oh My Zsh uninstaller ran but the directory still remains (uninstall may have been canceled)."
    fi
  else
    rm -rf "$OMZ_DIR"
    log_ok "Oh My Zsh removed."
  fi
}

remove_homebrew() {
  log_step "Removing Homebrew..."
  if [[ ! -d "$HOMEBREW_PREFIX" ]]; then
    log_ok "Homebrew not found at $HOMEBREW_PREFIX, skipping."
    return 0
  fi
  # Installed via git clone → removal is simply deleting the directory
  rm -rf "$HOMEBREW_PREFIX"
  log_ok "Homebrew removed from $HOMEBREW_PREFIX."
}

restore_zshrc() {
  log_step "Restoring $ZSHRC_FILE..."
  local backup="${ZSHRC_FILE}.bak"
  if [[ -f "$backup" ]]; then
    cp "$backup" "$ZSHRC_FILE"
    rm -f "$backup"
    log_ok "Restored $ZSHRC_FILE from backup."
  elif [[ -f "$ZSHRC_FILE" ]]; then
    log_ok "No backup found for $ZSHRC_FILE; leaving current file unchanged."
  else
    log_ok "$ZSHRC_FILE not found, skipping."
  fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  local answer=""

  printf 'This will remove all components installed by install.sh. Continue? [y/N] '
  if ! read_confirmation answer; then
    exit 1
  fi

  case "$answer" in
    [yY]|[yY][eE][sS]) ;;
    *) log_step "Aborted."; exit 0 ;;
  esac

  log_step "Starting uninstall..."
  remove_claude_code
  remove_claude_data
  remove_bun
  remove_uv
  remove_powerlevel10k
  remove_zsh_plugins
  remove_ohmyzsh
  remove_homebrew
  restore_zshrc
  log_ok "Uninstall complete."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
