# Connection Debug Log

> Current focused record for connection and video-stream verification. Keep this file updated when device-side behavior is tested.

## 2026-06-15 v0.22.4 core-80 incoming frame bridge verification

- Core release: 13 核心 commit `12ad723907af594fdec210b8379cd7d662224102` 已由 GitHub Actions run `27526413545` 发布 `core-80`，release body 已补中文说明；线上 asset `131,624,954` bytes，SHA256 `4047C8432BCA6C7F5FECBD4E1D6F55BE9717F28889B4699043A74138800E0E2A`。
- App/native fix: `rustdesk_bridge_loader.cpp` 在 native screen capture drain loop 中 map `OH_NativeBuffer` 后调用 `rustdesk_bridge_update_incoming_screen_frame()`，统计 `coreFrameCount/payloadBytes/corePushOk`；ArkTS wrapper 和 d.ts 已补 `getIncomingScreenFrameMetadata/copyIncomingScreenFrame/updateIncomingScreenFrame/clearIncomingScreenFrame`。
- Safety boundary: `incomingReady` 仍不能因为 native buffer 有 payload 就置 true；当前只证明“App native capture frame -> core incoming cache”链路可用，desktop server/video source 真接入后才能对外显示共享服务运行。
- Build result: `scripts\build_hap.bat` 强制下载 latest core 后 rebuilt `0.22.4` / versionCode `1000107`，BuildInfo time `2026-06-15 07:15`。
- HAP result: `18,968,380` bytes，SHA256 `7C0B0D7AF7FDD224908F6CE10323AA7FD8E11C0BCB233DD03936513219A321C5`。
- Verification: `verify_native_harmonyos_hap.ps1 -HapPath ... -SkipLaunch -SkipLogs` passed；`audit_connection_chain.ps1` passed `66 PASS, 0 FAIL, 0 SKIP`。
- Wireless install/start: `scripts\AUTO_BUILD_INSTALL.bat --skip-build auto` succeeded on `192.168.11.100:36169`；`bm dump` showed `versionName=0.22.4`, `versionCode=1000107`, native library path `entry/libs/arm64`; `pidof com.open.rundesk` returned `14881`。
- Clean hilog: after `hilog -r` and 18s wait, `reports\hilog_latest_after_0224_core80_wireless_app_strict_clean.txt` recorded `coreReady=4`, `query-onlines-result=8`, app fatal/panic/`exit(-1)` = 0, app-related signal = 0. Remaining `signal` matches are Wi-Fi service `HandleSignalPollChangedMsg unsupported`, not app crash.

## 2026-06-15 v0.22.2 native screen capture verification

- Symptom: after removing the explicit `CUSTOM_SCREEN_CAPTURE` pre-request, the share capture path still used ArkTS `AVScreenCaptureRecorder` and a temporary mp4 probe file. That was the wrong current primitive for RustDesk sharing because it records to a file instead of exposing live buffers to the desktop server/video source.
- App/native fix: `ScreenCaptureService.ets` now calls `NativeRustDeskBridge.startNativeScreenCapture/stopNativeScreenCapture/isNativeScreenCaptureActive/getNativeScreenCaptureStats`. `rustdesk_bridge_loader.cpp` creates `OH_AVScreenCapture`, starts `OH_AVScreenCapture_StartScreenCapture`, and drains `OH_AVScreenCapture_AcquireVideoBuffer`/native buffer map-unmap in a background loop for frame stats. `CMakeLists.txt` links `native_avscreen_capture` and `native_buffer`.
- Build result: `scripts\build_hap.bat` rebuilt `0.22.2` / versionCode `1000105`, BuildInfo time `2026-06-15 06:17`.
- Signed HAP: `18,946,878` bytes, SHA256 `9F4C40E9B10BE4D88BA5B76A24C887B1A8586F1A2812619CDC48C843C97DE1DA`.
- HAP verification: explicit `verify_native_harmonyos_hap.ps1 -HapPath ... -SkipLaunch -SkipLogs` passed; connection chain audit passed `50 PASS, 0 FAIL, 0 SKIP`.
- Wireless install/start: `scripts\AUTO_BUILD_INSTALL.bat --skip-build auto` succeeded on `192.168.11.100:36169`; `bm dump` showed `versionName=0.22.2`, `versionCode=1000105`, native library path `entry/libs/arm64`; `pidof com.open.rundesk` returned `62121`.
- Runtime log: `reports\hilog_latest_after_0222_wireless_app_strict.txt` has `coreReady=1`, `query-onlines-result=2`, and app fatal/panic/`exit(-1)` all `0`. The `signal` text hits are Wi-Fi service `HandleSignalPollChangedMsg unsupported` lines, not `com.open.rundesk` crashes.
- Remaining share work: this verifies the app native capture entry and install/runtime stability. It does not yet mean incoming sharing is ready; frame payload still must be bridged into the RustDesk desktop server/video source before `incomingReady=true`.

