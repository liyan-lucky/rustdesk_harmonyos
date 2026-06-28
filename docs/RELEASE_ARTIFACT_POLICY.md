# Release Artifact Policy

This policy defines what may be published in GitHub Releases or other public distribution channels.

## Allowed public release artifacts

The following may be published when license and source requirements are satisfied:

- Signed or unsigned HAP application packages.
- Source archives generated from the repository.
- Checksums for released application packages.
- Release notes identifying source commits and build provenance.

## Conditionally allowed artifacts

These may be published only when rights and source obligations are confirmed:

- Native static libraries or shared libraries, if Corresponding Source is available.
- Generated bridge files, if their source/generator provenance is documented.
- Third-party assets, if their license permits redistribution and attribution is provided.

## Prohibited unless explicit redistribution rights exist

Do not publish these in public releases by default:

- HarmonyOS SDK archives.
- DevEco Studio archives.
- hvigor, ohpm, command-line-tools, or vendor toolchain archives.
- Extracted vendor SDK/toolchain directories.
- Signing certificates, private keys, signing profiles, or signing bundles.
- Private build caches, logs with personal data, device IDs, tokens, passwords, or private URLs.
- User data or production diagnostics.

## Required release metadata

Each release should include:

- App source commit.
- Native core source commit or release tag.
- Artifact hashes.
- Build date.
- License summary.
- Source availability statement pointing to `SOURCE_OFFER.md`.

## Existing releases

Existing public releases should be reviewed. Remove SDK/toolchain archives or other restricted artifacts unless redistribution rights are verified.
