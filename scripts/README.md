# Script Inventory

This directory keeps only the current HarmonyOS build and verification helpers.

> 2026-06-21 23:23：统一测试为 100 轮，每 5 轮增量检查点、每 10 轮全量检查点，第 100 轮后对固定 HAP 哈希做最终签名/双 ABI/BuildInfo/CoreBuildInfo/真机 updateTime/hilog/连接链验证。`99_Temp` 为多项目共享目录，脚本只能写入或清理本项目命名子目录，且任何 APK 都不得删除。

## Workspace and temporary output rule

All build, package, verification, HDC, backup, and temporary outputs must live under `%VSCODE_ROOT%/99_Temp` (current machine: `F:\Visual_Studio_Code\99_Temp`). See `docs/WORKSPACE_PATHS.md` for the authoritative directory map.

Do not write persistent outputs to `F:\99_Temp`, `C:\99_Temp`, the app repository root `.codex_*`, or `%TEMP%`. If a one-off diagnostic tool creates files there, delete or move them before handoff.

Some scripts may recreate `99_Temp/harmonyos_stage/<project name>` or `99_Temp/rustdesk_harmonyos_build/windows_hap` as transient staging/verification directories. They are not persistent evidence locations; after the signed HAP is copied or verified, the current retained install target is `99_Temp/harmonyos_build/<project name>/entry/build/default/outputs/default/entry-default-signed.hap`.

## Daily entry points

- `run_hvigor_with_sdk_patch.js`: canonical Hvigor build entry. It updates `BuildInfo.ets` and `CoreBuildInfo.ets`, applies the DevEco/Hvigor SDK compatibility patches, discovers DevEco paths from environment variables, `local.properties`, or the default install location, and switches to project mode for APP packaging tasks.
- `build_hap.bat`: Windows incremental HAP build. It force-refreshes `entry/src/main/libs/arm64/librustdesk_core.a`, stages a clean project copy under `99_Temp/harmonyos_stage/<project name>`, sets `RUSTDESK_HARMONY_VERSION_BUMP=incremental`, increments the rightmost app version number, builds under `99_Temp/harmonyos_build/<project name>`, then syncs version files back to the real project.
- `build_full_hap.bat`: Windows full HAP rebuild. It force-refreshes the native core, sets `RUSTDESK_HARMONY_VERSION_BUMP=full`, so the middle app version number is incremented and the rightmost number is reset to 0. It cleans generated project artifacts and `99_Temp/harmonyos_build/<project name>`, then runs the same staged Hvigor build path. It keeps `99_Temp/harmonyos_cache` by default to avoid DevEco/Hvigor built-in clean touching stale USB project caches.
- `AUTO_BUILD_INSTALL.bat`: Windows build, install, and launch wrapper. It force-refreshes the native core, uses the staged HAP build path, then installs the signed HAP with `hdc -t <target>`. With no target or `auto`, it uses `RUSTDESK_HARMONY_USB_TARGET` when configured, then tries wireless target `192.168.11.102:36169`, then falls back to the first available HDC target. Use `usb` or `--usb` to skip wireless and only use USB/local HDC targets. It rejects `[Empty]` from HDC target discovery.
- `build_harmonyos_hap.ps1`: Windows HAP staging helper for signed or unsigned artifacts.
- `verify_native_harmonyos_hap.ps1`: HAP inspection, optional install, launch, and log helper. Signature certificate/profile extraction uses GUID-named temp files so repeated verification cannot fail because a stale fixed `cert-chain.cer` or `profile.p7b` is still locked.
- `audit_connection_chain.ps1`: 66-check connection-chain audit. It verifies native core metadata, NAPI aliases, bridge wrappers, reconnect handling, quality-status display, native `StartScreenCapture`/incoming-frame bridge wiring, file access authorization guards, packaged HAP native libraries, and the absence of the unsupported `libtime_service_ndk.so` runtime dependency. It writes `reports/connection_chain_audit_latest.md`.
- `audit_full_function_rounds.ps1`: repeatable full-function static/package audit. It checks connection flow, retry/reset handling, LAN discovery, native core metadata, quality info display, service wrappers, GitHub packaging files, and optional HAP/APP artifacts. Use `-Rounds 100` after broad connection-chain changes. It writes `reports/full_function_audit_latest.md`.
- `github_build_harmonyos.ps1`: GitHub Actions/self-hosted HAP-only build entry. It has `-PreflightOnly` for DevEco SDK, signing, native core completeness, native core size, and optional SHA256 checks before packaging. By default it builds from a staged copy under `99_Temp` and writes only HAP artifacts to `99_Temp/harmonyos_artifacts/<project name>`.
- `github_build_harmonyos_linux.sh`: Linux GitHub Actions HAP-only build entry used by `.github/workflows/build-harmonyos.yml`. It builds from a staged copy, downloads/verifies the native core, produces HAP artifacts, and writes them to the workflow artifact directory.
- `.github/workflows/build-harmonyos.yml`: current Linux online package workflow. It builds and uploads HAP only, downloads the split SDK packages (`harmonyos-sdk-full.zip` and `harmonyos-hvigor-full.zip`), downloads `RUSTDESK_CORE_URL`/`RUSTDESK_CORE_X86_64_URL` or the default latest core URLs, and verifies SHA256 values only when configured. Workflow inputs are `version_bump`, `skip_package_verify`, and `publish_release`.

