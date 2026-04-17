#!/usr/bin/env bats

@test "main runs install.sh for --install" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../mdb.sh"'"
    git() {
      if [[ "$1" == "clone" ]]; then
        mkdir -p "$7"
        return 0
      fi
      return 1
    }
    bash() {
      printf "%s\n" "$1"
    }
    mktemp() {
      printf "/tmp/mdb-install-test\n"
    }
    rm() { :; }
    main --install
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"./install.sh"* ]]
}

@test "main runs uninstall.sh for --uninstall" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../mdb.sh"'"
    git() {
      if [[ "$1" == "clone" ]]; then
        mkdir -p "$7"
        return 0
      fi
      return 1
    }
    bash() {
      printf "%s\n" "$1"
    }
    mktemp() {
      printf "/tmp/mdb-uninstall-test\n"
    }
    rm() { :; }
    main --uninstall
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"./uninstall.sh"* ]]
}

@test "main exits with usage when flag is missing" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../mdb.sh"'"
    main
  '

  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: mdb.sh --install | --uninstall"* ]]
}

@test "main exits with usage when flag is invalid" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../mdb.sh"'"
    main --nope
  '

  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: mdb.sh --install | --uninstall"* ]]
}

@test "cleanup removes temporary directory on exit" {
  run bash -c '
    source "'"${BATS_TEST_DIRNAME}/../mdb.sh"'"
    removed_path=""
    git() {
      if [[ "$1" == "clone" ]]; then
        mkdir -p "$7"
        return 0
      fi
      return 1
    }
    bash() { :; }
    mktemp() {
      printf "/tmp/mdb-cleanup-test\n"
    }
    rm() {
      if [[ "$1" == "-rf" ]]; then
        removed_path="$2"
      fi
    }
    main --install
    printf "%s\n" "$removed_path"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"/tmp/mdb-cleanup-test"* ]]
}
