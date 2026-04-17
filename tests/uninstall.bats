#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/../uninstall.sh"
}

@test "remove_homebrew skips when HOMEBREW_PREFIX directory does not exist" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    HOMEBREW_PREFIX="/tmp/__nonexistent_homebrew_$$__"
    remove_homebrew
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping"* ]]
}

@test "remove_homebrew deletes HOMEBREW_PREFIX directory when it exists" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/bin"
    touch "$tmpdir/bin/brew"
    HOMEBREW_PREFIX="$tmpdir"
    remove_homebrew
    [ ! -d "$tmpdir" ] && echo "removed"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed"* ]]
}

@test "remove_claude_code skips and logs when claude not in PATH" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    command_exists() { return 1; }
    remove_claude_code
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping"* ]]
}

@test "remove_claude_code does not delete unmanaged claude binary" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/bin"
    claude_bin="$tmpdir/bin/claude"
    printf "#!/usr/bin/env bash\necho unmanaged\n" > "$claude_bin"
    chmod +x "$claude_bin"
    PATH="$tmpdir/bin:$PATH"
    remove_claude_code
    [ -f "$claude_bin" ] && echo "still_exists"
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"still_exists"* ]]
}

@test "remove_claude_code removes managed claude binary path" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/bin"
    claude_bin="$tmpdir/bin/claude"
    printf "#!/usr/bin/env bash\necho managed\n" > "$claude_bin"
    chmod +x "$claude_bin"
    PATH="$tmpdir/bin:$PATH"
    CLAUDE_MANAGED_PATHS="$claude_bin"
    remove_claude_code
    [ ! -f "$claude_bin" ] && echo "removed"
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed"* ]]
}

@test "remove_bun skips when BUN_DIR does not exist" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    BUN_DIR="/tmp/__nonexistent_bun_$$__"
    remove_bun
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping"* ]]
}

@test "remove_bun removes the directory when it exists" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    tmpdir=$(mktemp -d)
    BUN_DIR="$tmpdir"
    remove_bun
    [ ! -d "$tmpdir" ] && echo "removed"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed"* ]]
}

@test "remove_uv skips when neither uv binary nor data dir exists" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    UV_BIN="/tmp/__nonexistent_uv_$$__"
    UVX_BIN="/tmp/__nonexistent_uvx_$$__"
    UV_DATA="/tmp/__nonexistent_uvdata_$$__"
    remove_uv
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping"* ]]
}

@test "remove_claude_data removes CLAUDE_SHARE_DIR and CLAUDE_STATE_DIR when present" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    tmpdir=$(mktemp -d)
    CLAUDE_SHARE_DIR="$tmpdir/share/claude"
    CLAUDE_STATE_DIR="$tmpdir/state/claude"
    mkdir -p "$CLAUDE_SHARE_DIR" "$CLAUDE_STATE_DIR"
    remove_claude_data
    if [[ ! -d "$CLAUDE_SHARE_DIR" && ! -d "$CLAUDE_STATE_DIR" ]]; then
      echo "removed_both"
    fi
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed_both"* ]]
}

@test "remove_claude_data logs skip when Claude data paths are absent" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    tmpdir=$(mktemp -d)
    CLAUDE_SHARE_DIR="$tmpdir/__nonexistent_share__"
    CLAUDE_STATE_DIR="$tmpdir/__nonexistent_state__"
    HOME="$tmpdir"
    remove_claude_data
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"No Claude data found, skipping."* ]]
}

@test "remove_uv removes UVX_BIN when present" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    tmpdir=$(mktemp -d)
    UV_BIN="$tmpdir/__nonexistent_uv__"
    UVX_BIN="$tmpdir/uvx"
    UV_DATA="$tmpdir/__nonexistent_uv_data__"
    touch "$UVX_BIN"
    remove_uv
    if [[ ! -f "$UVX_BIN" ]]; then
      echo "uvx_removed"
    fi
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"uvx_removed"* ]]
}

