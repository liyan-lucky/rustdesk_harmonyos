# Connection Chain Audit

- Generated: 2026-06-15 07:16:28
- Project: F:\Visual_Studio_Code\11_Rustdesk_harmonyos
- HAP: F:\Visual_Studio_Code\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap
- Summary: 66 PASS, 0 FAIL, 0 SKIP

| # | Status | Check | Detail |
|---:|:---:|---|---|
| 1 | PASS | Hvigor build wrapper exists | scripts\run_hvigor_with_sdk_patch.js |
| 2 | PASS | Native HAP verifier exists | scripts\verify_native_harmonyos_hap.ps1 |
| 3 | PASS | GitHub online build wrapper exists | scripts\github_build_harmonyos.ps1 |
| 4 | PASS | GitHub online workflow exists | .github\workflows\build-harmonyos.yml |
| 5 | PASS | App profile exists | AppScope\app.json5 |
| 6 | PASS | Entry build profile exists | entry\build-profile.json5 |
| 7 | PASS | Native core archive exists | F:\Visual_Studio_Code\11_Rustdesk_harmonyos\entry\src\main\libs\arm64\librustdesk_core.a |
| 8 | PASS | Native core archive size is plausible | 131624954 bytes |
| 9 | PASS | CoreBuildInfo exists | entry\src\main\ets\common\CoreBuildInfo.ets |
| 10 | PASS | CoreBuildInfo size matches native core | FILE_SIZE=131624954 |
| 11 | PASS | CoreBuildInfo SHA256 matches native core | HASH_SHA256=4047C8432BCA6C7F5FECBD4E1D6F55BE9717F28889B4699043A74138800E0E2A |
| 12 | PASS | CMake declares rustdesk_bridge shared library | entry\src\main\cpp\CMakeLists.txt matches add_library\(\s*rustdesk_bridge\s+SHARED |
| 13 | PASS | CMake links static native core archive | entry\src\main\cpp\CMakeLists.txt matches librustdesk_core\.a |
| 14 | PASS | CMake does not link time_service_ndk | entry\src\main\cpp\CMakeLists.txt does not match forbidden pattern |
| 15 | PASS | OH_TimeService fallback stub is compiled locally | entry\src\main\cpp\ohos_stubs.cpp matches OH_TimeService_GetTimeZone |
| 16 | PASS | NAPI loader source exists | entry\src\main\cpp\rustdesk_bridge_loader.cpp |
| 17 | PASS | NAPI loader registers librustdesk_bridge.so alias | entry\src\main\cpp\rustdesk_bridge_loader.cpp matches nm_modname\s*=\s*"librustdesk_bridge\.so" |
| 18 | PASS | NAPI loader registers librustdesk_bridge alias | entry\src\main\cpp\rustdesk_bridge_loader.cpp matches nm_modname\s*=\s*"librustdesk_bridge" |
| 19 | PASS | NAPI loader registers canonical rustdesk_bridge name | entry\src\main\cpp\rustdesk_bridge_loader.cpp matches nm_modname\s*=\s*"rustdesk_bridge" |
| 20 | PASS | NAPI loader logs alias registration | entry\src\main\cpp\rustdesk_bridge_loader.cpp matches aliases ready |
| 21 | PASS | ArkTS statically imports native bridge so | entry\src\main\ets\services\NativeRustDeskBridge.ts matches import\s+rustdeskBridgeLibrary\s+from\s+'librustdesk_bridge\.so' |
| 22 | PASS | Native module candidates include canonical name | entry\src\main\ets\services\NativeRustDeskBridge.ts matches 'rustdesk_bridge' |
| 23 | PASS | Native module shape probes nested rustdesk_bridge export | entry\src\main\ets\services\NativeRustDeskBridge.ts matches top\.rustdesk_bridge |
| 24 | PASS | Known bridge function list includes connectToPeer | entry\src\main\ets\services\NativeRustDeskBridge.ts matches 'connectToPeer' |
| 25 | PASS | initializeRuntime wrapper is present | entry\src\main\ets\services\NativeRustDeskBridge.ts matches static\s+initializeRuntime |
| 26 | PASS | connectToPeer wrapper resolves native ABI names | entry\src\main\ets\services\NativeRustDeskBridge.ts matches rustdesk_bridge_connect_to_peer |
| 27 | PASS | pullSessionEvents wrapper is present | entry\src\main\ets\services\NativeRustDeskBridge.ts matches pullSessionEvents |
| 28 | PASS | pullLatestVideoFrame wrapper is present | entry\src\main\ets\services\NativeRustDeskBridge.ts matches pullLatestVideoFrame |
| 29 | PASS | refreshSessionVideo wrapper is present | entry\src\main\ets\services\NativeRustDeskBridge.ts matches refreshSessionVideo |
| 30 | PASS | harmonyNextRgba wrapper is present | entry\src\main\ets\services\NativeRustDeskBridge.ts matches harmonyNextRgba |
| 31 | PASS | reconnectSession wrapper is present | entry\src\main\ets\services\NativeRustDeskBridge.ts matches reconnectSession |
| 32 | PASS | submitSessionPassword wrapper is present | entry\src\main\ets\services\NativeRustDeskBridge.ts matches submitSessionPassword |
| 33 | PASS | Official bridge reports missing native core as hard error | entry\src\main\ets\services\OfficialRustDeskBridge.ets matches Native core missing |
| 34 | PASS | Official bridge retries connect after native reset | entry\src\main\ets\services\OfficialRustDeskBridge.ets matches resetForRetry\(\) |
| 35 | PASS | Official bridge handles session-connected events | entry\src\main\ets\services\OfficialRustDeskBridge.ets matches session-connected |
| 36 | PASS | Official bridge handles session-error events | entry\src\main\ets\services\OfficialRustDeskBridge.ets matches session-error |
| 37 | PASS | Official bridge handles session-closed events | entry\src\main\ets\services\OfficialRustDeskBridge.ets matches session-closed |
| 38 | PASS | Remote page has terminal event handler | entry\src\main\ets\pages\RemoteControl.ets matches handleTerminalBridgeEvent |
| 39 | PASS | Remote terminal event handler opens reconnect dialog | entry\src\main\ets\pages\RemoteControl.ets matches showReconnectDialogFromState\(this\.lt\('Connection Error'\) |
| 40 | PASS | Remote page has stale connected-session watchdog | entry\src\main\ets\pages\RemoteControl.ets matches maybeHandleStaleConnectedSession |
| 41 | PASS | Quality status is cached even when panel is hidden | applyQualityStatus parses and caches before panel rendering |
| 42 | PASS | Quality cache state exists | entry\src\main\ets\pages\RemoteControl.ets matches qualityMetricItems |
| 43 | PASS | Quality cache updater exists | entry\src\main\ets\pages\RemoteControl.ets matches updateQualityDetailCache |
| 44 | PASS | Connection info panel is scrollable | entry\src\main\ets\pages\RemoteControl.ets matches Scroll\(\)\s*\{\s*Column\(\{\s*space:\s*8\s*\}\) |
| 45 | PASS | Quality panel renders dynamic metric rows | entry\src\main\ets\pages\RemoteControl.ets matches ForEach\(this\.qualityMetricItems |
| 46 | PASS | Quality parser captures target bitrate | entry\src\main\ets\pages\RemoteControl.ets matches target_bitrate |
| 47 | PASS | Quality parser captures codec format | entry\src\main\ets\pages\RemoteControl.ets matches codec_format |
| 48 | PASS | Speed summary falls back to target bitrate | entry\src\main\ets\pages\RemoteControl.ets matches targetBitrateDisplay |
| 49 | PASS | Built HAP contains required native libraries | F:\Visual_Studio_Code\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap |
| 50 | PASS | Packaged native bridge has no missing time service dependency | NEEDED set excludes libtime_service_ndk.so and includes NAPI/Hilog |
| 51 | PASS | CMake links native screen capture library | entry\src\main\cpp\CMakeLists.txt matches native_avscreen_capture |
| 52 | PASS | CMake links native buffer library | entry\src\main\cpp\CMakeLists.txt matches native_buffer |
| 53 | PASS | Screen capture service starts native capture through bridge | entry\src\main\ets\services\ScreenCaptureService.ets matches NativeRustDeskBridge\.startNativeScreenCapture |
| 54 | PASS | Screen capture service no longer uses recorder/screenshot APIs | entry\src\main\ets\services\ScreenCaptureService.ets does not match forbidden pattern |
| 55 | PASS | Index does not pre-request custom screen capture permission | entry\src\main\ets\pages\Index.ets does not match forbidden pattern |
| 56 | PASS | Permission service does not request custom screen capture generically | entry\src\main\ets\services\PermissionService.ets does not match forbidden pattern |
| 57 | PASS | Native loader starts original-stream screen capture | entry\src\main\cpp\rustdesk_bridge_loader.cpp matches OH_AVScreenCapture_StartScreenCapture |
| 58 | PASS | Native loader drains screen capture native buffers | entry\src\main\cpp\rustdesk_bridge_loader.cpp matches OH_AVScreenCapture_AcquireVideoBuffer |
| 59 | PASS | Native loader pushes incoming screen frames into core | entry\src\main\cpp\rustdesk_bridge_loader.cpp matches rustdesk_bridge_update_incoming_screen_frame |
| 60 | PASS | Core ABI declares incoming screen frame update | entry\src\main\cpp\rustdesk_bridge_abi.h matches rustdesk_bridge_update_incoming_screen_frame |
| 61 | PASS | Native bridge wrapper exposes incoming frame metadata | entry\src\main\ets\services\NativeRustDeskBridge.ts matches static\s+getIncomingScreenFrameMetadata |
| 62 | PASS | Native bridge wrapper exposes incoming frame copy | entry\src\main\ets\services\NativeRustDeskBridge.ts matches static\s+copyIncomingScreenFrame |
| 63 | PASS | Native d.ts exposes incoming frame update | entry\src\main\cpp\types\librustdesk_bridge\index.d.ts matches updateIncomingScreenFrame |
| 64 | PASS | File transfer page bootstraps local access authorization | entry\src\main\ets\pages\FileTransfer.ets matches bootstrapFileTransferPage |
| 65 | PASS | File transfer local operations use access authorization guard | entry\src\main\ets\pages\FileTransfer.ets matches ensureLocalFileAccessAuthorization |
| 66 | PASS | File access authorization uses folder auth mode | entry\src\main\ets\services\PermissionService.ets matches requestFileAuthorization\(\s*\{\s*folder:\s*true,\s*authMode:\s*true\s*\}\s*\) |
