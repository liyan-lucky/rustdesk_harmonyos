# Compliance Policy

This repository is maintained with the goal of minimizing license, attribution, trademark, privacy, security, supply-chain, and redistribution risk.

## License baseline

- Project source code is licensed under `AGPL-3.0-only` unless a file states another compatible license.
- Keep `LICENSE` in the repository root.
- Keep package metadata license fields aligned with the root license.
- Any distribution of object code, signed HAP files, native libraries, or network-accessible modified versions must also provide Corresponding Source as required by AGPL-3.0.
- See `SOURCE_OFFER.md` for source availability expectations.

## Third-party code and assets

Before adding third-party files, record at least:

1. Source project or upstream URL.
2. Copyright holder, if known.
3. License identifier and license text location.
4. Whether the file was copied, modified, generated, or only referenced.
5. Any extra attribution or notice requirement.

Do not add files with unclear origin, incompatible licenses, or missing redistribution permission. See `THIRD_PARTY_NOTICES.md` and `docs/ASSET_PROVENANCE.md`.

## Proprietary SDK/toolchain materials

Do not commit or publish proprietary SDKs, command-line tools, DevEco/hvigor archives, system libraries, private build caches, or downloaded vendor packages unless redistribution rights have been confirmed in writing.

CI may use `HARMONYOS_SDK_URL` and `HARMONYOS_FULL_URL`, but those URLs must point to artifacts that the repository owner is authorized to use. Prefer private GitHub Actions secrets or internal storage over public release assets for vendor toolchains. See `docs/HARMONYOS_TOOLCHAIN.md` and `docs/RELEASE_ARTIFACT_POLICY.md`.

## RustDesk compatibility and attribution

This project may interoperate with RustDesk-compatible components and may include bridge code generated from companion projects. Keep RustDesk attribution in `NOTICE` and avoid representing this repository as an official RustDesk product unless authorized.

## Huawei/HarmonyOS attribution

HarmonyOS, OpenHarmony, DevEco Studio, hvigor, HMS, and related names are owned by Huawei or their respective owners. Use those names only to describe compatibility, build requirements, or platform targets. Do not imply endorsement or official status.

## Sensitive files

Never commit:

- Signing key material or private build profiles.
- Plaintext credentials, API tokens, server passwords, or session secrets.
- Production user data, logs with personal data, device IDs, or access tokens.
- Full proprietary SDK/toolchain archives unless redistribution rights are confirmed.

The `Compliance Check` workflow blocks common restricted files and public HarmonyOS SDK/toolchain fallback URLs from active workflows/scripts.

## Supply chain and SBOM

- Follow `docs/SUPPLY_CHAIN.md` when changing workflows, native core downloads, signing, dependencies, or release packaging.
- Follow `docs/SBOM_POLICY.md` when preparing public or commercial releases.
- Prefer SHA256-pinned native core artifacts for releases.
- Prefer immutable GitHub Action SHAs for high-assurance release workflows.

## Release checklist

Before publishing a release:

- Confirm source code for the released binary is available.
- Confirm `LICENSE`, `NOTICE`, `THIRD_PARTY_NOTICES.md`, `TRADEMARKS.md`, `PRIVACY.md`, and `SECURITY.md` are present.
- Confirm public artifacts do not include proprietary SDK/toolchain archives without permission.
- Confirm package metadata license fields are accurate.
- Confirm release notes do not imply RustDesk or Huawei endorsement.
- Confirm hashes and build provenance are documented without exposing secrets.
- Confirm release artifacts follow `docs/RELEASE_ARTIFACT_POLICY.md`.

## Audit status

This policy improves repository hygiene but is not a legal opinion. If distributing commercially or publishing to an app store, perform a formal legal review of all upstream code, SDK terms, app store terms, cryptography/export rules, and privacy obligations.
