#!/bin/sh
set -eu

TARGET_TRIPLE=${1:-aarch64-unknown-linux-ohos}
PROFILE=${2:-release}

if [ "$TARGET_TRIPLE" != "aarch64-unknown-linux-ohos" ]; then
  echo "Unsupported target triple: $TARGET_TRIPLE. Current HarmonyOS package ABI is arm64-v8a only." 1>&2
  exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
NATIVE_CORE_DIR="$PROJECT_ROOT/native_rust_core"
BUILD_ROOT=${RUSTDESK_HARMONY_BUILD_DIR:-"$PROJECT_ROOT/../99_Temp/rustdesk_harmonyos_build"}
CARGO_TARGET_DIR=${CARGO_TARGET_DIR:-"$BUILD_ROOT/native_rust_core/target"}
OUTPUT_DIR="$CARGO_TARGET_DIR/harmony"

. "$SCRIPT_DIR/_ohos-sdk-env.sh"

case "$TARGET_TRIPLE" in
  aarch64-unknown-linux-ohos)
    LINKER_SCRIPT="$SCRIPT_DIR/$TARGET_TRIPLE-clang.sh"
    CXX_SCRIPT="$SCRIPT_DIR/$TARGET_TRIPLE-clang++.sh"
    BINDGEN_TARGET=aarch64-linux-ohos
    SYSROOT_INCLUDE_DIR=aarch64-linux-ohos
    ;;
  *)
    echo "Unsupported target triple: $TARGET_TRIPLE" 1>&2
    exit 1
    ;;
esac

AR_SCRIPT="$SCRIPT_DIR/ohos-llvm-ar.sh"

if [ ! -x "$HOME/.cargo/bin/cargo" ] && ! command -v cargo >/dev/null 2>&1; then
  echo "cargo was not found. Install Rust first." 1>&2
  exit 1
fi

if command -v cargo >/dev/null 2>&1; then
  CARGO_BIN=$(command -v cargo)
else
  CARGO_BIN="$HOME/.cargo/bin/cargo"
fi

if [ ! -x "$LINKER_SCRIPT" ]; then
  echo "OpenHarmony linker wrapper was not found: $LINKER_SCRIPT" 1>&2
  exit 1
fi

if [ ! -x "$AR_SCRIPT" ]; then
  echo "OpenHarmony llvm-ar wrapper was not found: $AR_SCRIPT" 1>&2
  exit 1
fi

TARGET_KEY=$(printf '%s' "$TARGET_TRIPLE" | tr '[:lower:]-' '[:upper:]_')
TARGET_KEY_CC=$(printf '%s' "$TARGET_TRIPLE" | tr '[:upper:]' '[:lower:]' | sed 's/[-.]/_/g')
VCPKG_ROOT=${VCPKG_ROOT:-"$BUILD_ROOT/vcpkg"}
VCPKG_INSTALLED_ROOT=${VCPKG_INSTALLED_ROOT:-"$VCPKG_ROOT/installed"}
COMMON_CFLAGS="--target=$BINDGEN_TARGET --sysroot=$SYSROOT -D__MUSL__ -fPIC"
BINDGEN_CLANG_ARGS=${BINDGEN_EXTRA_CLANG_ARGS:-"--target=$BINDGEN_TARGET --sysroot=$SYSROOT -I$SYSROOT/usr/include/$SYSROOT_INCLUDE_DIR -I$SYSROOT/usr/include -D__MUSL__"}

if [ ! -d "$VCPKG_INSTALLED_ROOT" ]; then
  echo "vcpkg installed root was not found: $VCPKG_INSTALLED_ROOT" 1>&2
  exit 1
fi

# Cargo target-specific linker/ar
export "CARGO_TARGET_${TARGET_KEY}_LINKER=$LINKER_SCRIPT"
export "CARGO_TARGET_${TARGET_KEY}_AR=$AR_SCRIPT"

# CC/CXX/AR for the 'cc' crate (uppercase underscore format)
export "CC_${TARGET_KEY}=$LINKER_SCRIPT"
export "CXX_${TARGET_KEY}=$CXX_SCRIPT"
export "AR_${TARGET_KEY}=$AR_SCRIPT"

