#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_TYPE="hap"
VERSION_BUMP="incremental"
DEFAULT_CORE_URL="https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a"
CORE_URL="${RUSTDESK_CORE_URL:-$DEFAULT_CORE_URL}"
EXPECTED_CORE_SHA256="${RUSTDESK_CORE_SHA256:-}"
SIGNING_ZIP_B64="${RUSTDESK_SIGNING_ZIP_B64:-}"
ARTIFACTS_DIR=""
MIN_CORE_BYTES=52428800
SKIP_PACKAGE_VERIFY="false"
PREFLIGHT_ONLY="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-type|-ArtifactType) ARTIFACT_TYPE="$2"; shift 2 ;;
    --version-bump|-VersionBump) VERSION_BUMP="$2"; shift 2 ;;
    --artifacts-dir|-ArtifactsDir) ARTIFACTS_DIR="$2"; shift 2 ;;
    --core-url|-CoreUrl) CORE_URL="$2"; shift 2 ;;
    --core-sha256|-ExpectedCoreSha256) EXPECTED_CORE_SHA256="$2"; shift 2 ;;
    --skip-package-verify|-SkipPackageVerify) SKIP_PACKAGE_VERIFY="true"; shift ;;
    --preflight-only|-PreflightOnly) PREFLIGHT_ONLY="true"; shift ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

case "$ARTIFACT_TYPE" in hap) ;; *) echo "Invalid artifact type: $ARTIFACT_TYPE; online builds are HAP-only"; exit 1 ;; esac
case "$VERSION_BUMP" in none|incremental|full) ;; *) echo "Invalid version bump: $VERSION_BUMP"; exit 1 ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
TEMP_ROOT="${RUSTDESK_HARMONY_TEMP_ROOT:-$(cd "$PROJECT_ROOT/.." && pwd)/99_Temp}"

export CI=true
export RUSTDESK_HARMONY_TEMP_ROOT="$TEMP_ROOT"
export BUILD_CACHE_DIR="${BUILD_CACHE_DIR:-$TEMP_ROOT/harmonyos_cache}"

if [[ -z "$ARTIFACTS_DIR" ]]; then
  ARTIFACTS_DIR="$TEMP_ROOT/harmonyos_artifacts/$PROJECT_NAME"
fi

mkdir -p "$TEMP_ROOT" "$BUILD_CACHE_DIR"

echo "HarmonyOS Linux build preflight"
echo "Project: $PROJECT_ROOT"
echo "Temp root: $TEMP_ROOT"
echo "Artifact type: $ARTIFACT_TYPE"
echo "Version bump: $VERSION_BUMP"
echo "Native core URL: $CORE_URL"

need_file() {
  local path="$1"
  if [[ ! -e "$PROJECT_ROOT/$path" ]]; then
    echo "Required repository file is missing: $path"
    exit 1
  fi
}

need_file "build-profile.json5"
need_file "AppScope/app.json5"
need_file "entry/hvigorfile.ts"
need_file "entry/src/main/cpp/CMakeLists.txt"
need_file "entry/src/main/cpp/rustdesk_bridge_loader.cpp"
need_file "entry/src/main/cpp/types/librustdesk_bridge/oh-package.json5"
need_file "entry/src/main/cpp/types/librustdesk_bridge/index.d.ts"
need_file "entry/src/main/module.json5"
need_file "scripts/run_hvigor_with_sdk_patch.js"

NODE_EXE="${DEVECO_NODE_EXE:-$(command -v node || true)}"
if [[ -z "$NODE_EXE" ]]; then
  echo "node executable was not found."
  exit 1
fi

SDK_ROOT="${DEVECO_SDK_HOME:-${OHOS_HVIGOR_SDK_ROOT:-${HOS_SDK_HOME:-}}}"

if [[ -z "$SDK_ROOT" ]]; then
  SDK_ROOT="/home/runner/harmonyos-sdk"
fi

if [[ "$SDK_ROOT" == */command-line-tools ]]; then
  SDK_ROOT="$(dirname "$SDK_ROOT")"
fi

if [[ ! -d "$SDK_ROOT" ]]; then
  echo "HarmonyOS SDK root was not found: $SDK_ROOT"
  exit 1
fi

