# Source Availability Notice

This project is distributed under `AGPL-3.0-only`.

If you distribute a signed HAP, native library, static library, hosted service, or modified network-accessible version based on this project, you must provide the Corresponding Source as required by AGPL-3.0.

## What should be available

For each released binary, keep enough source and build information for recipients to rebuild or modify the covered work, including:

- The exact source commit or source archive.
- Build scripts and workflow files used for the release.
- Native bridge source and interface definitions.
- Companion native-core source or a link to the exact corresponding source release.
- Patches, generated source inputs, and build configuration needed to recreate the binary.
- License and notice files.

## What should not be included as source

Do not publish private signing material, passwords, API tokens, private user data, or proprietary SDK/toolchain archives unless you have redistribution rights. Vendor SDKs and platform system libraries may be obtained separately from authorized sources.

## Release note recommendation

Each GitHub Release should identify:

- App source commit.
- Native core source commit or release tag.
- Build date.
- Artifact hashes.
- Where recipients can obtain Corresponding Source.
