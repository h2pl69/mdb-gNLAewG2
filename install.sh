#!/usr/bin/env bash

set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
HOMEBREW_PREFIX="$HOME/.homebrew"
CLAUDE_INSTALL_MARKER_DEFAULT="$HOME/.claude/.macos-dev-bootstrap-claude-bin"

# ─── Helper functions ─────────────────────────────────────────────────────────

log_step() { printf '[INFO]  %s\n' "$1"; }
log_ok()   { printf '[OK]    %s\n' "$1"; }
log_error(){ printf '[ERROR] %s\n' "$1" >&2; }

command_exists() { command -v "$1" &>/dev/null; }
dir_exists()     { [[ -d "$1" ]]; }

append_if_absent() {
  local file="$1"
  local line="$2"
  touch "$file"
  if ! grep -Fqx "$line" "$file"; then
    printf '%s\n' "$line" >> "$file"
  fi
}

# Backs up $1 to $2. Never overwrites an existing backup.
backup_file() {
  local src="$1"
  local dest="$2"
  if [[ -f "$src" ]] && [[ ! -f "$dest" ]]; then
    cp "$src" "$dest"
    log_ok "Backed up $src to $dest"
  fi
}

build_managed_zshrc_block() {
  local marker_file="${CLAUDE_INSTALL_MARKER:-$CLAUDE_INSTALL_MARKER_DEFAULT}"
  local claude_line=""
  local claude_path=""
  local claude_dir=""
  local escaped_claude_dir=""

  if [[ -f "$marker_file" ]]; then
    IFS= read -r claude_path < "$marker_file" || true
    if [[ -n "$claude_path" ]] && [[ -f "$claude_path" ]]; then
      claude_dir="$(dirname "$claude_path")"
      case "$claude_dir" in
        "$HOME/.bun/bin"|"$HOME/.local/bin"|"$HOME/.homebrew/bin"|"$HOME/.homebrew/sbin")
          ;;
        *)
          escaped_claude_dir="${claude_dir//\'/\'\"\'\"\'}"
          claude_line="export PATH='${escaped_claude_dir}':\$PATH"
          ;;
      esac
    elif [[ -n "$claude_path" ]]; then
      log_step "Ignoring invalid Claude marker path: $claude_path"
    fi
  fi

  cat <<EOF
# >>> macos-dev-bootstrap managed block >>>
export PATH="\$HOME/.bun/bin:\$PATH"
export PATH="\$HOME/.local/bin:\$PATH"
export PATH="\$HOME/.homebrew/bin:\$PATH"
export PATH="\$HOME/.homebrew/sbin:\$PATH"
${claude_line}
typeset -U path PATH

export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git zsh-completions zsh-autosuggestions zsh-syntax-highlighting)
source \$ZSH/oh-my-zsh.sh
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
# <<< macos-dev-bootstrap managed block <<<
EOF
}

# ─── Guards ───────────────────────────────────────────────────────────────────
check_macos() {
  if [[ "$(uname)" != "Darwin" ]]; then
    log_error "This script only supports macOS. Detected OS: $(uname)"
    return 1
  fi
}

check_xcode_clt() {
  if ! xcode-select -p &>/dev/null; then
    log_error "Xcode Command Line Tools are not installed."
    log_error "Run: xcode-select --install"
    log_error "Then re-run install.sh after installation completes."
    return 1
  fi
}

# ─── Installer functions ──────────────────────────────────────────────────────
install_homebrew() {
  log_step "Checking Homebrew..."
  if [[ -f "$HOMEBREW_PREFIX/bin/brew" ]]; then
    log_ok "Homebrew already installed, skipping."
    return 0
  fi
  log_step "Installing Homebrew to $HOMEBREW_PREFIX (no sudo)..."
  git clone --depth=1 https://github.com/Homebrew/brew "$HOMEBREW_PREFIX" || {
    log_error "Failed to clone Homebrew to $HOMEBREW_PREFIX. Check your internet connection and re-run install.sh."
    return 1
  }
  "$HOMEBREW_PREFIX/bin/brew" update --force --quiet 2>/dev/null || true
  log_ok "Homebrew installed to $HOMEBREW_PREFIX."
}

install_ohmyzsh() {
  log_step "Checking Oh My Zsh..."
  local omz_dir="${OMZ_DIR:-$HOME/.oh-my-zsh}"
  if dir_exists "$omz_dir"; then
    log_ok "Oh My Zsh already installed, skipping."
    return 0
  fi
  log_step "Installing Oh My Zsh..."
  RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || {
    log_error "Failed to install Oh My Zsh. Check your internet connection and re-run install.sh."
    return 1
  }
  log_ok "Oh My Zsh installed successfully."
}

