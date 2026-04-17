#!/usr/bin/env bats

# Source install.sh without executing main() — safe because of BASH_SOURCE guard.
setup() {
  source "${BATS_TEST_DIRNAME}/../install.sh"
  TMP_FILES=()
}

teardown() {
  if [ "${#TMP_FILES[@]}" -gt 0 ]; then
    rm -f "${TMP_FILES[@]}"
  fi
}

track_tmp_file() {
  TMP_FILES+=("$1")
}

@test "log_step prints [INFO] prefix to stdout" {
  run log_step "hello"
  [ "$status" -eq 0 ]
  [ "$output" = "[INFO]  hello" ]
}

@test "log_ok prints [OK] prefix to stdout" {
  run log_ok "done"
  [ "$status" -eq 0 ]
  [ "$output" = "[OK]    done" ]
}

@test "log_error prints [ERROR] prefix to stderr" {
  run log_error "bad"
  [ "$status" -eq 0 ]
  [ "$output" = "[ERROR] bad" ]
}

@test "command_exists returns 0 for ls" {
  run command_exists ls
  [ "$status" -eq 0 ]
}

@test "command_exists returns 1 for __nonexistent_cmd__" {
  run command_exists __nonexistent_cmd__
  [ "$status" -eq 1 ]
}

@test "dir_exists returns 0 for /tmp" {
  run dir_exists /tmp
  [ "$status" -eq 0 ]
}

@test "dir_exists returns 1 for /tmp/__nonexistent_dir__" {
  run dir_exists /tmp/__nonexistent_dir__
  [ "$status" -eq 1 ]
}

@test "append_if_absent appends when line is missing" {
  local tmpfile
  tmpfile=$(mktemp)
  track_tmp_file "$tmpfile"
  append_if_absent "$tmpfile" "newline"
  run grep -Fxc "newline" "$tmpfile"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "append_if_absent does not duplicate when line already present" {
  local tmpfile
  tmpfile=$(mktemp)
  track_tmp_file "$tmpfile"
  echo "newline" > "$tmpfile"
  append_if_absent "$tmpfile" "newline"
  run grep -Fxc "newline" "$tmpfile"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "append_if_absent matches exact full line only" {
  local tmpfile
  tmpfile=$(mktemp)
  track_tmp_file "$tmpfile"
  echo "prefix-newline-suffix" > "$tmpfile"
  append_if_absent "$tmpfile" "newline"
  run grep -Fxc "newline" "$tmpfile"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "backup_file copies source to dest" {
  local tmpfile
  tmpfile=$(mktemp)
  track_tmp_file "$tmpfile"
  track_tmp_file "${tmpfile}.bak"
  echo "original" > "$tmpfile"
  backup_file "$tmpfile" "${tmpfile}.bak"
  run cat "${tmpfile}.bak"
  [ "$status" -eq 0 ]
  [ "$output" = "original" ]
}

@test "backup_file does not overwrite existing backup" {
  local tmpfile
  tmpfile=$(mktemp)
  track_tmp_file "$tmpfile"
  track_tmp_file "${tmpfile}.bak"
  echo "original" > "$tmpfile"
  echo "old-backup" > "${tmpfile}.bak"
  backup_file "$tmpfile" "${tmpfile}.bak"
  run cat "${tmpfile}.bak"
  [ "$status" -eq 0 ]
  [ "$output" = "old-backup" ]
}