## Native core helpers

- `fetch_native_core.ps1`: downloads `librustdesk_core.a` and `librustdesk_core_x86_64.a` before local builds. Default URLs are the latest core release assets; override with `RUSTDESK_CORE_URL` / `RUSTDESK_CORE_X86_64_URL`, pin with matching SHA256 variables, or skip only when valid local cores exist with `RUSTDESK_CORE_SKIP_DOWNLOAD=1`.
- Core source and build scripts now live in `%VSCODE_ROOT%/13_librustdesk_core`. Modify Rust/C++ bridge code there, publish `librustdesk_core.a` to `https://github.com/liyan-lucky/librustdesk_core/releases`, then let this app project fetch the latest release asset during build.
- `build_native_bridge.ps1`: legacy/app-side Windows native core helper kept for reference. The current active core build path is the 13 project.
- `build_native_bridge.sh`: legacy Linux native core helper for `aarch64-unknown-linux-ohos`.
- `extract_linux_native_sdk.sh`: legacy Linux SDK extraction helper used before Linux native builds.
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
- `switch_deveco_paths.ps1`: switches `hvigor/hvigor-config.json5` and `build-profile.json5` between portable `../99_Temp/...` paths and absolute DevEco Studio paths. Use `-Mode DevEco` only when DevEco Studio needs absolute paths, then switch back with `-Mode Portable` before committing.

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

The repository root should stay portable by default. `run_hvigor_with_sdk_patch.js` may write absolute build/cache paths while the wrapper is running, but it restores portable `../99_Temp/...` paths on exit. If DevEco Studio sync fails on relative paths, run `powershell -ExecutionPolicy Bypass -File scripts\switch_deveco_paths.ps1 -Mode DevEco`, verify signing, then run `-Mode Portable` before committing or handing the project to another machine.

The online Linux workflow uses these default artifact URLs unless secrets or repository variables override them:

- `HARMONYOS_SDK_URL=https://github.com/liyan-lucky/rustdesk_harmonyos/releases/download/harmonyos-sdk-full/harmonyos-sdk-full.zip`
- `HARMONYOS_HVIGOR_URL=https://github.com/liyan-lucky/rustdesk_harmonyos/releases/download/harmonyos-hvigor-full/harmonyos-hvigor-full.zip`
- `RUSTDESK_CORE_URL=https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a`

Release upload rule: upload only `.hap`. Do not create APP, `.app.zip`, `manifest.json`, or `SHA256SUMS.txt` in the online workflow.

If install succeeds but launch returns `Error Code:10106102`, the script reports a warning and exits successfully because the device is locked and cannot be auto-unlocked by HDC in developer mode.

Use `build_hap.bat` for a fast incremental build, `build_full_hap.bat` for a clean rebuild, and `AUTO_BUILD_INSTALL.bat --full auto` when the build and install flow should start from a clean generated state.
For temporary USB-only install testing, use `AUTO_BUILD_INSTALL.bat --skip-build usb` after a successful HAP build.

Use `powershell -ExecutionPolicy Bypass -File scripts\audit_connection_chain.ps1` after connection-chain changes. A healthy local build should finish with `66 PASS, 0 FAIL, 0 SKIP`.

Use `powershell -ExecutionPolicy Bypass -File scripts\audit_full_function_rounds.ps1 -Rounds 100 -HapPath <signed.hap> -AppPath <signed.app>` after broad native/core/package changes. A healthy run should finish every round without FAIL results.
