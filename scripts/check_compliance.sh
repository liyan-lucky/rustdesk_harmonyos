#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

required=(
  LICENSE
  NOTICE
  COMPLIANCE.md
  THIRD_PARTY_NOTICES.md
  TRADEMARKS.md
  PRIVACY.md
  SECURITY.md
  CONTRIBUTING.md
  SOURCE_OFFER.md
  RELEASE_COMPLIANCE_CHECKLIST.md
  docs/HARMONYOS_TOOLCHAIN.md
  docs/LEGAL_AUDIT.md
  docs/ASSET_PROVENANCE.md
  docs/RELEASE_ARTIFACT_POLICY.md
  docs/SUPPLY_CHAIN.md
  docs/SBOM_POLICY.md
)

missing=0
for f in "${required[@]}"; do
  if [ ! -s "$f" ]; then
    echo "Missing required compliance file: $f" >&2
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  exit 1
fi

grep -q '"license"[[:space:]]*:[[:space:]]*"AGPL-3.0-only"' oh-package.json5
grep -q '"license"[[:space:]]*:[[:space:]]*"AGPL-3.0-only"' entry/oh-package.json5
grep -q '"license"[[:space:]]*:[[:space:]]*"AGPL-3.0-only"' entry/src/main/cpp/types/librustdesk_bridge/oh-package.json5

blocked_regex='\.(hap|app|app\.zip|p12|pfx|jks|keystore|pem|key|p7b|p7s|profile|provisionprofile)$|(^|/)(harmonyos-sdk-full|harmonyos-hvigor-full|DevEco|HarmonyOS|OpenHarmony|command-line-tools|sdk-full|hvigor).*(\.zip|\.7z|\.tar|\.tar\.gz|\.tgz)$'
if git ls-files | grep -E -i "$blocked_regex"; then
  echo "Blocked artifact or sensitive file is tracked. Remove it from the repository." >&2
  exit 1
fi

scan_targets=(
  .github/workflows/build-harmonyos.yml
  .github/workflows/build-harmonyos-linux.yml
  scripts/README.md
  docs/HARMONYOS_TOOLCHAIN.md
  COMPLIANCE.md
)
if grep -R -n -E 'releases/download/harmonyos-(sdk|hvigor)-full|harmonyos-sdk-full\.zip|harmonyos-hvigor-full\.zip|HARMONYOS_HVIGOR_URL' "${scan_targets[@]}" 2>/dev/null; then
  echo "Public HarmonyOS SDK/hvigor fallback or old variable found in active workflow/script/compliance docs." >&2
  exit 1
fi

if git ls-files | grep -E -i '(^|/)(.*secret.*|.*token.*|.*password.*|.*private.*)\.(txt|json|yaml|yml|env|ini|properties)$'; then
  echo "Tracked file name looks sensitive. Rename/remove it or document why it is safe." >&2
  exit 1
fi

echo "Compliance check passed."