## 2026-06-15 v0.22.1 share/file authorization verification

- Symptom: the share start path still explicitly requested `CUSTOM_SCREEN_CAPTURE`, which can show as a screenshot/screen-capture authorization prompt before any real screen recording starts. The file transfer page could also read local Download paths without first waking the system file access authorization picker.
- App fix: `Index.checkScreenCapturePermissionAndToggle()` no longer calls `requestPermissionsFromUser(['ohos.permission.CUSTOM_SCREEN_CAPTURE'])`; `PermissionService.getRequiredPermissions()` and `requestShareRuntimePermissions()` no longer include that permission in generic requests. `FileTransfer.ets` now requests `DocumentViewPicker` folder authorization on page entry and before local file operations; `requestFileAccessAuthorization()` defaults to folder authorization mode.
- Build result: `scripts\build_hap.bat` rebuilt `0.22.1` / versionCode `1000104`, BuildInfo time `2026-06-15 06:01`.
- Signed HAP: `18,953,784` bytes, SHA256 `F16398FCB29E9E4F24131602D7B03C7BEED0A88BE0C37463BC7238AFF4C31A06`.
- HAP verification: explicit `verify_native_harmonyos_hap.ps1 -HapPath ... -SkipLaunch -SkipLogs` passed; connection chain audit passed `50 PASS, 0 FAIL, 0 SKIP`.
- Wireless install/start: `scripts\AUTO_BUILD_INSTALL.bat --skip-build auto` succeeded on `192.168.11.100:36169`; `bm dump` showed `versionName=0.22.1`, `versionCode=1000104`, native library path `entry/libs/arm64`; `pidof com.open.rundesk` returned `56711`.
- Runtime log: `reports\hilog_latest_after_0221_wireless_app_strict.txt` has `coreReady=71`, `initializeRuntimeFn returned=3`, `Bootstrap snapshot=1`, `query-onlines-result=134`, and app fatal/panic/signal/`exit(-1)` all `0`.

## 2026-06-15 RemoteControl direct session command and local recording conflict

- Symptom: the RemoteControl `Session Recording` menu requested `CUSTOM_SCREEN_CAPTURE` and called `ScreenCaptureService.startCapture()`, putting the phone into local recording state even though this menu is a remote-session command. `Switch Sides` and `Take Screenshot` also still used a generic option command, while voice chat used local `AudioService` capture state.
- App fix: `RemoteControl.ets` now calls `NativeRustDeskBridge.sessionSwitchSides()`, `sessionTakeScreenshot(display)`, `sessionRecordScreen(start)`, `sessionRequestVoiceCall()`, and `sessionCloseVoiceCall()` directly. Session recording no longer requests local screen-capture permission and no longer starts `ScreenCaptureService`.
- State fix: `record-status`, `voice-call-started`, `voice-call-waiting`, `voice-call-closed`, and `screenshot-response` events update the UI state/toasts. `I18nService.ets` includes Chinese translations for the new screenshot, recording, and voice-call toast strings.
- Core dependency: core commit `bc36b1d` was published by run `27516993020` as `core-79`; release asset `131,493,470` bytes, SHA256 `8BBB12AA93EE8703ABBED5BA6D411031AD78CE7FA6A71D7C407A0A350A8789F2`.
- Verification: `scripts\build_full_hap.bat` rebuilt `0.22.0` / versionCode `1000103`; signed HAP `18,929,896` bytes, SHA256 `C8EB6B133B71752F50447410DE3E9DECC0BDE3EFD3630E8CBA9AB015E3A39F96`; native/signature verifier passed with explicit `-HapPath`; connection chain audit passed `50 PASS, 0 FAIL, 0 SKIP`; wireless install/start to `192.168.11.100:36169` succeeded and `pidof com.open.rundesk` returned `56136`.
- Runtime log: `reports\hilog_latest_after_core79_wireless_app_only.txt` has `coreReady=187`, `initializeRuntimeFn returned=3`, `Bootstrap snapshot=1`, `query-onlines-result=366`, and app fatal/panic/signal/`exit(-1)` all `0`.

