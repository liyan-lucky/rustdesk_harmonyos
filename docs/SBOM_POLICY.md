# SBOM Policy

An SBOM (Software Bill of Materials) should be generated for public or commercial releases when practical.

## Minimum SBOM scope

A release SBOM should identify:

- Application source repository and commit.
- Native core repository and commit/release tag.
- GitHub Actions used for the build.
- Declared package dependencies from `oh-package.json5` and `entry/oh-package.json5`.
- Native libraries bundled into the HAP.
- Third-party assets with recorded origin.

## Native and generated artifacts

For native libraries and generated bridge files, record:

- Source project or generator.
- Build commit.
- Output file name.
- SHA256 hash.
- License.
- Corresponding Source location.

## Vendor toolchains

HarmonyOS SDK, DevEco, hvigor, ohpm, and platform toolchains are build tools. Do not publish proprietary toolchain archives as part of the SBOM package unless redistribution rights are confirmed.

The SBOM may describe toolchain provenance in general terms without exposing private URLs, secrets, signing material, or access tokens.

## Recommended release files

For each public release, consider publishing:

- `SBOM.md` or a standard SBOM format file.
- `SHA256SUMS.txt` for application artifacts only.
- Release notes with source commit and native core commit.

Do not include SDK/toolchain hashes in public release notes if doing so would reveal private artifact identity or unauthorized redistribution details.
