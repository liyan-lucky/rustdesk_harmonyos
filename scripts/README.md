# Script Inventory

This directory keeps only the current HarmonyOS build and verification helpers.

## Daily entry points

- `run_hvigor_with_sdk_patch.js`: canonical Hvigor build entry. It updates `BuildInfo.ets` and `CoreBuildInfo.ets`, applies the DevEco/Hvigor SDK compatibility patches, discovers DevEco paths from environment variables, `local.properties`, or the default install location, and switches to project mode for APP packaging tasks.
- `build_hap.bat`: Windows incremental HAP build. It stages a clean project copy under `99_Temp/harmonyos_stage/<project name>`, sets `RUSTDESK_HARMONY_VERSION_BUMP=incremental`, increments the rightmost app version number, builds under `99_Temp/harmonyos_build/<project name>`, then syncs version files back to the real project.
- `build_full_hap.bat`: Windows full HAP rebuild. It sets `RUSTDESK_HARMONY_VERSION_BUMP=full`, so the middle app version number is incremented and the rightmost number is reset to 0. It cleans generated project artifacts and `99_Temp/harmonyos_build/<project name>`, then runs the same staged Hvigor build path. It keeps `99_Temp/harmonyos_cache` by default to avoid DevEco/Hvigor built-in clean touching stale USB project caches.
- `AUTO_BUILD_INSTALL.bat`: Windows build, install, and launch wrapper. It uses the staged HAP build path, then installs the signed HAP with `hdc -t <target>`. With no target or `auto`, it uses `RUSTDESK_HARMONY_USB_TARGET` when configured, then tries wireless target `192.168.11.100:36169`, then falls back to the first available HDC target.
- `build_harmonyos_hap.ps1`: Windows HAP staging helper for signed or unsigned artifacts.
- `verify_native_harmonyos_hap.ps1`: HAP inspection, optional install, launch, and log helper.
- `audit_connection_chain.ps1`: 50-check connection-chain audit. It verifies native core metadata, NAPI aliases, bridge wrappers, reconnect handling, quality-status display, packaged HAP native libraries, and the absence of the unsupported `libtime_service_ndk.so` runtime dependency. It writes `reports/connection_chain_audit_latest.md`.
- `audit_full_function_rounds.ps1`: repeatable full-function static/package audit. It checks connection flow, retry/reset handling, LAN discovery, native core metadata, quality info display, service wrappers, GitHub packaging files, and optional HAP/APP artifacts. Use `-Rounds 100` after broad connection-chain changes. It writes `reports/full_function_audit_latest.md`.
- `github_build_harmonyos.ps1`: GitHub Actions/self-hosted build entry. It can build `hap`, `app`, or `both`; `both` uses the APP packaging task because it also produces the embedded/signed HAP. It has `-PreflightOnly` for DevEco SDK, signing, native core completeness, native core size, and optional SHA256 checks before packaging. By default it builds from a staged copy under `99_Temp` and writes artifacts to `99_Temp/harmonyos_artifacts/<project name>`.
- `.github/workflows/build-harmonyos.yml`: manual online package workflow. Configure `RUSTDESK_CORE_URL`, `RUSTDESK_CORE_SHA256`, and `RUSTDESK_SIGNING_ZIP_B64`; set `DEVECO_TOOLS_HOME`, `DEVECO_SDK_HOME`, and `DEVECO_NODE_EXE` when the runner does not use the default DevEco install paths. Workflow inputs include `artifact_type`, `version_bump`, `skip_package_verify`, and `disable_stage`.

## Native core helpers