export DEVECO_SDK_HOME="$SDK_ROOT"
export OHOS_HVIGOR_SDK_ROOT="$SDK_ROOT"
export DEVECO_TOOLS_HOME="$SDK_ROOT/command-line-tools"
export PATH="$DEVECO_TOOLS_HOME/bin:$DEVECO_TOOLS_HOME/ohpm/bin:$DEVECO_TOOLS_HOME/hvigor/bin:$PATH"
SDK_LIBRARY_PATHS=(
  "$SDK_ROOT/hms/toolchains/lib"
  "$SDK_ROOT/openharmony/previewer/common/bin"
  "$SDK_ROOT/openharmony/ets/build-tools/ets-loader/bin/ark/build/bin"
  "$SDK_ROOT/openharmony/toolchains"
  "$SDK_ROOT/openharmony/toolchains/lib"
  "$SDK_ROOT/hms/native/sysroot/usr/lib/x86_64-linux-ohos"
)
for sdk_library_path in "${SDK_LIBRARY_PATHS[@]}"; do
  if [[ -d "$sdk_library_path" ]]; then
    export LD_LIBRARY_PATH="$sdk_library_path:${LD_LIBRARY_PATH:-}"
  fi
done

echo "Node: $NODE_EXE"
echo "HarmonyOS SDK root: $SDK_ROOT"
echo "DevEco tools root: $DEVECO_TOOLS_HOME"
echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}"

if [[ ! -d "$SDK_ROOT/openharmony/native" ]]; then
  echo "Warning: $SDK_ROOT/openharmony/native not found."
  echo "Current SDK content:"
  find "$SDK_ROOT" -maxdepth 5 -type d | sort || true
fi

SIGNING_ROOT="$TEMP_ROOT/rustdesk_harmonyos_signing"

if [[ -n "$SIGNING_ZIP_B64" ]]; then
  rm -rf "$SIGNING_ROOT" "$TEMP_ROOT/rustdesk_harmonyos_signing_extract"
  mkdir -p "$SIGNING_ROOT" "$TEMP_ROOT/rustdesk_harmonyos_signing_extract"

  echo "$SIGNING_ZIP_B64" | base64 -d > "$TEMP_ROOT/rustdesk_harmonyos_signing.zip"
  unzip -o -q "$TEMP_ROOT/rustdesk_harmonyos_signing.zip" -d "$TEMP_ROOT/rustdesk_harmonyos_signing_extract" 2>/dev/null || true

  SRC_ROOT="$(find "$TEMP_ROOT/rustdesk_harmonyos_signing_extract" -type f \( -name "*.p12" -o -name "*.cer" -o -name "*.p7b" \) -printf '%h\n' | sort | uniq | head -n 1 || true)"

  if [[ -z "$SRC_ROOT" ]]; then
    echo "Signing zip decoded, but no .p12/.cer/.p7b directory found."
    exit 1
  fi

  cp -a "$SRC_ROOT"/. "$SIGNING_ROOT"/
fi

if [[ -d "$SIGNING_ROOT" ]]; then
  echo "Signing material available at: $SIGNING_ROOT"

  if ! find "$SIGNING_ROOT" -name "*.p12" | grep -q .; then
    echo "Missing .p12 signing file"
    SIGNING_ROOT=""
  fi
  if ! find "$SIGNING_ROOT" -name "*.cer" | grep -q .; then
    echo "Missing .cer signing file"
    SIGNING_ROOT=""
  fi
  if ! find "$SIGNING_ROOT" -name "*.p7b" | grep -q .; then
    echo "Missing .p7b signing file"
    SIGNING_ROOT=""
  fi
fi

if [[ -d "$SIGNING_ROOT" ]] && [[ -d "$SIGNING_ROOT/material" ]]; then
  SIGNING_IN_PROJECT="$PROJECT_ROOT/signing"
  rm -rf "$SIGNING_IN_PROJECT"
  mkdir -p "$SIGNING_IN_PROJECT"
  cp -a "$SIGNING_ROOT"/. "$SIGNING_IN_PROJECT"/
  cp -a "$SIGNING_ROOT/material" "$SIGNING_IN_PROJECT/material"

  sed -i 's|../99_Temp/rustdesk_harmonyos_signing/|./signing/|g' "$PROJECT_ROOT/build-profile.json5"
  echo "Patched build-profile.json5 signing paths to ./signing/ (signed build)"
else
  echo "No valid signing material found; building unsigned HAP"
  python3 -c "
import json, re, sys
with open('$PROJECT_ROOT/build-profile.json5', 'r') as f:
    content = f.read()
content = re.sub(r'\"signingConfig\"\s*:\s*\"default\"', '\"signingConfig\": \"\"', content)
with open('$PROJECT_ROOT/build-profile.json5', 'w') as f:
    f.write(content)
print('Removed signingConfig from build-profile.json5 (unsigned build)')
"
fi

CORE_PATH="$PROJECT_ROOT/entry/src/main/libs/arm64/librustdesk_core.a"

if [[ "${RUSTDESK_CORE_SKIP_DOWNLOAD:-}" =~ ^(1|true|yes)$ ]]; then
  echo "Native core download skipped by RUSTDESK_CORE_SKIP_DOWNLOAD."
