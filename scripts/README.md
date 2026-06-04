# Script Inventory

This directory keeps only the current HarmonyOS build and verification helpers.

## Daily entry points

- `run_hvigor_with_sdk_patch.js`: canonical HAP build entry. It updates `BuildInfo.ets` and applies the DevEco/Hvigor SDK compatibility patches.
- `build_hap.bat`: Windows incremental HAP build. It calls `run_hvigor_with_sdk_patch.js`, so app build time is refreshed automatically without clearing caches.
- `build_full_hap.bat`: Windows full HAP rebuild. It cleans generated project artifacts, then calls `run_hvigor_with_sdk_patch.js`, so app build time is refreshed automatically.
- `AUTO_BUILD_INSTALL.bat`: Windows build, install, and launch wrapper. It calls `run_hvigor_with_sdk_patch.js`, then installs the signed HAP with `hdc -t <target>`. With no target or `auto`, it prefers USB target `2NX0224429035123`, then tries wireless target `192.168.11.100:36169`.
- `build_harmonyos_hap.ps1`: Windows HAP staging helper for signed or unsigned artifacts.
- `verify_native_harmonyos_hap.ps1`: HAP inspection, optional install, launch, and log helper.

## Native core helpers

- `build_native_bridge.ps1`: Windows native core helper. The current project ABI is arm64 only, so the supported target is `aarch64-unknown-linux-ohos`.
- `build_native_bridge.sh`: Linux native core helper for `aarch64-unknown-linux-ohos`.
- `extract_linux_native_sdk.sh`: Linux SDK extraction helper used before Linux native builds.
- `_ohos-sdk-env.cmd` / `_ohos-sdk-env.sh`: shared SDK discovery helpers.
- `aarch64-unknown-linux-ohos-clang.cmd` / `.sh`, `aarch64-unknown-linux-ohos-clang++.cmd` / `.sh`, `ohos-llvm-ar.cmd` / `.sh`: compiler and archiver wrappers used by native builds.

## Maintenance helpers

- `clean_project.ps1`: Windows cleanup for generated project artifacts. Use `-IncludeExternalBuild` to also remove `99_Temp/harmonyos_build/rustdesk_harmonyos` and `99_Temp/harmonyos_cache`.
- `backup_project.ps1`: Windows project backup helper. It always writes zip backups under `E:/Visual_Studio_Code/99_Temp/rustdesk_harmonyos_backups` and keeps the latest 2 archives.
- `clean_project_artifacts.sh`: Linux/macOS cleanup for generated project artifacts.
- `check_harmony_signing_profile.ps1`: signing preflight used by the HAP staging helper.
- `export_deveco_signing_command.js`: signing command export/debug utility.

Removed scripts were stale duplicate build/install chains, old hard-coded SDK wrappers, non-current ABI wrappers, and the obsolete Linux HAP repack/sign/install path.

`AUTO_BUILD_INSTALL.bat` target defaults can be overridden with:

- `RUSTDESK_HARMONY_USB_TARGET`
- `RUSTDESK_HARMONY_WIRELESS_TARGET`

If install succeeds but launch returns `Error Code:10106102`, the script reports a warning and exits successfully because the device is locked and cannot be auto-unlocked by HDC in developer mode.

Use `build_hap.bat` for a fast incremental build, `build_full_hap.bat` for a clean rebuild, and `AUTO_BUILD_INSTALL.bat --full auto` when the build and install flow should start from a clean generated state.
