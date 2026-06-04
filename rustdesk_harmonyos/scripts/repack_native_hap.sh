#!/bin/sh
set -eu

TARGET_TRIPLE=${1:-aarch64-unknown-linux-ohos}
PROFILE=${2:-release}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BUILD_ROOT=${RUSTDESK_HARMONY_BUILD_DIR:-"$PROJECT_ROOT/../../99_Temp/rustdesk_harmonyos_build"}

. "$SCRIPT_DIR/_ohos-sdk-env.sh"

case "$TARGET_TRIPLE" in
  aarch64-unknown-linux-ohos)
    SDK_LIB_SUBDIR=aarch64-linux-ohos
    NATIVE_LIB_DIR=arm64-v8a
    ;;
  armv7-unknown-linux-ohos)
    SDK_LIB_SUBDIR=arm-linux-ohos
    NATIVE_LIB_DIR=armeabi-v7a
    ;;
  x86_64-unknown-linux-ohos)
    SDK_LIB_SUBDIR=x86_64-linux-ohos
    NATIVE_LIB_DIR=x86_64
    ;;
  *)
    echo "Unsupported target triple: $TARGET_TRIPLE" 1>&2
    exit 1
    ;;
esac

NATIVE_MODULE="$BUILD_ROOT/native_module/$TARGET_TRIPLE/$PROFILE/librustdesk_bridge.so"
CPP_SHARED_LIB="$OHOS_SDK_DIR/native/llvm/lib/$SDK_LIB_SUBDIR/libc++_shared.so"
SOURCE_HAP="$PROJECT_ROOT/entry/build/default/outputs/default/entry-default-unsigned.hap"
WORK_DIR="$BUILD_ROOT/hap_repack/work"
OUTPUT_HAP="$BUILD_ROOT/hap_repack/entry-default-native-unsigned.hap"

if ! command -v unzip >/dev/null 2>&1; then
  echo "unzip was not found." 1>&2
  exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
  echo "zip was not found." 1>&2
  exit 1
fi

if [ ! -f "$SOURCE_HAP" ]; then
  echo "Source unsigned HAP was not found: $SOURCE_HAP" 1>&2
  echo "Build the Harmony entry module once in DevEco Studio or hvigor before repacking." 1>&2
  exit 1
fi

"$SCRIPT_DIR/build_native_module.sh" "$TARGET_TRIPLE" "$PROFILE"

if [ ! -f "$NATIVE_MODULE" ]; then
  echo "Native bridge module was not found: $NATIVE_MODULE" 1>&2
  exit 1
fi

if [ ! -f "$CPP_SHARED_LIB" ]; then
  echo "libc++_shared.so was not found: $CPP_SHARED_LIB" 1>&2
  exit 1
fi

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/libs/$NATIVE_LIB_DIR"

cd "$WORK_DIR"
unzip -q "$SOURCE_HAP"
cp -f "$NATIVE_MODULE" "$WORK_DIR/libs/$NATIVE_LIB_DIR/librustdesk_bridge.so"
cp -f "$CPP_SHARED_LIB" "$WORK_DIR/libs/$NATIVE_LIB_DIR/libc++_shared.so"

mkdir -p "$(dirname "$OUTPUT_HAP")"
rm -f "$OUTPUT_HAP"
zip -qr "$OUTPUT_HAP" .
unzip -t "$OUTPUT_HAP" >/dev/null

printf 'Native-enabled unsigned HAP written to %s\n' "$OUTPUT_HAP"
