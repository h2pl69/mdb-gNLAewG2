#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/../install.sh"
}

@test "check_macos exits 0 on Darwin" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    uname() { echo "Darwin"; }
    export -f uname
    check_macos
  '
  [ "$status" -eq 0 ]
}

@test "check_macos exits 1 on Linux" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    uname() { echo "Linux"; }
    export -f uname
    check_macos
  '
  [ "$status" -eq 1 ]
}

@test "check_macos prints ERROR message on non-macOS" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    uname() { echo "Linux"; }
    export -f uname
    check_macos 2>&1 || true
  '
  [[ "$output" == *"[ERROR]"* ]]
}

@test "install_homebrew skips when brew binary already exists" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/bin"
    touch "$tmpdir/bin/brew"
    HOMEBREW_PREFIX="$tmpdir"
    install_homebrew
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"already installed"* ]]
}

@test "install_ohmyzsh skips when ~/.oh-my-zsh exists" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    OMZ_DIR="$tmpdir"
    install_ohmyzsh
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"already installed"* ]]
}

@test "install_zsh_plugins skips when all plugin dirs exist" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/zsh-completions" "$tmpdir/zsh-autosuggestions" "$tmpdir/zsh-syntax-highlighting"
    ZSH_CUSTOM_PLUGINS="$tmpdir"
    install_zsh_plugins
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"already installed"* ]]
}

@test "install_powerlevel10k skips when theme directory already exists" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    P10K_DIR="$tmpdir/themes/powerlevel10k"
    mkdir -p "$P10K_DIR"
    install_powerlevel10k
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"already installed"* ]]
}

@test "install_uv skips when uv binary already exists" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/bin"
    touch "$tmpdir/bin/uv"
    UV_BIN="$tmpdir/bin/uv"
    install_uv
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"already installed"* ]]
}

@test "install_bun skips when bun binary already exists" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/bin"
    touch "$tmpdir/bin/bun"
    BUN_BIN="$tmpdir/bin/bun"
    install_bun
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"already installed"* ]]
}

@test "install_claude_code skips when claude command exists" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    marker_file="$tmpdir/.claude/.macos-dev-bootstrap-claude-bin"
    claude_bin="$tmpdir/bin/claude"
    mkdir -p "$(dirname "$claude_bin")"
    touch "$claude_bin"

    # Override command_exists to return true for claude.
    command_exists() { [[ "$1" == "claude" ]]; }
    command() {
      if [[ "$1" == "-v" && "$2" == "claude" ]]; then
        printf "%s\n" "$claude_bin"
        return 0
      fi
      builtin command "$@"
    }

    CLAUDE_INSTALL_MARKER="$marker_file" install_claude_code
    [ -f "$marker_file" ] || exit 1
    actual=$(cat "$marker_file")
    [ "$actual" = "$claude_bin" ] || exit 1
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"already installed"* ]]
}

@test "install_claude_code writes marker with resolved claude path after successful install" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    marker_file="$tmpdir/.claude/.macos-dev-bootstrap-claude-bin"
    claude_bin="$tmpdir/bin/claude"

    command_exists() { return 1; }
    curl() { return 0; }
    command() {
      if [[ "$1" == "-v" && "$2" == "claude" ]]; then
        printf "%s\n" "$claude_bin"
        return 0
      fi
      builtin command "$@"
    }

    CLAUDE_INSTALL_MARKER="$marker_file" install_claude_code

    [ -f "$marker_file" ] || exit 1
    actual=$(cat "$marker_file")
    [ "$actual" = "$claude_bin" ] || exit 1
    echo "marker_written"
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"marker_written"* ]]
}

@test "install_claude_code errors when claude is still missing after installer runs" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    marker_file="$tmpdir/.claude/.macos-dev-bootstrap-claude-bin"

    command_exists() { return 1; }
    curl() { return 0; }
    command() {
      if [[ "$1" == "-v" && "$2" == "claude" ]]; then
        return 1
      fi
      builtin command "$@"
    }

    CLAUDE_INSTALL_MARKER="$marker_file" install_claude_code
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *"Claude Code install completed but"* ]]
}

