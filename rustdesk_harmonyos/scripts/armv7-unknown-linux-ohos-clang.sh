#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/_ohos-sdk-env.sh"
exec "$LLVM_BIN/clang" -target arm-linux-ohos --sysroot="$SYSROOT" -D__MUSL__ -march=armv7-a -mfloat-abi=softfp -mtune=generic-armv7-a -mthumb "$@"
