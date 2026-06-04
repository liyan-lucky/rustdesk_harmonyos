#!/bin/bash
# RustDesk HarmonyOS - Build & Install with Core
# Usage: ./install_with_core.sh [device_address]
# Example: ./install_with_core.sh 192.168.11.100:33839
#
# This script:
# 1. Copies core .so from independent output dir to libs/arm64/
# 2. Builds HAP (with core packaged in bundle libs)
# 3. Installs HAP to device
# 4. Verifies core loading
#
# To build WITHOUT core (small HAP for UI-only testing):
#   Remove libs/arm64/librustdesk_core.so before building

set -e

DEVICE="${1:-}"
CORE_OUTPUT_DIR="E:/Visual_Studio_Code/99_Temp/rustdesk_core_output"
CORE_SO="${CORE_OUTPUT_DIR}/librustdesk_core.so"
LIBS_ARM64="E:/Visual_Studio_Code/11_Rustdesk/rustdesk_harmonyos/entry/src/main/libs/arm64"
LIBS_CORE="${LIBS_ARM64}/librustdesk_core.so"
HAP_PATH="E:/Visual_Studio_Code/99_Temp/harmonyos_build/rustdesk_harmonyos/entry/build/default/outputs/default/entry-default-signed.hap"
HDC="C:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe"
BUNDLE_NAME="com.open.rundesk"
BUILD_DIR="E:/Visual_Studio_Code/99_Temp/harmonyos_build/rustdesk_harmonyos"

echo "=== RustDesk Build & Install with Core ==="

# Step 1: Copy core .so to libs/arm64/
if [ -f "$CORE_SO" ]; then
    CORE_SIZE=$(stat -c%s "$CORE_SO" 2>/dev/null || echo "0")
    echo "Core .so found: $(( CORE_SIZE / 1024 / 1024 )) MB"
    echo "Copying core to libs/arm64/..."
    cp "$CORE_SO" "$LIBS_CORE"
else
    echo "WARNING: Core .so not found at $CORE_SO"
    echo "Building HAP without core (UI-only mode)"
    rm -f "$LIBS_CORE"
fi

# Step 2: Build HAP
echo ""
echo "Building HAP..."
export DEVECO_SDK_HOME="E:/Visual_Studio_Code/99_Temp/rustdesk_harmonyos_build/deveco-sdk-fixed"
export OHOS_BASE_SDK_HOME="$DEVECO_SDK_HOME/HarmonyOS-6.0.2/openharmony"
export OHOS_SDK_HOME="$OHOS_BASE_SDK_HOME"
export OHOS_NDK_HOME="$OHOS_BASE_SDK_HOME"
export NODE_HOME="C:/Program Files/Huawei/DevEco Studio/tools/node"
export NODE_OPTIONS="--max-old-space-size=8192"

rm -rf "${BUILD_DIR}/entry/build"

cd "E:/Visual_Studio_Code/11_Rustdesk/rustdesk_harmonyos"
"$NODE_HOME/node" "C:/Program Files/Huawei/DevEco Studio/tools/hvigor/bin/hvigorw.js" \
  --mode module -p module=entry@default -p product=default -p requiredDeviceType=phone \
  assembleHap --analyze=normal --parallel --incremental --daemon --no-daemon

if [ ! -f "$HAP_PATH" ]; then
    echo "ERROR: HAP build failed"
    exit 1
fi

HAP_SIZE=$(stat -c%s "$HAP_PATH" 2>/dev/null || echo "0")
echo "HAP built: $(( HAP_SIZE / 1024 / 1024 )) MB"

# Step 3: Install to device
if [ -n "$DEVICE" ]; then
    echo ""
    echo "Connecting to $DEVICE..."
    "$HDC" tconn "$DEVICE" || { echo "ERROR: Failed to connect"; exit 1; }
    sleep 1
fi

echo "Uninstalling old version..."
"$HDC" uninstall "$BUNDLE_NAME" 2>/dev/null || true

echo "Installing HAP..."
"$HDC" install -r "$HAP_PATH"

# Step 4: Start and verify
echo ""
echo "Starting app..."
"$HDC" shell aa start -a EntryAbility -b "$BUNDLE_NAME"

sleep 3
echo ""
echo "=== Core Load Verification ==="
"$HDC" shell "hilog -x" 2>/dev/null | grep -i "RustDeskLoader\|Core verif\|coreReady\|Core loaded\|Core validat" | head -10

echo ""
echo "=== Done ==="
if [ -f "$CORE_SO" ]; then
    echo "HAP with core: $(( HAP_SIZE / 1024 / 1024 )) MB (core $(( CORE_SIZE / 1024 / 1024 )) MB included)"
else
    echo "HAP without core: $(( HAP_SIZE / 1024 / 1024 )) MB (UI-only)"
fi