install_zsh_plugins() {
  log_step "Checking zsh plugins..."
  local plugins_dir="${ZSH_CUSTOM_PLUGINS:-$HOME/.oh-my-zsh/custom/plugins}"
  local plugin
  for plugin in zsh-completions zsh-autosuggestions zsh-syntax-highlighting; do
    if dir_exists "$plugins_dir/$plugin"; then
      log_ok "$plugin already installed, skipping."
      continue
    fi
    log_step "Installing $plugin..."
    local repo_url
    case "$plugin" in
      zsh-completions)         repo_url="https://github.com/zsh-users/zsh-completions" ;;
      zsh-autosuggestions)     repo_url="https://github.com/zsh-users/zsh-autosuggestions" ;;
      zsh-syntax-highlighting) repo_url="https://github.com/zsh-users/zsh-syntax-highlighting" ;;
    esac
    git clone --depth=1 "$repo_url" "$plugins_dir/$plugin" || {
      log_error "Failed to install $plugin. Check your internet connection and re-run install.sh."
      return 1
    }
    log_ok "$plugin installed successfully."
  done
}

install_powerlevel10k() {
  log_step "Checking Powerlevel10k..."
  local p10k_dir="${P10K_DIR:-${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k}"
  if [[ -d "$p10k_dir" ]]; then
    log_ok "Powerlevel10k already installed, skipping."
    return 0
  fi
  log_step "Installing Powerlevel10k to $p10k_dir..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir" || {
    log_error "Failed to clone Powerlevel10k. Check your internet connection and re-run install.sh."
    return 1
  }
  log_ok "Powerlevel10k installed successfully."
}

configure_powerlevel10k() {
  log_step "Configuring Powerlevel10k prompt..."
  local src="${P10K_CONFIG_SRC:-$(dirname "$0")/config/.p10k.zsh}"
  local dest="${P10K_CONFIG_DEST:-$HOME/.p10k.zsh}"

  if [[ -f "$dest" ]]; then
    log_ok "Powerlevel10k config already exists at $dest, skipping overwrite."
    return 0
  fi

  if [[ ! -f "$src" ]]; then
    log_error "Powerlevel10k config source missing: $src"
    return 1
  fi

  cp "$src" "$dest"
  log_ok "Powerlevel10k config written to $dest"
}

install_uv() {
  log_step "Checking uv..."
  local uv_bin="${UV_BIN:-$HOME/.local/bin/uv}"
  if [[ -f "$uv_bin" ]]; then
    log_ok "uv already installed, skipping."
    return 0
  fi
  log_step "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh || {
    log_error "Failed to install uv. Check your internet connection and re-run install.sh."
    return 1
  }
  log_ok "uv installed successfully."
}

install_bun() {
  log_step "Checking Bun..."
  local bun_bin="${BUN_BIN:-$HOME/.bun/bin/bun}"
  if [[ -f "$bun_bin" ]]; then
    log_ok "Bun already installed, skipping."
    return 0
  fi
  log_step "Installing Bun..."
  curl -fsSL https://bun.sh/install | bash || {
    log_error "Failed to install Bun. Check your internet connection and re-run install.sh."
    return 1
  }
  log_ok "Bun installed successfully."
}

install_claude_code() {
  log_step "Checking Claude Code..."
  local claude_path=""
  local marker_file="${CLAUDE_INSTALL_MARKER:-$CLAUDE_INSTALL_MARKER_DEFAULT}"

  if command_exists claude; then
    claude_path="$(command -v claude || true)"
    if [[ -z "$claude_path" ]]; then
      log_error "Failed to resolve Claude Code path from command lookup."
      return 1
    fi
    mkdir -p "$(dirname "$marker_file")"
    printf '%s\n' "$claude_path" > "$marker_file"
    log_ok "Claude Code path marker written to $marker_file"
    log_ok "Claude Code already installed, skipping."
    return 0
  fi

  log_step "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash || {
    log_error "Failed to install Claude Code. Check your internet connection and re-run install.sh."
    return 1
  }
  # The installer typically drops the binary into ~/.local/bin, but this script may be running
  # with a PATH that doesn't include it yet (shell config is updated later).
  export PATH="$HOME/.local/bin:$PATH"
  claude_path="$(command -v claude || true)"
  if [[ -z "$claude_path" && -x "$HOME/.local/bin/claude" ]]; then
    claude_path="$HOME/.local/bin/claude"
  fi
  if [[ -z "$claude_path" ]]; then
    log_error "Claude Code install completed but 'claude' is still not available on PATH."
    return 1
  fi
  mkdir -p "$(dirname "$marker_file")"
  printf '%s\n' "$claude_path" > "$marker_file"
  log_ok "Claude Code path marker written to $marker_file"
  log_ok "Claude Code installed successfully."
}