## 2026-06-15 v0.21.0 core-78 wireless runtime verification

- Context: after core run `27515510727` completed, the latest release `core-78` was downloaded by `scripts\build_full_hap.bat` and a full HAP rebuild was run.
- Core release: `https://github.com/liyan-lucky/librustdesk_core/releases/tag/core-78`, commit `cc5f4de27bff6c89a6edcf3ea3d19f01b12b128e`, asset `librustdesk_core.a` `131,470,442` bytes, SHA256 `F68E575D593BBE331E931E582870CB72EAA810BF56B817045162C44FCAF91ACD`.
- Build result: version `0.21.0`, versionCode `1000102`, BuildInfo time `2026-06-15 01:02`.
- Signed HAP: `18,928,728` bytes, SHA256 `491ED6E5CF1A8B6E2DD3F1E4661D99C15A4EB7D9B7B6FCB4A45BC92346BE2F90`.
- HAP verification: `scripts\verify_native_harmonyos_hap.ps1 -SkipLaunch -SkipLogs` passed.
- Static chain verification: `scripts\audit_connection_chain.ps1` passed `50 PASS, 0 FAIL, 0 SKIP`.
- Target: `192.168.11.100:36169`.
- Install/start command: `scripts\AUTO_BUILD_INSTALL.bat --skip-build auto`.
- Install/start result: `install bundle successfully`; `start ability successfully`.
- Package state from `bm dump -n com.open.rundesk`: installed `versionName=0.21.0`, `versionCode=1000102`, `minCompatibleVersionCode=1000102`, native library path `entry/libs/arm64`.
- Process state: `pidof com.open.rundesk` returned `41841`.
- Hilog capture: `reports\hilog_latest_after_core78_wireless.txt`; `coreReady` count 14, `initializeRuntimeFn returned` count 3, `Bootstrap snapshot` count 1, `query-onlines-result` count 20, app fatal/panic/signal/`Unexpected call`/`exit(-1)` all 0.

## 2026-06-15 v0.20.5 share start-order wireless verification

- Context: after changing share start order and requested/not-ready UI state, an incremental HAP build was run with unchanged core-76.
- Build result: version `0.20.5`, versionCode `1000101`, BuildInfo time `2026-06-15 00:56`.
- Signed HAP: `18,928,713` bytes, SHA256 `E174E07ABB77CBF3E17489AABFEBDC7A5827A7DDE409206C59377C4BA9631FF0`.
- HAP verification: `scripts\verify_native_harmonyos_hap.ps1 -SkipLaunch -SkipLogs` passed native library, runtime dependency, bundle, and signature checks.
- Static chain verification: `scripts\audit_connection_chain.ps1` passed `50 PASS, 0 FAIL, 0 SKIP`.
- Target: `192.168.11.100:36169`.
- Install/start command: `scripts\AUTO_BUILD_INSTALL.bat --skip-build auto`.
- Install/start result: `install bundle successfully`; `start ability successfully`.
- Package state from `bm dump -n com.open.rundesk`: installed `versionName=0.20.5`, `versionCode=1000101`, `minCompatibleVersionCode=1000101`, native library path `entry/libs/arm64`.
- Process state: `pidof com.open.rundesk` returned `39312`.