@test "restore_zshrc restores from .bak and removes the backup" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    tmpdir=$(mktemp -d)
    ZSHRC_FILE="$tmpdir/.zshrc"
    echo "modified" > "$ZSHRC_FILE"
    echo "original" > "${ZSHRC_FILE}.bak"
    restore_zshrc
    cat "$ZSHRC_FILE"
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"original"* ]]
}

@test "restore_zshrc makes no changes when no backup exists" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    tmpdir=$(mktemp -d)
    ZSHRC_FILE="$tmpdir/.zshrc"
    printf "# other config\nexport PATH=\"\$HOME/.local/bin:\$PATH\"\n" > "$ZSHRC_FILE"
    before_contents=$(cat "$ZSHRC_FILE")
    restore_zshrc
    after_contents=$(cat "$ZSHRC_FILE")
    [[ "$before_contents" == "$after_contents" ]] && echo "unchanged"
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"unchanged"* ]]
}

@test "restore_zshrc keeps unrelated user lines intact" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    tmpdir=$(mktemp -d)
    ZSHRC_FILE="$tmpdir/.zshrc"
    printf "alias show_bootstrap=\"echo custom-shell-note\"\n" > "$ZSHRC_FILE"
    restore_zshrc
    grep -q "alias show_bootstrap" "$ZSHRC_FILE" && echo "mention_preserved"
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"mention_preserved"* ]]
}

@test "read_confirmation reads from stdin when stdin is a TTY-like fd" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    # Force the "stdin is a TTY" branch by overriding the detector.
    _is_stdin_tty() { return 0; }
    answer=""
    read_confirmation answer <<<"y"
    printf "answer=%s\n" "$answer"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"answer=y"* ]]
}

@test "read_confirmation reads from /dev/tty when stdin is not a TTY and /dev/tty is readable" {
  if [[ ! -r /dev/tty ]]; then
    skip "no /dev/tty available in this environment"
  fi
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    _is_stdin_tty() { return 1; }
    # Substitute /dev/tty reading with a controlled fd for testability.
    _read_from_tty() { local __var="$1"; printf -v "$__var" "%s" "n"; }
    answer=""
    read_confirmation answer </dev/null
    printf "answer=%s\n" "$answer"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"answer=n"* ]]
}

@test "read_confirmation exits non-zero with [ERROR] when no TTY is available" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    _is_stdin_tty() { return 1; }
    _read_from_tty() { return 1; }
    answer=""
    read_confirmation answer </dev/null
  '
  [ "$status" -ne 0 ]
  [[ "$output" == *"[ERROR]"* ]]
}

# ─── main() behaviour tests ───────────────────────────────────────────────────

@test "main no longer honors --yes / --unattended / --assume-yes / -y flags" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    # Simulate no TTY so read_confirmation falls through to /dev/tty path,
    # then make /dev/tty unreadable so it returns non-yes input.
    _is_stdin_tty() { return 1; }
    _read_from_tty() { local __var="$1"; printf -v "$__var" "%s" "N"; }
    main --yes
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"Aborted"* ]]
}

@test "main no longer honors UNINSTALL_ASSUME_YES / UNATTENDED / ASSUME_YES env vars" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    _is_stdin_tty() { return 1; }
    _read_from_tty() { local __var="$1"; printf -v "$__var" "%s" "N"; }
    UNINSTALL_ASSUME_YES=1 UNATTENDED=1 ASSUME_YES=1 main
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"Aborted"* ]]
}

@test "main exits non-zero with [ERROR] when no TTY is available" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    _is_stdin_tty() { return 1; }
    _read_from_tty() { return 1; }
    main
  '
  [ "$status" -ne 0 ]
  [[ "$output" == *"[ERROR]"* ]]
}

# ─── remove_ohmyzsh tests ─────────────────────────────────────────────────────

