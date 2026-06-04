#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/_ohos-sdk-env.sh"
exec "$LLVM_BIN/clang++" -target x86_64-linux-ohos --sysroot="$SYSROOT" -D__MUSL__ "$@"
