#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BUILD_ROOT=${RUSTDESK_HARMONY_BUILD_DIR:-"$PROJECT_ROOT/../99_Temp/rustdesk_harmonyos_build"}
ARCHIVE_PATH=${1:-"$BUILD_ROOT/downloads/openharmony-sdk/ohos-sdk-windows_linux-public.tar.gz"}
OUTPUT_DIR=${2:-"$BUILD_ROOT/ohos-sdk"}
WORK_DIR=$(mktemp -d)

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

if [ ! -f "$ARCHIVE_PATH" ]; then
  echo "SDK archive not found: $ARCHIVE_PATH" 1>&2
  exit 1
fi

NATIVE_ZIP_PATH=$(tar -tf "$ARCHIVE_PATH" | grep 'ohos-sdk/linux/native-.*\.zip$' | head -n 1 || true)

if [ -z "$NATIVE_ZIP_PATH" ]; then
  echo "Could not find linux native SDK zip inside $ARCHIVE_PATH" 1>&2
  exit 1
fi

printf 'Extracting %s\n' "$NATIVE_ZIP_PATH"
tar -xf "$ARCHIVE_PATH" -C "$WORK_DIR" "$NATIVE_ZIP_PATH"

NATIVE_ZIP_FILE="$WORK_DIR/$NATIVE_ZIP_PATH"
mkdir -p "$OUTPUT_DIR"
unzip -qo "$NATIVE_ZIP_FILE" -d "$OUTPUT_DIR"

if [ ! -d "$OUTPUT_DIR/native" ]; then
  extracted_native=$(find "$OUTPUT_DIR" -maxdepth 1 -type d -name 'native*' | head -n 1 || true)
  if [ -n "$extracted_native" ] && [ "$extracted_native" != "$OUTPUT_DIR/native" ]; then
    rm -rf "$OUTPUT_DIR/native"
    mv "$extracted_native" "$OUTPUT_DIR/native"
  fi
fi

if [ ! -d "$OUTPUT_DIR/native/llvm/bin" ] || [ ! -d "$OUTPUT_DIR/native/sysroot" ]; then
  echo "Extracted SDK is missing native/llvm/bin or native/sysroot under $OUTPUT_DIR" 1>&2
  exit 1
fi

printf 'Linux native SDK extracted to %s\n' "$OUTPUT_DIR"