@test "configure_claude_settings copies settings.json to destination" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    CLAUDE_SETTINGS_SRC="'"${BATS_TEST_DIRNAME}/../config/claude-settings.json"'"
    CLAUDE_SETTINGS_DEST="$tmpdir/settings.json"
    configure_claude_settings
    [ -f "$tmpdir/settings.json" ] && echo "copied"
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"copied"* ]]
}

@test "configure_powerlevel10k copies config when destination is absent" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    trap "rm -rf \"$tmpdir\"" EXIT
    src="$tmpdir/source.p10k.zsh"
    dest="$tmpdir/.p10k.zsh"
    echo "POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir)" > "$src"
    P10K_CONFIG_SRC="$src" P10K_CONFIG_DEST="$dest" configure_powerlevel10k
    [ -f "$dest" ] || exit 1
    diff "$src" "$dest" >/dev/null || exit 1
    echo "copied"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"copied"* ]]
}

@test "configure_powerlevel10k does not overwrite existing destination" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    trap "rm -rf \"$tmpdir\"" EXIT
    src="$tmpdir/source.p10k.zsh"
    dest="$tmpdir/.p10k.zsh"
    echo "new-managed-config" > "$src"
    echo "existing-user-config" > "$dest"
    P10K_CONFIG_SRC="$src" P10K_CONFIG_DEST="$dest" configure_powerlevel10k
    content=$(cat "$dest")
    [ "$content" = "existing-user-config" ] || exit 1
    echo "not_overwritten"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"not_overwritten"* ]]
}

@test "configure_powerlevel10k fails when source config is missing" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    trap "rm -rf \"$tmpdir\"" EXIT
    src="$tmpdir/repo/missing/.p10k.zsh"
    dest="$tmpdir/home/.p10k.zsh"
    mkdir -p "$(dirname "$dest")"
    P10K_CONFIG_SRC="$src" P10K_CONFIG_DEST="$dest" configure_powerlevel10k
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *"Powerlevel10k config source missing"* ]]
}

@test "setup_shell_integration writes guarded p10k source line into .zshrc managed block" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    trap "rm -rf \"$tmpdir\"" EXIT
    ZSHRC_FILE="$tmpdir/.zshrc"
    touch "$ZSHRC_FILE"
    setup_shell_integration
    grep -Fq "[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh" "$ZSHRC_FILE" && echo "guard_present"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"guard_present"* ]]
}

@test "setup_shell_integration still ensures single managed block after repeated runs" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    trap '\''rm -rf "$tmpdir"'\'' EXIT
    home="$tmpdir/home"
    mkdir -p "$home"
    HOME="$home"
    ZSHRC_FILE="$home/.zshrc"
    touch "$ZSHRC_FILE"

    setup_shell_integration
    setup_shell_integration

    begin_count=$(grep -Fc "# >>> macos-dev-bootstrap managed block >>>" "$ZSHRC_FILE")
    end_count=$(grep -Fc "# <<< macos-dev-bootstrap managed block <<<" "$ZSHRC_FILE")
    dedupe_count=$(grep -Fc "typeset -U path PATH" "$ZSHRC_FILE")

    [ "$begin_count" -eq 1 ] || exit 1
    [ "$end_count" -eq 1 ] || exit 1
    [ "$dedupe_count" -eq 1 ] || exit 1
    echo "single_managed_block_after_repeated_runs"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"single_managed_block_after_repeated_runs"* ]]
}

@test "setup_shell_integration preserves non-managed source line content" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    trap '\''rm -rf "$tmpdir"'\'' EXIT
    home="$tmpdir/home"
    mkdir -p "$home"
    HOME="$home"
    ZSHRC_FILE="$home/.zshrc"

    cfg_name_a="zshrc"
    cfg_name_b="devbootstrap"
    cfg_path=".$cfg_name_a.$cfg_name_b"
    preserved_line="[ -f ~/$cfg_path ] && source ~/$cfg_path"

    cat > "$ZSHRC_FILE" <<EOF