## 2026-06-15 v0.20.4 wireless reinstall/runtime smoke

- Context: after rebuilding the USB-only installer/doc updates, the user re-enabled wireless debugging and asked to retry wireless install.
- Target: `192.168.11.100:36169`.
- Install/start command: `scripts\AUTO_BUILD_INSTALL.bat --skip-build auto`.
- Install/start result: `install bundle successfully`; `start ability successfully`.
- Package state from `bm dump -n com.open.rundesk`: installed `versionName=0.20.4`, `versionCode=1000100`, `minCompatibleVersionCode=1000100`.
- Signed HAP: `18,917,915` bytes, SHA256 `D14C9DECF5199277F0AB7E97BBFCDF540BACEB06BCDA3AB74581F09A4CBF3CDB`.
- Process state: `pidof com.open.rundesk` returned `29101`.
- HDC target list after install: `192.168.11.100:36169`.
- HAP verification: `scripts\verify_native_harmonyos_hap.ps1 -SkipLaunch -SkipLogs` passed native library, runtime dependency, bundle, and signature checks.
- Static chain verification: `scripts\audit_connection_chain.ps1` passed `50 PASS, 0 FAIL, 0 SKIP`.
- Follow-up: continue manual feature logic validation and remaining share live-frame implementation work.

## 2026-06-15 share start-order recheck

- Finding: the share toggle still started `AVScreenCaptureRecorder` before asking the core whether the incoming service was really ready. That could show system screen-recording state even while the core returned `incomingReady=false`.
- App fix: `Index.toggleIncomingService(true)` now writes `enable-screen-capture=Y` and calls `setIncomingServiceEnabled` first; screen capture starts only after `officialCoreState.incomingReady=true`.
- UI fix: while requested but not ready, the share card displays `Share requested` / `Requested` and shows core `lastError/detailMessage`; it does not expose device ID/password or mark the share TAB as running.
- Remaining core work: real incoming share still requires OHOS live buffer capture plus `server_ohos.rs`/`scrap::common::ohos::Capturer` integration.

## 2026-06-15 core chat ABI follow-up

- Finding: the app-side `entry/src/main/cpp` copy already forwarded chat as `peer_id/message_type/content/timestamp`, but the source-of-truth core project `13_librustdesk_core\cpp` still declared and called `rustdesk_bridge_session_send_chat(content)` with one argument.
- Core fix: `cpp/rustdesk_bridge_abi.h` and `cpp/rustdesk_bridge_loader.cpp` in the real `F:\Visual_Studio_Code\13_librustdesk_core` project now use the four-argument Rust ABI and keep a one-argument fallback for legacy callers.
- Local core build: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_native_bridge.ps1` passed from the real core path.
- Local core artifact: `128,882,788` bytes, SHA256 `D0654CC920619957D99E640B7E18969135D224A0F562E26188241B41F47BC45A`.
- Core commits pushed: `034e446 Fix Harmony chat ABI forwarding`, then `cc5f4de Sync Harmony bridge TypeScript signatures`.
- Online core run: `https://github.com/liyan-lucky/librustdesk_core/actions/runs/27515510727` completed successfully and published release tag `core-78`; asset `131,470,442` bytes, SHA256 `F68E575D593BBE331E931E582870CB72EAA810BF56B817045162C44FCAF91ACD`. The earlier intermediate run `27515455076` was canceled after the follow-up source sync.

## 2026-06-15 v0.20.3 wireless install/runtime smoke

- Context: after USB-only mode returned `[Empty]`, the phone's wireless debugging was re-enabled and the current signed HAP was installed with `scripts\AUTO_BUILD_INSTALL.bat --skip-build auto`.
- Target: `192.168.11.100:36169`.
- Install/start result: `install bundle successfully`; `start ability successfully`.
- Package state from `bm dump -n com.open.rundesk`: installed `versionName=0.20.3`, `versionCode=1000099`.
- Signed HAP: `18,917,916` bytes, SHA256 `1B72498BBB53A8637C2859364B877D4116D06AEF339977ED1D1E0F6A8E2748A4`.
- Process state: `pidof com.open.rundesk` returned `26834`.
- Static chain verification: `scripts\audit_connection_chain.ps1` passed `50 PASS, 0 FAIL, 0 SKIP`.
- Follow-up: after the USB-only installer script/doc changes are rebuilt, install the next version again so the installed package matches the latest repository changes.