@test "remove_ohmyzsh skips when OMZ_DIR does not exist" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    OMZ_DIR="/tmp/__nonexistent_omz_$$__"
    remove_ohmyzsh
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping"* ]]
}

@test "remove_ohmyzsh logs success only when directory is removed by uninstaller" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/tools"
    # Fake uninstaller that removes the directory (simulates successful uninstall)
    printf "#!/usr/bin/env bash\nrm -rf \"$tmpdir\"\n" > "$tmpdir/tools/uninstall.sh"
    chmod +x "$tmpdir/tools/uninstall.sh"
    OMZ_DIR="$tmpdir"
    _is_stdin_tty() { return 0; }
    remove_ohmyzsh
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK]"* ]]
  [[ "$output" == *"Oh My Zsh removed"* ]]
}

@test "remove_ohmyzsh does not claim success when directory remains after uninstaller" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/tools"
    # Fake upstream uninstaller cancel path: prints message, exits 0, leaves dir in place.
    printf "#!/usr/bin/env bash\necho \"Uninstall cancelled\"\nexit 0\n" > "$tmpdir/tools/uninstall.sh"
    chmod +x "$tmpdir/tools/uninstall.sh"
    OMZ_DIR="$tmpdir"
    _is_stdin_tty() { return 0; }
    remove_ohmyzsh
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" != *"[OK]    Oh My Zsh removed"* ]]
  [[ "$output" == *"Uninstall cancelled"* ]]
  [[ "$output" == *"still remains"* ]]
}

@test "remove_ohmyzsh falls back to rm -rf when tools/uninstall.sh is absent" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    tmpdir=$(mktemp -d)
    # No tools/uninstall.sh — only the bare directory exists
    OMZ_DIR="$tmpdir"
    remove_ohmyzsh
    [ ! -d "$tmpdir" ] && echo "dir_removed"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"dir_removed"* ]]
  [[ "$output" == *"Oh My Zsh removed"* ]]
}

# ─── main() behaviour tests ───────────────────────────────────────────────────

@test "main proceeds and calls removers when user answers y" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    _is_stdin_tty() { return 0; }
    # Stub all removers to track invocation order.
    remove_claude_code()   { echo "called:remove_claude_code"; }
    remove_claude_data()   { echo "called:remove_claude_data"; }
    remove_bun()           { echo "called:remove_bun"; }
    remove_uv()            { echo "called:remove_uv"; }
    remove_powerlevel10k() { echo "called:remove_powerlevel10k"; }
    remove_zsh_plugins()   { echo "called:remove_zsh_plugins"; }
    remove_ohmyzsh()       { echo "called:remove_ohmyzsh"; }
    remove_homebrew()      { echo "called:remove_homebrew"; }
    restore_zshrc()        { echo "called:restore_zshrc"; }
    main <<<"y"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"called:remove_claude_code"* ]]
  [[ "$output" == *"called:remove_bun"* ]]
  [[ "$output" == *"called:remove_ohmyzsh"* ]]
  [[ "$output" == *"called:restore_zshrc"* ]]
  [[ "$output" == *"Uninstall complete."* ]]
}

# ─── restore_zshrc integration test ───────────────────────────────────────────────

@test "restore_zshrc recovers from backup even when a prior step renamed .zshrc" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../uninstall.sh"'"
    tmpdir=$(mktemp -d)
    HOME="$tmpdir"
    ZSHRC_FILE="$tmpdir/.zshrc"
    echo "live" > "$ZSHRC_FILE"
    echo "original" > "${ZSHRC_FILE}.bak"
    # Simulate what upstream OMZ may do: rename .zshrc to a timestamped path.
    mv "$ZSHRC_FILE" "${ZSHRC_FILE}.omz-uninstalled"
    restore_zshrc
    cat "$ZSHRC_FILE"
    rm -rf "$tmpdir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"original"* ]]
}
