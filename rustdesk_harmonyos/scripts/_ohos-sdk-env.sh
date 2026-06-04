#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BUILD_ROOT=${RUSTDESK_HARMONY_BUILD_DIR:-"$PROJECT_ROOT/../../99_Temp/rustdesk_harmonyos_build"}
LOCAL_PROPERTIES="$SCRIPT_DIR/../local.properties"

windows_to_posix_path() {
  value=$1
  case "$value" in
    [A-Za-z]:\\*)
      drive=$(printf '%s' "$value" | cut -c1 | tr '[:upper:]' '[:lower:]')
      remainder=$(printf '%s' "$value" | cut -c3- | sed 's#\\#/#g')
      printf '/mnt/%s/%s\n' "$drive" "$remainder"
      ;;
    *)
      printf '%s\n' "$value"
      ;;
  esac
}

append_candidate() {
  candidate=$1
  if [ -z "$candidate" ]; then
    return
  fi
  if [ -z "${SDK_CANDIDATES:-}" ]; then
    SDK_CANDIDATES=$candidate
  else
    SDK_CANDIDATES=$SDK_CANDIDATES"
$candidate"
  fi
}

append_variants() {
  base=$1
  append_candidate "$base"
  append_candidate "$base/default/openharmony"
  append_candidate "$base/openharmony"
  append_candidate "$base/sdk/default/openharmony"
}

if [ -n "${OHOS_NDK_HOME:-}" ]; then
  append_variants "$OHOS_NDK_HOME"
fi
if [ -n "${OHOS_SDK_HOME:-}" ]; then
  append_variants "$OHOS_SDK_HOME"
fi

append_variants "$BUILD_ROOT/ohos-sdk"
append_variants "$BUILD_ROOT/.ohos-sdk"
append_variants "$BUILD_ROOT/tools/openharmony-sdk"

if [ -f "$LOCAL_PROPERTIES" ]; then
  sdk_dir=$(sed -n 's/^sdk\.dir=//p' "$LOCAL_PROPERTIES" | head -n 1 | tr -d '\r')
  if [ -n "$sdk_dir" ]; then
    append_variants "$sdk_dir"
    append_variants "$(windows_to_posix_path "$sdk_dir")"
  fi
fi

append_variants "$SCRIPT_DIR/../.ohos-sdk"
append_variants "$SCRIPT_DIR/../.tools/openharmony-sdk"
append_variants "$SCRIPT_DIR/../.tools/ohos-sdk"
append_variants "$HOME/ohos-sdk"
append_variants "$HOME/.local/share/openharmony-sdk"
append_variants "$HOME/.cache/openharmony-sdk"

FOUND_SDK_DIR=
OLD_IFS=${IFS}
IFS='
'
for candidate in ${SDK_CANDIDATES:-}; do
  if [ -d "$candidate/native/llvm/bin" ] && [ -d "$candidate/native/sysroot" ]; then
    FOUND_SDK_DIR=$candidate
    break
  fi
done
IFS=${OLD_IFS}

if [ -z "$FOUND_SDK_DIR" ]; then
  echo "OpenHarmony SDK not found. Set OHOS_NDK_HOME/OHOS_SDK_HOME or place a Linux SDK under $BUILD_ROOT/ohos-sdk." 1>&2
  exit 1
fi

LLVM_BIN="$FOUND_SDK_DIR/native/llvm/bin"
SYSROOT="$FOUND_SDK_DIR/native/sysroot"

if [ ! -x "$LLVM_BIN/clang" ]; then
  echo "OpenHarmony clang not found under $LLVM_BIN" 1>&2
  exit 1
fi

if [ ! -x "$LLVM_BIN/llvm-ar" ]; then
  echo "OpenHarmony llvm-ar not found under $LLVM_BIN" 1>&2
  exit 1
fi

if [ ! -d "$SYSROOT" ]; then
  echo "OpenHarmony sysroot not found under $SYSROOT" 1>&2
  exit 1
fi

export OHOS_SDK_DIR="$FOUND_SDK_DIR"
export LLVM_BIN
export SYSROOT