## 2026-06-14 share-state UI gate recheck

- Context: user reported the sharing link is not implemented yet and the current screen-recording state may conflict with sharing service readiness.
- Finding: App `Index.isShareServiceRunning()` treated either `officialCoreState.incomingReady` or `ScreenCaptureService.isCapturingActive()` as a running share service, so the UI could show service running, ID, and one-time password while native core still returned `incomingReady=false`.
- App fix: `isShareServiceRunning()` now only returns `settings.serviceEnabled && officialCoreState.incomingReady`; a separate recording-probe state shows `Recording Probe`, keeps the stop button available, and hides Device ID/password until the core incoming service is genuinely ready.
- Core state remains unchanged: `core-76` still reports incoming unavailable until the Harmony live frame/desktop server path is wired.
- Implementation note: ArkTS `AVScreenCaptureRecorder` is useful for permission/recording probe only. The SDK's native `OH_AVScreenCapture` buffer callback path is the likely route for real live frames into the RustDesk desktop server/video source.
- Verification required after build/install: open the Share TAB, start screen recording permission flow, confirm the card shows recording probe instead of service running when `incomingReady=false`, and confirm Stop service closes the probe.

## 2026-06-14 core-76 package/install verification

- Core source: `https://github.com/liyan-lucky/librustdesk_core/releases/tag/core-76`
- Core workflow: `https://github.com/liyan-lucky/librustdesk_core/actions/runs/27505721889`, conclusion `success`
- Core changes included: custom server key passthrough from `core-75`, plus chat send result semantics (`chat-error`, `chat-sent`, remote-only `chat-message`) in `core-76`
- Core asset: `librustdesk_core.a`, `131,470,712` bytes, SHA256 `AA4E99EBBE794C979348E2B1C0CAFDDE7B846703398B2D1146E84DDF5640130F`, FNV-1a 1MB `da7131f6`
- App HAP build: full build version `0.20.0`, versionCode `1000096`, signed HAP `18,909,325` bytes, SHA256 `3A6302DCFFCC93D62F79BA37B1E573E8929FDC56A697682A5A88E1BEA8DF4F9C`
- HAP verification: native libraries, runtime dependency check, bundle `com.open.rundesk`, and signature verification passed with `scripts\verify_native_harmonyos_hap.ps1 -HapPath ... -SkipLaunch -SkipLogs`
- Device target: `192.168.11.100:36169`
- Install result: `install bundle successfully`
- Package state from `bm dump -n com.open.rundesk`: installed `versionName=0.20.0`, `versionCode=1000096`
- Launch result: blocked by password lock, `Error Code:10106102`; `power-shell wakeup`, `uitest uiInput swipe`, and `aa start -N` did not unlock the phone in developer mode
- Runtime follow-up after manual unlock: start `com.open.rundesk`, capture hilog, and verify `coreReady=true`, `query-onlines-result`, chat send failure no longer becomes a message, and custom server key path.

## 2026-06-14 post-doc unlocked install/runtime recheck

- Context: after the documentation update, the phone was manually unlocked again and the unchanged signed HAP was reinstalled with `scripts\AUTO_BUILD_INSTALL.bat --skip-build 192.168.11.100:36169`.
- Install/start result: `install bundle successfully`; `start ability successfully`.
- Process state: `pidof com.open.rundesk` returned `12565`; the process was still alive on the follow-up check.
- Hilog capture: `reports/hilog_latest_after_core74_post_docs_unlocked.txt`, `930,112` bytes.
- Hilog summary: `coreReady= true` count 7, `query-onlines-result` count 14, app log lines 314, app fatal/panic/signal all 0. The 87 plain `signal` matches were outside `com.open.rundesk` system logs.
- Experience: when only docs changed after a verified full HAP build, use skip-build install/start plus hilog smoke verification; do not rebuild solely for documentation text.

