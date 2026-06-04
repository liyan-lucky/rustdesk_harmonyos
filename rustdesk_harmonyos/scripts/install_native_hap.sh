#!/bin/sh
set -eu

TARGET_TRIPLE=${1:-aarch64-unknown-linux-ohos}
PROFILE=${2:-release}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BUILD_ROOT=${RUSTDESK_HARMONY_BUILD_DIR:-"$PROJECT_ROOT/../../99_Temp/rustdesk_harmonyos_build"}
HDC_BIN="$BUILD_ROOT/ohos-sdk/toolchains/hdc"
SIGNED_HAP="$BUILD_ROOT/hap_repack/entry-default-native-signed-openharmony.hap"
TARGET_HINT=${HDC_TARGET:-}
APP_JSON="$PROJECT_ROOT/AppScope/app.json"

read_bundle_name() {
  python3 - "$APP_JSON" <<'PY'
import json
import sys
from pathlib import Path

app_json = Path(sys.argv[1])
data = json.loads(app_json.read_text())
bundle = data.get("app", {}).get("bundleName", "").strip()
if not bundle:
    raise SystemExit("bundleName was not found in AppScope/app.json")
print(bundle)
PY
}

BUNDLE_NAME=${RUSTDESK_BUNDLE_NAME:-$(read_bundle_name)}

hdc_cmd() {
  if [ -n "$TARGET_HINT" ]; then
    "$HDC_BIN" -t "$TARGET_HINT" "$@"
  else
    "$HDC_BIN" "$@"
  fi
}

if [ ! -x "$HDC_BIN" ]; then
  echo "hdc was not found at $HDC_BIN" 1>&2
  exit 1
fi

"$SCRIPT_DIR/sign_native_hap_openharmony.sh" "$TARGET_TRIPLE" "$PROFILE"

if [ -z "$TARGET_HINT" ]; then
  AVAILABLE_TARGETS=$(hdc_cmd list targets | tr -d '\r')
  if [ -z "$AVAILABLE_TARGETS" ] || [ "$AVAILABLE_TARGETS" = "[Empty]" ]; then
    echo "No connected Harmony/OpenHarmony targets were found." 1>&2
    echo "Set HDC_TARGET=<connect key> and rerun after connecting a device." 1>&2
    exit 1
  fi
else
  echo "Using HDC target $TARGET_HINT"
fi

hdc_cmd install -r "$SIGNED_HAP"

printf 'Installed %s\n' "$SIGNED_HAP"
printf 'Bundle name: %s\n' "$BUNDLE_NAME"