# CC/CXX/AR for the 'cc' crate (lowercase underscore format)
export "CC_${TARGET_KEY_CC}=$LINKER_SCRIPT"
export "CXX_${TARGET_KEY_CC}=$CXX_SCRIPT"
export "AR_${TARGET_KEY_CC}=$AR_SCRIPT"

# CFLAGS/CXXFLAGS for the target
export "CFLAGS_${TARGET_KEY_CC}=$COMMON_CFLAGS"
export "CXXFLAGS_${TARGET_KEY_CC}=$COMMON_CFLAGS"

# LD/NM/RANLIB for the target
export "LD_${TARGET_KEY_CC}=$LLVM_BIN/ld.lld"
export "NM_${TARGET_KEY_CC}=$LLVM_BIN/llvm-nm"
export "RANLIB_${TARGET_KEY_CC}=$LLVM_BIN/llvm-ranlib"

# Bindgen
export "BINDGEN_EXTRA_CLANG_ARGS_${TARGET_KEY_CC}=$BINDGEN_CLANG_ARGS"
export BINDGEN_EXTRA_CLANG_ARGS="$BINDGEN_CLANG_ARGS"

# Generic target toolchain
export TARGET_CC="$LINKER_SCRIPT"
export TARGET_CXX="$CXX_SCRIPT"
export TARGET_AR="$AR_SCRIPT"
export LD="$LLVM_BIN/ld.lld"
export NM="$LLVM_BIN/llvm-nm"
export RANLIB="$LLVM_BIN/llvm-ranlib"

# Sodium
SODIUM_LIB_DIR=${SODIUM_LIB_DIR:-"$BUILD_ROOT/build/libsodium/$TARGET_TRIPLE/lib"}
if [ -d "$SODIUM_LIB_DIR" ]; then
  # Use target-specific sodium dir to avoid host/target conflict
  # Do NOT set global SODIUM_LIB_DIR as it breaks host build scripts
  export "SODIUM_LIB_DIR_${TARGET_KEY_CC}=$SODIUM_LIB_DIR"
fi

# Vcpkg
export VCPKG_ROOT
export VCPKG_INSTALLED_ROOT

# pkg-config cross-compilation support
export PKG_CONFIG_ALLOW_CROSS=1
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"

# RUSTFLAGS for OHOS linker
export RUSTFLAGS="-C link-arg=--target=$BINDGEN_TARGET -C link-arg=-fuse-ld=lld"

# LIBCLANG_PATH for bindgen
export LIBCLANG_PATH="$LLVM_BIN/../lib"

# PATH and target dir
export PATH="$LLVM_BIN:$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
export CARGO_TARGET_DIR

# Clean stale openssl build cache
for stale_dir in \
  "$CARGO_TARGET_DIR/release/build"/openssl-sys-* \
  "$CARGO_TARGET_DIR/$TARGET_TRIPLE/$PROFILE/build"/openssl-sys-*; do
  if [ -d "$stale_dir/out/openssl-build" ]; then
    rm -rf "$stale_dir/out/openssl-build" 2>/dev/null || true
  fi
done

mkdir -p "$CARGO_TARGET_DIR"
cd "$NATIVE_CORE_DIR"
env \
  "CC_$TARGET_TRIPLE=$LINKER_SCRIPT" \
  "CXX_$TARGET_TRIPLE=$CXX_SCRIPT" \
  "AR_$TARGET_TRIPLE=$AR_SCRIPT" \
  "$CARGO_BIN" build --profile "$PROFILE" --target "$TARGET_TRIPLE"

ARTIFACT_DIR="$CARGO_TARGET_DIR/$TARGET_TRIPLE/$PROFILE"
STATIC_LIB="$ARTIFACT_DIR/rustdesk_harmony_bridge.a"
PREFIXED_STATIC_LIB="$ARTIFACT_DIR/librustdesk_harmony_bridge.a"

if [ -f "$PREFIXED_STATIC_LIB" ]; then
  SOURCE_LIB="$PREFIXED_STATIC_LIB"
elif [ -f "$STATIC_LIB" ]; then
  SOURCE_LIB="$STATIC_LIB"
else
  echo "Native bridge build succeeded, but no static library was found in $ARTIFACT_DIR." 1>&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
cp -f "$SOURCE_LIB" "$OUTPUT_DIR/librustdesk_harmony_bridge.a"
printf 'Native bridge artifact copied to %s\n' "$OUTPUT_DIR/librustdesk_harmony_bridge.a"