## 2026-06-14 core-74 source-mirror/package verification

- Core source: `https://github.com/liyan-lucky/librustdesk_core/releases/tag/core-74`
- Core workflow: `https://github.com/liyan-lucky/librustdesk_core/actions/runs/27486100946`, conclusion `success`
- Core commit: `1b987914a2c27ace376e5af45a9c6790d84d40b4`
- Core asset: `librustdesk_core.a`, `131,471,786` bytes, SHA256 `3755D448FBB1A583E7B5F7C3C6ADEC29D8AF0FBB7E5DD192251CD18A68C45D7C`
- App HAP build: full build version `0.19.0`, versionCode `1000090`, signed HAP `18,828,000` bytes, SHA256 `4BF796ED37DD1FCADF455F1585A55E36CFFC58940235D82FCAC55C6CBA6042A1`
- HAP verification: native libraries, runtime dependency check, bundle `com.open.rundesk`, and signature verification passed with `scripts\verify_native_harmonyos_hap.ps1 -HapPath ... -SkipLaunch -SkipLogs`
- Device target: `192.168.11.100:36169`
- Install result: `install bundle successfully`
- Launch result after manual unlock: `start ability successfully`
- Package state from `bm dump -n com.open.rundesk`: installed `versionName=0.19.0`, `versionCode=1000090`, native library path `entry/libs/arm64`
- Process state: `pidof com.open.rundesk` returned `4232`; the same process was still alive after a 20 second follow-up check
- Hilog capture: `reports/hilog_latest_after_core74_unlocked.txt`
- Hilog summary: `coreReady= true` count 5, `query-onlines-result` count 6, app log lines 49, app fatal/panic/signal all 0. `signal` matches outside app logs were Wi-Fi/hiview system messages.
- Runtime follow-up: remote directory events, terminal output, clipboard send path, and RemoteControl command failure prompts still need feature-interaction testing against an active peer.

## 2026-06-14 core-73 file-transfer/switch-sides package verification

- Core source: `https://github.com/liyan-lucky/librustdesk_core/releases/tag/core-73`
- Core workflow: `https://github.com/liyan-lucky/librustdesk_core/actions/runs/27485061967`, conclusion `success`
- Core commit: `275b231e11aefd4a2e51050fc74fbdeba9c566bd`
- Core asset: `librustdesk_core.a`, `131,471,532` bytes, SHA256 `E444D739EC958CD1485519FE0A712BFC1F074B60EEA65D71552E7E95A909A7B1`
- App HAP build: full build version `0.18.0`, versionCode `1000088`, signed HAP `18,828,338` bytes, SHA256 `F40E44646D8DB6A561559B1815E812FB8D4B85FDA0D8D2073DBDC26648AC5DB4`
- HAP verification: native libraries, runtime dependency check, bundle `com.open.rundesk`, and signature verification passed with `scripts\verify_native_harmonyos_hap.ps1 -HapPath ... -SkipLaunch -SkipLogs`
- Device target: `192.168.11.100:36169`
- Install result: `install bundle successfully`
- Launch result: blocked by lock screen, `Error Code:10106102`; `power-shell wakeup`, lockscreen swipe, and `aa start -N` still left `SCBScreenLock` active
- Package state from `bm dump -n com.open.rundesk`: installed `versionName=0.18.0`, `versionCode=1000088`, native library path `entry/libs/arm64`
- Process state: `pidof com.open.rundesk` returned no process after the blocked launch
- Hilog capture: `reports/hilog_latest_after_core73_locked.txt`; no `com.open.rundesk`, `coreReady`, `RustDesk bridge`, or `official-native` entries because the app did not start. `Fatal/signal` matches were Wi-Fi/cellular system logs, not app logs.
- Runtime follow-up after unlock: verify `coreReady=true`, remote directory events (`folder-files`, `job-progress`, `job-done`, `job-error`) and RemoteControl `Switch Sides` menu path.