- `build_native_bridge.ps1`: Windows native core helper. The current project ABI is arm64 only, so the supported target is `aarch64-unknown-linux-ohos`.
- `build_native_bridge.sh`: Linux native core helper for `aarch64-unknown-linux-ohos`.
- `extract_linux_native_sdk.sh`: Linux SDK extraction helper used before Linux native builds.
- `_ohos-sdk-env.cmd` / `_ohos-sdk-env.sh`: shared SDK discovery helpers.
- `aarch64-unknown-linux-ohos-clang.cmd` / `.sh`, `aarch64-unknown-linux-ohos-clang++.cmd` / `.sh`, `ohos-llvm-ar.cmd` / `.sh`: compiler and archiver wrappers used by native builds.

## Maintenance helpers

- `clean_project.ps1`: Windows cleanup for generated project artifacts. Use `-IncludeExternalBuild` to also remove `99_Temp/harmonyos_build/<project name>` and `99_Temp/harmonyos_stage/<project name>`; add `-IncludeHvigorCache` only when you explicitly need to remove `99_Temp/harmonyos_cache`.
- `backup_project.ps1`: Windows project backup helper. It derives `%VSCODE_ROOT%` from the current project location, writes zip backups under `%VSCODE_ROOT%/99_Temp/rustdesk_harmonyos_backups`, and keeps the latest 2 archives.
- `clean_project_artifacts.sh`: Linux/macOS cleanup for generated project artifacts.
- `stage_project_for_build.ps1`: Copies a clean build snapshot into `99_Temp/harmonyos_stage/<project name>` and rewrites only the staged signing paths so root config can stay portable.
- `sync_build_version_from_stage.ps1`: Copies `AppScope/app.json5` and `BuildInfo.ets` from the staged build back to the real project after a successful build.
- `check_harmony_signing_profile.ps1`: signing preflight used by the HAP staging helper.
- `export_deveco_signing_command.js`: signing command export/debug utility.

Removed scripts were stale duplicate build/install chains, old hard-coded SDK wrappers, non-current ABI wrappers, and the obsolete Linux HAP repack/sign/install path.

`AUTO_BUILD_INSTALL.bat` target defaults can be overridden with:

- `RUSTDESK_HARMONY_USB_TARGET`
- `RUSTDESK_HARMONY_WIRELESS_TARGET`

Borrowed-computer path overrides:

- `DEVECO_NODE_EXE` or `local.properties` `npm.dir` for Node.
- `HDC_EXE` or `local.properties` `sdk.dir` for HDC.
- `DEVECO_TOOLS_HOME` for Hvigor tools when DevEco is not installed in the default location.
- `DEVECO_SDK_HOME` for the DevEco SDK root when `local.properties` is not enough.
- `RUSTDESK_HARMONY_TEMP_ROOT` if `99_Temp` is not beside `11_Rustdesk_harmonyos`.
- `RUSTDESK_HARMONY_BUILD_DIR` if native build files live outside `%VSCODE_ROOT%/99_Temp/rustdesk_harmonyos_build`.

The Windows HAP entry points set `CI=true`, `RUSTDESK_HARMONY_TEMP_ROOT`, and `BUILD_CACHE_DIR` before Node starts, then build from a staged clean copy. This keeps Hvigor outputs, logs, and Native `.cxx` files under `99_Temp` instead of the real project tree, which is important when the workspace is carried on a USB drive between borrowed computers.

If install succeeds but launch returns `Error Code:10106102`, the script reports a warning and exits successfully because the device is locked and cannot be auto-unlocked by HDC in developer mode.

Use `build_hap.bat` for a fast incremental build, `build_full_hap.bat` for a clean rebuild, and `AUTO_BUILD_INSTALL.bat --full auto` when the build and install flow should start from a clean generated state.

Use `powershell -ExecutionPolicy Bypass -File scripts\audit_connection_chain.ps1` after connection-chain changes. A healthy local build should finish with `50 PASS, 0 FAIL, 0 SKIP`.

Use `powershell -ExecutionPolicy Bypass -File scripts\audit_full_function_rounds.ps1 -Rounds 100 -HapPath <signed.hap> -AppPath <signed.app>` after broad native/core/package changes. A healthy run should finish every round without FAIL results.