elif [[ -n "$CORE_URL" ]]; then
  DOWNLOAD_DIR="$TEMP_ROOT/librustdesk_core"
  TMP_CORE="$DOWNLOAD_DIR/librustdesk_core_$(date -u +%Y%m%d%H%M%S).a.tmp"
  echo "Downloading native core."
  echo "  URL: $CORE_URL"
  echo "  To : $TMP_CORE"
  mkdir -p "$(dirname "$CORE_PATH")"
  mkdir -p "$DOWNLOAD_DIR"
  curl -L --fail --retry 3 --retry-delay 5 -o "$TMP_CORE" "$CORE_URL"
  mv -f "$TMP_CORE" "$CORE_PATH"
fi

if [[ ! -f "$CORE_PATH" ]]; then
  echo "Native core staticlib is missing: $CORE_PATH"
  echo "Use the default latest release asset, set RUSTDESK_CORE_URL, or set RUSTDESK_CORE_SKIP_DOWNLOAD only when a valid local core exists."
  exit 1
fi

CORE_SIZE="$(stat -c%s "$CORE_PATH")"

if (( CORE_SIZE < MIN_CORE_BYTES )); then
  echo "Native core staticlib is too small: $CORE_SIZE bytes"
  exit 1
fi

CORE_SHA256="$(sha256sum "$CORE_PATH" | awk '{print toupper($1)}')"

if [[ -n "$EXPECTED_CORE_SHA256" ]]; then
  EXPECTED_UPPER="$(echo "$EXPECTED_CORE_SHA256" | tr '[:lower:]' '[:upper:]')"

  if [[ "$CORE_SHA256" != "$EXPECTED_UPPER" ]]; then
    echo "Native core SHA256 mismatch."
    echo "Expected: $EXPECTED_UPPER"
    echo "Actual:   $CORE_SHA256"
    exit 1
  fi
fi

echo "Native core: $CORE_PATH"
echo "Native core size: $CORE_SIZE"
echo "Native core sha256: $CORE_SHA256"

if [[ "$PREFLIGHT_ONLY" == "true" ]]; then
  echo "Preflight completed; build was skipped."
  exit 0
fi

if [[ "$VERSION_BUMP" == "none" ]]; then
  unset RUSTDESK_HARMONY_VERSION_BUMP || true
else
  export RUSTDESK_HARMONY_VERSION_BUMP="$VERSION_BUMP"
fi

TASKS=("assembleHap")

echo "Running Hvigor tasks: ${TASKS[*]}"

cd "$PROJECT_ROOT"

if [[ ! -d "$SDK_ROOT/command-line-tools/hvigor/bin" ]]; then
  echo "Installing hvigor via ohpm..."
  OHPM_BIN="$SDK_ROOT/command-line-tools/ohpm/bin/ohpm"
  HVIGOR_DIR="$SDK_ROOT/command-line-tools/hvigor"
  mkdir -p "$HVIGOR_DIR"
  cd "$HVIGOR_DIR"
  if [[ -f "$OHPM_BIN" ]]; then
    "$OHPM_BIN" install @ohos/hvigor@5.0.6 2>&1 || true
    "$OHPM_BIN" install @ohos/hvigor-ohos-plugin@5.0.6 2>&1 || true
  fi
  cd "$PROJECT_ROOT"
  export DEVECO_TOOLS_HOME="$SDK_ROOT/command-line-tools"
fi

"$NODE_EXE" "$PROJECT_ROOT/scripts/run_hvigor_with_sdk_patch.js" "${TASKS[@]}"

rm -rf "$ARTIFACTS_DIR"
mkdir -p "$ARTIFACTS_DIR"

mapfile -t PACKAGES < <(
  find "$PROJECT_ROOT" "$TEMP_ROOT" -type f \( -name "entry-default-signed.hap" -o -name "entry-default-unsigned.hap" \) 2>/dev/null | sort -u
)

if [[ "${#PACKAGES[@]}" -eq 0 ]]; then
  echo "No HarmonyOS package artifacts were produced."
  exit 1
fi

NEED_EXTS=("hap")

for ext in "${NEED_EXTS[@]}"; do
  FOUND="false"

  for file in "${PACKAGES[@]}"; do
    if [[ "$file" == *".$ext" ]]; then
      cp -f "$file" "$ARTIFACTS_DIR/"
      FOUND="true"
    fi
  done

  if [[ "$FOUND" != "true" ]]; then
    echo "Expected .$ext artifact was not produced."
    exit 1
  fi
done

if [[ "$SKIP_PACKAGE_VERIFY" != "true" ]]; then
  echo "Linux version currently skips native HAP verification."
fi

echo "Generated artifacts:"
find "$ARTIFACTS_DIR" -maxdepth 1 -type f -print