export PATH="\$HOME/.acme/bin:\$PATH"
$preserved_line
EOF

    setup_shell_integration

    preserved_count=$(grep -Fxc "$preserved_line" "$ZSHRC_FILE")
    [ "$preserved_count" -eq 1 ] || exit 1
    grep -Fq "export PATH=\"\$HOME/.acme/bin:\$PATH\"" "$ZSHRC_FILE" || exit 1
    echo "non_managed_source_line_preserved"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"non_managed_source_line_preserved"* ]]
}

@test "setup_shell_integration removes oh-my-zsh core config outside managed block" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    trap '\''rm -rf "$tmpdir"'\'' EXIT
    home="$tmpdir/home"
    mkdir -p "$home"
    HOME="$home"
    ZSHRC_FILE="$home/.zshrc"

    cat > "$ZSHRC_FILE" <<EOF
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source \$ZSH/oh-my-zsh.sh
# user-line
# >>> macos-dev-bootstrap managed block >>>
old-content
# <<< macos-dev-bootstrap managed block <<<
EOF

    setup_shell_integration

    begin_count=$(grep -Fc "# >>> macos-dev-bootstrap managed block >>>" "$ZSHRC_FILE")
    end_count=$(grep -Fc "# <<< macos-dev-bootstrap managed block <<<" "$ZSHRC_FILE")

    # `source $ZSH/oh-my-zsh.sh` must appear only once (inside the managed block).
    source_count=$(grep -Fc "source \$ZSH/oh-my-zsh.sh" "$ZSHRC_FILE")
    zsh_count=$(grep -Fc "export ZSH=\"\$HOME/.oh-my-zsh\"" "$ZSHRC_FILE")
    robby_count=$(grep -Fc "ZSH_THEME=\"robbyrussell\"" "$ZSHRC_FILE" || true)
    plugins_git_count=$(grep -Fc "plugins=(git)" "$ZSHRC_FILE" || true)

    [ "$begin_count" -eq 1 ] || exit 1
    [ "$end_count" -eq 1 ] || exit 1
    [ "$source_count" -eq 1 ] || exit 1
    [ "$zsh_count" -eq 1 ] || exit 1
    [ "$robby_count" -eq 0 ] || exit 1
    [ "$plugins_git_count" -eq 0 ] || exit 1
    grep -Fq "# user-line" "$ZSHRC_FILE" || exit 1

    echo "omz_core_deduped"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"omz_core_deduped"* ]]
}

@test "setup_shell_integration backs up .zshrc before first modification" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    ZSHRC_FILE="$tmpdir/.zshrc"
    echo "original content" > "$ZSHRC_FILE"
    setup_shell_integration 1
    cat "${ZSHRC_FILE}.bak"
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"original content"* ]]
}

@test "setup_shell_integration does not overwrite existing .zshrc backup" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    ZSHRC_FILE="$tmpdir/.zshrc"
    echo "current" > "$ZSHRC_FILE"
    echo "old-backup" > "${ZSHRC_FILE}.bak"
    setup_shell_integration 1
    cat "${ZSHRC_FILE}.bak"
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"old-backup"* ]]
}

@test "setup_shell_integration does not back up existing .zshrc without pre-existing flag" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    ZSHRC_FILE="$tmpdir/.zshrc"
    echo "original content" > "$ZSHRC_FILE"
    setup_shell_integration
    [ ! -f "${ZSHRC_FILE}.bak" ] && echo "no_backup_without_flag"
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"no_backup_without_flag"* ]]
}

@test "setup_shell_integration does not create .zshrc.bak when .zshrc is missing" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    trap '\''rm -rf "$tmpdir"'\'' EXIT
    home="$tmpdir/home"
    mkdir -p "$home"
    HOME="$home"
    ZSHRC_FILE="$home/.zshrc"

    [ -f "$ZSHRC_FILE" ] && exit 1

    setup_shell_integration

    [ ! -f "${ZSHRC_FILE}.bak" ] || exit 1
    echo "no_backup_when_missing"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"no_backup_when_missing"* ]]
}