## 2026-06-14 core-71 terminal/audio bridge verification

- Core source: `https://github.com/liyan-lucky/librustdesk_core/releases/tag/core-71`
- Core workflow: `https://github.com/liyan-lucky/librustdesk_core/actions/runs/27483922931`, conclusion `success`
- Core commit: `38c837cee0bb28aee795c0fc3895044f1440f96a`
- Core asset: `librustdesk_core.a`, `131,297,004` bytes, SHA256 `C750A785297AA22A2518B158BF334A1B1415C4E0739E01D0856C8BB5D450E15C`
- App HAP build: full build version `0.17.0`, versionCode `1000087`, signed HAP `18,821,844` bytes, SHA256 `46E78399C826595CB509261B50A82BB8D1DC8941C041415792DA4186D17EF780`
- HAP verification: native libraries, runtime dependency check, bundle `com.open.rundesk`, and signature verification passed with `scripts\verify_native_harmonyos_hap.ps1 -HapPath ... -SkipLaunch -SkipLogs`
- Device target: `192.168.11.100:36169`
- Install/launch result: `install bundle successfully` and `start ability successfully`
- Package state from `bm dump -n com.open.rundesk`: installed `versionName=0.17.0`, `versionCode=1000087`, native library path `entry/libs/arm64`
- Process state after final skip-build reinstall: `pidof com.open.rundesk` returned `18876`
- Hilog capture: `reports/hilog_latest_after_core71.txt`
- Hilog summary after final skip-build reinstall: `coreReady= true` count 39, `query-onlines-result` count 78, `RustDesk bridge` count 2, `official-native` count 4, app fatal/panic/signal all 0
- Runtime evidence: online query returned peer `1283267036`; LAN discovery received Windows peer pong from `192.168.11.116:21119`

## 2026-06-13 core-70 verification

- Core source: `https://github.com/liyan-lucky/librustdesk_core/releases/tag/core-70`
- Core asset: `librustdesk_core.a`, `131,263,476` bytes, SHA256 `3C238E788636DEF1BD97B21194D7B8FB16327E19EDD83E4387560E9485C60153`
- Core workflow: `https://github.com/liyan-lucky/librustdesk_core/actions/runs/27459455573`, conclusion `success`
- App HAP build: version `0.13.40`, signed HAP `18,746,449` bytes, SHA256 `A927DA8F54806F0AA53AEAD16575016AE6F535B8AED5FCA537AD7F219E35F070`
- HAP verification: native libraries and signature passed with `scripts\verify_native_harmonyos_hap.ps1 -SkipLaunch -SkipLogs`
- Device target: `192.168.11.100:36169`
- Install result: `install bundle successfully`
- Launch result: blocked by lock screen, `Error Code:10106102`
- Package state from `bm dump -n com.open.rundesk`: installed `versionName=0.13.40`, `versionCode=1000071`, native library path `entry/libs/arm64`
- Process state: `pidof com.open.rundesk` returned no process after the blocked launch
- Hilog capture: `reports/hilog_latest_after_core70.txt`; no `coreReady`, `session-connected`, `video-frame`, panic, crash, or RustDesk runtime evidence because the app did not start

## Current conclusion

The core-76 artifact and HAP packaging path are valid. Build, package verification, and WiFi install passed on 2026-06-14; runtime `coreReady=true` smoke verification is pending because the phone is currently password-locked and HDC cannot auto-unlock it in developer mode.

## Online app build status

- Latest app release: `https://github.com/liyan-lucky/rustdesk_harmonyos/releases/tag/harmonyos-20260612-065038`
- Latest app workflow run checked: `https://github.com/liyan-lucky/rustdesk_harmonyos/actions/runs/27443845710`
- Run state: failed on old commit `0000da60074323447862ac75774b6ebe26a95ea3`; it does not include the locally verified core-76, staged-signing/HAP-only, and staging junction fixes
- Required next online verification: push current app changes, trigger `Build HarmonyOS HAP Linux`, confirm artifact/release contains only `.hap`
