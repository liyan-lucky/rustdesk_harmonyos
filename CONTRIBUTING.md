# Contributing

Thanks for contributing to this project.

## License of contributions

By submitting a contribution, you confirm that:

- You have the right to submit the contribution.
- Your contribution may be distributed under `AGPL-3.0-only` unless a file explicitly states another compatible license.
- Your contribution does not include copied third-party code, assets, SDK files, generated binaries, signing material, credentials, or private user data unless the license and redistribution rights are documented.

## Before opening a pull request

Check that your change follows these rules:

- Do not add proprietary SDK/toolchain archives or extracted SDK directories.
- Do not add `.hap`, `.app`, `.a`, `.so`, signing bundles, profiles, certificates, private keys, or generated release artifacts.
- Do not add credentials, tokens, passwords, private URLs with tokens, device logs containing personal data, or production user data.
- Add or update `THIRD_PARTY_NOTICES.md` for new copied assets, copied source, generated code, or external binaries.
- Add SPDX headers or update REUSE metadata when adding new source files.
- Keep package metadata license fields aligned with `AGPL-3.0-only`.
- Avoid wording that implies official RustDesk or Huawei endorsement.

## Security-sensitive changes

Changes touching remote-control authorization, screen capture, audio, input injection, clipboard, file transfer, native bridge code, downloaded native libraries, signing, or release packaging require extra review.

## Build toolchain

CI variables `HARMONYOS_SDK_URL` and `HARMONYOS_FULL_URL` must point to authorized toolchain archives. Do not submit public fallback URLs for vendor SDK/toolchain redistribution unless rights are verified.
