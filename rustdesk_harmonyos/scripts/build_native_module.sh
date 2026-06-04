#!/bin/sh
set -eu

TARGET_TRIPLE=${1:-aarch64-unknown-linux-ohos}
PROFILE=${2:-release}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BUILD_ROOT=${RUSTDESK_HARMONY_BUILD_DIR:-"$PROJECT_ROOT/../../99_Temp/rustdesk_harmonyos_build"}
ENTRY_CPP_DIR="$PROJECT_ROOT/entry/src/main/cpp"

. "$SCRIPT_DIR/_ohos-sdk-env.sh"

case "$TARGET_TRIPLE" in
  aarch64-unknown-linux-ohos)
    OHOS_ARCH=arm64-v8a
    ;;
  armv7-unknown-linux-ohos)
    OHOS_ARCH=armeabi-v7a
    ;;
  x86_64-unknown-linux-ohos)
    OHOS_ARCH=x86_64
    ;;
  *)
    echo "Unsupported target triple: $TARGET_TRIPLE" 1>&2
    exit 1
    ;;
esac

case "$PROFILE" in
  release)
    CMAKE_BUILD_TYPE=Release
    ;;
  debug|dev)
    CMAKE_BUILD_TYPE=Debug
    ;;
  *)
    echo "Unsupported profile for native module build: $PROFILE" 1>&2
    exit 1
    ;;
esac

if [ -x "$OHOS_SDK_DIR/native/build-tools/cmake/bin/cmake" ]; then
  CMAKE_BIN="$OHOS_SDK_DIR/native/build-tools/cmake/bin/cmake"
else
  CMAKE_BIN=cmake
fi

CMAKE_BUILD_DIR="$BUILD_ROOT/cmake/entry-${TARGET_TRIPLE}-${PROFILE}"
OUTPUT_DIR="$BUILD_ROOT/native_module/${TARGET_TRIPLE}/${PROFILE}"

"$SCRIPT_DIR/build_native_bridge.sh" "$TARGET_TRIPLE" "$PROFILE"

mkdir -p "$CMAKE_BUILD_DIR"
"$CMAKE_BIN" \
  -S "$ENTRY_CPP_DIR" \
  -B "$CMAKE_BUILD_DIR" \
  -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$OHOS_SDK_DIR/native/build/cmake/ohos.toolchain.cmake" \
  -DOHOS_ARCH="$OHOS_ARCH" \
  -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" \
  -DRUSTDESK_HARMONY_BUILD_DIR="$BUILD_ROOT"

"$CMAKE_BIN" --build "$CMAKE_BUILD_DIR"

mkdir -p "$OUTPUT_DIR"
cp -f "$CMAKE_BUILD_DIR/librustdesk_bridge.so" "$OUTPUT_DIR/librustdesk_bridge.so"
printf 'Native Harmony bridge module copied to %s\n' "$OUTPUT_DIR/librustdesk_bridge.so"