configure_claude_settings() {
  log_step "Configuring Claude settings..."
  # CLAUDE_SETTINGS_SRC can be overridden in tests; default resolves relative to this script
  local src="${CLAUDE_SETTINGS_SRC:-$(dirname "$0")/config/claude-settings.json}"
  local dest="${CLAUDE_SETTINGS_DEST:-$HOME/.claude/settings.json}"
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  log_ok "Claude settings written to $dest"
}

setup_shell_integration() {
  # Important: Oh My Zsh installs before this function and may create ~/.zshrc.
  # We only want to backup when the user already had a .zshrc BEFORE Oh My Zsh ran.
  local zshrc_pre_existed="${1:-0}"
  log_step "Setting up shell integration..."
  local zshrc="${ZSHRC_FILE:-$HOME/.zshrc}"
  local begin_marker="# >>> macos-dev-bootstrap managed block >>>"
  local end_marker="# <<< macos-dev-bootstrap managed block <<<"
  local managed_block=""
  local zshrc_existed="$zshrc_pre_existed"
  local tmp_file
  local status_file
  local malformed_block="0"
  # Only create a backup when the user already had a .zshrc (before Oh My Zsh ran).
  if [[ "$zshrc_existed" == "1" ]]; then
    backup_file "$zshrc" "${zshrc}.bak"
  fi
  touch "$zshrc"
  managed_block="$(build_managed_zshrc_block)"
  tmp_file="$(mktemp)"
  status_file="$(mktemp)"
  # Use ${var:-} to avoid `set -u` failing during RETURN when trap runs out of scope.
  trap 'rm -f "${tmp_file:-}" "${status_file:-}"' RETURN
  MANAGED_BLOCK="$managed_block" \
  BEGIN_MARKER="$begin_marker" \
  END_MARKER="$end_marker" \
  python3 - "$zshrc" "$tmp_file" "$status_file" <<'PY'
import os
import re
import sys

zshrc_path = sys.argv[1]
tmp_path = sys.argv[2]
status_path = sys.argv[3]
managed_block = os.environ["MANAGED_BLOCK"].rstrip("\n")
begin_marker = os.environ["BEGIN_MARKER"]
end_marker = os.environ["END_MARKER"]

with open(zshrc_path, "r", encoding="utf-8") as f:
    lines = [line.rstrip("\n") for line in f]

result = []
in_block = False
replaced = False
malformed_block = False

for idx, line in enumerate(lines):
    if line == begin_marker:
        has_valid_end = False
        for probe in lines[idx + 1 :]:
            if probe == begin_marker:
                # Nested begin before end means this begin marker is malformed.
                break
            if probe == end_marker:
                has_valid_end = True
                break
        if not has_valid_end:
            malformed_block = True
            # Drop malformed begin marker but keep following user content.
            continue

        if not replaced:
            result.extend(managed_block.split("\n"))
            replaced = True
        in_block = True
        continue

    if in_block:
        if line == end_marker:
            in_block = False
        continue

    # Avoid duplicating oh-my-zsh core configuration outside our managed block.
    # The managed block re-sets these and performs the single `source $ZSH/oh-my-zsh.sh`.
    if re.match(r'^export ZSH=', line):
        continue
    if re.match(r'^ZSH_THEME=', line):
        continue
    if re.match(r'^plugins=\(', line):
        continue
    if line == 'source $ZSH/oh-my-zsh.sh':
        continue

    result.append(line)

if not replaced:
    if result and result[-1] != "":
        result.append("")
    result.extend(managed_block.split("\n"))

with open(tmp_path, "w", encoding="utf-8") as f:
    if result:
        f.write("\n".join(result) + "\n")

with open(status_path, "w", encoding="utf-8") as f:
    f.write("1\n" if malformed_block else "0\n")
PY
  if [[ -f "$status_file" ]]; then
    malformed_block="$(tr -d '\n' < "$status_file")"
  fi
  if [[ "$malformed_block" == "1" ]]; then
    log_step "Warning: detected malformed managed block without end marker; preserved user content and appended a fresh managed block."
  fi
  mv "$tmp_file" "$zshrc"

  log_ok "Shell integration configured."
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  log_step "Starting macOS dev bootstrap..."
  local zshrc_path="${ZSHRC_FILE:-$HOME/.zshrc}"
  local zshrc_was_present="0"
  if [[ -f "$zshrc_path" ]]; then
    zshrc_was_present="1"
  fi
  check_macos
  check_xcode_clt
  install_homebrew
  install_ohmyzsh
  install_zsh_plugins
  install_powerlevel10k
  configure_powerlevel10k
  install_uv
  install_bun
  install_claude_code
  configure_claude_settings
  setup_shell_integration "$zshrc_was_present"
  log_ok "Bootstrap complete! Restart your terminal or run: source ~/.zshrc"
}

# Guard: only call main when executed directly (not sourced for testing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