@test "setup_shell_integration creates .zshrc when missing and appends managed block" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    trap '\''rm -rf "$tmpdir"'\'' EXIT
    home="$tmpdir/home"
    mkdir -p "$home"
    HOME="$home"
    ZSHRC_FILE="$home/.zshrc"
    CLAUDE_INSTALL_MARKER="$home/.claude/.macos-dev-bootstrap-claude-bin"
    setup_shell_integration
    [ -f "$ZSHRC_FILE" ] || exit 1
    grep -Fq "# >>> macos-dev-bootstrap managed block >>>" "$ZSHRC_FILE" || exit 1
    grep -Fq "# <<< macos-dev-bootstrap managed block <<<" "$ZSHRC_FILE" || exit 1
    echo "managed_block_created"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"managed_block_created"* ]]
}

@test "setup_shell_integration replaces existing managed block content instead of appending another" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    trap '\''rm -rf "$tmpdir"'\'' EXIT
    home="$tmpdir/home"
    mkdir -p "$home"
    HOME="$home"
    ZSHRC_FILE="$home/.zshrc"
    cat > "$ZSHRC_FILE" <<EOF
# user-line
# >>> macos-dev-bootstrap managed block >>>
old-content
# <<< macos-dev-bootstrap managed block <<<
EOF
    setup_shell_integration
    count_begin=$(grep -Fc "# >>> macos-dev-bootstrap managed block >>>" "$ZSHRC_FILE")
    count_end=$(grep -Fc "# <<< macos-dev-bootstrap managed block <<<" "$ZSHRC_FILE")
    grep -Fq "typeset -U path PATH" "$ZSHRC_FILE" || exit 1
    ! grep -Fq "old-content" "$ZSHRC_FILE" || exit 1
    [ "$count_begin" -eq 1 ] || exit 1
    [ "$count_end" -eq 1 ] || exit 1
    grep -Fq "# user-line" "$ZSHRC_FILE" || exit 1
    echo "block_replaced_once"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"block_replaced_once"* ]]
}

@test "setup_shell_integration prepends Claude directory when marker points to valid binary outside standard paths" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    trap '\''rm -rf "$tmpdir"'\'' EXIT
    home="$tmpdir/home"
    custom_dir="$home/custom-tools/bin"
    claude_bin="$custom_dir/claude"
    marker_file="$home/.claude/.macos-dev-bootstrap-claude-bin"
    mkdir -p "$home/.claude" "$custom_dir"
    touch "$claude_bin"

    HOME="$home"
    ZSHRC_FILE="$home/.zshrc"
    CLAUDE_INSTALL_MARKER="$marker_file"
    printf "%s\n" "$claude_bin" > "$marker_file"

    setup_shell_integration

    expected_line="export PATH='\''$custom_dir'\'':\$PATH"
    grep -Fq "$expected_line" "$ZSHRC_FILE" || exit 1
    echo "claude_path_added"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude_path_added"* ]]
}

@test "setup_shell_integration skips Claude PATH augmentation when marker is invalid" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    trap '\''rm -rf "$tmpdir"'\'' EXIT
    home="$tmpdir/home"
    marker_file="$home/.claude/.macos-dev-bootstrap-claude-bin"
    invalid_bin="$home/ghost-bin/claude"
    mkdir -p "$home/.claude"

    HOME="$home"
    ZSHRC_FILE="$home/.zshrc"
    CLAUDE_INSTALL_MARKER="$marker_file"
    printf "%s\n" "$invalid_bin" > "$marker_file"

    setup_shell_integration

    ! grep -Fq "export PATH='\''$home/ghost-bin'\'':\$PATH" "$ZSHRC_FILE" || exit 1
    echo "claude_path_skipped"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude_path_skipped"* ]]
}

