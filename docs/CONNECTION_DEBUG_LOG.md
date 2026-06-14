# Connection Debug Log

> Current focused record for connection and video-stream verification. Keep this file updated when device-side behavior is tested.

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
