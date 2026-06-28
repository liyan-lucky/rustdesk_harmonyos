# Release Compliance Checklist

Use this checklist before publishing signed HAP files or GitHub Releases.

## Source and license

- [ ] `LICENSE` is present and matches package metadata.
- [ ] `NOTICE` and `THIRD_PARTY_NOTICES.md` are up to date.
- [ ] Corresponding Source for every released binary is available.
- [ ] Release notes identify the source commit used for the build.
- [ ] Native static libraries or generated native bridges are traceable to source.

## Vendor toolchains

- [ ] Public releases do not include HarmonyOS SDK, DevEco, hvigor, ohpm, signing profiles, private keys, or vendor tool archives unless redistribution rights are confirmed.
- [ ] `HARMONYOS_SDK_URL` points to an authorized SDK archive.
- [ ] `HARMONYOS_FULL_URL` points to an authorized hvigor/toolchain archive.
- [ ] Signing material is stored only in GitHub Secrets or another private secret store.

## Trademarks and wording

- [ ] Release title and app description do not imply official RustDesk or Huawei endorsement.
- [ ] `TRADEMARKS.md` remains accurate.
- [ ] Screenshots, icons, names, and descriptions are checked for unauthorized brand use.

## Privacy and security

- [ ] `PRIVACY.md` matches actual runtime behavior.
- [ ] `SECURITY.md` gives a clear vulnerability reporting path.
- [ ] Logs and artifacts do not expose device IDs, tokens, private URLs, signing data, or user data.
- [ ] Remote-control authorization, screen capture, audio, input, clipboard, and file-transfer behavior are reviewed.

## Assets and dependencies

- [ ] New copied assets have documented origin and license.
- [ ] Dependency/license changes are reflected in `THIRD_PARTY_NOTICES.md`.
- [ ] GitHub Actions and dependencies are reviewed for supply-chain risk.

## Final gate

Do not publish the release if any item above is unknown or blocked by license/redistribution uncertainty.
