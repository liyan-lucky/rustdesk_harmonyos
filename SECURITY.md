# Security Policy

## Supported versions

This project is under active development. Security fixes are expected to target the latest `master` branch unless a release branch is explicitly created.

## Reporting a vulnerability

Please do not publish exploit details in a public issue before a fix is available.

Report suspected vulnerabilities by opening a private security advisory when available, or by contacting the repository owner through GitHub. Include:

- Affected version or commit.
- Reproduction steps.
- Expected and actual impact.
- Whether credentials, remote control, file transfer, screen/audio capture, or account/session data are involved.
- Any suggested fix or mitigation.

## Sensitive material

Do not attach private keys, tokens, production logs containing personal data, or full user datasets to public issues. Redact sensitive fields before sharing diagnostics.

## Security-sensitive areas

Review changes carefully when they affect:

- Remote-control authorization and authentication.
- Clipboard, file transfer, screen capture, audio capture, and input injection.
- Server address, relay, rendezvous, and account configuration.
- Native bridge code, C ABI, memory ownership, and buffer parsing.
- Build signing, release packaging, and native-library downloads.

## Dependency and release hygiene

- Prefer pinned dependencies and reproducible build inputs.
- Do not distribute proprietary SDK/toolchain archives without confirmed rights.
- Keep Corresponding Source available for released binaries as required by AGPL-3.0.
