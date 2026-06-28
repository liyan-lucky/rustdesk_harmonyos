# Legal and Compliance Audit

Date: 2026-06-28
Repository: `liyan-lucky/rustdesk_harmonyos`

This audit records the compliance issues found during repository review and the remediation applied in this repository. It is not a formal legal opinion.

## Remediated items

### 1. Missing root license file

Finding: package metadata declared AGPL, but the repository did not have a root `LICENSE` file.

Remediation: added `LICENSE` with AGPL-3.0 text.

### 2. Incomplete attribution and notices

Finding: repository references RustDesk-compatible components and HarmonyOS toolchains, but no root notice explained upstream attribution, trademark ownership, or toolchain redistribution boundaries.

Remediation: added `NOTICE`, `THIRD_PARTY_NOTICES.md`, and `TRADEMARKS.md`.

### 3. Incomplete package metadata

Finding: package metadata had empty author fields, inconsistent license identifier style, and a native bridge subpackage without a license field.

Remediation: normalized package metadata to `AGPL-3.0-only`, added contributor attribution, and added native bridge metadata.

### 4. Missing privacy/security policy

Finding: remote desktop software processes sensitive categories of runtime data, but no privacy or security policy existed in the repository root.

Remediation: added `PRIVACY.md` and `SECURITY.md`.

### 5. Vendor SDK/toolchain redistribution risk

Finding: workflow defaults referenced public repository release URLs for HarmonyOS SDK / hvigor full archives. Vendor SDK and toolchain archives may have redistribution restrictions.

Remediation: documented that these inputs must come from authorized sources in `docs/HARMONYOS_TOOLCHAIN.md`. Public redistribution of SDK/toolchain archives should be removed from releases unless rights are verified.

## Remaining manual actions

These items require repository owner verification outside source editing:

1. Review existing GitHub Releases and remove public SDK/hvigor/toolchain archives unless redistribution rights are confirmed.
2. Confirm `HARMONYOS_SDK_URL` and `HARMONYOS_FULL_URL` point to authorized private/internal artifacts.
3. Confirm the companion `librustdesk_core` repository contains its own `LICENSE`, `NOTICE`, and corresponding-source materials.
4. Confirm all copied SVG/assets have known origin and compatible license; add detailed entries to `THIRD_PARTY_NOTICES.md` when origin is known.
5. Before app-store or commercial distribution, publish a production privacy policy matching actual telemetry, server, account, crash-reporting, and data-retention behavior.
6. Pin GitHub Actions to immutable commit SHAs if supply-chain hardening is required.

## Risk rating after remediation

- License-file and metadata risk: reduced.
- Attribution/trademark risk: reduced.
- Privacy/security process risk: reduced.
- Vendor SDK redistribution risk: partially reduced; still requires release cleanup and authorized artifact verification.
- Full third-party asset provenance: partially reduced; requires manual provenance confirmation for all assets.

## Ongoing rule

Do not add binary dependencies, SDKs, signing materials, copied assets, or upstream source fragments unless their license and redistribution rights are recorded first.
