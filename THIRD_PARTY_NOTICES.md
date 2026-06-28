# Third-Party Notices

This file tracks third-party components and external materials referenced by this repository.

## RustDesk-compatible components

- Component: RustDesk-compatible core and bridge interfaces.
- Role: remote desktop protocol/session/core interoperability.
- License: AGPL-3.0 family, subject to upstream licensing and the companion core repository licensing.
- Notice: RustDesk names and marks belong to their respective owners. This repository is not official RustDesk unless explicitly authorized by the upstream project owners.

## HarmonyOS / OpenHarmony SDK and command-line tooling

- Component: HarmonyOS/OpenHarmony SDK, DevEco command-line tools, hvigor, ohpm, and related platform tooling.
- Role: build-time platform toolchain.
- License: not granted by this repository; governed by Huawei/OpenHarmony/vendor terms.
- Notice: These tools must be obtained from authorized sources. This repository should not redistribute proprietary SDK/toolchain archives unless redistribution rights have been confirmed.

## GitHub Actions used by workflow files

The workflow files reference public GitHub Actions such as:

- `actions/checkout`
- `actions/setup-java`
- `actions/setup-node`
- `actions/upload-artifact`
- `actions/download-artifact`
- `softprops/action-gh-release`
- `harmonyos-dev/setup-harmonyos-sdk`

Each action is subject to its own repository license and terms. Pinning to immutable commit SHAs is recommended for high-assurance supply-chain control.

## Assets and icons

SVG and raw resources in `entry/src/main/resources` must either be original project assets, generated assets, or assets whose licenses permit redistribution under this project. When adding new assets, record their origin and license here.

## Native libraries and build artifacts

Downloaded native static libraries, generated `.so` files, signed HAP packages, and other object-code artifacts must be accompanied by Corresponding Source as required by AGPL-3.0 when distributed.

## Maintenance rule

Add a new entry here whenever a dependency, copied file, generated file, asset pack, SDK package, or external binary becomes part of the repository or release process.
