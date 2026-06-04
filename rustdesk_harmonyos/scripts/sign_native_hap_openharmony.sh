#!/bin/sh
set -eu

TARGET_TRIPLE=${1:-aarch64-unknown-linux-ohos}
PROFILE=${2:-release}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BUILD_ROOT=${RUSTDESK_HARMONY_BUILD_DIR:-"$PROJECT_ROOT/../../99_Temp/rustdesk_harmonyos_build"}
TOOLCHAIN_LIB_DIR="$BUILD_ROOT/ohos-sdk/toolchains/lib"
SIGNING_DIR="$BUILD_ROOT/signing"
VERIFY_DIR="$BUILD_ROOT/hap_repack/verify"
APP_JSON="$PROJECT_ROOT/AppScope/app.json"
UNSIGNED_HAP="$BUILD_ROOT/hap_repack/entry-default-native-unsigned.hap"
SIGNED_HAP="$BUILD_ROOT/hap_repack/entry-default-native-signed-openharmony.hap"
APP_CERT_CHAIN="$SIGNING_DIR/openharmony-application-release-generated-chain.cer"
PROFILE_JSON="$SIGNING_DIR/rustdesk-release-profile-generated-cert.json"
SIGNED_PROFILE="$SIGNING_DIR/rustdesk-release-profile-generated-cert.p7b"
VERIFIED_PROFILE_JSON="$VERIFY_DIR/profile-verify.json"
VERIFIED_CERT_CHAIN="$VERIFY_DIR/app-cert-chain.cer"
VERIFIED_PROFILE_P7B="$VERIFY_DIR/app-profile.p7b"
KEYSTORE_FILE="$TOOLCHAIN_LIB_DIR/OpenHarmony.p12"
PROFILE_CERT_CHAIN="$TOOLCHAIN_LIB_DIR/OpenHarmonyProfileRelease.pem"
KEYSTORE_PASSWORD=123456
KEY_PASSWORD=123456

export KEYSTORE_FILE KEYSTORE_PASSWORD KEY_PASSWORD

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

if ! command -v keytool >/dev/null 2>&1; then
  echo "keytool was not found." 1>&2
  exit 1
fi

if [ ! -f "$KEYSTORE_FILE" ]; then
  echo "OpenHarmony test keystore was not found: $KEYSTORE_FILE" 1>&2
  exit 1
fi

"$SCRIPT_DIR/repack_native_hap.sh" "$TARGET_TRIPLE" "$PROFILE"

mkdir -p "$SIGNING_DIR"
mkdir -p "$VERIFY_DIR"

keytool -exportcert -rfc \
  -alias "openharmony application ca" \
  -keystore "$KEYSTORE_FILE" \
  -storetype PKCS12 \
  -storepass "$KEYSTORE_PASSWORD" \
  -file "$SIGNING_DIR/openharmony-application-ca.cer" >/dev/null 2>&1

keytool -exportcert -rfc \
  -alias "openharmony application root ca" \
  -keystore "$KEYSTORE_FILE" \
  -storetype PKCS12 \
  -storepass "$KEYSTORE_PASSWORD" \
  -file "$SIGNING_DIR/openharmony-application-root-ca.cer" >/dev/null 2>&1

java -jar "$TOOLCHAIN_LIB_DIR/hap-sign-tool.jar" generate-app-cert \
  -keyAlias "openharmony application release" \
  -keyPwd "$KEY_PASSWORD" \
  -issuer "C=CN,O=OpenHarmony,OU=OpenHarmony Team,CN=OpenHarmony Application CA" \
  -issuerKeyAlias "openharmony application ca" \
  -issuerKeyPwd "$KEY_PASSWORD" \
  -subject "C=CN,O=OpenHarmony,OU=OpenHarmony Team,CN=OpenHarmony Application Release" \
  -validity 3650 \
  -signAlg SHA256withECDSA \
  -rootCaCertFile "$SIGNING_DIR/openharmony-application-root-ca.cer" \
  -subCaCertFile "$SIGNING_DIR/openharmony-application-ca.cer" \
  -keystoreFile "$KEYSTORE_FILE" \
  -keystorePwd "$KEYSTORE_PASSWORD" \
  -outForm certChain \
  -outFile "$APP_CERT_CHAIN" >/dev/null

python3 - "$TOOLCHAIN_LIB_DIR/UnsgnedReleasedProfileTemplate.json" "$APP_CERT_CHAIN" "$PROFILE_JSON" "$BUNDLE_NAME" <<'PY'
import json
import sys
import time
import uuid
from pathlib import Path

template_path = Path(sys.argv[1])
chain_path = Path(sys.argv[2])
output_path = Path(sys.argv[3])

template = json.loads(template_path.read_text())
chain = chain_path.read_text()

certs = []
current = []
for line in chain.splitlines(True):
    current.append(line)
    if 'END CERTIFICATE' in line:
        certs.append(''.join(current))
        current = []

if not certs:
    raise SystemExit('No certificates were found in the generated app cert chain.')

now = int(time.time())
template['uuid'] = str(uuid.uuid4())
template['validity'] = {
    'not-before': now - 3600,
    'not-after': now + 3600 * 24 * 365 * 10,
}
template['bundle-info']['bundle-name'] = sys.argv[4]
template['bundle-info']['distribution-certificate'] = certs[0]

output_path.write_text(json.dumps(template, indent=2))
PY

java -jar "$TOOLCHAIN_LIB_DIR/hap-sign-tool.jar" sign-profile \
  -mode localSign \
  -keyAlias "openharmony application profile release" \
  -keyPwd "$KEY_PASSWORD" \
  -profileCertFile "$PROFILE_CERT_CHAIN" \
  -inFile "$PROFILE_JSON" \
  -signAlg SHA256withECDSA \
  -keystoreFile "$KEYSTORE_FILE" \
  -keystorePwd "$KEYSTORE_PASSWORD" \
  -outFile "$SIGNED_PROFILE" >/dev/null

java -jar "$TOOLCHAIN_LIB_DIR/hap-sign-tool.jar" verify-profile \
  -inFile "$SIGNED_PROFILE" \
  -outFile "$VERIFIED_PROFILE_JSON" >/dev/null

java -jar "$TOOLCHAIN_LIB_DIR/hap-sign-tool.jar" sign-app \
  -mode localSign \
  -keyAlias "openharmony application release" \
  -keyPwd "$KEY_PASSWORD" \
  -appCertFile "$APP_CERT_CHAIN" \
  -profileFile "$SIGNED_PROFILE" \
  -inFile "$UNSIGNED_HAP" \
  -signAlg SHA256withECDSA \
  -keystoreFile "$KEYSTORE_FILE" \
  -keystorePwd "$KEYSTORE_PASSWORD" \
  -outFile "$SIGNED_HAP" \
  -compatibleVersion 22 \
  -signCode 1 >/dev/null

java -jar "$TOOLCHAIN_LIB_DIR/hap-sign-tool.jar" verify-app \
  -inFile "$SIGNED_HAP" \
  -outCertChain "$VERIFIED_CERT_CHAIN" \
  -outProfile "$VERIFIED_PROFILE_P7B" \
  -inForm zip >/dev/null

printf 'OpenHarmony test-signed native HAP written to %s\n' "$SIGNED_HAP"
printf 'Verification outputs written to %s\n' "$VERIFY_DIR"
printf 'Bundle name: %s\n' "$BUNDLE_NAME"