@test "setup_shell_integration succeeds when Claude marker file is missing" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    trap '\''rm -rf "$tmpdir"'\'' EXIT
    home="$tmpdir/home"
    mkdir -p "$home"

    HOME="$home"
    ZSHRC_FILE="$home/.zshrc"
    CLAUDE_INSTALL_MARKER="$home/.claude/.macos-dev-bootstrap-claude-bin"

    setup_shell_integration

    ! grep -Eq "^export PATH='\''.*claude[^'\'']*'\''\\:\\$PATH$" "$ZSHRC_FILE" || exit 1
    grep -Fq "# >>> macos-dev-bootstrap managed block >>>" "$ZSHRC_FILE" || exit 1
    grep -Fq "# <<< macos-dev-bootstrap managed block <<<" "$ZSHRC_FILE" || exit 1
    echo "missing_marker_ok"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"missing_marker_ok"* ]]
}

@test "setup_shell_integration collapses duplicate managed blocks into exactly one block" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    trap '\''rm -rf "$tmpdir"'\'' EXIT
    home="$tmpdir/home"
    mkdir -p "$home"
    HOME="$home"
    ZSHRC_FILE="$home/.zshrc"

    cat > "$ZSHRC_FILE" <<EOF
# user-top
# >>> macos-dev-bootstrap managed block >>>
stale-one
# <<< macos-dev-bootstrap managed block <<<
# user-middle
# >>> macos-dev-bootstrap managed block >>>
stale-two
# <<< macos-dev-bootstrap managed block <<<
# user-bottom
EOF

    setup_shell_integration

    begin_count=$(grep -Fc "# >>> macos-dev-bootstrap managed block >>>" "$ZSHRC_FILE")
    end_count=$(grep -Fc "# <<< macos-dev-bootstrap managed block <<<" "$ZSHRC_FILE")
    stale_one_count=$(grep -Fc "stale-one" "$ZSHRC_FILE" || true)
    stale_two_count=$(grep -Fc "stale-two" "$ZSHRC_FILE" || true)

    [ "$begin_count" -eq 1 ] || exit 1
    [ "$end_count" -eq 1 ] || exit 1
    [ "$stale_one_count" -eq 0 ] || exit 1
    [ "$stale_two_count" -eq 0 ] || exit 1
    grep -Fq "# user-top" "$ZSHRC_FILE" || exit 1
    grep -Fq "# user-middle" "$ZSHRC_FILE" || exit 1
    grep -Fq "# user-bottom" "$ZSHRC_FILE" || exit 1
    echo "duplicate_collapsed"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"duplicate_collapsed"* ]]
}

@test "setup_shell_integration appends fresh block when markers are malformed and keeps user content" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../install.sh"'"
    tmpdir=$(mktemp -d)
    trap '\''rm -rf "$tmpdir"'\'' EXIT
    home="$tmpdir/home"
    mkdir -p "$home"
    HOME="$home"
    ZSHRC_FILE="$home/.zshrc"

    cat > "$ZSHRC_FILE" <<EOF
# user-top
# >>> macos-dev-bootstrap managed block >>>
broken-content
# user-bottom
EOF

    setup_shell_integration
    setup_shell_integration

    begin_count=$(grep -Fc "# >>> macos-dev-bootstrap managed block >>>" "$ZSHRC_FILE")
    end_count=$(grep -Fc "# <<< macos-dev-bootstrap managed block <<<" "$ZSHRC_FILE")
    broken_count=$(grep -Fc "broken-content" "$ZSHRC_FILE")
    user_top_count=$(grep -Fc "# user-top" "$ZSHRC_FILE")
    user_bottom_count=$(grep -Fc "# user-bottom" "$ZSHRC_FILE")
    typeset_count=$(grep -Fc "typeset -U path PATH" "$ZSHRC_FILE")

    [ "$begin_count" -eq 1 ] || exit 1
    [ "$end_count" -eq 1 ] || exit 1
    [ "$broken_count" -eq 1 ] || exit 1
    [ "$user_top_count" -eq 1 ] || exit 1
    [ "$user_bottom_count" -eq 1 ] || exit 1
    [ "$typeset_count" -eq 1 ] || exit 1
    echo "malformed_preserved_and_appended"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"malformed_preserved_and_appended"* ]]
}

