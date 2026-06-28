# HarmonyOS Toolchain Compliance

This project requires HarmonyOS/OpenHarmony build tools at build time, but this repository does not grant redistribution rights for proprietary SDK or command-line tool archives.

## Required CI variables

GitHub Actions may use these values:

- `HARMONYOS_SDK_URL`: URL of an SDK archive that the repository owner is authorized to use.
- `HARMONYOS_FULL_URL`: URL of a full hvigor/command-line-tools archive that the repository owner is authorized to use.
- `RUSTDESK_SIGNING_ZIP_B64`: base64 signing bundle for authorized release signing. Store this as a GitHub Secret only.

## Compliance rules

- Prefer GitHub Secrets or private internal artifact storage for vendor toolchains.
- Do not publish SDK, DevEco, hvigor, signing profiles, certificates, private keys, or vendor tool archives in public releases unless redistribution rights are confirmed.
- Do not commit extracted SDK/toolchain files into this repository.
- Build logs should not print sensitive signing data or private URLs containing tokens.
- Release artifacts should contain the application package and required AGPL corresponding-source information, not vendor SDK bundles.

## If CI fails after removing public defaults

Add repository or organization Variables/Secrets for:

```text
HARMONYOS_SDK_URL
HARMONYOS_FULL_URL
```

The URLs must point to archives you are allowed to use. The workflow intentionally fails when these values are missing to avoid silently relying on public redistribution of vendor toolchains.
