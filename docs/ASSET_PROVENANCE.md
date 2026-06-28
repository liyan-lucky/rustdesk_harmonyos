# Asset Provenance Register

This register tracks the origin and license status of assets included in the application.

## Policy

Every copied icon, SVG, image, sound, font, document, or generated asset should have a known source and license before it is committed or released.

For each asset group, record:

- Path or glob.
- Source URL or internal origin.
- Copyright holder.
- License identifier.
- Whether modified.
- Required attribution.

## Current asset groups

| Path | Origin | License status | Action required |
| --- | --- | --- | --- |
| `entry/src/main/resources/rawfile/*.svg` | Project assets / copied or generated icons, exact per-file origin not fully recorded | Must be verified before commercial distribution | Confirm origin and update this table with exact licenses |
| `entry/src/main/resources/base/media/*` | Project media resources | Must be verified before commercial distribution | Confirm origin and license |
| `entry/src/main/resources/base/profile/*` | HarmonyOS profile/config resources | Project/application configuration | Keep free of private signing profiles and personal data |

## Rules for new assets

- Do not copy icons from websites or apps without checking the license.
- Prefer original project-created SVGs or assets from clearly permissive sources.
- Do not use trademarked logos unless required for compatibility UI and allowed by the trademark holder's policy.
- Keep source URLs and license notes in this file.
- If an asset has a license notice requirement, add it to `THIRD_PARTY_NOTICES.md`.

## Release gate

If an asset's origin or license is unknown, treat it as unresolved risk and do not ship it in a public/commercial release until verified or replaced.
