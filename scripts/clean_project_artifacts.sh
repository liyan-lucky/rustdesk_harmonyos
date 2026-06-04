#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

remove_dir_if_exists() {
  target_dir=$1
  if [ -d "$target_dir" ]; then
    rm -rf "$target_dir"
    printf 'Removed %s\n' "$target_dir"
  fi
}

remove_dir_if_exists "$PROJECT_ROOT/native_rust_core/target"
remove_dir_if_exists "$PROJECT_ROOT/entry/build"
remove_dir_if_exists "$PROJECT_ROOT/entry/.cxx"
remove_dir_if_exists "$PROJECT_ROOT/.hvigor"
remove_dir_if_exists "$PROJECT_ROOT/.hvigor_home"
remove_dir_if_exists "$PROJECT_ROOT/.appanalyzer"
remove_dir_if_exists "$PROJECT_ROOT/.local_sdk"

if [ -f "$PROJECT_ROOT/native_rust_core/cargo-check.log" ]; then
  rm -f "$PROJECT_ROOT/native_rust_core/cargo-check.log"
  printf 'Removed %s\n' "$PROJECT_ROOT/native_rust_core/cargo-check.log"
fi

printf 'Project tree cleanup completed.\n'
