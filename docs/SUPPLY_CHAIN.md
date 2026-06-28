# Supply Chain Security Policy

This project includes application source code, native bridge code, GitHub Actions workflows, generated artifacts, and downloaded native core/toolchain inputs. Supply-chain changes must be reviewed carefully.

## Build inputs

Allowed build inputs:

- Source files tracked in this repository.
- Native core artifacts from the companion core project, preferably pinned by SHA256.
- HarmonyOS SDK/toolchain archives from authorized sources only.
- GitHub Actions pinned or versioned dependencies.

Do not use public SDK/toolchain fallback URLs for proprietary vendor archives unless redistribution rights are confirmed.

## Native core artifacts

When using `RUSTDESK_CORE_URL` or `RUSTDESK_CORE_X86_64_URL`:

- Prefer release assets from the companion source repository.
- Pin `RUSTDESK_CORE_SHA256` and `RUSTDESK_CORE_X86_64_SHA256` for release builds.
- Record the companion source commit or release tag in release notes.
- Ensure Corresponding Source is available under AGPL-3.0.

## GitHub Actions

Current workflows use public GitHub Actions. For high-assurance releases:

- Pin actions to immutable commit SHAs instead of floating version tags.
- Review each action's source and license.
- Keep workflow permissions minimal.
- Do not print secrets, signed URLs, signing profiles, or private artifact URLs.

## Dependencies

- Keep dependency manifests small and reviewed.
- Review Dependabot changes before merging.
- Do not add telemetry, crash reporting, analytics, or advertising SDKs without privacy review.
- Update `THIRD_PARTY_NOTICES.md` when new third-party source/assets/binaries are introduced.

## Artifacts

Release artifacts must follow `docs/RELEASE_ARTIFACT_POLICY.md`.

Do not publish SDK/toolchain archives, signing material, private logs, or generated object-code artifacts unless redistribution and source obligations are satisfied.

## Verification recommendation

For public releases, record:

- App source commit.
- Native core source commit or tag.
- HAP file hash.
- Native core file hashes.
- Build workflow run ID.
- Toolchain provenance without exposing private URLs or secrets.
